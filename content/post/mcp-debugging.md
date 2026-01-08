+++
title = "MCP Debugging: Troubleshoot Tool Failures"
image = "images/mcp-debugging.webp"
date = 2025-11-13
description = "Debug MCP tools and AI agent issues. Logging, tracing, error analysis, and debugging patterns for reliable tool execution."
draft = false
tags = ['mcp', 'debugging', 'observability']
voice = false
summary = "Master MCP tool debugging with structured JSON logging, distributed tracing across tool calls, and comprehensive error context capture. This guide shows you how to implement debug mode, request replay for reproducing issues, and build a debugging dashboard that aggregates insights for rapid troubleshooting."

[howto]
name = "Debug MCP Tools"
totalTime = 25
[[howto.steps]]
name = "Enable verbose logging"
text = "Configure detailed logging for tool execution."
[[howto.steps]]
name = "Add distributed tracing"
text = "Trace requests across tool calls."
[[howto.steps]]
name = "Capture error context"
text = "Log relevant state when errors occur."
[[howto.steps]]
name = "Use debugging tools"
text = "Apply debuggers and profilers."
[[howto.steps]]
name = "Analyze failure patterns"
text = "Identify common failure modes."
+++


Tools fail silently. Agents get confused.

Without debugging, you're guessing.

Logging and tracing reveal the truth.

## Why debugging matters

Without debugging:
```
Tool failed → Agent retries → Fails again →
User confused → Developer guessing →
Hours wasted
```

With debugging:
```
Tool failed → Logs show: "Connection timeout to DB" →
Fix: Increase timeout → Works
Minutes to resolution
```

## Step 1: Structured logging

