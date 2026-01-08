+++
title = "MCP Concurrency: Parallel Tool Execution"
image = "images/mcp-concurrency.webp"
date = 2025-11-11
description = "Implement concurrent tool execution for MCP. Parallel processing, thread pools, async patterns, and rate limiting for high-throughput AI agents."
summary = "Execute multiple MCP tool calls in parallel using thread pools, asyncio, and rate-limited executors to achieve up to 5x throughput improvements. This guide covers concurrent tool execution with dependency ordering, parallel database operations, and monitoring patterns to track concurrent operation metrics."
draft = false
tags = ['mcp', 'performance', 'concurrency']
voice = false

[howto]
name = "Implement MCP Concurrency"
totalTime = 30
[[howto.steps]]
name = "Identify parallelizable operations"
text = "Find independent tool calls that can run concurrently."
[[howto.steps]]
name = "Configure concurrency limits"
text = "Set appropriate thread and connection limits."
[[howto.steps]]
name = "Implement parallel execution"
text = "Use thread pools or async for parallel processing."
[[howto.steps]]
name = "Add rate limiting"
text = "Prevent overwhelming external services."
[[howto.steps]]
name = "Handle concurrent errors"
text = "Manage failures in parallel operations."
+++


Sequential execution is slow.

5 API calls × 200ms each = 1 second.

Run them in parallel: 200ms total.

Concurrency multiplies throughput.

## Why concurrency matters

Sequential:
```
Tool 1 (200ms) → Tool 2 (200ms) → Tool 3 (200ms) →
Tool 4 (200ms) → Tool 5 (200ms)
Total: 1000ms
```

Concurrent:
```
Tool 1 (200ms) ─┐
Tool 2 (200ms) ─┤
Tool 3 (200ms) ─┼→ All complete
Tool 4 (200ms) ─┤
Tool 5 (200ms) ─┘
Total: 200ms (5x faster)
```

## Step 1: Basic concurrent execution

