+++
title = "MCP vs ReAct: Protocol vs Pattern"
date = 2025-12-11
description = "Understand the difference between MCP and ReAct. MCP is a protocol for tool communication, ReAct is a reasoning pattern. Learn when to use each in your AI agents."
image = "images/agent-train-02.webp"
draft = false
tags = ['mcp', 'patterns', 'comparison']
voice = true
+++


Two terms you'll hear when building AI agents: MCP and ReAct. They sound similar — both involve AI using tools. But they're solving different problems at different layers.

Understanding the difference will save you a lot of confusion.

## ReAct: The reasoning pattern

ReAct (Reasoning + Acting) is a pattern for how AI thinks and acts in a loop.

The loop:
```
Think → Act → Observe → Repeat
```

Example:
```
User: What's the population of the capital of France?

AI [Think]: I need to find the capital of France first, then look up its population.

AI [Act]: search("capital of France")

AI [Observe]: Result: Paris is the capital of France.

AI [Think]: Now I know the capital is Paris. I need to find Paris's population.

AI [Act]: search("population of Paris")

AI [Observe]: Result: Paris has approximately 2.1 million people.

AI [Think]: I have all the information I need.

AI [Answer]: The capital of France is Paris, with a population of approximately 2.1 million people.
```

ReAct is about **orchestration** — how the AI decides what to do, when to use tools, and how to combine results.

Frameworks like LangChain, AutoGPT, and CrewAI implement this pattern.

## MCP: The communication protocol

MCP (Model Context Protocol) is a protocol for how AI connects to and calls tools.

It defines:
- How to discover available tools
- How to call a tool
- How to get results back
- How to handle auth, errors, streaming

```
AI                          MCP Server
 |                               |
 |-- tools/list ---------------->|
 |<-- [list of tools] -----------|
 |                               |
 |-- tools/call (search) ------->|
 |<-- [result] ------------------|
```

MCP is about **communication** — the wire protocol between AI and tools.

It doesn't care how the AI decides to use tools. It just provides the pipe.

## Different layers

Think of it like web development:

| Layer | Web | AI Agents |
|-------|-----|-----------|
| Pattern | MVC, REST | ReAct, CoT |
| Protocol | HTTP | MCP |
| Transport | TCP/IP | stdio, SSE |

ReAct is like MVC — a pattern for organizing logic.
MCP is like HTTP — a protocol for communication.

You don't choose between them. You use both.

## How they work together

Here's what actually happens when an AI agent uses tools:

```
┌─────────────────────────────────────┐
│         Your Application            │
│  (LangChain, AutoGPT, custom code)  │
│                                     │
│  ┌─────────────────────────────┐    │
│  │     ReAct Orchestration     │    │
│  │  Think → Act → Observe →    │    │
│  └──────────────┬──────────────┘    │
│                 │                   │
│                 │ "Call this tool"  │
│                 ▼                   │
│  ┌─────────────────────────────┐    │
│  │        MCP Client           │    │
│  │  (handles protocol stuff)   │    │
│  └──────────────┬──────────────┘    │
└─────────────────┼───────────────────┘
                  │
                  │ MCP Protocol (JSON-RPC over SSE)
                  ▼
┌─────────────────────────────────────┐
│          MCP Server                 │
│  (Gantz, custom server, etc.)       │
│                                     │
│  ┌─────────────────────────────┐    │
│  │         Your Tools          │    │
│  │  - query_database           │    │
│  │  - send_email               │    │
│  │  - search_files             │    │
│  └─────────────────────────────┘    │
└─────────────────────────────────────┘
```

**ReAct** decides WHAT to do and WHEN.
**MCP** handles HOW to actually call tools.

## Concrete example

Let's say you're building an AI assistant that can manage your calendar.

**Without ReAct, without MCP:**
```python
response = openai.chat("What meetings do I have tomorrow?")
# AI can only guess or say "I don't know"
```

**With ReAct, without MCP:**
```python
# Your code implements the loop
while not done:
    thought = ai.think(context)
    action = ai.decide_action(thought)

    # But how do you actually call tools?
    # You build custom integrations for each one
    if action.tool == "calendar":
        result = custom_calendar_integration(action.params)
    elif action.tool == "email":
        result = custom_email_integration(action.params)
    # ... endless if/else

    context.add(result)
```

**Without ReAct, with MCP:**
```python
# AI can call tools via MCP
response = claude.messages.create(
    messages=[{"role": "user", "content": "What meetings do I have tomorrow?"}],
    mcp_servers=[{"url": "https://my-tools.gantz.run/sse"}],
    tools=[{"type": "mcp_toolset"}]
)
# Works! But AI makes one tool call and stops
# No multi-step reasoning
```

