+++
title = "Discord MCP Integration: Build AI-Powered Discord Bots"
image = "images/discord-mcp-integration.webp"
date = 2025-05-11
description = "Create intelligent Discord bots with MCP tools. Learn slash commands, message handling, voice integration, and moderation automation with Gantz."
draft = false
tags = ['discord', 'bot', 'chat', 'mcp', 'community', 'gantz']
voice = false

[howto]
name = "How To Build AI Discord Bots with MCP"
totalTime = 30
[[howto.steps]]
name = "Set up Discord bot"
text = "Create a Discord application and bot in the Developer Portal"
[[howto.steps]]
name = "Define MCP tools"
text = "Create tool definitions for Discord operations"
[[howto.steps]]
name = "Implement handlers"
text = "Build message and slash command handlers"
[[howto.steps]]
name = "Add AI capabilities"
text = "Integrate AI-powered responses and moderation"
[[howto.steps]]
name = "Deploy with Gantz"
text = "Deploy your Discord bot using Gantz CLI"
+++

Discord is the go-to platform for communities, and MCP-powered bots can transform how you engage with members. This guide covers building intelligent Discord bots that respond to commands, moderate content, and provide AI-powered assistance.

## Why Discord MCP Integration?

AI-powered Discord bots enable powerful capabilities:

- **Smart responses**: Context-aware AI conversations
- **Auto-moderation**: AI-powered content filtering
- **Slash commands**: Execute MCP tools via Discord commands
- **Community management**: Automated member support
- **Analytics**: Track engagement and sentiment

## Discord MCP Tool Definition

Configure Discord tools in Gantz:

```yaml
# gantz.yaml
name: discord-mcp-tools
version: 1.0.0

tools:
  send_message:
    description: "Send message to Discord channel"
    parameters:
      channel_id:
        type: string
        required: true
      content:
        type: string
        required: true
      embed:
        type: object
        description: "Optional embed object"
    handler: discord.send_message

  reply_to_message:
    description: "Reply to a specific message"
    parameters:
      channel_id:
        type: string
        required: true
      message_id:
        type: string
        required: true
      content:
        type: string
        required: true
    handler: discord.reply_to_message

  create_thread:
    description: "Create a thread from a message"
    parameters:
      channel_id:
        type: string
        required: true
      message_id:
        type: string
        required: true
      name:
        type: string
        required: true
      auto_archive_duration:
        type: integer
        default: 1440
    handler: discord.create_thread

  get_channel_messages:
    description: "Get recent messages from channel"
    parameters:
      channel_id:
        type: string
        required: true
      limit:
        type: integer
        default: 50
    handler: discord.get_messages

  moderate_message:
    description: "Moderate message with AI analysis"
    parameters:
      message_id:
        type: string
        required: true
      channel_id:
        type: string
        required: true
      action:
        type: string
        description: "delete, warn, timeout"
    handler: discord.moderate_message

  assign_role:
    description: "Assign role to member"
    parameters:
      guild_id:
        type: string
        required: true
      user_id:
        type: string
        required: true
      role_id:
        type: string
        required: true
    handler: discord.assign_role
```

## Handler Implementation

Build Discord operation handlers:

