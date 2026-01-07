+++
title = "Agent Observability: Debug AI in Production"
image = "/images/agent-observability.png"
date = 2025-11-20
description = "Monitor and debug AI agents in production. Implement logging, tracing, metrics, and alerting for agent systems using MCP tools."
draft = false
tags = ['mcp', 'architecture', 'observability']
voice = false

[howto]
name = "Build Agent Observability"
totalTime = 35
[[howto.steps]]
name = "Implement logging"
text = "Create structured logs for agent activities."
[[howto.steps]]
name = "Add tracing"
text = "Track requests through multi-step agent workflows."
[[howto.steps]]
name = "Build metrics"
text = "Measure latency, success rates, and costs."
[[howto.steps]]
name = "Create dashboards"
text = "Visualize agent performance and health."
[[howto.steps]]
name = "Set up alerting"
text = "Detect and alert on agent failures."
+++


AI agents fail silently. You won't know until users complain.

Unless you instrument them properly.

Observability for AI. Here's how.

## Why agent observability matters

Agents are complex:
- Multiple LLM calls
- Tool executions
- Non-deterministic outputs
- Hard to reproduce issues

Without observability:
- No idea why responses are bad
- Can't track costs
- Can't identify slow paths
- Debug by guess and check

With observability:
- See exactly what happened
- Track every decision
- Measure performance
- Alert on issues automatically

## The three pillars

1. **Logs**: What happened
2. **Traces**: How it happened (request flow)
3. **Metrics**: How often and how fast

## Step 1: Structured logging

