+++
title = "Why Agents Get Stuck in Loops (And How to Prevent It)"
date = 2026-01-04
image = "images/agent-neon-standing.webp"
draft = false
tags = ['patterns', 'debugging', 'architecture']
+++


You've seen it. The agent tries something. Fails. Tries the exact same thing. Fails again. Repeats forever.

Loops are the most common agent failure mode.

Here's why they happen and how to stop them.

## What a loop looks like

```
User: "Find the config file"

Agent:
[1] search("config")
    → No results
[2] search("config")
    → No results
[3] search("config")
    → No results
[4] search("config")
    → No results
... forever
```

The agent doesn't learn. It just keeps trying the same thing.

## Why loops happen

### Reason 1: No memory of failures

Agents don't automatically remember what didn't work.

```
Agent thinks: "I should search for config"
Agent searches: No results
Agent thinks: "I should search for config"  ← Forgot it just failed
Agent searches: No results
...
```

Each step, the agent reasons from scratch. Without explicit failure memory, it reaches the same conclusion.

### Reason 2: No alternative strategies

The agent only knows one approach.

```
User: "Get the user's email"

Agent knows: query_database tool
Agent tries: query_database → Database offline
Agent tries: query_database → Database offline
Agent tries: query_database → Database offline

Agent doesn't know: check_cache, call_api, ask_user
```

One tool. One strategy. When it fails, there's nothing else to try.

### Reason 3: Unclear success criteria

The agent doesn't know when it's done.

```
User: "Improve this code"

Agent:
[1] Refactors function A
[2] Refactors function B
[3] Refactors function A again (could be better!)
[4] Refactors function B again (could be better!)
[5] Refactors function A again...
```

Without clear "done" criteria, improvement is infinite.

### Reason 4: Oscillating states

Agent bounces between two states.

```
Agent: Adds feature X
Tests fail
Agent: Removes feature X
Tests pass
Agent: Adds feature X (user asked for it!)
Tests fail
Agent: Removes feature X
...
```

The agent is trying to satisfy conflicting constraints.

### Reason 5: Tool returns same error

The tool keeps failing the same way, agent keeps retrying.

```
Agent: send_email("invalid@")
Tool: "Invalid email format"
Agent: send_email("invalid@")  ← Didn't fix the input
Tool: "Invalid email format"
...
```

Agent doesn't understand the error or how to fix it.

## Detection strategies

### Strategy 1: Action history tracking

Track recent actions, detect repetition.

```python
class LoopDetector:
    def __init__(self, window=5, threshold=3):
        self.history = []
        self.window = window
        self.threshold = threshold

    def record(self, action):
        # Hash the action for comparison
        action_hash = hash(str(action))
        self.history.append(action_hash)

        # Keep only recent history
        if len(self.history) > self.window * 2:
            self.history = self.history[-self.window * 2:]

    def is_looping(self):
        if len(self.history) < self.threshold:
            return False

        recent = self.history[-self.threshold:]
        # Check if all recent actions are the same
        if len(set(recent)) == 1:
            return True

        # Check for oscillation (A-B-A-B pattern)
        if len(self.history) >= 4:
            pattern = self.history[-4:]
            if pattern[0] == pattern[2] and pattern[1] == pattern[3]:
                return True

        return False
```

### Strategy 2: Result comparison

Compare tool results. Same result = potential loop.

```python
class ResultTracker:
    def __init__(self):
        self.results = []

    def record(self, tool_name, result):
        result_hash = hash(str(result))
        self.results.append({
            "tool": tool_name,
            "result_hash": result_hash
        })

    def is_stuck(self, n=3):
        if len(self.results) < n:
            return False

        recent = self.results[-n:]
        # Same tool, same result, n times
        tools = set(r["tool"] for r in recent)
        results = set(r["result_hash"] for r in recent)

        return len(tools) == 1 and len(results) == 1
```

### Strategy 3: Progress tracking

Define progress metrics, detect stagnation.

```python
class ProgressTracker:
    def __init__(self):
        self.checkpoints = []

    def checkpoint(self, state):
        self.checkpoints.append({
            "timestamp": time.time(),
            "state_hash": hash(str(state))
        })

    def is_stagnant(self, duration=60):
        if len(self.checkpoints) < 2:
            return False

        recent = [c for c in self.checkpoints
                  if time.time() - c["timestamp"] < duration]

        if len(recent) < 2:
            return False

        # All states the same in the duration
        states = set(c["state_hash"] for c in recent)
        return len(states) == 1
```

## Prevention strategies

### Strategy 1: Explicit failure memory

Tell the agent what didn't work.

```python
def execute_with_memory(agent, task):
    failures = []

    while not done:
        # Include failures in context
        context = f"""
Task: {task}

Previous failed attempts:
{format_failures(failures)}

Try a DIFFERENT approach than the ones listed above.
"""

        action = agent.decide(context)
        result = execute(action)

        if not result.success:
            failures.append({
                "action": action,
                "error": result.error
            })

            if len(failures) > 5:
                return "Unable to complete after 5 different attempts"
```

### Strategy 2: Force diversity

Require different actions after failures.

```python
def execute_diverse(agent, task, max_attempts=5):
    attempted_actions = set()

    for attempt in range(max_attempts):
        action = agent.decide(task)
        action_sig = signature(action)  # Normalize action

        # Reject if we've tried this before
        if action_sig in attempted_actions:
            agent.feedback(
                "You've already tried this. Suggest something different."
            )
            continue

        attempted_actions.add(action_sig)
        result = execute(action)

        if result.success:
            return result

    return "Exhausted all unique approaches"
```

