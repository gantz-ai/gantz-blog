+++
title = "Trigger AI Agents from Webhooks with MCP"
image = "images/webhook-mcp.webp"
date = 2025-11-03
description = "Connect webhooks to AI agents using MCP. Trigger automated workflows from GitHub, Stripe, Slack, and other services."
draft = false
tags = ['mcp', 'tutorial', 'automation']
voice = false

[howto]
name = "Connect Webhooks to AI Agents"
totalTime = 30
[[howto.steps]]
name = "Create webhook endpoint"
text = "Build an HTTP endpoint that receives webhook payloads."
[[howto.steps]]
name = "Parse webhook data"
text = "Extract relevant information from the webhook payload."
[[howto.steps]]
name = "Trigger agent"
text = "Call your AI agent with the webhook context."
[[howto.steps]]
name = "Execute MCP tools"
text = "Let the agent use tools to respond to the event."
[[howto.steps]]
name = "Send response"
text = "Return results or trigger follow-up actions."
+++


GitHub push event. Stripe payment. Slack message.

What if AI could respond automatically?

Webhooks + AI agents = powerful automation.

## The architecture

```
External Service → Webhook → Your Server → AI Agent → MCP Tools → Actions
     (GitHub)        │           │            │           │
                  HTTP POST   Parse      Decide      Execute
                             payload    what to do   commands
```

When something happens externally, your agent decides what to do and acts.

## Use cases

- **GitHub**: Auto-review PRs, triage issues, update docs
- **Stripe**: Send personalized emails, update CRM, alert sales
- **Slack**: Answer questions, run commands, fetch data
- **Monitoring**: Investigate alerts, suggest fixes, notify team
- **Forms**: Process submissions, qualify leads, route requests

## Step 1: Set up MCP server

