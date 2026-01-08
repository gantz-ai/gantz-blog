+++
title = "MCP Rate Limiting: Prevent API Overload in AI Agents"
image = "images/mcp-rate-limiting.webp"
date = 2025-11-14
description = "Implement rate limiting for MCP servers. Protect your APIs from overload, manage costs, and ensure fair usage across AI agent clients."
summary = "Implement rate limiting to protect your MCP server from infinite agent loops, retry storms, and cost explosions using fixed window, sliding window, or token bucket algorithms. This guide covers per-tool and per-client limits, Redis-based distributed limiting, proper response headers, and cost-based limiting for expensive operations."
draft = false
tags = ['mcp', 'architecture', 'best-practices']
voice = false

[howto]
name = "Add Rate Limiting to MCP Servers"
totalTime = 25
[[howto.steps]]
name = "Choose a rate limiting strategy"
text = "Select between fixed window, sliding window, or token bucket algorithms."
[[howto.steps]]
name = "Define rate limits"
text = "Set appropriate limits per client, per tool, and globally."
[[howto.steps]]
name = "Implement the limiter"
text = "Add rate limiting middleware to your MCP server."
[[howto.steps]]
name = "Handle limit exceeded"
text = "Return proper error responses with retry-after headers."
[[howto.steps]]
name = "Monitor and adjust"
text = "Track usage patterns and fine-tune limits based on real data."
+++


Your AI agent calls tools in a loop. Sometimes that loop goes wrong.

Infinite loops. Retry storms. Runaway costs.

Rate limiting prevents disaster.

## Why rate limit MCP?

AI agents are autonomous. They decide when to call tools. Without limits:

- A confused agent might call the same tool 1000 times
- Retry logic can create exponential request storms
- Multiple agents can overwhelm shared resources
- API costs can spiral out of control

Rate limiting is your safety net.

## Real scenarios

### The infinite loop

```
Agent: "I need to find the file"
Agent: [calls search_files]
Agent: "Not found, let me search again"
Agent: [calls search_files]
Agent: "Still not found, searching..."
Agent: [calls search_files]
... 500 more times
```

Without rate limiting, this burns through API quota and compute resources.

### The retry storm

```
Tool: [returns error]
Agent: [retries immediately]
Tool: [still error - server overloaded]
Agent: [retries immediately]
Tool: [error intensifies]
... server crashes
```

### The cost explosion

```
Agent using expensive API:
- 1 call = $0.10
- Agent decides to "be thorough"
- 10,000 calls later
- $1,000 bill
```

## Rate limiting strategies

### Fixed window

Count requests in fixed time windows.

```
Window: 1 minute
Limit: 100 requests

00:00 - 00:59 → Allow up to 100
01:00 - 01:59 → Counter resets, allow 100 more
```

**Pros:** Simple to implement
**Cons:** Burst at window boundaries (100 at 00:59, 100 at 01:00)

```python
from collections import defaultdict
import time

class FixedWindowLimiter:
    def __init__(self, limit, window_seconds):
        self.limit = limit
        self.window = window_seconds
        self.counts = defaultdict(int)
        self.windows = {}

    def is_allowed(self, client_id):
        current_window = int(time.time() / self.window)

        if self.windows.get(client_id) != current_window:
            self.counts[client_id] = 0
            self.windows[client_id] = current_window

        if self.counts[client_id] >= self.limit:
            return False

        self.counts[client_id] += 1
        return True
```

### Sliding window

Smoother limiting across window boundaries.

```
Current time: 01:30
Window: 1 minute
Look back 60 seconds from now

Count requests from 00:30 to 01:30
```

**Pros:** No burst at boundaries
**Cons:** More memory (need to store timestamps)

```python
from collections import defaultdict
import time

class SlidingWindowLimiter:
    def __init__(self, limit, window_seconds):
        self.limit = limit
        self.window = window_seconds
        self.requests = defaultdict(list)

    def is_allowed(self, client_id):
        now = time.time()
        window_start = now - self.window

        # Remove old requests
        self.requests[client_id] = [
            ts for ts in self.requests[client_id]
            if ts > window_start
        ]

        if len(self.requests[client_id]) >= self.limit:
            return False

        self.requests[client_id].append(now)
        return True
```

