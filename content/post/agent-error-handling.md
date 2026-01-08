+++
title = "AI Agent Error Handling: Build Resilient Systems"
image = "images/agent-error-handling.webp"
date = 2025-11-19
description = "Handle errors gracefully in AI agents. Implement retry logic, graceful degradation, and error recovery patterns for robust MCP tool execution."
summary = "Build resilient AI agents with error classification, exponential backoff retries, circuit breakers to prevent cascading failures, and fallback chains for graceful degradation. Monitor errors and enable self-healing."
draft = false
tags = ['mcp', 'reliability', 'error-handling']
voice = false

[howto]
name = "Handle Agent Errors"
totalTime = 35
[[howto.steps]]
name = "Classify errors"
text = "Distinguish between retryable and fatal errors."
[[howto.steps]]
name = "Implement retries"
text = "Add exponential backoff for transient failures."
[[howto.steps]]
name = "Add fallbacks"
text = "Provide alternative actions when tools fail."
[[howto.steps]]
name = "Surface errors clearly"
text = "Return meaningful error messages to users."
[[howto.steps]]
name = "Monitor error patterns"
text = "Track errors to identify systemic issues."
+++


AI agents fail. Tools timeout. APIs error.

The question isn't if your agent will fail. It's how.

Here's how to build agents that fail gracefully.

## The error landscape

Agents face multiple failure modes:

| Error Type | Cause | Retryable |
|------------|-------|-----------|
| Rate limits | API quota exceeded | Yes (with backoff) |
| Timeout | Tool took too long | Sometimes |
| Network | Connection failed | Yes |
| Validation | Bad input | No |
| Authentication | Invalid token | No |
| Tool failure | Script error | Depends |
| Model error | LLM API failure | Yes |

## Step 1: Error classification

