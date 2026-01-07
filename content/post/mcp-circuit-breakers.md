+++
title = "MCP Circuit Breakers: Prevent Cascading Failures"
image = "/images/mcp-circuit-breakers.png"
date = 2025-11-02
description = "Implement circuit breakers for MCP tools. Prevent cascading failures, handle service degradation, and build resilient AI agent systems."
draft = false
tags = ['mcp', 'reliability', 'resilience']
voice = false

[howto]
name = "Implement Circuit Breakers"
totalTime = 30
[[howto.steps]]
name = "Define failure thresholds"
text = "Set when circuit should open."
[[howto.steps]]
name = "Implement circuit states"
text = "Build closed, open, and half-open states."
[[howto.steps]]
name = "Add recovery logic"
text = "Configure how circuits recover."
[[howto.steps]]
name = "Handle open circuits"
text = "Define fallback behavior."
[[howto.steps]]
name = "Monitor circuit health"
text = "Track circuit state and transitions."
+++


One failing service can take down everything.

Circuit breakers prevent cascading failures.

Here's how to protect your MCP tools.

## The problem

Without circuit breakers:
```
Tool A fails → Retries pile up → Resources exhausted →
Other tools slow down → System overload → Everything fails
```

With circuit breakers:
```
Tool A fails → Circuit opens → Fast fail →
Other tools unaffected → System stable → Recovery when ready
```

## Circuit breaker states

```
         ┌─────────────────────────────────────┐
         │                                     │
         ▼                                     │
    ┌─────────┐     Failure threshold     ┌────────┐
    │ CLOSED  │ ─────────────────────────►│  OPEN  │
    │ (Allow) │                           │ (Deny) │
    └─────────┘                           └────────┘
         ▲                                     │
         │                                     │
         │    Success        Timeout           │
         │       │              │              │
         │       ▼              ▼              │
         │  ┌───────────────────────┐          │
         └──│      HALF-OPEN        │◄─────────┘
            │  (Test with limited)  │
            └───────────────────────┘
```

## Step 1: Basic circuit breaker

