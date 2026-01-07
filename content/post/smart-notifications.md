+++
title = "Smart Notifications: AI That Knows When to Alert You"
image = "/images/smart-notifications.png"
date = 2025-11-15
description = "Build an AI notification system that filters noise, prioritizes alerts, and knows when to interrupt. Stop notification overload with MCP tools."
draft = false
tags = ['mcp', 'tutorial', 'notifications']
voice = false

[howto]
name = "Build Smart Notifications"
totalTime = 30
[[howto.steps]]
name = "Create notification tools"
text = "Build MCP tools for multi-channel notifications."
[[howto.steps]]
name = "Implement filtering logic"
text = "Design prompts that evaluate notification importance."
[[howto.steps]]
name = "Add context awareness"
text = "Consider time, user state, and history."
[[howto.steps]]
name = "Build aggregation"
text = "Combine related notifications intelligently."
[[howto.steps]]
name = "Create escalation paths"
text = "Route urgent notifications appropriately."
+++


100+ notifications a day.

Most don't matter. Some really do.

AI can tell the difference.

## The notification problem

We're drowning in alerts:
- Slack pings for everything
- Email that "might" be important
- Monitoring alerts (mostly noise)
- App notifications galore
- Calendar reminders

Result: Important things get missed. Attention is fragmented.

## What smart notifications do

- **Filter noise**: Suppress low-priority alerts
- **Batch intelligently**: Group related notifications
- **Time appropriately**: Don't interrupt during focus time
- **Escalate correctly**: Get urgent alerts through
- **Learn preferences**: Adapt to user behavior

## What you'll build

- Multi-channel notification routing
- Importance classification
- Context-aware delivery timing
- Notification aggregation
- Escalation management

## Step 1: Create notification tools

