+++
title = "Event-Driven Agent Architecture for Real-Time Processing"
image = "/images/event-driven-agents.png"
date = 2025-11-16
description = "Build event-driven AI agents that react to events in real-time. Architecture patterns for scalable, responsive agent systems using MCP."
draft = false
tags = ['mcp', 'architecture', 'events']
voice = false

[howto]
name = "Build Event-Driven Agents"
totalTime = 35
[[howto.steps]]
name = "Design event architecture"
text = "Create event schemas and routing patterns."
[[howto.steps]]
name = "Implement event handlers"
text = "Build agents that respond to specific events."
[[howto.steps]]
name = "Add event sourcing"
text = "Track event history for debugging and replay."
[[howto.steps]]
name = "Build event pipeline"
text = "Connect events to agent processing."
[[howto.steps]]
name = "Handle failures"
text = "Implement retry logic and dead letter queues."
+++


Request-response is simple. But real-time is powerful.

AI agents that react to events. Instantly. Autonomously.

Here's the architecture.

## Why event-driven agents?

Traditional agent patterns:
- User asks → Agent responds
- Synchronous, blocking
- Limited to explicit requests

Event-driven agents:
- Event happens → Agent acts
- Asynchronous, non-blocking
- Continuous monitoring and response

## Use cases

- **Monitoring alerts**: Investigate and respond automatically
- **Code changes**: Review commits, update docs
- **Customer events**: Personalize responses in real-time
- **Security events**: Detect and respond to threats
- **Business events**: Trigger workflows automatically

## The architecture

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   Events    │───▶│   Router    │───▶│   Agents    │
│  (Webhooks, │    │  (Filter,   │    │  (Process,  │
│   Queues)   │    │   Route)    │    │   Act)      │
└─────────────┘    └─────────────┘    └─────────────┘
                          │
                   ┌──────▼──────┐
                   │ Event Store │
                   │  (History)  │
                   └─────────────┘
```

## Step 1: Event system design

Using [Gantz](https://gantz.run):

```yaml
# gantz.yaml
name: event-driven-agent

tools:
  - name: publish_event
    description: Publish an event to the event bus
    parameters:
      - name: event_type
        type: string
        required: true
      - name: payload
        type: string
        required: true
      - name: source
        type: string
        default: "unknown"
    script:
      command: python
      args: ["scripts/publish_event.py", "{{event_type}}", "{{source}}"]
      stdin: "{{payload}}"

  - name: subscribe_events
    description: Subscribe to events of a specific type
    parameters:
      - name: event_types
        type: string
        required: true
        description: Comma-separated event types
      - name: handler_id
        type: string
        required: true
    script:
      command: python
      args: ["scripts/subscribe.py", "{{event_types}}", "{{handler_id}}"]

  - name: get_event_history
    description: Get historical events for replay or analysis
    parameters:
      - name: event_type
        type: string
      - name: since
        type: string
        description: ISO timestamp
      - name: limit
        type: integer
        default: 100
    script:
      command: python
      args: ["scripts/get_events.py", "{{event_type}}", "{{since}}", "{{limit}}"]

  - name: acknowledge_event
    description: Mark an event as processed
    parameters:
      - name: event_id
        type: string
        required: true
      - name: status
        type: string
        default: "processed"
    script:
      command: python
      args: ["scripts/ack_event.py", "{{event_id}}", "{{status}}"]

  - name: retry_event
    description: Retry a failed event
    parameters:
      - name: event_id
        type: string
        required: true
    script:
      command: python
      args: ["scripts/retry_event.py", "{{event_id}}"]

  - name: get_dead_letters
    description: Get events that failed processing
    parameters:
      - name: limit
        type: integer
        default: 50
    script:
      command: python
      args: ["scripts/get_dlq.py", "{{limit}}"]
```

Event publisher script:

```python
# scripts/publish_event.py
import sys
import json
import redis
import uuid
from datetime import datetime