Using [Gantz](https://gantz.run):

```yaml
# gantz.yaml
name: resilient-agent

tools:
  - name: api_call
    description: Call external API with error handling
    parameters:
      - name: endpoint
        type: string
        required: true
    timeout: 30
    retries: 3
    script:
      shell: curl -f "{{endpoint}}" 2>/dev/null || echo '{"error": "API call failed"}'

  - name: database_query
    description: Query database with timeout
    parameters:
      - name: query
        type: string
        required: true
    timeout: 10
    script:
      shell: timeout 10 psql "$DATABASE_URL" -c "{{query}}" || echo "Query timeout"
```

Error classification system:

```python
from enum import Enum
from dataclasses import dataclass
from typing import Optional, Type

class ErrorCategory(Enum):
    TRANSIENT = "transient"      # Retry with backoff
    RATE_LIMIT = "rate_limit"    # Retry after delay
    VALIDATION = "validation"     # Don't retry, fix input
    AUTH = "authentication"       # Don't retry, re-auth needed
    FATAL = "fatal"              # Don't retry, requires intervention
    UNKNOWN = "unknown"          # Log and investigate

@dataclass
class AgentError:
    """Structured agent error."""
    category: ErrorCategory
    message: str
    original_error: Optional[Exception] = None
    retryable: bool = False
    retry_after: Optional[int] = None
    context: Optional[dict] = None

class ErrorClassifier:
    """Classify errors into categories."""

    # Error patterns mapped to categories
    PATTERNS = {
        ErrorCategory.RATE_LIMIT: [
            "rate limit", "too many requests", "429",
            "quota exceeded", "throttled"
        ],
        ErrorCategory.AUTH: [
            "unauthorized", "401", "403", "forbidden",
            "invalid token", "authentication failed"
        ],
        ErrorCategory.TRANSIENT: [
            "timeout", "connection refused", "503",
            "502", "504", "temporary", "retry"
        ],
        ErrorCategory.VALIDATION: [
            "invalid input", "validation error", "400",
            "bad request", "missing required"
        ]
    }

    @classmethod
    def classify(cls, error: Exception) -> AgentError:
        """Classify an exception into an AgentError."""

        error_str = str(error).lower()

        # Check patterns
        for category, patterns in cls.PATTERNS.items():
            if any(p in error_str for p in patterns):
                return AgentError(
                    category=category,
                    message=str(error),
                    original_error=error,
                    retryable=category in [ErrorCategory.TRANSIENT, ErrorCategory.RATE_LIMIT],
                    retry_after=60 if category == ErrorCategory.RATE_LIMIT else None
                )

        # Unknown errors
        return AgentError(
            category=ErrorCategory.UNKNOWN,
            message=str(error),
            original_error=error,
            retryable=False
        )

    @classmethod
    def from_http_status(cls, status_code: int, message: str = "") -> AgentError:
        """Create error from HTTP status code."""

        if status_code == 429:
            return AgentError(
                category=ErrorCategory.RATE_LIMIT,
                message=message or "Rate limit exceeded",
                retryable=True,
                retry_after=60
            )
        elif status_code in [401, 403]:
            return AgentError(
                category=ErrorCategory.AUTH,
                message=message or "Authentication failed",
                retryable=False
            )
        elif status_code in [500, 502, 503, 504]:
            return AgentError(
                category=ErrorCategory.TRANSIENT,
                message=message or "Server error",
                retryable=True
            )
        elif status_code == 400:
            return AgentError(
                category=ErrorCategory.VALIDATION,
                message=message or "Bad request",
                retryable=False
            )
        else:
            return AgentError(
                category=ErrorCategory.UNKNOWN,
                message=message or f"HTTP {status_code}",
                retryable=False
            )
```

## Step 2: Retry logic

Exponential backoff with jitter:

```python
import time
import random
from functools import wraps
from typing import Callable, TypeVar, List, Type

T = TypeVar('T')

class RetryConfig:
    """Configuration for retry behavior."""

    def __init__(
        self,
        max_attempts: int = 3,
        base_delay: float = 1.0,
        max_delay: float = 60.0,
        exponential_base: float = 2.0,
        jitter: bool = True,
        retryable_errors: List[Type[Exception]] = None
    ):
        self.max_attempts = max_attempts
        self.base_delay = base_delay
        self.max_delay = max_delay
        self.exponential_base = exponential_base
        self.jitter = jitter
        self.retryable_errors = retryable_errors or [Exception]

class RetryHandler:
    """Handle retries with exponential backoff."""

    def __init__(self, config: RetryConfig = None):
        self.config = config or RetryConfig()

    def calculate_delay(self, attempt: int) -> float:
        """Calculate delay for this attempt."""
        delay = self.config.base_delay * (
            self.config.exponential_base ** attempt
        )
        delay = min(delay, self.config.max_delay)

        if self.config.jitter:
            # Add random jitter (0-25% of delay)
            delay += random.uniform(0, delay * 0.25)

        return delay

    def should_retry(self, error: Exception, attempt: int) -> bool:
        """Determine if we should retry."""
        if attempt >= self.config.max_attempts:
            return False

        # Check if error is retryable
        classified = ErrorClassifier.classify(error)
        return classified.retryable

    def execute(self, func: Callable[[], T]) -> T:
        """Execute function with retries."""
        last_error = None

        for attempt in range(self.config.max_attempts):
            try:
                return func()
            except Exception as e:
                last_error = e

                if not self.should_retry(e, attempt):
                    raise

                delay = self.calculate_delay(attempt)
                print(f"Attempt {attempt + 1} failed: {e}. Retrying in {delay:.2f}s")
                time.sleep(delay)

        raise last_error

def with_retry(config: RetryConfig = None):
    """Decorator for automatic retries."""
    handler = RetryHandler(config)

    def decorator(func):
        @wraps(func)
        def wrapper(*args, **kwargs):
            return handler.execute(lambda: func(*args, **kwargs))
        return wrapper
    return decorator

# Usage
@with_retry(RetryConfig(max_attempts=3, base_delay=1.0))
def call_api(endpoint: str) -> dict:
    import requests
    response = requests.get(endpoint)
    response.raise_for_status()
    return response.json()
```

Async retry handler:

```python
import asyncio
from typing import Callable, Awaitable

class AsyncRetryHandler:
    """Async retry handler."""

    def __init__(self, config: RetryConfig = None):
        self.config = config or RetryConfig()

    async def execute(self, func: Callable[[], Awaitable[T]]) -> T:
        """Execute async function with retries."""
        last_error = None

        for attempt in range(self.config.max_attempts):
            try:
                return await func()
            except Exception as e:
                last_error = e

                classified = ErrorClassifier.classify(e)
                if not classified.retryable:
                    raise

                if attempt < self.config.max_attempts - 1:
                    delay = self.calculate_delay(attempt)
                    await asyncio.sleep(delay)

        raise last_error

    def calculate_delay(self, attempt: int) -> float:
        delay = self.config.base_delay * (
            self.config.exponential_base ** attempt
        )
        return min(delay, self.config.max_delay)

# Usage
async def run_agent_task(task: str):
    handler = AsyncRetryHandler()
    return await handler.execute(lambda: call_llm(task))
```

## Step 3: Circuit breaker

Prevent cascading failures:

```python
import time
from enum import Enum
from threading import Lock

class CircuitState(Enum):
    CLOSED = "closed"      # Normal operation
    OPEN = "open"          # Failing, reject requests
    HALF_OPEN = "half_open"  # Testing if recovered

class CircuitBreaker:
    """Circuit breaker pattern for tool calls."""

    def __init__(
        self,
        failure_threshold: int = 5,
        recovery_timeout: int = 30,
        half_open_requests: int = 3
    ):
        self.failure_threshold = failure_threshold
        self.recovery_timeout = recovery_timeout
        self.half_open_requests = half_open_requests

        self.state = CircuitState.CLOSED
        self.failure_count = 0
        self.success_count = 0
        self.last_failure_time = 0
        self.lock = Lock()

    def can_execute(self) -> bool:
        """Check if circuit allows execution."""
        with self.lock:
            if self.state == CircuitState.CLOSED:
                return True

            if self.state == CircuitState.OPEN:
                # Check if recovery timeout passed
                if time.time() - self.last_failure_time > self.recovery_timeout:
                    self.state = CircuitState.HALF_OPEN
                    self.success_count = 0
                    return True
                return False

            # HALF_OPEN: Allow limited requests
            return True

    def record_success(self):
        """Record successful execution."""
        with self.lock:
            if self.state == CircuitState.HALF_OPEN:
                self.success_count += 1
                if self.success_count >= self.half_open_requests:
                    self.state = CircuitState.CLOSED
                    self.failure_count = 0
            else:
                self.failure_count = 0

    def record_failure(self):
        """Record failed execution."""
        with self.lock:
            self.failure_count += 1
            self.last_failure_time = time.time()

            if self.state == CircuitState.HALF_OPEN:
                # Any failure in half-open reopens circuit
                self.state = CircuitState.OPEN
            elif self.failure_count >= self.failure_threshold:
                self.state = CircuitState.OPEN

    def execute(self, func: Callable[[], T]) -> T:
        """Execute function with circuit breaker."""
        if not self.can_execute():
            raise CircuitOpenError(f"Circuit is open, retry after {self.recovery_timeout}s")

        try:
            result = func()
            self.record_success()
            return result
        except Exception as e:
            self.record_failure()
            raise

class CircuitOpenError(Exception):
    """Raised when circuit is open."""
    pass

# Per-tool circuit breakers
class ToolCircuitBreakers:
    """Manage circuit breakers for each tool."""

    def __init__(self):
        self.breakers = {}

    def get(self, tool_name: str) -> CircuitBreaker:
        if tool_name not in self.breakers:
            self.breakers[tool_name] = CircuitBreaker()
        return self.breakers[tool_name]

    def execute_tool(self, tool_name: str, func: Callable) -> any:
        breaker = self.get(tool_name)
        return breaker.execute(func)

# Usage
breakers = ToolCircuitBreakers()

def call_tool(tool_name: str, params: dict):
    return breakers.execute_tool(
        tool_name,
        lambda: execute_tool_internal(tool_name, params)
    )
```

## Step 4: Graceful degradation

Fallback strategies when tools fail:

```python
from typing import List, Callable, Any, Optional
from dataclasses import dataclass

@dataclass
class FallbackOption:
    """A fallback option for tool execution."""
    name: str
    executor: Callable
    condition: Optional[Callable[[Exception], bool]] = None
    priority: int = 0

class FallbackChain:
    """Chain of fallback options."""

    def __init__(self):
        self.fallbacks: List[FallbackOption] = []

    def add(self, option: FallbackOption):
        """Add fallback option."""
        self.fallbacks.append(option)
        self.fallbacks.sort(key=lambda x: x.priority, reverse=True)

    def execute(self, primary: Callable, context: dict = None) -> Any:
        """Execute with fallbacks."""
        last_error = None

        # Try primary
        try:
            return primary()
        except Exception as e:
            last_error = e

        # Try fallbacks
        for fallback in self.fallbacks:
            if fallback.condition and not fallback.condition(last_error):
                continue

            try:
                return fallback.executor(context)
            except Exception as e:
                last_error = e
                continue

        raise last_error

# Example: Database query with fallbacks
class DatabaseWithFallback:
    """Database queries with fallback strategies."""

    def __init__(self):
        self.fallback_chain = FallbackChain()

        # Add fallbacks
        self.fallback_chain.add(FallbackOption(
            name="cache",
            executor=self._query_cache,
            priority=10
        ))

        self.fallback_chain.add(FallbackOption(
            name="replica",
            executor=self._query_replica,
            condition=lambda e: "connection" in str(e).lower(),
            priority=5
        ))

        self.fallback_chain.add(FallbackOption(
            name="default",
            executor=self._return_default,
            priority=0
        ))

    def query(self, sql: str) -> dict:
        """Query with fallbacks."""
        return self.fallback_chain.execute(
            lambda: self._query_primary(sql),
            context={"sql": sql}
        )

    def _query_primary(self, sql: str) -> dict:
        # Primary database query
        pass

    def _query_cache(self, context: dict) -> dict:
        # Return cached result
        pass

    def _query_replica(self, context: dict) -> dict:
        # Query read replica
        pass

    def _return_default(self, context: dict) -> dict:
        # Return safe default
        return {"data": [], "fallback": True}
```

## Step 5: Error recovery

Automatic recovery from failures:

```python
import anthropic
from typing import Optional

class RecoverableAgent:
    """Agent with error recovery capabilities."""

    def __init__(self):
        self.client = anthropic.Anthropic()
        self.retry_handler = RetryHandler()
        self.breakers = ToolCircuitBreakers()

    def run(self, task: str, mcp_url: str, mcp_token: str) -> str:
        """Run agent with error recovery."""

        messages = [{"role": "user", "content": task}]
        max_errors = 3
        error_count = 0

        while error_count < max_errors:
            try:
                response = self._call_llm(messages, mcp_url, mcp_token)

                # Handle tool use
                if response.stop_reason == "tool_use":
                    tool_results = self._execute_tools(response)

                    # Add assistant response and tool results
                    messages.append({"role": "assistant", "content": response.content})
                    messages.append({"role": "user", "content": tool_results})
                    continue

                # Extract final response
                return self._extract_response(response)

            except CircuitOpenError as e:
                # Tool circuit is open, ask LLM to use alternative
                error_count += 1
                messages.append({
                    "role": "user",
                    "content": f"The tool is temporarily unavailable: {e}. Please try an alternative approach."
                })

            except Exception as e:
                error_count += 1
                classified = ErrorClassifier.classify(e)

                if classified.category == ErrorCategory.RATE_LIMIT:
                    # Wait and retry
                    time.sleep(classified.retry_after or 60)
                    continue

                if classified.retryable:
                    continue

                # Non-retryable: inform user
                return f"I encountered an error: {classified.message}"

        return "I was unable to complete the task after multiple attempts."

    def _call_llm(self, messages: list, mcp_url: str, mcp_token: str):
        """Call LLM with retry."""
        return self.retry_handler.execute(lambda:
            self.client.messages.create(
                model="claude-sonnet-4-20250514",
                max_tokens=4096,
                messages=messages,
                tools=[{"type": "mcp", "server_url": mcp_url, "token": mcp_token}]
            )
        )

    def _execute_tools(self, response) -> list:
        """Execute tools with circuit breakers."""
        results = []

        for content in response.content:
            if hasattr(content, 'type') and content.type == "tool_use":
                try:
                    result = self.breakers.execute_tool(
                        content.name,
                        lambda: self._run_tool(content.name, content.input)
                    )
                    results.append({
                        "type": "tool_result",
                        "tool_use_id": content.id,
                        "content": result
                    })
                except CircuitOpenError:
                    results.append({
                        "type": "tool_result",
                        "tool_use_id": content.id,
                        "content": f"Tool {content.name} is temporarily unavailable",
                        "is_error": True
                    })
                except Exception as e:
                    results.append({
                        "type": "tool_result",
                        "tool_use_id": content.id,
                        "content": f"Tool error: {str(e)}",
                        "is_error": True
                    })

        return results

    def _run_tool(self, name: str, params: dict) -> str:
        # Actual tool execution
        pass

    def _extract_response(self, response) -> str:
        for content in response.content:
            if hasattr(content, 'text'):
                return content.text
        return ""
```

## Step 6: Error monitoring

Track and alert on errors:

```python
from prometheus_client import Counter, Histogram
import logging

# Metrics
error_counter = Counter(
    'agent_errors_total',
    'Total agent errors',
    ['error_category', 'tool_name']
)

error_recovery_counter = Counter(
    'agent_error_recoveries_total',
    'Successful error recoveries',
    ['recovery_type']
)

retry_histogram = Histogram(
    'agent_retry_attempts',
    'Retry attempts before success',
    buckets=[1, 2, 3, 4, 5]
)

class ErrorMonitor:
    """Monitor and log agent errors."""

    def __init__(self):
        self.logger = logging.getLogger("agent.errors")

    def record_error(self, error: AgentError, tool_name: str = "unknown"):
        """Record an error for monitoring."""

        # Increment counter
        error_counter.labels(
            error_category=error.category.value,
            tool_name=tool_name
        ).inc()

        # Log error
        self.logger.error(
            "Agent error",
            extra={
                "category": error.category.value,
                "message": error.message,
                "tool": tool_name,
                "retryable": error.retryable
            }
        )

        # Alert on critical errors
        if error.category in [ErrorCategory.AUTH, ErrorCategory.FATAL]:
            self._send_alert(error)

    def record_recovery(self, recovery_type: str):
        """Record successful recovery."""
        error_recovery_counter.labels(recovery_type=recovery_type).inc()

    def record_retry_success(self, attempts: int):
        """Record how many retries were needed."""
        retry_histogram.observe(attempts)

    def _send_alert(self, error: AgentError):
        """Send alert for critical errors."""
        # Implement alerting (PagerDuty, Slack, etc.)
        pass

# Usage in agent
monitor = ErrorMonitor()

try:
    result = execute_tool("query_db", params)
except Exception as e:
    error = ErrorClassifier.classify(e)
    monitor.record_error(error, "query_db")
    raise
```

## Summary

Error handling for AI agents:

1. **Classify errors** - Know what's retryable
2. **Implement retries** - Exponential backoff with jitter
3. **Use circuit breakers** - Prevent cascading failures
4. **Add fallbacks** - Graceful degradation
5. **Enable recovery** - Self-healing agents
6. **Monitor errors** - Track and alert

Build tools with [Gantz](https://gantz.run), build resilient agents.

Failures happen. How you handle them matters.

## Related reading

- [Agent Fallbacks](/post/agent-fallbacks/) - Fallback strategies
- [Agent Observability](/post/agent-observability/) - Monitor agent health
- [MCP Security](/post/mcp-security-best-practices/) - Secure error handling

---

*How do you handle agent failures? Share your patterns.*
