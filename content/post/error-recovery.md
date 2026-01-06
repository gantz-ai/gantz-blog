+++
title = "Error Recovery in AI Agents: Graceful Degradation and Retry Strategies"
date = 2025-12-22
image = "images/warrior-rain-city-01.webp"
draft = false
tags = ['patterns', 'architecture', 'best-practices']
+++


AI agents fail. Tools break. APIs timeout. Models hallucinate.

The difference between a toy and production agent? How it handles failure.

## Why agents fail

Agents fail in ways traditional software doesn't:

```
Traditional software:
Input → Function → Output (or Error)

AI Agent:
Input → Think → Act → Observe → Think → Act → ...
              ↓       ↓          ↓       ↓
           Fail?   Fail?      Fail?   Fail?
```

Every step is a failure point:
- **Thinking**: Model outputs garbage
- **Acting**: Tool call fails
- **Observing**: Can't parse result
- **Loop**: Gets stuck, infinite loop

## Types of failures

### 1. Tool failures

The tool itself breaks.

```python
# Tool times out
result = tool.call("search", {"query": "test"})
# TimeoutError: Connection timed out

# Tool returns error
result = tool.call("send_email", {"to": "invalid"})
# {"error": "Invalid email address"}

# Tool unavailable
result = tool.call("database_query", {...})
# ConnectionRefusedError: Database offline
```

### 2. Model failures

The AI does something wrong.

```python
# Invalid tool call
{"tool": "nonexistent_tool", "params": {...}}

# Malformed parameters
{"tool": "search", "params": {"query": 123}}  # Expected string

# Infinite loop
Think: "I should search"
Act: search("test")
Think: "I should search again"
Act: search("test")  # Same thing, forever
```

### 3. Context failures

The situation itself is problematic.

```python
# Missing information
User: "Send the report"
# What report? To whom?

# Conflicting instructions
User: "Delete everything but keep it safe"
# ???

# Impossible request
User: "Predict tomorrow's stock prices with certainty"
# Can't be done
```

## Retry strategies

### Strategy 1: Simple retry

Try again, maybe it works.

```python
def retry_simple(func, max_retries=3):
    for attempt in range(max_retries):
        try:
            return func()
        except Exception as e:
            if attempt == max_retries - 1:
                raise
            continue
```

**When to use**: Transient failures (network blips, rate limits)

**When not to use**: Permanent failures (wrong password, missing file)

### Strategy 2: Exponential backoff

Wait longer between each retry.

```python
import time
import random

def retry_backoff(func, max_retries=5, base_delay=1):
    for attempt in range(max_retries):
        try:
            return func()
        except Exception as e:
            if attempt == max_retries - 1:
                raise

            # Exponential delay with jitter
            delay = base_delay * (2 ** attempt)
            jitter = random.uniform(0, delay * 0.1)
            time.sleep(delay + jitter)
```

**When to use**: Rate-limited APIs, overloaded services

### Strategy 3: Retry with modification

Change something and try again.

```python
def retry_with_modification(agent, task, max_retries=3):
    attempt_context = []

    for attempt in range(max_retries):
        try:
            return agent.execute(task, context=attempt_context)
        except ToolError as e:
            # Add failure info to context
            attempt_context.append({
                "attempt": attempt + 1,
                "error": str(e),
                "suggestion": "Try a different approach"
            })
        except ModelError as e:
            # Simplify the task
            task = simplify_task(task)
            attempt_context.append({
                "attempt": attempt + 1,
                "error": "Task was too complex",
                "action": "Simplified task"
            })

    raise MaxRetriesExceeded(attempt_context)
```

**When to use**: Complex tasks that might need different approaches

### Strategy 4: Circuit breaker

Stop trying if failures pile up.

```python
class CircuitBreaker:
    def __init__(self, failure_threshold=5, reset_timeout=60):
        self.failures = 0
        self.failure_threshold = failure_threshold
        self.reset_timeout = reset_timeout
        self.last_failure_time = None
        self.state = "closed"  # closed, open, half-open

    def call(self, func):
        if self.state == "open":
            if time.time() - self.last_failure_time > self.reset_timeout:
                self.state = "half-open"
            else:
                raise CircuitOpenError("Circuit breaker is open")

        try:
            result = func()
            if self.state == "half-open":
                self.state = "closed"
                self.failures = 0
            return result
        except Exception as e:
            self.failures += 1
            self.last_failure_time = time.time()
            if self.failures >= self.failure_threshold:
                self.state = "open"
            raise

# Usage
breaker = CircuitBreaker()

def call_external_api():
    return breaker.call(lambda: api.search(query))
```

