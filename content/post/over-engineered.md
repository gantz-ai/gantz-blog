+++
title = "I Over-Engineered My Agent (Here's What I Learned)"
date = 2025-12-05
image = "/images/robot-billboard-05.png"
draft = false
tags = ['best-practices', 'architecture', 'patterns']
+++


I spent 3 months building the perfect agent architecture.

It had everything:
- Multi-tier memory system
- Hierarchical planning
- Self-reflection loops
- Multi-agent coordination
- Custom embedding pipeline
- Sophisticated error recovery

It was beautiful.

Users hated it.

Here's what went wrong.

## The vision

I was building a coding assistant. My architecture looked like this:

```
┌─────────────────────────────────────────────────────────────┐
│                    ORCHESTRATOR AGENT                        │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐          │
│  │   PLANNER   │  │  EXECUTOR   │  │  REVIEWER   │          │
│  │    AGENT    │──│    AGENT    │──│    AGENT    │          │
│  └─────────────┘  └─────────────┘  └─────────────┘          │
│         │                │                │                  │
│         ▼                ▼                ▼                  │
│  ┌─────────────────────────────────────────────────┐        │
│  │              SHARED MEMORY SYSTEM                │        │
│  │  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌───────┐  │        │
│  │  │ Working │ │ Episodic│ │Semantic │ │ Long  │  │        │
│  │  │ Memory  │ │ Memory  │ │ Memory  │ │ Term  │  │        │
│  │  └─────────┘ └─────────┘ └─────────┘ └───────┘  │        │
│  └─────────────────────────────────────────────────┘        │
│                           │                                  │
│         ┌─────────────────┴─────────────────┐               │
│         ▼                                   ▼               │
│  ┌─────────────┐                    ┌─────────────┐         │
│  │    TOOLS    │                    │  REFLECTION │         │
│  │   (15 MCP)  │                    │    MODULE   │         │
│  └─────────────┘                    └─────────────┘         │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

Impressive, right?

## What I built

### Multi-agent system

Three specialized agents:

```python
class PlannerAgent:
    """Creates detailed execution plans"""
    def plan(self, task):
        return self.llm.create(
            system="You are a planning specialist...",
            messages=[{"role": "user", "content": f"Plan: {task}"}]
        )

class ExecutorAgent:
    """Executes individual steps"""
    def execute(self, step, tools):
        return self.llm.create(
            system="You are an execution specialist...",
            tools=tools,
            messages=[{"role": "user", "content": f"Execute: {step}"}]
        )

class ReviewerAgent:
    """Reviews and critiques work"""
    def review(self, work):
        return self.llm.create(
            system="You are a code review specialist...",
            messages=[{"role": "user", "content": f"Review: {work}"}]
        )
```

### Four-tier memory

```python
class MemorySystem:
    def __init__(self):
        self.working = WorkingMemory()      # Current task
        self.episodic = EpisodicMemory()    # Past conversations
        self.semantic = SemanticMemory()    # Learned facts (vector DB)
        self.long_term = LongTermMemory()   # Persistent storage
```

### Reflection loop

```python
def execute_with_reflection(self, task):
    for attempt in range(3):
        result = self.executor.execute(task)

        reflection = self.reflector.reflect(result)

        if reflection.is_good:
            return result

        task = self.improve_task(task, reflection.feedback)

    return result
```

### 15 specialized tools

```yaml
tools:
  - read_file
  - read_file_range
  - write_file
  - patch_file
  - search_content
  - search_files
  - search_symbols
  - run_command
  - run_tests
  - lint_code
  - format_code
  - git_status
  - git_diff
  - git_commit
  - analyze_dependencies
```

## The problems

### Problem 1: It was slow

```
User: "Add a print statement to main.py"

My agent:
1. Planner analyzes task (2s)
2. Creates 5-step plan (3s)
3. Executor reads file (1s)
4. Executor makes change (2s)
5. Reviewer checks work (3s)
6. Reflection evaluates (2s)
7. Memory updates (1s)

Total: 14 seconds

Simple agent:
1. Read file (0.5s)
2. Make change (1s)

Total: 1.5 seconds
```

14 seconds for a one-line change. Users didn't wait.

### Problem 2: It was expensive

```
Simple request token usage:

Planner: 2,000 tokens
Executor: 1,500 tokens
Reviewer: 1,800 tokens
Reflection: 1,200 tokens
Memory queries: 800 tokens
Orchestration: 500 tokens

Total: 7,800 tokens

vs.

Simple agent: 1,200 tokens
```

6x more expensive. For the same result.

### Problem 3: It was fragile

```python
# Things that broke regularly:

# Planner and Executor disagreed on format
PlannerOutput: {"steps": ["read", "modify", "save"]}
ExecutorExpected: {"step": "read", "params": {...}}

# Memory retrieval returned irrelevant context
Query: "How to add logging?"
Retrieved: "User prefers dark mode" (from 3 weeks ago)

# Reflection loop got stuck
Reflection: "Code could be better"
Attempt 2: Same code
Reflection: "Code could be better"
Attempt 3: Same code
```

### Problem 4: It was unpredictable

```
Same request, different runs:

Run 1: Planner creates 3 steps
Run 2: Planner creates 7 steps
Run 3: Planner creates 1 step (skips planning)