Using [Gantz](https://gantz.run):

```yaml
# gantz.yaml
name: resilient-tools

circuit_breakers:
  database:
    failure_threshold: 5
    recovery_timeout: 30
    half_open_requests: 3

  external_api:
    failure_threshold: 3
    recovery_timeout: 60
    half_open_requests: 1

tools:
  - name: query_database
    description: Query with circuit breaker
    circuit_breaker: database
    parameters:
      - name: query
        type: string
        required: true
    script:
      command: python
      args: ["scripts/db_query.py", "{{query}}"]
```

Circuit breaker implementation:

```python
import time
import threading
from enum import Enum
from typing import Callable, Any, Optional
from dataclasses import dataclass

class CircuitState(Enum):
    CLOSED = "closed"      # Normal operation
    OPEN = "open"          # Failing fast
    HALF_OPEN = "half_open"  # Testing recovery

@dataclass
class CircuitConfig:
    """Circuit breaker configuration."""
    failure_threshold: int = 5
    recovery_timeout: int = 30
    half_open_requests: int = 3
    failure_rate_threshold: float = 0.5
    minimum_requests: int = 10

class CircuitBreaker:
    """Circuit breaker implementation."""

    def __init__(self, name: str, config: CircuitConfig):
        self.name = name
        self.config = config

        self.state = CircuitState.CLOSED
        self.failure_count = 0
        self.success_count = 0
        self.last_failure_time = 0
        self.half_open_successes = 0

        self._lock = threading.Lock()
        self._listeners = []

    def call(self, func: Callable, *args, **kwargs) -> Any:
        """Execute function with circuit breaker protection."""

        if not self._can_execute():
            raise CircuitOpenError(
                f"Circuit {self.name} is open"
            )

        try:
            result = func(*args, **kwargs)
            self._record_success()
            return result
        except Exception as e:
            self._record_failure()
            raise

    def _can_execute(self) -> bool:
        """Check if execution is allowed."""
        with self._lock:
            if self.state == CircuitState.CLOSED:
                return True

            if self.state == CircuitState.OPEN:
                # Check if recovery timeout passed
                if time.time() - self.last_failure_time > self.config.recovery_timeout:
                    self._transition_to(CircuitState.HALF_OPEN)
                    return True
                return False

            if self.state == CircuitState.HALF_OPEN:
                # Allow limited requests
                return True

        return False

    def _record_success(self):
        """Record successful execution."""
        with self._lock:
            self.success_count += 1

            if self.state == CircuitState.HALF_OPEN:
                self.half_open_successes += 1
                if self.half_open_successes >= self.config.half_open_requests:
                    self._transition_to(CircuitState.CLOSED)

    def _record_failure(self):
        """Record failed execution."""
        with self._lock:
            self.failure_count += 1
            self.last_failure_time = time.time()

            if self.state == CircuitState.HALF_OPEN:
                # Any failure in half-open reopens
                self._transition_to(CircuitState.OPEN)
            elif self.state == CircuitState.CLOSED:
                # Check threshold
                if self._should_open():
                    self._transition_to(CircuitState.OPEN)

    def _should_open(self) -> bool:
        """Check if circuit should open."""
        total = self.success_count + self.failure_count

        # Need minimum requests
        if total < self.config.minimum_requests:
            return self.failure_count >= self.config.failure_threshold

        # Check failure rate
        failure_rate = self.failure_count / total
        return failure_rate >= self.config.failure_rate_threshold

    def _transition_to(self, new_state: CircuitState):
        """Transition to new state."""
        old_state = self.state
        self.state = new_state

        if new_state == CircuitState.CLOSED:
            self.failure_count = 0
            self.success_count = 0
        elif new_state == CircuitState.HALF_OPEN:
            self.half_open_successes = 0

        # Notify listeners
        for listener in self._listeners:
            listener(self.name, old_state, new_state)

    def add_listener(self, listener: Callable):
        """Add state change listener."""
        self._listeners.append(listener)

    def get_state(self) -> dict:
        """Get current circuit state."""
        return {
            "name": self.name,
            "state": self.state.value,
            "failure_count": self.failure_count,
            "success_count": self.success_count,
            "last_failure": self.last_failure_time
        }

    def reset(self):
        """Manually reset circuit."""
        with self._lock:
            self._transition_to(CircuitState.CLOSED)

class CircuitOpenError(Exception):
    """Raised when circuit is open."""
    pass
```

## Step 2: Circuit breaker registry

Manage multiple circuit breakers:

```python
from typing import Dict, Optional

class CircuitBreakerRegistry:
    """Registry for managing circuit breakers."""

    def __init__(self):
        self.breakers: Dict[str, CircuitBreaker] = {}
        self._default_config = CircuitConfig()

    def register(
        self,
        name: str,
        config: CircuitConfig = None
    ) -> CircuitBreaker:
        """Register a new circuit breaker."""
        config = config or self._default_config
        breaker = CircuitBreaker(name, config)
        self.breakers[name] = breaker

        # Add monitoring listener
        breaker.add_listener(self._on_state_change)

        return breaker

    def get(self, name: str) -> Optional[CircuitBreaker]:
        """Get circuit breaker by name."""
        return self.breakers.get(name)

    def get_or_create(
        self,
        name: str,
        config: CircuitConfig = None
    ) -> CircuitBreaker:
        """Get existing or create new circuit breaker."""
        if name not in self.breakers:
            return self.register(name, config)
        return self.breakers[name]

    def _on_state_change(
        self,
        name: str,
        old_state: CircuitState,
        new_state: CircuitState
    ):
        """Handle circuit state change."""
        print(f"Circuit {name}: {old_state.value} -> {new_state.value}")

        # Alert on open
        if new_state == CircuitState.OPEN:
            self._send_alert(name, "Circuit opened")

    def _send_alert(self, name: str, message: str):
        """Send alert for circuit event."""
        # Implement alerting (Slack, PagerDuty, etc.)
        pass

    def get_all_states(self) -> Dict[str, dict]:
        """Get state of all circuit breakers."""
        return {
            name: breaker.get_state()
            for name, breaker in self.breakers.items()
        }

    def reset_all(self):
        """Reset all circuit breakers."""
        for breaker in self.breakers.values():
            breaker.reset()

# Global registry
circuit_registry = CircuitBreakerRegistry()
```

## Step 3: Decorator pattern

Easy circuit breaker application:

```python
from functools import wraps
from typing import Callable, Optional

def circuit_breaker(
    name: str,
    config: CircuitConfig = None,
    fallback: Callable = None
):
    """Decorator to apply circuit breaker to function."""

    def decorator(func: Callable) -> Callable:
        breaker = circuit_registry.get_or_create(name, config)

        @wraps(func)
        def wrapper(*args, **kwargs):
            try:
                return breaker.call(func, *args, **kwargs)
            except CircuitOpenError:
                if fallback:
                    return fallback(*args, **kwargs)
                raise

        # Attach breaker reference
        wrapper.circuit_breaker = breaker
        return wrapper

    return decorator

# Usage
def database_fallback(query: str) -> dict:
    """Fallback when database circuit is open."""
    return {"error": "Database temporarily unavailable", "cached": True}

@circuit_breaker(
    "database",
    config=CircuitConfig(failure_threshold=5, recovery_timeout=30),
    fallback=database_fallback
)
def query_database(query: str) -> dict:
    """Query database with circuit breaker."""
    # Actual database query
    pass

@circuit_breaker("external_api")
def call_external_api(endpoint: str) -> dict:
    """Call API with circuit breaker."""
    import requests
    response = requests.get(endpoint, timeout=10)
    response.raise_for_status()
    return response.json()
```

## Step 4: Tool-level circuit breakers

Apply to MCP tools:

```python
class CircuitProtectedTool:
    """MCP tool with circuit breaker protection."""

    def __init__(
        self,
        name: str,
        executor: Callable,
        circuit_config: CircuitConfig = None,
        fallback: Callable = None
    ):
        self.name = name
        self.executor = executor
        self.fallback = fallback

        self.circuit = circuit_registry.get_or_create(
            f"tool:{name}",
            circuit_config
        )

    def execute(self, params: dict) -> dict:
        """Execute tool with circuit protection."""
        try:
            return self.circuit.call(self.executor, params)
        except CircuitOpenError:
            if self.fallback:
                return {
                    "result": self.fallback(params),
                    "fallback": True,
                    "circuit_open": True
                }
            return {
                "error": f"Tool {self.name} circuit is open",
                "circuit_open": True
            }

class MCPCircuitBreakerMiddleware:
    """Middleware to add circuit breakers to all tools."""

    def __init__(self, default_config: CircuitConfig = None):
        self.default_config = default_config or CircuitConfig()
        self.fallbacks: Dict[str, Callable] = {}

    def set_fallback(self, tool_name: str, fallback: Callable):
        """Set fallback for a tool."""
        self.fallbacks[tool_name] = fallback

    def wrap_tool(self, tool_name: str, executor: Callable) -> Callable:
        """Wrap tool with circuit breaker."""
        circuit = circuit_registry.get_or_create(
            f"tool:{tool_name}",
            self.default_config
        )
        fallback = self.fallbacks.get(tool_name)

        def wrapped(params: dict) -> dict:
            try:
                return circuit.call(executor, params)
            except CircuitOpenError:
                if fallback:
                    return fallback(params)
                raise

        return wrapped

# Usage
middleware = MCPCircuitBreakerMiddleware(
    default_config=CircuitConfig(failure_threshold=3)
)

middleware.set_fallback("search", lambda p: {"results": [], "cached": True})

# Wrap tools
search_tool = middleware.wrap_tool("search", original_search)
```

## Step 5: Advanced patterns

Sliding window and bulkhead:

```python
from collections import deque
from dataclasses import dataclass
import threading

@dataclass
class SlidingWindowConfig:
    """Sliding window circuit breaker config."""
    window_size: int = 10  # Number of requests
    failure_rate_threshold: float = 0.5
    slow_call_duration: float = 2.0  # seconds
    slow_call_rate_threshold: float = 0.5

class SlidingWindowCircuitBreaker:
    """Circuit breaker with sliding window."""

    def __init__(self, name: str, config: SlidingWindowConfig):
        self.name = name
        self.config = config

        self.window: deque = deque(maxlen=config.window_size)
        self.state = CircuitState.CLOSED
        self._lock = threading.Lock()

    def call(self, func: Callable, *args, **kwargs) -> Any:
        if self.state == CircuitState.OPEN:
            raise CircuitOpenError(f"Circuit {self.name} is open")

        start_time = time.time()
        try:
            result = func(*args, **kwargs)
            duration = time.time() - start_time

            self._record(success=True, duration=duration)
            return result
        except Exception as e:
            self._record(success=False, duration=0)
            raise

    def _record(self, success: bool, duration: float):
        """Record call result in sliding window."""
        with self._lock:
            is_slow = duration > self.config.slow_call_duration

            self.window.append({
                "success": success,
                "slow": is_slow,
                "timestamp": time.time()
            })

            self._evaluate()

    def _evaluate(self):
        """Evaluate if circuit should open."""
        if len(self.window) < self.config.window_size:
            return

        failures = sum(1 for r in self.window if not r["success"])
        slow_calls = sum(1 for r in self.window if r["slow"])

        failure_rate = failures / len(self.window)
        slow_rate = slow_calls / len(self.window)

        if failure_rate >= self.config.failure_rate_threshold:
            self.state = CircuitState.OPEN
        elif slow_rate >= self.config.slow_call_rate_threshold:
            self.state = CircuitState.OPEN

class BulkheadCircuitBreaker:
    """Circuit breaker with bulkhead pattern."""

    def __init__(
        self,
        name: str,
        max_concurrent: int = 10,
        max_wait: int = 5
    ):
        self.name = name
        self.max_concurrent = max_concurrent
        self.max_wait = max_wait

        self.semaphore = threading.Semaphore(max_concurrent)
        self.circuit = CircuitBreaker(name, CircuitConfig())

    def call(self, func: Callable, *args, **kwargs) -> Any:
        """Execute with bulkhead and circuit breaker."""

        # Bulkhead: limit concurrent calls
        acquired = self.semaphore.acquire(timeout=self.max_wait)
        if not acquired:
            raise BulkheadFullError(
                f"Bulkhead {self.name} is full"
            )

        try:
            # Circuit breaker
            return self.circuit.call(func, *args, **kwargs)
        finally:
            self.semaphore.release()

class BulkheadFullError(Exception):
    pass
```

## Step 6: Monitoring

Track circuit breaker health:

```python
from prometheus_client import Gauge, Counter

circuit_state_gauge = Gauge(
    'circuit_breaker_state',
    'Current circuit state (0=closed, 1=open, 2=half-open)',
    ['circuit_name']
)

circuit_failures_counter = Counter(
    'circuit_breaker_failures_total',
    'Total circuit breaker failures',
    ['circuit_name']
)

circuit_opens_counter = Counter(
    'circuit_breaker_opens_total',
    'Times circuit has opened',
    ['circuit_name']
)

class CircuitBreakerMonitor:
    """Monitor circuit breaker health."""

    def __init__(self, registry: CircuitBreakerRegistry):
        self.registry = registry

        # Add listeners to all breakers
        for name, breaker in registry.breakers.items():
            breaker.add_listener(self._on_state_change)

    def _on_state_change(
        self,
        name: str,
        old_state: CircuitState,
        new_state: CircuitState
    ):
        """Update metrics on state change."""
        state_value = {
            CircuitState.CLOSED: 0,
            CircuitState.OPEN: 1,
            CircuitState.HALF_OPEN: 2
        }

        circuit_state_gauge.labels(circuit_name=name).set(
            state_value[new_state]
        )

        if new_state == CircuitState.OPEN:
            circuit_opens_counter.labels(circuit_name=name).inc()

    def get_dashboard_data(self) -> dict:
        """Get data for dashboard."""
        states = self.registry.get_all_states()

        return {
            "circuits": states,
            "summary": {
                "total": len(states),
                "open": sum(1 for s in states.values() if s["state"] == "open"),
                "closed": sum(1 for s in states.values() if s["state"] == "closed"),
                "half_open": sum(1 for s in states.values() if s["state"] == "half_open")
            }
        }
```

## Summary

Circuit breaker patterns for MCP:

1. **Basic breaker** - Three-state protection
2. **Registry** - Manage multiple breakers
3. **Decorators** - Easy application
4. **Tool protection** - MCP tool integration
5. **Advanced patterns** - Sliding window, bulkhead
6. **Monitoring** - Track health

Build tools with [Gantz](https://gantz.run), protect with breakers.

Fail fast. Recover gracefully.

## Related reading

- [Agent Error Handling](/post/agent-error-handling/) - Handle failures
- [Agent Fallbacks](/post/agent-fallbacks/) - Fallback strategies
- [MCP Retries](/post/mcp-retries/) - Retry patterns

---

*How do you handle failures in your agents? Share your patterns.*