**With ReAct AND MCP:**
```python
# LangChain or similar handles ReAct loop
# MCP handles tool communication

agent = create_react_agent(
    llm=claude,
    tools=MCPToolkit("https://my-tools.gantz.run/sse")
)

# Agent reasons through the problem, calls tools via MCP
result = agent.run("What meetings do I have tomorrow? If any conflict, suggest reschedules.")

# Agent might:
# 1. Think: "I need to check tomorrow's calendar"
# 2. Act: [MCP call to get_calendar]
# 3. Observe: "3 meetings, two overlap"
# 4. Think: "There's a conflict, I should check priorities"
# 5. Act: [MCP call to get_meeting_details]
# 6. Observe: "Meeting A is with CEO, Meeting B is optional"
# 7. Think: "I should suggest moving the optional one"
# 8. Answer: "You have 3 meetings. Meetings at 2pm conflict..."
```

## When you need what

**You need ReAct (or similar pattern) when:**
- Multi-step tasks
- AI needs to reason about what to do
- Results of one action inform the next
- Complex workflows
- Error recovery and retries

**You need MCP when:**
- AI needs to call external tools
- You want standard tool interface
- Multiple AI agents share tools
- Tools run on different machines
- You want tool discovery

**You need both when:**
- Building real AI agents
- Anything beyond simple Q&A
- Production applications

## What each one handles

**ReAct handles:**
- Planning ("I need to do X, then Y, then Z")
- Reasoning ("The result shows X, so I should try Y")
- Memory ("Earlier I found that...")
- Error recovery ("That failed, let me try differently")
- Stopping conditions ("I have enough info now")

**MCP handles:**
- Tool discovery ("What tools are available?")
- Tool schemas ("What parameters does this tool need?")
- Invocation ("Call this tool with these params")
- Authentication ("Here's my token")
- Streaming ("Send results as they come")
- Transport ("Use SSE/stdio/etc")

## Common mistakes

### Mistake 1: "I'll just use MCP"

MCP alone gives you tool calling. But without orchestration, AI makes one call and stops.

```
User: "Analyze my sales data and create a report"
AI: [calls get_sales_data]
AI: "Here's your sales data: [raw JSON]"
# That's it. No analysis. No report.
```

You need ReAct or similar to make AI actually reason through the task.

### Mistake 2: "I'll just use LangChain/ReAct"

ReAct handles orchestration, but you still need to connect tools somehow.

Without MCP, you're writing custom integrations:
- Custom code for each tool
- No standard discovery
- No standard auth
- Reinventing the wheel

MCP gives you the standard interface.

### Mistake 3: "They're alternatives"

They're not. They're layers.

Like saying "Should I use HTTP or React?" Wrong question. React (the framework) uses HTTP to fetch data. They're different layers.

Same here. ReAct (the pattern) uses MCP to call tools. Different layers.

## The stack

Modern AI agent stack:

```
┌────────────────────────────┐
│   User Interface           │  (Chat UI, API, etc.)
├────────────────────────────┤
│   Agent Framework          │  (LangChain, AutoGPT, custom)
│   - ReAct loop             │
│   - Memory management      │
│   - Planning               │
├────────────────────────────┤
│   MCP Client               │  (Protocol handling)
├────────────────────────────┤
│   MCP Server               │  (Gantz, custom, hosted)
│   - Tool definitions       │
│   - Execution              │
├────────────────────────────┤
│   Actual Tools             │  (APIs, databases, scripts)
└────────────────────────────┘
```

Each layer has a job. ReAct orchestrates. MCP communicates.

## Getting started

**For MCP:**
- Use [Gantz](https://gantz.run) to spin up an MCP server
- Define your tools in YAML
- Connect any AI agent

**For ReAct:**
- Use LangChain, LlamaIndex, or similar
- Or implement your own loop
- The pattern is simple: Think → Act → Observe → Repeat

**For both together:**
- LangChain has MCP integrations
- Claude API supports MCP natively with built-in reasoning
- Or build custom orchestration on top of MCP

## Summary

| | ReAct | MCP |
|---|---|---|
| Layer | Orchestration | Communication |
| What it does | Decides what tools to call | Handles how to call tools |
| Analogy | The brain | The nervous system |
| Implemented by | LangChain, AutoGPT, etc. | Protocol spec + servers |
| You need it for | Multi-step reasoning | Tool connectivity |

Don't choose between them. Use both.

ReAct for thinking. MCP for doing.

Understanding this separation makes your architecture cleaner. The orchestration layer (ReAct, Planner-Executor, or your custom loop) decides what to do. The protocol layer (MCP) handles how to communicate with tools. Clean separation of concerns.

When building agents, get the orchestration right first, then optimize the tool communication layer.

## Related reading

- [What is MCP and Where Does it Fit in Your Stack?](/post/mcp-in-stack/) - MCP fundamentals
- [Why Agents Get Stuck in Loops](/post/agent-loops/) - Understanding agent reasoning
- [The Planner-Executor Pattern](/post/planner-executor/) - Another orchestration approach

---

*Building AI agents? How do you handle orchestration and tool calling?*