Using [Gantz](https://gantz.run):

```yaml
# gantz.yaml
name: concurrent-tools

concurrency:
  max_parallel: 10
  thread_pool_size: 20

  rate_limits:
    default:
      requests_per_second: 50
    api_calls:
      requests_per_second: 10

tools:
  - name: parallel_fetch
    description: Fetch multiple URLs in parallel
    concurrency:
      max_parallel: 5
    parameters:
      - name: urls
        type: array
        required: true
    script:
      command: python
      args: ["scripts/parallel_fetch.py"]
```

Concurrent executor implementation:

```python
import asyncio
import threading
from concurrent.futures import ThreadPoolExecutor, as_completed
from typing import List, Callable, TypeVar, Any, Dict
from dataclasses import dataclass

T = TypeVar('T')
R = TypeVar('R')

@dataclass
class ConcurrencyConfig:
    """Concurrency configuration."""
    max_workers: int = 10
    timeout: float = 30.0

class ThreadPoolExecutorWrapper:
    """Thread pool for concurrent execution."""

    def __init__(self, config: ConcurrencyConfig = None):
        self.config = config or ConcurrencyConfig()
        self.executor = ThreadPoolExecutor(max_workers=self.config.max_workers)

    def map_parallel(
        self,
        func: Callable[[T], R],
        items: List[T],
        timeout: float = None
    ) -> List[R]:
        """Execute function on items in parallel."""
        timeout = timeout or self.config.timeout
        futures = {
            self.executor.submit(func, item): i
            for i, item in enumerate(items)
        }

        results = [None] * len(items)

        for future in as_completed(futures, timeout=timeout):
            index = futures[future]
            try:
                results[index] = future.result()
            except Exception as e:
                results[index] = e

        return results

    def execute_parallel(
        self,
        tasks: List[Callable[[], R]],
        timeout: float = None
    ) -> List[R]:
        """Execute multiple callables in parallel."""
        timeout = timeout or self.config.timeout
        futures = {
            self.executor.submit(task): i
            for i, task in enumerate(tasks)
        }

        results = [None] * len(tasks)

        for future in as_completed(futures, timeout=timeout):
            index = futures[future]
            try:
                results[index] = future.result()
            except Exception as e:
                results[index] = e

        return results

    def shutdown(self):
        """Shutdown executor."""
        self.executor.shutdown(wait=True)

# Usage
executor = ThreadPoolExecutorWrapper(ConcurrencyConfig(max_workers=10))

def fetch_url(url: str) -> dict:
    response = requests.get(url)
    return {"url": url, "status": response.status_code}

urls = ["https://api1.com", "https://api2.com", "https://api3.com"]
results = executor.map_parallel(fetch_url, urls)
```

## Step 2: Async concurrent execution

Use asyncio for I/O-bound operations:

```python
import asyncio
import httpx
from typing import List, Callable, Awaitable, TypeVar

T = TypeVar('T')
R = TypeVar('R')

class AsyncConcurrentExecutor:
    """Async concurrent execution."""

    def __init__(
        self,
        max_concurrent: int = 10,
        timeout: float = 30.0
    ):
        self.semaphore = asyncio.Semaphore(max_concurrent)
        self.timeout = timeout

    async def execute_with_limit(
        self,
        coro: Awaitable[R]
    ) -> R:
        """Execute coroutine with concurrency limit."""
        async with self.semaphore:
            return await asyncio.wait_for(coro, timeout=self.timeout)

    async def gather_with_limit(
        self,
        coros: List[Awaitable[R]],
        return_exceptions: bool = True
    ) -> List[R]:
        """Gather coroutines with concurrency limit."""
        tasks = [
            self.execute_with_limit(coro)
            for coro in coros
        ]
        return await asyncio.gather(*tasks, return_exceptions=return_exceptions)

    async def map_async(
        self,
        func: Callable[[T], Awaitable[R]],
        items: List[T]
    ) -> List[R]:
        """Map async function over items concurrently."""
        coros = [func(item) for item in items]
        return await self.gather_with_limit(coros)

class AsyncHTTPFetcher:
    """Concurrent HTTP fetcher."""

    def __init__(
        self,
        max_concurrent: int = 10,
        timeout: float = 30.0
    ):
        self.executor = AsyncConcurrentExecutor(max_concurrent, timeout)
        self.client = httpx.AsyncClient()

    async def fetch_one(self, url: str) -> dict:
        """Fetch single URL."""
        response = await self.client.get(url)
        return {
            "url": url,
            "status": response.status_code,
            "data": response.json() if response.headers.get("content-type", "").startswith("application/json") else response.text
        }

    async def fetch_all(self, urls: List[str]) -> List[dict]:
        """Fetch all URLs concurrently."""
        return await self.executor.map_async(self.fetch_one, urls)

    async def close(self):
        await self.client.aclose()

# Usage
async def fetch_multiple_apis():
    fetcher = AsyncHTTPFetcher(max_concurrent=5)

    urls = [
        "https://api.example.com/users",
        "https://api.example.com/posts",
        "https://api.example.com/comments"
    ]

    results = await fetcher.fetch_all(urls)
    await fetcher.close()

    return results
```

## Step 3: Rate-limited concurrency

Prevent overwhelming external services:

```python
import asyncio
import time
from dataclasses import dataclass
from typing import Callable, Awaitable, TypeVar

T = TypeVar('T')

@dataclass
class RateLimitConfig:
    """Rate limit configuration."""
    requests_per_second: float = 10.0
    burst_size: int = 10

class TokenBucketRateLimiter:
    """Token bucket rate limiter."""

    def __init__(self, config: RateLimitConfig):
        self.config = config
        self.tokens = config.burst_size
        self.last_update = time.time()
        self.lock = asyncio.Lock()

    async def acquire(self):
        """Acquire a token, waiting if necessary."""
        async with self.lock:
            now = time.time()
            elapsed = now - self.last_update

            # Add tokens based on elapsed time
            self.tokens = min(
                self.config.burst_size,
                self.tokens + elapsed * self.config.requests_per_second
            )
            self.last_update = now

            if self.tokens >= 1:
                self.tokens -= 1
                return

            # Wait for next token
            wait_time = (1 - self.tokens) / self.config.requests_per_second
            await asyncio.sleep(wait_time)
            self.tokens = 0

class RateLimitedExecutor:
    """Execute with rate limiting."""

    def __init__(
        self,
        rate_limit: RateLimitConfig,
        max_concurrent: int = 10
    ):
        self.limiter = TokenBucketRateLimiter(rate_limit)
        self.semaphore = asyncio.Semaphore(max_concurrent)

    async def execute(
        self,
        coro: Awaitable[T]
    ) -> T:
        """Execute with rate limiting."""
        await self.limiter.acquire()
        async with self.semaphore:
            return await coro

    async def map_rate_limited(
        self,
        func: Callable[[T], Awaitable],
        items: list
    ) -> list:
        """Map with rate limiting."""
        async def rate_limited_call(item):
            await self.limiter.acquire()
            async with self.semaphore:
                return await func(item)

        tasks = [rate_limited_call(item) for item in items]
        return await asyncio.gather(*tasks)

# Usage
executor = RateLimitedExecutor(
    rate_limit=RateLimitConfig(requests_per_second=10, burst_size=5),
    max_concurrent=20
)

async def call_api(item: dict) -> dict:
    async with httpx.AsyncClient() as client:
        response = await client.post("https://api.example.com", json=item)
        return response.json()

results = await executor.map_rate_limited(call_api, items)
```

## Step 4: Concurrent tool executor

Execute MCP tools concurrently:

```python
from typing import Dict, List, Any, Optional
from dataclasses import dataclass
import asyncio

@dataclass
class ToolCall:
    """Single tool call."""
    tool_name: str
    params: Dict[str, Any]
    call_id: str = None

@dataclass
class ToolResult:
    """Tool execution result."""
    call_id: str
    tool_name: str
    success: bool
    result: Any = None
    error: str = None

class ConcurrentToolExecutor:
    """Execute multiple tools concurrently."""

    def __init__(
        self,
        tool_registry: Dict[str, Callable],
        max_concurrent: int = 10,
        timeout: float = 30.0
    ):
        self.tools = tool_registry
        self.max_concurrent = max_concurrent
        self.timeout = timeout
        self.semaphore = asyncio.Semaphore(max_concurrent)

    async def execute_single(self, call: ToolCall) -> ToolResult:
        """Execute single tool call."""
        if call.tool_name not in self.tools:
            return ToolResult(
                call_id=call.call_id,
                tool_name=call.tool_name,
                success=False,
                error=f"Tool not found: {call.tool_name}"
            )

        try:
            async with self.semaphore:
                tool = self.tools[call.tool_name]

                # Handle both sync and async tools
                if asyncio.iscoroutinefunction(tool):
                    result = await asyncio.wait_for(
                        tool(**call.params),
                        timeout=self.timeout
                    )
                else:
                    result = await asyncio.wait_for(
                        asyncio.to_thread(tool, **call.params),
                        timeout=self.timeout
                    )

                return ToolResult(
                    call_id=call.call_id,
                    tool_name=call.tool_name,
                    success=True,
                    result=result
                )
        except asyncio.TimeoutError:
            return ToolResult(
                call_id=call.call_id,
                tool_name=call.tool_name,
                success=False,
                error="Tool execution timed out"
            )
        except Exception as e:
            return ToolResult(
                call_id=call.call_id,
                tool_name=call.tool_name,
                success=False,
                error=str(e)
            )

    async def execute_batch(
        self,
        calls: List[ToolCall]
    ) -> List[ToolResult]:
        """Execute multiple tool calls concurrently."""
        tasks = [self.execute_single(call) for call in calls]
        return await asyncio.gather(*tasks)

    async def execute_with_dependencies(
        self,
        calls: List[ToolCall],
        dependencies: Dict[str, List[str]]  # call_id -> [dependent_call_ids]
    ) -> List[ToolResult]:
        """Execute with dependency ordering."""
        results = {}
        pending = set(c.call_id for c in calls)
        call_map = {c.call_id: c for c in calls}

        while pending:
            # Find calls with no pending dependencies
            ready = []
            for call_id in pending:
                deps = dependencies.get(call_id, [])
                if all(d in results for d in deps):
                    ready.append(call_id)

            if not ready:
                raise RuntimeError("Circular dependency detected")

            # Execute ready calls
            ready_calls = [call_map[cid] for cid in ready]
            batch_results = await self.execute_batch(ready_calls)

            # Store results
            for result in batch_results:
                results[result.call_id] = result
                pending.remove(result.call_id)

        return list(results.values())

# Usage
tools = {
    "fetch_user": lambda user_id: {"id": user_id, "name": "User"},
    "fetch_posts": lambda user_id: [{"id": 1, "title": "Post"}],
    "analyze": lambda data: {"analysis": "done"}
}

executor = ConcurrentToolExecutor(tools, max_concurrent=5)

calls = [
    ToolCall(tool_name="fetch_user", params={"user_id": 1}, call_id="1"),
    ToolCall(tool_name="fetch_posts", params={"user_id": 1}, call_id="2"),
    ToolCall(tool_name="fetch_user", params={"user_id": 2}, call_id="3"),
]

results = await executor.execute_batch(calls)
```

## Step 5: Parallel database operations

Concurrent database queries:

```python
import asyncio
from typing import List, Dict, Any
import asyncpg

class ConcurrentDatabaseExecutor:
    """Execute database queries concurrently."""

    def __init__(
        self,
        pool: asyncpg.Pool,
        max_concurrent: int = 20
    ):
        self.pool = pool
        self.semaphore = asyncio.Semaphore(max_concurrent)

    async def execute_query(
        self,
        query: str,
        params: tuple = None
    ) -> List[Dict[str, Any]]:
        """Execute single query."""
        async with self.semaphore:
            async with self.pool.acquire() as conn:
                rows = await conn.fetch(query, *(params or ()))
                return [dict(row) for row in rows]

    async def execute_many(
        self,
        queries: List[tuple]  # [(query, params), ...]
    ) -> List[List[Dict[str, Any]]]:
        """Execute multiple queries concurrently."""
        tasks = [
            self.execute_query(query, params)
            for query, params in queries
        ]
        return await asyncio.gather(*tasks)

    async def fetch_related(
        self,
        entity_type: str,
        entity_ids: List[int],
        relations: List[str]
    ) -> Dict[int, Dict[str, Any]]:
        """Fetch entity and relations concurrently."""
        # Build queries for each relation
        queries = []

        # Main entity query
        queries.append((
            f"SELECT * FROM {entity_type} WHERE id = ANY($1)",
            (entity_ids,)
        ))

        # Relation queries
        for relation in relations:
            queries.append((
                f"SELECT * FROM {relation} WHERE {entity_type}_id = ANY($1)",
                (entity_ids,)
            ))

        # Execute all concurrently
        results = await self.execute_many(queries)

        # Combine results
        entities = {e["id"]: e for e in results[0]}

        for i, relation in enumerate(relations):
            relation_data = results[i + 1]
            for entity_id in entities:
                entities[entity_id][relation] = [
                    r for r in relation_data
                    if r[f"{entity_type}_id"] == entity_id
                ]

        return entities

# Usage
async def main():
    pool = await asyncpg.create_pool(dsn="postgresql://...")
    executor = ConcurrentDatabaseExecutor(pool, max_concurrent=10)

    # Fetch users with their posts and comments concurrently
    users = await executor.fetch_related(
        entity_type="users",
        entity_ids=[1, 2, 3],
        relations=["posts", "comments"]
    )
```

## Step 6: Monitoring concurrent operations

Track concurrency metrics:

```python
from prometheus_client import Gauge, Counter, Histogram
import asyncio
import time

concurrent_operations = Gauge(
    'concurrent_operations',
    'Current concurrent operations',
    ['operation_type']
)

operation_duration = Histogram(
    'operation_duration_seconds',
    'Operation duration',
    ['operation_type'],
    buckets=[0.01, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10]
)

operation_errors = Counter(
    'operation_errors_total',
    'Total operation errors',
    ['operation_type']
)

class MonitoredConcurrentExecutor:
    """Concurrent executor with monitoring."""

    def __init__(
        self,
        operation_type: str,
        max_concurrent: int = 10
    ):
        self.operation_type = operation_type
        self.semaphore = asyncio.Semaphore(max_concurrent)

    async def execute(self, coro) -> Any:
        """Execute with monitoring."""
        concurrent_operations.labels(
            operation_type=self.operation_type
        ).inc()

        start = time.time()

        try:
            async with self.semaphore:
                result = await coro
                return result
        except Exception as e:
            operation_errors.labels(
                operation_type=self.operation_type
            ).inc()
            raise
        finally:
            duration = time.time() - start

            concurrent_operations.labels(
                operation_type=self.operation_type
            ).dec()

            operation_duration.labels(
                operation_type=self.operation_type
            ).observe(duration)

# Usage
executor = MonitoredConcurrentExecutor("api_calls", max_concurrent=10)

async def monitored_fetch():
    async with httpx.AsyncClient() as client:
        return await executor.execute(
            client.get("https://api.example.com/data")
        )
```

## Summary

MCP concurrency patterns:

1. **Thread pools** - Parallel sync execution
2. **Async execution** - I/O-bound concurrency
3. **Rate limiting** - Prevent overload
4. **Tool execution** - Concurrent MCP tools
5. **Database operations** - Parallel queries
6. **Monitoring** - Track concurrency metrics

Build tools with [Gantz](https://gantz.run), parallelize for speed.

Concurrent beats sequential.

## Related reading

- [MCP Connection Pooling](/post/mcp-connection-pooling/) - Pool connections
- [MCP Batching](/post/mcp-batching/) - Batch concurrent requests
- [MCP Performance](/post/mcp-performance/) - Optimize throughput

---

*How do you handle concurrency? Share your patterns.*