```python
# handlers/discord.py
import discord
from discord import Intents
import asyncio
import os

# Discord client with necessary intents
intents = Intents.default()
intents.message_content = True
intents.members = True

client = discord.Client(intents=intents)
_ready = False


async def ensure_connected():
    """Ensure Discord client is connected."""
    global _ready
    if not _ready:
        asyncio.create_task(client.start(os.environ['DISCORD_TOKEN']))
        while not client.is_ready():
            await asyncio.sleep(0.1)
        _ready = True


async def send_message(channel_id: str, content: str,
                       embed: dict = None) -> dict:
    """Send message to Discord channel."""
    await ensure_connected()

    try:
        channel = client.get_channel(int(channel_id))
        if not channel:
            channel = await client.fetch_channel(int(channel_id))

        discord_embed = None
        if embed:
            discord_embed = discord.Embed(
                title=embed.get('title'),
                description=embed.get('description'),
                color=embed.get('color', 0x5865F2)
            )
            if embed.get('fields'):
                for field in embed['fields']:
                    discord_embed.add_field(
                        name=field['name'],
                        value=field['value'],
                        inline=field.get('inline', False)
                    )

        message = await channel.send(content=content, embed=discord_embed)

        return {
            'message_id': str(message.id),
            'channel_id': channel_id,
            'content': content,
            'sent': True
        }

    except discord.Forbidden:
        return {'error': 'Missing permissions to send message'}
    except Exception as e:
        return {'error': f'Failed to send message: {str(e)}'}


async def reply_to_message(channel_id: str, message_id: str,
                           content: str) -> dict:
    """Reply to a specific message."""
    await ensure_connected()

    try:
        channel = client.get_channel(int(channel_id))
        if not channel:
            channel = await client.fetch_channel(int(channel_id))

        message = await channel.fetch_message(int(message_id))
        reply = await message.reply(content)

        return {
            'message_id': str(reply.id),
            'reply_to': message_id,
            'content': content,
            'sent': True
        }

    except discord.NotFound:
        return {'error': 'Message not found'}
    except Exception as e:
        return {'error': f'Failed to reply: {str(e)}'}


async def create_thread(channel_id: str, message_id: str,
                        name: str, auto_archive_duration: int = 1440) -> dict:
    """Create a thread from a message."""
    await ensure_connected()

    try:
        channel = client.get_channel(int(channel_id))
        message = await channel.fetch_message(int(message_id))

        thread = await message.create_thread(
            name=name,
            auto_archive_duration=auto_archive_duration
        )

        return {
            'thread_id': str(thread.id),
            'name': name,
            'parent_channel': channel_id,
            'created': True
        }

    except Exception as e:
        return {'error': f'Failed to create thread: {str(e)}'}


async def get_messages(channel_id: str, limit: int = 50) -> dict:
    """Get recent messages from channel."""
    await ensure_connected()

    try:
        channel = client.get_channel(int(channel_id))
        if not channel:
            channel = await client.fetch_channel(int(channel_id))

        messages = []
        async for msg in channel.history(limit=limit):
            messages.append({
                'id': str(msg.id),
                'author': {
                    'id': str(msg.author.id),
                    'name': msg.author.name,
                    'bot': msg.author.bot
                },
                'content': msg.content,
                'timestamp': msg.created_at.isoformat(),
                'attachments': len(msg.attachments)
            })

        return {
            'channel_id': channel_id,
            'count': len(messages),
            'messages': messages
        }

    except Exception as e:
        return {'error': f'Failed to get messages: {str(e)}'}


async def moderate_message(message_id: str, channel_id: str,
                          action: str) -> dict:
    """Moderate message with specified action."""
    await ensure_connected()

    try:
        channel = client.get_channel(int(channel_id))
        message = await channel.fetch_message(int(message_id))

        if action == 'delete':
            await message.delete()
            return {
                'message_id': message_id,
                'action': 'deleted',
                'success': True
            }

        elif action == 'warn':
            await message.reply(
                "⚠️ Warning: This message may violate community guidelines."
            )
            return {
                'message_id': message_id,
                'action': 'warned',
                'success': True
            }

        elif action == 'timeout':
            # Timeout the member
            if message.guild:
                await message.author.timeout(
                    duration=datetime.timedelta(minutes=10),
                    reason="Automated moderation"
                )
            return {
                'message_id': message_id,
                'action': 'timeout',
                'user_id': str(message.author.id),
                'success': True
            }

        return {'error': f'Unknown action: {action}'}

    except Exception as e:
        return {'error': f'Moderation failed: {str(e)}'}


async def assign_role(guild_id: str, user_id: str, role_id: str) -> dict:
    """Assign role to member."""
    await ensure_connected()

    try:
        guild = client.get_guild(int(guild_id))
        if not guild:
            return {'error': 'Guild not found'}

        member = await guild.fetch_member(int(user_id))
        role = guild.get_role(int(role_id))

        if not role:
            return {'error': 'Role not found'}

        await member.add_roles(role)

        return {
            'user_id': user_id,
            'role_id': role_id,
            'role_name': role.name,
            'assigned': True
        }

    except Exception as e:
        return {'error': f'Failed to assign role: {str(e)}'}
```

## Discord Bot with Slash Commands

Create a full-featured bot:

```python
# bot.py
import discord
from discord import app_commands
from discord.ext import commands
from gantz import MCPClient
import os

intents = discord.Intents.default()
intents.message_content = True
intents.members = True

bot = commands.Bot(command_prefix='!', intents=intents)
mcp = MCPClient(config_path='gantz.yaml')


@bot.event
async def on_ready():
    print(f'{bot.user} has connected to Discord!')
    await bot.tree.sync()


@bot.tree.command(name="ask", description="Ask the AI assistant")
@app_commands.describe(question="Your question for the AI")
async def ask(interaction: discord.Interaction, question: str):
    """AI-powered question answering."""
    await interaction.response.defer(thinking=True)

    result = mcp.execute_tool('ai_chat', {
        'prompt': question,
        'context': f'Discord user {interaction.user.name} asked'
    })

    await interaction.followup.send(result.get('response', 'Sorry, I could not process your request.'))


@bot.tree.command(name="summarize", description="Summarize recent messages")
@app_commands.describe(count="Number of messages to summarize")
async def summarize(interaction: discord.Interaction, count: int = 20):
    """Summarize channel conversation."""
    await interaction.response.defer(thinking=True)

    messages = []
    async for msg in interaction.channel.history(limit=count):
        if not msg.author.bot:
            messages.append(f"{msg.author.name}: {msg.content}")

    conversation = "\n".join(reversed(messages))

    result = mcp.execute_tool('summarize', {
        'content': conversation,
        'max_length': 500
    })

    embed = discord.Embed(
        title=f"Summary of last {count} messages",
        description=result.get('summary', 'Could not generate summary'),
        color=0x5865F2
    )

    await interaction.followup.send(embed=embed)


@bot.tree.command(name="analyze", description="Analyze sentiment of recent messages")
async def analyze(interaction: discord.Interaction):
    """Analyze channel sentiment."""
    await interaction.response.defer(thinking=True)

    messages = []
    async for msg in interaction.channel.history(limit=50):
        if not msg.author.bot:
            messages.append(msg.content)

    result = mcp.execute_tool('sentiment_analysis', {
        'texts': messages
    })

    sentiment = result.get('overall_sentiment', 'neutral')
    emoji = {'positive': '😊', 'negative': '😔', 'neutral': '😐'}.get(sentiment, '🤔')

    embed = discord.Embed(
        title="Channel Sentiment Analysis",
        description=f"{emoji} Overall sentiment: **{sentiment}**",
        color=0x5865F2
    )
    embed.add_field(name="Messages Analyzed", value=str(len(messages)))
    embed.add_field(name="Positive", value=f"{result.get('positive_pct', 0)}%")
    embed.add_field(name="Negative", value=f"{result.get('negative_pct', 0)}%")

    await interaction.followup.send(embed=embed)


@bot.tree.command(name="help-ticket", description="Create a support ticket")
@app_commands.describe(issue="Describe your issue")
async def help_ticket(interaction: discord.Interaction, issue: str):
    """Create AI-triaged support ticket."""
    await interaction.response.defer(ephemeral=True)

    # AI categorization
    result = mcp.execute_tool('categorize_issue', {
        'description': issue,
        'categories': ['technical', 'billing', 'feature_request', 'bug', 'general']
    })

    category = result.get('category', 'general')
    priority = result.get('priority', 'normal')

    # Create support thread
    thread = await interaction.channel.create_thread(
        name=f"🎫 {category}: {issue[:30]}...",
        auto_archive_duration=1440
    )

    embed = discord.Embed(
        title="Support Ticket Created",
        description=issue,
        color=0xFF6B6B if priority == 'high' else 0x5865F2
    )
    embed.add_field(name="Category", value=category)
    embed.add_field(name="Priority", value=priority)
    embed.add_field(name="User", value=interaction.user.mention)

    await thread.send(embed=embed)
    await interaction.followup.send(
        f"Your ticket has been created: {thread.mention}",
        ephemeral=True
    )


@bot.event
async def on_message(message):
    """AI-powered auto-moderation."""
    if message.author.bot:
        return

    # Check message with AI moderation
    result = mcp.execute_tool('moderate_content', {
        'content': message.content,
        'check_spam': True,
        'check_toxicity': True,
        'check_links': True
    })

    if result.get('should_moderate'):
        reason = result.get('reason', 'Policy violation')

        if result.get('action') == 'delete':
            await message.delete()
            await message.channel.send(
                f"⚠️ {message.author.mention}, your message was removed: {reason}",
                delete_after=10
            )
        elif result.get('action') == 'warn':
            await message.reply(f"⚠️ Warning: {reason}")

    await bot.process_commands(message)


# Run bot
if __name__ == '__main__':
    bot.run(os.environ['DISCORD_TOKEN'])
```

