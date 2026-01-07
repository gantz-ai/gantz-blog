+++
title = "Build a Slack bot that uses your local tools"
date = 2025-11-25
description = "Create a Slack bot connected to local MCP tools. Run scripts, query databases, and execute commands from Slack using Claude and Gantz."
image = "images/robot-billboard-07.webp"
draft = false
tags = ['tutorial', 'mcp', 'automation']
voice = false

[howto]
name = "Build a Slack Bot with MCP Tools"
totalTime = 30
[[howto.steps]]
name = "Set up local tools"
text = "Create a gantz.yaml file defining the tools your Slack bot can use."
[[howto.steps]]
name = "Create a Slack app"
text = "Go to api.slack.com, create a new app, and configure bot permissions."
[[howto.steps]]
name = "Write the bot code"
text = "Create a Python script that listens for Slack messages and calls Claude with MCP."
[[howto.steps]]
name = "Start the MCP server"
text = "Run gantz run --auth to start your local MCP server with a secure tunnel."
[[howto.steps]]
name = "Connect and test"
text = "Add the bot to a Slack channel and test commands to verify the integration."
+++


I wanted a Slack bot that could run scripts on my machine. Not some cloud function - actual local tools. Query my dev database, check server logs, run deployment scripts.

The problem with typical Slack bots: they run in the cloud. You need to deploy code, set up infrastructure, handle secrets. For quick internal tools, that's massive overhead.

What I wanted: ask a question in Slack, have it execute something on my laptop, get the answer back. No deployment. No cloud functions. Just my local machine doing the work.

Turns out it's pretty easy with MCP. Here's how I built it.

## The architecture

```
┌─────────┐     ┌─────────┐     ┌─────────┐     ┌─────────────┐     ┌──────────┐
│  Slack  │────▶│   Bot   │────▶│  Claude │────▶│ MCP Server  │────▶│  Local   │
│  User   │◀────│ (Python)│◀────│   API   │◀────│  (Gantz)    │◀────│  Tools   │
└─────────┘     └─────────┘     └─────────┘     └─────────────┘     └──────────┘
                     │                               │
               Your Server                     Your Laptop
               or Computer                    (via tunnel)
```

You ask the bot something in Slack, the bot sends it to Claude with your MCP server config, Claude discovers your tools and decides which one to use, your local machine executes it, and the result flows back through the chain.

The MCP server stays on your laptop. The tunnel (via Gantz) makes it accessible to Claude. No need to deploy your tools anywhere.

## What you'll need