Using [Gantz](https://gantz.run):

```yaml
# gantz.yaml
name: debuggable-tools

logging:
  level: debug
  format: json
  include:
    - timestamp
    - tool_name
    - request_id
    - duration
    - parameters
    - result_summary

tools:
  - name: query_database
    description: Query with full logging
    logging:
      level: debug
      log_params: true
      log_result: true
    parameters:
      - name: query
        type: string
        required: true
    script:
      command: python
      args: ["scripts/query.py"]
```

Structured logging implementation:

```python
import logging
import json
import sys
import traceback
from datetime import datetime
from typing import Any, Dict, Optional
from dataclasses import dataclass, asdict
from contextlib import contextmanager
import uuid

@dataclass
class LogContext:
    """Context for structured logging."""
    request_id: str
    tool_name: str
    timestamp: str = None

    def __post_init__(self):
        if not self.timestamp:
            self.timestamp = datetime.utcnow().isoformat()

class StructuredLogger:
    """JSON structured logger for MCP tools."""

    def __init__(self, name: str, level: int = logging.DEBUG):
        self.logger = logging.getLogger(name)
        self.logger.setLevel(level)

        # JSON handler
        handler = logging.StreamHandler(sys.stderr)
        handler.setFormatter(self._json_formatter())
        self.logger.addHandler(handler)

        self._context: Optional[LogContext] = None

    def _json_formatter(self):
        class JSONFormatter(logging.Formatter):
            def format(self, record):
                log_data = {
                    "timestamp": datetime.utcnow().isoformat(),
                    "level": record.levelname,
                    "message": record.getMessage(),
                    "logger": record.name
                }

                # Add extra fields
                if hasattr(record, 'extra'):
                    log_data.update(record.extra)

                return json.dumps(log_data)

        return JSONFormatter()

    @contextmanager
    def context(self, tool_name: str, request_id: str = None):
        """Set logging context."""
        self._context = LogContext(
            request_id=request_id or str(uuid.uuid4()),
            tool_name=tool_name
        )
        try:
            yield self._context
        finally:
            self._context = None

    def _log(self, level: int, message: str, **kwargs):
        """Log with context."""
        extra = kwargs.copy()
        if self._context:
            extra.update(asdict(self._context))

        self.logger.log(level, message, extra={'extra': extra})

    def debug(self, message: str, **kwargs):
        self._log(logging.DEBUG, message, **kwargs)

    def info(self, message: str, **kwargs):
        self._log(logging.INFO, message, **kwargs)

    def warning(self, message: str, **kwargs):
        self._log(logging.WARNING, message, **kwargs)

    def error(self, message: str, **kwargs):
        self._log(logging.ERROR, message, **kwargs)

    def exception(self, message: str, exc: Exception = None, **kwargs):
        """Log exception with traceback."""
        kwargs['traceback'] = traceback.format_exc()
        if exc:
            kwargs['exception_type'] = type(exc).__name__
            kwargs['exception_message'] = str(exc)
        self._log(logging.ERROR, message, **kwargs)

# Usage
logger = StructuredLogger("mcp.tools")

def tool_handler(params: dict) -> dict:
    with logger.context("query_database", request_id=params.get("request_id")):
        logger.info("Tool execution started", params=params)

        try:
            result = execute_query(params["query"])
            logger.info("Tool execution completed",
                       result_count=len(result),
                       duration_ms=100)
            return {"success": True, "data": result}
        except Exception as e:
            logger.exception("Tool execution failed", exc=e)
            return {"success": False, "error": str(e)}
```

## Step 2: Distributed tracing

Trace requests across tool calls:

```python
import uuid
import time
from typing import Dict, List, Optional, Any
from dataclasses import dataclass, field
from contextlib import contextmanager
from contextvars import ContextVar

# Trace context
current_span: ContextVar[Optional['Span']] = ContextVar('current_span', default=None)

@dataclass
class Span:
    """Tracing span."""
    trace_id: str
    span_id: str
    parent_id: Optional[str]
    operation: str
    start_time: float
    end_time: float = None
    tags: Dict[str, Any] = field(default_factory=dict)
    logs: List[Dict[str, Any]] = field(default_factory=list)
    status: str = "ok"

    def set_tag(self, key: str, value: Any):
        self.tags[key] = value

    def log(self, message: str, **kwargs):
        self.logs.append({
            "timestamp": time.time(),
            "message": message,
            **kwargs
        })

    def finish(self, status: str = "ok"):
        self.end_time = time.time()
        self.status = status

    @property
    def duration_ms(self) -> float:
        if self.end_time:
            return (self.end_time - self.start_time) * 1000
        return 0

class Tracer:
    """Distributed tracing for MCP tools."""

    def __init__(self, service_name: str):
        self.service_name = service_name
        self.spans: List[Span] = []

    @contextmanager
    def span(self, operation: str, tags: Dict[str, Any] = None):
        """Create a new span."""
        parent = current_span.get()

        trace_id = parent.trace_id if parent else str(uuid.uuid4())
        span_id = str(uuid.uuid4())[:16]
        parent_id = parent.span_id if parent else None

        span = Span(
            trace_id=trace_id,
            span_id=span_id,
            parent_id=parent_id,
            operation=operation,
            start_time=time.time(),
            tags=tags or {}
        )
        span.set_tag("service", self.service_name)

        token = current_span.set(span)

        try:
            yield span
            span.finish("ok")
        except Exception as e:
            span.set_tag("error", True)
            span.set_tag("error.message", str(e))
            span.finish("error")
            raise
        finally:
            current_span.reset(token)
            self.spans.append(span)

    def get_current_span(self) -> Optional[Span]:
        """Get current active span."""
        return current_span.get()

    def export_spans(self) -> List[dict]:
        """Export spans for analysis."""
        return [
            {
                "traceId": s.trace_id,
                "spanId": s.span_id,
                "parentId": s.parent_id,
                "operation": s.operation,
                "service": self.service_name,
                "startTime": s.start_time,
                "duration": s.duration_ms,
                "tags": s.tags,
                "logs": s.logs,
                "status": s.status
            }
            for s in self.spans
        ]

# Usage
tracer = Tracer("mcp-tools")

async def handle_request(request: dict):
    with tracer.span("handle_request", {"request.type": request["type"]}):
        # Process request
        with tracer.span("validate_request"):
            validate(request)

        with tracer.span("execute_tool", {"tool": request["tool"]}):
            result = await execute_tool(request)

        with tracer.span("format_response"):
            return format_response(result)
```

## Step 3: Error context capture

Capture context when errors occur:

```python
from dataclasses import dataclass
from typing import Dict, Any, List, Optional
import sys
import traceback
import json

@dataclass
class ErrorContext:
    """Context captured when error occurs."""
    error_type: str
    error_message: str
    traceback: str
    tool_name: str
    parameters: Dict[str, Any]
    state: Dict[str, Any]
    timestamp: str
    request_id: str

class ErrorCapture:
    """Capture detailed error context."""

    def __init__(self, max_history: int = 100):
        self.errors: List[ErrorContext] = []
        self.max_history = max_history

    def capture(
        self,
        error: Exception,
        tool_name: str,
        parameters: Dict[str, Any],
        state: Dict[str, Any] = None,
        request_id: str = None
    ) -> ErrorContext:
        """Capture error with full context."""
        context = ErrorContext(
            error_type=type(error).__name__,
            error_message=str(error),
            traceback=traceback.format_exc(),
            tool_name=tool_name,
            parameters=self._sanitize_params(parameters),
            state=state or {},
            timestamp=datetime.utcnow().isoformat(),
            request_id=request_id or str(uuid.uuid4())
        )

        self.errors.append(context)

        # Trim history
        if len(self.errors) > self.max_history:
            self.errors = self.errors[-self.max_history:]

        return context

    def _sanitize_params(self, params: Dict[str, Any]) -> Dict[str, Any]:
        """Remove sensitive data from parameters."""
        sensitive_keys = {'password', 'token', 'api_key', 'secret'}
        sanitized = {}

        for key, value in params.items():
            if key.lower() in sensitive_keys:
                sanitized[key] = "[REDACTED]"
            elif isinstance(value, dict):
                sanitized[key] = self._sanitize_params(value)
            else:
                sanitized[key] = value

        return sanitized

    def get_recent_errors(
        self,
        tool_name: str = None,
        error_type: str = None,
        limit: int = 10
    ) -> List[ErrorContext]:
        """Get recent errors with optional filtering."""
        errors = self.errors

        if tool_name:
            errors = [e for e in errors if e.tool_name == tool_name]

        if error_type:
            errors = [e for e in errors if e.error_type == error_type]

        return errors[-limit:]

    def analyze_patterns(self) -> Dict[str, Any]:
        """Analyze error patterns."""
        by_type = {}
        by_tool = {}

        for error in self.errors:
            by_type[error.error_type] = by_type.get(error.error_type, 0) + 1
            by_tool[error.tool_name] = by_tool.get(error.tool_name, 0) + 1

        return {
            "total_errors": len(self.errors),
            "by_error_type": by_type,
            "by_tool": by_tool,
            "most_common_error": max(by_type, key=by_type.get) if by_type else None,
            "most_failing_tool": max(by_tool, key=by_tool.get) if by_tool else None
        }

# Usage
error_capture = ErrorCapture()

def execute_tool_with_capture(tool_name: str, params: dict) -> dict:
    try:
        return tool_registry[tool_name](**params)
    except Exception as e:
        context = error_capture.capture(
            error=e,
            tool_name=tool_name,
            parameters=params,
            state={"current_step": "execution"}
        )

        logger.error(
            f"Tool failed: {context.error_type}",
            error_context=asdict(context)
        )

        return {
            "success": False,
            "error": context.error_message,
            "error_id": context.request_id
        }
```

## Step 4: Debug mode for tools

Add debug mode to tools:

```python
from functools import wraps
from typing import Callable, Any
import inspect

class DebugMode:
    """Debug mode for MCP tools."""

    enabled: bool = False

    @classmethod
    def enable(cls):
        cls.enabled = True

    @classmethod
    def disable(cls):
        cls.enabled = False

def debuggable(func: Callable) -> Callable:
    """Decorator to add debug capabilities to tools."""

    @wraps(func)
    def wrapper(*args, **kwargs):
        if not DebugMode.enabled:
            return func(*args, **kwargs)

        # Capture input
        sig = inspect.signature(func)
        bound = sig.bind(*args, **kwargs)
        bound.apply_defaults()

        debug_info = {
            "function": func.__name__,
            "input": dict(bound.arguments),
            "start_time": time.time()
        }

        try:
            result = func(*args, **kwargs)

            debug_info["output"] = result
            debug_info["duration_ms"] = (time.time() - debug_info["start_time"]) * 1000
            debug_info["status"] = "success"

            logger.debug("Tool execution debug", **debug_info)

            return result

        except Exception as e:
            debug_info["error"] = str(e)
            debug_info["error_type"] = type(e).__name__
            debug_info["traceback"] = traceback.format_exc()
            debug_info["status"] = "error"

            logger.debug("Tool execution debug", **debug_info)
            raise

    return wrapper

class ToolDebugger:
    """Interactive debugger for tools."""

    def __init__(self, tool_registry: Dict[str, Callable]):
        self.tools = tool_registry
        self.breakpoints: Dict[str, List[Callable]] = {}
        self.execution_history: List[Dict] = []

    def add_breakpoint(
        self,
        tool_name: str,
        condition: Callable[[dict], bool] = None
    ):
        """Add breakpoint to tool."""
        if tool_name not in self.breakpoints:
            self.breakpoints[tool_name] = []

        self.breakpoints[tool_name].append(condition or (lambda x: True))

    def execute_with_debug(
        self,
        tool_name: str,
        params: dict,
        step_mode: bool = False
    ) -> dict:
        """Execute tool with debugging."""
        execution = {
            "tool": tool_name,
            "params": params,
            "steps": []
        }

        # Check breakpoints
        if tool_name in self.breakpoints:
            for condition in self.breakpoints[tool_name]:
                if condition(params):
                    execution["steps"].append({
                        "type": "breakpoint",
                        "message": f"Breakpoint hit for {tool_name}"
                    })

                    if step_mode:
                        # In real implementation, pause for user input
                        pass

        # Execute
        try:
            result = self.tools[tool_name](**params)
            execution["result"] = result
            execution["status"] = "success"
        except Exception as e:
            execution["error"] = str(e)
            execution["status"] = "error"

        self.execution_history.append(execution)
        return execution

    def replay_execution(self, index: int) -> dict:
        """Replay a previous execution."""
        if index >= len(self.execution_history):
            raise IndexError("Execution not found")

        execution = self.execution_history[index]
        return self.execute_with_debug(
            execution["tool"],
            execution["params"]
        )

# Usage
@debuggable
def query_database(query: str, limit: int = 100) -> list:
    return db.execute(query, limit=limit)

# Enable debug mode
DebugMode.enable()
result = query_database("SELECT * FROM users", limit=10)
```

## Step 5: Request replay

Replay failed requests for debugging:

```python
import json
from pathlib import Path
from datetime import datetime
from typing import List, Optional

@dataclass
class RecordedRequest:
    """Recorded request for replay."""
    id: str
    timestamp: str
    tool_name: str
    parameters: dict
    result: Optional[dict]
    error: Optional[str]
    duration_ms: float

class RequestRecorder:
    """Record and replay tool requests."""

    def __init__(self, storage_path: str = "./debug_recordings"):
        self.storage_path = Path(storage_path)
        self.storage_path.mkdir(exist_ok=True)
        self.recordings: List[RecordedRequest] = []

    def record(
        self,
        tool_name: str,
        parameters: dict,
        result: dict = None,
        error: str = None,
        duration_ms: float = 0
    ) -> RecordedRequest:
        """Record a request."""
        recording = RecordedRequest(
            id=str(uuid.uuid4()),
            timestamp=datetime.utcnow().isoformat(),
            tool_name=tool_name,
            parameters=parameters,
            result=result,
            error=error,
            duration_ms=duration_ms
        )

        self.recordings.append(recording)
        self._save_recording(recording)

        return recording

    def _save_recording(self, recording: RecordedRequest):
        """Save recording to file."""
        filename = f"{recording.id}.json"
        filepath = self.storage_path / filename

        with open(filepath, 'w') as f:
            json.dump(asdict(recording), f, indent=2)

    def load_recording(self, recording_id: str) -> RecordedRequest:
        """Load recording from file."""
        filepath = self.storage_path / f"{recording_id}.json"

        with open(filepath) as f:
            data = json.load(f)

        return RecordedRequest(**data)

    def replay(
        self,
        recording_id: str,
        tool_executor: Callable
    ) -> dict:
        """Replay a recorded request."""
        recording = self.load_recording(recording_id)

        start = time.time()
        try:
            result = tool_executor(
                recording.tool_name,
                recording.parameters
            )

            return {
                "original_result": recording.result,
                "replay_result": result,
                "original_error": recording.error,
                "replay_error": None,
                "original_duration": recording.duration_ms,
                "replay_duration": (time.time() - start) * 1000,
                "match": result == recording.result
            }
        except Exception as e:
            return {
                "original_result": recording.result,
                "replay_result": None,
                "original_error": recording.error,
                "replay_error": str(e),
                "original_duration": recording.duration_ms,
                "replay_duration": (time.time() - start) * 1000,
                "match": False
            }

    def get_failed_recordings(self) -> List[RecordedRequest]:
        """Get all failed recordings."""
        return [r for r in self.recordings if r.error]

# Usage
recorder = RequestRecorder()

def execute_with_recording(tool_name: str, params: dict) -> dict:
    start = time.time()

    try:
        result = tool_registry[tool_name](**params)
        recorder.record(
            tool_name=tool_name,
            parameters=params,
            result=result,
            duration_ms=(time.time() - start) * 1000
        )
        return result
    except Exception as e:
        recorder.record(
            tool_name=tool_name,
            parameters=params,
            error=str(e),
            duration_ms=(time.time() - start) * 1000
        )
        raise

# Replay failed request
failed = recorder.get_failed_recordings()[0]
comparison = recorder.replay(failed.id, execute_tool)
```

## Step 6: Debug dashboard

Aggregate debugging information:

```python
from dataclasses import dataclass
from typing import Dict, List, Any

@dataclass
class DebugDashboard:
    """Debugging dashboard data."""
    error_summary: Dict[str, int]
    slow_tools: List[Dict[str, Any]]
    recent_errors: List[ErrorContext]
    trace_summary: Dict[str, Any]
    health_status: Dict[str, str]

class DebugAggregator:
    """Aggregate debug information."""

    def __init__(
        self,
        tracer: Tracer,
        error_capture: ErrorCapture,
        logger: StructuredLogger
    ):
        self.tracer = tracer
        self.error_capture = error_capture
        self.logger = logger
        self.tool_metrics: Dict[str, Dict] = {}

    def record_execution(
        self,
        tool_name: str,
        duration_ms: float,
        success: bool
    ):
        """Record tool execution metrics."""
        if tool_name not in self.tool_metrics:
            self.tool_metrics[tool_name] = {
                "total_calls": 0,
                "failures": 0,
                "total_duration": 0,
                "max_duration": 0
            }

        metrics = self.tool_metrics[tool_name]
        metrics["total_calls"] += 1
        metrics["total_duration"] += duration_ms
        metrics["max_duration"] = max(metrics["max_duration"], duration_ms)

        if not success:
            metrics["failures"] += 1

    def get_dashboard(self) -> DebugDashboard:
        """Get debugging dashboard."""
        # Error summary
        error_patterns = self.error_capture.analyze_patterns()

        # Slow tools
        slow_tools = []
        for tool, metrics in self.tool_metrics.items():
            avg_duration = metrics["total_duration"] / max(metrics["total_calls"], 1)
            if avg_duration > 1000:  # > 1 second
                slow_tools.append({
                    "tool": tool,
                    "avg_duration_ms": avg_duration,
                    "max_duration_ms": metrics["max_duration"],
                    "total_calls": metrics["total_calls"]
                })

        slow_tools.sort(key=lambda x: x["avg_duration_ms"], reverse=True)

        # Health status
        health = {}
        for tool, metrics in self.tool_metrics.items():
            failure_rate = metrics["failures"] / max(metrics["total_calls"], 1)
            if failure_rate > 0.5:
                health[tool] = "critical"
            elif failure_rate > 0.1:
                health[tool] = "degraded"
            else:
                health[tool] = "healthy"

        return DebugDashboard(
            error_summary=error_patterns["by_error_type"],
            slow_tools=slow_tools[:10],
            recent_errors=self.error_capture.get_recent_errors(limit=20),
            trace_summary={
                "total_spans": len(self.tracer.spans),
                "error_spans": len([s for s in self.tracer.spans if s.status == "error"])
            },
            health_status=health
        )
```

## Summary

MCP debugging patterns:

1. **Structured logging** - JSON logs with context
2. **Distributed tracing** - Cross-tool request tracing
3. **Error capture** - Full context on failures
4. **Debug mode** - Step-through execution
5. **Request replay** - Reproduce issues
6. **Debug dashboard** - Aggregate insights

Build tools with [Gantz](https://gantz.run), debug with confidence.

Visibility beats guessing.

## Related reading

- [Agent Error Handling](/post/agent-error-handling/) - Handle errors gracefully
- [MCP Observability](/post/mcp-observability/) - Monitor tools
- [MCP Testing](/post/mcp-testing/) - Test before production

---

*How do you debug your tools? Share your techniques.*