### Token bucket

Allows bursts while maintaining average rate.

```
Bucket capacity: 10 tokens
Refill rate: 1 token/second

- Start with 10 tokens
- Each request consumes 1 token
- Tokens refill over time
- Burst of 10 allowed, then limited to 1/sec
```

**Pros:** Handles bursts gracefully
**Cons:** More complex logic

```python
import time

class TokenBucket:
    def __init__(self, capacity, refill_rate):
        self.capacity = capacity
        self.refill_rate = refill_rate  # tokens per second
        self.tokens = capacity
        self.last_refill = time.time()

    def is_allowed(self):
        now = time.time()
        elapsed = now - self.last_refill

        # Refill tokens
        self.tokens = min(
            self.capacity,
            self.tokens + elapsed * self.refill_rate
        )
        self.last_refill = now

        if self.tokens >= 1:
            self.tokens -= 1
            return True
        return False
```

## Implementation

### Basic MCP rate limiting

```python
from functools import wraps
from flask import request, jsonify

limiter = SlidingWindowLimiter(limit=100, window_seconds=60)

def rate_limit(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        client_id = get_client_id(request)

        if not limiter.is_allowed(client_id):
            return jsonify({
                "error": "Rate limit exceeded",
                "retry_after": 60
            }), 429

        return f(*args, **kwargs)
    return decorated

@app.route("/mcp/tools/call", methods=["POST"])
@rate_limit
def call_tool():
    # Process tool call
    ...
```

### Per-tool limits

Different tools have different costs:

```python
TOOL_LIMITS = {
    "read_file": {"limit": 100, "window": 60},      # Fast, cheap
    "search_code": {"limit": 20, "window": 60},     # More expensive
    "run_command": {"limit": 10, "window": 60},     # Resource intensive
    "call_api": {"limit": 5, "window": 60},         # External API costs
}

limiters = {
    tool: SlidingWindowLimiter(**config)
    for tool, config in TOOL_LIMITS.items()
}

def check_tool_limit(tool_name, client_id):
    limiter = limiters.get(tool_name)
    if limiter and not limiter.is_allowed(client_id):
        return False
    return True
```

### Global + per-client limits

Layer multiple limits:

```python
class MultiLevelLimiter:
    def __init__(self):
        # Global: 1000 req/min across all clients
        self.global_limiter = SlidingWindowLimiter(1000, 60)
        # Per-client: 100 req/min per client
        self.client_limiters = defaultdict(
            lambda: SlidingWindowLimiter(100, 60)
        )

    def is_allowed(self, client_id):
        # Check global first
        if not self.global_limiter.is_allowed("global"):
            return False, "Global rate limit exceeded"

        # Then check per-client
        if not self.client_limiters[client_id].is_allowed(client_id):
            return False, "Client rate limit exceeded"

        return True, None
```

### With Redis (distributed)

For multiple server instances:

```python
import redis
import time

class RedisRateLimiter:
    def __init__(self, redis_client, limit, window):
        self.redis = redis_client
        self.limit = limit
        self.window = window

    def is_allowed(self, key):
        pipe = self.redis.pipeline()
        now = time.time()
        window_start = now - self.window

        # Remove old entries
        pipe.zremrangebyscore(key, 0, window_start)
        # Count current entries
        pipe.zcard(key)
        # Add new entry
        pipe.zadd(key, {str(now): now})
        # Set expiry
        pipe.expire(key, self.window)

        results = pipe.execute()
        count = results[1]

        return count < self.limit

# Usage
redis_client = redis.Redis(host='localhost', port=6379)
limiter = RedisRateLimiter(redis_client, limit=100, window=60)
```

## Response headers

Tell clients about limits:

```python
def add_rate_limit_headers(response, limiter, client_id):
    remaining = limiter.get_remaining(client_id)
    reset_time = limiter.get_reset_time(client_id)

    response.headers['X-RateLimit-Limit'] = str(limiter.limit)
    response.headers['X-RateLimit-Remaining'] = str(remaining)
    response.headers['X-RateLimit-Reset'] = str(int(reset_time))

    return response

@app.after_request
def after_request(response):
    client_id = get_client_id(request)
    return add_rate_limit_headers(response, limiter, client_id)
```

