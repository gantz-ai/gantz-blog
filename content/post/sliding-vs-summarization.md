+++
title = "The Sliding Window vs Summarization Trade-off"
date = 2025-11-24
image = "images/warrior-rain-city-07.png"
draft = false
tags = ['memory', 'patterns', 'comparison']
+++


Your context is full. You need to drop something.

Two options: slide the window or summarize.

Both have costs. Here's how to choose.

## The problem

```
Turn 1:   "My name is Alice, I work on the payments team"
Turn 2:   "Can you help me debug the checkout flow?"
Turn 3:   [tool call: read checkout.js]
Turn 4:   "I see the issue, it's in the validation"
...
Turn 30:  Context is 95% full
Turn 31:  Need to make room
```

What do you drop?

## Option 1: Sliding window

Keep the last N messages. Drop everything older.

```
Before (30 messages):
[1] [2] [3] [4] [5] ... [26] [27] [28] [29] [30]

After sliding (keep last 20):
                [11] [12] ... [26] [27] [28] [29] [30]

Dropped: Messages 1-10
```

### Implementation

```python
class SlidingWindow:
    def __init__(self, max_messages=20):
        self.messages = []
        self.max_messages = max_messages

    def add(self, message):
        self.messages.append(message)
        if len(self.messages) > self.max_messages:
            self.messages = self.messages[-self.max_messages:]

    def get_context(self):
        return self.messages
```

### What you gain

**Speed**: O(1) operation. Just slice the list.

```python
# Instant, no API calls
self.messages = self.messages[-20:]
```

**Predictability**: Always same size. No surprises.

```python
# Context size is bounded
assert len(context.messages) <= 20
```

**Simplicity**: No LLM calls. No prompts. No failure modes.

**Cost**: Zero additional tokens.

### What you lose

**Early context**: First messages disappear.

```
Turn 1: "My name is Alice"        ← GONE
Turn 2: "I'm on the payments team" ← GONE
...
Turn 25: "What's my name again?"
Agent: "I don't know your name"   ← Oops
```

**Important setup**: Key instructions vanish.

```
Turn 1: "Always respond in French" ← GONE
...
Turn 25: [Agent responds in English]
```

**Accumulated knowledge**: Facts learned early are lost.

```
Turn 3: [Reads config file]        ← GONE
Turn 5: [User explains architecture] ← GONE
...
Turn 25: Agent asks same questions again
```

## Option 2: Summarization

Compress old messages into a summary. Keep recent messages verbatim.

```
Before:
[msg1] [msg2] [msg3] ... [msg28] [msg29] [msg30]

After summarizing:
[SUMMARY of msgs 1-20] [msg21] [msg22] ... [msg30]
```

### Implementation

```python
class SummarizingContext:
    def __init__(self, keep_recent=10, summarize_threshold=20):
        self.messages = []
        self.summary = ""
        self.keep_recent = keep_recent
        self.summarize_threshold = summarize_threshold

    def add(self, message):
        self.messages.append(message)

        if len(self.messages) > self.summarize_threshold:
            self.compress()

    def compress(self):
        to_summarize = self.messages[:-self.keep_recent]
        to_keep = self.messages[-self.keep_recent:]

        # Summarize old messages
        new_summary = self.create_summary(to_summarize)

        # Update state
        if self.summary:
            self.summary = f"{self.summary}\n\n{new_summary}"
        else:
            self.summary = new_summary

        self.messages = to_keep

    def create_summary(self, messages):
        messages_text = "\n".join([
            f"{m['role']}: {m['content'][:500]}"
            for m in messages
        ])

        response = llm.create(
            model="gpt-4o-mini",  # Fast, cheap model
            messages=[{
                "role": "user",
                "content": f"""Summarize this conversation, preserving:
- Key facts (names, preferences, decisions)
- Important context (what was discussed, what was decided)
- Any instructions or requirements mentioned

Conversation:
{messages_text}

Summary:"""
            }]
        )
        return response.content

    def get_context(self):
        context = []
        if self.summary:
            context.append({
                "role": "system",
                "content": f"Previous conversation summary:\n{self.summary}"
            })
        context.extend(self.messages)
        return context
```

### What you gain

**Preserved knowledge**: Key facts survive.

