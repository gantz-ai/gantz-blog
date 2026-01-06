+++
title = "Prompt Engineering vs Agent Engineering"
date = 2025-12-02
description = "Prompt engineering crafts inputs. Agent engineering builds systems. Learn how these disciplines differ and where they overlap in AI development."
image = "images/agent-neon-04.webp"
draft = false
tags = ['prompting', 'architecture', 'comparison']
voice = false
+++


Two years ago, everyone was a "prompt engineer." Now everyone's building "AI agents."

Are these the same thing? No. But they're related.

Let me break down the difference.

## Prompt Engineering: Talking to AI

Prompt engineering is about crafting the right input to get the right output.

```
Bad prompt:
"Write a summary"

Better prompt:
"Summarize this article in 3 bullet points, focusing on key takeaways for developers"

Even better:
"You are a technical writer. Summarize this article in 3 bullet points.
Focus on: practical takeaways, code implications, and gotchas.
Keep each point under 20 words."
```

Prompt engineering is a **single turn**. You write input, AI gives output. Done.

Skills involved:
- Clear instructions
- Context setting
- Output formatting
- Few-shot examples
- Role assignment

## Agent Engineering: Building AI systems

Agent engineering is about designing systems where AI makes decisions and takes actions over multiple steps.

```
User: "Find bugs in my codebase and fix them"

Agent:
1. Thinks: "I need to first understand the codebase structure"
2. Acts: [calls list_files tool]
3. Thinks: "Let me run the tests to find failures"
4. Acts: [calls run_tests tool]
5. Observes: "3 tests failing in auth module"
6. Thinks: "Let me look at the auth code"
7. Acts: [calls read_file tool]
8. Thinks: "Found the bug - wrong comparison operator"
9. Acts: [calls edit_file tool]
10. Acts: [calls run_tests tool]
11. Observes: "All tests passing"
12. Responds: "Fixed 3 bugs in the auth module..."
```

Agent engineering is **multi-turn**. AI reasons, acts, observes, repeats.

Skills involved:
- System architecture
- Tool design
- State management
- Error handling
- Orchestration logic
- Memory systems

## The difference

| | Prompt Engineering | Agent Engineering |
|---|---|---|
| Scope | Single interaction | Multiple steps |
| AI role | Responder | Actor |
| Output | Text | Actions + Text |
| Complexity | Low-medium | Medium-high |
| Skills | Writing, psychology | Programming, architecture |

**Prompt Engineering** = What you say to AI
**Agent Engineering** = What AI can do

## When you're prompt engineering

You're prompt engineering when:

### Writing system prompts

```
You are a helpful coding assistant.
- Always explain your reasoning
- Use Python unless specified otherwise
- Include error handling in code examples
```

### Crafting user messages

```
Review this code for security issues.
Focus on: SQL injection, XSS, and authentication bypasses.
Format: bullet list with severity ratings.
```

### Few-shot examples

```
Convert to JSON:
Input: "John, 25, NYC"
Output: {"name": "John", "age": 25, "city": "NYC"}

Input: "Sarah, 30, LA"
Output: {"name": "Sarah", "age": 30, "city": "LA"}

Input: "Mike, 28, Chicago"
Output:
```

### Output formatting

```
Return your response as valid JSON:
{
  "summary": "...",
  "sentiment": "positive|negative|neutral",
  "confidence": 0.0-1.0
}
```

This is all prompt engineering. Single turn. Text in, text out.

## When you're agent engineering

You're agent engineering when:

### Designing tool systems

```yaml
tools:
  - name: search_codebase
    description: Search for code patterns
    parameters:
      - name: query
        type: string
        required: true

  - name: run_tests
    description: Execute test suite
    parameters:
      - name: path
        type: string
        default: "."
```

### Building orchestration logic

```python
while not task_complete:
    thought = agent.think(context)

    if thought.needs_tool:
        result = execute_tool(thought.tool_call)
        context.add_observation(result)

    if thought.has_answer:
        task_complete = True
```

### Managing state and memory

```python
class AgentMemory:
    def __init__(self):
        self.conversation = []
        self.tool_results = []
        self.learned_facts = {}

    def add_observation(self, obs):
        self.tool_results.append(obs)
        self.extract_facts(obs)
```

### Handling errors and retries

