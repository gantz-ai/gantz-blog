+++
title = "Why every dev will run an MCP server"
date = 2025-11-17
image = "/images/agent-misc-01.png"
draft = false
tags = ['agents', 'ai', 'mcp']
+++


Hot take: In a couple years, running an MCP server will be as normal as running a local dev server.

Let me explain.

## The shift that's happening

Right now, when you want AI to do something useful, you copy-paste. Context into ChatGPT. Output back to your app. Rinse, repeat.

It works. But it's manual. And AI can't actually *do* anything — it can only talk.

MCP changes that. It gives AI hands.

## What MCP actually is

MCP (Model Context Protocol) is a standard way for AI to call tools. Instead of:

```
You → ChatGPT → Copy answer → Do the thing yourself
```

It's:

```
You → AI → MCP Server → Thing gets done
```

The AI connects to your server, discovers what tools are available, and uses them.

Query a database. Run a script. Call an API. Read a file. Whatever you expose.

## Why this matters for developers

### 1. Your local environment becomes AI-accessible

Right now, Claude can't see your code. It can't query your dev database. It can't run your tests. It can't check your logs.

With MCP, it can. You expose tools that run locally, and AI uses them.

```yaml
tools:
  - name: query_dev_db
    script:
      shell: psql -d myapp_dev -c "{{query}}"

  - name: run_tests
    script:
      shell: npm test

  - name: check_logs
    script:
      shell: tail -100 /var/log/myapp.log
```

Now you can say "check if any tests are failing" and it actually checks.

### 2. No more building one-off integrations

Before MCP, giving AI access to something meant:
- Building a custom integration
- Handling auth, errors, retries
- Maintaining it forever

With MCP, you write a YAML config. Or a small script. That's it.

Want Claude to access your Postgres? Five lines of config.
Want it to call your internal API? Ten lines.
Want it to run shell commands? Already built-in.

### 3. AI becomes context-aware

The biggest limitation of AI today is context. It doesn't know your codebase. It doesn't know your data. It doesn't know your setup.

MCP fixes this. AI can:
- Search your codebase
- Read your docs
- Query your data
- Check your environment

It goes from "generic assistant" to "assistant that knows your stuff."

### 4. Tools are composable

Once you have MCP tools, they work with any AI that supports the protocol.

- Claude
- GPT (with MCP support)
- Gemini
- Local models
- Your own agents

Write once, use everywhere.

## The tipping point

Here's what I think will happen:

**Phase 1 (now):** Early adopters build MCP servers for specific use cases. Local databases, internal tools, dev workflows.

**Phase 2 (soon):** Standard tools emerge. MCP servers for Postgres, Redis, GitHub, Slack — plug and play.

**Phase 3 (inevitable):** Every developer has an MCP server running. It's part of the dev environment, like Docker or a local server.

Your `.mcp.yaml` becomes as common as your `.env`.

## Why local matters

You might ask: why not just use cloud AI tools?

Because your data shouldn't leave your machine.

- Your database has real user data
- Your codebase has proprietary code
- Your logs have sensitive info
- Your notes have private thoughts

MCP lets AI access all of this without uploading anything. The AI connects to your local server. Your data stays on your machine.

## What this looks like day-to-day

Morning standup:
```
"What did I work on yesterday?"
→ AI checks git commits, time tracker, notes
```

Debugging:
```
"Why is this endpoint slow?"
→ AI queries logs, checks DB performance, profiles code
```

Code review:
```
"Anything concerning in this PR?"
→ AI reads diff, checks for patterns, runs tests
```

Writing:
```
"Draft a doc for this feature based on my notes"
→ AI searches notes, reads code, generates doc
```

You're not copy-pasting. You're not switching tabs. You're just talking to an AI that has access to your tools.

## The objections

**"Isn't this a security risk?"**

You control what tools you expose. Read-only? Fine. No access to production? Easy. Auth required? Built-in.

It's actually more secure than copy-pasting sensitive data into a web chat.

**"I don't want AI doing things automatically"**

Then don't let it. Many MCP setups are read-only. AI can search, but not modify.

Or add confirmation steps. AI proposes, you approve.

**"Setting this up sounds complicated"**

It's a YAML file and one command:

```bash
gantz run
```

That's it. You have an MCP server.

**"What if the AI makes mistakes?"**

Same as any tool. You review the output. Start with low-risk stuff (reading logs, searching code). Build trust before automation.

## Where we're headed

I think MCP (or something like it) becomes infrastructure.

Just like you run:
- A local server for your app
- Docker for your services
- A database for your data

You'll run:
- An MCP server for your AI tools

It's the interface between your stuff and AI.

## Start now

You don't have to wait. MCP works today. The protocol is stable. The tools exist.

Start simple:
- A tool that searches your codebase
- A tool that queries your dev database
- A tool that reads your notes

Tools like [Gantz](https://gantz.run) let you spin up an MCP server in one command — define tools in YAML, run `gantz run`, and you're live.

Once you have AI that can actually see your world, you won't go back to copy-paste.

---

*Running an MCP server yet? What tools would you expose first?*
