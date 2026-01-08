+++
title = "MCP Timeout Configuration: Prevent Hanging Operations"
image = "images/mcp-timeout-configuration.webp"
date = 2025-10-31
description = "Configure timeouts for MCP tools and AI agents. Connection, read, and operation timeouts for responsive and reliable systems."
summary = "Prevent indefinite hangs in your MCP tools by configuring connection, read, write, and total operation timeouts appropriately. This guide covers HTTP client and database timeout configuration, cascading timeout budgets for nested operations, timeout-aware MCP tool execution, and monitoring timeout metrics to optimize values over time."
draft = false
tags = ['mcp', 'reliability', 'timeouts']
voice = false

[howto]
name = "Configure MCP Timeouts"
totalTime = 25
[[howto.steps]]
name = "Identify timeout points"
text = "Find where timeouts are needed in your system."
[[howto.steps]]
name = "Set appropriate values"
text = "Configure timeouts based on operation types."
[[howto.steps]]
name = "Implement timeout handling"
text = "Handle timeout errors gracefully."
[[howto.steps]]
name = "Add cascading timeouts"
text = "Ensure child operations respect parent timeouts."
[[howto.steps]]
name = "Monitor timeout metrics"
text = "Track timeout rates and adjust values."
+++


Operations that never complete are worse than failures.

At least failures give you an error.

Timeouts prevent indefinite hangs.

## Why timeouts matter

Without timeouts:
```
User request → Tool call → API hangs forever →
Thread blocked → Resources exhausted → System unresponsive
```

With timeouts:
```
User request → Tool call → API hangs →
Timeout triggers (5s) → Error returned → User informed →
Resources freed → System continues
```

## Timeout types

| Type | Purpose | Typical Value |
|------|---------|---------------|
| Connection | Establish connection | 5-10s |
| Read | Receive response | 30-60s |
| Write | Send request | 10-30s |
| Total | Entire operation | 60-120s |
| Idle | Keep-alive | 60-300s |

## Step 1: Basic timeout configuration