```python
def safe_tool_call(tool, params, max_retries=3):
    for attempt in range(max_retries):
        try:
            return tool.execute(params)
        except ToolError as e:
            if attempt == max_retries - 1:
                return f"Tool failed: {e}"
            context.add(f"Tool failed, retrying: {e}")
```

This is agent engineering. Multi-turn. Decisions and actions.

## They build on each other

Agent engineering doesn't replace prompt engineering. It includes it.

```
Agent Engineering
├── System design
├── Tool architecture
├── Orchestration logic
├── Memory management
├── Error handling
└── Prompt Engineering  ← Still needed!
    ├── System prompts
    ├── Tool descriptions
    ├── Reasoning prompts
    └── Output formatting
```

Good agents need good prompts. The prompts tell AI:
- How to think ("reason step by step")
- When to use tools ("use search when you need information")
- How to format output ("respond in JSON")
- What persona to adopt ("you are a senior developer")

## The evolution

Most people follow this path:

**Stage 1: Basic prompting**
```
"Summarize this text"
```

**Stage 2: Better prompting**
```
"You are an expert summarizer. Create a 3-point summary focusing on..."
```

**Stage 3: Structured output**
```
"Return JSON with fields: summary, key_points, action_items"
```

**Stage 4: Single tool use**
```
AI can call one tool to get data, then respond
```

**Stage 5: Multi-step agents**
```
AI reasons through problems, uses multiple tools, handles errors
```

**Stage 6: Complex agent systems**
```
Multiple agents, planning, reflection, memory, human-in-the-loop
```

Stages 1-3 are prompt engineering. Stages 4-6 are agent engineering.

## Different skills

### Prompt engineering skills

- **Writing clearly** — Unambiguous instructions
- **Understanding AI** — What models can/can't do
- **Iteration** — Testing and refining prompts
- **Psychology** — How to frame requests
- **Domain knowledge** — Subject matter expertise

### Agent engineering skills

- **System design** — Architecture decisions
- **Programming** — Building the orchestration
- **API design** — Creating good tool interfaces
- **Error handling** — Graceful failures
- **State management** — Memory and context
- **Security** — Safe tool execution

## What you need for each

### Prompt engineering toolkit

- Playground (Claude, ChatGPT)
- Version control for prompts
- Evaluation framework
- A/B testing

### Agent engineering toolkit

- Framework (LangChain, custom)
- MCP server ([Gantz](https://gantz.run))
- Tool definitions
- Monitoring/logging
- Testing harness

## Common mistakes

### Mistake 1: Over-engineering prompts

When you need an agent, no prompt will fix it.

```
# Won't work no matter how good the prompt
"Check my calendar and if I'm free tomorrow at 3pm,
schedule a meeting with John and send him an email"

# This needs tools, not better prompts
```

### Mistake 2: Under-engineering prompts in agents

Agents still need good prompts.

```
# Bad agent system prompt
"You are an assistant."

# Good agent system prompt
"You are a developer assistant with access to code tools.
Think step by step before acting.
Always verify changes by running tests.
If something fails, try a different approach."
```

### Mistake 3: Agents for everything

Sometimes a good prompt is enough.

```
# Doesn't need to be an agent
"Translate this to French"

# A simple API call works
response = claude.messages.create(
    messages=[{"role": "user", "content": f"Translate to French: {text}"}]
)
```

## When to use what

**Use prompt engineering when:**
- Single-turn interaction
- No external data needed
- No actions required
- Simple transformations
- Content generation

**Use agent engineering when:**
- Multi-step tasks
- External tools needed
- Real-world actions
- Dynamic decision making
- Complex workflows

**Use both when:**
- Always. Agents need good prompts.

## The future

Prompt engineering isn't going away. But agent engineering is where the leverage is.

Good prompts make AI 2x better.
Good agents make AI 10x more capable.

If you only know prompt engineering, you're limited to what AI can do in one turn.

If you know agent engineering, you can build AI that actually does things in the world.

## Related reading

- [Writing Tool Descriptions That Work](/post/tool-descriptions/) - Prompt engineering for tools
- [The Meta-Prompting Pattern](/post/meta-prompting/) - Advanced prompting
- [Your First AI Agent in 15 Minutes](/post/first-agent/) - Getting started

---

*Are you more of a prompt engineer or agent engineer? Where do you spend most of your time?*
