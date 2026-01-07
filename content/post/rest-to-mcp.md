+++
title = "From REST to MCP: what's changing"
date = 2025-11-28
description = "REST was built for apps, MCP for AI. Compare API paradigms and understand why AI agents need tool protocols instead of traditional endpoints."
image = "images/robot-billboard-06.webp"
draft = false
tags = ['mcp', 'architecture', 'comparison']
voice = true
+++


REST has been the standard for 20 years. Every API you use, every integration you build - it's probably REST. The pattern is everywhere: resources with URLs, HTTP verbs for actions, JSON responses.

But something's shifting. AI doesn't think in endpoints and HTTP verbs. It thinks in actions and goals. When you ask Claude to "get the user's recent orders," it doesn't naturally map that to `GET /api/v2/users/123/orders?limit=10&sort=desc`. That translation layer is friction.

MCP (Model Context Protocol) takes a different approach. Instead of exposing resources and operations, you expose tools with descriptions. The AI reads the description, understands the purpose, and decides when to use it.

This isn't about REST being bad. REST is great for apps. But AI is a different kind of client, and it needs a different interface.

## REST was built for apps

REST (Representational State Transfer) was designed for applications talking to servers. The model is clean:

- **Resources** have URLs (`/users/123`, `/orders`, `/products/456`)
- **HTTP verbs** define actions (GET reads, POST creates, PUT updates, DELETE removes)
- **Responses** are structured data (usually JSON)
- **State** is maintained by the client, not the server

```
GET /users/123           → Read user 123
POST /orders             → Create new order
PUT /products/456        → Update product 456
DELETE /comments/789     → Delete comment 789
```

This works brilliantly for apps. A frontend developer knows exactly what data they need. They write code that calls specific endpoints with specific parameters. The structure is fixed at compile time.

The REST contract is explicit: the server documents its endpoints, the client implements calls to those endpoints. Both sides know the interface.

But this assumes the caller knows exactly what it wants before the request. The entire interaction is predetermined.

## AI doesn't work that way

When you ask Claude to "get me the user's recent orders," it doesn't naturally think:

```
"I need to call GET /api/v2/users/123/orders with query parameters
limit=10 and sort=created_at&order=desc, using Bearer token authentication
in the Authorization header..."
```

It thinks in goals and actions:

- **Goal:** Get orders for this user
- **Constraint:** Recent ones (what does "recent" mean? Last 10? Last week?)
- **Action:** Use whatever tool gets user orders

The mismatch is fundamental. REST is designed around **resources and operations**. AI thinks in **goals and capabilities**.

To make REST work with AI, you need a translation layer - either prompt engineering that teaches the AI your API structure, or code that maps AI intent to REST calls. Both add friction. Both break when APIs change.

REST forces AI to map natural language to rigid endpoints. It can work, but it's fighting against the grain.

## MCP is built for AI

MCP flips the model. Instead of endpoints that the caller must know in advance, you expose **tools** that describe themselves:

```yaml
tools:
  - name: get_user_orders
    description: >
      Get orders for a user, optionally filtered by date.
      Use this when someone asks about a customer's purchase history,
      recent orders, or order status. Returns up to 100 orders.
    parameters:
      - name: user_id
        type: string
        description: The user's unique identifier
        required: true
      - name: since
        type: string
        description: ISO date to filter orders from (e.g., "2024-01-01")
      - name: status
        type: string
        description: Filter by order status (pending, shipped, delivered)
```

The key differences:

1. **Self-describing:** The AI reads the description and understands when to use this tool
2. **Intent-focused:** The description explains the *purpose*, not just the mechanics
3. **Discoverable:** AI asks "what tools do you have?" and gets this list automatically

No documentation parsing. No memorizing URL patterns. No teaching the AI your API version structure. Just tools with clear descriptions that explain their purpose.

The AI reads the description, understands the parameters, and makes intelligent decisions about when to use each tool.

## Key differences

Let's break down the fundamental differences between REST and MCP.

### Discovery

**REST approach:**
1. Developer reads API documentation
2. Developer finds relevant endpoints
3. Developer hardcodes those endpoints into their app
4. If the API changes, the app breaks

**MCP approach:**
1. AI connects to MCP server
2. AI calls `tools/list` - "what tools do you have?"
3. Server returns all available tools with descriptions
4. AI picks the right tool based on the user's request

```json
// MCP tools/list response
{
  "tools": [
    {
      "name": "get_user_orders",
      "description": "Get orders for a user. Use when someone asks about purchase history.",
      "inputSchema": {
        "type": "object",
        "properties": {
          "user_id": { "type": "string" },
          "limit": { "type": "number" }
        },
        "required": ["user_id"]
      }
    },
    {
      "name": "create_order",
      "description": "Create a new order. Use when processing a purchase.",
      "inputSchema": { ... }
    }
  ]
}
```