- A Slack workspace where you can add apps (admin permissions or approval needed)
- Anthropic API key (get one at [console.anthropic.com](https://console.anthropic.com))
- Python 3.8+ for the bot code
- [Gantz CLI](https://gantz.run) installed to expose your local tools
- About 30 minutes of setup time

**Cost note:** The Anthropic API charges per token. For a Slack bot handling a few dozen queries per day, expect costs under $5/month. Heavy usage will cost more.

## Step 1: Set up your local tools

First, create a `gantz.yaml` file in your project directory. This defines what tools your bot can use.

Think about what you actually want your Slack bot to do. For a DevOps bot, you probably want:
- Health checks for servers and services
- Log viewing and searching
- Deployment status and git info
- Resource monitoring (disk, memory, CPU)
- Maybe some database queries

Here's a practical starting config:

```yaml
name: slack-tools
description: Tools for my Slack bot
version: "1.0.0"

tools:
  - name: check_server
    description: Check if a server/URL is responding. Returns HTTP status code. Use this when someone asks if a service is up or working.
    parameters:
      - name: url
        type: string
        description: The URL to check (include https://)
        required: true
    script:
      shell: curl -s -o /dev/null -w "%{http_code}" "{{url}}"
      timeout: 10s

  - name: disk_usage
    description: Check disk usage on the local machine. Shows available space on all mounted drives. Use when someone asks about storage or disk space.
    parameters: []
    script:
      shell: df -h | head -10

  - name: memory_usage
    description: Check memory and swap usage. Use when someone asks about RAM or memory.
    parameters: []
    script:
      shell: free -h

  - name: recent_logs
    description: Get recent application logs. Use when someone asks to see logs or check for errors.
    parameters:
      - name: lines
        type: integer
        description: Number of lines to return (default 20, max 100)
        default: 20
      - name: filter
        type: string
        description: Optional grep pattern to filter logs
    script:
      shell: tail -n {{lines}} /var/log/app.log {{ if filter }}| grep -i "{{filter}}"{{ end }}
      timeout: 30s

  - name: deploy_status
    description: Check current deployment status including last commit and current branch. Use when someone asks about what's deployed or the current version.
    parameters: []
    script:
      shell: |
        echo "=== Current Deploy ==="
        git log -1 --format="Commit: %h%nAuthor: %an%nDate: %cr%nMessage: %s"
        echo ""
        echo "Branch: $(git branch --show-current)"
        echo "Status: $(git status --short | wc -l) uncommitted changes"
      working_dir: /path/to/your/project

  - name: running_processes
    description: Show top processes by CPU or memory. Use when someone asks what's consuming resources.
    parameters:
      - name: sort_by
        type: string
        description: Sort by 'cpu' or 'mem'
        default: cpu
    script:
      shell: ps aux --sort=-{{ if sort_by }}%{{sort_by}}{{ else }}%cpu{{ end }} | head -10
```

**Important:** The `description` field is how Claude decides when to use each tool. Write descriptions that explain both what the tool does AND when to use it.

Run your MCP server with authentication enabled:

```bash
gantz run --auth
```

You'll see output like:
```
Gantz Run v0.1.0
Loaded 6 tools from gantz.yaml

Connecting to relay server...

  MCP Server URL: https://cool-penguin.gantz.run
  Auth Token: gtz_abc123...

  Add to your MCP client config to connect.

Press Ctrl+C to stop
```

**Save both values** - you'll need the URL and auth token for the bot code. Keep the auth token secret; anyone with it can call your tools.

## Step 2: Create a Slack app

This part is a bit tedious but only needs to be done once.

1. Go to [api.slack.com/apps](https://api.slack.com/apps)
2. Click **Create New App** → **From scratch**
3. Name it something descriptive like "DevBot" or "OpsAssistant"
4. Select your workspace

### Configure permissions

Navigate to **OAuth & Permissions** in the left sidebar. Under **Scopes**, add these Bot Token Scopes:

| Scope | Purpose |
|-------|---------|
| `app_mentions:read` | Lets the bot see when someone @mentions it |
| `chat:write` | Lets the bot send messages |
| `channels:history` | Lets the bot read channel messages (for context) |
| `channels:read` | Lets the bot see channel info |

5. Scroll up and click **Install to Workspace**
6. Authorize the app
7. Copy the **Bot User OAuth Token** (starts with `xoxb-...`) - you'll need this

## Step 3: Enable Socket Mode

Socket Mode lets your bot receive events without setting up a public URL. Perfect for local development and simple deployments.

Navigate to **Socket Mode** in the left sidebar:
1. Toggle **Enable Socket Mode** to ON
2. You'll be prompted to create an App-Level Token
3. Name it something like "socket-token"
4. Add the `connections:write` scope
5. Click **Generate**
6. Copy this token (starts with `xapp-...`) - you'll need this too

### Subscribe to events

Navigate to **Event Subscriptions**:
1. Toggle **Enable Events** to ON
2. Under **Subscribe to bot events**, click **Add Bot User Event**
3. Add `app_mention` - this triggers when someone @mentions your bot
4. Click **Save Changes**

You might need to reinstall the app after changing event subscriptions. Slack will prompt you if needed.

## Step 4: Build the bot

Now for the actual bot code. Create a file called `bot.py`:

```python
import os
import anthropic
from slack_bolt import App
from slack_bolt.adapter.socket_mode import SocketModeHandler

# Configuration - use environment variables in production!
SLACK_BOT_TOKEN = os.environ.get("SLACK_BOT_TOKEN", "xoxb-your-token")
SLACK_APP_TOKEN = os.environ.get("SLACK_APP_TOKEN", "xapp-your-token")
ANTHROPIC_API_KEY = os.environ.get("ANTHROPIC_API_KEY", "sk-ant-...")
MCP_URL = os.environ.get("MCP_URL", "https://cool-penguin.gantz.run")
MCP_AUTH_TOKEN = os.environ.get("MCP_AUTH_TOKEN", "gtz_abc123...")

# Initialize Slack app and Claude client
app = App(token=SLACK_BOT_TOKEN)
claude = anthropic.Anthropic(api_key=ANTHROPIC_API_KEY)

# System prompt defines how the bot behaves
SYSTEM_PROMPT = """You're a DevOps assistant for the team. Use the available tools to help with:
- Server health checks
- Log viewing and analysis
- Deployment status
- Resource monitoring

Be concise in your responses. Format output for Slack readability.
If a tool fails, explain what went wrong and suggest alternatives.
Never expose sensitive data like passwords or API keys in responses."""


@app.event("app_mention")
def handle_mention(event, say):
    """Handle @mentions of the bot"""
    user_message = event["text"]
    channel = event["channel"]

    # Remove the bot mention from the message (e.g., "<@U123ABC> check server")
    # becomes "check server"
    user_message = user_message.split(">", 1)[-1].strip()

    if not user_message:
        say("How can I help? Try asking me to check a server, view logs, or show deployment status.")
        return

    try:
        # Call Claude with MCP tools enabled
        response = claude.beta.messages.create(
            model="claude-sonnet-4-5-20250929",
            max_tokens=1024,
            system=SYSTEM_PROMPT,
            messages=[{"role": "user", "content": user_message}],
            mcp_servers=[{
                "type": "url",
                "url": f"{MCP_URL}/sse",
                "name": "local-tools",
                "authorization_token": MCP_AUTH_TOKEN
            }],
            tools=[{"type": "mcp_toolset", "mcp_server_name": "local-tools"}],
            betas=["mcp-client-2025-11-20"]
        )

        # Extract the text response from Claude
        result = ""
        for block in response.content:
            if hasattr(block, "text"):
                result += block.text

        # Send response back to Slack
        if result:
            say(result)
        else:
            say("Task completed, but there's nothing to report.")

    except anthropic.APIConnectionError:
        say("⚠️ Couldn't connect to Claude API. Is your API key valid?")
    except anthropic.RateLimitError:
        say("⚠️ Rate limited by Claude API. Try again in a moment.")
    except Exception as e:
        # Log the full error for debugging
        print(f"Error handling mention: {e}")
        say(f"⚠️ Something went wrong: {str(e)[:200]}")


@app.event("message")
def handle_message(event, say):
    """Handle direct messages to the bot"""
    # Only respond to DMs, not channel messages
    if event.get("channel_type") == "im":
        handle_mention(event, say)


if __name__ == "__main__":
    print("Starting Slack bot...")
    print(f"MCP URL: {MCP_URL}")
    handler = SocketModeHandler(app, SLACK_APP_TOKEN)
    handler.start()
```

### Install dependencies

Create a `requirements.txt`:

```
slack-bolt>=1.18.0
anthropic>=0.18.0
```

Install them:

```bash
pip install -r requirements.txt
```

### Run the bot

For development, you can set variables directly:

```bash
export SLACK_BOT_TOKEN="xoxb-..."
export SLACK_APP_TOKEN="xapp-..."
export ANTHROPIC_API_KEY="sk-ant-..."
export MCP_URL="https://cool-penguin.gantz.run"
export MCP_AUTH_TOKEN="gtz_..."

python bot.py
```

You should see:
```
Starting Slack bot...
MCP URL: https://cool-penguin.gantz.run
⚡️ Bolt app is running!
```

## Step 5: Use it

In Slack, mention your bot:

```
@DevBot check if google.com is up
```

```
@DevBot how much disk space do we have?
```

```
@DevBot show me the last 10 log lines
```

```
@DevBot what's the current deploy status?
```

Claude will pick the right tool and execute it on your machine.

## What's actually happening

1. Slack sends the message to your bot
2. Bot sends it to Claude with your MCP server config
3. Claude connects to your local MCP server (via the Gantz tunnel)
4. Claude discovers available tools
5. Claude decides which tool to call
6. Your laptop runs the command
7. Result goes back through Claude → Bot → Slack

The cool part: your tools run locally. You can access files, databases, scripts - anything on your machine.

## Making it useful

Some ideas for tools:

**DevOps:**
- Check service health
- View recent deploys
- Restart services
- Check error rates

**Database:**
- Run read-only queries
- Check table sizes
- Find recent records

**Monitoring:**
- Disk/memory/CPU usage
- Log searches
- Process lists

**Git:**
- Recent commits
- Branch status
- Pending PRs

## Troubleshooting

### Bot doesn't respond

1. **Check Socket Mode is enabled** - Go to your Slack app settings and verify Socket Mode is ON
2. **Verify the bot is in the channel** - Invite the bot with `/invite @BotName`
3. **Check the console** - Look for error messages when the bot starts
4. **Test the MCP server** - Make sure `gantz run` is running and the tunnel is active

### "invalid_auth" error

Your Slack tokens are wrong. Double-check:
- Bot token starts with `xoxb-`
- App token starts with `xapp-`
- Both are from the correct app

### MCP tools aren't being called

1. Check the MCP URL is correct (including the `/sse` path)
2. Verify the auth token matches what Gantz displayed
3. Look at the Gantz terminal - you should see incoming requests

### Claude returns errors

- Check your Anthropic API key is valid
- Verify you have API credits remaining
- Make sure you're using the beta flag for MCP support

## Security considerations

This setup gives your Slack channel access to local tools. Think carefully about what that means.

### What to do

- **Use `--auth` flag** - Always run Gantz with authentication so only your bot can call tools
- **Read-only by default** - Start with tools that only read data, not modify it
- **Limit scope** - Only expose tools your team actually needs
- **Keep tokens secret** - Don't commit tokens to git or share them in Slack
- **Monitor usage** - Watch the Gantz terminal to see what's being called

### What NOT to do

- Don't expose `rm`, `drop table`, or other destructive commands
- Don't give the bot access to production databases with write permissions
- Don't run the bot on a machine with sensitive data unless necessary
- Don't share your MCP auth token publicly

### For production use

If you're running this for a real team:
- Store secrets in a proper secret manager, not environment variables
- Add rate limiting to prevent abuse
- Log all tool calls for audit trails
- Consider running the bot code on a server (the MCP server can still be local)

## Running in production

For a persistent setup:

### Using systemd (Linux)

Create `/etc/systemd/system/slack-bot.service`:

```ini
[Unit]
Description=Slack DevOps Bot
After=network.target

[Service]
Type=simple
User=youruser
WorkingDirectory=/path/to/bot
EnvironmentFile=/path/to/bot/.env
ExecStart=/usr/bin/python3 bot.py
Restart=always

[Install]
WantedBy=multi-user.target
```

Enable and start:

```bash
sudo systemctl enable slack-bot
sudo systemctl start slack-bot
```

### Using Docker

```dockerfile
FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY bot.py .
CMD ["python", "bot.py"]
```

Build and run:

```bash
docker build -t slack-bot .
docker run -d --env-file .env slack-bot
```

## Wrap up

Total setup time: about 30 minutes. And now you have a Slack bot that can run tools on your local machine.

The architecture:
- MCP server stays on your laptop (via Gantz)
- Bot code can run anywhere (local, server, container)
- Slack and Claude are in the cloud
- The tunnel connects them securely

No deploying your actual tools. No cloud functions with limited capabilities. Just your local scripts, accessible from Slack, powered by Claude's reasoning.

## Related reading

- [Let AI Agents Read and Respond to Your Emails](/post/ai-email-assistant/) - Similar automation tutorial
- [Control Your Smart Home with Claude and MCP](/post/claude-smart-home/) - Another local automation example
- [Your First AI Agent in 15 Minutes](/post/first-agent/) - Getting started with agents

---

*What tools would you add to your Slack bot? I'm curious what people would find useful.*