**When to use**: External services that might be down

## Graceful degradation

When you can't do the full task, do what you can.

### Pattern 1: Fallback tools

Primary tool fails? Use backup.

```python
class ToolWithFallback:
    def __init__(self, primary, fallbacks):
        self.primary = primary
        self.fallbacks = fallbacks

    def call(self, params):
        # Try primary
        try:
            return self.primary.call(params)
        except ToolError as e:
            pass

        # Try fallbacks in order
        for fallback in self.fallbacks:
            try:
                return fallback.call(params)
            except ToolError:
                continue

        raise AllToolsFailedError("No tool succeeded")

# Usage
search_tool = ToolWithFallback(
    primary=GoogleSearch(),
    fallbacks=[BingSearch(), DuckDuckGo(), LocalCache()]
)
```

### Pattern 2: Reduced functionality

Can't do everything? Do something.

```python
def send_notification(user, message, channels=["email", "sms", "push"]):
    results = {"sent": [], "failed": []}

    for channel in channels:
        try:
            send_via_channel(channel, user, message)
            results["sent"].append(channel)
        except ChannelError as e:
            results["failed"].append({"channel": channel, "error": str(e)})

    if not results["sent"]:
        raise AllChannelsFailedError(results["failed"])

    return results

# Even if SMS and push fail, email might succeed
# Partial success is better than total failure
```

### Pattern 3: Cached results

Live data unavailable? Use cached.

```python
class CachedTool:
    def __init__(self, tool, cache_ttl=3600):
        self.tool = tool
        self.cache = {}
        self.cache_ttl = cache_ttl

    def call(self, params):
        cache_key = hash(str(params))

        try:
            # Try live call
            result = self.tool.call(params)
            # Update cache
            self.cache[cache_key] = {
                "result": result,
                "timestamp": time.time(),
                "is_cached": False
            }
            return result
        except ToolError:
            # Fall back to cache
            if cache_key in self.cache:
                cached = self.cache[cache_key]
                age = time.time() - cached["timestamp"]
                return {
                    **cached["result"],
                    "is_cached": True,
                    "cache_age_seconds": age
                }
            raise
```

### Pattern 4: Simplified response

Can't give full answer? Give partial.

```python
def answer_question(question, tools):
    try:
        # Full answer with tool use
        data = tools.search(question)
        analysis = tools.analyze(data)
        return {"answer": analysis, "confidence": "high", "sources": data}
    except ToolError:
        try:
            # Fall back to just search
            data = tools.search(question)
            return {"answer": summarize(data), "confidence": "medium", "sources": data}
        except ToolError:
            # Fall back to model knowledge
            return {
                "answer": llm.answer(question),
                "confidence": "low",
                "sources": None,
                "note": "Based on training data only, tools unavailable"
            }
```

## Agent-level error handling

### Handle tool errors gracefully

```python
def execute_with_recovery(agent, task):
    max_attempts = 3
    errors = []

    for attempt in range(max_attempts):
        try:
            result = agent.step()

            if result.type == "tool_call":
                tool_result = safe_tool_call(result.tool, result.params)
                agent.observe(tool_result)

            elif result.type == "answer":
                return result.content

        except ToolError as e:
            errors.append(str(e))
            # Tell agent about the failure
            agent.observe({
                "type": "error",
                "message": str(e),
                "suggestion": get_recovery_suggestion(e)
            })

        except ModelError as e:
            errors.append(str(e))
            # Reset agent state and simplify
            agent.reset_to_last_good_state()
            agent.simplify_approach()

    return {
        "status": "failed",
        "errors": errors,
        "partial_result": agent.get_partial_result()
    }
```

### Detect and break loops

