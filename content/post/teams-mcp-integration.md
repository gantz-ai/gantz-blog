+++
title = "Microsoft Teams MCP Integration: Build Enterprise AI Assistants"
image = "images/teams-mcp-integration.webp"
date = 2025-05-12
description = "Create intelligent Microsoft Teams bots with MCP tools. Learn adaptive cards, proactive messaging, and enterprise integration with Gantz."
summary = "Build AI bots that live in Microsoft Teams channels - answering questions, automating workflows, summarizing meetings, and sending proactive alerts. Covers Azure Bot Service registration, adaptive cards for rich interactions, Azure AD authentication, and connecting to corporate systems through MCP tools."
draft = false
tags = ['teams', 'microsoft', 'enterprise', 'mcp', 'bot', 'gantz']
voice = false

[howto]
name = "How To Build AI Teams Bots with MCP"
totalTime = 35
[[howto.steps]]
name = "Register Teams bot"
text = "Create bot in Azure Bot Service and register with Teams"
[[howto.steps]]
name = "Define MCP tools"
text = "Create tool definitions for Teams operations"
[[howto.steps]]
name = "Implement handlers"
text = "Build message and card handlers for Teams"
[[howto.steps]]
name = "Add AI capabilities"
text = "Integrate AI-powered assistance and automation"
[[howto.steps]]
name = "Deploy with Gantz"
text = "Deploy your Teams bot using Gantz CLI"
+++

Microsoft Teams is the collaboration hub for enterprise work, and MCP-powered bots can streamline workflows and provide intelligent assistance. This guide covers building enterprise-grade Teams bots with AI capabilities.

## Why Teams MCP Integration?

AI-powered Teams bots enable enterprise workflows:

- **Smart assistance**: Context-aware help for employees
- **Workflow automation**: Automate repetitive tasks
- **Meeting intelligence**: Summarize and action meetings
- **Adaptive cards**: Rich interactive experiences
- **Enterprise security**: Azure AD integration

## Teams MCP Tool Definition

Configure Teams tools in Gantz:

```yaml
# gantz.yaml
name: teams-mcp-tools
version: 1.0.0

tools:
  send_message:
    description: "Send message to Teams channel or chat"
    parameters:
      conversation_id:
        type: string
        required: true
      message:
        type: string
        required: true
      card:
        type: object
        description: "Optional adaptive card"
    handler: teams.send_message

  send_adaptive_card:
    description: "Send adaptive card to Teams"
    parameters:
      conversation_id:
        type: string
        required: true
      card:
        type: object
        required: true
    handler: teams.send_adaptive_card

  create_meeting:
    description: "Create Teams meeting"
    parameters:
      subject:
        type: string
        required: true
      attendees:
        type: array
        required: true
      start_time:
        type: string
        required: true
      duration_minutes:
        type: integer
        default: 30
    handler: teams.create_meeting

  get_channel_messages:
    description: "Get messages from channel"
    parameters:
      team_id:
        type: string
        required: true
      channel_id:
        type: string
        required: true
      limit:
        type: integer
        default: 50
    handler: teams.get_channel_messages

  mention_user:
    description: "Send message with user mention"
    parameters:
      conversation_id:
        type: string
        required: true
      user_id:
        type: string
        required: true
      message:
        type: string
        required: true
    handler: teams.mention_user

  get_user_presence:
    description: "Get user presence status"
    parameters:
      user_id:
        type: string
        required: true
    handler: teams.get_user_presence
```

## Handler Implementation

Build Teams operation handlers:

```python
# handlers/teams.py
import httpx
from msal import ConfidentialClientApplication
import os

# Microsoft Graph API
GRAPH_API = "https://graph.microsoft.com/v1.0"

# Authentication
_app = None
_token = None


def get_auth_app():
    """Get MSAL authentication app."""
    global _app
    if _app is None:
        _app = ConfidentialClientApplication(
            os.environ['TEAMS_APP_ID'],
            authority=f"https://login.microsoftonline.com/{os.environ['TEAMS_TENANT_ID']}",
            client_credential=os.environ['TEAMS_APP_SECRET']
        )
    return _app


async def get_token():
    """Get access token for Graph API."""
    global _token
    app = get_auth_app()

    result = app.acquire_token_for_client(
        scopes=["https://graph.microsoft.com/.default"]
    )

    if "access_token" in result:
        _token = result["access_token"]
        return _token

    raise Exception(f"Failed to get token: {result.get('error_description')}")


async def graph_request(method: str, path: str,
                        data: dict = None) -> dict:
    """Make Graph API request."""
    token = await get_token()

    async with httpx.AsyncClient() as client:
        response = await client.request(
            method,
            f"{GRAPH_API}{path}",
            json=data,
            headers={
                "Authorization": f"Bearer {token}",
                "Content-Type": "application/json"
            }
        )

        if response.status_code >= 400:
            return {"error": response.text}

        return response.json() if response.text else {"success": True}


async def send_message(conversation_id: str, message: str,
                       card: dict = None) -> dict:
    """Send message to Teams conversation."""
    try:
        body = {
            "body": {
                "contentType": "html",
                "content": message
            }
        }

        if card:
            body["attachments"] = [{
                "contentType": "application/vnd.microsoft.card.adaptive",
                "content": card
            }]

        result = await graph_request(
            "POST",
            f"/chats/{conversation_id}/messages",
            body
        )

        if "error" in result:
            return result

        return {
            "message_id": result.get("id"),
            "conversation_id": conversation_id,
            "sent": True
        }

    except Exception as e:
        return {"error": f"Failed to send message: {str(e)}"}


async def send_adaptive_card(conversation_id: str, card: dict) -> dict:
    """Send adaptive card to Teams."""
    try:
        result = await graph_request(
            "POST",
            f"/chats/{conversation_id}/messages",
            {
                "attachments": [{
                    "contentType": "application/vnd.microsoft.card.adaptive",
                    "content": card
                }]
            }
        )

        if "error" in result:
            return result

        return {
            "message_id": result.get("id"),
            "conversation_id": conversation_id,
            "card_sent": True
        }

    except Exception as e:
        return {"error": f"Failed to send card: {str(e)}"}


async def create_meeting(subject: str, attendees: list,
                        start_time: str, duration_minutes: int = 30) -> dict:
    """Create Teams meeting."""
    try:
        from datetime import datetime, timedelta

        start = datetime.fromisoformat(start_time.replace('Z', '+00:00'))
        end = start + timedelta(minutes=duration_minutes)

        result = await graph_request(
            "POST",
            "/me/onlineMeetings",
            {
                "subject": subject,
                "startDateTime": start.isoformat(),
                "endDateTime": end.isoformat(),
                "participants": {
                    "attendees": [
                        {"upn": email, "role": "attendee"}
                        for email in attendees
                    ]
                }
            }
        )

        if "error" in result:
            return result

        return {
            "meeting_id": result.get("id"),
            "join_url": result.get("joinWebUrl"),
            "subject": subject,
            "start_time": start_time,
            "duration_minutes": duration_minutes
        }

    except Exception as e:
        return {"error": f"Failed to create meeting: {str(e)}"}


async def get_channel_messages(team_id: str, channel_id: str,
                               limit: int = 50) -> dict:
    """Get messages from channel."""
    try:
        result = await graph_request(
            "GET",
            f"/teams/{team_id}/channels/{channel_id}/messages?$top={limit}"
        )

        if "error" in result:
            return result

        messages = result.get("value", [])

        return {
            "team_id": team_id,
            "channel_id": channel_id,
            "count": len(messages),
            "messages": [{
                "id": m.get("id"),
                "from": m.get("from", {}).get("user", {}).get("displayName"),
                "content": m.get("body", {}).get("content"),
                "created": m.get("createdDateTime")
            } for m in messages]
        }

    except Exception as e:
        return {"error": f"Failed to get messages: {str(e)}"}


async def mention_user(conversation_id: str, user_id: str,
                      message: str) -> dict:
    """Send message with user mention."""
    try:
        # Get user details
        user = await graph_request("GET", f"/users/{user_id}")

        if "error" in user:
            return user

        mention_text = f"<at id=\"0\">{user.get('displayName')}</at>"

        result = await graph_request(
            "POST",
            f"/chats/{conversation_id}/messages",
            {
                "body": {
                    "contentType": "html",
                    "content": f"{mention_text} {message}"
                },
                "mentions": [{
                    "id": 0,
                    "mentionText": user.get("displayName"),
                    "mentioned": {
                        "user": {
                            "id": user_id,
                            "displayName": user.get("displayName"),
                            "userIdentityType": "aadUser"
                        }
                    }
                }]
            }
        )

        if "error" in result:
            return result

        return {
            "message_id": result.get("id"),
            "mentioned_user": user.get("displayName"),
            "sent": True
        }

    except Exception as e:
        return {"error": f"Failed to mention user: {str(e)}"}


async def get_user_presence(user_id: str) -> dict:
    """Get user presence status."""
    try:
        result = await graph_request("GET", f"/users/{user_id}/presence")

        if "error" in result:
            return result

        return {
            "user_id": user_id,
            "availability": result.get("availability"),
            "activity": result.get("activity"),
            "status_message": result.get("statusMessage", {}).get("message", {}).get("content")
        }

    except Exception as e:
        return {"error": f"Failed to get presence: {str(e)}"}
```

