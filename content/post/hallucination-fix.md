+++
title = "One Prompt Change That Stopped My Agent Hallucinating"
date = 2025-12-19
description = "Stop AI agents from making up information. One prompt technique forces tool use instead of hallucination when agents lack knowledge."
summary = "My agent was confident, articulate, and completely wrong. The fix was simple: add one line to the system prompt telling the agent 'when you don't know something, use your tools to find out instead of guessing.' This forces tool use over hallucination - the agent will search, query, or ask rather than make things up."
image = "images/agent-electric-sparks.webp"
draft = false
tags = ['prompting', 'best-practices', 'debugging']
voice = false
+++


My agent was confident. Articulate. Completely wrong.

```text
User: "What's in config.json?"

Agent: "Based on your config.json, you have:
- Database: PostgreSQL on port 5432
- Cache: Redis on port 6379
- API key: starts with 'sk-'"

User: "...I don't have a config.json"
```

It made up an entire file. Convincingly.

One prompt change fixed it.

## The problem

My agent would hallucinate when it should have used tools.

```text
User: "How many lines in main.py?"

Agent: "main.py has approximately 150 lines of code."

# Reality: main.py has 47 lines. Agent never read it.
```

```text
User: "What tests are failing?"

Agent: "Looking at your test suite, it appears the
authentication tests are failing, specifically
test_login_invalid_password and test_session_timeout."

# Reality: No tests are failing. Agent never ran them.
```

The agent was answering from imagination instead of observation.

## Why this happens

LLMs are trained on patterns. They've seen millions of config files, test suites, and codebases.

When you ask "What's in config.json?", the model thinks:

> "Config files usually have database settings, API keys, ports...
> I'll describe a typical config file."

It's not lying. It's pattern-matching. But for an agent, pattern-matching without verification is hallucination.

## The fix

I added one line to my system prompt:

```python
# Before
SYSTEM_PROMPT = """
You are a helpful coding assistant with access to file and shell tools.
"""

# After
SYSTEM_PROMPT = """
You are a helpful coding assistant with access to file and shell tools.

IMPORTANT: Never state facts about files, code, or system state without
first using a tool to verify. If asked about a file, read it first.
If asked about tests, run them first. Never guess.
"""
```

That's it. One rule: **verify before stating**.

## The results

Before:

```text
User: "What's in config.json?"
Agent: "Based on your config.json..." (hallucinated)
```

After:

```text
User: "What's in config.json?"
Agent: 🔧 read_file({"path": "config.json"})
"config.json contains:
{
  'debug': true,
  'port': 3000
}
That's all - just debug mode and port settings."
```

Before:

```text
User: "How many lines in main.py?"
Agent: "main.py has approximately 150 lines." (wrong)
```

After:

```text
User: "How many lines in main.py?"
Agent: 🔧 run_command({"command": "wc -l main.py"})
"main.py has 47 lines."
```

Before:

```text
User: "Are the tests passing?"
Agent: "The authentication tests appear to be failing..." (made up)
```

After:

```text
User: "Are the tests passing?"
Agent: 🔧 run_command({"command": "npm test"})
"All 23 tests pass. No failures."
```

## Why it works

The prompt creates a mental checkpoint:

```text
Without the rule:
  Question → Pattern match → Answer (often wrong)

With the rule:
  Question → "Do I need to verify?" → Yes → Use tool → Answer (correct)
```

The model pauses before answering. That pause makes it reach for tools instead of imagination.

## Making it stronger

The basic rule works. These variations make it bulletproof:

### Variation 1: Explicit examples

```python
SYSTEM_PROMPT = """
You are a coding assistant with file and shell access.

NEVER state facts about the codebase without verifying first:
- Asked about a file? Read it.
- Asked about tests? Run them.
- Asked about git status? Check it.
- Asked about errors? Look at logs.

Don't say "I think" or "probably" or "typically". Verify and know.
"""
```

### Variation 2: Call out the failure mode

```python
SYSTEM_PROMPT = """
You are a coding assistant with file and shell access.

WARNING: You have a tendency to guess about file contents and system
state based on common patterns. This leads to confidently wrong answers.

Before stating ANY fact about:
- File contents → read the file
- Test results → run the tests
- System state → check with a command
- Dependencies → check package.json/requirements.txt

If you catch yourself about to say something without tool verification,
stop and use a tool instead.
"""
```

### Variation 3: The "show your work" approach

```python
SYSTEM_PROMPT = """
You are a coding assistant with file and shell access.

Always show your work:
1. State what you need to find out
2. Use a tool to find it
3. Report what the tool showed

Never skip step 2. No exceptions.
"""
```

## Common hallucination triggers