Using [Gantz](https://gantz.run):

```yaml
# gantz.yaml
name: agent-observability

tools:
  - name: log_event
    description: Log an agent event
    parameters:
      - name: level
        type: string
        default: "info"
        description: "debug, info, warn, error"
      - name: event_type
        type: string
        required: true
      - name: message
        type: string
        required: true
      - name: metadata
        type: string
        description: JSON metadata
    script:
      command: python
      args: ["scripts/log_event.py", "{{level}}", "{{event_type}}", "{{metadata}}"]
      stdin: "{{message}}"

  - name: start_span
    description: Start a trace span
    parameters:
      - name: trace_id
        type: string
        required: true
      - name: span_name
        type: string
        required: true
      - name: parent_span_id
        type: string
    script:
      command: python
      args: ["scripts/start_span.py", "{{trace_id}}", "{{span_name}}", "{{parent_span_id}}"]

  - name: end_span
    description: End a trace span
    parameters:
      - name: span_id
        type: string
        required: true
      - name: status
        type: string
        default: "ok"
      - name: metadata
        type: string
    script:
      command: python
      args: ["scripts/end_span.py", "{{span_id}}", "{{status}}", "{{metadata}}"]

  - name: record_metric
    description: Record a metric value
    parameters:
      - name: metric_name
        type: string
        required: true
      - name: value
        type: number
        required: true
      - name: labels
        type: string
        description: JSON labels
    script:
      command: python
      args: ["scripts/record_metric.py", "{{metric_name}}", "{{value}}", "{{labels}}"]

  - name: get_trace
    description: Get a complete trace
    parameters:
      - name: trace_id
        type: string
        required: true
    script:
      command: python
      args: ["scripts/get_trace.py", "{{trace_id}}"]

  - name: query_logs
    description: Query recent logs
    parameters:
      - name: event_type
        type: string
      - name: level
        type: string
      - name: since_minutes
        type: integer
        default: 60
    script:
      command: python
      args: ["scripts/query_logs.py", "{{event_type}}", "{{level}}", "{{since_minutes}}"]
```

Logging script:

```python
# scripts/log_event.py
import sys
import json
import logging
from datetime import datetime
from pythonjsonlogger import jsonlogger

# Configure JSON logging
logger = logging.getLogger("agent")
handler = logging.StreamHandler()
formatter = jsonlogger.JsonFormatter(
    fmt='%(timestamp)s %(level)s %(event_type)s %(message)s'
)
handler.setFormatter(formatter)
logger.addHandler(handler)
logger.setLevel(logging.DEBUG)

def log_event(level: str, event_type: str, message: str, metadata: dict = None):
    """Log a structured event."""

    log_data = {
        "timestamp": datetime.utcnow().isoformat(),
        "event_type": event_type,
        "message": message,
        **(metadata or {})
    }

    log_level = getattr(logging, level.upper(), logging.INFO)
    logger.log(log_level, message, extra=log_data)

    # Also store in time-series DB for querying
    store_log(log_data)

    return {"logged": True, "event_type": event_type}

def store_log(log_data: dict):
    """Store log in database for later querying."""
    import redis
    r = redis.Redis()

    # Store in sorted set by timestamp
    r.zadd(
        f"logs:{log_data['event_type']}",
        {json.dumps(log_data): datetime.utcnow().timestamp()}
    )

    # Keep only last 24 hours
    cutoff = datetime.utcnow().timestamp() - 86400
    r.zremrangebyscore(f"logs:{log_data['event_type']}", 0, cutoff)

if __name__ == "__main__":
    level = sys.argv[1]
    event_type = sys.argv[2]
    metadata = json.loads(sys.argv[3]) if len(sys.argv) > 3 and sys.argv[3] else {}
    message = sys.stdin.read()

    result = log_event(level, event_type, message, metadata)
    print(json.dumps(result))
```

```bash
gantz run --auth
```

## Step 2: Distributed tracing

```python
# scripts/start_span.py
import sys
import json
import uuid
import redis
from datetime import datetime

r = redis.Redis()

def start_span(trace_id: str, span_name: str, parent_span_id: str = None) -> dict:
    """Start a new trace span."""

    span_id = str(uuid.uuid4())[:8]

    span = {
        "span_id": span_id,
        "trace_id": trace_id,
        "parent_span_id": parent_span_id,
        "name": span_name,
        "start_time": datetime.utcnow().isoformat(),
        "status": "in_progress"
    }

    r.hset(f"span:{span_id}", mapping=span)
    r.sadd(f"trace:{trace_id}:spans", span_id)

    return span

if __name__ == "__main__":
    trace_id = sys.argv[1]
    span_name = sys.argv[2]
    parent_span_id = sys.argv[3] if len(sys.argv) > 3 and sys.argv[3] != "None" else None

    result = start_span(trace_id, span_name, parent_span_id)
    print(json.dumps(result))
```

```python
# scripts/end_span.py
import sys
import json
import redis
from datetime import datetime

r = redis.Redis()

def end_span(span_id: str, status: str = "ok", metadata: dict = None) -> dict:
    """End a trace span."""

    end_time = datetime.utcnow()

    # Get span
    span = r.hgetall(f"span:{span_id}")
    if not span:
        return {"error": "Span not found"}

    start_time = datetime.fromisoformat(span[b"start_time"].decode())
    duration_ms = (end_time - start_time).total_seconds() * 1000

    # Update span
    updates = {
        "end_time": end_time.isoformat(),
        "duration_ms": duration_ms,
        "status": status
    }
    if metadata:
        updates["metadata"] = json.dumps(metadata)

    r.hset(f"span:{span_id}", mapping=updates)

    return {
        "span_id": span_id,
        "duration_ms": duration_ms,
        "status": status
    }

if __name__ == "__main__":
    span_id = sys.argv[1]
    status = sys.argv[2] if len(sys.argv) > 2 else "ok"
    metadata = json.loads(sys.argv[3]) if len(sys.argv) > 3 and sys.argv[3] else None

    result = end_span(span_id, status, metadata)
    print(json.dumps(result))
```

## Step 3: Instrumented agent

```python
import anthropic
import uuid
from typing import Optional
from functools import wraps
import time

MCP_URL = "https://agent-observability.gantz.run/sse"
MCP_TOKEN = "gtz_abc123"

client = anthropic.Anthropic()

class InstrumentedAgent:
    """Agent with full observability instrumentation."""

    def __init__(self, agent_name: str):
        self.agent_name = agent_name
        self.current_trace_id = None
        self.current_span_id = None

    def _log(self, level: str, event_type: str, message: str, **metadata):
        """Log an event."""
        metadata["agent_name"] = self.agent_name
        metadata["trace_id"] = self.current_trace_id

        response = client.messages.create(
            model="claude-sonnet-4-20250514",
            max_tokens=100,
            messages=[{
                "role": "user",
                "content": f"Use log_event: level={level}, event_type={event_type}, message={message}, metadata={json.dumps(metadata)}"
            }],
            tools=[{"type": "mcp", "server_url": MCP_URL, "token": MCP_TOKEN}]
        )

    def _start_span(self, span_name: str, parent_span_id: str = None) -> str:
        """Start a trace span."""
        response = client.messages.create(
            model="claude-sonnet-4-20250514",
            max_tokens=100,
            messages=[{
                "role": "user",
                "content": f"Use start_span: trace_id={self.current_trace_id}, span_name={span_name}, parent_span_id={parent_span_id}"
            }],
            tools=[{"type": "mcp", "server_url": MCP_URL, "token": MCP_TOKEN}]
        )

        # Extract span_id from response
        for content in response.content:
            if hasattr(content, 'text'):
                result = json.loads(content.text)
                return result.get("span_id")

        return None

    def _end_span(self, span_id: str, status: str = "ok", **metadata):
        """End a trace span."""
        response = client.messages.create(
            model="claude-sonnet-4-20250514",
            max_tokens=100,
            messages=[{
                "role": "user",
                "content": f"Use end_span: span_id={span_id}, status={status}, metadata={json.dumps(metadata)}"
            }],
            tools=[{"type": "mcp", "server_url": MCP_URL, "token": MCP_TOKEN}]
        )

    def _record_metric(self, metric_name: str, value: float, **labels):
        """Record a metric."""
        labels["agent_name"] = self.agent_name

        response = client.messages.create(
            model="claude-sonnet-4-20250514",
            max_tokens=100,
            messages=[{
                "role": "user",
                "content": f"Use record_metric: metric_name={metric_name}, value={value}, labels={json.dumps(labels)}"
            }],
            tools=[{"type": "mcp", "server_url": MCP_URL, "token": MCP_TOKEN}]
        )

    def run(self, task: str) -> str:
        """Run the agent with full instrumentation."""

        # Start trace
        self.current_trace_id = str(uuid.uuid4())[:8]
        root_span_id = self._start_span("agent_request")

        self._log("info", "agent.request.start", f"Processing request: {task[:100]}")

        start_time = time.time()
        input_tokens = 0
        output_tokens = 0
        tool_calls = 0

        try:
            # LLM call span
            llm_span_id = self._start_span("llm_call", root_span_id)

            response = client.messages.create(
                model="claude-sonnet-4-20250514",
                max_tokens=4096,
                system=f"You are {self.agent_name}. Complete the task.",
                messages=[{"role": "user", "content": task}],
                tools=[{"type": "mcp", "server_url": MCP_URL, "token": MCP_TOKEN}]
            )

            # Track token usage
            input_tokens = response.usage.input_tokens
            output_tokens = response.usage.output_tokens

            self._end_span(llm_span_id, "ok", tokens=input_tokens + output_tokens)

            # Process tool calls
            for content in response.content:
                if hasattr(content, 'tool_use'):
                    tool_calls += 1
                    tool_span_id = self._start_span(f"tool.{content.tool_use.name}", root_span_id)
                    # Tool execution happens here
                    self._end_span(tool_span_id, "ok")

            # Extract result
            result = ""
            for content in response.content:
                if hasattr(content, 'text'):
                    result += content.text

            # Success metrics
            duration = time.time() - start_time
            self._record_metric("agent.request.duration_ms", duration * 1000)
            self._record_metric("agent.tokens.input", input_tokens)
            self._record_metric("agent.tokens.output", output_tokens)
            self._record_metric("agent.tool_calls", tool_calls)

            self._log("info", "agent.request.success", f"Request completed in {duration:.2f}s")
            self._end_span(root_span_id, "ok", duration_ms=duration * 1000)

            return result

        except Exception as e:
            duration = time.time() - start_time

            self._log("error", "agent.request.error", str(e), error_type=type(e).__name__)
            self._record_metric("agent.request.errors", 1, error_type=type(e).__name__)
            self._end_span(root_span_id, "error", error=str(e))

            raise
```

## Step 4: Metrics collection

```python
# scripts/record_metric.py
import sys
import json
from prometheus_client import Counter, Histogram, Gauge, CollectorRegistry, push_to_gateway

# Metrics registry
registry = CollectorRegistry()

# Define metrics
request_duration = Histogram(
    'agent_request_duration_seconds',
    'Agent request duration',
    ['agent_name'],
    registry=registry
)

request_errors = Counter(
    'agent_request_errors_total',
    'Total agent errors',
    ['agent_name', 'error_type'],
    registry=registry
)

tokens_used = Counter(
    'agent_tokens_total',
    'Total tokens used',
    ['agent_name', 'token_type'],
    registry=registry
)

active_requests = Gauge(
    'agent_active_requests',
    'Active agent requests',
    ['agent_name'],
    registry=registry
)

def record_metric(metric_name: str, value: float, labels: dict = None):
    """Record a metric value."""

    labels = labels or {}
    agent_name = labels.get('agent_name', 'unknown')

    if metric_name == "agent.request.duration_ms":
        request_duration.labels(agent_name=agent_name).observe(value / 1000)

    elif metric_name == "agent.request.errors":
        request_errors.labels(
            agent_name=agent_name,
            error_type=labels.get('error_type', 'unknown')
        ).inc()

    elif metric_name == "agent.tokens.input":
        tokens_used.labels(agent_name=agent_name, token_type='input').inc(value)

    elif metric_name == "agent.tokens.output":
        tokens_used.labels(agent_name=agent_name, token_type='output').inc(value)

    # Push to Prometheus gateway (for batch jobs) or expose via HTTP
    try:
        push_to_gateway('localhost:9091', job='agent_metrics', registry=registry)
    except:
        pass  # Ignore if gateway not available

    return {"recorded": True, "metric": metric_name, "value": value}

if __name__ == "__main__":
    metric_name = sys.argv[1]
    value = float(sys.argv[2])
    labels = json.loads(sys.argv[3]) if len(sys.argv) > 3 and sys.argv[3] else {}

    result = record_metric(metric_name, value, labels)
    print(json.dumps(result))
```

## Step 5: Dashboard and alerting

```python
from flask import Flask, jsonify, render_template
import redis

app = Flask(__name__)
r = redis.Redis()

@app.route("/api/metrics")
def get_metrics():
    """Get current metrics."""

    # Aggregate from Redis or metrics store
    metrics = {
        "requests_per_minute": calculate_rpm(),
        "error_rate": calculate_error_rate(),
        "avg_latency_ms": calculate_avg_latency(),
        "active_traces": count_active_traces(),
        "tokens_per_hour": calculate_token_usage()
    }

    return jsonify(metrics)

@app.route("/api/traces")
def list_traces():
    """List recent traces."""

    traces = []
    trace_keys = r.keys("trace:*:spans")

    for key in trace_keys[:50]:  # Last 50 traces
        trace_id = key.decode().split(":")[1]
        span_ids = r.smembers(key)

        spans = []
        for span_id in span_ids:
            span_data = r.hgetall(f"span:{span_id.decode()}")
            if span_data:
                spans.append({
                    k.decode(): v.decode() for k, v in span_data.items()
                })

        if spans:
            traces.append({
                "trace_id": trace_id,
                "spans": spans,
                "duration_ms": calculate_trace_duration(spans)
            })

    return jsonify(traces)

@app.route("/api/traces/<trace_id>")
def get_trace(trace_id: str):
    """Get a specific trace with all spans."""

    span_ids = r.smembers(f"trace:{trace_id}:spans")
    spans = []

    for span_id in span_ids:
        span_data = r.hgetall(f"span:{span_id.decode()}")
        if span_data:
            spans.append({
                k.decode(): v.decode() for k, v in span_data.items()
            })

    # Build span tree
    span_tree = build_span_tree(spans)

    return jsonify({
        "trace_id": trace_id,
        "spans": spans,
        "tree": span_tree
    })

@app.route("/api/logs")
def get_logs():
    """Get recent logs."""

    event_type = request.args.get("event_type", "*")
    level = request.args.get("level")
    limit = int(request.args.get("limit", 100))

    logs = []
    keys = r.keys(f"logs:{event_type}")

    for key in keys:
        entries = r.zrevrange(key, 0, limit - 1)
        for entry in entries:
            log_data = json.loads(entry)
            if not level or log_data.get("level") == level:
                logs.append(log_data)

    # Sort by timestamp
    logs.sort(key=lambda x: x.get("timestamp", ""), reverse=True)

    return jsonify(logs[:limit])

def calculate_rpm():
    """Calculate requests per minute."""
    # Implementation based on your metrics store
    return 0

def calculate_error_rate():
    """Calculate error rate percentage."""
    return 0

def calculate_avg_latency():
    """Calculate average latency in ms."""
    return 0

def count_active_traces():
    """Count currently active traces."""
    return len(r.keys("trace:*:spans"))

def calculate_token_usage():
    """Calculate tokens used per hour."""
    return 0

def calculate_trace_duration(spans: list) -> float:
    """Calculate total trace duration from spans."""
    if not spans:
        return 0

    start_times = [s.get("start_time") for s in spans if s.get("start_time")]
    end_times = [s.get("end_time") for s in spans if s.get("end_time")]

    if not start_times or not end_times:
        return 0

    # Find earliest start and latest end
    return 0  # Implement actual calculation

def build_span_tree(spans: list) -> dict:
    """Build hierarchical span tree."""
    # Implementation for tree building
    return {}

if __name__ == "__main__":
    app.run(port=8080)
```

## Step 6: Alerting

```python
import smtplib
from email.mime.text import MIMEText

def check_alerts():
    """Check for alert conditions."""

    alerts = []

    # High error rate
    error_rate = calculate_error_rate()
    if error_rate > 5:  # 5% threshold
        alerts.append({
            "severity": "critical",
            "title": "High Agent Error Rate",
            "message": f"Error rate is {error_rate}% (threshold: 5%)"
        })

    # High latency
    avg_latency = calculate_avg_latency()
    if avg_latency > 5000:  # 5 second threshold
        alerts.append({
            "severity": "warning",
            "title": "High Agent Latency",
            "message": f"Average latency is {avg_latency}ms (threshold: 5000ms)"
        })

    # Dead letter queue growth
    dlq_size = r.llen("dlq:agent_tasks")
    if dlq_size > 100:
        alerts.append({
            "severity": "warning",
            "title": "DLQ Growing",
            "message": f"Dead letter queue has {dlq_size} items"
        })

    # Send alerts
    for alert in alerts:
        send_alert(alert)

    return alerts

def send_alert(alert: dict):
    """Send an alert notification."""

    # Slack webhook
    import requests
    slack_webhook = os.environ.get("SLACK_WEBHOOK")
    if slack_webhook:
        emoji = "🚨" if alert["severity"] == "critical" else "⚠️"
        requests.post(slack_webhook, json={
            "text": f"{emoji} *{alert['title']}*\n{alert['message']}"
        })

    # PagerDuty for critical
    if alert["severity"] == "critical":
        pd_key = os.environ.get("PAGERDUTY_KEY")
        if pd_key:
            requests.post(
                "https://events.pagerduty.com/v2/enqueue",
                json={
                    "routing_key": pd_key,
                    "event_action": "trigger",
                    "payload": {
                        "summary": alert["title"],
                        "severity": "critical",
                        "source": "agent-observability"
                    }
                }
            )
```

## Summary

Agent observability:

1. **Structured logging** - What happened, searchable
2. **Distributed tracing** - Follow request flow
3. **Metrics** - Performance and health numbers
4. **Dashboards** - Visualize the state
5. **Alerting** - Know when things break

Build tools with [Gantz](https://gantz.run), debug AI in production.

See everything. Miss nothing.

## Related reading

- [Agent Testing](/post/agent-testing/) - Test strategies
- [Agent Deployment](/post/agent-deployment/) - Deploy to production
- [Multi-Agent Systems](/post/multi-agent-systems/) - Coordinate agents

---

*How do you monitor AI agents? Share your observability setup.*