## Teams Bot Implementation

Create a Bot Framework bot:

```python
# bot.py
from botbuilder.core import TurnContext, ActivityHandler
from botbuilder.schema import Activity, Attachment, CardAction
from gantz import MCPClient
import json

mcp = MCPClient(config_path='gantz.yaml')


class TeamsBot(ActivityHandler):
    """MCP-powered Teams bot."""

    async def on_message_activity(self, turn_context: TurnContext):
        """Handle incoming messages."""
        text = turn_context.activity.text.strip().lower()

        # Remove bot mention
        if turn_context.activity.entities:
            for entity in turn_context.activity.entities:
                if entity.type == "mention":
                    text = text.replace(entity.text.lower(), "").strip()

        # Route to appropriate handler
        if text.startswith("help"):
            await self.send_help_card(turn_context)
        elif text.startswith("summarize"):
            await self.summarize_conversation(turn_context)
        elif text.startswith("schedule"):
            await self.schedule_meeting(turn_context, text)
        elif text.startswith("task"):
            await self.create_task(turn_context, text)
        else:
            await self.ai_response(turn_context, text)

    async def ai_response(self, turn_context: TurnContext, query: str):
        """Generate AI response."""
        # Show typing indicator
        await turn_context.send_activity(Activity(type="typing"))

        result = mcp.execute_tool('ai_chat', {
            'prompt': query,
            'context': f"Teams conversation with {turn_context.activity.from_property.name}"
        })

        response = result.get('response', 'I apologize, I could not process your request.')
        await turn_context.send_activity(response)

    async def send_help_card(self, turn_context: TurnContext):
        """Send help adaptive card."""
        card = {
            "$schema": "http://adaptivecards.io/schemas/adaptive-card.json",
            "type": "AdaptiveCard",
            "version": "1.4",
            "body": [
                {
                    "type": "TextBlock",
                    "text": "🤖 AI Assistant Commands",
                    "weight": "bolder",
                    "size": "large"
                },
                {
                    "type": "TextBlock",
                    "text": "Here's what I can help you with:",
                    "wrap": True
                },
                {
                    "type": "FactSet",
                    "facts": [
                        {"title": "summarize", "value": "Summarize the conversation"},
                        {"title": "schedule", "value": "Schedule a meeting"},
                        {"title": "task", "value": "Create a task"},
                        {"title": "help", "value": "Show this help"}
                    ]
                }
            ],
            "actions": [
                {
                    "type": "Action.Submit",
                    "title": "Get Started",
                    "data": {"action": "get_started"}
                }
            ]
        }

        attachment = Attachment(
            content_type="application/vnd.microsoft.card.adaptive",
            content=card
        )

        await turn_context.send_activity(
            Activity(attachments=[attachment])
        )

    async def summarize_conversation(self, turn_context: TurnContext):
        """Summarize channel conversation."""
        await turn_context.send_activity(Activity(type="typing"))

        # Get conversation context
        conversation = turn_context.activity.conversation
        team_id = conversation.tenant_id
        channel_id = conversation.id

        messages = mcp.execute_tool('get_channel_messages', {
            'team_id': team_id,
            'channel_id': channel_id,
            'limit': 30
        })

        if 'error' in messages:
            await turn_context.send_activity("Sorry, I couldn't retrieve the conversation.")
            return

        # Summarize with AI
        content = "\n".join([
            f"{m['from']}: {m['content']}"
            for m in messages.get('messages', [])
        ])

        summary = mcp.execute_tool('summarize', {
            'content': content,
            'max_length': 500
        })

        card = {
            "type": "AdaptiveCard",
            "version": "1.4",
            "body": [
                {
                    "type": "TextBlock",
                    "text": "📝 Conversation Summary",
                    "weight": "bolder",
                    "size": "medium"
                },
                {
                    "type": "TextBlock",
                    "text": summary.get('summary', 'Could not generate summary'),
                    "wrap": True
                },
                {
                    "type": "TextBlock",
                    "text": f"Based on {len(messages.get('messages', []))} messages",
                    "size": "small",
                    "isSubtle": True
                }
            ]
        }

        attachment = Attachment(
            content_type="application/vnd.microsoft.card.adaptive",
            content=card
        )

        await turn_context.send_activity(Activity(attachments=[attachment]))

    async def schedule_meeting(self, turn_context: TurnContext, text: str):
        """Schedule a meeting from natural language."""
        await turn_context.send_activity(Activity(type="typing"))

        # Parse meeting details with AI
        parsed = mcp.execute_tool('parse_meeting_request', {
            'text': text,
            'user_timezone': 'America/New_York'
        })

        if parsed.get('needs_clarification'):
            await turn_context.send_activity(parsed.get('clarification_message'))
            return

        # Send confirmation card
        card = {
            "type": "AdaptiveCard",
            "version": "1.4",
            "body": [
                {
                    "type": "TextBlock",
                    "text": "📅 Schedule Meeting",
                    "weight": "bolder"
                },
                {
                    "type": "Input.Text",
                    "id": "subject",
                    "label": "Subject",
                    "value": parsed.get('subject', '')
                },
                {
                    "type": "Input.Date",
                    "id": "date",
                    "label": "Date",
                    "value": parsed.get('date', '')
                },
                {
                    "type": "Input.Time",
                    "id": "time",
                    "label": "Time",
                    "value": parsed.get('time', '')
                },
                {
                    "type": "Input.Number",
                    "id": "duration",
                    "label": "Duration (minutes)",
                    "value": parsed.get('duration', 30)
                }
            ],
            "actions": [
                {
                    "type": "Action.Submit",
                    "title": "Schedule",
                    "data": {"action": "create_meeting"}
                }
            ]
        }

        attachment = Attachment(
            content_type="application/vnd.microsoft.card.adaptive",
            content=card
        )

        await turn_context.send_activity(Activity(attachments=[attachment]))

    async def on_invoke_activity(self, turn_context: TurnContext):
        """Handle adaptive card submissions."""
        data = turn_context.activity.value

        if data.get("action") == "create_meeting":
            result = mcp.execute_tool('create_meeting', {
                'subject': data.get('subject'),
                'start_time': f"{data.get('date')}T{data.get('time')}:00",
                'duration_minutes': int(data.get('duration', 30)),
                'attendees': []
            })

            if 'error' in result:
                await turn_context.send_activity(f"Failed to create meeting: {result['error']}")
            else:
                await turn_context.send_activity(
                    f"✅ Meeting scheduled! Join: {result.get('join_url')}"
                )

        return Activity()
```

