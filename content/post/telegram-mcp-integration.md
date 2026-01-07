+++
title = "Telegram MCP Integration: Build Intelligent Telegram Bots"
image = "images/telegram-mcp-integration.webp"
date = 2025-05-13
description = "Create AI-powered Telegram bots with MCP tools. Learn inline mode, keyboards, payments, and group management with Gantz."
draft = false
tags = ['telegram', 'bot', 'messaging', 'mcp', 'chat', 'gantz']
voice = false

[howto]
name = "How To Build AI Telegram Bots with MCP"
totalTime = 30
[[howto.steps]]
name = "Create Telegram bot"
text = "Register a new bot with BotFather and get your token"
[[howto.steps]]
name = "Define MCP tools"
text = "Create tool definitions for Telegram operations"
[[howto.steps]]
name = "Implement handlers"
text = "Build message, callback, and inline handlers"
[[howto.steps]]
name = "Add AI capabilities"
text = "Integrate AI-powered responses and automation"
[[howto.steps]]
name = "Deploy with Gantz"
text = "Deploy your Telegram bot using Gantz CLI"
+++

Telegram's bot platform offers rich features for building intelligent assistants. With MCP integration, you can create bots that understand context, process media, and provide smart responses to millions of users.

## Why Telegram MCP Integration?

Telegram bots with AI capabilities unlock powerful features:

- **Rich interactions**: Buttons, keyboards, inline queries
- **Media processing**: Images, documents, voice messages
- **Group management**: AI-powered moderation
- **Payments**: Integrated commerce
- **Webhooks**: Real-time message processing

## Telegram MCP Tool Definition

Configure Telegram tools in Gantz:

```yaml
# gantz.yaml
name: telegram-mcp-tools
version: 1.0.0

tools:
  send_message:
    description: "Send message to Telegram chat"
    parameters:
      chat_id:
        type: string
        required: true
      text:
        type: string
        required: true
      parse_mode:
        type: string
        default: "HTML"
      reply_markup:
        type: object
        description: "Keyboard or inline buttons"
    handler: telegram.send_message

  send_photo:
    description: "Send photo to chat"
    parameters:
      chat_id:
        type: string
        required: true
      photo:
        type: string
        description: "File ID or URL"
        required: true
      caption:
        type: string
    handler: telegram.send_photo

  answer_inline_query:
    description: "Answer inline query"
    parameters:
      inline_query_id:
        type: string
        required: true
      results:
        type: array
        required: true
    handler: telegram.answer_inline_query

  edit_message:
    description: "Edit existing message"
    parameters:
      chat_id:
        type: string
        required: true
      message_id:
        type: string
        required: true
      text:
        type: string
        required: true
    handler: telegram.edit_message

  get_chat_members:
    description: "Get members of a group chat"
    parameters:
      chat_id:
        type: string
        required: true
    handler: telegram.get_chat_members

  ban_user:
    description: "Ban user from group"
    parameters:
      chat_id:
        type: string
        required: true
      user_id:
        type: string
        required: true
      until_date:
        type: integer
        description: "Unix timestamp for ban end"
    handler: telegram.ban_user
```

## Handler Implementation

Build Telegram operation handlers:

