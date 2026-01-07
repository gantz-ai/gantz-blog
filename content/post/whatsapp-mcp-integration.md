+++
title = "WhatsApp MCP Integration: Build Business Messaging AI Agents"
image = "images/whatsapp-mcp-integration.webp"
date = 2025-05-14
description = "Create AI-powered WhatsApp business bots with MCP tools. Learn Cloud API, message templates, and customer engagement automation with Gantz."
draft = false
tags = ['whatsapp', 'business', 'messaging', 'mcp', 'meta', 'gantz']
voice = false

[howto]
name = "How To Build AI WhatsApp Bots with MCP"
totalTime = 35
[[howto.steps]]
name = "Set up WhatsApp Business API"
text = "Configure WhatsApp Cloud API in Meta Developer portal"
[[howto.steps]]
name = "Define MCP tools"
text = "Create tool definitions for WhatsApp operations"
[[howto.steps]]
name = "Implement handlers"
text = "Build message handlers for text, media, and templates"
[[howto.steps]]
name = "Add AI capabilities"
text = "Integrate AI-powered customer support and automation"
[[howto.steps]]
name = "Deploy with Gantz"
text = "Deploy your WhatsApp bot using Gantz CLI"
+++

WhatsApp is the world's most popular messaging platform with over 2 billion users. With MCP integration and the WhatsApp Cloud API, you can build intelligent business bots that provide 24/7 customer support and automate engagement.

## Why WhatsApp MCP Integration?

AI-powered WhatsApp bots enable business capabilities:

- **Customer support**: 24/7 automated assistance
- **Order updates**: Transaction notifications
- **Lead qualification**: AI-powered conversations
- **Appointment booking**: Automated scheduling
- **Product catalog**: Interactive shopping

## WhatsApp MCP Tool Definition

Configure WhatsApp tools in Gantz:

```yaml
# gantz.yaml
name: whatsapp-mcp-tools
version: 1.0.0

tools:
  send_text:
    description: "Send text message to WhatsApp user"
    parameters:
      phone_number:
        type: string
        description: "Phone number with country code"
        required: true
      message:
        type: string
        required: true
    handler: whatsapp.send_text

  send_template:
    description: "Send approved message template"
    parameters:
      phone_number:
        type: string
        required: true
      template_name:
        type: string
        required: true
      language:
        type: string
        default: "en_US"
      components:
        type: array
        description: "Template variable components"
    handler: whatsapp.send_template

  send_interactive:
    description: "Send interactive message with buttons or list"
    parameters:
      phone_number:
        type: string
        required: true
      type:
        type: string
        description: "button, list, or product"
        required: true
      body:
        type: string
        required: true
      options:
        type: array
        required: true
    handler: whatsapp.send_interactive

  send_media:
    description: "Send media message (image, document, video)"
    parameters:
      phone_number:
        type: string
        required: true
      media_type:
        type: string
        description: "image, document, audio, video"
        required: true
      media_url:
        type: string
        required: true
      caption:
        type: string
    handler: whatsapp.send_media

  mark_read:
    description: "Mark message as read"
    parameters:
      message_id:
        type: string
        required: true
    handler: whatsapp.mark_read

  get_media:
    description: "Download media from message"
    parameters:
      media_id:
        type: string
        required: true
    handler: whatsapp.get_media
```

## Handler Implementation

Build WhatsApp Cloud API handlers:

```python
# handlers/whatsapp.py
import httpx
import os
from typing import Optional

GRAPH_API = "https://graph.facebook.com/v18.0"
PHONE_NUMBER_ID = os.environ['WHATSAPP_PHONE_NUMBER_ID']
ACCESS_TOKEN = os.environ['WHATSAPP_ACCESS_TOKEN']


def get_headers():
    """Get authorization headers."""
    return {
        "Authorization": f"Bearer {ACCESS_TOKEN}",
        "Content-Type": "application/json"
    }


async def api_request(method: str, path: str,
                      data: dict = None) -> dict:
    """Make Graph API request."""
    async with httpx.AsyncClient() as client:
        response = await client.request(
            method,
            f"{GRAPH_API}{path}",
            json=data,
            headers=get_headers(),
            timeout=30.0
        )

        result = response.json()

        if response.status_code >= 400:
            error = result.get("error", {})
            return {"error": error.get("message", "Unknown error")}

        return result


async def send_text(phone_number: str, message: str) -> dict:
    """Send text message."""
    try:
        result = await api_request(
            "POST",
            f"/{PHONE_NUMBER_ID}/messages",
            {
                "messaging_product": "whatsapp",
                "recipient_type": "individual",
                "to": phone_number,
                "type": "text",
                "text": {"body": message}
            }
        )

        if "error" in result:
            return result

        return {
            "message_id": result.get("messages", [{}])[0].get("id"),
            "phone_number": phone_number,
            "sent": True
        }

    except Exception as e:
        return {"error": f"Failed to send message: {str(e)}"}


async def send_template(phone_number: str, template_name: str,
                        language: str = "en_US",
                        components: list = None) -> dict:
    """Send approved message template."""
    try:
        template = {
            "name": template_name,
            "language": {"code": language}
        }

        if components:
            template["components"] = components

        result = await api_request(
            "POST",
            f"/{PHONE_NUMBER_ID}/messages",
            {
                "messaging_product": "whatsapp",
                "to": phone_number,
                "type": "template",
                "template": template
            }
        )

        if "error" in result:
            return result

        return {
            "message_id": result.get("messages", [{}])[0].get("id"),
            "template": template_name,
            "sent": True
        }

    except Exception as e:
        return {"error": f"Failed to send template: {str(e)}"}


async def send_interactive(phone_number: str, interactive_type: str,
                          body: str, options: list) -> dict:
    """Send interactive message."""
    try:
        interactive = {
            "type": interactive_type,
            "body": {"text": body}
        }

        if interactive_type == "button":
            interactive["action"] = {
                "buttons": [
                    {
                        "type": "reply",
                        "reply": {"id": opt["id"], "title": opt["title"]}
                    }
                    for opt in options[:3]  # Max 3 buttons
                ]
            }

        elif interactive_type == "list":
            interactive["action"] = {
                "button": "Options",
                "sections": [{
                    "title": "Choose an option",
                    "rows": [
                        {"id": opt["id"], "title": opt["title"], "description": opt.get("description", "")}
                        for opt in options[:10]  # Max 10 items
                    ]
                }]
            }

        result = await api_request(
            "POST",
            f"/{PHONE_NUMBER_ID}/messages",
            {
                "messaging_product": "whatsapp",
                "to": phone_number,
                "type": "interactive",
                "interactive": interactive
            }
        )

        if "error" in result:
            return result

        return {
            "message_id": result.get("messages", [{}])[0].get("id"),
            "type": interactive_type,
            "sent": True
        }

    except Exception as e:
        return {"error": f"Failed to send interactive: {str(e)}"}


async def send_media(phone_number: str, media_type: str,
                    media_url: str, caption: str = None) -> dict:
    """Send media message."""
    try:
        media_object = {"link": media_url}
        if caption:
            media_object["caption"] = caption

        result = await api_request(
            "POST",
            f"/{PHONE_NUMBER_ID}/messages",
            {
                "messaging_product": "whatsapp",
                "to": phone_number,
                "type": media_type,
                media_type: media_object
            }
        )

        if "error" in result:
            return result

        return {
            "message_id": result.get("messages", [{}])[0].get("id"),
            "media_type": media_type,
            "sent": True
        }

    except Exception as e:
        return {"error": f"Failed to send media: {str(e)}"}


async def mark_read(message_id: str) -> dict:
    """Mark message as read."""
    try:
        result = await api_request(
            "POST",
            f"/{PHONE_NUMBER_ID}/messages",
            {
                "messaging_product": "whatsapp",
                "status": "read",
                "message_id": message_id
            }
        )

        return {"message_id": message_id, "marked_read": True}

    except Exception as e:
        return {"error": f"Failed to mark read: {str(e)}"}


async def get_media(media_id: str) -> dict:
    """Get media URL for download."""
    try:
        # Get media URL
        result = await api_request("GET", f"/{media_id}")

        if "error" in result:
            return result

        media_url = result.get("url")

        # Download media
        async with httpx.AsyncClient() as client:
            response = await client.get(
                media_url,
                headers=get_headers()
            )

            return {
                "media_id": media_id,
                "mime_type": result.get("mime_type"),
                "file_size": result.get("file_size"),
                "data": response.content
            }

    except Exception as e:
        return {"error": f"Failed to get media: {str(e)}"}
```