The AI discovers what's available at runtime. If you add a new tool, the AI can use it immediately - no code changes needed on the client side.

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

MCP is a layer on top - it wraps your existing stuff and exposes it to AI.

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

We're early in this shift. Most APIs are still REST-only. But the pattern is emerging.

### Where we are today

**2024-2025: Manual integration**
- Developers manually teach AI about their REST APIs via prompts
- Custom code translates AI intent to REST calls
- Lots of prompt engineering to get reliable API usage

### Where we're heading

**2025-2026: MCP wrappers emerge**
- Popular APIs get community-built MCP wrappers (Stripe, GitHub, Slack)
- Tools like [Gantz](https://gantz.run) make wrapping REST APIs trivial
- Companies start exposing MCP alongside REST for AI integration

**2026+: MCP becomes standard**
- Major APIs ship with official MCP servers
- "AI-native" replaces "mobile-first" as a design principle
- MCP support is expected, like REST support today

### Wrapping REST APIs today

You don't have to wait. Tools like Gantz let you wrap existing REST APIs as MCP tools right now:

```yaml
tools:
  - name: get_weather
    description: >
      Get current weather for a city.
      Use when someone asks about weather, temperature, or conditions.
    parameters:
      - name: city
        type: string
        description: City name (e.g., "London", "New York")
        required: true
    http:
      method: GET
      url: "https://api.weather.com/current"
      query:
        q: "{{city}}"
      headers:
        Authorization: "Bearer ${WEATHER_API_KEY}"

  - name: create_github_issue
    description: >
      Create a new issue in a GitHub repository.
      Use when someone wants to file a bug or feature request.
    parameters:
      - name: repo
        type: string
        description: Repository in owner/repo format
        required: true
      - name: title
        type: string
        required: true
      - name: body
        type: string
    http:
      method: POST
      url: "https://api.github.com/repos/{{repo}}/issues"
      headers:
        Authorization: "Bearer ${GITHUB_TOKEN}"
        Accept: "application/vnd.github.v3+json"
      body:
        title: "{{title}}"
        body: "{{body}}"
```

Your REST API becomes AI-accessible with a few lines of YAML. The AI doesn't need to know it's REST under the hood - it just sees tools with descriptions.

### Migration pattern

If you're building APIs today, consider this pattern:

1. **Build your REST API** as normal (it's still what apps need)
2. **Add an MCP layer** that wraps your most common operations
3. **Write good descriptions** that explain when to use each tool
4. **Test with AI** to see if the descriptions are clear enough

You're not replacing REST. You're adding an AI-friendly interface on top.

## When to use which

This isn't a binary choice. Different clients need different interfaces.

### Use REST when:

- **Building traditional web/mobile apps** - Your frontend knows exactly what data it needs
- **Server-to-server communication** - Microservices talking to each other
- **Public APIs for developers** - You need stable, versioned endpoints
- **High-performance scenarios** - REST is well-optimized, every framework supports it
- **The client is deterministic** - Same input always needs same endpoint

### Use MCP when:

- **AI is the client** - Claude, GPT, or other LLMs need to use your service
- **The interaction is dynamic** - You don't know in advance what the AI will need
- **You want self-describing tools** - AI should understand capabilities without documentation
- **Multiple AI providers** - You want one interface that works with any MCP-compatible AI
- **Building AI agents** - Autonomous systems that decide which tools to use

### Use both when:

Most realistic scenarios need both:

```
Mobile App    →  REST API  →  Your Backend
AI Agent      →  MCP Server → Your Backend
```

Your backend stays the same. You just expose different interfaces for different clients.

## Not either/or

This isn't REST vs MCP. It's REST + MCP.

REST handles app-to-server communication. It's mature, well-understood, supported everywhere. Your apps will use REST for years to come.

MCP handles AI-to-tools communication. It's designed for a new kind of client - one that reasons about capabilities rather than hardcoding endpoints.

Different problems, different protocols.

If you're building for the future, you'll want both. REST for your apps, MCP for AI integration. Start with REST (you probably already have it), add MCP when AI support matters.

## Related reading

- [What is MCP and Where Does it Fit in Your Stack?](/post/mcp-in-stack/) - MCP architecture explained
- [MCP vs Function Calling - What's the difference?](/post/mcp-vs-function-calling/) - Choosing between approaches
- [Why Every Dev Will Run an MCP Server](/post/why-every-dev-mcp/) - The future of local tools

---

*Already wrapping REST APIs with MCP? What's been your experience?*
