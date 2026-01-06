+++
title = "Build a Slack bot that uses your local tools"
date = 2025-11-25
image = "/images/robot-billboard-07.png"
draft = false
tags = ['agents', 'ai', 'mcp']
+++


I wanted a Slack bot that could run scripts on my machine. Not some cloud function — actual local tools. Query my dev database, check server logs, run deployment scripts.

Turns out it's pretty easy with MCP. Here's how I did it.

## The idea

```
Slack message → Bot → Claude → MCP Server (your laptop) → Run tool → Response
```

You ask the bot something in Slack, Claude figures out what tool to use, calls your local MCP server, and returns the result.

## What you'll need

- A Slack workspace (and permission to add apps)
- Anthropic API key
- Node.js or Python for the bot
- [Gantz CLI](https://gantz.run) (to expose local tools)

## Step 1: Set up your local tools

First, create a `gantz.yaml` with the tools you want your bot to use:

```yaml
name: slack-tools
description: Tools for my Slack bot

tools:
  - name: check_server
    description: Check if a server is responding
    parameters:
      - name: url
        type: string
        required: true
    script:
      shell: curl -s -o /dev/null -w "%{http_code}" "{{url}}"

  - name: disk_usage
    description: Check disk usage on local machine
    parameters: []
    script:
      shell: df -h | head -5

  - name: recent_logs
    description: Get recent application logs
    parameters:
      - name: lines
        type: integer
        default: 20
    script:
      shell: tail -n {{lines}} /var/log/app.log

  - name: deploy_status
    description: Check current deployment status
    parameters: []
    script:
      shell: git log -1 --format="%h %s (%cr)" && echo "Branch:" && git branch --show-current
```

Run your MCP server:

```bash
gantz run --auth
```

You'll get something like:
```
Tunnel URL: https://cool-penguin.gantz.run
Auth Token: gtz_abc123...
```

Save that auth token — you'll need it.

## Step 2: Create a Slack app

1. Go to [api.slack.com/apps](https://api.slack.com/apps)
2. Create New App → From scratch
3. Name it something like "DevBot"
4. Add these Bot Token Scopes under OAuth & Permissions:
   - `app_mentions:read`
   - `chat:write`
   - `channels:history`
5. Install to workspace
6. Copy the Bot User OAuth Token (`xoxb-...`)

## Step 3: Enable Socket Mode

Under Socket Mode:
1. Enable Socket Mode
2. Generate an App-Level Token with `connections:write` scope
3. Copy the token (`xapp-...`)

Under Event Subscriptions:
1. Enable Events
2. Subscribe to `app_mention` bot event

## Step 4: Build the bot

Here's a simple Python bot:

```python
import os
import anthropic
from slack_bolt import App
from slack_bolt.adapter.socket_mode import SocketModeHandler

# Config
SLACK_BOT_TOKEN = "xoxb-your-token"
SLACK_APP_TOKEN = "xapp-your-token"
ANTHROPIC_API_KEY = "sk-ant-..."
MCP_URL = "https://cool-penguin.gantz.run"
MCP_AUTH_TOKEN = "gtz_abc123..."

app = App(token=SLACK_BOT_TOKEN)
claude = anthropic.Anthropic(api_key=ANTHROPIC_API_KEY)

@app.event("app_mention")
def handle_mention(event, say):
    user_message = event["text"]

    # Remove the bot mention from the message
    user_message = user_message.split(">", 1)[-1].strip()

    try:
        response = claude.beta.messages.create(
            model="claude-sonnet-4-5-20250929",
            max_tokens=1024,
            system="You're a DevOps assistant. Use the available tools to help with server and deployment tasks. Be concise.",
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

        # Extract text response
        result = ""
        for block in response.content:
            if hasattr(block, "text"):
                result += block.text

        say(result or "Done, but no text response.")

    except Exception as e:
        say(f"Error: {str(e)}")

if __name__ == "__main__":
    handler = SocketModeHandler(app, SLACK_APP_TOKEN)
    handler.start()
```

Install dependencies:

```bash
pip install slack-bolt anthropic
```

Run it:

```bash
python bot.py
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

The cool part: your tools run locally. You can access files, databases, scripts — anything on your machine.

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

## Security notes

- Use `--auth` flag so only your bot can access tools
- Be careful with destructive commands
- Consider read-only tools for Slack (no `rm -rf` please)
- Keep your auth token secret

## Wrap up

Total setup time: maybe 30 minutes. And now you have a Slack bot that can run tools on your local machine.

The MCP server stays on your laptop. Slack and Claude are in the cloud. The tunnel connects them.

No deploying code. No cloud functions. Just local scripts exposed through Slack.

---

*What tools would you add to your Slack bot? I'm curious what people would find useful.*
