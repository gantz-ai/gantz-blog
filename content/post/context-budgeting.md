+++
title = "Context Window Budgeting for Multi-Turn Agents"
date = 2025-12-26
image = "/images/agent-arctic-white.png"
draft = false
tags = ['agents', 'ai', 'mcp']
+++


Your context window is a budget. Every turn, you spend some. Eventually, you run out.

Most developers don't think about this until it's too late.

## The problem

```
Turn 1:  System prompt (2K) + User message (100) = 2,100 tokens
Turn 2:  + Response (500) + User (100) + Response (400) = 3,100 tokens
Turn 3:  + Tool call (200) + Tool result (2K) = 5,300 tokens
Turn 4:  + Response (600) + User (150) = 6,050 tokens
...
Turn 15: 47,000 tokens = 💥 Context limit exceeded
```

Each turn adds to the pile. It never shrinks automatically.

## Know your limits

| Model | Context Window | Practical Limit* |
|-------|---------------|------------------|
| GPT-4o | 128K | ~100K |
| Claude 3.5 Sonnet | 200K | ~150K |
| GPT-4 Turbo | 128K | ~100K |
| Llama 3.1 70B | 128K | ~100K |
| Mixtral | 32K | ~25K |

*Leave headroom for response generation

## The budget framework

Think of your context as a budget with categories:

```
┌─────────────────────────────────────────────────────┐
│              CONTEXT BUDGET: 100K tokens            │
├─────────────────────────────────────────────────────┤
│                                                     │
│  ┌─────────────────┐  Fixed costs (always present)  │
│  │ System Prompt   │  5-10K                         │
│  │ Tool Definitions│  2-5K                          │
│  └─────────────────┘                                │
│                                                     │
│  ┌─────────────────┐  Variable costs (grows)        │
│  │ Conversation    │  10-30K                        │
│  │ Tool Results    │  10-50K                        │
│  │ Working Memory  │  5-10K                         │
│  └─────────────────┘                                │
│                                                     │
│  ┌─────────────────┐  Reserved                      │
│  │ Response Space  │  4-8K                          │
│  └─────────────────┘                                │
│                                                     │
└─────────────────────────────────────────────────────┘
```

## Category 1: Fixed costs

These are always in your context. Optimize once, benefit always.

### System prompt

```python
# Before: 3,847 tokens
SYSTEM_PROMPT = """
You are a helpful AI assistant designed to help users with their tasks.
You have access to various tools that allow you to interact with external
systems. When responding to users, you should be helpful, harmless, and
honest. Always think step by step before taking action. If you're unsure
about something, ask for clarification rather than making assumptions.
You should format your responses in a clear and readable manner using
markdown when appropriate. Remember to be concise but thorough...
[500 more words of fluff]
"""

# After: 847 tokens
SYSTEM_PROMPT = """
You are a coding assistant with access to file and database tools.

Rules:
- Read before editing
- Test after changes
- Ask if requirements unclear

Output: Use markdown. Be concise.
"""
```

### Tool definitions

```python
# Before: 500 tokens per tool × 20 tools = 10,000 tokens
tools = [
    {
        "name": "search_files",
        "description": "This tool allows you to search through files in the filesystem...",
        "parameters": {
            "query": {
                "type": "string",
                "description": "The search query to use when searching..."
            }
        }
    },
    # ... 19 more verbose tools
]

# After: 150 tokens per tool × 20 tools = 3,000 tokens
tools = [
    {
        "name": "search",
        "description": "Search files by content. Returns matching lines.",
        "parameters": {
            "query": {"type": "string"}
        }
    },
    # ... 19 more concise tools
]
```

## Category 2: Conversation history

This grows every turn. You need a management strategy.

### Strategy 1: Sliding window

Keep only the last N messages.

```python
class SlidingWindowContext:
    def __init__(self, max_messages=20):
        self.messages = []
        self.max_messages = max_messages

    def add(self, message):
        self.messages.append(message)
        if len(self.messages) > self.max_messages:
            self.messages.pop(0)  # Remove oldest
```

**Problem**: Loses early context. User says their name in turn 1, agent forgets by turn 25.

### Strategy 2: Sliding window + summary

Summarize old messages before dropping.