```
Summary: "User is Alice from payments team. Debugging checkout flow.
         Found validation issue in checkout.js line 47."

Turn 25: "What team am I on?"
Agent: "You're on the payments team"  ← Remembered!
```

**Accumulated context**: Learning compounds.

```
Summary includes:
- User preferences discovered
- Decisions made
- Problems solved
- Architecture understood
```

**Better continuity**: Conversation feels coherent.

### What you lose

**Latency**: LLM call to summarize.

```python
# 500ms - 2s per summarization
summary = llm.create(...)
```

**Cost**: Tokens to generate summary.

```
Summarizing 10 messages: ~500 input tokens + ~200 output tokens
At $0.01/1K tokens: ~$0.007 per summarization
```

**Accuracy**: Summarizer might miss things.

```
# Important detail in message 5
"Make sure to use UTC timestamps, not local time"

# Summarizer misses it
Summary: "User discussed timestamp handling"  ← Lost the UTC detail!
```

**Complexity**: More failure modes.

```python
# What if summarization fails?
try:
    summary = llm.create(...)
except APIError:
    # Fall back to sliding window?
    # Retry?
    # Keep full context temporarily?
```

## The trade-off matrix

| Factor | Sliding Window | Summarization |
|--------|---------------|---------------|
| Speed | ✓ Instant | Slow (LLM call) |
| Cost | ✓ Free | Costs tokens |
| Simplicity | ✓ Simple | Complex |
| Knowledge retention | Poor | ✓ Better |
| Accuracy | ✓ Perfect (recent) | May lose details |
| Continuity | Abrupt | ✓ Smooth |
| Failure modes | ✓ None | Several |

## When to use sliding window

**Short tasks**: User will complete within window.

```python
# Task typically takes 5-10 turns
# Window of 20 is plenty
context = SlidingWindow(max_messages=20)
```

**Stateless interactions**: Each turn is independent.

```python
# Q&A bot - each question stands alone
# No need to remember previous questions
```

**High-throughput**: Need speed, can't afford LLM latency.

```python
# Processing 1000 requests/minute
# Can't add 1s latency for summarization
```

**Budget-constrained**: Every token counts.

```python
# Free tier, limited API budget
# Can't afford summarization overhead
```

## When to use summarization

**Long sessions**: Conversations span many turns.

```python
# Coding session: 50+ turns over hours
# Must remember early context
context = SummarizingContext(keep_recent=15)
```

**Personalization**: User identity matters.

```python
# Personal assistant
# Must remember: name, preferences, past interactions
```

**Complex tasks**: Building on previous work.

```python
# Multi-step project
# Each step depends on previous decisions
```

**Knowledge accumulation**: Learning throughout conversation.

```python
# Onboarding agent that learns your codebase
# Must retain discovered information
```

## Hybrid approaches

### Approach 1: Tiered retention

Recent: verbatim. Medium: summarized. Old: key facts only.

```python
class TieredContext:
    def __init__(self):
        self.key_facts = {}           # Permanent
        self.summary = ""             # Compressed old
        self.recent = []              # Last 10 verbatim

    def get_context(self):
        facts = "\n".join(f"- {k}: {v}" for k, v in self.key_facts.items())
        return [
            {"role": "system", "content": f"Key facts:\n{facts}"},
            {"role": "system", "content": f"Previous context:\n{self.summary}"},
            *self.recent
        ]
```

### Approach 2: Smart sliding

Slide, but protect important messages.

```python
class SmartSlidingWindow:
    def __init__(self, max_messages=20):
        self.messages = []
        self.protected = []  # Never dropped
        self.max_messages = max_messages

    def add(self, message, protect=False):
        if protect:
            self.protected.append(message)
        else:
            self.messages.append(message)
            if len(self.messages) > self.max_messages:
                self.messages.pop(0)

    def get_context(self):
        return self.protected + self.messages
```

### Approach 3: On-demand summarization

Only summarize when explicitly needed.

