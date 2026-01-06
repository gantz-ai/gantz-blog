+++
title = "Will MCP become a standard?"
date = 2025-12-13
description = "Analysis of whether Model Context Protocol will become the industry standard for AI tool integration. Examines MCP's advantages, adoption trajectory, and competition."
image = "images/astronaut-space-station.webp"
draft = false
tags = ['mcp', 'deep-dive', 'architecture']
voice = true
+++


Anthropic released MCP (Model Context Protocol) and suddenly everyone's talking about it. But here's the real question:

Will it stick? Or will it become another protocol that fades into obscurity?

I think MCP has a real shot at becoming *the* standard. Here's why — and what history tells us about which protocols win.

## The problem is real

Every AI app has the same problem: how do you give AI access to tools?

Right now, everyone builds their own thing:
- OpenAI has function calling with their specific JSON schema
- LangChain has its tools format with Python decorators
- Every startup has a custom integration layer
- Google has their own function calling format
- Cohere has their tools API

It's fragmented. You build tools for one system, and they don't work anywhere else. Want your weather tool to work with Claude AND GPT? Build it twice. Want it to work with your custom agent framework? Build it again.

This is the same problem we had before HTTP, before USB, before REST. Proprietary protocols everywhere, with everyone reinventing the wheel.

MCP solves this with a standard protocol. Build once, use everywhere. But "solving a real problem" isn't enough — plenty of good protocols have failed. Let's look at what actually makes standards win.

## What makes standards stick

Looking at history, successful standards share common traits:

### 1. Backed by a major player

HTTP had CERN, then the W3C. JSON had Douglas Crockford and eventually ECMA. USB had Intel leading a consortium of hardware manufacturers. TCP/IP had DARPA and the US government.

Counter-examples: XMPP had Google backing... until they didn't. Google Talk dropped it. Wave used it until Wave died. Jabber faded.