Create tools the agent will use. Using [Gantz](https://gantz.run):

```yaml
# gantz.yaml
name: webhook-tools

tools:
  - name: send_slack_message
    description: Send a message to a Slack channel
    parameters:
      - name: channel
        type: string
        required: true
      - name: message
        type: string
        required: true
    script:
      shell: |
        curl -X POST https://slack.com/api/chat.postMessage \
          -H "Authorization: Bearer $SLACK_TOKEN" \
          -H "Content-Type: application/json" \
          -d '{"channel": "{{channel}}", "text": "{{message}}"}'

  - name: create_github_comment
    description: Add a comment to a GitHub issue or PR
    parameters:
      - name: repo
        type: string
        required: true
      - name: issue_number
        type: integer
        required: true
      - name: body
        type: string
        required: true
    script:
      shell: |
        curl -X POST "https://api.github.com/repos/{{repo}}/issues/{{issue_number}}/comments" \
          -H "Authorization: token $GITHUB_TOKEN" \
          -H "Content-Type: application/json" \
          -d '{"body": "{{body}}"}'

  - name: query_database
    description: Run a SQL query
    parameters:
      - name: query
        type: string
        required: true
    script:
      shell: psql "$DATABASE_URL" -c "{{query}}" --csv

  - name: send_email
    description: Send an email
    parameters:
      - name: to
        type: string
        required: true
      - name: subject
        type: string
        required: true
      - name: body
        type: string
        required: true
    script:
      command: python
      args: ["scripts/send_email.py", "{{to}}", "{{subject}}", "{{body}}"]
```

```bash
gantz run --auth
```

## Step 2: Create webhook server

Build the server that receives webhooks and triggers agents:

```python
from flask import Flask, request, jsonify
import anthropic
import json
import hmac
import hashlib

app = Flask(__name__)

# Configuration
MCP_URL = "https://webhook-tools.gantz.run/sse"
MCP_TOKEN = "gtz_abc123"
WEBHOOK_SECRET = "your-webhook-secret"

# Claude client
claude = anthropic.Anthropic()

def verify_github_signature(payload, signature):
    """Verify GitHub webhook signature."""
    expected = 'sha256=' + hmac.new(
        WEBHOOK_SECRET.encode(),
        payload,
        hashlib.sha256
    ).hexdigest()
    return hmac.compare_digest(expected, signature)

def run_agent(context: str, task: str):
    """Run AI agent with MCP tools."""
    response = claude.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=2048,
        system=f"""You are an automation assistant.
        You receive webhook events and take appropriate actions using your tools.

        Current context:
        {context}
        """,
        messages=[{"role": "user", "content": task}],
        tools=[{"type": "mcp", "server_url": MCP_URL, "token": MCP_TOKEN}]
    )

    # Handle tool calls
    while response.stop_reason == "tool_use":
        tool_results = []
        for content in response.content:
            if content.type == "tool_use":
                # MCP handles tool execution automatically
                pass

        response = claude.messages.create(
            model="claude-sonnet-4-20250514",
            max_tokens=2048,
            messages=[
                {"role": "user", "content": task},
                {"role": "assistant", "content": response.content},
                {"role": "user", "content": tool_results}
            ],
            tools=[{"type": "mcp", "server_url": MCP_URL, "token": MCP_TOKEN}]
        )

    return response.content[0].text

@app.route("/webhook/github", methods=["POST"])
def github_webhook():
    """Handle GitHub webhooks."""
    # Verify signature
    signature = request.headers.get("X-Hub-Signature-256", "")
    if not verify_github_signature(request.data, signature):
        return jsonify({"error": "Invalid signature"}), 401

    event = request.headers.get("X-GitHub-Event")
    payload = request.json

    # Build context
    context = f"""
    GitHub Event: {event}
    Repository: {payload.get('repository', {}).get('full_name')}
    Sender: {payload.get('sender', {}).get('login')}
    """

    # Determine task based on event
    if event == "issues" and payload.get("action") == "opened":
        issue = payload["issue"]
        task = f"""
        A new issue was opened:
        Title: {issue['title']}
        Body: {issue['body']}

        Please:
        1. Analyze if this is a bug, feature request, or question
        2. Add appropriate labels using create_github_comment
        3. If it's a common question, provide a helpful initial response
        """

    elif event == "pull_request" and payload.get("action") == "opened":
        pr = payload["pull_request"]
        task = f"""
        A new PR was opened:
        Title: {pr['title']}
        Description: {pr['body']}
        Changed files: {pr.get('changed_files', 'unknown')}

        Please:
        1. Review the PR description for completeness
        2. Add a welcoming comment with any initial feedback
        3. Notify the team on Slack if this seems important
        """

    elif event == "push":
        task = f"""
        Code was pushed to {payload.get('ref')}
        Commits: {len(payload.get('commits', []))}

        Please notify the team on Slack about this push.
        """

    else:
        return jsonify({"status": "ignored", "event": event})

    # Run agent
    result = run_agent(context, task)

    return jsonify({"status": "processed", "result": result})

@app.route("/webhook/stripe", methods=["POST"])
def stripe_webhook():
    """Handle Stripe webhooks."""
    payload = request.json
    event_type = payload.get("type")

    context = f"""
    Stripe Event: {event_type}
    """

    if event_type == "checkout.session.completed":
        session = payload["data"]["object"]
        task = f"""
        A customer completed checkout!
        Email: {session.get('customer_email')}
        Amount: ${session.get('amount_total', 0) / 100}

        Please:
        1. Send a thank you email to the customer
        2. Notify the sales team on Slack
        3. Add the customer to our database if new
        """

    elif event_type == "invoice.payment_failed":
        invoice = payload["data"]["object"]
        task = f"""
        A payment failed!
        Customer: {invoice.get('customer_email')}
        Amount: ${invoice.get('amount_due', 0) / 100}

        Please:
        1. Send a friendly payment reminder email
        2. Alert the support team on Slack
        """

    else:
        return jsonify({"status": "ignored"})

    result = run_agent(context, task)
    return jsonify({"status": "processed", "result": result})

@app.route("/webhook/slack", methods=["POST"])
def slack_webhook():
    """Handle Slack events."""
    payload = request.json

    # Handle URL verification
    if payload.get("type") == "url_verification":
        return jsonify({"challenge": payload["challenge"]})

    event = payload.get("event", {})
    event_type = event.get("type")

    if event_type == "app_mention":
        text = event.get("text", "")
        channel = event.get("channel")
        user = event.get("user")

        context = f"""
        Slack mention in channel {channel}
        From user: {user}
        """

        task = f"""
        Someone mentioned me in Slack with this message:
        "{text}"

        Please respond helpfully in the same channel.
        Use send_slack_message to reply.
        """

        result = run_agent(context, task)
        return jsonify({"status": "processed"})

    return jsonify({"status": "ignored"})

if __name__ == "__main__":
    app.run(port=5000)
```

## Step 3: Deploy and connect

### Deploy your webhook server

```bash
# Using Docker
docker build -t webhook-agent .
docker run -p 5000:5000 \
  -e MCP_TOKEN=gtz_abc123 \
  -e WEBHOOK_SECRET=your-secret \
  webhook-agent
```

### Configure webhooks

**GitHub:**
1. Go to repo Settings → Webhooks
2. Add webhook URL: `https://your-server.com/webhook/github`
3. Set secret
4. Select events: Issues, Pull requests, Push

**Stripe:**
```bash
stripe listen --forward-to localhost:5000/webhook/stripe
```

**Slack:**
1. Create Slack app at api.slack.com
2. Enable Events API
3. Subscribe to `app_mention` events
4. Set request URL: `https://your-server.com/webhook/slack`

## Advanced: Queue-based processing

For high volume, use a queue:

```python
from redis import Redis
from rq import Queue

redis = Redis()
queue = Queue(connection=redis)

@app.route("/webhook/github", methods=["POST"])
def github_webhook():
    payload = request.json
    event = request.headers.get("X-GitHub-Event")

    # Queue for async processing
    job = queue.enqueue(
        process_github_event,
        event,
        payload,
        job_timeout=300
    )

    return jsonify({"status": "queued", "job_id": job.id})

def process_github_event(event, payload):
    """Process GitHub event asynchronously."""
    # ... agent logic here
    pass
```

## Error handling

```python
import logging
from functools import wraps

logger = logging.getLogger(__name__)

def handle_webhook_errors(f):
    @wraps(f)
    def wrapper(*args, **kwargs):
        try:
            return f(*args, **kwargs)
        except anthropic.APIError as e:
            logger.error(f"Claude API error: {e}")
            return jsonify({"error": "AI processing failed"}), 500
        except Exception as e:
            logger.exception(f"Webhook processing failed: {e}")
            return jsonify({"error": "Internal error"}), 500
    return wrapper

@app.route("/webhook/github", methods=["POST"])
@handle_webhook_errors
def github_webhook():
    # ... webhook logic
    pass
```

## Monitoring

Track webhook processing:

```python
from prometheus_client import Counter, Histogram

webhook_requests = Counter(
    'webhook_requests_total',
    'Total webhook requests',
    ['source', 'event', 'status']
)

webhook_duration = Histogram(
    'webhook_duration_seconds',
    'Webhook processing duration',
    ['source']
)

@app.route("/webhook/github", methods=["POST"])
def github_webhook():
    event = request.headers.get("X-GitHub-Event")

    with webhook_duration.labels(source="github").time():
        try:
            result = process_webhook(request.json, event)
            webhook_requests.labels(
                source="github",
                event=event,
                status="success"
            ).inc()
            return result
        except Exception as e:
            webhook_requests.labels(
                source="github",
                event=event,
                status="error"
            ).inc()
            raise
```

## Summary

Webhooks + AI agents = event-driven automation:

1. **Receive webhooks** from external services
2. **Parse context** from the payload
3. **Trigger agent** with relevant task
4. **Execute actions** via MCP tools
5. **Monitor** processing and errors

Build tools once with [Gantz](https://gantz.run), trigger them from any webhook.

Your AI agent becomes the universal webhook handler.

## Related reading

- [Build a Slack Bot with MCP](/post/slack-bot-mcp/) - Slack integration
- [Event-Driven Agent Architecture](/post/event-driven-agents/) - Patterns
- [Agent Job Queues](/post/agent-queues/) - Scale webhooks

---

*What webhooks have you connected to AI agents? Share your automation.*