Using [Gantz](https://gantz.run):

```yaml
# gantz.yaml
name: timeout-tools

timeouts:
  default:
    connect: 5
    read: 30
    write: 10
    total: 60

  llm_calls:
    connect: 10
    read: 120
    total: 180

  database:
    connect: 5
    read: 30
    total: 45

tools:
  - name: call_api
    description: Call external API
    timeout: 30
    parameters:
      - name: url
        type: string
        required: true
    script:
      shell: curl --connect-timeout 5 --max-time 30 "{{url}}"

  - name: long_analysis
    description: Long-running analysis
    timeout: 300
    parameters:
      - name: data
        type: string
        required: true
    script:
      command: python
      args: ["scripts/analyze.py"]
```

Timeout implementation:

```python
import signal
import threading
from typing import Callable, TypeVar, Optional, Any
from dataclasses import dataclass
from contextlib import contextmanager
import time

T = TypeVar('T')

@dataclass
class TimeoutConfig:
    """Configuration for timeouts."""
    connect: float = 5.0
    read: float = 30.0
    write: float = 10.0
    total: float = 60.0
    idle: float = 300.0

class TimeoutError(Exception):
    """Raised when operation times out."""
    pass

class TimeoutManager:
    """Manage timeouts for operations."""

    def __init__(self, config: TimeoutConfig = None):
        self.config = config or TimeoutConfig()

    @contextmanager
    def timeout(self, seconds: float, message: str = "Operation timed out"):
        """Context manager for timeout."""
        def handler(signum, frame):
            raise TimeoutError(message)

        # Set alarm
        old_handler = signal.signal(signal.SIGALRM, handler)
        signal.setitimer(signal.ITIMER_REAL, seconds)

        try:
            yield
        finally:
            signal.setitimer(signal.ITIMER_REAL, 0)
            signal.signal(signal.SIGALRM, old_handler)

    def execute_with_timeout(
        self,
        func: Callable[[], T],
        timeout: float = None,
        timeout_type: str = "total"
    ) -> T:
        """Execute function with timeout."""
        timeout = timeout or getattr(self.config, timeout_type)

        with self.timeout(timeout, f"{timeout_type} timeout exceeded"):
            return func()

class ThreadedTimeoutManager:
    """Thread-safe timeout manager."""

    def execute_with_timeout(
        self,
        func: Callable[[], T],
        timeout: float,
        default: T = None
    ) -> tuple:
        """Execute with timeout in separate thread."""
        result = [None]
        exception = [None]
        completed = threading.Event()

        def worker():
            try:
                result[0] = func()
            except Exception as e:
                exception[0] = e
            finally:
                completed.set()

        thread = threading.Thread(target=worker)
        thread.daemon = True
        thread.start()

        if completed.wait(timeout):
            if exception[0]:
                raise exception[0]
            return result[0], True
        else:
            return default, False

# Usage
timeout_mgr = TimeoutManager(TimeoutConfig(total=30))

try:
    result = timeout_mgr.execute_with_timeout(
        lambda: slow_operation(),
        timeout=10
    )
except TimeoutError:
    print("Operation timed out")
```

## Step 2: HTTP client timeouts

Configure HTTP timeouts:

```python
import httpx
import requests
from typing import Optional

class TimeoutHTTPClient:
    """HTTP client with comprehensive timeouts."""

    def __init__(self, config: TimeoutConfig = None):
        self.config = config or TimeoutConfig()

        # httpx timeout configuration
        self.timeout = httpx.Timeout(
            connect=self.config.connect,
            read=self.config.read,
            write=self.config.write,
            pool=self.config.idle
        )

        self.client = httpx.Client(timeout=self.timeout)

    def get(self, url: str, **kwargs) -> httpx.Response:
        """GET with configured timeouts."""
        return self.client.get(url, **kwargs)

    def post(self, url: str, **kwargs) -> httpx.Response:
        """POST with configured timeouts."""
        return self.client.post(url, **kwargs)

    def request_with_custom_timeout(
        self,
        method: str,
        url: str,
        timeout: float = None,
        **kwargs
    ) -> httpx.Response:
        """Request with custom timeout override."""
        if timeout:
            kwargs['timeout'] = timeout
        return self.client.request(method, url, **kwargs)

class AsyncTimeoutHTTPClient:
    """Async HTTP client with timeouts."""

    def __init__(self, config: TimeoutConfig = None):
        self.config = config or TimeoutConfig()

        self.timeout = httpx.Timeout(
            connect=self.config.connect,
            read=self.config.read,
            write=self.config.write
        )

        self.client = httpx.AsyncClient(timeout=self.timeout)

    async def get(self, url: str, **kwargs) -> httpx.Response:
        return await self.client.get(url, **kwargs)

    async def post(self, url: str, **kwargs) -> httpx.Response:
        return await self.client.post(url, **kwargs)

    async def close(self):
        await self.client.aclose()

# Usage
http_client = TimeoutHTTPClient(TimeoutConfig(
    connect=5,
    read=30,
    total=60
))

try:
    response = http_client.get("https://api.example.com/data")
except httpx.TimeoutException as e:
    print(f"Request timed out: {e}")
```

## Step 3: Database timeouts

Configure database connection and query timeouts:

```python
import psycopg2
from psycopg2 import extensions
import sqlite3
from typing import Optional, List, Any

class TimeoutDatabaseClient:
    """Database client with timeout support."""

    def __init__(
        self,
        dsn: str,
        connect_timeout: int = 5,
        query_timeout: int = 30
    ):
        self.dsn = dsn
        self.connect_timeout = connect_timeout
        self.query_timeout = query_timeout

    def connect(self):
        """Connect with timeout."""
        return psycopg2.connect(
            self.dsn,
            connect_timeout=self.connect_timeout,
            options=f"-c statement_timeout={self.query_timeout * 1000}"
        )

    def execute(
        self,
        query: str,
        params: tuple = None,
        timeout: int = None
    ) -> List[Any]:
        """Execute query with timeout."""
        timeout = timeout or self.query_timeout

        conn = self.connect()
        try:
            with conn.cursor() as cur:
                # Set statement timeout for this query
                cur.execute(f"SET statement_timeout = {timeout * 1000}")
                cur.execute(query, params)

                if cur.description:
                    return cur.fetchall()
                return []
        finally:
            conn.close()

class SQLiteTimeoutClient:
    """SQLite with timeout support."""

    def __init__(self, db_path: str, timeout: float = 30.0):
        self.db_path = db_path
        self.timeout = timeout

    def execute(self, query: str, params: tuple = None) -> List[Any]:
        """Execute with timeout."""
        conn = sqlite3.connect(
            self.db_path,
            timeout=self.timeout
        )
        try:
            cursor = conn.execute(query, params or ())
            return cursor.fetchall()
        finally:
            conn.close()
```

## Step 4: Cascading timeouts

Ensure child operations respect parent timeouts:

```python
import time
from contextlib import contextmanager
from typing import Optional

class TimeoutBudget:
    """Track remaining time budget for nested operations."""

    def __init__(self, total_timeout: float):
        self.total_timeout = total_timeout
        self.start_time = time.time()

    @property
    def remaining(self) -> float:
        """Get remaining time."""
        elapsed = time.time() - self.start_time
        return max(0, self.total_timeout - elapsed)

    @property
    def is_expired(self) -> bool:
        """Check if budget is expired."""
        return self.remaining <= 0

    def check(self):
        """Raise if budget expired."""
        if self.is_expired:
            raise TimeoutError("Time budget expired")

    def get_timeout_for(self, operation: str, default: float) -> float:
        """Get timeout for operation within budget."""
        return min(default, self.remaining)

class CascadingTimeoutManager:
    """Manage cascading timeouts across operations."""

    _current_budget = threading.local()

    @classmethod
    @contextmanager
    def budget(cls, timeout: float):
        """Create a time budget context."""
        parent_budget = getattr(cls._current_budget, 'value', None)

        if parent_budget:
            # Inherit from parent, use minimum
            effective_timeout = min(timeout, parent_budget.remaining)
        else:
            effective_timeout = timeout

        budget = TimeoutBudget(effective_timeout)
        cls._current_budget.value = budget

        try:
            yield budget
        finally:
            cls._current_budget.value = parent_budget

    @classmethod
    def get_current_budget(cls) -> Optional[TimeoutBudget]:
        """Get current time budget."""
        return getattr(cls._current_budget, 'value', None)

    @classmethod
    def get_timeout(cls, default: float) -> float:
        """Get timeout respecting current budget."""
        budget = cls.get_current_budget()
        if budget:
            return budget.get_timeout_for("operation", default)
        return default

# Usage
def parent_operation():
    with CascadingTimeoutManager.budget(60) as budget:
        # Child operations inherit the budget
        result1 = child_operation_1()
        budget.check()  # Check if still have time

        result2 = child_operation_2()
        budget.check()

        return combine(result1, result2)

def child_operation_1():
    # Get timeout respecting parent budget
    timeout = CascadingTimeoutManager.get_timeout(30)
    return call_api_with_timeout(timeout)

def child_operation_2():
    timeout = CascadingTimeoutManager.get_timeout(20)
    return query_database_with_timeout(timeout)
```

## Step 5: MCP tool timeouts

Apply timeouts to MCP tools:

```python
class TimeoutTool:
    """MCP tool with timeout support."""

    def __init__(
        self,
        name: str,
        executor: Callable,
        timeout: float = 30.0,
        timeout_message: str = None
    ):
        self.name = name
        self.executor = executor
        self.timeout = timeout
        self.timeout_message = timeout_message or f"Tool {name} timed out"

        self.timeout_manager = ThreadedTimeoutManager()

    def execute(self, params: dict) -> dict:
        """Execute tool with timeout."""
        result, completed = self.timeout_manager.execute_with_timeout(
            lambda: self.executor(params),
            self.timeout
        )

        if not completed:
            return {
                "success": False,
                "error": self.timeout_message,
                "timeout": True
            }

        return {"success": True, "result": result}

class TimeoutToolRegistry:
    """Registry for tools with timeout support."""

    def __init__(self, default_timeout: float = 30.0):
        self.default_timeout = default_timeout
        self.tools: Dict[str, TimeoutTool] = {}

    def register(
        self,
        name: str,
        executor: Callable,
        timeout: float = None
    ):
        """Register tool with timeout."""
        self.tools[name] = TimeoutTool(
            name=name,
            executor=executor,
            timeout=timeout or self.default_timeout
        )

    def execute(self, name: str, params: dict) -> dict:
        """Execute tool with timeout."""
        if name not in self.tools:
            return {"success": False, "error": f"Tool not found: {name}"}

        return self.tools[name].execute(params)

# LLM call with timeout
class TimeoutLLMClient:
    """LLM client with timeout support."""

    def __init__(self, timeout: float = 120.0):
        self.timeout = timeout
        self.client = anthropic.Anthropic()

    def create_message(self, **kwargs) -> Any:
        """Create message with timeout."""
        import signal

        def handler(signum, frame):
            raise TimeoutError("LLM call timed out")

        signal.signal(signal.SIGALRM, handler)
        signal.alarm(int(self.timeout))

        try:
            return self.client.messages.create(**kwargs)
        finally:
            signal.alarm(0)
```

## Step 6: Timeout monitoring

Track timeout metrics:

```python
from prometheus_client import Counter, Histogram
from dataclasses import dataclass
from typing import Dict

timeout_counter = Counter(
    'operation_timeouts_total',
    'Total timeout occurrences',
    ['operation', 'timeout_type']
)

operation_duration = Histogram(
    'operation_duration_seconds',
    'Operation duration',
    ['operation'],
    buckets=[0.1, 0.5, 1, 2, 5, 10, 30, 60, 120]
)

@dataclass
class TimeoutStats:
    """Statistics for timeout tracking."""
    total_operations: int = 0
    timeouts: int = 0
    total_duration: float = 0.0

class TimeoutMonitor:
    """Monitor timeout occurrences."""

    def __init__(self):
        self.stats: Dict[str, TimeoutStats] = {}

    def record_success(self, operation: str, duration: float):
        """Record successful operation."""
        if operation not in self.stats:
            self.stats[operation] = TimeoutStats()

        self.stats[operation].total_operations += 1
        self.stats[operation].total_duration += duration

        operation_duration.labels(operation=operation).observe(duration)

    def record_timeout(self, operation: str, timeout_type: str):
        """Record timeout occurrence."""
        if operation not in self.stats:
            self.stats[operation] = TimeoutStats()

        self.stats[operation].total_operations += 1
        self.stats[operation].timeouts += 1

        timeout_counter.labels(
            operation=operation,
            timeout_type=timeout_type
        ).inc()

    def get_timeout_rate(self, operation: str) -> float:
        """Get timeout rate for operation."""
        if operation not in self.stats:
            return 0.0

        stats = self.stats[operation]
        if stats.total_operations == 0:
            return 0.0

        return stats.timeouts / stats.total_operations

    def suggest_timeout(self, operation: str, percentile: float = 0.95) -> float:
        """Suggest timeout based on observed durations."""
        # In practice, use histogram data
        stats = self.stats.get(operation)
        if not stats or stats.total_operations == 0:
            return 30.0  # Default

        avg_duration = stats.total_duration / stats.total_operations
        # Add buffer for variance
        return avg_duration * 2

# Usage
monitor = TimeoutMonitor()

def monitored_operation(name: str, func: Callable, timeout: float) -> Any:
    """Execute operation with monitoring."""
    start = time.time()

    try:
        result = execute_with_timeout(func, timeout)
        monitor.record_success(name, time.time() - start)
        return result
    except TimeoutError:
        monitor.record_timeout(name, "total")
        raise
```

## Summary

MCP timeout configuration:

1. **Basic timeouts** - Connect, read, write, total
2. **HTTP timeouts** - Client-level configuration
3. **Database timeouts** - Query and connection limits
4. **Cascading timeouts** - Budget-aware child operations
5. **Tool timeouts** - MCP tool integration
6. **Monitoring** - Track and optimize

Build tools with [Gantz](https://gantz.run), timeout wisely.

Hanging is worse than failing.

## Related reading

- [MCP Circuit Breakers](/post/mcp-circuit-breakers/) - Fail fast
- [MCP Retry Strategies](/post/mcp-retry-strategies/) - Retry after timeout
- [Agent Error Handling](/post/agent-error-handling/) - Handle timeouts

---

*How do you configure timeouts? Share your strategies.*
