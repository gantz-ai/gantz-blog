+++
title = "MCP Logging: Debug AI Agent Tool Calls"
image = "images/mcp-logging.webp"
date = 2025-11-12
description = "Implement comprehensive logging for MCP servers. Track tool calls, debug agent behavior, and monitor performance with structured logs."
draft = false
tags = ['mcp', 'debugging', 'observability']
voice = false
summary = "Set up comprehensive logging for MCP servers to track tool calls, parameters, execution times, and failures with structured JSON output. This guide covers context propagation with request IDs, sensitive data sanitization, performance logging, log aggregation patterns, and setting up alerts for errors and anomalies."

[howto]
name = "Set Up MCP Server Logging"
totalTime = 20
[[howto.steps]]
name = "Configure structured logging"
text = "Set up JSON logging with consistent fields for tool calls."
[[howto.steps]]
name = "Log request and response"
text = "Capture incoming tool calls and their results."
[[howto.steps]]
name = "Add context tracking"
text = "Include request IDs and session info for tracing."
[[howto.steps]]
name = "Set up log aggregation"
text = "Send logs to a central location for analysis."
[[howto.steps]]
name = "Create alerts"
text = "Set up notifications for errors and anomalies."
+++


Your agent failed. Something went wrong.

But what? When? Why?

Without logs, you're debugging blind.

## Why log MCP calls?

AI agents are black boxes. They:
- Decide which tools to call
- Choose parameters autonomously
- Chain multiple calls together
- Sometimes fail mysteriously

Logs give you visibility:
- What tools were called
- With what parameters
- What they returned
- How long they took
- Where they failed

## What to log

### Essential fields

Every log entry should include:

```json
{
  "timestamp": "2025-01-06T10:30:00.000Z",
  "level": "info",
  "request_id": "req_abc123",
  "session_id": "sess_xyz789",
  "tool": "read_file",
  "params": {"path": "config.json"},
  "duration_ms": 45,
  "status": "success",
  "result_size": 1024
}
```

### Tool call lifecycle

Log each phase:

```text
1. Request received
2. Validation started
3. Execution started
4. Execution completed (or failed)
5. Response sent
```

```python
import logging
import time
import uuid

logger = logging.getLogger("mcp")

def log_tool_call(tool_name, params):
    request_id = str(uuid.uuid4())[:8]
    start_time = time.time()

    logger.info("tool_call_started", extra={
        "request_id": request_id,
        "tool": tool_name,
        "params": sanitize_params(params)
    })

    try:
        result = execute_tool(tool_name, params)
        duration = (time.time() - start_time) * 1000

        logger.info("tool_call_completed", extra={
            "request_id": request_id,
            "tool": tool_name,
            "duration_ms": duration,
            "result_size": len(str(result)),
            "status": "success"
        })

        return result

    except Exception as e:
        duration = (time.time() - start_time) * 1000

        logger.error("tool_call_failed", extra={
            "request_id": request_id,
            "tool": tool_name,
            "duration_ms": duration,
            "error": str(e),
            "error_type": type(e).__name__,
            "status": "error"
        })

        raise
```

## Structured logging

Use JSON logs for easy parsing:

```python
import json
import logging
import sys

class JSONFormatter(logging.Formatter):
    def format(self, record):
        log_data = {
            "timestamp": self.formatTime(record),
            "level": record.levelname,
            "message": record.getMessage(),
            "logger": record.name,
        }

        # Add extra fields
        if hasattr(record, "request_id"):
            log_data["request_id"] = record.request_id
        if hasattr(record, "tool"):
            log_data["tool"] = record.tool
        if hasattr(record, "params"):
            log_data["params"] = record.params
        if hasattr(record, "duration_ms"):
            log_data["duration_ms"] = record.duration_ms
        if hasattr(record, "error"):
            log_data["error"] = record.error

        return json.dumps(log_data)

# Setup
handler = logging.StreamHandler(sys.stdout)
handler.setFormatter(JSONFormatter())
logger = logging.getLogger("mcp")
logger.addHandler(handler)
logger.setLevel(logging.INFO)
```

