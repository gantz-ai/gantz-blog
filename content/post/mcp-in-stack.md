+++
title = "Where does MCP fit in your stack?"
date = 2025-12-14
description = "Understand where Model Context Protocol fits in your AI architecture. Visual guide to MCP's role between LLMs, tools, and your application layer."
image = "images/agent-platform-logo.webp"
draft = false
tags = ['mcp', 'architecture', 'deep-dive']
voice = false
+++


You've heard about MCP. You know it connects AI to tools. But where does it actually sit in your architecture?

This is a common source of confusion. People ask: "Is MCP like LangChain? Is it a replacement for function calling? Does it replace my RAG pipeline?"

The answer to all of these is no. MCP fills a specific gap in the AI stack — and understanding where it fits helps you use it effectively.

Let me draw you a map.

## The modern AI stack

Here's a typical AI application stack, top to bottom:

```
┌─────────────────────────────────────┐
│           User Interface            │  ← What users see
├─────────────────────────────────────┤
│           Application               │  ← Your app logic
├─────────────────────────────────────┤
│         AI Orchestration            │  ← Agent/reasoning layer
├─────────────────────────────────────┤
│           AI Model API              │  ← Claude, GPT, etc.
├─────────────────────────────────────┤
│      ┌─────────┐ ┌─────────┐        │
│      │   MCP   │ │   RAG   │        │  ← Data & tool access
│      └─────────┘ └─────────┘        │
├─────────────────────────────────────┤
│         External Systems            │  ← DBs, APIs, services
└─────────────────────────────────────┘
```

MCP sits between your AI layer and your external systems. It's the bridge that standardizes how AI talks to tools.

Notice what MCP is NOT in this diagram:
- It's not the UI
- It's not your application logic
- It's not the AI model
- It's not the orchestration layer
- It's not your databases or services

It's specifically the **tool communication protocol** — nothing more, nothing less.

## Layer by layer

Let's walk through each layer to understand what it does and how it relates to MCP.

### Layer 1: User Interface

What users interact with.

- Chat interface
- Web app
- CLI
- API endpoint
- Slack bot

MCP has nothing to do with this layer.

### Layer 2: Application

Your business logic.

- User authentication
- Request handling
- Response formatting
- Logging, analytics

MCP doesn't live here either.

### Layer 3: AI Orchestration

Where AI decisions happen.

- ReAct loops
- Planning
- Memory management
- Multi-step reasoning

This layer *uses* MCP to call tools.

```python
# Orchestration layer decides to call a tool
if agent.needs_tool("search_database"):
    # MCP handles the actual call
    result = mcp_client.call_tool("search_database", params)
```

### Layer 4: AI Model API

The actual AI model.

- Claude API
- OpenAI API
- Local models

Some models (like Claude) have native MCP support. Others need an adapter.

### Layer 5: MCP (This is where it lives)

**MCP sits here.** Between AI and external systems.

```
AI wants to do something
        ↓
    MCP Client
        ↓
   MCP Protocol (JSON-RPC over SSE/stdio)
        ↓
    MCP Server
        ↓
External systems (DB, API, files, etc.)
```

MCP handles:
- Tool discovery
- Tool invocation
- Parameter passing
- Result returning
- Auth, streaming, errors

### Layer 6: External Systems

The actual things MCP connects to.

- Databases
- REST APIs
- File systems
- Shell commands
- Third-party services

MCP doesn't care what's here. It just provides the interface.

## MCP components

MCP has two sides:

```
┌─────────────────┐         ┌─────────────────┐
│   MCP Client    │ ←─────→ │   MCP Server    │
│                 │   MCP   │                 │
│  (In your app   │ Protocol│  (Exposes your  │
│   or AI model)  │         │   tools)        │
└─────────────────┘         └─────────────────┘
```

### MCP Client

Lives in your application or AI model.

- Connects to MCP servers
- Discovers available tools
- Makes tool calls
- Handles responses

Claude has a built-in MCP client. Or you use a library.

### MCP Server

Exposes your tools to AI.

- Defines available tools
- Handles tool calls
- Executes against external systems
- Returns results