Watch out for these - they tempt the model to guess:

### "What's in...?"

```text
User: "What's in the .env file?"

Bad:  "Typically, .env contains DATABASE_URL, API_KEY..."
Good: 🔧 read_file({".env"}) → actual contents
```

### "How many...?"

```text
User: "How many tests do we have?"

Bad:  "Based on the test structure, approximately 50 tests..."
Good: 🔧 run_command({"find . -name '*.test.js' | wc -l"}) → actual count
```

### "Is/Are...?"

```text
User: "Is the server running?"

Bad:  "The server should be running on port 3000..."
Good: 🔧 run_command({"curl localhost:3000/health"}) → actual status
```

### "Why is...?"

```text
User: "Why is the build failing?"

Bad:  "Build failures are often caused by syntax errors or..."
Good: 🔧 run_command({"npm run build 2>&1 | tail -50"}) → actual error
```

### "What version...?"

```text
User: "What version of React are we using?"

Bad:  "Based on modern practices, probably React 18..."
Good: 🔧 read_file({"package.json"}) → actual version
```

## The before/after pattern

Train yourself to recognize the pattern:

```text
❌ Hallucination pattern:
   User asks → Agent answers from knowledge → Wrong

✅ Verification pattern:
   User asks → Agent uses tool → Agent answers from tool output → Correct
```

Every answer about the current codebase should follow the tool first.

## What about common knowledge?

The rule applies to **facts about the current codebase/system**. General knowledge is fine:

```text
# This is fine - general knowledge
User: "What's the difference between let and const?"
Agent: "let allows reassignment, const doesn't..." (no tool needed)

# This needs verification - specific to this codebase
User: "Do we use let or const in this project?"
Agent: 🔧 search({"query": "\\blet\\b|\\bconst\\b"})
"The codebase uses const 234 times and let 12 times."
```

## Handling "I don't know"

Sometimes the tool reveals the answer doesn't exist:

```text
User: "What's in config.json?"

Agent: 🔧 read_file({"path": "config.json"})
# Tool returns: "Error: File not found"

Agent: "There is no config.json in the current directory.
Would you like me to create one, or are you looking for
a different config file?"
```

This is correct behavior. "File doesn't exist" is better than making up contents.

## Implementation with Gantz

Using [Gantz](https://gantz.run), the system prompt enforces verification:

```yaml
# gantz.yaml
system: |
  You are a coding assistant.

  RULE: Never state facts about files, code, or system state without
  using a tool first. When asked about something, verify it.

  You have these tools:
  - read: Read file contents
  - search: Search for text in files
  - run: Run shell commands

  Use them before answering questions about the codebase.

tools:
  - name: read
    description: Read a file. Use this before stating anything about file contents.
    parameters:
      - name: path
        type: string
        required: true
    script:
      shell: cat "{{path}}"

  - name: search
    description: Search files. Use this to find code before making claims about it.
    parameters:
      - name: query
        type: string
        required: true
    script:
      shell: rg "{{query}}" . --max-count=20

  - name: run
    description: Run a command. Use this to check system state.
    parameters:
      - name: command
        type: string
        required: true
    script:
      shell: "{{command}}"
```

The descriptions reinforce when to use each tool.

## Testing for hallucinations

Try these prompts to test if your agent hallucinates:

```text
# Should trigger tool use, not guessing
"What's in package.json?"
"How many files are in src/?"
"What does the main function do?"
"Are there any TODO comments?"
"What port does the server run on?"

# If the agent answers without using a tool, it's hallucinating
```

Watch for phrases that indicate guessing:

- "Typically..."
- "Usually..."
- "Based on common patterns..."
- "I would expect..."
- "Probably..."

These mean the model is about to hallucinate.

## Summary

The hallucination fix:

```python
# Add this to your system prompt
"""
Never state facts about files, code, or system state
without first using a tool to verify.
"""
```

That's it. One rule.

Before this rule:
- Agent guesses from patterns
- Confident but wrong
- User loses trust

After this rule:
- Agent verifies with tools
- Accurate answers
- User trusts the agent

Stop guessing. Start verifying.

The tools are there. Use them. Every time your agent guesses instead of checking, you're risking user trust. And trust, once lost, is hard to rebuild.

Give your agent the tools to verify. Make verification the default behavior. Your users will thank you.

## Related reading

- [Writing Tool Descriptions That Work](/post/tool-descriptions/) - Help AI use tools correctly
- [Debugging Agent Thoughts](/post/debugging-thoughts/) - Understanding agent behavior
- [The Reflection Pattern](/post/reflection-pattern/) - Teaching agents to verify

---

*What's the worst thing your agent confidently made up?*
