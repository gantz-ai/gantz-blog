+++
title = "Twilio MCP Integration: Build AI-Powered SMS and Voice Agents"
image = "images/twilio-mcp-integration.webp"
date = 2025-05-15
description = "Create intelligent SMS and voice agents with Twilio and MCP. Learn programmable messaging, voice IVR, and conversation handling with Gantz."
summary = "Build AI-powered communication agents with Twilio. Send smart SMS, handle inbound calls with context-aware IVR, manage multi-channel conversations, and scale to 180+ countries. Includes handlers for programmable messaging, voice flows, and conversation management."
draft = false
tags = ['twilio', 'sms', 'voice', 'mcp', 'telephony', 'gantz']
voice = false

[howto]
name = "How To Build AI Agents with Twilio and MCP"
totalTime = 35
[[howto.steps]]
name = "Set up Twilio account"
text = "Configure Twilio with phone numbers and messaging services"
[[howto.steps]]
name = "Define MCP tools"
text = "Create tool definitions for SMS, MMS, and voice operations"
[[howto.steps]]
name = "Implement handlers"
text = "Build message and call handlers with AI integration"
[[howto.steps]]
name = "Create voice flows"
text = "Design IVR and conversational voice experiences"
[[howto.steps]]
name = "Deploy with Gantz"
text = "Deploy your Twilio agents using Gantz CLI"
+++

Twilio provides the most powerful APIs for SMS, voice, and video communication. With MCP integration, you can build intelligent agents that handle customer communications across channels with AI-powered responses.

## Why Twilio MCP Integration?

Twilio with AI capabilities enables sophisticated communication:

- **Programmable SMS**: Two-way messaging at scale
- **Voice IVR**: AI-powered phone systems
- **Conversations**: Multi-channel messaging
- **Video**: WebRTC video integration
- **Global reach**: 180+ countries supported

## Twilio MCP Tool Definition

Configure Twilio tools in Gantz:

```yaml
# gantz.yaml
name: twilio-mcp-tools
version: 1.0.0

tools:
  send_sms:
    description: "Send SMS message"
    parameters:
      to:
        type: string
        description: "Recipient phone number"
        required: true
      body:
        type: string
        required: true
      media_url:
        type: string
        description: "URL for MMS media"
    handler: twilio.send_sms

  send_whatsapp:
    description: "Send WhatsApp message via Twilio"
    parameters:
      to:
        type: string
        required: true
      body:
        type: string
        required: true
    handler: twilio.send_whatsapp

  make_call:
    description: "Initiate outbound call"
    parameters:
      to:
        type: string
        required: true
      twiml_url:
        type: string
        description: "URL for TwiML instructions"
      message:
        type: string
        description: "Message to speak"
    handler: twilio.make_call

  get_messages:
    description: "Get message history"
    parameters:
      phone_number:
        type: string
        description: "Filter by phone number"
      limit:
        type: integer
        default: 20
    handler: twilio.get_messages

  lookup_phone:
    description: "Lookup phone number information"
    parameters:
      phone_number:
        type: string
        required: true
      type:
        type: string
        description: "carrier, caller-name, etc."
    handler: twilio.lookup_phone

  create_conversation:
    description: "Create Conversations thread"
    parameters:
      friendly_name:
        type: string
        required: true
    handler: twilio.create_conversation

  verify_phone:
    description: "Send verification code"
    parameters:
      phone_number:
        type: string
        required: true
      channel:
        type: string
        description: "sms, call, email"
        default: "sms"
    handler: twilio.verify_phone
```

## Handler Implementation

Build Twilio operation handlers:

```python
# handlers/twilio.py
from twilio.rest import Client
from twilio.twiml.voice_response import VoiceResponse, Gather
from twilio.twiml.messaging_response import MessagingResponse
import os

# Initialize Twilio client
client = Client(
    os.environ['TWILIO_ACCOUNT_SID'],
    os.environ['TWILIO_AUTH_TOKEN']
)

TWILIO_PHONE = os.environ['TWILIO_PHONE_NUMBER']


async def send_sms(to: str, body: str, media_url: str = None) -> dict:
    """Send SMS or MMS message."""
    try:
        message_params = {
            'to': to,
            'from_': TWILIO_PHONE,
            'body': body
        }

        if media_url:
            message_params['media_url'] = [media_url]

        message = client.messages.create(**message_params)

        return {
            'sid': message.sid,
            'to': to,
            'status': message.status,
            'sent': True
        }

    except Exception as e:
        return {'error': f'Failed to send SMS: {str(e)}'}


async def send_whatsapp(to: str, body: str) -> dict:
    """Send WhatsApp message via Twilio."""
    try:
        # WhatsApp numbers need whatsapp: prefix
        message = client.messages.create(
            to=f'whatsapp:{to}',
            from_=f'whatsapp:{TWILIO_PHONE}',
            body=body
        )

        return {
            'sid': message.sid,
            'to': to,
            'status': message.status,
            'sent': True
        }

    except Exception as e:
        return {'error': f'Failed to send WhatsApp: {str(e)}'}


async def make_call(to: str, twiml_url: str = None,
                   message: str = None) -> dict:
    """Initiate outbound call."""
    try:
        call_params = {
            'to': to,
            'from_': TWILIO_PHONE
        }

        if twiml_url:
            call_params['url'] = twiml_url
        elif message:
            # Create TwiML for simple message
            response = VoiceResponse()
            response.say(message, voice='Polly.Joanna')
            call_params['twiml'] = str(response)

        call = client.calls.create(**call_params)

        return {
            'sid': call.sid,
            'to': to,
            'status': call.status,
            'initiated': True
        }

    except Exception as e:
        return {'error': f'Failed to make call: {str(e)}'}


async def get_messages(phone_number: str = None, limit: int = 20) -> dict:
    """Get message history."""
    try:
        params = {'limit': limit}

        if phone_number:
            params['to'] = phone_number

        messages = client.messages.list(**params)

        return {
            'count': len(messages),
            'messages': [{
                'sid': m.sid,
                'from': m.from_,
                'to': m.to,
                'body': m.body,
                'status': m.status,
                'date_sent': m.date_sent.isoformat() if m.date_sent else None
            } for m in messages]
        }

    except Exception as e:
        return {'error': f'Failed to get messages: {str(e)}'}


async def lookup_phone(phone_number: str, lookup_type: str = None) -> dict:
    """Lookup phone number information."""
    try:
        params = {}
        if lookup_type:
            params['type'] = [lookup_type]

        phone_info = client.lookups.v2.phone_numbers(phone_number).fetch(**params)

        result = {
            'phone_number': phone_info.phone_number,
            'national_format': phone_info.national_format,
            'country_code': phone_info.country_code,
            'valid': phone_info.valid
        }

        if hasattr(phone_info, 'carrier') and phone_info.carrier:
            result['carrier'] = {
                'name': phone_info.carrier.get('name'),
                'type': phone_info.carrier.get('type')
            }

        if hasattr(phone_info, 'caller_name') and phone_info.caller_name:
            result['caller_name'] = phone_info.caller_name.get('caller_name')

        return result

    except Exception as e:
        return {'error': f'Lookup failed: {str(e)}'}


async def create_conversation(friendly_name: str) -> dict:
    """Create Conversations thread."""
    try:
        conversation = client.conversations.v1.conversations.create(
            friendly_name=friendly_name
        )

        return {
            'sid': conversation.sid,
            'friendly_name': conversation.friendly_name,
            'state': conversation.state,
            'created': True
        }

    except Exception as e:
        return {'error': f'Failed to create conversation: {str(e)}'}


async def verify_phone(phone_number: str, channel: str = 'sms') -> dict:
    """Send verification code."""
    try:
        verification = client.verify.v2.services(
            os.environ['TWILIO_VERIFY_SERVICE_SID']
        ).verifications.create(
            to=phone_number,
            channel=channel
        )

        return {
            'sid': verification.sid,
            'to': phone_number,
            'channel': channel,
            'status': verification.status
        }

    except Exception as e:
        return {'error': f'Verification failed: {str(e)}'}


async def check_verification(phone_number: str, code: str) -> dict:
    """Check verification code."""
    try:
        verification_check = client.verify.v2.services(
            os.environ['TWILIO_VERIFY_SERVICE_SID']
        ).verification_checks.create(
            to=phone_number,
            code=code
        )

        return {
            'to': phone_number,
            'status': verification_check.status,
            'valid': verification_check.status == 'approved'
        }

    except Exception as e:
        return {'error': f'Verification check failed: {str(e)}'}
```

