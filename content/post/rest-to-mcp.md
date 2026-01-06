+++
title = "From REST to MCP: what's changing"
date = 2025-11-28
image = "images/robot-billboard-06.webp"
draft = false
tags = ['mcp', 'architecture', 'comparison']
+++


REST has been the standard for 20 years. Every API you use, every integration you build — it's probably REST.

But something's shifting. AI doesn't want to call endpoints. It wants to call tools.

That's where MCP comes in.

## REST was built for apps

REST is great for what it was designed for: apps talking to servers.

```
GET /users/123
POST /orders
PUT /products/456
DELETE /comments/789
```

Predictable. Stateless. Works everywhere.

But REST assumes the caller knows exactly what it wants. You write code that calls specific endpoints with specific parameters. The structure is fixed.

## AI doesn't work that way

When you ask Claude to "get me the user's recent orders," it doesn't think in endpoints. It thinks in actions:

- What do I need to do? → Get orders
- What information do I need? → User ID
- What constraints? → Recent ones

REST forces AI to map natural language to rigid endpoints. It can work, but it's awkward.

## MCP is built for AI

MCP flips the model. Instead of endpoints, you expose tools:

```yaml
tools:
  - name: get_user_orders
    description: Get orders for a user, optionally filtered by date
    parameters:
      - name: user_id
        type: string
        required: true
      - name: since
        type: string
        description: ISO date to filter orders from
```

The AI reads the description, understands the parameters, and decides when to use it.

No documentation parsing. No endpoint memorization. Just tools with clear descriptions.

## Key differences

### Discovery

**REST:** You read docs, find endpoints, hardcode them.

**MCP:** AI connects to server, asks "what tools do you have?", gets a list with descriptions.

```json
// MCP tools/list response
{
  "tools": [
    {
      "name": "get_user_orders",
      "description": "Get orders for a user",
      "inputSchema": { ... }
    },
    {
      "name": "create_order",
      "description": "Create a new order",
      "inputSchema": { ... }
    }
  ]
}
```

AI discovers what's available at runtime. No hardcoding.

### Intent vs structure

**REST:**
```
GET /api/v2/users/123/orders?status=completed&limit=10&sort=desc
```

You need to know the exact path, query params, API version.

**MCP:**
```json
{
  "tool": "get_user_orders",
  "arguments": {
    "user_id": "123",
    "status": "completed",
    "limit": 10
  }
}
```

AI figures out the arguments from natural language. "Show me John's last 10 completed orders" maps directly.

### Descriptions matter

In REST, descriptions are documentation. Nice to have.

In MCP, descriptions are how AI understands what to do. They're functional.

```yaml
# Bad - AI won't know when to use this
- name: proc_txn
  description: Process transaction

# Good - AI understands the use case
- name: process_payment
  description: Charge a customer's saved payment method. Use this when the user wants to complete a purchase. Requires order_id and payment_method_id.
```

The better your descriptions, the smarter the AI behaves.

### Streaming

REST is request-response. Call endpoint, get result.

MCP supports streaming via SSE. AI can:
- See partial results as they come
- Get progress updates
- Handle long-running operations

```
AI: "Analyze this large dataset"
Tool: [streaming] Processing chunk 1/10...
Tool: [streaming] Processing chunk 2/10...
...
Tool: [complete] Analysis ready
```

### State and context

REST is stateless by design. Each request is independent.

MCP can maintain context. The AI can:
- Make multiple related calls
- Build on previous results
- Handle multi-step workflows

```
User: "Find the slowest API endpoint and show me its logs"

AI:
1. calls get_performance_metrics
2. identifies slow endpoint from results
3. calls get_logs with that endpoint
4. summarizes findings
```

One user request, multiple tool calls, coherent result.

## What this means for developers

### You'll still use REST

MCP doesn't replace REST. Your apps still call APIs the normal way.

MCP is a layer on top — it wraps your existing stuff and exposes it to AI.

```
Your REST API → MCP Server → AI Agent
```

### Tools become the interface

Instead of thinking "what endpoints do I need?", you'll think "what tools should AI have?"

Different mental model:
- Endpoints: What operations exist?
- Tools: What can AI do with this?

### Descriptions become documentation

Your tool descriptions are how AI understands your system. Write them like you're explaining to a smart intern.

Bad: `query_db` - "Query database"
Good: `query_db` - "Run a read-only SQL query against the production database. Use for fetching data, never for modifications. Returns up to 1000 rows."

### You control the interface

With REST, the API structure is fixed. With MCP, you control what tools exist and how they're described.

You can:
- Hide complexity behind simple tools
- Add guardrails (read-only, rate limits)
- Shape how AI interacts with your system

## The transition

We're early. Most APIs are still REST. But the pattern is emerging:

1. **Now:** Developers manually integrate REST APIs with AI
2. **Soon:** MCP wrappers for popular APIs (Stripe, GitHub, etc.)
3. **Later:** APIs ship with MCP servers alongside REST

Tools like [Gantz](https://gantz.run) already let you wrap REST APIs as MCP tools:

```yaml
tools:
  - name: get_weather
    description: Get current weather for a city
    parameters:
      - name: city
        type: string
        required: true
    http:
      method: GET
      url: "https://api.weather.com/current"
      query:
        q: "{{city}}"
```

Your REST API becomes AI-accessible in a few lines.

## Not either/or

This isn't REST vs MCP. It's REST + MCP.

REST handles app-to-server communication. MCP handles AI-to-tools communication.

Different problems, different protocols.

But if you're building for an AI-first world, MCP is the interface that matters.

---

*Already wrapping REST APIs with MCP? What's been your experience?*
