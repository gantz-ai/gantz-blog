+++
title = 'I got tired of ngrok just to test MCP tools, so I built this'
date = 2025-12-06
draft = false
tags = ['agents', 'ai', 'mcp']
+++


If you've been playing with MCP (Model Context Protocol) to give Claude or other AI agents access to tools, you've probably hit this wall:

You write a cool tool that queries your local Postgres, runs a script, or hits an internal API. Works great locally. Then you want to actually use it with Claude... and now you need to figure out how to expose it.

ngrok? Sure, but it's another thing to set up. Port forwarding? Pain in the ass, especially if you're on a corporate network. Deploy to a server? Now you're maintaining infrastructure for a prototype.

I kept running into this so I built a CLI called **gantz** that just handles it.

## How it works

You define your tools in a YAML file:

```yaml
tools:
  - name: query_db
    description: Run a SQL query on my local database
    parameters:
      - name: query
        type: string
        required: true
    script:
      shell: psql -U postgres -d myapp -c "{{query}}"

  - name: list_files
    description: List files in a directory
    parameters:
      - name: path
        type: string
        default: "."
    script:
      shell: ls -la "{{path}}"
```

Then run:

```bash
gantz run
```

You get a URL like `https://happy-panda.gantz.run` and that's it. Point Claude at it and your local tools are accessible.

## What I actually use it for

- Letting Claude query my dev database without copying data anywhere
- Running local scripts that interact with files on my machine
- Testing MCP integrations before deploying anything
- Quick demos for clients without spinning up infrastructure

## The boring details

- It's free
- Requests go through a relay server (has to work somehow) but nothing is stored
- You can add auth tokens if you don't want your tunnel open to anyone
- Dashboard shows requests in real-time so you can see what's happening

## Connecting Claude to your tunnel

Once your tunnel is running, you can connect Claude using the Anthropic SDK:

```python
import anthropic

client = anthropic.Anthropic(api_key="your-api-key")

response = client.beta.messages.create(
    model="claude-sonnet-4-5-20250929",
    max_tokens=2000,
    messages=[{"role": "user", "content": "list all files in current directory"}],
    mcp_servers=[{
        "type": "url",
        "url": "https://happy-panda.gantz.run/sse",
        "name": "gantz",
        "authorization_token": "your-auth-token"  # if auth enabled
    }],
    tools=[{
        "type": "mcp_toolset",
        "mcp_server_name": "gantz"
    }],
    betas=["mcp-client-2025-11-20"]
)

for content in response.content:
    if hasattr(content, 'text'):
        print(content.text)
```

Claude will automatically discover your tools and use them to answer queries.

## Try it

```bash
curl -fsSL https://gantz.run/install.sh | bash
```

Or grab binaries from GitHub: https://github.com/gantz-ai/gantz-cli

Website: https://gantz.run

Still early and probably has bugs. Let me know what breaks or what features would actually be useful.

---

*What local tools would you want to expose to AI agents? Curious what use cases people have.*