## AI Moderation System

Implement intelligent content moderation:

```python
# moderation.py
from gantz import MCPClient

mcp = MCPClient()


def analyze_message(content: str, author_history: list = None) -> dict:
    """Analyze message for moderation."""
    result = mcp.execute_tool('content_analysis', {
        'content': content,
        'checks': [
            'toxicity',
            'spam',
            'self_promotion',
            'nsfw',
            'personal_info'
        ]
    })

    # Consider author history for repeat offenders
    if author_history:
        past_violations = sum(1 for h in author_history if h.get('violated'))
        if past_violations > 3:
            result['severity'] = 'high'

    return {
        'should_moderate': result.get('score', 0) > 0.7,
        'action': determine_action(result),
        'reason': result.get('primary_issue'),
        'confidence': result.get('confidence'),
        'details': result
    }


def determine_action(analysis: dict) -> str:
    """Determine moderation action based on analysis."""
    score = analysis.get('score', 0)
    issue = analysis.get('primary_issue', '')

    if score > 0.9 or issue in ['nsfw', 'personal_info']:
        return 'delete'
    elif score > 0.7:
        return 'warn'
    elif score > 0.5:
        return 'flag'

    return 'none'


def generate_warning(reason: str, severity: str) -> str:
    """Generate contextual warning message."""
    result = mcp.execute_tool('generate_warning', {
        'reason': reason,
        'severity': severity,
        'tone': 'friendly_but_firm'
    })

    return result.get('message', f'Please review our community guidelines. Reason: {reason}')
```

## Embed Templates

Create rich embeds for responses:

```python
# embeds.py
import discord
from datetime import datetime


def create_help_embed(tools: list) -> discord.Embed:
    """Create help embed listing available commands."""
    embed = discord.Embed(
        title="🤖 AI Assistant Commands",
        description="Here's what I can do for you:",
        color=0x5865F2
    )

    for tool in tools:
        embed.add_field(
            name=f"/{tool['name']}",
            value=tool['description'],
            inline=False
        )

    embed.set_footer(text="Powered by Gantz MCP")
    embed.timestamp = datetime.now()

    return embed


def create_analysis_embed(analysis: dict) -> discord.Embed:
    """Create analysis result embed."""
    sentiment = analysis.get('sentiment', 'neutral')
    colors = {
        'positive': 0x00FF00,
        'negative': 0xFF0000,
        'neutral': 0x808080
    }

    embed = discord.Embed(
        title="📊 Message Analysis",
        color=colors.get(sentiment, 0x5865F2)
    )

    embed.add_field(name="Sentiment", value=sentiment.title())
    embed.add_field(name="Confidence", value=f"{analysis.get('confidence', 0):.0%}")

    if analysis.get('topics'):
        embed.add_field(
            name="Topics",
            value=", ".join(analysis['topics']),
            inline=False
        )

    return embed


def create_error_embed(error: str) -> discord.Embed:
    """Create error message embed."""
    return discord.Embed(
        title="❌ Error",
        description=error,
        color=0xFF0000
    )
```

## Deploy with Gantz CLI

Deploy your Discord bot:

```bash
# Install Gantz
npm install -g gantz

# Initialize Discord project
gantz init --template discord-bot

# Set environment variables
export DISCORD_TOKEN=your-bot-token

# Deploy to cloud platform
gantz deploy --platform railway

# Or run locally
gantz run bot.py
```

Build intelligent Discord bots at [gantz.run](https://gantz.run).

## Related Reading

- [Telegram MCP Integration](/post/telegram-mcp-integration/) - Compare with Telegram bots
- [MCP Streaming Patterns](/post/mcp-streaming-patterns/) - Stream responses
- [MCP Connection Pooling](/post/mcp-connection-pooling/) - Handle rate limits

## Conclusion

Discord and MCP create a powerful combination for building intelligent community bots. With slash commands, AI moderation, and smart responses, you can build engaging experiences that scale with your community.

Start building AI-powered Discord bots with Gantz today.