```python
class SummarizingContext:
    def __init__(self, max_messages=20, summary_threshold=30):
        self.messages = []
        self.summary = ""
        self.max_messages = max_messages

    def add(self, message):
        self.messages.append(message)

        if len(self.messages) > self.max_messages + 10:
            # Summarize oldest messages
            to_summarize = self.messages[:10]
            self.summary = self.update_summary(to_summarize)
            self.messages = self.messages[10:]

    def get_context(self):
        context = []
        if self.summary:
            context.append({
                "role": "system",
                "content": f"Previous conversation summary:\n{self.summary}"
            })
        context.extend(self.messages)
        return context

    def update_summary(self, messages):
        response = fast_llm.create(
            messages=[{
                "role": "user",
                "content": f"Summarize this conversation, keeping key facts:\n\n"
                          f"Previous summary: {self.summary}\n\n"
                          f"New messages: {messages}"
            }]
        )
        return response.content
```

### Strategy 3: Importance-based retention

Keep important messages, drop filler.

```python
class ImportanceBasedContext:
    def __init__(self, max_tokens=30000):
        self.messages = []
        self.max_tokens = max_tokens

    def add(self, message, importance="normal"):
        self.messages.append({
            **message,
            "importance": importance,
            "timestamp": time.time()
        })
        self.prune()

    def prune(self):
        while self.count_tokens() > self.max_tokens:
            # Find least important, oldest message
            candidates = [m for m in self.messages if m["importance"] == "low"]
            if not candidates:
                candidates = [m for m in self.messages if m["importance"] == "normal"]
            if not candidates:
                break  # Only high importance left

            oldest = min(candidates, key=lambda m: m["timestamp"])
            self.messages.remove(oldest)

    def mark_important(self, message_id):
        for m in self.messages:
            if m.get("id") == message_id:
                m["importance"] = "high"
```

## Category 3: Tool results

Often the biggest budget killer.

### Budget per tool call

```python
class BudgetedToolExecutor:
    def __init__(self, max_result_tokens=2000):
        self.max_result_tokens = max_result_tokens

    def execute(self, tool_call):
        result = self.tools.call(tool_call.name, tool_call.params)

        # Check size
        result_tokens = count_tokens(result)

        if result_tokens > self.max_result_tokens:
            result = self.truncate(result, self.max_result_tokens)

        return result

    def truncate(self, result, max_tokens):
        # Smart truncation based on content type
        if self.looks_like_json(result):
            return self.truncate_json(result, max_tokens)
        else:
            return self.truncate_text(result, max_tokens)
```

### Summarize large results

```python
def process_tool_result(result, max_tokens=2000):
    result_tokens = count_tokens(result)

    if result_tokens <= max_tokens:
        return result

    # Summarize instead
    summary = fast_llm.create(
        messages=[{
            "role": "user",
            "content": f"Summarize this tool output concisely:\n\n{result[:50000]}"
        }]
    ).content

    return f"[Summarized from {result_tokens} tokens]\n{summary}"
```

### Compress after using

```python
class CompressingContext:
    def add_tool_result(self, tool_name, result):
        # Add full result
        self.messages.append({
            "role": "tool",
            "content": result
        })

        # After agent processes it, compress
        if self.should_compress(result):
            compressed = self.compress_result(tool_name, result)
            # Replace full result with compressed version
            self.messages[-1]["content"] = compressed

    def compress_result(self, tool_name, result):
        return fast_llm.create(
            messages=[{
                "role": "user",
                "content": f"Extract key information from this {tool_name} result:\n{result}"
            }]
        ).content
```

## Category 4: Working memory

Facts and state the agent needs to remember.

### Separate from conversation

```python
class AgentWithMemory:
    def __init__(self):
        self.conversation = []  # Chat history
        self.memory = {}        # Key facts (compact)

    def remember(self, key, value):
        self.memory[key] = value

    def build_context(self):
        # Memory is always included, compactly
        memory_str = "\n".join(f"- {k}: {v}" for k, v in self.memory.items())

        return [
            {"role": "system", "content": self.system_prompt},
            {"role": "system", "content": f"Known facts:\n{memory_str}"},
            *self.conversation[-20:]  # Last 20 messages
        ]
```

### Auto-extract facts

