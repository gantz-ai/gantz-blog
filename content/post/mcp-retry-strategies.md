+++
title = "MCP Retry Strategies: Handle Transient Failures"
image = "images/mcp-retry-strategies.webp"
date = 2025-11-01
description = "Implement retry strategies for MCP tools. Exponential backoff, jitter, and smart retries for reliable AI agent operations."
draft = false
tags = ['mcp', 'reliability', 'retries']
voice = false
summary = "Build robust retry logic for MCP tools using exponential backoff, decorrelated jitter, and adaptive strategies that adjust based on error types. This guide covers implementing retry budgets to limit system-wide retry load, async retry patterns, and integrating retries into your MCP tool registry for reliable AI agent operations."

[howto]
name = "Implement Retry Strategies"
totalTime = 25
[[howto.steps]]
name = "Identify retryable errors"
text = "Distinguish transient from permanent failures."
[[howto.steps]]
name = "Choose retry algorithm"
text = "Select exponential backoff, linear, or custom."
[[howto.steps]]
name = "Add jitter"
text = "Prevent thundering herd with randomization."
[[howto.steps]]
name = "Set limits"
text = "Configure max retries and timeouts."
[[howto.steps]]
name = "Implement retry budgets"
text = "Limit total retry load on system."
+++


Networks fail. APIs timeout. Databases hiccup.

Not every failure is permanent.

Retries turn temporary failures into success.

## What to retry

| Error Type | Retry? | Example |
|------------|--------|---------|
| Network timeout | Yes | Connection reset |
| Rate limit (429) | Yes | Wait and retry |
| Server error (5xx) | Yes | Temporary overload |
| Bad request (400) | No | Fix the request |
| Auth error (401/403) | No | Fix credentials |
| Not found (404) | No | Resource doesn't exist |

## Step 1: Basic retry logic