Run 1: Reviewer approves
Run 2: Reviewer requests changes
Run 3: Reviewer gets confused about what to review
```

Users couldn't trust it.

### Problem 5: It was impossible to debug

```
User: "Why did it delete my file?"

Me: "Let me check..."
- Orchestrator logs: "Delegated to executor"
- Planner logs: "Step 3: clean up"
- Executor logs: "Executed: delete temp files"
- Memory logs: "Retrieved: user likes clean workspaces"
- Reflection logs: "Approved cleanup"

Me: "Uh... multiple agents agreed it was a good idea?"
```

No single point of responsibility.

## The rewrite

I threw it all away. Started over with this:

```python
class SimpleAgent:
    def __init__(self, llm, tools):
        self.llm = llm
        self.tools = tools
        self.messages = []

    def run(self, user_input):
        self.messages.append({"role": "user", "content": user_input})

        while True:
            response = self.llm.create(
                messages=self.messages,
                tools=self.tools
            )

            if response.tool_call:
                result = self.execute_tool(response.tool_call)
                self.messages.append({"role": "tool", "content": result})
            else:
                self.messages.append({"role": "assistant", "content": response.content})
                return response.content

    def execute_tool(self, tool_call):
        return self.tools.call(tool_call.name, tool_call.params)
```

50 lines. No planner. No reviewer. No reflection. No multi-tier memory.

### The tools

```yaml
# From 15 to 4
tools:
  - name: read
    description: Read a file
  - name: write
    description: Write to a file
  - name: search
    description: Search in files
  - name: run
    description: Run a command
```

### The result

```
Same request: "Add a print statement to main.py"

Simple agent:
1. Read file (0.5s)
2. Write file (1s)

Total: 1.5 seconds
Tokens: 1,200
Success rate: 95%
```

## What I learned

### Lesson 1: Start with the simplest thing

```python
# Week 1: This
response = llm.create(messages + [user_input])

# Week 2: Add tools if needed
response = llm.create(messages + [user_input], tools=basic_tools)

# Week 3+: Add complexity only when you hit real limits
```

Not:

```python
# Week 1: Build the perfect architecture
orchestrator = Orchestrator(
    planner=PlannerAgent(),
    executor=ExecutorAgent(),
    reviewer=ReviewerAgent(),
    memory=FourTierMemory(),
    reflection=ReflectionModule()
)
```

### Lesson 2: Multi-agent is usually wrong

Multi-agent sounds cool. In practice:

```
Single agent:
- One context
- One decision maker
- Clear responsibility
- Easy to debug

Multi-agent:
- Context passing overhead
- Coordination bugs
- Blame diffusion
- Debugging nightmare
```

Use multi-agent when you have genuinely different capabilities that can't share context. That's rare.

### Lesson 3: Memory is a premature optimization

```python
# What I built
memory = VectorDB() + EpisodicStore() + FactDatabase() + WorkingMemory()

# What I needed
messages = []  # That's it. Conversation history.
```

Add memory when users complain about forgetting. Not before.

### Lesson 4: Reflection loops are token burners

```python
# What I thought
"Self-reflection will catch errors and improve quality!"

# What happened
Agent: *does thing*
Reflector: "Could be better"
Agent: *does same thing slightly differently*
Reflector: "Could be better"
Agent: *does same thing again*
# 3x the tokens, same result
```

Reflection works in research papers. In production, it mostly burns money.

### Lesson 5: More tools = more confusion

```yaml
# With 15 tools
AI: "Should I use search_content or search_files or search_symbols?"
AI: "Should I use write_file or patch_file?"
AI: *picks wrong one*

# With 4 tools
AI: "I need to search" → uses search
AI: "I need to write" → uses write
```

Fewer tools = clearer decisions.

### Lesson 6: Speed matters more than intelligence

```
User preference:

Fast + slightly wrong → "I can fix that, thanks!"
Slow + perfect → "Is it frozen? *closes tab*"
```

Users will tolerate imperfection. They won't tolerate waiting.

## The new philosophy

```
Before:
"How do I make my agent smarter?"

After:
"How do I make my agent simpler?"
```

### Simple tools with Gantz

Now I use [Gantz](https://gantz.run) with minimal tools:

```yaml
# gantz.yaml
tools:
  - name: read
    script:
      shell: cat "{{path}}"

  - name: write
    script:
      shell: echo "{{content}}" > "{{path}}"

  - name: search
    script:
      shell: rg "{{query}}" . | head -30

  - name: run
    script:
      shell: "{{command}}"
```

Four tools. Covers 95% of coding tasks.

### When I add complexity now

Only when I have evidence:

```
"Users are asking the same questions repeatedly"
→ Maybe add memory

"Simple search isn't finding relevant content"
→ Maybe add better retrieval

"Tasks require genuine coordination"
→ Maybe add another agent
```

Not because it's cool. Because users need it.

## Summary

What I over-engineered:
- Multi-agent coordination (didn't need it)
- Four-tier memory (conversation history was enough)
- Reflection loops (burned tokens)
- 15 specialized tools (4 was enough)
- Hierarchical planning (overkill for most tasks)

What I learned:
- Start with the simplest thing that works
- Add complexity only when you hit real limits
- Speed beats intelligence
- One agent beats three
- Users don't care about architecture

The best agent is the one that gets out of the way.

---

*Have you over-engineered an agent? What did you cut?*