Using [Gantz](https://gantz.run):

```yaml
# gantz.yaml
name: smart-notifications

tools:
  - name: send_slack
    description: Send a Slack message
    parameters:
      - name: channel
        type: string
        required: true
      - name: message
        type: string
        required: true
      - name: priority
        type: string
        default: "normal"
    script:
      shell: |
        curl -s -X POST "https://slack.com/api/chat.postMessage" \
          -H "Authorization: Bearer $SLACK_TOKEN" \
          -H "Content-Type: application/json" \
          -d '{"channel": "{{channel}}", "text": "{{message}}", "unfurl_links": false}'

  - name: send_email
    description: Send an email notification
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
      - name: priority
        type: string
        default: "normal"
    script:
      command: python
      args: ["scripts/send_email.py", "{{to}}", "{{subject}}", "{{body}}", "{{priority}}"]

  - name: send_push
    description: Send a push notification
    parameters:
      - name: user_id
        type: string
        required: true
      - name: title
        type: string
        required: true
      - name: body
        type: string
        required: true
      - name: data
        type: string
    script:
      command: python
      args: ["scripts/send_push.py", "{{user_id}}", "{{title}}", "{{body}}", "{{data}}"]

  - name: send_sms
    description: Send an SMS for urgent notifications
    parameters:
      - name: phone
        type: string
        required: true
      - name: message
        type: string
        required: true
    script:
      shell: |
        curl -s -X POST "https://api.twilio.com/2010-04-01/Accounts/$TWILIO_SID/Messages.json" \
          -u "$TWILIO_SID:$TWILIO_TOKEN" \
          -d "To={{phone}}" \
          -d "From=$TWILIO_NUMBER" \
          -d "Body={{message}}"

  - name: page_oncall
    description: Page the on-call person via PagerDuty
    parameters:
      - name: message
        type: string
        required: true
      - name: severity
        type: string
        default: "high"
    script:
      shell: |
        curl -s -X POST "https://events.pagerduty.com/v2/enqueue" \
          -H "Content-Type: application/json" \
          -d '{
            "routing_key": "'$PAGERDUTY_KEY'",
            "event_action": "trigger",
            "payload": {
              "summary": "{{message}}",
              "severity": "{{severity}}",
              "source": "smart-notifications"
            }
          }'

  - name: get_user_status
    description: Get current user status and preferences
    parameters:
      - name: user_id
        type: string
        required: true
    script:
      command: python
      args: ["scripts/get_user_status.py", "{{user_id}}"]

  - name: get_notification_history
    description: Get recent notifications sent to a user
    parameters:
      - name: user_id
        type: string
        required: true
      - name: hours
        type: integer
        default: 24
    script:
      command: python
      args: ["scripts/get_history.py", "{{user_id}}", "{{hours}}"]

  - name: save_notification
    description: Log a notification for tracking
    parameters:
      - name: user_id
        type: string
        required: true
      - name: notification
        type: string
        required: true
      - name: channel
        type: string
        required: true
      - name: priority
        type: string
    script:
      command: python
      args: ["scripts/save_notification.py", "{{user_id}}", "{{channel}}", "{{priority}}"]
      stdin: "{{notification}}"

  - name: get_user_schedule
    description: Get user's calendar for timing decisions
    parameters:
      - name: user_id
        type: string
        required: true
    script:
      command: python
      args: ["scripts/get_schedule.py", "{{user_id}}"]

  - name: check_quiet_hours
    description: Check if user is in quiet/focus hours
    parameters:
      - name: user_id
        type: string
        required: true
    script:
      command: python
      args: ["scripts/check_quiet_hours.py", "{{user_id}}"]
```

User status script:

```python
# scripts/get_user_status.py
import sys
import json
from datetime import datetime

def get_user_status(user_id: str) -> dict:
    """Get user's current status and notification preferences."""

    # In production, fetch from database/API
    # This is a simplified example

    now = datetime.now()
    hour = now.hour

    status = {
        "user_id": user_id,
        "online": True,
        "status": "available",
        "timezone": "America/New_York",
        "local_time": now.isoformat(),
        "preferences": {
            "quiet_hours": {"start": "22:00", "end": "08:00"},
            "focus_time": {"enabled": True, "current": False},
            "preferred_channel": "slack" if 9 <= hour <= 18 else "email",
            "batch_non_urgent": True,
            "batch_interval_minutes": 30
        },
        "channels": {
            "slack": user_id,
            "email": f"{user_id}@company.com",
            "phone": "+1234567890"
        },
        "escalation_contacts": [
            {"name": "Manager", "email": "manager@company.com"},
            {"name": "Team Lead", "email": "lead@company.com"}
        ]
    }

    # Check if in meeting
    # In production, check calendar API
    if 10 <= hour <= 11 or 14 <= hour <= 15:
        status["status"] = "in_meeting"

    return status

if __name__ == "__main__":
    user_id = sys.argv[1]
    status = get_user_status(user_id)
    print(json.dumps(status, indent=2))
```

```bash
gantz run --auth
```

## Step 2: The notification agent

```python
import anthropic
from typing import Dict, List, Optional
from datetime import datetime
import json

MCP_URL = "https://smart-notifications.gantz.run/sse"
MCP_TOKEN = "gtz_abc123"

client = anthropic.Anthropic()

NOTIFICATION_SYSTEM_PROMPT = """You are an intelligent notification manager.

Your job is to ensure important notifications reach users appropriately while reducing noise.

Classification levels:
- CRITICAL: Security breaches, system outages, financial alerts - immediate delivery
- HIGH: Production issues, important messages from leadership - deliver within minutes
- NORMAL: Regular work communications - batch if preferred, respect quiet hours
- LOW: FYI, automated reports, non-urgent updates - batch aggressively

Delivery decisions consider:
1. **Urgency**: How time-sensitive is this?
2. **Impact**: What happens if they don't see it immediately?
3. **User state**: Are they available? In a meeting? After hours?
4. **History**: Have we sent similar notifications recently?
5. **Preferences**: What does the user prefer?

Channel selection:
- Slack: Real-time work communication
- Email: Detailed info, async communication
- Push: Mobile alerts for away-from-desk
- SMS: Urgent only, when other channels fail
- PagerDuty: Critical incidents only

Golden rule: Protect user attention. Only interrupt for things that truly need interruption."""

def process_notification(user_id: str, notification: Dict) -> Dict:
    """Process and route a notification intelligently."""

    response = client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=1024,
        system=NOTIFICATION_SYSTEM_PROMPT,
        messages=[{
            "role": "user",
            "content": f"""Process this notification:

User: {user_id}
Type: {notification.get('type', 'general')}
Source: {notification.get('source', 'unknown')}
Subject: {notification.get('subject', '')}
Content: {notification.get('content', '')}
Metadata: {json.dumps(notification.get('metadata', {}))}

Steps:
1. Use get_user_status to check user state and preferences
2. Use check_quiet_hours to see if interruption is appropriate
3. Use get_notification_history to check for duplicates/batching
4. Classify the notification priority
5. Decide: deliver now, batch, delay, or suppress
6. Choose the appropriate channel(s)
7. If delivering, use the appropriate send_* tool
8. Log with save_notification

Return JSON with:
- priority: classified priority level
- action: deliver/batch/delay/suppress
- channel: chosen channel(s)
- reason: why this decision was made"""
        }],
        tools=[{"type": "mcp", "server_url": MCP_URL, "token": MCP_TOKEN}]
    )

    for content in response.content:
        if hasattr(content, 'text'):
            try:
                return json.loads(content.text)
            except:
                return {"raw": content.text}

    return {}

def batch_notifications(user_id: str) -> str:
    """Send batched notifications that have been queued."""

    response = client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=2048,
        system=NOTIFICATION_SYSTEM_PROMPT,
        messages=[{
            "role": "user",
            "content": f"""Process batched notifications for {user_id}.

1. Get queued notifications from notification history
2. Group related notifications
3. Summarize each group
4. Send a single digest with:
   - Most important items first
   - Related items grouped
   - Clear action items if any
5. Use the user's preferred channel

Make the digest scannable and actionable."""
        }],
        tools=[{"type": "mcp", "server_url": MCP_URL, "token": MCP_TOKEN}]
    )

    for content in response.content:
        if hasattr(content, 'text'):
            return content.text

    return ""
```

## Step 3: Priority classification

```python
def classify_notification(notification: Dict) -> Dict:
    """Classify notification priority and urgency."""

    response = client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=512,
        system="""You classify notification urgency.

        CRITICAL indicators:
        - Security breach/attempt
        - Service outage
        - Data loss risk
        - Financial transaction issues
        - Legal/compliance deadlines

        HIGH indicators:
        - Production errors affecting users
        - Important deadline within 24 hours
        - Direct message from leadership
        - Customer escalation

        NORMAL indicators:
        - Regular work communication
        - PR/code review requests
        - Meeting invites
        - Task assignments

        LOW indicators:
        - Automated reports
        - FYI notifications
        - Social/community updates
        - Marketing newsletters""",
        messages=[{
            "role": "user",
            "content": f"""Classify this notification:

Type: {notification.get('type')}
Source: {notification.get('source')}
Subject: {notification.get('subject')}
Content preview: {notification.get('content', '')[:500]}

Output JSON with:
- priority: CRITICAL/HIGH/NORMAL/LOW
- urgency_score: 1-10
- time_sensitivity: immediate/hours/day/week
- can_batch: boolean
- reasoning: brief explanation"""
        }]
    )

    for content in response.content:
        if hasattr(content, 'text'):
            try:
                return json.loads(content.text)
            except:
                return {"raw": content.text}

    return {}

def should_interrupt(user_id: str, notification: Dict, priority: str) -> Dict:
    """Decide if a notification should interrupt the user."""

    response = client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=512,
        system=NOTIFICATION_SYSTEM_PROMPT,
        messages=[{
            "role": "user",
            "content": f"""Should this notification interrupt user {user_id}?

Notification priority: {priority}
Subject: {notification.get('subject')}

1. Check user status with get_user_status
2. Check quiet hours with check_quiet_hours
3. Check if in focus mode
4. Consider the notification priority

Decision framework:
- CRITICAL: Always interrupt (except if set to absolute DND)
- HIGH: Interrupt unless in meeting or quiet hours
- NORMAL: Respect all preferences
- LOW: Never interrupt

Output JSON with:
- interrupt: boolean
- reason: explanation
- alternative: what to do if not interrupting"""
        }],
        tools=[{"type": "mcp", "server_url": MCP_URL, "token": MCP_TOKEN}]
    )

    for content in response.content:
        if hasattr(content, 'text'):
            try:
                return json.loads(content.text)
            except:
                return {"raw": content.text}

    return {}
```

## Step 4: Aggregation and summarization

```python
def aggregate_notifications(notifications: List[Dict]) -> Dict:
    """Aggregate similar notifications into a summary."""

    notif_json = json.dumps(notifications)

    response = client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=2048,
        system="""You aggregate notifications into concise summaries.

        Group by:
        - Source/system
        - Topic/project
        - Action required

        Summary format:
        - Lead with count and category
        - Highlight any requiring action
        - List details in order of importance
        - Make scannable with bullets""",
        messages=[{
            "role": "user",
            "content": f"""Aggregate these notifications:

{notif_json}

Create:
1. Groups of related notifications
2. Summary for each group
3. Overall summary
4. Action items if any

Output as structured JSON."""
        }]
    )

    for content in response.content:
        if hasattr(content, 'text'):
            try:
                return json.loads(content.text)
            except:
                return {"raw": content.text}

    return {}

def create_digest(user_id: str, timeframe: str = "daily") -> str:
    """Create a notification digest for a user."""

    response = client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=4096,
        system=NOTIFICATION_SYSTEM_PROMPT,
        messages=[{
            "role": "user",
            "content": f"""Create a {timeframe} notification digest for {user_id}.

1. Use get_notification_history to get notifications
2. Filter out already-addressed items
3. Group and summarize
4. Format as a clear digest:

Structure:
## Action Required (X items)
- Item 1 [link/action]
- Item 2

## Updates (X items)
- Summary of updates

## FYI (X items)
- Low priority items

Keep it concise and scannable."""
        }],
        tools=[{"type": "mcp", "server_url": MCP_URL, "token": MCP_TOKEN}]
    )

    for content in response.content:
        if hasattr(content, 'text'):
            return content.text

    return ""
```

## Step 5: Escalation management

```python
def handle_escalation(user_id: str, notification: Dict,
                      failed_channels: List[str]) -> str:
    """Handle notification escalation when primary channels fail."""

    response = client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=1024,
        system=NOTIFICATION_SYSTEM_PROMPT + """

        Escalation path:
        1. Primary channel (Slack) - 5 min timeout
        2. Secondary channel (Email) - 15 min timeout
        3. Push notification - 10 min timeout
        4. SMS - 5 min timeout
        5. PagerDuty - for critical only
        6. Escalation contacts - manager, team lead

        Only escalate if:
        - Priority is HIGH or CRITICAL
        - Primary channels have been tried
        - Time-sensitivity requires it""",
        messages=[{
            "role": "user",
            "content": f"""Handle escalation for notification:

User: {user_id}
Subject: {notification.get('subject')}
Priority: {notification.get('priority', 'unknown')}
Failed channels: {', '.join(failed_channels)}

1. Get user status and escalation contacts
2. Determine next channel to try
3. If all personal channels exhausted, consider escalation contacts
4. For CRITICAL, consider paging on-call

Execute the escalation and report what was done."""
        }],
        tools=[{"type": "mcp", "server_url": MCP_URL, "token": MCP_TOKEN}]
    )

    for content in response.content:
        if hasattr(content, 'text'):
            return content.text

    return ""

def handle_incident(incident: Dict) -> str:
    """Handle a critical incident notification."""

    response = client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=2048,
        system=NOTIFICATION_SYSTEM_PROMPT + """

        For incidents:
        - Immediately notify on-call via PagerDuty
        - Alert incident Slack channel
        - Email stakeholders
        - Track acknowledgment
        - Escalate if not acknowledged""",
        messages=[{
            "role": "user",
            "content": f"""Handle this incident:

{json.dumps(incident)}

1. Page on-call immediately with page_oncall
2. Send to incident Slack channel
3. Email relevant stakeholders
4. Report what was done and who was notified"""
        }],
        tools=[{"type": "mcp", "server_url": MCP_URL, "token": MCP_TOKEN}]
    )

    for content in response.content:
        if hasattr(content, 'text'):
            return content.text

    return ""
```

## Step 6: CLI and webhook

```python
#!/usr/bin/env python3
"""Smart Notifications CLI."""

import argparse
import json
from flask import Flask, request, jsonify

app = Flask(__name__)

@app.route("/notify", methods=["POST"])
def notify_webhook():
    """Webhook endpoint for incoming notifications."""

    data = request.json
    user_id = data.get("user_id")
    notification = {
        "type": data.get("type", "general"),
        "source": data.get("source", "webhook"),
        "subject": data.get("subject", ""),
        "content": data.get("content", ""),
        "metadata": data.get("metadata", {})
    }

    result = process_notification(user_id, notification)
    return jsonify(result)

@app.route("/digest/<user_id>", methods=["POST"])
def send_digest(user_id: str):
    """Trigger a digest for a user."""

    timeframe = request.args.get("timeframe", "daily")
    result = create_digest(user_id, timeframe)
    return jsonify({"status": "sent", "digest": result})

@app.route("/incident", methods=["POST"])
def incident_webhook():
    """Webhook for incident notifications."""

    incident = request.json
    result = handle_incident(incident)
    return jsonify({"status": "handled", "result": result})

def main():
    parser = argparse.ArgumentParser(description="Smart Notifications")
    subparsers = parser.add_subparsers(dest="command")

    # Send
    send_parser = subparsers.add_parser("send", help="Send notification")
    send_parser.add_argument("--user", "-u", required=True)
    send_parser.add_argument("--subject", "-s", required=True)
    send_parser.add_argument("--content", "-c", required=True)
    send_parser.add_argument("--type", "-t", default="general")

    # Digest
    digest_parser = subparsers.add_parser("digest", help="Send digest")
    digest_parser.add_argument("--user", "-u", required=True)
    digest_parser.add_argument("--timeframe", "-t", default="daily")

    # Server
    server_parser = subparsers.add_parser("server", help="Run webhook server")
    server_parser.add_argument("--port", "-p", type=int, default=5000)

    args = parser.parse_args()

    if args.command == "send":
        notification = {
            "type": args.type,
            "subject": args.subject,
            "content": args.content
        }
        result = process_notification(args.user, notification)
        print(json.dumps(result, indent=2))

    elif args.command == "digest":
        result = create_digest(args.user, args.timeframe)
        print(result)

    elif args.command == "server":
        app.run(port=args.port)

    else:
        parser.print_help()

if __name__ == "__main__":
    main()
```

## Summary

Building smart notifications:

1. **Priority classification** - Know what matters
2. **Context awareness** - Consider user state
3. **Channel selection** - Right message, right channel
4. **Aggregation** - Batch the noise
5. **Escalation** - Get critical alerts through

Build tools with [Gantz](https://gantz.run), end notification overload.

Fewer interruptions. Nothing important missed.

## Related reading

- [Calendar Assistant](/post/calendar-assistant/) - Time management
- [Build a Support Bot](/post/support-bot-mcp/) - User communication
- [Event-Driven Agents](/post/event-driven-agents/) - Reactive systems

---

*How do you manage notification overload? Share your approach.*
