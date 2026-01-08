+++
title = "Why every dev will run an MCP server"
date = 2025-11-17
description = "Prediction: MCP servers will be as common as local dev servers. Learn why Model Context Protocol is becoming essential for AI-powered development workflows."
summary = "MCP servers will become as common as local dev servers. Instead of copy-pasting data into ChatGPT, you'll run a local MCP server that gives AI direct access to your database, codebase, and internal tools - all while keeping sensitive data on your machine. The killer feature isn't raw capability, it's keeping your data private while getting AI's help."
image = "images/agent-misc-01.webp"
draft = false
tags = ['mcp', 'architecture', 'deep-dive']
voice = true

[[faqs]]
question = "What is MCP (Model Context Protocol)?"
answer = "MCP is a standard protocol that lets AI connect to tool servers. Instead of copy-pasting between AI and your apps, AI connects to your MCP server and uses tools directly - querying databases, running scripts, calling APIs."

[[faqs]]
question = "Is running an MCP server a security risk?"
answer = "You control what tools you expose. MCP can be read-only with no access to production. It's actually more secure than copy-pasting sensitive data into web chats because your data stays on your machine."

[[faqs]]
question = "Is MCP hard to set up?"
answer = "No. With tools like Gantz, you write a YAML config and run one command. Your MCP server is live. No complex deployment or code maintenance required."

[[faqs]]
question = "Why use MCP instead of cloud AI tools?"
answer = "Your data stays local. Your database has real user data, your codebase has proprietary code, your logs have sensitive info. MCP lets AI access all of this without uploading anything to the cloud."
+++


Hot take: In a couple years, running an MCP server will be as normal as running a local dev server.

This isn't wishful thinking. It's following the pattern of how developer tools evolve. We went from FTP to local servers. From manual deployments to Docker. From copy-pasting code to AI assistants.

The next step is obvious: AI that can actually interact with your tools, not just talk about them.

Let me explain.

## The shift that's happening

Right now, when you want AI to do something useful, you copy-paste. Context into ChatGPT. Output back to your app. Rinse, repeat.

It works. But it's manual. And AI can't actually *do* anything - it can only talk.

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

**Phase 2 (soon):** Standard tools emerge. MCP servers for Postgres, Redis, GitHub, Slack - plug and play.

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
- A tool that runs your test suite

Here's a minimal setup to try today:

```yaml
# gantz.yaml
name: dev-tools
description: My local development tools

tools:
  - name: search_code
    description: Search codebase for a pattern
    parameters:
      - name: pattern
        type: string
        required: true
    script:
      shell: grep -r "{{pattern}}" ./src --include="*.ts" | head -20

  - name: git_status
    description: Check git status and recent commits
    script:
      shell: |
        echo "=== Status ==="
        git status --short
        echo ""
        echo "=== Recent Commits ==="
        git log --oneline -5

  - name: run_tests
    description: Run the test suite
    script:
      shell: npm test
      timeout: 120s

  - name: query_db
    description: Run a read-only query on dev database
    parameters:
      - name: query
        type: string
        required: true
    script:
      shell: psql -d myapp_dev -c "{{query}}"
```

```bash
gantz run
```

That's it. Now Claude can search your code, check git status, run tests, and query your database.

Tools like [Gantz](https://gantz.run) let you spin up an MCP server in one command - define tools in YAML, run `gantz run`, and you're live.

Once you have AI that can actually see your world, you won't go back to copy-paste.

## The comparison to past shifts

Think about how Docker changed things:

**Before Docker:**
- "It works on my machine"
- Complex setup docs
- Environment drift
- Works different in prod

**After Docker:**
- Consistent environments
- One command to run anything
- Share setups easily
- Infrastructure as code

MCP is doing the same for AI:

**Before MCP:**
- Copy-paste context to AI
- AI can only suggest, not do
- No access to your actual tools
- Generic advice, not specific help

**After MCP:**
- AI directly accesses your tools
- AI can query, test, check
- Context-aware assistance
- Personalized to your setup

Same shift. Different layer of the stack.

The developers who adopt MCP early will have a significant advantage. Their AI tools will be context-aware. Their workflows will be more efficient. They'll iterate faster.

The rest will catch up eventually. They always do.

## Related reading

- [What is MCP and Where Does it Fit in Your Stack?](/post/mcp-in-stack/) - Architecture deep-dive
- [Will MCP Become the Standard?](/post/mcp-standard/) - The future of MCP adoption
- [MCP vs ReAct: Protocol vs Pattern](/post/mcp-vs-react/) - Understanding the layers

---

*Running an MCP server yet? What tools would you expose first?*