## WhatsApp Bot Implementation

Create a complete bot with webhook handling:

```python
# bot.py
from fastapi import FastAPI, Request, HTTPException
from gantz import MCPClient
import os
import hmac
import hashlib

app = FastAPI()
mcp = MCPClient(config_path='gantz.yaml')

VERIFY_TOKEN = os.environ['WHATSAPP_VERIFY_TOKEN']
APP_SECRET = os.environ['WHATSAPP_APP_SECRET']


def verify_signature(payload: bytes, signature: str) -> bool:
    """Verify webhook signature."""
    expected = hmac.new(
        APP_SECRET.encode(),
        payload,
        hashlib.sha256
    ).hexdigest()
    return hmac.compare_digest(f"sha256={expected}", signature)


@app.get("/webhook")
async def verify_webhook(request: Request):
    """Verify webhook for WhatsApp."""
    params = request.query_params

    mode = params.get("hub.mode")
    token = params.get("hub.verify_token")
    challenge = params.get("hub.challenge")

    if mode == "subscribe" and token == VERIFY_TOKEN:
        return int(challenge)

    raise HTTPException(status_code=403, detail="Verification failed")


@app.post("/webhook")
async def receive_webhook(request: Request):
    """Handle incoming WhatsApp messages."""
    # Verify signature
    signature = request.headers.get("X-Hub-Signature-256", "")
    payload = await request.body()

    if not verify_signature(payload, signature):
        raise HTTPException(status_code=403, detail="Invalid signature")

    data = await request.json()

    # Process messages
    for entry in data.get("entry", []):
        for change in entry.get("changes", []):
            if change.get("field") == "messages":
                value = change.get("value", {})

                for message in value.get("messages", []):
                    await process_message(message, value.get("contacts", []))

    return {"status": "ok"}


async def process_message(message: dict, contacts: list):
    """Process incoming message."""
    phone = message.get("from")
    message_id = message.get("id")
    message_type = message.get("type")

    # Mark as read
    mcp.execute_tool('mark_read', {'message_id': message_id})

    # Get contact name
    contact_name = "Customer"
    for contact in contacts:
        if contact.get("wa_id") == phone:
            contact_name = contact.get("profile", {}).get("name", "Customer")
            break

    # Route by message type
    if message_type == "text":
        await handle_text_message(phone, message.get("text", {}).get("body", ""), contact_name)

    elif message_type == "interactive":
        interactive = message.get("interactive", {})
        if interactive.get("type") == "button_reply":
            button_id = interactive.get("button_reply", {}).get("id")
            await handle_button_reply(phone, button_id)
        elif interactive.get("type") == "list_reply":
            list_id = interactive.get("list_reply", {}).get("id")
            await handle_list_reply(phone, list_id)

    elif message_type == "image":
        media_id = message.get("image", {}).get("id")
        await handle_image(phone, media_id)

    elif message_type == "location":
        location = message.get("location", {})
        await handle_location(phone, location)


async def handle_text_message(phone: str, text: str, name: str):
    """Handle text messages with AI."""
    text_lower = text.lower()

    # Check for keywords
    if any(word in text_lower for word in ["hi", "hello", "hey"]):
        await send_welcome(phone, name)

    elif "menu" in text_lower or "options" in text_lower:
        await send_main_menu(phone)

    elif "order" in text_lower:
        await send_order_menu(phone)

    elif "support" in text_lower or "help" in text_lower:
        await send_support_options(phone)

    else:
        # AI response for general queries
        result = mcp.execute_tool('ai_chat', {
            'prompt': text,
            'context': f"WhatsApp customer support. Customer: {name}",
            'personality': 'helpful_business'
        })

        response = result.get('response', "I'm here to help! Could you please rephrase your question?")

        mcp.execute_tool('send_text', {
            'phone_number': phone,
            'message': response
        })


async def send_welcome(phone: str, name: str):
    """Send welcome message with menu."""
    mcp.execute_tool('send_interactive', {
        'phone_number': phone,
        'type': 'button',
        'body': f"👋 Hello {name}! Welcome to our business.\n\nHow can I help you today?",
        'options': [
            {'id': 'browse', 'title': '🛍️ Browse Products'},
            {'id': 'orders', 'title': '📦 My Orders'},
            {'id': 'support', 'title': '💬 Get Support'}
        ]
    })


async def send_main_menu(phone: str):
    """Send main menu list."""
    mcp.execute_tool('send_interactive', {
        'phone_number': phone,
        'type': 'list',
        'body': "Choose from our menu options:",
        'options': [
            {'id': 'products', 'title': 'Products', 'description': 'Browse our catalog'},
            {'id': 'orders', 'title': 'Order Status', 'description': 'Track your orders'},
            {'id': 'account', 'title': 'My Account', 'description': 'Account settings'},
            {'id': 'support', 'title': 'Support', 'description': 'Get help'},
            {'id': 'faq', 'title': 'FAQ', 'description': 'Common questions'}
        ]
    })


async def handle_button_reply(phone: str, button_id: str):
    """Handle button click."""
    handlers = {
        'browse': send_product_catalog,
        'orders': send_order_status,
        'support': send_support_options
    }

    handler = handlers.get(button_id)
    if handler:
        await handler(phone)
    else:
        mcp.execute_tool('send_text', {
            'phone_number': phone,
            'message': "I didn't understand that selection. Please try again."
        })


async def send_product_catalog(phone: str):
    """Send product catalog."""
    # Fetch products
    products = mcp.execute_tool('get_products', {'limit': 5})

    message = "🛍️ *Featured Products*\n\n"
    for product in products.get('items', []):
        message += f"*{product['name']}*\n"
        message += f"💰 ${product['price']}\n"
        message += f"{product['description'][:50]}...\n\n"

    mcp.execute_tool('send_text', {
        'phone_number': phone,
        'message': message
    })


async def send_order_status(phone: str):
    """Send order status."""
    # Fetch user orders
    orders = mcp.execute_tool('get_user_orders', {'phone': phone})

    if not orders.get('items'):
        mcp.execute_tool('send_text', {
            'phone_number': phone,
            'message': "You don't have any recent orders."
        })
        return

    order = orders['items'][0]
    mcp.execute_tool('send_text', {
        'phone_number': phone,
        'message': f"📦 *Order #{order['id']}*\n\n"
                   f"Status: {order['status']}\n"
                   f"Items: {order['item_count']}\n"
                   f"Total: ${order['total']}\n\n"
                   f"Estimated delivery: {order['delivery_date']}"
    })


async def handle_image(phone: str, media_id: str):
    """Handle image message with AI analysis."""
    # Get media
    media = mcp.execute_tool('get_media', {'media_id': media_id})

    if 'error' in media:
        mcp.execute_tool('send_text', {
            'phone_number': phone,
            'message': "Sorry, I couldn't process your image."
        })
        return

    # Analyze with AI
    result = mcp.execute_tool('analyze_image', {
        'image_data': media['data'],
        'analysis_type': 'product_match'
    })

    if result.get('matched_products'):
        products = result['matched_products']
        message = "📸 I found similar products:\n\n"
        for product in products[:3]:
            message += f"• {product['name']} - ${product['price']}\n"

        mcp.execute_tool('send_text', {
            'phone_number': phone,
            'message': message
        })
    else:
        mcp.execute_tool('send_text', {
            'phone_number': phone,
            'message': result.get('description', 'I received your image!')
        })


async def handle_location(phone: str, location: dict):
    """Handle location sharing."""
    lat = location.get('latitude')
    lng = location.get('longitude')

    # Find nearby stores
    stores = mcp.execute_tool('find_nearby_stores', {
        'latitude': lat,
        'longitude': lng,
        'radius_km': 10
    })

    if stores.get('items'):
        message = "📍 Nearby stores:\n\n"
        for store in stores['items'][:3]:
            message += f"*{store['name']}*\n"
            message += f"📍 {store['address']}\n"
            message += f"🕐 {store['hours']}\n\n"

        mcp.execute_tool('send_text', {
            'phone_number': phone,
            'message': message
        })
    else:
        mcp.execute_tool('send_text', {
            'phone_number': phone,
            'message': "Sorry, we don't have stores in your area yet."
        })
```

