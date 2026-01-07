+++
title = "MCP Connection Pooling: Optimize Resource Usage"
image = "images/mcp-connection-pooling.webp"
date = 2025-11-03
description = "Implement connection pooling for MCP tools. Manage database connections, API clients, and resources efficiently for high-throughput AI agents."
draft = false
tags = ['mcp', 'performance', 'connections']
voice = false

[howto]
name = "Implement Connection Pooling"
totalTime = 25
[[howto.steps]]
name = "Identify poolable resources"
text = "Find connections that benefit from pooling."
[[howto.steps]]
name = "Configure pool sizes"
text = "Set min, max, and idle connection limits."
[[howto.steps]]
name = "Implement health checks"
text = "Validate connections before use."
[[howto.steps]]
name = "Handle pool exhaustion"
text = "Manage behavior when pool is full."
[[howto.steps]]
name = "Monitor pool metrics"
text = "Track pool utilization and performance."
+++


Creating connections is expensive.

Database connections: 50-100ms. API handshakes: 100-500ms.

Pooling reuses connections. Pooling is fast.

## Why connection pooling?

Without pooling:
```
Request 1: Create connection (100ms) → Execute (50ms) → Close
Request 2: Create connection (100ms) → Execute (50ms) → Close
Request 3: Create connection (100ms) → Execute (50ms) → Close
Total: 450ms
```

With pooling:
```
Request 1: Get from pool (1ms) → Execute (50ms) → Return to pool
Request 2: Get from pool (1ms) → Execute (50ms) → Return to pool
Request 3: Get from pool (1ms) → Execute (50ms) → Return to pool
Total: 153ms (3x faster)
```

## Step 1: Generic connection pool