def publish_event(event_type: str, payload: str, source: str) -> dict:
    """Publish an event to Redis streams."""

    r = redis.Redis(host='localhost', port=6379, db=0)

    event = {
        "id": str(uuid.uuid4()),
        "type": event_type,
        "source": source,
        "timestamp": datetime.utcnow().isoformat(),
        "payload": payload
    }

    # Publish to Redis stream
    stream_key = f"events:{event_type}"
    r.xadd(stream_key, {"data": json.dumps(event)})

    # Also publish to general stream for routing
    r.xadd("events:all", {"data": json.dumps(event)})

    # Store in event store
    r.hset(f"event:{event['id']}", mapping={
        "type": event_type,
        "source": source,
        "timestamp": event["timestamp"],
        "payload": payload,
        "status": "pending"
    })

    return event

if __name__ == "__main__":
    event_type = sys.argv[1]
    source = sys.argv[2] if len(sys.argv) > 2 else "unknown"
    payload = sys.stdin.read()

    event = publish_event(event_type, payload, source)
    print(json.dumps(event, indent=2))
```

```bash
gantz run --auth
```

## Step 2: Event router

```python
import anthropic
import json
import redis
from typing import Dict, Callable, List
import threading

MCP_URL = "https://event-driven-agent.gantz.run/sse"
MCP_TOKEN = "gtz_abc123"

client = anthropic.Anthropic()

class EventRouter:
    """Routes events to appropriate handlers."""

    def __init__(self):
        self.redis = redis.Redis(host='localhost', port=6379, db=0)
        self.handlers: Dict[str, List[Callable]] = {}
        self.running = False

    def register_handler(self, event_type: str, handler: Callable):
        """Register a handler for an event type."""
        if event_type not in self.handlers:
            self.handlers[event_type] = []
        self.handlers[event_type].append(handler)

    def route_event(self, event: dict):
        """Route an event to registered handlers."""
        event_type = event.get("type", "unknown")

        # Find matching handlers
        handlers = self.handlers.get(event_type, [])
        handlers.extend(self.handlers.get("*", []))  # Wildcard handlers

        for handler in handlers:
            try:
                handler(event)
                self.mark_processed(event["id"])
            except Exception as e:
                self.handle_failure(event, str(e))

    def mark_processed(self, event_id: str):
        """Mark an event as successfully processed."""
        self.redis.hset(f"event:{event_id}", "status", "processed")

    def handle_failure(self, event: dict, error: str):
        """Handle failed event processing."""
        event_id = event["id"]

        # Get retry count
        retry_count = int(self.redis.hget(f"event:{event_id}", "retries") or 0)

        if retry_count < 3:
            # Retry
            self.redis.hincrby(f"event:{event_id}", "retries", 1)
            self.redis.hset(f"event:{event_id}", "status", "retry")
            self.redis.hset(f"event:{event_id}", "last_error", error)
            # Re-publish with delay
            self.schedule_retry(event, retry_count + 1)
        else:
            # Move to dead letter queue
            self.redis.hset(f"event:{event_id}", "status", "failed")
            self.redis.hset(f"event:{event_id}", "last_error", error)
            self.redis.lpush("dlq:events", json.dumps(event))

    def schedule_retry(self, event: dict, attempt: int):
        """Schedule event retry with exponential backoff."""
        delay = 2 ** attempt  # 2, 4, 8 seconds
        # In production, use a proper scheduler
        threading.Timer(delay, lambda: self.route_event(event)).start()

    def start(self):
        """Start consuming events."""
        self.running = True

        while self.running:
            # Read from all events stream
            events = self.redis.xread({"events:all": "$"}, block=1000, count=10)

            for stream, messages in events:
                for message_id, data in messages:
                    event = json.loads(data[b"data"])
                    self.route_event(event)

    def stop(self):
        """Stop consuming events."""
        self.running = False

router = EventRouter()
```

## Step 3: Agent event handlers

```python
EVENT_HANDLER_PROMPT = """You are an event-driven AI agent.

You receive events and take appropriate actions based on:
- Event type and content
- Context from the event source
- Historical patterns (if available)

Guidelines:
1. Analyze the event quickly
2. Determine if action is needed
3. Take action using available tools
4. Report what you did
5. Only process relevant events

Be efficient - events arrive continuously."""