```python
class OnDemandSummarizing:
    def __init__(self, max_tokens=50000):
        self.messages = []
        self.max_tokens = max_tokens

    def add(self, message):
        self.messages.append(message)

        # Only summarize when approaching limit
        if self.count_tokens() > self.max_tokens * 0.9:
            self.compress()

    def compress(self):
        # Keep last 10, summarize rest
        to_summarize = self.messages[:-10]
        summary = self.create_summary(to_summarize)

        self.messages = [
            {"role": "system", "content": f"Summary:\n{summary}"}
        ] + self.messages[-10:]
```

### Approach 4: Extract-then-slide

Extract key facts, then slide.

```python
class ExtractAndSlide:
    def __init__(self, max_messages=20):
        self.messages = []
        self.facts = {}
        self.max_messages = max_messages

    def add(self, message):
        self.messages.append(message)

        # Extract facts from all messages
        self.extract_facts(message)

        # Slide normally
        if len(self.messages) > self.max_messages:
            self.messages.pop(0)

    def extract_facts(self, message):
        # Fast extraction (could use regex or small model)
        if "my name is" in message["content"].lower():
            # Extract name
            ...
        if "i work on" in message["content"].lower():
            # Extract team
            ...

    def get_context(self):
        facts_str = "\n".join(f"- {k}: {v}" for k, v in self.facts.items())
        return [
            {"role": "system", "content": f"Known facts:\n{facts_str}"},
            *self.messages
        ]
```

## Decision flowchart

```
                    Start
                      │
                      ▼
         ┌──────────────────────┐
         │ Session > 20 turns?  │
         └──────────┬───────────┘
                    │
          ┌─────────┴─────────┐
          │                   │
         No                  Yes
          │                   │
          ▼                   ▼
    ┌──────────┐    ┌─────────────────┐
    │ Sliding  │    │ Need to remember │
    │ Window   │    │ early context?   │
    └──────────┘    └────────┬────────┘
                             │
                   ┌─────────┴─────────┐
                   │                   │
                  No                  Yes
                   │                   │
                   ▼                   ▼
             ┌──────────┐      ┌─────────────┐
             │ Sliding  │      │ Can afford  │
             │ Window   │      │ latency?    │
             └──────────┘      └──────┬──────┘
                                      │
                            ┌─────────┴─────────┐
                            │                   │
                           No                  Yes
                            │                   │
                            ▼                   ▼
                     ┌────────────┐      ┌─────────────┐
                     │ Extract +  │      │ Summarize   │
                     │ Slide      │      │             │
                     └────────────┘      └─────────────┘
```

## Practical example with Gantz

Using [Gantz](https://gantz.run) tools with managed context:

```python
class AgentWithManagedContext:
    def __init__(self, mcp_client):
        self.mcp = mcp_client

        # Hybrid: facts + summarization + recent
        self.facts = {}
        self.summary = ""
        self.recent = []

    def run(self, user_input):
        self.recent.append({"role": "user", "content": user_input})

        # Check if compression needed
        if len(self.recent) > 25:
            self.compress()

        # Build context
        context = self.build_context()

        # Run agent loop
        response = self.agent_loop(context)

        self.recent.append({"role": "assistant", "content": response})
        return response

    def compress(self):
        # Extract facts from old messages
        for msg in self.recent[:-10]:
            self.extract_facts(msg)

        # Summarize old messages
        old_messages = self.recent[:-10]
        new_summary = summarize(old_messages)

        if self.summary:
            self.summary = f"{self.summary}\n\n{new_summary}"
        else:
            self.summary = new_summary

        # Keep only recent
        self.recent = self.recent[-10:]

    def build_context(self):
        parts = []

        if self.facts:
            facts_str = "\n".join(f"- {k}: {v}" for k, v in self.facts.items())
            parts.append({"role": "system", "content": f"Known facts:\n{facts_str}"})

        if self.summary:
            parts.append({"role": "system", "content": f"Context:\n{self.summary}"})

        parts.extend(self.recent)
        return parts
```

## Summary

**Sliding window**:
- Fast, free, simple
- Loses early context
- Best for: short tasks, stateless, high-throughput

**Summarization**:
- Preserves knowledge
- Costs latency and tokens
- Best for: long sessions, personalization, complex tasks

**Hybrid** (usually best):
- Extract key facts permanently
- Summarize medium-old context
- Keep recent verbatim

There's no perfect answer. Match your strategy to your use case.

---

*Which approach do you use for context management?*