Output:
```json
{"timestamp": "2025-01-06 10:30:00", "level": "INFO", "message": "tool_call_started", "tool": "read_file", "params": {"path": "config.json"}}
{"timestamp": "2025-01-06 10:30:00", "level": "INFO", "message": "tool_call_completed", "tool": "read_file", "duration_ms": 45, "status": "success"}
```

## Context propagation

Track requests across the system:

```python
from contextvars import ContextVar

request_context = ContextVar('request_context', default={})

class RequestContext:
    def __init__(self, request_id=None, session_id=None, client_id=None):
        self.request_id = request_id or str(uuid.uuid4())[:8]
        self.session_id = session_id
        self.client_id = client_id

    def __enter__(self):
        self.token = request_context.set({
            "request_id": self.request_id,
            "session_id": self.session_id,
            "client_id": self.client_id
        })
        return self

    def __exit__(self, *args):
        request_context.reset(self.token)

class ContextualLogger:
    def __init__(self, logger):
        self.logger = logger

    def _log(self, level, message, **kwargs):
        ctx = request_context.get()
        kwargs.update(ctx)
        getattr(self.logger, level)(message, extra=kwargs)

    def info(self, message, **kwargs):
        self._log("info", message, **kwargs)

    def error(self, message, **kwargs):
        self._log("error", message, **kwargs)

# Usage
logger = ContextualLogger(logging.getLogger("mcp"))

@app.route("/mcp/tools/call", methods=["POST"])
def handle_tool_call():
    with RequestContext(
        request_id=request.headers.get("X-Request-ID"),
        session_id=request.headers.get("X-Session-ID"),
        client_id=get_client_id(request)
    ):
        # All logs in this context include request_id, session_id, client_id
        logger.info("Processing request")
        result = process_tool_call(request.json)
        logger.info("Request completed")
        return jsonify(result)
```

## Sensitive data handling

Never log secrets:

```python
SENSITIVE_KEYS = {"password", "api_key", "token", "secret", "credential"}

def sanitize_params(params):
    """Remove sensitive data from params before logging."""
    if not isinstance(params, dict):
        return params

    sanitized = {}
    for key, value in params.items():
        if any(s in key.lower() for s in SENSITIVE_KEYS):
            sanitized[key] = "[REDACTED]"
        elif isinstance(value, dict):
            sanitized[key] = sanitize_params(value)
        elif isinstance(value, str) and len(value) > 1000:
            sanitized[key] = f"[STRING:{len(value)} chars]"
        else:
            sanitized[key] = value

    return sanitized

# Before logging params
logger.info("tool_call", extra={
    "params": sanitize_params(params)  # Safe to log
})
```

## Log levels

Use appropriate levels:

```python
# DEBUG: Detailed information for debugging
logger.debug("Parsing tool parameters", extra={"raw_params": params})

# INFO: Normal operations
logger.info("Tool call completed", extra={"tool": tool, "duration_ms": 45})

# WARNING: Something unexpected but handled
logger.warning("Tool returned empty result", extra={"tool": tool})

# ERROR: Something failed
logger.error("Tool execution failed", extra={"tool": tool, "error": str(e)})

# CRITICAL: System-wide failure
logger.critical("MCP server shutting down", extra={"reason": "out of memory"})
```

## Performance logging

Track timing and resources:

```python
import psutil
import time
from contextlib import contextmanager

@contextmanager
def log_performance(operation):
    start_time = time.time()
    start_memory = psutil.Process().memory_info().rss

    try:
        yield
    finally:
        duration = (time.time() - start_time) * 1000
        memory_delta = psutil.Process().memory_info().rss - start_memory

        logger.info("performance", extra={
            "operation": operation,
            "duration_ms": duration,
            "memory_delta_bytes": memory_delta
        })

# Usage
with log_performance("search_code"):
    results = search_code(query)
```

## Log aggregation

Send logs to central location:

### Using structlog with multiple outputs

```python
import structlog

structlog.configure(
    processors=[
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.processors.JSONRenderer()
    ],
    wrapper_class=structlog.BoundLogger,
    context_class=dict,
    logger_factory=structlog.PrintLoggerFactory(),
)

logger = structlog.get_logger()
```

### Send to external service