This is what [Gantz](https://gantz.run) gives you — an easy way to run MCP servers.

## Where MCP doesn't fit

MCP is NOT:

### Not an AI model

MCP doesn't do AI. It connects AI to tools.

```
Wrong: "MCP will answer my questions"
Right: "MCP lets AI access my database to answer questions"
```

### Not an orchestration framework

MCP doesn't decide what to do. That's your agent/orchestration layer.

```
Wrong: "MCP will figure out which tools to use"
Right: "AI decides which tools to use, MCP handles the call"
```

### Not a RAG system

MCP is for actions. RAG is for knowledge retrieval.

```
Wrong: "MCP will search my documents"
Right: "MCP calls a search tool, which might use RAG"
```

### Not your application logic

MCP just connects. Your app logic lives elsewhere.

```
Wrong: "MCP handles user authentication"
Right: "MCP calls a tool that checks authentication"
```

## Integration patterns

### Pattern 1: Direct integration

AI model with native MCP support.

```
┌──────────┐      ┌──────────────┐
│  Claude  │─────→│  MCP Server  │
│  (MCP    │ MCP  │  (Gantz)     │
│  Client) │      │              │
└──────────┘      └──────────────┘
```

```python
response = claude.messages.create(
    messages=[...],
    mcp_servers=[{
        "type": "url",
        "url": "https://my-tools.gantz.run/sse",
        "name": "tools"
    }],
    tools=[{"type": "mcp_toolset"}]
)
```

### Pattern 2: Through orchestration

Agent framework manages MCP.

```
┌──────────┐      ┌──────────────┐      ┌──────────────┐
│  Claude  │─────→│  LangChain   │─────→│  MCP Server  │
│          │      │  (MCP Client)│ MCP  │              │
└──────────┘      └──────────────┘      └──────────────┘
```

```python
from langchain_mcp import MCPToolkit

toolkit = MCPToolkit("https://my-tools.gantz.run/sse")
agent = create_agent(llm=claude, tools=toolkit.get_tools())
```

### Pattern 3: Multiple MCP servers

Different servers for different domains.

```
                  ┌──────────────────┐
                  │   MCP Server 1   │
             ┌───→│   (Database)     │
             │    └──────────────────┘
┌──────────┐ │
│   AI     │─┼───→┌──────────────────┐
│  Agent   │ │    │   MCP Server 2   │
└──────────┘ │    │   (Email)        │
             │    └──────────────────┘
             │
             └───→┌──────────────────┐
                  │   MCP Server 3   │
                  │   (Calendar)     │
                  └──────────────────┘
```

### Pattern 4: MCP gateway

Single entry point to multiple backends.

```
┌──────────┐      ┌──────────────┐      ┌─────────────┐
│   AI     │─────→│  MCP Gateway │─────→│ Service A   │
│  Agent   │ MCP  │              │      ├─────────────┤
└──────────┘      │              │─────→│ Service B   │
                  │              │      ├─────────────┤
                  │              │─────→│ Service C   │
                  └──────────────┘      └─────────────┘
```

## Real example

Let's trace a request through the stack:

**User:** "What's my top customer's email?"

```
1. User Interface
   └─ User types question in chat

2. Application
   └─ Request sent to backend

3. AI Orchestration
   └─ Agent decides: "I need to query the database"

4. AI Model
   └─ Claude generates tool call: query_customers

5. MCP Layer  ← HERE
   ├─ MCP Client sends: tools/call "query_customers"
   ├─ MCP Server receives request
   ├─ Server executes: SELECT * FROM customers ORDER BY revenue DESC LIMIT 1
   └─ Server returns result via MCP

6. External Systems
   └─ PostgreSQL returns data

7. Back up the stack
   └─ AI gets result → formulates answer → returns to user
```

MCP handled step 5 — the protocol layer between AI and database.

## What MCP replaces

Before MCP, you'd write custom integration code:

```python
# Old way: Custom integration per tool
def handle_tool_call(tool_name, params):
    if tool_name == "query_db":
        return custom_db_query(params)
    elif tool_name == "send_email":
        return custom_email_send(params)
    elif tool_name == "search_files":
        return custom_file_search(params)
    # ... endless if/else
```

With MCP:

```python
# New way: Standard protocol
mcp_client.call_tool(tool_name, params)
# MCP server handles the rest
```

## Common misconceptions

Let me address some things I see people get wrong about MCP.

### "MCP replaces LangChain"

No. LangChain is an orchestration framework — it handles chains, agents, memory, and routing. MCP is a protocol for tool communication. You can use MCP **with** LangChain:

```python
from langchain_mcp import MCPToolkit

# LangChain orchestrates, MCP handles tool calls
toolkit = MCPToolkit("https://my-tools.gantz.run/sse")
agent = create_react_agent(llm, toolkit.get_tools())
```

### "MCP replaces RAG"

No. RAG is for knowledge retrieval — finding relevant documents to inform AI responses. MCP is for tool execution — doing things, not finding things.

You might have both:
- MCP tool to trigger a search
- RAG pipeline to retrieve and rank documents
- AI uses the results

### "MCP is only for Claude"

No. MCP is an open protocol. While Claude has native support, you can use MCP with any AI system that supports tool use. Cursor, Zed, and other tools also support MCP.

### "MCP is only for local tools"

No. MCP servers can run anywhere:
- On your laptop (for local development)
- On a server in your VPC (for production)
- As a cloud service (for shared tools)

The protocol doesn't care where the server lives.

## When to add MCP to your stack

Not every AI application needs MCP. Consider adding it when:

1. **You have tools that need to run in a specific location** — local machine, VPC, air-gapped network
2. **You want to share tools across multiple applications** — one server, many clients
3. **Tools change frequently** — update server, not apps
4. **You want dynamic tool discovery** — AI learns available tools at runtime
5. **You're building for multiple AI providers** — one tool interface for all

Skip MCP if:
- You have 2-3 simple tools tightly integrated with your app
- Tools need access to your application's internal state
- You're prototyping and want minimal setup

## Summary

**MCP sits between AI and external systems.**

```
Your AI app
    ↓
AI orchestration (decides what to do)
    ↓
MCP ← HERE (handles tool communication)
    ↓
Your tools and services
```

It's not the brain (AI model).
It's not the decision maker (orchestration).
It's not the data (external systems).

It's the nervous system — carrying signals between brain and body.

Understanding this positioning helps you make better architectural decisions. MCP doesn't replace your other tools — it complements them by standardizing one specific part of the stack: how AI communicates with external capabilities.

## Related reading

- [Will MCP become a standard?](/post/mcp-standard/) - The future of MCP adoption
- [MCP vs ReAct: Protocol vs Pattern](/post/mcp-vs-react/) - Understanding the difference
- [Why every dev will run an MCP server](/post/why-every-dev-mcp/) - MCP in developer workflows

---

*Where does MCP fit in your architecture? Running it locally or in the cloud?*