## SMS Bot Implementation

Create an AI-powered SMS bot:

```python
# sms_bot.py
from fastapi import FastAPI, Request, Form
from fastapi.responses import Response
from twilio.twiml.messaging_response import MessagingResponse
from gantz import MCPClient
import os

app = FastAPI()
mcp = MCPClient(config_path='gantz.yaml')

# Store conversation state
conversations = {}


@app.post("/sms")
async def handle_sms(
    From: str = Form(...),
    To: str = Form(...),
    Body: str = Form(...),
    NumMedia: int = Form(default=0)
):
    """Handle incoming SMS."""
    phone = From
    message = Body.strip()

    # Get or create conversation state
    state = conversations.get(phone, {'history': [], 'context': {}})

    # Add message to history
    state['history'].append({'role': 'user', 'content': message})

    # Process with AI
    response_text = await process_message(phone, message, state)

    # Update state
    state['history'].append({'role': 'assistant', 'content': response_text})
    conversations[phone] = state

    # Create TwiML response
    response = MessagingResponse()
    response.message(response_text)

    return Response(content=str(response), media_type="application/xml")


async def process_message(phone: str, message: str, state: dict) -> str:
    """Process incoming message with AI."""
    message_lower = message.lower()

    # Check for commands
    if message_lower in ['stop', 'quit', 'bye']:
        conversations.pop(phone, None)
        return "Thanks for chatting! Text us anytime you need help."

    if message_lower == 'menu':
        return ("📱 Menu:\n"
                "1. Check order status\n"
                "2. Talk to support\n"
                "3. FAQ\n"
                "Reply with a number or ask anything!")

    if message_lower == '1' or 'order' in message_lower:
        result = mcp.execute_tool('get_order_status', {'phone': phone})
        if result.get('order'):
            order = result['order']
            return f"📦 Order #{order['id']}\nStatus: {order['status']}\nETA: {order['eta']}"
        return "No recent orders found. Need help with something else?"

    if message_lower == '2' or 'support' in message_lower:
        state['context']['mode'] = 'support'
        return "I've connected you to support mode. Describe your issue and I'll help or escalate if needed."

    # AI response
    result = mcp.execute_tool('ai_chat', {
        'prompt': message,
        'history': state['history'][-10:],  # Last 10 messages for context
        'context': f"SMS conversation with {phone}",
        'max_length': 160  # SMS character limit
    })

    response = result.get('response', "I'm not sure how to help with that. Try asking differently!")

    # Truncate if too long
    if len(response) > 160:
        response = response[:157] + "..."

    return response


@app.post("/sms/status")
async def handle_status(
    MessageSid: str = Form(...),
    MessageStatus: str = Form(...)
):
    """Handle SMS status callbacks."""
    # Log or process delivery status
    print(f"Message {MessageSid}: {MessageStatus}")
    return {"status": "ok"}
```

## Voice IVR Implementation

Build an AI-powered phone system:

```python
# voice_bot.py
from fastapi import FastAPI, Request, Form
from fastapi.responses import Response
from twilio.twiml.voice_response import VoiceResponse, Gather
from gantz import MCPClient
import os

app = FastAPI()
mcp = MCPClient(config_path='gantz.yaml')


@app.post("/voice/incoming")
async def handle_incoming_call(
    From: str = Form(...),
    To: str = Form(...),
    CallSid: str = Form(...)
):
    """Handle incoming voice call."""
    response = VoiceResponse()

    # Welcome message
    response.say(
        "Welcome to our AI-powered support line. "
        "Please tell me how I can help you today.",
        voice='Polly.Joanna'
    )

    # Gather speech input
    gather = Gather(
        input='speech',
        timeout=5,
        speech_timeout='auto',
        action='/voice/process',
        method='POST'
    )
    gather.say("I'm listening...")
    response.append(gather)

    # If no input
    response.say("I didn't hear anything. Goodbye!")
    response.hangup()

    return Response(content=str(response), media_type="application/xml")


@app.post("/voice/process")
async def process_speech(
    SpeechResult: str = Form(default=""),
    Confidence: float = Form(default=0.0),
    From: str = Form(...),
    CallSid: str = Form(...)
):
    """Process speech input and respond."""
    response = VoiceResponse()

    if not SpeechResult or Confidence < 0.5:
        response.say("Sorry, I couldn't understand that. Let me transfer you to an agent.")
        response.dial(os.environ.get('SUPPORT_PHONE', '+15551234567'))
        return Response(content=str(response), media_type="application/xml")

    # Process with AI
    result = mcp.execute_tool('ai_chat', {
        'prompt': SpeechResult,
        'context': 'Voice IVR support call',
        'personality': 'phone_support'
    })

    ai_response = result.get('response', "I'm having trouble processing your request.")

    # Check if we should transfer to human
    if result.get('should_transfer', False):
        response.say("Let me connect you with a specialist who can help better.")
        response.dial(os.environ.get('SUPPORT_PHONE'))
    else:
        # Speak AI response
        response.say(ai_response, voice='Polly.Joanna')

        # Ask for more input
        gather = Gather(
            input='speech',
            timeout=5,
            speech_timeout='auto',
            action='/voice/process',
            method='POST'
        )
        gather.say("Is there anything else I can help you with?")
        response.append(gather)

        # End call if no input
        response.say("Thank you for calling. Goodbye!")
        response.hangup()

    return Response(content=str(response), media_type="application/xml")


@app.post("/voice/menu")
async def voice_menu():
    """IVR menu system."""
    response = VoiceResponse()

    gather = Gather(
        num_digits=1,
        action='/voice/menu-handler',
        method='POST'
    )

    gather.say(
        "Press 1 for order status. "
        "Press 2 for technical support. "
        "Press 3 to speak with an agent. "
        "Press 0 to repeat this menu.",
        voice='Polly.Joanna'
    )

    response.append(gather)
    response.redirect('/voice/menu')

    return Response(content=str(response), media_type="application/xml")


@app.post("/voice/menu-handler")
async def handle_menu_selection(
    Digits: str = Form(...),
    From: str = Form(...)
):
    """Handle menu selection."""
    response = VoiceResponse()

    if Digits == '1':
        # Order status
        result = mcp.execute_tool('get_order_status', {'phone': From})
        if result.get('order'):
            order = result['order']
            response.say(
                f"Your order {order['id']} is {order['status']}. "
                f"Expected delivery is {order['eta']}.",
                voice='Polly.Joanna'
            )
        else:
            response.say("We couldn't find any recent orders for this number.")
        response.redirect('/voice/menu')

    elif Digits == '2':
        response.say("Connecting you to technical support.")
        response.redirect('/voice/incoming')

    elif Digits == '3':
        response.say("Please hold while I connect you to an agent.")
        response.dial(os.environ.get('SUPPORT_PHONE'))

    elif Digits == '0':
        response.redirect('/voice/menu')

    else:
        response.say("Invalid selection.")
        response.redirect('/voice/menu')

    return Response(content=str(response), media_type="application/xml")
```

