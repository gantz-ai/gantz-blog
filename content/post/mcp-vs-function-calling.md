+++
title = "MCP vs Function Calling - What's the difference?"
date = 2025-12-12
description = "MCP vs Function Calling explained. MCP servers execute tools remotely, function calling returns tool calls for your code to handle. When to use each approach."
image = "images/warrior-rain-city-03.webp"
draft = false
featured = true
tags = ['mcp', 'tool-use', 'comparison']
voice = true

[[faqs]]
question = "What is the difference between MCP and function calling?"
answer = "Function calling returns tool calls for your code to execute, while MCP connects AI to a server that executes tools directly. With function calling, you handle execution; with MCP, the server handles it."

[[faqs]]
question = "When should I use MCP instead of function calling?"
answer = "Use MCP when tools need specific environments (local machine, VPC), you want to share tools across multiple apps, or you need dynamic tool discovery. Use function calling for simple integrations with 2-3 tools."

[[faqs]]
question = "Can MCP and function calling work together?"
answer = "Yes. Many applications use both - function calling for simple, app-integrated tools and MCP for complex tools that need to run in specific environments or be shared across applications."

[[faqs]]
question = "Is MCP harder to set up than function calling?"
answer = "MCP requires running a server, but tools like Gantz make setup simple with YAML configuration. Function calling requires more code but no separate server. Choose based on your use case, not setup difficulty."
+++


If you've been building with AI, you've probably seen both "function calling" and "MCP" thrown around. They sound similar - both let AI models use tools. But they're actually solving different problems.

This confusion is understandable. Both involve defining tools, both let AI decide when to use them, and both return results. But the architecture is fundamentally different, and choosing the wrong one for your use case creates unnecessary friction.

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

This has implications:
- Your code needs to handle every tool you define
- Tool execution happens in your application's environment
- You need to maintain the tool implementation code
- Adding new tools requires code changes and redeployment

Function calling is essentially the AI saying "I want to use the `get_weather` tool with these parameters" - and your code has to actually do the work.

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

This changes everything:
- Tools live separately from your application
- The MCP server handles all execution
- Adding tools means updating the server config, not your app
- The same tools can be shared across multiple applications

The AI doesn't just ask for something - it actually gets it done through the MCP server.

## The architecture difference

Let me visualize this more clearly:

**Function Calling Architecture:**
```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Your App  │────▶│  Claude API │────▶│  Your App   │
│  (defines   │     │  (returns   │     │  (executes  │
│   tools)    │     │  tool call) │     │   tools)    │
└─────────────┘     └─────────────┘     └─────────────┘
       │                                       │
       └───────────── same codebase ───────────┘
```

**MCP Architecture:**
```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Your App  │────▶│  Claude API │────▶│ MCP Server  │
│  (just UI)  │     │  (connects  │     │ (executes   │
│             │     │   to MCP)   │     │  tools)     │
└─────────────┘     └─────────────┘     └─────────────┘
                                               │
                                        separate system
```

With function calling, your application is both the client AND the tool executor. With MCP, your application just talks to Claude, and Claude talks to the MCP server.

## Why does this matter?

### Function calling is good when:
- **Tools are simple and few** - You have 2-5 straightforward tools that don't need complex setup
- **You want full control over execution** - You need to validate, transform, or intercept tool calls before execution
- **Tools need access to your app's state** - The tool needs to read from your database connection, session data, or in-memory state
- **You're building a single application** - One app, one set of tools, no sharing needed
- **You need tight integration** - The tool is core to your application logic, not separable

### MCP is good when:
- **Tools are complex or numerous** - You have many tools or tools with complex dependencies
- **You want to share tools across multiple apps** - Same tools used by your web app, Slack bot, and CLI
- **Tools need to run in a specific environment** - Your laptop, inside a VPC, or on a machine with special software
- **You want AI to discover tools dynamically** - Tools change frequently, and you don't want to redeploy
- **Tools are independent of your app** - They operate on external systems, not your app's state
- **You want separation of concerns** - App development separate from tool development

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

## Another example: Multi-app scenario

Imagine you have three applications:
1. A customer support chatbot
2. A Slack bot for your team
3. A CLI tool for developers

All three need to query the same database and check the same service health.

**With function calling:**
- Each app implements the same tools
- Three codebases to maintain
- Changes require updating all three
- Different bugs in different implementations

**With MCP:**
- One MCP server with the tools
- All three apps connect to the same server
- One codebase for tools
- Change once, all apps get the update

```yaml
# One gantz.yaml serves all three apps
tools:
  - name: query_customers
    description: Query customer database
    script:
      shell: psql -c "{{query}}"

  - name: check_service
    description: Check if a service is healthy
    script:
      shell: curl -s {{url}}/health
```

## The catch with MCP

MCP servers need to be accessible. If it's running on your laptop, Claude can't reach it unless you expose it somehow.

That's actually why I built [Gantz](https://gantz.run) - it creates a tunnel so your local MCP server gets a public URL. No port forwarding, no ngrok setup.

## Can you use both?

Yes. In fact, many real-world applications use both:

```python
response = client.messages.create(
    model="claude-sonnet-4-5-20250929",
    messages=[...],
    # Function calling for app-integrated tools
    tools=[
        {
            "name": "get_user_session",
            "description": "Get current user's session data",
            "input_schema": {...}
        },
        # MCP for external tools
        {"type": "mcp_toolset", "mcp_server_name": "infra-tools"}
    ],
    mcp_servers=[{
        "type": "url",
        "url": "https://infra.example.com/sse",
        "name": "infra-tools"
    }]
)
```

Use function calling for tools that need your app's context (user sessions, app state, in-memory data). Use MCP for tools that operate independently (database queries, external APIs, system commands).

## Decision framework

Ask yourself these questions:

1. **Does the tool need my app's state?**
   - Yes → Function calling
   - No → Either works, MCP might be cleaner

2. **Will multiple apps use this tool?**
   - Yes → MCP (share once, use everywhere)
   - No → Function calling is fine

3. **Does the tool need a specific environment?**
   - Yes → MCP (run the server where it needs to be)
   - No → Either works

4. **How often do tools change?**
   - Often → MCP (update server, not apps)
   - Rarely → Function calling is fine

5. **How many tools do you have?**
   - Many (10+) → MCP is easier to manage
   - Few (2-5) → Function calling is simpler

## TL;DR

| | Function Calling | MCP |
|---|---|---|
| Tools defined in | Your code | MCP server |
| Tool execution | Your app | MCP server |
| Discovery | Static (you define) | Dynamic (server provides) |
| Sharing | Per-app | Across apps |
| Environment | Your app's environment | Server's environment |
| Best for | Simple, integrated tools | Complex, shareable, remote tools |

Both have their place. Function calling isn't going away - it's still the simplest approach for basic integrations. But MCP makes certain things way easier - especially when you want AI to use tools that live somewhere specific, or when you want to share tools across applications.

## Related reading

- [What is MCP and Where Does it Fit in Your Stack?](/post/mcp-in-stack/) - MCP architecture deep-dive
- [Why Every Dev Will Run an MCP Server](/post/why-every-dev-mcp/) - The future of MCP
- [MCP vs ReAct: Protocol vs Pattern](/post/mcp-vs-react/) - Understanding the layers

---

*Building with MCP? I'd love to hear what tools you're exposing to AI agents.*
