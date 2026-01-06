+++
title = 'MCP vs Function Calling — What's the difference?'
date = 2025-12-12
draft = false
tags = ['agents', 'ai', 'mcp']
+++


If you've been building with AI, you've probably seen both "function calling" and "MCP" thrown around. They sound similar — both let AI models use tools. But they're actually solving different problems.

Let me break it down.

## Function Calling (the old way)

Function calling has been around for a while. You define functions in your API request, and the model decides when to call them.

```python
response = client.messages.create(
    model="claude-sonnet-4-5-20250929",
    messages=[{"role": "user", "content": "What's the weather in Tokyo?"}],
    tools=[{
        "name": "get_weather",
        "description": "Get current weather for a city",
        "input_schema": {
            "type": "object",
            "properties": {
                "city": {"type": "string"}
            },
            "required": ["city"]
        }
    }]
)
```

The model returns a tool call, you execute it yourself, send the result back, and the model continues.

**The flow:**
1. You define tools in code
2. Model decides to call a tool
3. Model returns tool call params
4. **You** execute the tool
5. You send result back
6. Model responds

The key thing: **you're responsible for executing the tool**. The model just tells you what it wants to call.

## MCP (Model Context Protocol)

MCP flips this around. Instead of defining tools in your code, tools live on a **server**. The AI connects to that server directly.

```python
response = client.beta.messages.create(
    model="claude-sonnet-4-5-20250929",
    messages=[{"role": "user", "content": "What's the weather in Tokyo?"}],
    mcp_servers=[{
        "type": "url",
        "url": "https://weather-tools.example.com/sse",
        "name": "weather"
    }],
    tools=[{"type": "mcp_toolset", "mcp_server_name": "weather"}]
)
```

**The flow:**
1. Tools live on an MCP server
2. AI connects to the server
3. AI discovers available tools automatically
4. AI calls tools directly
5. Server executes and returns results
6. AI responds

The key thing: **the server executes the tool**, not your code.

## Why does this matter?

### Function calling is good when:
- Tools are simple and few
- You want full control over execution
- Tools need access to your app's state
- You're building a single application

### MCP is good when:
- Tools are complex or numerous
- You want to share tools across multiple apps
- Tools need to run in a specific environment (your laptop, a VPC, etc.)
- You want AI to discover tools dynamically

## The real difference

Think of it this way:

**Function calling** = "Hey AI, here are the tools you can use. Tell me what you want to call and I'll do it."

**MCP** = "Hey AI, connect to this server. It has tools. Figure out what's available and use them."

Function calling is like giving someone a menu and taking their order. MCP is like letting them walk into the kitchen.

## When I use each

**Function calling:**
- Simple chatbots with 2-3 tools
- When tools need database access from my app
- Prototyping quickly

**MCP:**
- Giving Claude access to my local machine
- Running tools that need specific environments
- Sharing toolsets across different AI apps
- When I don't want to redeploy my app to add tools

## Practical example

Let's say you want Claude to query your local Postgres database.

**With function calling:**
1. Build an app that connects to Postgres
2. Define a `query_db` function
3. Handle tool calls, execute queries, return results
4. Deploy and maintain the app

**With MCP:**
1. Write a YAML config with your query tool
2. Run an MCP server locally
3. Point Claude at it
4. Done

```yaml
tools:
  - name: query_db
    description: Run a SQL query
    parameters:
      - name: query
        type: string
        required: true
    script:
      shell: psql -U postgres -d myapp -c "{{query}}"
```

No app to deploy. No code to maintain. Just a config file and a running server.

## The catch with MCP

MCP servers need to be accessible. If it's running on your laptop, Claude can't reach it unless you expose it somehow.

That's actually why I built [Gantz](https://gantz.run) — it creates a tunnel so your local MCP server gets a public URL. No port forwarding, no ngrok setup.

## TL;DR

| | Function Calling | MCP |
|---|---|---|
| Tools defined in | Your code | MCP server |
| Tool execution | Your app | MCP server |
| Discovery | Static (you define) | Dynamic (server provides) |
| Best for | Simple, integrated tools | Complex, shareable, remote tools |

Both have their place. Function calling isn't going away. But MCP makes certain things way easier — especially when you want AI to use tools that live somewhere specific.

---

*Building with MCP? I'd love to hear what tools you're exposing to AI agents.*