## Message Templates

Create and use approved templates:

```python
# templates.py
from gantz import MCPClient

mcp = MCPClient()


def send_order_confirmation(phone: str, order_id: str, total: str):
    """Send order confirmation template."""
    mcp.execute_tool('send_template', {
        'phone_number': phone,
        'template_name': 'order_confirmation',
        'language': 'en_US',
        'components': [
            {
                'type': 'body',
                'parameters': [
                    {'type': 'text', 'text': order_id},
                    {'type': 'currency', 'currency': {'code': 'USD', 'amount_1000': int(float(total) * 1000)}}
                ]
            }
        ]
    })


def send_shipping_update(phone: str, tracking_number: str, carrier: str):
    """Send shipping update template."""
    mcp.execute_tool('send_template', {
        'phone_number': phone,
        'template_name': 'shipping_update',
        'components': [
            {
                'type': 'body',
                'parameters': [
                    {'type': 'text', 'text': tracking_number},
                    {'type': 'text', 'text': carrier}
                ]
            },
            {
                'type': 'button',
                'sub_type': 'url',
                'index': '0',
                'parameters': [
                    {'type': 'text', 'text': tracking_number}
                ]
            }
        ]
    })


def send_appointment_reminder(phone: str, date: str, time: str, location: str):
    """Send appointment reminder template."""
    mcp.execute_tool('send_template', {
        'phone_number': phone,
        'template_name': 'appointment_reminder',
        'components': [
            {
                'type': 'body',
                'parameters': [
                    {'type': 'text', 'text': date},
                    {'type': 'text', 'text': time},
                    {'type': 'text', 'text': location}
                ]
            }
        ]
    })
```

## Deploy with Gantz CLI

Deploy your WhatsApp bot:

```bash
# Install Gantz
npm install -g gantz

# Initialize WhatsApp project
gantz init --template whatsapp-bot

# Set environment variables
export WHATSAPP_PHONE_NUMBER_ID=your-phone-number-id
export WHATSAPP_ACCESS_TOKEN=your-access-token
export WHATSAPP_VERIFY_TOKEN=your-verify-token
export WHATSAPP_APP_SECRET=your-app-secret

# Deploy
gantz deploy --platform railway

# Configure webhook in Meta Developer Portal
# URL: https://your-app.railway.app/webhook
```

Build business messaging AI at [gantz.run](https://gantz.run).

## Related Reading

- [Telegram MCP Integration](/post/telegram-mcp-integration/) - Compare with Telegram
- [Twilio MCP Integration](/post/twilio-mcp-integration/) - SMS and voice
- [MCP Connection Pooling](/post/mcp-connection-pooling/) - Handle rate limits

## Conclusion

WhatsApp and MCP create a powerful platform for business messaging. With interactive messages, templates, and AI capabilities, you can build automated customer experiences that scale to billions of potential users.

Start building WhatsApp business bots with Gantz today.
