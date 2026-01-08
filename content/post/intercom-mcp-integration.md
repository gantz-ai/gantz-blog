+++
title = "Intercom MCP Integration: Build AI-Powered Customer Support"
image = "images/intercom-mcp-integration.webp"
date = 2025-05-18
description = "Create intelligent customer support agents with Intercom and MCP. Learn conversation handling, bot automation, and customer insights with Gantz."
summary = "Create intelligent Intercom customer support agents that handle conversation routing, AI-powered response generation with knowledge base integration, sentiment-based escalation to human agents, and proactive engagement for at-risk users. This guide covers webhook handlers, user segmentation, and complete AISupport class implementation with category-based team routing."
draft = false
tags = ['intercom', 'support', 'customer-service', 'mcp', 'chat', 'gantz']
voice = false

[howto]
name = "How To Build AI Customer Support with Intercom and MCP"
totalTime = 35
[[howto.steps]]
name = "Set up Intercom workspace"
text = "Configure Intercom app and API access tokens"
[[howto.steps]]
name = "Define MCP tools"
text = "Create tool definitions for customer support operations"
[[howto.steps]]
name = "Implement handlers"
text = "Build handlers for conversations, users, and articles"
[[howto.steps]]
name = "Add AI capabilities"
text = "Integrate AI-powered responses and ticket routing"
[[howto.steps]]
name = "Deploy with Gantz"
text = "Deploy your support automation using Gantz CLI"
+++

Intercom is the modern customer messaging platform, and with MCP integration, you can build AI-powered support agents that understand context, resolve issues automatically, and provide personalized assistance at scale.

## Why Intercom MCP Integration?

AI-powered customer support enables:

- **Instant responses**: 24/7 automated support
- **Smart routing**: AI-driven ticket assignment
- **Context awareness**: Full customer history
- **Knowledge base**: AI-powered article suggestions
- **Proactive support**: Anticipate customer needs

## Intercom MCP Tool Definition

Configure Intercom tools in Gantz:

```yaml
# gantz.yaml
name: intercom-mcp-tools
version: 1.0.0

tools:
  send_message:
    description: "Send message in conversation"
    parameters:
      conversation_id:
        type: string
        required: true
      message:
        type: string
        required: true
      message_type:
        type: string
        default: "comment"
    handler: intercom.send_message

  create_conversation:
    description: "Create new conversation"
    parameters:
      user_id:
        type: string
        required: true
      body:
        type: string
        required: true
    handler: intercom.create_conversation

  get_conversation:
    description: "Get conversation details"
    parameters:
      conversation_id:
        type: string
        required: true
    handler: intercom.get_conversation

  search_users:
    description: "Search for users"
    parameters:
      query:
        type: string
        required: true
      field:
        type: string
        default: "email"
    handler: intercom.search_users

  update_user:
    description: "Update user attributes"
    parameters:
      user_id:
        type: string
        required: true
      attributes:
        type: object
        required: true
    handler: intercom.update_user

  search_articles:
    description: "Search help center articles"
    parameters:
      query:
        type: string
        required: true
    handler: intercom.search_articles

  assign_conversation:
    description: "Assign conversation to team or admin"
    parameters:
      conversation_id:
        type: string
        required: true
      assignee_id:
        type: string
        required: true
      assignee_type:
        type: string
        default: "admin"
    handler: intercom.assign_conversation

  add_tag:
    description: "Add tag to conversation"
    parameters:
      conversation_id:
        type: string
        required: true
      tag_name:
        type: string
        required: true
    handler: intercom.add_tag
```

## Handler Implementation

Build Intercom operation handlers:

```python
# handlers/intercom.py
import httpx
import os

INTERCOM_API = "https://api.intercom.io"


def get_headers():
    """Get authorization headers."""
    return {
        "Authorization": f"Bearer {os.environ['INTERCOM_ACCESS_TOKEN']}",
        "Content-Type": "application/json",
        "Intercom-Version": "2.10"
    }


async def api_request(method: str, path: str,
                      data: dict = None, params: dict = None) -> dict:
    """Make Intercom API request."""
    async with httpx.AsyncClient() as client:
        response = await client.request(
            method,
            f"{INTERCOM_API}{path}",
            json=data,
            params=params,
            headers=get_headers(),
            timeout=30.0
        )

        if response.status_code >= 400:
            error = response.json()
            return {'error': error.get('message', response.text)}

        return response.json()


async def send_message(conversation_id: str, message: str,
                       message_type: str = "comment") -> dict:
    """Send message in conversation."""
    try:
        result = await api_request(
            "POST",
            f"/conversations/{conversation_id}/reply",
            {
                "message_type": message_type,
                "type": "admin",
                "admin_id": os.environ['INTERCOM_ADMIN_ID'],
                "body": message
            }
        )

        if "error" in result:
            return result

        return {
            'conversation_id': conversation_id,
            'message_sent': True,
            'message_type': message_type
        }

    except Exception as e:
        return {'error': f'Failed to send message: {str(e)}'}


async def create_conversation(user_id: str, body: str) -> dict:
    """Create new conversation."""
    try:
        result = await api_request(
            "POST",
            "/conversations",
            {
                "from": {
                    "type": "user",
                    "id": user_id
                },
                "body": body
            }
        )

        if "error" in result:
            return result

        return {
            'conversation_id': result.get('id'),
            'created': True
        }

    except Exception as e:
        return {'error': f'Failed to create conversation: {str(e)}'}


async def get_conversation(conversation_id: str) -> dict:
    """Get conversation details."""
    try:
        result = await api_request(
            "GET",
            f"/conversations/{conversation_id}"
        )

        if "error" in result:
            return result

        # Extract key details
        parts = result.get('conversation_parts', {}).get('conversation_parts', [])

        return {
            'id': result.get('id'),
            'state': result.get('state'),
            'priority': result.get('priority'),
            'title': result.get('title'),
            'user': result.get('user', {}).get('name'),
            'assignee': result.get('assignee', {}).get('name'),
            'tags': [t['name'] for t in result.get('tags', {}).get('tags', [])],
            'messages': [{
                'author': p.get('author', {}).get('name'),
                'body': p.get('body'),
                'created_at': p.get('created_at')
            } for p in parts[-10:]]  # Last 10 messages
        }

    except Exception as e:
        return {'error': f'Failed to get conversation: {str(e)}'}


async def search_users(query: str, field: str = "email") -> dict:
    """Search for users."""
    try:
        result = await api_request(
            "POST",
            "/contacts/search",
            {
                "query": {
                    "field": field,
                    "operator": "~",
                    "value": query
                }
            }
        )

        if "error" in result:
            return result

        users = result.get('data', [])

        return {
            'count': len(users),
            'users': [{
                'id': u.get('id'),
                'email': u.get('email'),
                'name': u.get('name'),
                'created_at': u.get('created_at'),
                'last_seen_at': u.get('last_seen_at')
            } for u in users]
        }

    except Exception as e:
        return {'error': f'Search failed: {str(e)}'}


async def update_user(user_id: str, attributes: dict) -> dict:
    """Update user attributes."""
    try:
        result = await api_request(
            "PUT",
            f"/contacts/{user_id}",
            attributes
        )

        if "error" in result:
            return result

        return {
            'user_id': user_id,
            'updated': True,
            'attributes': list(attributes.keys())
        }

    except Exception as e:
        return {'error': f'Update failed: {str(e)}'}


async def search_articles(query: str) -> dict:
    """Search help center articles."""
    try:
        result = await api_request(
            "GET",
            "/articles/search",
            params={"phrase": query}
        )

        if "error" in result:
            return result

        articles = result.get('data', {}).get('articles', [])

        return {
            'query': query,
            'count': len(articles),
            'articles': [{
                'id': a.get('id'),
                'title': a.get('title'),
                'description': a.get('description'),
                'url': a.get('url'),
                'state': a.get('state')
            } for a in articles[:5]]
        }

    except Exception as e:
        return {'error': f'Search failed: {str(e)}'}


async def assign_conversation(conversation_id: str, assignee_id: str,
                             assignee_type: str = "admin") -> dict:
    """Assign conversation to team or admin."""
    try:
        result = await api_request(
            "POST",
            f"/conversations/{conversation_id}/parts",
            {
                "message_type": "assignment",
                "type": "admin",
                "admin_id": os.environ['INTERCOM_ADMIN_ID'],
                "assignee_id": assignee_id,
                "body": "Assigning to specialist"
            }
        )

        if "error" in result:
            return result

        return {
            'conversation_id': conversation_id,
            'assignee_id': assignee_id,
            'assigned': True
        }

    except Exception as e:
        return {'error': f'Assignment failed: {str(e)}'}


async def add_tag(conversation_id: str, tag_name: str) -> dict:
    """Add tag to conversation."""
    try:
        result = await api_request(
            "POST",
            f"/conversations/{conversation_id}/tags",
            {"id": tag_name}
        )

        if "error" in result:
            return result

        return {
            'conversation_id': conversation_id,
            'tag': tag_name,
            'added': True
        }

    except Exception as e:
        return {'error': f'Failed to add tag: {str(e)}'}
```

## AI-Powered Support Bot

Build an intelligent support agent:

```python
# support_bot.py
from gantz import MCPClient
from datetime import datetime

mcp = MCPClient(config_path='gantz.yaml')


class AISupport:
    """AI-powered customer support agent."""

    def __init__(self):
        self.escalation_keywords = [
            'manager', 'supervisor', 'human', 'person', 'angry', 'frustrated'
        ]

    async def handle_message(self, conversation_id: str, message: str,
                           user: dict) -> dict:
        """Handle incoming support message."""
        # Get conversation context
        conversation = mcp.execute_tool('get_conversation', {
            'conversation_id': conversation_id
        })

        # Check for escalation triggers
        if self.should_escalate(message, conversation):
            return await self.escalate(conversation_id, user, message)

        # Categorize the inquiry
        category = await self.categorize_inquiry(message)

        # Search for relevant articles
        articles = mcp.execute_tool('search_articles', {
            'query': message
        })

        # Generate AI response
        response = await self.generate_response(
            message=message,
            category=category,
            articles=articles.get('articles', []),
            user=user,
            conversation_history=conversation.get('messages', [])
        )

        # Tag conversation
        mcp.execute_tool('add_tag', {
            'conversation_id': conversation_id,
            'tag_name': category['category']
        })

        # Send response
        mcp.execute_tool('send_message', {
            'conversation_id': conversation_id,
            'message': response['message']
        })

        # Update user attributes if needed
        if response.get('update_user'):
            mcp.execute_tool('update_user', {
                'user_id': user['id'],
                'attributes': response['update_user']
            })

        return {
            'category': category,
            'response_sent': True,
            'articles_suggested': len(articles.get('articles', []))
        }

    def should_escalate(self, message: str, conversation: dict) -> bool:
        """Check if conversation should be escalated."""
        message_lower = message.lower()

        # Check keywords
        for keyword in self.escalation_keywords:
            if keyword in message_lower:
                return True

        # Check sentiment
        if self.detect_negative_sentiment(message):
            return True

        # Check message count (long conversation)
        if len(conversation.get('messages', [])) > 10:
            return True

        return False

    def detect_negative_sentiment(self, message: str) -> bool:
        """Detect negative sentiment in message."""
        result = mcp.execute_tool('analyze_sentiment', {
            'text': message
        })
        return result.get('sentiment') == 'negative' and result.get('score', 0) > 0.7

    async def categorize_inquiry(self, message: str) -> dict:
        """Categorize customer inquiry using AI."""
        result = mcp.execute_tool('ai_classify', {
            'text': message,
            'categories': [
                'billing', 'technical', 'account', 'feature_request',
                'bug_report', 'general_inquiry', 'cancellation'
            ]
        })

        return {
            'category': result.get('category'),
            'confidence': result.get('confidence'),
            'subcategory': result.get('subcategory')
        }

    async def generate_response(self, message: str, category: dict,
                               articles: list, user: dict,
                               conversation_history: list) -> dict:
        """Generate AI response."""
        # Build context
        context = {
            'customer_name': user.get('name', 'there'),
            'category': category['category'],
            'relevant_articles': articles,
            'history': conversation_history[-5:],  # Last 5 messages
            'user_plan': user.get('custom_attributes', {}).get('plan'),
            'user_tenure': self.calculate_tenure(user)
        }

        result = mcp.execute_tool('ai_generate', {
            'type': 'support_response',
            'query': message,
            'context': context,
            'tone': 'helpful_professional',
            'include_articles': len(articles) > 0
        })

        response = {
            'message': result.get('response'),
            'confidence': result.get('confidence')
        }

        # Check if we should update user attributes
        if result.get('inferred_intent') == 'cancellation':
            response['update_user'] = {
                'custom_attributes': {'churn_risk': 'high'}
            }

        return response

    async def escalate(self, conversation_id: str, user: dict,
                      message: str) -> dict:
        """Escalate conversation to human agent."""
        # Determine best team based on category
        category = await self.categorize_inquiry(message)
        team_id = self.get_team_for_category(category['category'])

        # Add escalation note
        mcp.execute_tool('send_message', {
            'conversation_id': conversation_id,
            'message': "I'm connecting you with a specialist who can help better. Please hold on.",
            'message_type': 'comment'
        })

        # Assign to team
        mcp.execute_tool('assign_conversation', {
            'conversation_id': conversation_id,
            'assignee_id': team_id,
            'assignee_type': 'team'
        })

        # Tag as escalated
        mcp.execute_tool('add_tag', {
            'conversation_id': conversation_id,
            'tag_name': 'escalated'
        })

        return {
            'escalated': True,
            'team': team_id,
            'reason': 'Customer requested human assistance'
        }

    def get_team_for_category(self, category: str) -> str:
        """Get appropriate team ID for category."""
        team_mapping = {
            'billing': os.environ.get('BILLING_TEAM_ID'),
            'technical': os.environ.get('TECHNICAL_TEAM_ID'),
            'cancellation': os.environ.get('RETENTION_TEAM_ID')
        }
        return team_mapping.get(category, os.environ.get('GENERAL_TEAM_ID'))

    def calculate_tenure(self, user: dict) -> str:
        """Calculate customer tenure."""
        created = user.get('created_at')
        if not created:
            return 'unknown'

        days = (datetime.now().timestamp() - created) / 86400
        if days < 30:
            return 'new'
        elif days < 365:
            return 'established'
        else:
            return 'long_term'


# Initialize bot
support_bot = AISupport()
```