```python
class LoopDetector:
    def __init__(self, window_size=5):
        self.recent_actions = []
        self.window_size = window_size

    def record(self, action):
        self.recent_actions.append(hash(str(action)))
        if len(self.recent_actions) > self.window_size * 2:
            self.recent_actions.pop(0)

    def is_looping(self):
        if len(self.recent_actions) < self.window_size * 2:
            return False

        recent = self.recent_actions[-self.window_size:]
        previous = self.recent_actions[-self.window_size*2:-self.window_size]
        return recent == previous

# Usage
detector = LoopDetector()

while not done:
    action = agent.decide()
    detector.record(action)

    if detector.is_looping():
        agent.observe({
            "type": "warning",
            "message": "You seem to be repeating the same actions. Try something different."
        })
        agent.force_different_approach()
```

### Timeout protection

```python
import asyncio

async def execute_with_timeout(agent, task, timeout=120):
    try:
        result = await asyncio.wait_for(
            agent.execute(task),
            timeout=timeout
        )
        return result
    except asyncio.TimeoutError:
        # Get whatever progress was made
        partial = agent.get_partial_result()
        return {
            "status": "timeout",
            "message": f"Task did not complete within {timeout}s",
            "partial_result": partial,
            "can_resume": agent.can_resume()
        }
```

## MCP tools for error handling

Build error-aware tools with [Gantz](https://gantz.run):

```yaml
# tools.yaml
tools:
  - name: search_with_fallback
    description: Search with automatic fallback
    parameters:
      - name: query
        type: string
        required: true
    script:
      shell: |
        # Try primary search
        result=$(curl -s "https://api.primary.com/search?q={{query}}" 2>/dev/null)
        if [ $? -eq 0 ] && [ -n "$result" ]; then
          echo "$result"
          exit 0
        fi

        # Try fallback
        result=$(curl -s "https://api.fallback.com/search?q={{query}}" 2>/dev/null)
        if [ $? -eq 0 ] && [ -n "$result" ]; then
          echo '{"source": "fallback"}'"$result"
          exit 0
        fi

        # Return cached if available
        cached=$(cat "cache/{{query}}.json" 2>/dev/null)
        if [ -n "$cached" ]; then
          echo '{"source": "cache", "data": '"$cached"'}'
          exit 0
        fi

        echo '{"error": "All search methods failed"}'
        exit 1

  - name: safe_write
    description: Write file with backup
    parameters:
      - name: path
        type: string
        required: true
      - name: content
        type: string
        required: true
    script:
      shell: |
        # Backup existing file
        if [ -f "{{path}}" ]; then
          cp "{{path}}" "{{path}}.backup"
        fi

        # Write new content
        echo "{{content}}" > "{{path}}"

        # Verify write
        if [ $? -eq 0 ]; then
          echo '{"status": "success", "backup": "{{path}}.backup"}'
        else
          # Restore backup
          if [ -f "{{path}}.backup" ]; then
            mv "{{path}}.backup" "{{path}}"
          fi
          echo '{"status": "failed", "restored": true}'
          exit 1
        fi
```

## Error reporting to users

Be honest about failures:

```python
def format_error_for_user(error, partial_result=None):
    if isinstance(error, ToolTimeoutError):
        message = "The operation took too long and was stopped."
    elif isinstance(error, ToolNotFoundError):
        message = "I tried to use a tool that isn't available."
    elif isinstance(error, PermissionError):
        message = "I don't have permission to do that."
    else:
        message = "Something went wrong."

    response = f"I wasn't able to complete your request. {message}"

    if partial_result:
        response += f"\n\nHere's what I was able to do:\n{partial_result}"

    response += "\n\nWould you like me to try a different approach?"

    return response
```

## Summary

Agents fail. Good agents recover.

**Retry strategies:**
- Simple retry for transient errors
- Exponential backoff for rate limits
- Retry with modification for complex failures
- Circuit breaker for failing services

**Graceful degradation:**
- Fallback tools
- Reduced functionality
- Cached results
- Simplified responses

**Agent-level handling:**
- Tell agent about failures
- Detect and break loops
- Enforce timeouts
- Report honestly to users

Build error handling in from the start. It's not optional.

## Related reading

- [Why Agents Get Stuck in Loops](/post/agent-loops/) - Detecting and breaking loops
- [The Confirm-Before-Destroy Pattern](/post/confirm-before-destroy/) - Preventing mistakes
- [Background Jobs for Long-Running Tasks](/post/background-jobs/) - Handling timeouts

---

*How do you handle failures in your agents? What strategies have saved you?*