```python
import requests
from queue import Queue
from threading import Thread

class LogShipper:
    def __init__(self, endpoint, batch_size=100):
        self.endpoint = endpoint
        self.batch_size = batch_size
        self.queue = Queue()
        self.start_worker()

    def start_worker(self):
        def worker():
            batch = []
            while True:
                log = self.queue.get()
                batch.append(log)

                if len(batch) >= self.batch_size:
                    self.ship(batch)
                    batch = []

        Thread(target=worker, daemon=True).start()

    def ship(self, logs):
        try:
            requests.post(self.endpoint, json=logs, timeout=5)
        except Exception as e:
            print(f"Failed to ship logs: {e}")

    def log(self, data):
        self.queue.put(data)

shipper = LogShipper("https://logs.example.com/ingest")
```

## Alerting

Set up alerts for important events:

```python
from dataclasses import dataclass
from typing import Callable

@dataclass
class AlertRule:
    name: str
    condition: Callable
    action: Callable

class AlertManager:
    def __init__(self):
        self.rules = []

    def add_rule(self, rule: AlertRule):
        self.rules.append(rule)

    def check(self, log_entry):
        for rule in self.rules:
            if rule.condition(log_entry):
                rule.action(log_entry, rule.name)

def send_slack_alert(log_entry, rule_name):
    requests.post(SLACK_WEBHOOK, json={
        "text": f"Alert: {rule_name}\n```{json.dumps(log_entry, indent=2)}```"
    })

alerts = AlertManager()

# Alert on errors
alerts.add_rule(AlertRule(
    name="Tool Error",
    condition=lambda log: log.get("level") == "ERROR",
    action=send_slack_alert
))

# Alert on slow calls
alerts.add_rule(AlertRule(
    name="Slow Tool Call",
    condition=lambda log: log.get("duration_ms", 0) > 5000,
    action=send_slack_alert
))

# Alert on specific tools
alerts.add_rule(AlertRule(
    name="Dangerous Tool Used",
    condition=lambda log: log.get("tool") in ["run_command", "delete_file"],
    action=send_slack_alert
))
```

## Quick setup with Gantz

[Gantz](https://gantz.run) includes built-in logging:

```yaml
# gantz.yaml
name: my-mcp-server

logging:
  level: info
  format: json
  output: stdout
  include_params: true
  redact_sensitive: true

tools:
  - name: read_file
    # ...
```

All tool calls automatically logged with request IDs, timing, and sanitized parameters.

## Querying logs

With structured JSON logs, query easily:

```bash
# Find all errors
cat logs.json | jq 'select(.level == "ERROR")'

# Find slow tool calls
cat logs.json | jq 'select(.duration_ms > 1000)'

# Count calls per tool
cat logs.json | jq -r '.tool' | sort | uniq -c | sort -rn

# Find calls from specific client
cat logs.json | jq 'select(.client_id == "client_123")'

# Average duration per tool
cat logs.json | jq -s 'group_by(.tool) | map({tool: .[0].tool, avg_ms: (map(.duration_ms) | add / length)})'
```

## Best practices

1. **Always use structured logging** - JSON, not plain text
2. **Include request IDs** - Trace requests across calls
3. **Sanitize sensitive data** - Never log secrets
4. **Log at appropriate levels** - Don't spam INFO with DEBUG
5. **Include timing** - Duration is crucial for debugging
6. **Set up alerting** - Know when things break
7. **Retain logs** - Keep them for debugging past issues
8. **Sample high-volume logs** - Don't log every request in production

## Summary

Good logging transforms debugging from guesswork to science:

- **Structured logs** make querying possible
- **Request IDs** let you trace flows
- **Timing data** reveals performance issues
- **Sanitization** keeps secrets safe
- **Alerts** notify you of problems

When your agent fails at 3 AM, logs are your only witness. Make them count.

## Related reading

- [Debugging Agent Thoughts](/post/debugging-thoughts/) - Understand agent behavior
- [Agent Observability](/post/agent-observability/) - Track every decision
- [Error Recovery Patterns](/post/error-recovery/) - Handle failures

---

*What logging setup do you use for your MCP servers? Share your stack.*
