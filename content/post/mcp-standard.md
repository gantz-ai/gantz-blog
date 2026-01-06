+++
title = "Will MCP become a standard?"
date = 2025-12-13
image = "images/astronaut-space-station.png"
draft = false
tags = ['mcp', 'deep-dive', 'architecture']
+++


Anthropic released MCP (Model Context Protocol) and suddenly everyone's talking about it. But here's the real question:

Will it stick? Or will it become another protocol that fades into obscurity?

I think MCP has a real shot at becoming *the* standard. Here's why.

## The problem is real

Every AI app has the same problem: how do you give AI access to tools?

Right now, everyone builds their own thing:
- OpenAI has function calling
- LangChain has its tools format
- Every startup has a custom integration layer

It's fragmented. You build tools for one system, and they don't work anywhere else.

MCP solves this with a standard protocol. Build once, use everywhere.

## What makes standards stick

Looking at history, successful standards share common traits:

### 1. Backed by a major player

HTTP had CERN, then the W3C. JSON had Douglas Crockford and eventually ECMA. USB had Intel and the consortium.

MCP has Anthropic. Not the biggest player, but credible. And they've open-sourced it — not keeping it proprietary.

### 2. Simple enough to implement

REST won partly because it's simple. GraphQL is more complex, and adoption has been slower.

MCP is relatively simple:
- JSON-RPC over stdio or SSE
- Standard methods (`tools/list`, `tools/call`)
- Clear schema for tools

You can implement a basic MCP server in an afternoon.

### 3. Solves a pain point

Nobody adopts standards for fun. They adopt them because the alternative is worse.

Right now, connecting AI to tools is painful:
- Custom integrations for each AI provider
- No standard way to discover tools
- Duplicate work across projects

MCP eliminates this. One protocol, all AI agents.

### 4. Network effects

The more tools use MCP, the more valuable it becomes. The more AI agents support MCP, the more tools get built.

We're early in this cycle, but the flywheel is starting to spin.

## Who's adopting it

**AI providers:**
- Claude (native support)
- Cursor (IDE integration)
- More coming

**Tool builders:**
- Growing ecosystem of MCP servers
- Open source implementations popping up
- Companies building MCP integrations

**Developers:**
- Building local MCP servers for personal use
- Wrapping existing APIs as MCP tools
- Sharing configs and tools

It's not mainstream yet. But the early signs are there.

## The competition

MCP isn't the only option.

**OpenAI function calling:** Already widely used. But it's OpenAI-specific and more limited in scope.

**LangChain tools:** Popular in the Python ecosystem. But tied to the LangChain framework.

**Custom protocols:** Every company rolling their own. Works, but not interoperable.

MCP's advantage: it's not tied to one vendor or framework. It's designed to be universal.

## What could go wrong

### OpenAI makes their own standard

If OpenAI releases a competing protocol with better tooling and marketing, MCP could lose momentum.

But OpenAI tends to build closed ecosystems. A truly open standard might win anyway.

### Fragmentation

If different AI providers adopt different protocols, we get a VHS vs Betamax situation.

Developers would need to support multiple protocols. The dream of "build once, use everywhere" dies.

### Complexity creep

Standards can die from complexity. If MCP adds too many features, it becomes hard to implement correctly.

So far, MCP is staying simple. Hopefully it stays that way.

### Nobody uses it

Worst case: MCP stays niche. Only used by Anthropic users, never reaches critical mass.

Possible, but seems less likely given the momentum.

## My prediction

MCP becomes the de facto standard for AI-to-tool communication within 2-3 years.

Here's how I see it playing out:

**2025:** MCP adoption grows among Claude users. More tools, more integrations. OpenAI announces some form of compatibility or competing standard.

**2026:** Major APIs ship MCP servers alongside REST. GitHub, Stripe, Slack — the big ones. Framework support matures.

**2027:** MCP is assumed. If your service doesn't have MCP support, it's like not having a REST API today.

## Why it matters

If MCP becomes standard, everything changes:

**For developers:**
- Build tools once, work everywhere
- No more vendor lock-in
- Growing ecosystem to tap into

**For companies:**
- Standard way to expose services to AI
- Reduced integration costs
- Access to all AI agents, not just one

**For users:**
- AI that can actually do things
- Consistent experience across tools
- More capable AI assistants

## What you should do

Don't wait to find out.

If MCP becomes standard, you want to be ready. If it doesn't, you've still built useful tools.

Start now:
- Learn the protocol basics
- Build a few MCP tools
- Wrap your existing APIs

Tools like [Gantz](https://gantz.run) make this easy — spin up an MCP server in minutes, not days.

The cost of experimenting is low. The cost of being late is high.

---

*Betting on MCP? Or waiting to see how it plays out? I'm curious what others think.*