Using [Gantz](https://gantz.run):

```yaml
# gantz.yaml
name: retry-tools

retry:
  default:
    max_attempts: 3
    initial_delay: 1
    max_delay: 30
    exponential_base: 2

tools:
  - name: call_api
    description: Call API with retries
    retry:
      max_attempts: 5
      retryable_errors: [429, 500, 502, 503, 504]
    parameters:
      - name: endpoint
        type: string
        required: true
    script:
      shell: curl -f "{{endpoint}}"
```

Retry implementation:

```python
import time
import random
from typing import Callable, TypeVar, List, Type, Optional
from functools import wraps
from dataclasses import dataclass

T = TypeVar('T')

@dataclass
class RetryConfig:
    """Configuration for retry behavior."""
    max_attempts: int = 3
    initial_delay: float = 1.0
    max_delay: float = 60.0
    exponential_base: float = 2.0
    jitter: bool = True
    jitter_factor: float = 0.25
    retryable_exceptions: List[Type[Exception]] = None
    retryable_status_codes: List[int] = None

    def __post_init__(self):
        if self.retryable_exceptions is None:
            self.retryable_exceptions = [
                ConnectionError,
                TimeoutError,
                IOError
            ]
        if self.retryable_status_codes is None:
            self.retryable_status_codes = [429, 500, 502, 503, 504]

class RetryError(Exception):
    """Raised when all retries exhausted."""
    def __init__(self, message: str, last_exception: Exception):
        super().__init__(message)
        self.last_exception = last_exception

class Retryer:
    """Execute functions with retry logic."""

    def __init__(self, config: RetryConfig = None):
        self.config = config or RetryConfig()

    def execute(self, func: Callable[[], T]) -> T:
        """Execute function with retries."""
        last_exception = None

        for attempt in range(self.config.max_attempts):
            try:
                return func()
            except Exception as e:
                last_exception = e

                if not self._should_retry(e, attempt):
                    raise

                delay = self._calculate_delay(attempt)
                print(f"Attempt {attempt + 1} failed: {e}. Retrying in {delay:.2f}s")
                time.sleep(delay)

        raise RetryError(
            f"Failed after {self.config.max_attempts} attempts",
            last_exception
        )

    def _should_retry(self, exception: Exception, attempt: int) -> bool:
        """Determine if we should retry."""
        if attempt >= self.config.max_attempts - 1:
            return False

        # Check exception type
        for exc_type in self.config.retryable_exceptions:
            if isinstance(exception, exc_type):
                return True

        # Check HTTP status code
        if hasattr(exception, 'response'):
            status = getattr(exception.response, 'status_code', None)
            if status in self.config.retryable_status_codes:
                return True

        return False

    def _calculate_delay(self, attempt: int) -> float:
        """Calculate delay with exponential backoff and jitter."""
        # Exponential backoff
        delay = self.config.initial_delay * (
            self.config.exponential_base ** attempt
        )

        # Cap at max delay
        delay = min(delay, self.config.max_delay)

        # Add jitter
        if self.config.jitter:
            jitter_range = delay * self.config.jitter_factor
            delay += random.uniform(-jitter_range, jitter_range)

        return max(0, delay)

def with_retry(config: RetryConfig = None):
    """Decorator for adding retry logic."""
    retryer = Retryer(config)

    def decorator(func: Callable) -> Callable:
        @wraps(func)
        def wrapper(*args, **kwargs):
            return retryer.execute(lambda: func(*args, **kwargs))
        return wrapper

    return decorator

# Usage
@with_retry(RetryConfig(max_attempts=5, initial_delay=2))
def call_external_api(url: str) -> dict:
    import requests
    response = requests.get(url, timeout=10)
    response.raise_for_status()
    return response.json()
```

## Step 2: Advanced backoff strategies

Different algorithms for different scenarios:

```python
from abc import ABC, abstractmethod
from typing import Optional

class BackoffStrategy(ABC):
    """Base class for backoff strategies."""

    @abstractmethod
    def get_delay(self, attempt: int, last_delay: float = None) -> float:
        pass

class ExponentialBackoff(BackoffStrategy):
    """Exponential backoff with optional jitter."""

    def __init__(
        self,
        initial: float = 1.0,
        maximum: float = 60.0,
        base: float = 2.0,
        jitter: bool = True
    ):
        self.initial = initial
        self.maximum = maximum
        self.base = base
        self.jitter = jitter

    def get_delay(self, attempt: int, last_delay: float = None) -> float:
        delay = self.initial * (self.base ** attempt)
        delay = min(delay, self.maximum)

        if self.jitter:
            delay = random.uniform(0, delay)

        return delay

class LinearBackoff(BackoffStrategy):
    """Linear backoff."""

    def __init__(self, increment: float = 1.0, maximum: float = 30.0):
        self.increment = increment
        self.maximum = maximum

    def get_delay(self, attempt: int, last_delay: float = None) -> float:
        return min(self.increment * (attempt + 1), self.maximum)

class ConstantBackoff(BackoffStrategy):
    """Constant delay between retries."""

    def __init__(self, delay: float = 1.0):
        self.delay = delay

    def get_delay(self, attempt: int, last_delay: float = None) -> float:
        return self.delay

class DecorrelatedJitterBackoff(BackoffStrategy):
    """AWS-style decorrelated jitter backoff."""

    def __init__(self, base: float = 1.0, maximum: float = 60.0):
        self.base = base
        self.maximum = maximum

    def get_delay(self, attempt: int, last_delay: float = None) -> float:
        if last_delay is None:
            last_delay = self.base

        delay = random.uniform(self.base, last_delay * 3)
        return min(delay, self.maximum)

class FibonacciBackoff(BackoffStrategy):
    """Fibonacci sequence backoff."""

    def __init__(self, maximum: float = 60.0):
        self.maximum = maximum
        self._cache = {0: 1, 1: 1}

    def _fib(self, n: int) -> int:
        if n not in self._cache:
            self._cache[n] = self._fib(n - 1) + self._fib(n - 2)
        return self._cache[n]

    def get_delay(self, attempt: int, last_delay: float = None) -> float:
        return min(float(self._fib(attempt)), self.maximum)

# Smart strategy selector
class AdaptiveBackoff(BackoffStrategy):
    """Adapt strategy based on error type."""

    def __init__(self):
        self.strategies = {
            "rate_limit": ExponentialBackoff(initial=5, maximum=120),
            "timeout": LinearBackoff(increment=2, maximum=30),
            "server_error": ExponentialBackoff(initial=1, maximum=60),
            "default": ExponentialBackoff()
        }
        self.current_strategy = "default"

    def set_error_type(self, error_type: str):
        self.current_strategy = error_type if error_type in self.strategies else "default"

    def get_delay(self, attempt: int, last_delay: float = None) -> float:
        strategy = self.strategies[self.current_strategy]
        return strategy.get_delay(attempt, last_delay)

# Usage
class SmartRetryer(Retryer):
    """Retryer with adaptive backoff."""

    def __init__(self, config: RetryConfig = None):
        super().__init__(config)
        self.backoff = AdaptiveBackoff()

    def _calculate_delay(self, attempt: int) -> float:
        return self.backoff.get_delay(attempt)

    def _should_retry(self, exception: Exception, attempt: int) -> bool:
        if not super()._should_retry(exception, attempt):
            return False

        # Adapt backoff based on error
        if hasattr(exception, 'response'):
            status = getattr(exception.response, 'status_code', None)
            if status == 429:
                self.backoff.set_error_type("rate_limit")
            elif status >= 500:
                self.backoff.set_error_type("server_error")
        elif isinstance(exception, TimeoutError):
            self.backoff.set_error_type("timeout")

        return True
```

## Step 3: Retry budgets

Limit system-wide retry load:

```python
import threading
from typing import Dict
from dataclasses import dataclass

@dataclass
class RetryBudget:
    """Budget for retry attempts."""
    max_retries_per_second: float = 10.0
    max_retry_ratio: float = 0.1  # Max 10% of requests can be retries
    window_seconds: int = 60

class RetryBudgetManager:
    """Manage retry budgets across the system."""

    def __init__(self, budget: RetryBudget):
        self.budget = budget
        self.retry_counts: Dict[float, int] = {}
        self.request_counts: Dict[float, int] = {}
        self._lock = threading.Lock()

    def _get_window_key(self) -> float:
        """Get current time window key."""
        return int(time.time() / self.budget.window_seconds)

    def _cleanup_old_windows(self):
        """Remove expired window data."""
        current = self._get_window_key()
        old_keys = [
            k for k in self.retry_counts.keys()
            if k < current - 1
        ]
        for k in old_keys:
            del self.retry_counts[k]
            if k in self.request_counts:
                del self.request_counts[k]

    def record_request(self):
        """Record a request."""
        with self._lock:
            key = self._get_window_key()
            self.request_counts[key] = self.request_counts.get(key, 0) + 1

    def can_retry(self) -> bool:
        """Check if retry budget allows another retry."""
        with self._lock:
            self._cleanup_old_windows()
            key = self._get_window_key()

            retries = self.retry_counts.get(key, 0)
            requests = self.request_counts.get(key, 1)

            # Check retry rate limit
            elapsed = time.time() % self.budget.window_seconds
            max_retries = self.budget.max_retries_per_second * elapsed

            if retries >= max_retries:
                return False

            # Check retry ratio
            if requests > 0:
                ratio = retries / requests
                if ratio >= self.budget.max_retry_ratio:
                    return False

            return True

    def record_retry(self):
        """Record a retry attempt."""
        with self._lock:
            key = self._get_window_key()
            self.retry_counts[key] = self.retry_counts.get(key, 0) + 1

    def get_stats(self) -> dict:
        """Get budget statistics."""
        with self._lock:
            key = self._get_window_key()
            return {
                "current_retries": self.retry_counts.get(key, 0),
                "current_requests": self.request_counts.get(key, 0),
                "retry_ratio": (
                    self.retry_counts.get(key, 0) /
                    max(self.request_counts.get(key, 1), 1)
                )
            }

class BudgetedRetryer(Retryer):
    """Retryer with budget limits."""

    def __init__(
        self,
        config: RetryConfig = None,
        budget_manager: RetryBudgetManager = None
    ):
        super().__init__(config)
        self.budget = budget_manager or RetryBudgetManager(RetryBudget())

    def execute(self, func: Callable[[], T]) -> T:
        self.budget.record_request()
        return super().execute(func)

    def _should_retry(self, exception: Exception, attempt: int) -> bool:
        if not super()._should_retry(exception, attempt):
            return False

        # Check budget
        if not self.budget.can_retry():
            print("Retry budget exhausted")
            return False

        self.budget.record_retry()
        return True
```

## Step 4: Async retries

For async operations:

```python
import asyncio
from typing import Callable, Awaitable

class AsyncRetryer:
    """Async retry logic."""

    def __init__(self, config: RetryConfig = None):
        self.config = config or RetryConfig()
        self.backoff = ExponentialBackoff()

    async def execute(self, func: Callable[[], Awaitable[T]]) -> T:
        """Execute async function with retries."""
        last_exception = None

        for attempt in range(self.config.max_attempts):
            try:
                return await func()
            except Exception as e:
                last_exception = e

                if not self._should_retry(e, attempt):
                    raise

                delay = self.backoff.get_delay(attempt)
                await asyncio.sleep(delay)

        raise RetryError(
            f"Failed after {self.config.max_attempts} attempts",
            last_exception
        )

    def _should_retry(self, exception: Exception, attempt: int) -> bool:
        if attempt >= self.config.max_attempts - 1:
            return False

        for exc_type in self.config.retryable_exceptions:
            if isinstance(exception, exc_type):
                return True

        return False

def async_retry(config: RetryConfig = None):
    """Decorator for async retry."""
    retryer = AsyncRetryer(config)

    def decorator(func: Callable) -> Callable:
        @wraps(func)
        async def wrapper(*args, **kwargs):
            return await retryer.execute(
                lambda: func(*args, **kwargs)
            )
        return wrapper

    return decorator

# Usage
@async_retry(RetryConfig(max_attempts=3))
async def async_api_call(url: str) -> dict:
    import aiohttp
    async with aiohttp.ClientSession() as session:
        async with session.get(url) as response:
            response.raise_for_status()
            return await response.json()
```

## Step 5: MCP tool integration

Apply retries to MCP tools:

```python
class RetryableTool:
    """MCP tool with retry support."""

    def __init__(
        self,
        name: str,
        executor: Callable,
        config: RetryConfig = None
    ):
        self.name = name
        self.executor = executor
        self.retryer = Retryer(config)

    def execute(self, params: dict) -> dict:
        """Execute tool with retries."""
        try:
            result = self.retryer.execute(
                lambda: self.executor(params)
            )
            return {"success": True, "result": result}
        except RetryError as e:
            return {
                "success": False,
                "error": str(e),
                "last_error": str(e.last_exception)
            }

# Tool registry with retry support
class RetryableToolRegistry:
    """Registry for tools with retry configuration."""

    def __init__(self, default_config: RetryConfig = None):
        self.default_config = default_config or RetryConfig()
        self.tools: Dict[str, RetryableTool] = {}

    def register(
        self,
        name: str,
        executor: Callable,
        config: RetryConfig = None
    ):
        """Register tool with retry support."""
        self.tools[name] = RetryableTool(
            name=name,
            executor=executor,
            config=config or self.default_config
        )

    def execute(self, name: str, params: dict) -> dict:
        """Execute tool by name."""
        if name not in self.tools:
            return {"success": False, "error": f"Tool not found: {name}"}

        return self.tools[name].execute(params)

# Usage
registry = RetryableToolRegistry(
    default_config=RetryConfig(max_attempts=3)
)

registry.register(
    "fetch_data",
    fetch_data_func,
    config=RetryConfig(max_attempts=5, initial_delay=2)
)

result = registry.execute("fetch_data", {"url": "https://api.example.com"})
```

## Summary

Retry strategies for MCP:

1. **Basic retries** - Exponential backoff with jitter
2. **Backoff algorithms** - Linear, Fibonacci, decorrelated
3. **Retry budgets** - Limit system-wide retries
4. **Async support** - Handle async operations
5. **Tool integration** - Apply to MCP tools

Build tools with [Gantz](https://gantz.run), retry intelligently.

Fail gracefully. Retry wisely.

## Related reading

- [MCP Circuit Breakers](/post/mcp-circuit-breakers/) - Prevent cascading failures
- [Agent Error Handling](/post/agent-error-handling/) - Handle errors
- [Agent Fallbacks](/post/agent-fallbacks/) - Fallback strategies

---

*What retry strategies work for you? Share your patterns.*