def create_agent_handler(agent_name: str, instructions: str) -> Callable:
    """Create an event handler that uses an AI agent."""

    def handler(event: dict):
        response = client.messages.create(
            model="claude-sonnet-4-20250514",
            max_tokens=1024,
            system=f"""{EVENT_HANDLER_PROMPT}

            Agent: {agent_name}
            Instructions: {instructions}""",
            messages=[{
                "role": "user",
                "content": f"""Process this event:

Event Type: {event.get('type')}
Source: {event.get('source')}
Timestamp: {event.get('timestamp')}
Payload: {event.get('payload')}

Take appropriate action based on your instructions."""
            }],
            tools=[{"type": "mcp", "server_url": MCP_URL, "token": MCP_TOKEN}]
        )

        # Log the action taken
        for content in response.content:
            if hasattr(content, 'text'):
                print(f"[{agent_name}] {content.text}")

    return handler

# Create specific handlers
alert_handler = create_agent_handler(
    "AlertResponder",
    """Handle monitoring alerts:
    - Investigate the alert cause
    - Determine severity
    - Notify appropriate teams
    - Take initial remediation if safe"""
)

code_review_handler = create_agent_handler(
    "CodeReviewer",
    """Handle code change events:
    - Review the changes
    - Check for security issues
    - Add comments if needed
    - Approve if looks good"""
)

customer_event_handler = create_agent_handler(
    "CustomerAgent",
    """Handle customer events:
    - Understand what happened
    - Determine if response needed
    - Send appropriate communication
    - Update CRM if needed"""
)

# Register handlers
router.register_handler("alert.triggered", alert_handler)
router.register_handler("code.pushed", code_review_handler)
router.register_handler("code.pr_opened", code_review_handler)
router.register_handler("customer.signup", customer_event_handler)
router.register_handler("customer.churn_risk", customer_event_handler)
```

## Step 4: Event filtering and enrichment

```python
def create_filter_handler(conditions: dict) -> Callable:
    """Create a filtering handler that only processes matching events."""

    def handler(event: dict):
        payload = json.loads(event.get("payload", "{}"))

        # Check conditions
        for key, expected in conditions.items():
            actual = payload.get(key)
            if callable(expected):
                if not expected(actual):
                    return None  # Skip event
            elif actual != expected:
                return None  # Skip event

        return event  # Pass event through

    return handler

def create_enrichment_handler(enricher: Callable) -> Callable:
    """Create a handler that enriches events with additional data."""

    def handler(event: dict):
        enriched_payload = enricher(event)
        event["enriched"] = enriched_payload
        return event

    return handler

# Example: Only process high-severity alerts
high_severity_filter = create_filter_handler({
    "severity": lambda s: s in ["critical", "high"]
})

# Example: Enrich with user data
def enrich_with_user(event: dict) -> dict:
    """Enrich event with user information."""
    payload = json.loads(event.get("payload", "{}"))
    user_id = payload.get("user_id")

    if user_id:
        # Fetch user data
        response = client.messages.create(
            model="claude-sonnet-4-20250514",
            max_tokens=256,
            messages=[{
                "role": "user",
                "content": f"Get user info for {user_id} and return as JSON"
            }],
            tools=[{"type": "mcp", "server_url": MCP_URL, "token": MCP_TOKEN}]
        )

        for content in response.content:
            if hasattr(content, 'text'):
                return json.loads(content.text)

    return {}

user_enricher = create_enrichment_handler(enrich_with_user)
```

## Step 5: Event pipelines

```python
class EventPipeline:
    """Chain of event processors."""

    def __init__(self, name: str):
        self.name = name
        self.stages: List[Callable] = []

    def add_stage(self, stage: Callable) -> 'EventPipeline':
        """Add a processing stage."""
        self.stages.append(stage)
        return self

    def process(self, event: dict) -> dict:
        """Process event through all stages."""
        result = event

        for stage in self.stages:
            result = stage(result)
            if result is None:
                # Event filtered out
                return None

        return result

# Example pipeline
alert_pipeline = (
    EventPipeline("alert_processing")
    .add_stage(high_severity_filter)
    .add_stage(user_enricher)
    .add_stage(alert_handler)
)

# Register pipeline as handler
router.register_handler("alert.triggered", alert_pipeline.process)
```

## Step 6: Webhook integration

```python
from flask import Flask, request, jsonify