## Webhook Handler

Process Intercom webhooks:

```python
# webhooks.py
from fastapi import FastAPI, Request, HTTPException
from support_bot import support_bot
import hmac
import hashlib
import os

app = FastAPI()


def verify_signature(payload: bytes, signature: str) -> bool:
    """Verify Intercom webhook signature."""
    expected = hmac.new(
        os.environ['INTERCOM_CLIENT_SECRET'].encode(),
        payload,
        hashlib.sha1
    ).hexdigest()
    return hmac.compare_digest(expected, signature)


@app.post("/intercom/webhook")
async def handle_webhook(request: Request):
    """Handle Intercom webhook events."""
    # Verify signature
    signature = request.headers.get('X-Hub-Signature', '')
    payload = await request.body()

    if not verify_signature(payload, signature.replace('sha1=', '')):
        raise HTTPException(status_code=401, detail="Invalid signature")

    data = await request.json()
    topic = data.get('topic')

    if topic == 'conversation.user.created':
        await handle_new_conversation(data)

    elif topic == 'conversation.user.replied':
        await handle_user_reply(data)

    elif topic == 'conversation.admin.replied':
        pass  # Ignore admin replies

    return {"status": "ok"}


async def handle_new_conversation(data: dict):
    """Handle new conversation from user."""
    conversation_id = data['data']['item']['id']
    message = data['data']['item']['source']['body']
    user = data['data']['item']['user']

    await support_bot.handle_message(conversation_id, message, user)


async def handle_user_reply(data: dict):
    """Handle user reply in existing conversation."""
    conversation_id = data['data']['item']['id']

    # Get the latest message
    parts = data['data']['item'].get('conversation_parts', {}).get('conversation_parts', [])
    if parts:
        latest = parts[-1]
        if latest.get('author', {}).get('type') == 'user':
            message = latest.get('body', '')
            user = data['data']['item']['user']

            await support_bot.handle_message(conversation_id, message, user)
```

## Proactive Support

Implement proactive customer engagement:

```python
# proactive.py
from gantz import MCPClient

mcp = MCPClient()


async def check_at_risk_users():
    """Identify and engage at-risk users."""
    # Find users with low engagement
    users = mcp.execute_tool('search_users', {
        'query': 'last_seen_at < 7_days_ago',
        'field': 'custom_query'
    })

    for user in users.get('users', []):
        # Check if they have open issues
        conversations = await get_user_conversations(user['id'])

        if has_unresolved_issues(conversations):
            # Send proactive message
            mcp.execute_tool('create_conversation', {
                'user_id': user['id'],
                'body': generate_proactive_message(user, conversations)
            })


def generate_proactive_message(user: dict, conversations: list) -> str:
    """Generate personalized proactive message."""
    result = mcp.execute_tool('ai_generate', {
        'type': 'proactive_support',
        'context': {
            'user': user,
            'open_issues': conversations,
            'goal': 're_engagement'
        },
        'tone': 'caring_professional'
    })
    return result.get('message')
```

## Deploy with Gantz CLI

Deploy your support automation:

```bash
# Install Gantz
npm install -g gantz

# Initialize Intercom project
gantz init --template intercom-support

# Set environment variables
export INTERCOM_ACCESS_TOKEN=your-access-token
export INTERCOM_ADMIN_ID=your-admin-id

# Deploy
gantz deploy --platform railway

# Configure webhooks in Intercom Developer Hub
```

Build intelligent customer support at [gantz.run](https://gantz.run).

## Related Reading

- [Zendesk MCP Integration](/post/zendesk-mcp-integration/) - Compare with Zendesk
- [Freshdesk MCP Integration](/post/freshdesk-mcp-integration/) - Alternative support platform
- [MCP Streaming Patterns](/post/mcp-streaming-patterns/) - Real-time responses

## Conclusion

Intercom and MCP create powerful AI-driven customer support systems. With intelligent routing, automated responses, and proactive engagement, you can deliver exceptional support experiences at scale.

Start building support AI agents with Gantz today.