```python
# handlers/telegram.py
import httpx
import os
from typing import Optional

TELEGRAM_API = f"https://api.telegram.org/bot{os.environ['TELEGRAM_TOKEN']}"


async def api_request(method: str, data: dict = None) -> dict:
    """Make Telegram Bot API request."""
    async with httpx.AsyncClient() as client:
        response = await client.post(
            f"{TELEGRAM_API}/{method}",
            json=data,
            timeout=30.0
        )

        result = response.json()

        if not result.get("ok"):
            return {"error": result.get("description", "Unknown error")}

        return result.get("result", result)


async def send_message(chat_id: str, text: str,
                       parse_mode: str = "HTML",
                       reply_markup: dict = None) -> dict:
    """Send message to Telegram chat."""
    try:
        data = {
            "chat_id": chat_id,
            "text": text,
            "parse_mode": parse_mode
        }

        if reply_markup:
            data["reply_markup"] = reply_markup

        result = await api_request("sendMessage", data)

        if "error" in result:
            return result

        return {
            "message_id": result.get("message_id"),
            "chat_id": chat_id,
            "sent": True
        }

    except Exception as e:
        return {"error": f"Failed to send message: {str(e)}"}


async def send_photo(chat_id: str, photo: str,
                     caption: str = None) -> dict:
    """Send photo to chat."""
    try:
        data = {
            "chat_id": chat_id,
            "photo": photo
        }

        if caption:
            data["caption"] = caption
            data["parse_mode"] = "HTML"

        result = await api_request("sendPhoto", data)

        if "error" in result:
            return result

        return {
            "message_id": result.get("message_id"),
            "chat_id": chat_id,
            "photo_sent": True
        }

    except Exception as e:
        return {"error": f"Failed to send photo: {str(e)}"}


async def answer_inline_query(inline_query_id: str,
                              results: list) -> dict:
    """Answer inline query."""
    try:
        result = await api_request("answerInlineQuery", {
            "inline_query_id": inline_query_id,
            "results": results,
            "cache_time": 300
        })

        if "error" in result:
            return result

        return {
            "inline_query_id": inline_query_id,
            "results_count": len(results),
            "answered": True
        }

    except Exception as e:
        return {"error": f"Failed to answer query: {str(e)}"}


async def edit_message(chat_id: str, message_id: str,
                       text: str) -> dict:
    """Edit existing message."""
    try:
        result = await api_request("editMessageText", {
            "chat_id": chat_id,
            "message_id": int(message_id),
            "text": text,
            "parse_mode": "HTML"
        })

        if "error" in result:
            return result

        return {
            "message_id": message_id,
            "edited": True
        }

    except Exception as e:
        return {"error": f"Failed to edit message: {str(e)}"}


async def get_chat_members(chat_id: str) -> dict:
    """Get members count for a group."""
    try:
        result = await api_request("getChatMemberCount", {
            "chat_id": chat_id
        })

        if "error" in result:
            return result

        return {
            "chat_id": chat_id,
            "member_count": result
        }

    except Exception as e:
        return {"error": f"Failed to get members: {str(e)}"}


async def ban_user(chat_id: str, user_id: str,
                   until_date: int = None) -> dict:
    """Ban user from group."""
    try:
        data = {
            "chat_id": chat_id,
            "user_id": int(user_id)
        }

        if until_date:
            data["until_date"] = until_date

        result = await api_request("banChatMember", data)

        if "error" in result:
            return result

        return {
            "chat_id": chat_id,
            "user_id": user_id,
            "banned": True
        }

    except Exception as e:
        return {"error": f"Failed to ban user: {str(e)}"}
```

## Telegram Bot Implementation

Create a full-featured bot with python-telegram-bot:

```python
# bot.py
from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import (
    Application, CommandHandler, MessageHandler,
    CallbackQueryHandler, InlineQueryHandler, filters
)
from gantz import MCPClient
import os

mcp = MCPClient(config_path='gantz.yaml')


async def start(update: Update, context):
    """Handle /start command."""
    keyboard = [
        [InlineKeyboardButton("🤖 Ask AI", callback_data="ask_ai")],
        [InlineKeyboardButton("📊 Analyze", callback_data="analyze")],
        [InlineKeyboardButton("🔍 Search", switch_inline_query_current_chat="")]
    ]
    reply_markup = InlineKeyboardMarkup(keyboard)

    await update.message.reply_text(
        "👋 <b>Welcome to the AI Assistant!</b>\n\n"
        "I can help you with:\n"
        "• Answer questions with AI\n"
        "• Analyze images and documents\n"
        "• Search and summarize content\n\n"
        "Try the buttons below or just send me a message!",
        parse_mode="HTML",
        reply_markup=reply_markup
    )


async def help_command(update: Update, context):
    """Handle /help command."""
    help_text = """
<b>Available Commands:</b>

/start - Start the bot
/help - Show this help
/ask [question] - Ask the AI
/summarize [text] - Summarize text
/translate [text] - Translate text
/image [prompt] - Generate image

<b>Features:</b>
• Send any message for AI response
• Send images for analysis
• Use inline mode: @botname query
"""
    await update.message.reply_text(help_text, parse_mode="HTML")


async def ask_command(update: Update, context):
    """Handle /ask command."""
    if not context.args:
        await update.message.reply_text("Please provide a question: /ask [your question]")
        return

    question = " ".join(context.args)
    await process_ai_query(update, question)


async def process_ai_query(update: Update, query: str):
    """Process AI query and send response."""
    # Send typing action
    await update.message.chat.send_action("typing")

    result = mcp.execute_tool('ai_chat', {
        'prompt': query,
        'context': f"Telegram user {update.effective_user.first_name}"
    })

    response = result.get('response', 'Sorry, I could not process your request.')

    # Add follow-up buttons
    keyboard = [
        [
            InlineKeyboardButton("🔄 Ask another", callback_data="ask_ai"),
            InlineKeyboardButton("📋 Copy", callback_data=f"copy:{response[:50]}")
        ]
    ]
    reply_markup = InlineKeyboardMarkup(keyboard)

    await update.message.reply_text(
        response,
        parse_mode="HTML",
        reply_markup=reply_markup
    )


async def message_handler(update: Update, context):
    """Handle regular messages."""
    text = update.message.text

    # Check for message type
    if update.message.photo:
        await handle_photo(update, context)
    elif update.message.document:
        await handle_document(update, context)
    elif update.message.voice:
        await handle_voice(update, context)
    else:
        await process_ai_query(update, text)


async def handle_photo(update: Update, context):
    """Handle photo messages with AI analysis."""
    await update.message.chat.send_action("typing")

    # Get largest photo
    photo = update.message.photo[-1]
    file = await photo.get_file()

    result = mcp.execute_tool('analyze_image', {
        'image_url': file.file_path,
        'analysis_type': 'detailed'
    })

    description = result.get('description', 'Could not analyze image.')

    await update.message.reply_text(
        f"📸 <b>Image Analysis:</b>\n\n{description}",
        parse_mode="HTML"
    )


async def handle_voice(update: Update, context):
    """Handle voice messages with transcription."""
    await update.message.chat.send_action("typing")

    voice = update.message.voice
    file = await voice.get_file()

    result = mcp.execute_tool('transcribe_audio', {
        'audio_url': file.file_path
    })

    transcription = result.get('text', 'Could not transcribe audio.')

    # Also generate AI response to transcription
    ai_response = mcp.execute_tool('ai_chat', {
        'prompt': transcription
    })

    await update.message.reply_text(
        f"🎤 <b>Transcription:</b>\n<i>{transcription}</i>\n\n"
        f"💬 <b>Response:</b>\n{ai_response.get('response', '')}",
        parse_mode="HTML"
    )


async def callback_handler(update: Update, context):
    """Handle callback queries from inline buttons."""
    query = update.callback_query
    await query.answer()

    if query.data == "ask_ai":
        await query.message.reply_text(
            "What would you like to know? Send me your question!"
        )

    elif query.data == "analyze":
        await query.message.reply_text(
            "Send me an image or document to analyze!"
        )

    elif query.data.startswith("copy:"):
        # Just acknowledge - actual copy happens client-side
        await query.answer("Copied to clipboard!", show_alert=True)


async def inline_handler(update: Update, context):
    """Handle inline queries."""
    query = update.inline_query.query

    if not query:
        return

    # Get AI suggestions
    result = mcp.execute_tool('ai_suggestions', {
        'query': query,
        'count': 5
    })

    suggestions = result.get('suggestions', [])

    results = []
    for i, suggestion in enumerate(suggestions):
        results.append(
            InlineQueryResultArticle(
                id=str(i),
                title=suggestion.get('title', query),
                description=suggestion.get('description', ''),
                input_message_content=InputTextMessageContent(
                    message_text=suggestion.get('text', query)
                )
            )
        )

    await update.inline_query.answer(results, cache_time=60)


async def summarize_command(update: Update, context):
    """Handle /summarize command."""
    if not context.args:
        await update.message.reply_text(
            "Please provide text to summarize: /summarize [text]"
        )
        return

    text = " ".join(context.args)

    await update.message.chat.send_action("typing")

    result = mcp.execute_tool('summarize', {
        'content': text,
        'max_length': 200
    })

    summary = result.get('summary', 'Could not summarize text.')

    await update.message.reply_text(
        f"📝 <b>Summary:</b>\n\n{summary}",
        parse_mode="HTML"
    )


async def translate_command(update: Update, context):
    """Handle /translate command."""
    if not context.args:
        await update.message.reply_text(
            "Usage: /translate [target_language] [text]\n"
            "Example: /translate es Hello world"
        )
        return

    target_lang = context.args[0]
    text = " ".join(context.args[1:])

    await update.message.chat.send_action("typing")

    result = mcp.execute_tool('translate', {
        'text': text,
        'target_language': target_lang
    })

    translation = result.get('translation', 'Could not translate.')

    await update.message.reply_text(
        f"🌐 <b>Translation ({target_lang}):</b>\n\n{translation}",
        parse_mode="HTML"
    )


def main():
    """Run the bot."""
    app = Application.builder().token(os.environ['TELEGRAM_TOKEN']).build()

    # Command handlers
    app.add_handler(CommandHandler("start", start))
    app.add_handler(CommandHandler("help", help_command))
    app.add_handler(CommandHandler("ask", ask_command))
    app.add_handler(CommandHandler("summarize", summarize_command))
    app.add_handler(CommandHandler("translate", translate_command))

    # Message handlers
    app.add_handler(MessageHandler(
        filters.TEXT & ~filters.COMMAND,
        message_handler
    ))
    app.add_handler(MessageHandler(filters.PHOTO, handle_photo))
    app.add_handler(MessageHandler(filters.VOICE, handle_voice))

    # Callback and inline handlers
    app.add_handler(CallbackQueryHandler(callback_handler))
    app.add_handler(InlineQueryHandler(inline_handler))

    # Run bot
    app.run_polling()


if __name__ == '__main__':
    main()
```

