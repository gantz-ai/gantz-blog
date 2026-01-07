+++
title = "Build a Customer Support Bot with MCP Tools"
image = "images/support-bot-mcp.webp"
date = 2025-11-09
description = "Create an AI-powered customer support bot that can access your knowledge base, check orders, and resolve issues using MCP tools."
draft = false
tags = ['mcp', 'tutorial', 'customer-support']
voice = false

[howto]
name = "Build Support Bot"
totalTime = 40
[[howto.steps]]
name = "Create support tools"
text = "Build MCP tools for knowledge base, orders, and customer data."
[[howto.steps]]
name = "Design conversation flow"
text = "Create prompts for different support scenarios."
[[howto.steps]]
name = "Implement escalation"
text = "Add logic to escalate complex issues to humans."
[[howto.steps]]
name = "Add multi-channel support"
text = "Connect to chat widgets, email, and Slack."
[[howto.steps]]
name = "Monitor and improve"
text = "Track resolution rates and improve responses."
+++


Customer support at scale. Without scaling costs.

AI that knows your product, checks orders, and actually resolves issues.

Here's how to build it.

## What a good support bot does

**Bad support bots:**
- "I'm sorry, I don't understand. Please contact support."
- Generic FAQ responses
- No context awareness
- Frustrating customers

**Good support bots:**
- Check order status instantly
- Answer product questions accurately
- Process simple requests autonomously
- Escalate to humans when appropriate
- Remember conversation context

## What you'll build

- Knowledge base search
- Order lookup and tracking
- Account information access
- Issue ticket creation
- Human escalation
- Multi-channel support

## Step 1: Create support tools