app = Flask(__name__)

@app.route("/webhook/<source>", methods=["POST"])
def handle_webhook(source: str):
    """Generic webhook handler that converts to events."""

    payload = request.json

    # Determine event type based on source and payload
    event_type = determine_event_type(source, payload)

    # Publish as event
    response = client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=256,
        messages=[{
            "role": "user",
            "content": f"""Publish an event:
Type: {event_type}
Source: {source}
Payload: {json.dumps(payload)}

Use publish_event tool."""
        }],
        tools=[{"type": "mcp", "server_url": MCP_URL, "token": MCP_TOKEN}]
    )

    return jsonify({"status": "event_published", "type": event_type})

def determine_event_type(source: str, payload: dict) -> str:
    """Determine event type from webhook source and payload."""

    type_mapping = {
        "github": {
            "push": "code.pushed",
            "pull_request": "code.pr_opened",
            "issues": "issue.created"
        },
        "stripe": {
            "checkout.session.completed": "payment.completed",
            "invoice.payment_failed": "payment.failed"
        },
        "slack": {
            "message": "slack.message",
            "reaction_added": "slack.reaction"
        }
    }

    source_map = type_mapping.get(source, {})

    # Try to match event type
    for key, event_type in source_map.items():
        if key in str(payload):
            return event_type

    return f"{source}.event"

@app.route("/webhook/github", methods=["POST"])
def github_webhook():
    """GitHub-specific webhook handler."""

    event_type = request.headers.get("X-GitHub-Event")
    payload = request.json

    internal_type = {
        "push": "code.pushed",
        "pull_request": "code.pr_opened",
        "issues": "issue.created",
        "issue_comment": "issue.commented"
    }.get(event_type, f"github.{event_type}")

    # Publish event
    publish_event(internal_type, json.dumps(payload), "github")

    return jsonify({"status": "ok"})

if __name__ == "__main__":
    # Start router in background thread
    import threading
    router_thread = threading.Thread(target=router.start)
    router_thread.daemon = True
    router_thread.start()

    # Start web server
    app.run(port=5000)
```

## Step 7: Monitoring and replay

```python
def replay_events(event_type: str = None, since: str = None) -> str:
    """Replay historical events for testing or recovery."""

    response = client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=2048,
        system="You are replaying historical events for processing.",
        messages=[{
            "role": "user",
            "content": f"""Replay events:
Type filter: {event_type or 'all'}
Since: {since or 'beginning'}

1. Use get_event_history to fetch events
2. For each event, use publish_event to re-publish
3. Track how many events were replayed

Report summary when done."""
        }],
        tools=[{"type": "mcp", "server_url": MCP_URL, "token": MCP_TOKEN}]
    )

    for content in response.content:
        if hasattr(content, 'text'):
            return content.text

    return ""

def process_dead_letters() -> str:
    """Process events in the dead letter queue."""

    response = client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=2048,
        system="You are processing failed events from the dead letter queue.",
        messages=[{
            "role": "user",
            "content": """Process dead letter queue:

1. Use get_dead_letters to fetch failed events
2. For each event:
   - Analyze why it failed
   - Determine if it can be fixed and retried
   - Use retry_event if recoverable
   - Log permanently failed events
3. Report summary"""
        }],
        tools=[{"type": "mcp", "server_url": MCP_URL, "token": MCP_TOKEN}]
    )

    for content in response.content:
        if hasattr(content, 'text'):
            return content.text

    return ""
```

## Summary

Event-driven agent architecture:

1. **Events as triggers** - React to changes in real-time
2. **Event routing** - Direct events to appropriate agents
3. **Filtering and enrichment** - Process only relevant events
4. **Pipelines** - Chain processing stages
5. **Failure handling** - Retry and dead letter queues

Build tools with [Gantz](https://gantz.run), create reactive AI systems.

Events happen. Agents respond. Automatically.

## Related reading

- [Agent Job Queues](/post/agent-queues/) - Scale workloads
- [Multi-Agent Systems](/post/multi-agent-systems/) - Coordination
- [Agent Observability](/post/agent-observability/) - Debug in production

---

*How do you handle event-driven AI? Share your architecture.*