## Group Moderation

Implement AI-powered group moderation:

```python
# moderation.py
from telegram import Update
from telegram.ext import MessageHandler, filters
from gantz import MCPClient
import asyncio

mcp = MCPClient()


async def moderate_group_message(update: Update, context):
    """Moderate incoming group messages."""
    if update.message.chat.type not in ['group', 'supergroup']:
        return

    message = update.message
    text = message.text or message.caption or ''

    # Analyze message
    result = mcp.execute_tool('content_analysis', {
        'content': text,
        'checks': ['spam', 'toxicity', 'links', 'flooding']
    })

    if result.get('should_moderate'):
        action = result.get('action', 'warn')

        if action == 'delete':
            await message.delete()
            await message.chat.send_message(
                f"⚠️ @{message.from_user.username}, your message was removed.",
                message_thread_id=message.message_thread_id
            )

        elif action == 'warn':
            await message.reply_text(
                f"⚠️ Warning: {result.get('reason', 'Please follow community guidelines.')}"
            )

        elif action == 'ban':
            await message.chat.ban_member(message.from_user.id)
            await message.delete()


async def welcome_new_member(update: Update, context):
    """Welcome new members with AI-generated message."""
    for member in update.message.new_chat_members:
        if member.is_bot:
            continue

        # Generate personalized welcome
        result = mcp.execute_tool('generate_welcome', {
            'username': member.first_name,
            'chat_title': update.message.chat.title
        })

        await update.message.reply_text(
            result.get('message', f'Welcome {member.first_name}! 👋'),
            parse_mode="HTML"
        )
```

## Webhook Setup

Configure webhook for production:

```python
# webhook.py
from fastapi import FastAPI, Request
from telegram import Update, Bot
import os

app = FastAPI()
bot = Bot(token=os.environ['TELEGRAM_TOKEN'])


@app.post("/webhook")
async def webhook(request: Request):
    """Handle Telegram webhook."""
    data = await request.json()
    update = Update.de_json(data, bot)

    # Process update
    await process_update(update)

    return {"ok": True}


@app.on_event("startup")
async def setup_webhook():
    """Set up webhook on startup."""
    webhook_url = os.environ['WEBHOOK_URL']
    await bot.set_webhook(url=f"{webhook_url}/webhook")
```

## Deploy with Gantz CLI

Deploy your Telegram bot:

```bash
# Install Gantz
npm install -g gantz

# Initialize Telegram project
gantz init --template telegram-bot

# Set environment variables
export TELEGRAM_TOKEN=your-bot-token

# Deploy to cloud platform
gantz deploy --platform railway

# Or set webhook manually
gantz run set_webhook --url https://your-app.railway.app/webhook
```

Build intelligent Telegram bots at [gantz.run](https://gantz.run).

## Related Reading

- [Discord MCP Integration](/post/discord-mcp-integration/) - Compare with Discord bots
- [WhatsApp MCP Integration](/post/whatsapp-mcp-integration/) - WhatsApp integration
- [MCP Streaming Patterns](/post/mcp-streaming-patterns/) - Stream responses

## Conclusion

Telegram and MCP create a powerful platform for building intelligent bots. With rich interactions, media processing, and AI capabilities, you can build bots that serve millions of users with smart, context-aware responses.

Start building Telegram bots with Gantz today.