```python
def extract_and_remember(self, message):
    # Extract facts worth remembering
    extraction = llm.create(
        messages=[{
            "role": "user",
            "content": f"""Extract key facts from this message that should be remembered:

{message}

Return as JSON: {{"key": "value"}} or empty object if nothing worth remembering."""
        }]
    ).content

    facts = json.loads(extraction)
    for key, value in facts.items():
        self.memory[key] = value
```

## Token counting

You can't budget what you don't measure.

```python
import tiktoken

def count_tokens(text, model="gpt-4"):
    encoder = tiktoken.encoding_for_model(model)
    return len(encoder.encode(text))

def count_message_tokens(messages, model="gpt-4"):
    total = 0
    for message in messages:
        total += count_tokens(message.get("content", ""), model)
        total += 4  # Message overhead
    return total

class TokenBudget:
    def __init__(self, limit=100000, reserve=8000):
        self.limit = limit
        self.reserve = reserve
        self.available = limit - reserve

    def check(self, messages):
        used = count_message_tokens(messages)
        remaining = self.available - used

        return {
            "used": used,
            "remaining": remaining,
            "percent_used": (used / self.available) * 100,
            "warning": remaining < 10000
        }
```

## Real-time budget display

Show token usage in logs:

```python
def log_budget(context, budget):
    status = budget.check(context.messages)

    bar_length = 40
    filled = int(bar_length * status["percent_used"] / 100)
    bar = "█" * filled + "░" * (bar_length - filled)

    print(f"Context: [{bar}] {status['percent_used']:.1f}%")
    print(f"         {status['used']:,} / {budget.available:,} tokens")

    if status["warning"]:
        print("⚠️  Context running low!")
```

Output:
```
Context: [████████████████░░░░░░░░░░░░░░░░░░░░░░░░] 42.3%
         42,300 / 100,000 tokens
```

## Budget-aware agent

Putting it all together:

```python
class BudgetAwareAgent:
    def __init__(self, llm, tools, budget_limit=100000):
        self.llm = llm
        self.tools = BudgetedToolExecutor(max_result_tokens=3000)
        self.context = SummarizingContext(max_messages=30)
        self.memory = {}
        self.budget = TokenBudget(limit=budget_limit)

    def run(self, user_message):
        self.context.add({"role": "user", "content": user_message})

        while True:
            # Check budget
            status = self.budget.check(self.build_messages())
            if status["warning"]:
                self.compress_context()

            # Get response
            response = self.llm.create(
                messages=self.build_messages(),
                tools=self.tools.definitions
            )

            if response.tool_call:
                result = self.tools.execute(response.tool_call)
                self.context.add({"role": "tool", "content": result})
            else:
                self.context.add({"role": "assistant", "content": response.content})
                return response.content

    def compress_context(self):
        # Emergency compression
        self.context.force_summarize()
        self.compress_tool_results()

    def build_messages(self):
        memory_str = "\n".join(f"- {k}: {v}" for k, v in self.memory.items())
        return [
            {"role": "system", "content": self.system_prompt},
            {"role": "system", "content": f"Context:\n{memory_str}"},
            *self.context.get_context()
        ]
```

## MCP integration

Use [Gantz](https://gantz.run) with budget-aware tools:

```yaml
# gantz.yaml
tools:
  - name: search
    description: Search files. Max 50 results to save context.
    parameters:
      - name: query
        type: string
    script:
      shell: rg --json "{{query}}" . | head -50

  - name: read_file
    description: Read file. Large files return summary + snippet.
    parameters:
      - name: path
        type: string
    script:
      shell: |
        size=$(wc -c < "{{path}}")
        if [ $size -gt 10000 ]; then
          echo "[File: {{path}}, Size: $size bytes]"
          echo "First 100 lines:"
          head -100 "{{path}}"
          echo "..."
          echo "Last 20 lines:"
          tail -20 "{{path}}"
        else
          cat "{{path}}"
        fi
```

## Summary

Budget your context like money:

| Category | Budget | Strategy |
|----------|--------|----------|
| System prompt | 5-10% | Optimize once, keep lean |
| Tool definitions | 2-5% | Concise descriptions |
| Conversation | 20-40% | Sliding window + summaries |
| Tool results | 20-40% | Truncate, summarize |
| Memory | 5-10% | Key facts only |
| Response reserve | 5-10% | Always keep headroom |

Measure constantly. Compress proactively. Don't wait for overflow.

---

*How do you manage context in your multi-turn agents?*