### Strategy 3: Alternative injection

Suggest alternatives when stuck.

```python
def execute_with_alternatives(agent, task):
    failures = []

    while not done:
        action = agent.decide(task)
        result = execute(action)

        if not result.success:
            failures.append(action)

            if len(failures) >= 2:
                # Inject alternatives
                alternatives = get_alternative_approaches(task, failures)
                agent.feedback(f"""
Your approach isn't working. Consider these alternatives:
{alternatives}

Pick one of these or explain why none will work.
""")
```

### Strategy 4: Escalation

Give up and ask for help.

```python
def execute_with_escalation(agent, task, max_loops=3):
    loop_detector = LoopDetector()

    while not done:
        action = agent.decide(task)
        loop_detector.record(action)

        if loop_detector.is_looping():
            return ask_user(
                f"I'm stuck on this task. I've tried:\n"
                f"{format_attempts(loop_detector.history)}\n\n"
                f"Can you suggest a different approach?"
            )

        result = execute(action)

        if result.success:
            return result
```

### Strategy 5: Step limits

Hard cap on iterations.

```python
def execute_with_limit(agent, task, max_steps=20):
    for step in range(max_steps):
        action = agent.decide(task)
        result = execute(action)

        if result.type == "answer":
            return result

        if step == max_steps - 1:
            return {
                "status": "incomplete",
                "message": f"Reached {max_steps} step limit",
                "partial_result": agent.get_partial_result()
            }
```

## Breaking specific loop types

### Breaking "same action" loops

```python
BREAK_SAME_ACTION = """
You've tried "{action}" {count} times with the same result.

This approach is not working. You must try something different:
1. Use a different tool
2. Use different parameters
3. Try a different strategy entirely

Do NOT try "{action}" again.
"""
```

### Breaking oscillation loops

```python
BREAK_OSCILLATION = """
You're oscillating between two actions:
- {action_a}
- {action_b}

This suggests conflicting requirements. Before continuing:
1. Identify what conflict is causing this
2. Ask the user to clarify which approach they prefer
3. Or find a third option that satisfies both constraints
"""
```

### Breaking "no progress" loops

```python
BREAK_NO_PROGRESS = """
You've been working on this for {duration} without making progress.

Current state: {state}
Steps taken: {step_count}

Options:
1. Simplify the task - what's the minimum viable solution?
2. Ask for help - what specific information would unblock you?
3. Skip and note - mark this as blocked and move on
"""
```

## MCP tools for loop prevention

Build loop-aware tools with [Gantz](https://gantz.run):

```yaml
# gantz.yaml
tools:
  - name: search_with_memory
    description: |
      Search with automatic deduplication.
      Remembers previous searches in this session.
      Rejects duplicate queries, suggests alternatives.
    parameters:
      - name: query
        type: string
        required: true
    script:
      shell: |
        # Check if we've searched this before
        CACHE_FILE="/tmp/search_history_$$"

        if grep -Fxq "{{query}}" "$CACHE_FILE" 2>/dev/null; then
          echo '{"error": "Already searched for this. Try different terms.", "suggestions": ["Try broader terms", "Try synonyms", "Check spelling"]}'
          exit 0
        fi

        # Record this search
        echo "{{query}}" >> "$CACHE_FILE"

        # Perform actual search
        rg --json "{{query}}" . || echo '{"results": [], "suggestion": "No results. Try different search terms."}'

  - name: execute_unique
    description: |
      Execute a command, but only if it hasn't been run this session.
      Prevents duplicate operations.
    parameters:
      - name: command
        type: string
        required: true
    script:
      shell: |
        CMD_HASH=$(echo "{{command}}" | md5sum | cut -d' ' -f1)
        HISTORY_FILE="/tmp/cmd_history_$$"

        if grep -q "$CMD_HASH" "$HISTORY_FILE" 2>/dev/null; then
          echo '{"error": "This command was already run. Check previous results instead."}'
          exit 0
        fi

        echo "$CMD_HASH" >> "$HISTORY_FILE"
        {{command}}
```

## System prompt additions

Add loop awareness to your agent's system prompt:

```python
LOOP_AWARE_PROMPT = """
## Avoiding Loops

Before each action, ask yourself:
1. Have I tried this exact action before?
2. Did it work last time? If not, why would it work now?
3. What's different about this attempt?

If you catch yourself repeating:
- STOP and acknowledge you're stuck
- List what you've tried
- Either try something genuinely different OR ask for help

Never repeat the same action more than twice without changing your approach.
"""
```

## Monitoring and alerting

Track loop metrics in production:

```python
class LoopMetrics:
    def __init__(self):
        self.sessions = {}

    def record_action(self, session_id, action):
        if session_id not in self.sessions:
            self.sessions[session_id] = []

        self.sessions[session_id].append({
            "action": action,
            "timestamp": time.time()
        })

        # Check for loops
        if self.detect_loop(session_id):
            self.alert(session_id, "Loop detected")

    def get_stats(self):
        return {
            "total_sessions": len(self.sessions),
            "loops_detected": self.count_loops(),
            "avg_actions_per_session": self.avg_actions(),
            "loop_rate": self.loop_rate()
        }
```

## Summary

Agents loop because:
- No memory of failures
- No alternative strategies
- Unclear success criteria
- Oscillating states
- Repeated tool errors

Prevent loops with:
- Track action history
- Force diverse attempts
- Inject alternatives
- Escalate when stuck
- Set hard limits

Detection + prevention + good prompts = loop-free agents.

Don't let your agent spin forever. Build in the guardrails.

---

*What's the longest loop you've seen an agent get stuck in?*