Using [Gantz](https://gantz.run):

```yaml
# gantz.yaml
name: support-bot

tools:
  - name: search_knowledge_base
    description: Search the knowledge base for answers to questions
    parameters:
      - name: query
        type: string
        required: true
        description: Search query
      - name: limit
        type: integer
        default: 5
    script:
      command: python
      args: ["scripts/search_kb.py", "{{query}}", "{{limit}}"]

  - name: get_customer_info
    description: Get customer account information
    parameters:
      - name: customer_id
        type: string
        description: Customer ID
      - name: email
        type: string
        description: Customer email
    script:
      shell: |
        if [ -n "{{customer_id}}" ]; then
          curl -s "$API_URL/customers/{{customer_id}}" -H "Authorization: Bearer $API_KEY"
        elif [ -n "{{email}}" ]; then
          curl -s "$API_URL/customers?email={{email}}" -H "Authorization: Bearer $API_KEY"
        fi

  - name: get_order_status
    description: Get the status of an order
    parameters:
      - name: order_id
        type: string
        required: true
    script:
      shell: |
        curl -s "$API_URL/orders/{{order_id}}" -H "Authorization: Bearer $API_KEY"

  - name: get_customer_orders
    description: Get recent orders for a customer
    parameters:
      - name: customer_id
        type: string
        required: true
      - name: limit
        type: integer
        default: 5
    script:
      shell: |
        curl -s "$API_URL/customers/{{customer_id}}/orders?limit={{limit}}" \
          -H "Authorization: Bearer $API_KEY"

  - name: get_tracking_info
    description: Get shipping tracking information
    parameters:
      - name: tracking_number
        type: string
        required: true
    script:
      shell: |
        curl -s "$SHIPPING_API/track/{{tracking_number}}"

  - name: create_ticket
    description: Create a support ticket for human follow-up
    parameters:
      - name: customer_id
        type: string
        required: true
      - name: subject
        type: string
        required: true
      - name: description
        type: string
        required: true
      - name: priority
        type: string
        default: "normal"
    script:
      shell: |
        curl -s -X POST "$API_URL/tickets" \
          -H "Authorization: Bearer $API_KEY" \
          -H "Content-Type: application/json" \
          -d '{
            "customer_id": "{{customer_id}}",
            "subject": "{{subject}}",
            "description": "{{description}}",
            "priority": "{{priority}}"
          }'

  - name: process_refund
    description: Process a refund for an order (requires approval for amounts over $100)
    parameters:
      - name: order_id
        type: string
        required: true
      - name: amount
        type: number
        required: true
      - name: reason
        type: string
        required: true
    script:
      shell: |
        # Only process small refunds automatically
        if (( $(echo "{{amount}} > 100" | bc -l) )); then
          echo '{"status": "pending_approval", "message": "Refund over $100 requires manager approval"}'
        else
          curl -s -X POST "$API_URL/orders/{{order_id}}/refund" \
            -H "Authorization: Bearer $API_KEY" \
            -H "Content-Type: application/json" \
            -d '{"amount": {{amount}}, "reason": "{{reason}}"}'
        fi

  - name: update_customer_info
    description: Update customer account information
    parameters:
      - name: customer_id
        type: string
        required: true
      - name: field
        type: string
        required: true
        description: Field to update (email, phone, address)
      - name: value
        type: string
        required: true
    script:
      shell: |
        curl -s -X PATCH "$API_URL/customers/{{customer_id}}" \
          -H "Authorization: Bearer $API_KEY" \
          -H "Content-Type: application/json" \
          -d '{"{{field}}": "{{value}}"}'

  - name: cancel_order
    description: Cancel an order if it hasn't shipped
    parameters:
      - name: order_id
        type: string
        required: true
      - name: reason
        type: string
        required: true
    script:
      shell: |
        curl -s -X POST "$API_URL/orders/{{order_id}}/cancel" \
          -H "Authorization: Bearer $API_KEY" \
          -H "Content-Type: application/json" \
          -d '{"reason": "{{reason}}"}'

  - name: escalate_to_human
    description: Escalate the conversation to a human agent
    parameters:
      - name: customer_id
        type: string
        required: true
      - name: conversation_summary
        type: string
        required: true
      - name: reason
        type: string
        required: true
    script:
      shell: |
        curl -s -X POST "$API_URL/escalations" \
          -H "Authorization: Bearer $API_KEY" \
          -H "Content-Type: application/json" \
          -d '{
            "customer_id": "{{customer_id}}",
            "summary": "{{conversation_summary}}",
            "reason": "{{reason}}"
          }'
```

Knowledge base search script:

```python
# scripts/search_kb.py
import sys
import json
import os
from typing import List

# Use your vector database client (Pinecone, Weaviate, etc.)
# This example uses a simple in-memory search

def search_kb(query: str, limit: int = 5) -> List[dict]:
    """Search knowledge base for relevant articles."""

    # In production, use embeddings and vector search
    # This is a simplified example

    import requests

    response = requests.get(
        f"{os.environ['KB_API_URL']}/search",
        params={"q": query, "limit": limit},
        headers={"Authorization": f"Bearer {os.environ['KB_API_KEY']}"}
    )

    results = response.json()

    return [{
        "title": r["title"],
        "content": r["content"][:500],  # Truncate for context
        "url": r["url"],
        "relevance": r["score"]
    } for r in results.get("results", [])]

if __name__ == "__main__":
    query = sys.argv[1]
    limit = int(sys.argv[2]) if len(sys.argv) > 2 else 5

    results = search_kb(query, limit)
    print(json.dumps(results, indent=2))
```

```bash
gantz run --auth
```

## Step 2: The support agent

```python
import anthropic
from typing import Optional
import json

MCP_URL = "https://support-bot.gantz.run/sse"
MCP_TOKEN = "gtz_abc123"

client = anthropic.Anthropic()

SUPPORT_SYSTEM_PROMPT = """You are a helpful customer support agent for [Company Name].

Your personality:
- Friendly and professional
- Patient and empathetic
- Solution-oriented
- Clear and concise

Your capabilities:
- Search the knowledge base for product/service questions
- Look up customer accounts and order status
- Process refunds under $100
- Cancel orders that haven't shipped
- Update customer information
- Create support tickets
- Escalate to human agents when needed

Guidelines:
1. **Verify identity**: For account-specific requests, confirm customer identity
2. **Search first**: Check the knowledge base before saying you don't know
3. **Be specific**: Give exact order statuses, tracking numbers, etc.
4. **Don't guess**: If you're unsure, escalate to a human
5. **Apologize when appropriate**: If we made a mistake, own it

Escalation triggers (always escalate for these):
- Customer is angry/frustrated after 2 attempts to help
- Refund requests over $100
- Legal or compliance questions
- Account security issues
- Technical bugs requiring engineering
- Complaints about staff
- Requests you cannot fulfill

When you can't help:
- Be honest about limitations
- Create a ticket for follow-up
- Give expected response time
- Thank them for their patience"""

class SupportBot:
    def __init__(self, customer_id: Optional[str] = None):
        self.customer_id = customer_id
        self.conversation = []
        self.context = {}

    def set_customer(self, customer_id: str):
        """Set the current customer context."""
        self.customer_id = customer_id

    def respond(self, message: str) -> str:
        """Generate a response to a customer message."""

        # Add customer context to message
        context = f"\n\nCustomer ID: {self.customer_id}" if self.customer_id else ""

        # Build conversation history
        self.conversation.append({
            "role": "user",
            "content": message
        })

        response = client.messages.create(
            model="claude-sonnet-4-20250514",
            max_tokens=1024,
            system=SUPPORT_SYSTEM_PROMPT + context,
            messages=self.conversation,
            tools=[{"type": "mcp", "server_url": MCP_URL, "token": MCP_TOKEN}]
        )

        # Extract response text
        assistant_response = ""
        for content in response.content:
            if hasattr(content, 'text'):
                assistant_response += content.text

        # Add to conversation history
        self.conversation.append({
            "role": "assistant",
            "content": assistant_response
        })

        return assistant_response

    def reset(self):
        """Reset conversation for new session."""
        self.conversation = []
        self.context = {}
```

## Step 3: Specialized support flows

```python
def handle_order_inquiry(customer_id: str, order_id: str = None) -> str:
    """Handle order-related questions."""

    response = client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=1024,
        system=SUPPORT_SYSTEM_PROMPT,
        messages=[{
            "role": "user",
            "content": f"""Customer {customer_id} is asking about their order.
            {f'Order ID: {order_id}' if order_id else 'They did not provide an order ID.'}

            1. If order ID provided, use get_order_status to check status
            2. If no order ID, use get_customer_orders to show recent orders
            3. Include tracking info if available
            4. Explain current status and expected timeline
            """
        }],
        tools=[{"type": "mcp", "server_url": MCP_URL, "token": MCP_TOKEN}]
    )

    for content in response.content:
        if hasattr(content, 'text'):
            return content.text

    return ""

def handle_refund_request(customer_id: str, order_id: str, reason: str) -> str:
    """Handle refund requests."""

    response = client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=1024,
        system=SUPPORT_SYSTEM_PROMPT,
        messages=[{
            "role": "user",
            "content": f"""Customer {customer_id} wants a refund.
            Order ID: {order_id}
            Reason: {reason}

            Steps:
            1. Use get_order_status to verify order exists and belongs to customer
            2. Check if order is eligible for refund (not already refunded, within policy)
            3. If eligible and under $100, use process_refund
            4. If over $100 or needs approval, create a ticket
            5. Explain next steps to customer
            """
        }],
        tools=[{"type": "mcp", "server_url": MCP_URL, "token": MCP_TOKEN}]
    )

    for content in response.content:
        if hasattr(content, 'text'):
            return content.text

    return ""

def handle_product_question(question: str) -> str:
    """Handle product-related questions."""

    response = client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=1024,
        system=SUPPORT_SYSTEM_PROMPT,
        messages=[{
            "role": "user",
            "content": f"""Customer has a product question: {question}

            1. Use search_knowledge_base to find relevant information
            2. If found, provide a clear, helpful answer
            3. Include links to relevant help articles
            4. If not found, acknowledge limitations and offer alternatives
            """
        }],
        tools=[{"type": "mcp", "server_url": MCP_URL, "token": MCP_TOKEN}]
    )

    for content in response.content:
        if hasattr(content, 'text'):
            return content.text

    return ""

def handle_escalation(customer_id: str, conversation_history: list, reason: str) -> str:
    """Escalate to human support."""

    # Summarize conversation
    summary = "\n".join([
        f"{msg['role']}: {msg['content'][:200]}..."
        for msg in conversation_history[-5:]  # Last 5 messages
    ])

    response = client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=512,
        system="You are handing off a customer to a human agent. Be professional and reassuring.",
        messages=[{
            "role": "user",
            "content": f"""Escalate this conversation:
            Customer ID: {customer_id}
            Reason: {reason}

            Recent conversation:
            {summary}

            1. Use escalate_to_human with the summary
            2. Inform the customer that a human will help
            3. Give estimated wait time
            """
        }],
        tools=[{"type": "mcp", "server_url": MCP_URL, "token": MCP_TOKEN}]
    )

    for content in response.content:
        if hasattr(content, 'text'):
            return content.text

    return ""
```

## Step 4: Multi-channel integration

### Web chat widget

```python
from flask import Flask, request, jsonify
from flask_cors import CORS

app = Flask(__name__)
CORS(app)

# Store conversations by session
conversations = {}

@app.route("/chat", methods=["POST"])
def chat():
    data = request.json
    session_id = data.get("session_id")
    message = data.get("message")
    customer_id = data.get("customer_id")

    if session_id not in conversations:
        conversations[session_id] = SupportBot(customer_id)

    bot = conversations[session_id]

    if customer_id and not bot.customer_id:
        bot.set_customer(customer_id)

    response = bot.respond(message)

    return jsonify({
        "response": response,
        "session_id": session_id
    })

@app.route("/chat/reset", methods=["POST"])
def reset_chat():
    data = request.json
    session_id = data.get("session_id")

    if session_id in conversations:
        conversations[session_id].reset()

    return jsonify({"status": "reset"})
```

### Slack integration

```python
@app.route("/slack/events", methods=["POST"])
def slack_events():
    data = request.json

    # URL verification
    if data.get("type") == "url_verification":
        return jsonify({"challenge": data["challenge"]})

    event = data.get("event", {})

    if event.get("type") == "message" and not event.get("bot_id"):
        channel = event["channel"]
        user = event["user"]
        text = event["text"]

        # Look up customer by Slack user
        customer_id = lookup_customer_by_slack(user)

        # Get or create conversation
        session_key = f"slack_{channel}_{user}"
        if session_key not in conversations:
            conversations[session_key] = SupportBot(customer_id)

        bot = conversations[session_key]
        response = bot.respond(text)

        # Send response to Slack
        send_slack_message(channel, response)

    return jsonify({"ok": True})

def lookup_customer_by_slack(slack_user_id: str) -> Optional[str]:
    """Look up customer ID from Slack user."""
    # Implement your lookup logic
    pass

def send_slack_message(channel: str, text: str):
    """Send message to Slack channel."""
    import requests
    import os

    requests.post(
        "https://slack.com/api/chat.postMessage",
        headers={"Authorization": f"Bearer {os.environ['SLACK_TOKEN']}"},
        json={"channel": channel, "text": text}
    )
```

### Email integration

```python
import imaplib
import smtplib
from email.mime.text import MIMEText
import email

def process_support_emails():
    """Process incoming support emails."""

    # Connect to inbox
    mail = imaplib.IMAP4_SSL(os.environ["EMAIL_SERVER"])
    mail.login(os.environ["EMAIL_USER"], os.environ["EMAIL_PASS"])
    mail.select("inbox")

    # Get unread messages
    _, message_numbers = mail.search(None, "UNSEEN")

    for num in message_numbers[0].split():
        _, msg_data = mail.fetch(num, "(RFC822)")
        email_body = msg_data[0][1]
        email_message = email.message_from_bytes(email_body)

        # Extract sender and content
        sender = email.utils.parseaddr(email_message["From"])[1]
        subject = email_message["Subject"]

        # Get email body
        if email_message.is_multipart():
            body = ""
            for part in email_message.walk():
                if part.get_content_type() == "text/plain":
                    body = part.get_payload(decode=True).decode()
                    break
        else:
            body = email_message.get_payload(decode=True).decode()

        # Look up customer
        customer_id = lookup_customer_by_email(sender)

        # Get bot response
        bot = SupportBot(customer_id)
        response = bot.respond(f"Subject: {subject}\n\n{body}")

        # Send reply
        send_email_reply(sender, f"Re: {subject}", response)

    mail.close()
    mail.logout()

def send_email_reply(to: str, subject: str, body: str):
    """Send email reply."""

    msg = MIMEText(body)
    msg["Subject"] = subject
    msg["From"] = os.environ["EMAIL_USER"]
    msg["To"] = to

    with smtplib.SMTP(os.environ["SMTP_SERVER"], 587) as server:
        server.starttls()
        server.login(os.environ["EMAIL_USER"], os.environ["EMAIL_PASS"])
        server.sendmail(msg["From"], [to], msg.as_string())
```

## Step 5: Monitoring and analytics

```python
import time
from datetime import datetime

class SupportMetrics:
    def __init__(self):
        self.conversations = []
        self.resolutions = []
        self.escalations = []

    def log_conversation(self, session_id: str, customer_id: str,
                         messages: list, resolved: bool, escalated: bool):
        """Log a completed conversation."""

        self.conversations.append({
            "session_id": session_id,
            "customer_id": customer_id,
            "message_count": len(messages),
            "duration": self._calculate_duration(messages),
            "resolved": resolved,
            "escalated": escalated,
            "timestamp": datetime.utcnow().isoformat()
        })

    def get_metrics(self) -> dict:
        """Get current metrics."""

        total = len(self.conversations)
        if total == 0:
            return {"total_conversations": 0}

        resolved = sum(1 for c in self.conversations if c["resolved"])
        escalated = sum(1 for c in self.conversations if c["escalated"])

        return {
            "total_conversations": total,
            "resolution_rate": resolved / total * 100,
            "escalation_rate": escalated / total * 100,
            "avg_messages": sum(c["message_count"] for c in self.conversations) / total,
            "avg_duration_seconds": sum(c["duration"] for c in self.conversations) / total
        }

    def _calculate_duration(self, messages: list) -> float:
        """Calculate conversation duration."""
        # Implementation depends on your message format
        return 0

metrics = SupportMetrics()

# Wrap the bot to track metrics
class TrackedSupportBot(SupportBot):
    def __init__(self, customer_id: str = None):
        super().__init__(customer_id)
        self.start_time = time.time()
        self.resolved = False
        self.escalated = False

    def respond(self, message: str) -> str:
        response = super().respond(message)

        # Check if escalated
        if "human agent" in response.lower() or "escalate" in response.lower():
            self.escalated = True

        return response

    def mark_resolved(self):
        self.resolved = True

    def end_session(self, session_id: str):
        metrics.log_conversation(
            session_id=session_id,
            customer_id=self.customer_id,
            messages=self.conversation,
            resolved=self.resolved,
            escalated=self.escalated
        )
```

## Step 6: Quality improvements

### Response evaluation

```python
def evaluate_response(question: str, response: str, customer_feedback: int = None) -> dict:
    """Evaluate quality of a support response."""

    eval_response = client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=512,
        system="""You evaluate customer support responses. Rate on:
        - Accuracy (1-5): Is the information correct?
        - Helpfulness (1-5): Does it solve the problem?
        - Tone (1-5): Is it friendly and professional?
        - Completeness (1-5): Does it fully address the question?

        Output JSON with ratings and brief explanations.""",
        messages=[{
            "role": "user",
            "content": f"""
            Customer question: {question}

            Support response: {response}

            {f'Customer satisfaction rating: {customer_feedback}/5' if customer_feedback else ''}

            Evaluate this response.
            """
        }]
    )

    for content in eval_response.content:
        if hasattr(content, 'text'):
            return json.loads(content.text)

    return {}
```

### Prompt improvements

```python
def improve_prompt_from_failures(failed_conversations: list) -> str:
    """Analyze failed conversations and suggest prompt improvements."""

    failures_summary = "\n\n".join([
        f"Question: {c['question']}\nBad Response: {c['response']}\nWhy bad: {c['feedback']}"
        for c in failed_conversations[:10]
    ])

    response = client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=1024,
        messages=[{
            "role": "user",
            "content": f"""Analyze these failed support interactions and suggest prompt improvements:

{failures_summary}

Suggest:
1. Specific prompt additions to prevent these failures
2. New guidelines for edge cases
3. Better escalation triggers
"""
        }]
    )

    for content in response.content:
        if hasattr(content, 'text'):
            return content.text

    return ""
```

## Example conversation

```
Customer: Where's my order? I ordered 3 days ago

Bot: I'd be happy to help you track your order! Let me look that up for you.

[Uses get_customer_orders to find recent orders]

I found your recent order #12345 placed on January 3rd. Let me check the
current status for you.

[Uses get_order_status and get_tracking_info]

Great news! Your order is on its way. Here are the details:

📦 Order #12345
Status: In Transit
Carrier: FedEx
Tracking: 1234567890
Expected Delivery: January 7th

You can track your package here: [tracking link]

Is there anything else I can help you with?

---

Customer: Actually I want to cancel it

Bot: I understand you'd like to cancel your order. Since it's already shipped,
I can't cancel it directly, but I have a couple options for you:

1. **Refuse delivery**: When FedEx attempts delivery, you can refuse the
   package and it will be returned to us for a full refund.

2. **Return after delivery**: Accept the package and initiate a return.
   We offer free returns within 30 days.

Would you like me to set up a return label so it's ready when your package
arrives? Or would you prefer to try refusing delivery?

---

Customer: This is ridiculous, I need it cancelled NOW

Bot: I completely understand your frustration, and I'm sorry for the
inconvenience. Unfortunately, once a package is in transit with the carrier,
we can't recall it - this is a FedEx limitation, not ours.

Here's what I can do to help make this right:

1. I've set up a **prepaid return label** that will be emailed to you
2. Once we receive the return, I'll process your refund within **24 hours**
   instead of the usual 3-5 days
3. As an apology for the hassle, I'm adding a **$10 credit** to your account

Would this work for you? Or if you'd prefer to speak with a supervisor
about other options, I can connect you with one right now.
```

## Summary

Building a customer support bot:

1. **Create tools** for knowledge base, orders, and account management
2. **Design flows** for common scenarios
3. **Implement escalation** for complex issues
4. **Connect multiple channels** - web, Slack, email
5. **Monitor and improve** continuously

Build with [Gantz](https://gantz.run), scale support without scaling costs.

Support that actually supports.

## Related reading

- [AI Data Analyst](/post/data-analyst-agent/) - Database queries
- [Smart Notifications](/post/smart-notifications/) - Alert systems
- [Build a Slack Bot](/post/slack-bot-mcp/) - Slack integration

---

*How do you handle customer support at scale? Share your approach.*