## Adaptive Card Templates

Create reusable card templates:

```python
# cards.py

def approval_card(title: str, description: str, request_id: str) -> dict:
    """Create approval request card."""
    return {
        "type": "AdaptiveCard",
        "version": "1.4",
        "body": [
            {
                "type": "TextBlock",
                "text": "⚡ Approval Required",
                "weight": "bolder",
                "size": "large"
            },
            {
                "type": "TextBlock",
                "text": title,
                "weight": "bolder"
            },
            {
                "type": "TextBlock",
                "text": description,
                "wrap": True
            }
        ],
        "actions": [
            {
                "type": "Action.Submit",
                "title": "✅ Approve",
                "style": "positive",
                "data": {"action": "approve", "request_id": request_id}
            },
            {
                "type": "Action.Submit",
                "title": "❌ Reject",
                "style": "destructive",
                "data": {"action": "reject", "request_id": request_id}
            }
        ]
    }


def status_card(title: str, items: list) -> dict:
    """Create status report card."""
    facts = [{"title": item["label"], "value": item["value"]} for item in items]

    return {
        "type": "AdaptiveCard",
        "version": "1.4",
        "body": [
            {
                "type": "TextBlock",
                "text": title,
                "weight": "bolder",
                "size": "medium"
            },
            {
                "type": "FactSet",
                "facts": facts
            }
        ]
    }
```

## Deploy with Gantz CLI

Deploy your Teams bot:

```bash
# Install Gantz
npm install -g gantz

# Initialize Teams project
gantz init --template teams-bot

# Configure Azure Bot Service
az bot create --resource-group myRG --name my-teams-bot

# Deploy to Azure
gantz deploy --platform azure-functions

# Register with Teams
gantz run register_teams_bot --manifest-path manifest.json
```

Build enterprise AI assistants at [gantz.run](https://gantz.run).

## Related Reading

- [Discord MCP Integration](/post/discord-mcp-integration/) - Compare with Discord
- [Azure Functions MCP](/post/azure-functions-mcp/) - Azure deployment
- [MCP Streaming Patterns](/post/mcp-streaming-patterns/) - Stream responses

## Conclusion

Microsoft Teams and MCP create powerful enterprise AI assistants. With adaptive cards, meeting integration, and Graph API access, you can build intelligent bots that streamline workflows and enhance productivity.

Start building Teams bots with Gantz today.