When limit exceeded:

```python
def rate_limit_exceeded_response(retry_after):
    response = jsonify({
        "error": "rate_limit_exceeded",
        "message": "Too many requests. Please slow down.",
        "retry_after": retry_after
    })
    response.status_code = 429
    response.headers['Retry-After'] = str(retry_after)
    return response
```

## Agent-side handling

Your AI agent should respect rate limits:

```python
import time

class RateLimitAwareClient:
    def __init__(self, base_delay=1):
        self.base_delay = base_delay
        self.backoff_multiplier = 1

    def call_tool(self, tool, params):
        while True:
            response = self._make_request(tool, params)

            if response.status_code == 429:
                retry_after = int(response.headers.get('Retry-After', 60))
                print(f"Rate limited. Waiting {retry_after}s...")
                time.sleep(retry_after)
                self.backoff_multiplier *= 2
                continue

            # Success - reset backoff
            self.backoff_multiplier = 1
            return response

    def _make_request(self, tool, params):
        # Add small delay between requests
        time.sleep(self.base_delay * self.backoff_multiplier)
        return requests.post(f"{self.base_url}/tools/call", json={
            "tool": tool,
            "params": params
        })
```

## Cost-based limiting

Limit by cost, not just count:

```python
TOOL_COSTS = {
    "read_file": 1,
    "search_code": 5,
    "run_command": 10,
    "call_external_api": 50,
}

class CostBasedLimiter:
    def __init__(self, budget_per_minute):
        self.budget = budget_per_minute
        self.spent = defaultdict(float)
        self.windows = {}

    def is_allowed(self, client_id, tool_name):
        current_window = int(time.time() / 60)

        if self.windows.get(client_id) != current_window:
            self.spent[client_id] = 0
            self.windows[client_id] = current_window

        cost = TOOL_COSTS.get(tool_name, 1)

        if self.spent[client_id] + cost > self.budget:
            return False

        self.spent[client_id] += cost
        return True
```

## Quick setup with Gantz

[Gantz](https://gantz.run) includes built-in rate limiting:

```yaml
# gantz.yaml
name: my-mcp-server

rate_limit:
  requests_per_minute: 100
  burst: 20

tools:
  - name: search_files
    rate_limit: 20/min  # Override for specific tool
    # ...
```

No custom middleware needed. Limits enforced automatically.

## Monitoring

Track rate limit hits:

```python
import logging
from prometheus_client import Counter

rate_limit_hits = Counter(
    'mcp_rate_limit_hits_total',
    'Number of rate limit hits',
    ['client_id', 'tool']
)

def rate_limit(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        client_id = get_client_id(request)
        tool = request.json.get("tool")

        if not limiter.is_allowed(client_id):
            rate_limit_hits.labels(client_id=client_id, tool=tool).inc()
            logging.warning(f"Rate limit hit: {client_id} on {tool}")
            return rate_limit_exceeded_response(60)

        return f(*args, **kwargs)
    return decorated
```

## Best practices

1. **Start conservative** - Begin with strict limits, loosen based on data
2. **Different limits per tool** - Expensive tools get lower limits
3. **Include headers** - Tell clients their remaining quota
4. **Log limit hits** - Track which clients hit limits
5. **Graceful degradation** - Return helpful errors, not just 429
6. **Client-side respect** - Build agents that handle 429 properly
7. **Monitor costs** - Rate limiting should prevent bill shock

## Summary

Rate limiting protects your MCP server from:

- Infinite agent loops
- Retry storms
- Cost explosions
- Resource exhaustion

Implement it before you need it. The agent that runs away at 3 AM won't wait for you to add limits.

Start with sliding window for most cases. Add token bucket if you need burst handling. Use Redis for distributed deployments.

Your future self (and your wallet) will thank you.

## Related reading

- [Agent Cost Optimization](/post/agent-cost-optimization/) - Cut costs by 80%
- [Error Recovery Patterns](/post/error-recovery/) - Handle failures gracefully
- [Agent Loops and How to Break Them](/post/agent-loops/) - Stop infinite loops

---

*What rate limits do you use for your MCP tools? Share your numbers.*