Using [Gantz](https://gantz.run):

```yaml
# gantz.yaml
name: pooled-tools

pools:
  database:
    min_size: 5
    max_size: 20
    max_idle_time: 300
    health_check_interval: 30

  redis:
    min_size: 2
    max_size: 10
    max_idle_time: 600

tools:
  - name: query_database
    description: Query with pooled connection
    pool: database
    parameters:
      - name: query
        type: string
        required: true
    script:
      command: python
      args: ["scripts/pooled_query.py", "{{query}}"]
```

Connection pool implementation:

```python
import threading
import time
import queue
from typing import TypeVar, Generic, Callable, Optional, Any
from dataclasses import dataclass
from contextlib import contextmanager

T = TypeVar('T')

@dataclass
class PoolConfig:
    """Connection pool configuration."""
    min_size: int = 5
    max_size: int = 20
    max_idle_time: int = 300  # seconds
    acquire_timeout: int = 30  # seconds
    health_check_interval: int = 60
    validation_query: Optional[str] = None

class PooledConnection(Generic[T]):
    """Wrapper for pooled connection."""

    def __init__(self, connection: T, created_at: float):
        self.connection = connection
        self.created_at = created_at
        self.last_used = created_at
        self.use_count = 0

    def mark_used(self):
        """Mark connection as used."""
        self.last_used = time.time()
        self.use_count += 1

    def is_stale(self, max_idle: int) -> bool:
        """Check if connection is stale."""
        return time.time() - self.last_used > max_idle

class ConnectionPool(Generic[T]):
    """Generic connection pool."""

    def __init__(
        self,
        factory: Callable[[], T],
        config: PoolConfig,
        validator: Callable[[T], bool] = None,
        destroyer: Callable[[T], None] = None
    ):
        self.factory = factory
        self.config = config
        self.validator = validator or (lambda x: True)
        self.destroyer = destroyer or (lambda x: None)

        self._pool: queue.Queue[PooledConnection[T]] = queue.Queue()
        self._size = 0
        self._lock = threading.Lock()
        self._closed = False

        # Initialize minimum connections
        self._initialize_pool()

        # Start maintenance thread
        self._start_maintenance()

    def _initialize_pool(self):
        """Create initial connections."""
        for _ in range(self.config.min_size):
            self._add_connection()

    def _add_connection(self) -> bool:
        """Add new connection to pool."""
        with self._lock:
            if self._size >= self.config.max_size:
                return False

            try:
                conn = self.factory()
                pooled = PooledConnection(conn, time.time())
                self._pool.put(pooled)
                self._size += 1
                return True
            except Exception as e:
                print(f"Failed to create connection: {e}")
                return False

    def _remove_connection(self, pooled: PooledConnection[T]):
        """Remove connection from pool."""
        with self._lock:
            try:
                self.destroyer(pooled.connection)
            except Exception:
                pass
            self._size -= 1

    @contextmanager
    def acquire(self):
        """Acquire connection from pool."""
        if self._closed:
            raise RuntimeError("Pool is closed")

        pooled = self._get_connection()
        try:
            yield pooled.connection
        finally:
            self._return_connection(pooled)

    def _get_connection(self) -> PooledConnection[T]:
        """Get valid connection from pool."""
        deadline = time.time() + self.config.acquire_timeout

        while time.time() < deadline:
            try:
                pooled = self._pool.get(timeout=1)

                # Validate connection
                if self._is_valid(pooled):
                    pooled.mark_used()
                    return pooled
                else:
                    self._remove_connection(pooled)

            except queue.Empty:
                # Try to create new connection
                if self._add_connection():
                    continue

        raise TimeoutError("Could not acquire connection from pool")

    def _return_connection(self, pooled: PooledConnection[T]):
        """Return connection to pool."""
        if self._closed:
            self._remove_connection(pooled)
            return

        # Check if still valid
        if self._is_valid(pooled):
            self._pool.put(pooled)
        else:
            self._remove_connection(pooled)
            # Replace with new connection if below min
            if self._size < self.config.min_size:
                self._add_connection()

    def _is_valid(self, pooled: PooledConnection[T]) -> bool:
        """Check if connection is valid."""
        if pooled.is_stale(self.config.max_idle_time):
            return False

        try:
            return self.validator(pooled.connection)
        except Exception:
            return False

    def _start_maintenance(self):
        """Start background maintenance thread."""
        def maintain():
            while not self._closed:
                time.sleep(self.config.health_check_interval)
                self._maintain()

        thread = threading.Thread(target=maintain, daemon=True)
        thread.start()

    def _maintain(self):
        """Perform pool maintenance."""
        # Remove stale connections
        valid_connections = []

        while not self._pool.empty():
            try:
                pooled = self._pool.get_nowait()
                if self._is_valid(pooled) and self._size > self.config.min_size:
                    valid_connections.append(pooled)
                else:
                    self._remove_connection(pooled)
            except queue.Empty:
                break

        # Return valid connections
        for pooled in valid_connections:
            self._pool.put(pooled)

        # Ensure minimum connections
        while self._size < self.config.min_size:
            if not self._add_connection():
                break

    def close(self):
        """Close pool and all connections."""
        self._closed = True

        while not self._pool.empty():
            try:
                pooled = self._pool.get_nowait()
                self._remove_connection(pooled)
            except queue.Empty:
                break

    def stats(self) -> dict:
        """Get pool statistics."""
        return {
            "size": self._size,
            "available": self._pool.qsize(),
            "in_use": self._size - self._pool.qsize(),
            "max_size": self.config.max_size,
            "min_size": self.config.min_size
        }
```

## Step 2: Database connection pool

Specialized pool for databases:

```python
import psycopg2
from psycopg2 import pool as pg_pool

class DatabasePool:
    """PostgreSQL connection pool."""

    def __init__(self, dsn: str, config: PoolConfig):
        self.dsn = dsn
        self.config = config

        self.pool = ConnectionPool(
            factory=lambda: psycopg2.connect(dsn),
            config=config,
            validator=self._validate_connection,
            destroyer=lambda c: c.close()
        )

    def _validate_connection(self, conn) -> bool:
        """Validate database connection."""
        try:
            with conn.cursor() as cur:
                cur.execute("SELECT 1")
                return True
        except Exception:
            return False

    @contextmanager
    def connection(self):
        """Get database connection."""
        with self.pool.acquire() as conn:
            yield conn

    @contextmanager
    def cursor(self):
        """Get database cursor."""
        with self.connection() as conn:
            cursor = conn.cursor()
            try:
                yield cursor
                conn.commit()
            except Exception:
                conn.rollback()
                raise
            finally:
                cursor.close()

    def execute(self, query: str, params: tuple = None) -> list:
        """Execute query and return results."""
        with self.cursor() as cur:
            cur.execute(query, params)
            if cur.description:
                return cur.fetchall()
            return []

# Usage with MCP tool
db_pool = DatabasePool(
    dsn="postgresql://user:pass@localhost/db",
    config=PoolConfig(min_size=5, max_size=20)
)

def query_database_tool(query: str) -> dict:
    """MCP tool for database queries."""
    try:
        results = db_pool.execute(query)
        return {"success": True, "data": results}
    except Exception as e:
        return {"success": False, "error": str(e)}
```

## Step 3: HTTP client pool

Pool HTTP connections for API calls:

```python
import httpx
from typing import Dict, Any

class HTTPClientPool:
    """Pooled HTTP client for API calls."""

    def __init__(
        self,
        base_url: str = None,
        max_connections: int = 100,
        max_keepalive: int = 20,
        timeout: float = 30.0
    ):
        self.base_url = base_url

        # Connection limits
        limits = httpx.Limits(
            max_connections=max_connections,
            max_keepalive_connections=max_keepalive
        )

        # Create pooled client
        self.client = httpx.Client(
            base_url=base_url,
            limits=limits,
            timeout=timeout,
            http2=True  # Enable HTTP/2 for multiplexing
        )

    def get(self, url: str, **kwargs) -> httpx.Response:
        """GET request with pooled connection."""
        return self.client.get(url, **kwargs)

    def post(self, url: str, **kwargs) -> httpx.Response:
        """POST request with pooled connection."""
        return self.client.post(url, **kwargs)

    def close(self):
        """Close client and connections."""
        self.client.close()

class AsyncHTTPClientPool:
    """Async pooled HTTP client."""

    def __init__(
        self,
        base_url: str = None,
        max_connections: int = 100,
        timeout: float = 30.0
    ):
        limits = httpx.Limits(max_connections=max_connections)

        self.client = httpx.AsyncClient(
            base_url=base_url,
            limits=limits,
            timeout=timeout,
            http2=True
        )

    async def get(self, url: str, **kwargs) -> httpx.Response:
        return await self.client.get(url, **kwargs)

    async def post(self, url: str, **kwargs) -> httpx.Response:
        return await self.client.post(url, **kwargs)

    async def close(self):
        await self.client.aclose()

# Usage
api_pool = HTTPClientPool(
    base_url="https://api.example.com",
    max_connections=50
)

def call_api_tool(endpoint: str, data: dict) -> dict:
    """MCP tool for API calls."""
    response = api_pool.post(endpoint, json=data)
    return response.json()
```

## Step 4: Redis connection pool

Pool Redis connections:

```python
import redis
from typing import Optional

class RedisPool:
    """Redis connection pool."""

    def __init__(
        self,
        host: str = "localhost",
        port: int = 6379,
        db: int = 0,
        max_connections: int = 50,
        password: Optional[str] = None
    ):
        self.pool = redis.ConnectionPool(
            host=host,
            port=port,
            db=db,
            max_connections=max_connections,
            password=password,
            decode_responses=True,
            socket_keepalive=True,
            health_check_interval=30
        )

        self.client = redis.Redis(connection_pool=self.pool)

    def get(self, key: str) -> Optional[str]:
        """Get value from Redis."""
        return self.client.get(key)

    def set(self, key: str, value: str, ttl: int = None):
        """Set value in Redis."""
        if ttl:
            self.client.setex(key, ttl, value)
        else:
            self.client.set(key, value)

    def delete(self, key: str):
        """Delete key from Redis."""
        self.client.delete(key)

    def stats(self) -> dict:
        """Get pool statistics."""
        info = self.pool.connection_kwargs
        return {
            "host": info.get("host"),
            "port": info.get("port"),
            "max_connections": self.pool.max_connections,
            "current_connections": len(self.pool._in_use_connections)
        }

# Usage
redis_pool = RedisPool(max_connections=20)

def cache_tool(action: str, key: str, value: str = None) -> dict:
    """MCP tool for caching."""
    if action == "get":
        result = redis_pool.get(key)
        return {"value": result}
    elif action == "set":
        redis_pool.set(key, value)
        return {"success": True}
    elif action == "delete":
        redis_pool.delete(key)
        return {"success": True}
```

## Step 5: Pool management

Centralized pool management:

```python
from typing import Dict, Any
from prometheus_client import Gauge

# Metrics
pool_size_gauge = Gauge(
    'connection_pool_size',
    'Current pool size',
    ['pool_name']
)

pool_available_gauge = Gauge(
    'connection_pool_available',
    'Available connections',
    ['pool_name']
)

class PoolManager:
    """Manage multiple connection pools."""

    def __init__(self):
        self.pools: Dict[str, Any] = {}

    def register(self, name: str, pool: Any):
        """Register a connection pool."""
        self.pools[name] = pool

    def get(self, name: str) -> Any:
        """Get pool by name."""
        if name not in self.pools:
            raise KeyError(f"Pool not found: {name}")
        return self.pools[name]

    def stats(self) -> Dict[str, dict]:
        """Get stats for all pools."""
        return {
            name: pool.stats() if hasattr(pool, 'stats') else {}
            for name, pool in self.pools.items()
        }

    def update_metrics(self):
        """Update Prometheus metrics."""
        for name, pool in self.pools.items():
            if hasattr(pool, 'stats'):
                stats = pool.stats()
                pool_size_gauge.labels(pool_name=name).set(
                    stats.get('size', 0)
                )
                pool_available_gauge.labels(pool_name=name).set(
                    stats.get('available', 0)
                )

    def close_all(self):
        """Close all pools."""
        for pool in self.pools.values():
            if hasattr(pool, 'close'):
                pool.close()

# Global pool manager
pools = PoolManager()

# Register pools
pools.register('database', DatabasePool(
    dsn="postgresql://...",
    config=PoolConfig(min_size=5, max_size=20)
))

pools.register('redis', RedisPool(max_connections=20))

pools.register('api', HTTPClientPool(max_connections=50))

# MCP tool using pools
def pooled_query(pool_name: str, operation: str, **kwargs) -> dict:
    """Execute operation using pooled connection."""
    pool = pools.get(pool_name)

    if pool_name == 'database':
        return pool.execute(kwargs.get('query'))
    elif pool_name == 'redis':
        return pool.get(kwargs.get('key'))
    elif pool_name == 'api':
        return pool.get(kwargs.get('url')).json()
```

## Summary

Connection pooling for MCP:

1. **Generic pools** - Reusable pool implementation
2. **Database pools** - Efficient DB connections
3. **HTTP pools** - API client pooling
4. **Redis pools** - Cache connection pooling
5. **Pool management** - Centralized control

Build tools with [Gantz](https://gantz.run), pool for performance.

Create once. Reuse always.

## Related reading

- [MCP Performance](/post/mcp-performance/) - Optimize throughput
- [Agent Scaling](/post/agent-scaling/) - Scale connections
- [MCP Caching](/post/mcp-caching/) - Cache with pools

---

*How do you manage connections in your agents? Share your strategies.*