MCP has Anthropic. Not the biggest player in AI (that's OpenAI), but credible and growing. More importantly, they've open-sourced it — not keeping it proprietary. This is crucial. Proprietary protocols face an uphill battle because competitors won't adopt them.

Anthropic isn't trying to lock people in. The spec is public. Anyone can implement an MCP server. That's the right move for standardization.

### 2. Simple enough to implement

REST won partly because it's simple — it's just HTTP with conventions. SOAP was more "correct" but required XML schemas, WSDL files, envelope wrapping, and specialized tooling. REST won.

GraphQL is technically superior in many ways, but it's complex. You need schema definitions, resolvers, query parsers. Adoption has been slower than REST despite GraphQL solving real problems.

MCP hits the sweet spot:
- JSON-RPC over stdio or SSE (both well-understood transports)
- Three core methods: `initialize`, `tools/list`, `tools/call`
- Clear JSON schema for tool definitions
- No complex type systems or query languages

You can implement a basic MCP server in an afternoon. I've seen developers go from "what's MCP?" to a working server in under an hour. That's the simplicity threshold you need for adoption.

Compare that to building a GraphQL server from scratch, or implementing SOAP. MCP is closer to REST in implementation effort.

### 3. Solves a pain point

Nobody adopts standards for fun. They adopt them because the alternative is worse.

Right now, connecting AI to tools is painful:
- Custom integrations for each AI provider (OpenAI format is different from Claude format)
- No standard way to discover tools at runtime
- Duplicate work across projects
- Different authentication mechanisms for each provider
- No consistent error handling
- Fragmented documentation across implementations

Every time you add a new AI provider to your app, you rewrite your tool integrations. Every time you switch frameworks, you rebuild your tools.

MCP eliminates this. One protocol, all AI agents. One tool definition, works everywhere. That's a real reduction in development overhead — and developers will adopt things that save them work.

USB didn't win because it was technically perfect. It won because carrying six different chargers was annoying.

### 4. Network effects

The more tools use MCP, the more valuable it becomes. The more AI agents support MCP, the more tools get built. This is the flywheel that makes or breaks a standard.

Consider why PDF won: once enough people had PDF readers, everyone started publishing PDFs. Once everyone published PDFs, you had to support PDF. Self-reinforcing.

MCP has the same dynamic:
- AI providers add MCP support → developers build MCP tools
- More tools exist → more providers add support
- More providers support it → it becomes the default

We're early in this cycle, but the flywheel is starting to spin. The question is whether it spins fast enough before alternatives gain traction.

## Who's adopting it

The adoption picture is evolving quickly.

**AI providers:**
- Claude: Native support in Claude Desktop, API, and Claude Code
- Cursor: IDE integration for AI-assisted coding
- Zed: Code editor with MCP support
- Continue: VS Code extension for AI coding
- Cline: Another VS Code AI assistant
- More IDEs and AI tools adding support

**Tool builders:**
- Growing ecosystem of MCP servers (databases, file systems, APIs)
- Open source implementations in multiple languages (TypeScript, Python, Go, Rust)
- Companies building MCP integrations for their services
- Frameworks adding MCP server capabilities

**Developers:**
- Building local MCP servers for personal automation
- Wrapping existing REST APIs as MCP tools
- Sharing configurations and tool definitions
- Creating company-internal MCP servers for internal tools

**The infrastructure layer:**
- Relay services like [Gantz](https://gantz.run) for exposing local servers
- MCP registries and discovery services emerging
- Hosting platforms considering MCP support

It's not mainstream yet. Most developers haven't heard of MCP. But in the AI tooling space, adoption is accelerating. The early signs are promising.

## The competition

MCP isn't the only option. Let's look at what it's up against.

**OpenAI function calling:** Already widely used — probably the most common approach today. OpenAI has massive market share and their function calling format is well-documented. But it's OpenAI-specific. You can't take your OpenAI function definitions and run them with Claude or a local model without translation. And it doesn't include the discovery mechanism MCP has.

**LangChain tools:** Popular in the Python ecosystem. If you're building AI apps in Python, you've probably used LangChain tools. But it's tied to the LangChain framework. If you're not using LangChain, these tools don't help you.

**LlamaIndex tools:** Similar to LangChain — great within the LlamaIndex ecosystem, but framework-specific.

**Custom protocols:** Every company rolling their own tool format. Works for internal use, but not interoperable. You end up maintaining translation layers.

**OpenAPI/Swagger:** Some teams use OpenAPI specs to generate tool definitions. This can work but requires additional tooling and doesn't include MCP's streaming or resource capabilities.

MCP's advantage: it's not tied to one vendor or framework. It's designed to be universal. You can implement MCP in any language, for any AI provider that supports it. That's the bet Anthropic is making.

## What could go wrong

Let's be realistic about the risks. Standards fail all the time.

### OpenAI makes their own standard

The biggest threat. If OpenAI releases a competing protocol with better tooling, documentation, and marketing muscle, MCP could lose momentum fast.

OpenAI has the market share. If they say "this is how you do AI tools," most developers will follow. And OpenAI has a history of setting de facto standards through adoption rather than formal standardization.

The counter-argument: OpenAI tends to build closed ecosystems optimized for their platform. A truly open, vendor-neutral standard might win in the long run — especially as the AI market becomes more competitive and developers resist lock-in.

### Fragmentation

The VHS vs Betamax scenario. What if different AI providers adopt different protocols?

- OpenAI sticks with their function calling format
- Anthropic pushes MCP
- Google develops yet another approach
- Open source models use something else

Developers would need to support multiple protocols. Translation layers everywhere. The dream of "build once, use everywhere" dies.

This is a real risk. History shows fragmentation can persist for years (see: messaging protocols, smart home standards, payment APIs).

### Complexity creep

Standards can die from feature bloat. Every new capability sounds reasonable in isolation, but eventually you end up with SOAP — technically capable but too complex for most use cases.

MCP currently has tools, resources, prompts, and sampling capabilities. That's already more than tools alone. If each version adds more features, implementation burden grows. New developers look at the spec and think "this is too much."

So far, MCP is staying reasonably simple. The core (tools/list, tools/call) is straightforward. The hope is it stays that way.

### Nobody uses it

Worst case: MCP stays niche. Only used by Claude power users, never reaches critical mass. The flywheel never spins up.

This happens to plenty of good standards. They solve real problems but never achieve the adoption needed for network effects.

However, given the current momentum in the AI tooling space and the genuine pain of fragmentation, this seems less likely. The question is more about timing and competition than whether there's demand.

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

## Related reading

- [Where does MCP fit in your stack?](/post/mcp-in-stack/) - Architecture deep-dive
- [MCP vs Function Calling](/post/mcp-vs-function-calling/) - When to use each
- [Why every dev will run an MCP server](/post/why-every-dev-mcp/) - The future of development

---

*Betting on MCP? Or waiting to see how it plays out? I'm curious what others think.*