## Conversations API Integration

Build multi-channel conversations:

```python
# conversations.py
from twilio.rest import Client
from gantz import MCPClient
import os

client = Client(
    os.environ['TWILIO_ACCOUNT_SID'],
    os.environ['TWILIO_AUTH_TOKEN']
)

mcp = MCPClient()


async def create_support_conversation(customer_phone: str, issue: str) -> dict:
    """Create a new support conversation."""
    # Create conversation
    conversation = client.conversations.v1.conversations.create(
        friendly_name=f"Support: {customer_phone}"
    )

    # Add customer as participant
    customer_participant = client.conversations.v1.conversations(
        conversation.sid
    ).participants.create(
        messaging_binding_address=customer_phone,
        messaging_binding_proxy_address=os.environ['TWILIO_PHONE_NUMBER']
    )

    # Add initial context message
    client.conversations.v1.conversations(
        conversation.sid
    ).messages.create(
        author='system',
        body=f"New support request: {issue}"
    )

    # Get AI-generated initial response
    result = mcp.execute_tool('ai_chat', {
        'prompt': issue,
        'context': 'Customer support ticket',
        'personality': 'helpful_support'
    })

    # Send AI response
    client.conversations.v1.conversations(
        conversation.sid
    ).messages.create(
        author='assistant',
        body=result.get('response', 'How can I help you today?')
    )

    return {
        'conversation_sid': conversation.sid,
        'customer_phone': customer_phone,
        'status': 'created'
    }


async def add_agent_to_conversation(conversation_sid: str, agent_identity: str):
    """Add human agent to conversation."""
    participant = client.conversations.v1.conversations(
        conversation_sid
    ).participants.create(
        identity=agent_identity
    )

    return {
        'participant_sid': participant.sid,
        'agent': agent_identity,
        'added': True
    }
```

## Webhook Configuration

Configure Twilio webhooks:

```python
# Configure in Twilio Console or via API
from twilio.rest import Client
import os

client = Client(
    os.environ['TWILIO_ACCOUNT_SID'],
    os.environ['TWILIO_AUTH_TOKEN']
)


def configure_webhooks(base_url: str):
    """Configure Twilio webhooks."""
    # Update phone number webhooks
    phone_number = client.incoming_phone_numbers.list(
        phone_number=os.environ['TWILIO_PHONE_NUMBER']
    )[0]

    phone_number.update(
        sms_url=f"{base_url}/sms",
        sms_method="POST",
        voice_url=f"{base_url}/voice/incoming",
        voice_method="POST",
        status_callback=f"{base_url}/sms/status",
        status_callback_method="POST"
    )

    print(f"Webhooks configured for {phone_number.phone_number}")
```

## Deploy with Gantz CLI

Deploy your Twilio agents:

```bash
# Install Gantz
npm install -g gantz

# Initialize Twilio project
gantz init --template twilio-bot

# Set environment variables
export TWILIO_ACCOUNT_SID=your-account-sid
export TWILIO_AUTH_TOKEN=your-auth-token
export TWILIO_PHONE_NUMBER=+15551234567

# Deploy
gantz deploy --platform railway

# Configure webhooks
python -c "from webhooks import configure_webhooks; configure_webhooks('https://your-app.railway.app')"
```

Build intelligent telephony agents at [gantz.run](https://gantz.run).

## Related Reading

- [WhatsApp MCP Integration](/post/whatsapp-mcp-integration/) - WhatsApp messaging
- [SendGrid MCP Integration](/post/sendgrid-mcp-integration/) - Email integration
- [MCP Streaming Patterns](/post/mcp-streaming-patterns/) - Real-time responses

## Conclusion

Twilio and MCP create powerful communication agents that handle SMS, voice, and multi-channel conversations with AI intelligence. Whether building support bots, IVR systems, or notification services, this combination scales to enterprise needs.

Start building communication AI agents with Gantz today.
