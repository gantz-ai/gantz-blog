+++
title = "Scale AI Agents: From Prototype to Production"
image = "/images/agent-scaling.png"
date = 2025-11-22
description = "Scale AI agents from prototype to production traffic. Handle rate limits, optimize costs, implement caching, and manage concurrent requests with MCP."
draft = false
tags = ['mcp', 'architecture', 'scaling']
voice = false

[howto]
name = "Scale AI Agents"
totalTime = 35
[[howto.steps]]
name = "Handle rate limits"
text = "Implement backoff and queue management for API limits."
[[howto.steps]]
name = "Add caching"
text = "Cache responses to reduce API calls and latency."
[[howto.steps]]
name = "Optimize costs"
text = "Use model routing and prompt optimization."
[[howto.steps]]
name = "Scale horizontally"
text = "Add more instances to handle concurrent requests."
[[howto.steps]]
name = "Monitor and adjust"
text = "Track metrics and tune scaling parameters."
+++


Your agent handles 10 requests. What about 10,000?

Rate limits. Costs. Latency. Concurrency.

Here's how to scale AI agents properly.

## Scaling challenges

AI agents face unique scaling challenges:
- **Rate limits**: API quotas restrict throughput
- **Costs**: Every request costs money
- **Latency**: LLM calls are slow (seconds, not milliseconds)
- **Non-determinism**: Can't cache everything
- **External dependencies**: AI APIs can fail

## Step 1: Rate limit handling

Using [Gantz](https://gantz.run):

```yaml
# gantz.yaml
name: scaled-agent

tools:
  - name: check_rate_limit
    description: Check current rate limit status
    script:
      command: python
      args: ["scripts/check_rate_limit.py"]

  - name: increment_rate_counter
    description: Increment the rate limit counter
    parameters:
      - name: tokens_used
        type: integer
        default: 0
    script:
      command: python
      args: ["scripts/increment_rate.py", "{{tokens_used}}"]

  - name: get_queue_position
    description: Get position in the request queue
    parameters:
      - name: request_id
        type: string
        required: true
    script:
      command: python
      args: ["scripts/queue_position.py", "{{request_id}}"]
```

Rate limiter implementation:

```python
import redis
import time
from typing import Optional

class RateLimiter:
    """Token bucket rate limiter for AI API calls."""

    def __init__(self, redis_client: redis.Redis):
        self.redis = redis_client

        # Anthropic limits (example)
        self.limits = {
            "requests_per_minute": 1000,
            "tokens_per_minute": 100000,
            "tokens_per_day": 1000000
        }

    def acquire(self, estimated_tokens: int = 1000, timeout: int = 60) -> bool:
        """Acquire permission to make an API call."""

        start_time = time.time()

        while time.time() - start_time < timeout:
            if self._check_limits(estimated_tokens):
                self._increment_counters(estimated_tokens)
                return True

            # Wait and retry
            wait_time = self._calculate_wait_time()
            time.sleep(min(wait_time, 1))

        return False  # Timed out

    def _check_limits(self, tokens: int) -> bool:
        """Check if request is within limits."""

        # Get current counts
        minute_key = f"rate:minute:{int(time.time() / 60)}"
        day_key = f"rate:day:{int(time.time() / 86400)}"

        minute_requests = int(self.redis.get(f"{minute_key}:requests") or 0)
        minute_tokens = int(self.redis.get(f"{minute_key}:tokens") or 0)
        day_tokens = int(self.redis.get(f"{day_key}:tokens") or 0)

        return (
            minute_requests < self.limits["requests_per_minute"] and
            minute_tokens + tokens <= self.limits["tokens_per_minute"] and
            day_tokens + tokens <= self.limits["tokens_per_day"]
        )

    def _increment_counters(self, tokens: int):
        """Increment rate limit counters."""

        minute_key = f"rate:minute:{int(time.time() / 60)}"
        day_key = f"rate:day:{int(time.time() / 86400)}"

        pipe = self.redis.pipeline()
        pipe.incr(f"{minute_key}:requests")
        pipe.expire(f"{minute_key}:requests", 120)
        pipe.incrby(f"{minute_key}:tokens", tokens)
        pipe.expire(f"{minute_key}:tokens", 120)
        pipe.incrby(f"{day_key}:tokens", tokens)
        pipe.expire(f"{day_key}:tokens", 172800)
        pipe.execute()

    def _calculate_wait_time(self) -> float:
        """Calculate how long to wait before retry."""
        minute_key = f"rate:minute:{int(time.time() / 60)}"
        current_requests = int(self.redis.get(f"{minute_key}:requests") or 0)

        if current_requests >= self.limits["requests_per_minute"]:
            # Wait until next minute
            return 60 - (time.time() % 60)

        return 0.1  # Small backoff
```

## Step 2: Request queuing

```python
import uuid
from dataclasses import dataclass
from typing import Optional, Callable
import threading
import queue

@dataclass
class AgentRequest:
    id: str
    task: str
    priority: int
    callback: Optional[Callable] = None
    created_at: float = None

    def __post_init__(self):
        if not self.id:
            self.id = str(uuid.uuid4())
        if not self.created_at:
            self.created_at = time.time()

class RequestQueue:
    """Priority queue for agent requests."""

    def __init__(self, max_size: int = 1000, workers: int = 10):
        self.queue = queue.PriorityQueue(maxsize=max_size)
        self.results = {}
        self.workers = workers
        self.rate_limiter = RateLimiter(redis.Redis())

    def submit(self, task: str, priority: int = 5) -> str:
        """Submit a request to the queue."""

        request = AgentRequest(
            id=str(uuid.uuid4()),
            task=task,
            priority=priority
        )

        # Priority queue uses (priority, timestamp, request)
        # Lower priority number = higher priority
        self.queue.put((10 - priority, request.created_at, request))

        return request.id

    def get_result(self, request_id: str, timeout: int = 300) -> Optional[str]:
        """Wait for and get the result of a request."""

        start_time = time.time()

        while time.time() - start_time < timeout:
            if request_id in self.results:
                result = self.results.pop(request_id)
                return result

            time.sleep(0.1)

        return None

    def start_workers(self):
        """Start worker threads."""

        for i in range(self.workers):
            thread = threading.Thread(target=self._worker, daemon=True)
            thread.start()

    def _worker(self):
        """Worker thread that processes requests."""

        while True:
            try:
                _, _, request = self.queue.get(timeout=1)

                # Acquire rate limit
                if not self.rate_limiter.acquire(estimated_tokens=1000):
                    # Put back in queue with lower priority
                    self.queue.put((11, request.created_at, request))
                    continue

                # Process request
                result = self._process_request(request)
                self.results[request.id] = result

                if request.callback:
                    request.callback(result)

            except queue.Empty:
                continue
            except Exception as e:
                print(f"Worker error: {e}")

    def _process_request(self, request: AgentRequest) -> str:
        """Process a single request."""

        import anthropic
        client = anthropic.Anthropic()

        response = client.messages.create(
            model="claude-sonnet-4-20250514",
            max_tokens=4096,
            messages=[{"role": "user", "content": request.task}]
        )

        for content in response.content:
            if hasattr(content, 'text'):
                return content.text

        return ""
```

## Step 3: Response caching

```python
import hashlib
import json
from typing import Optional

class ResponseCache:
    """Cache for agent responses."""

    def __init__(self, redis_client: redis.Redis, ttl: int = 3600):
        self.redis = redis_client
        self.ttl = ttl

    def _cache_key(self, task: str, model: str = "claude-sonnet") -> str:
        """Generate cache key from task."""
        content = f"{model}:{task}"
        return f"cache:{hashlib.sha256(content.encode()).hexdigest()}"

    def get(self, task: str, model: str = "claude-sonnet") -> Optional[str]:
        """Get cached response if available."""
        key = self._cache_key(task, model)
        cached = self.redis.get(key)

        if cached:
            data = json.loads(cached)
            # Track hit
            self.redis.incr("cache:hits")
            return data["response"]

        self.redis.incr("cache:misses")
        return None

    def set(self, task: str, response: str, model: str = "claude-sonnet"):
        """Cache a response."""
        key = self._cache_key(task, model)
        data = {
            "response": response,
            "timestamp": time.time(),
            "model": model
        }
        self.redis.setex(key, self.ttl, json.dumps(data))

    def get_stats(self) -> dict:
        """Get cache statistics."""
        hits = int(self.redis.get("cache:hits") or 0)
        misses = int(self.redis.get("cache:misses") or 0)
        total = hits + misses

        return {
            "hits": hits,
            "misses": misses,
            "hit_rate": hits / total if total > 0 else 0
        }

class CachedAgent:
    """Agent with response caching."""

    def __init__(self, cache: ResponseCache):
        self.cache = cache
        self.client = anthropic.Anthropic()

    def run(self, task: str, use_cache: bool = True) -> str:
        """Run agent with caching."""

        # Check cache first
        if use_cache:
            cached = self.cache.get(task)
            if cached:
                return cached

        # Make API call
        response = self.client.messages.create(
            model="claude-sonnet-4-20250514",
            max_tokens=4096,
            messages=[{"role": "user", "content": task}]
        )

        result = ""
        for content in response.content:
            if hasattr(content, 'text'):
                result += content.text

        # Cache result
        if use_cache and result:
            self.cache.set(task, result)

        return result
```

## Step 4: Cost optimization

```python
class ModelRouter:
    """Route requests to appropriate models based on complexity."""

    def __init__(self):
        self.models = {
            "fast": "claude-3-haiku-20240307",
            "balanced": "claude-sonnet-4-20250514",
            "powerful": "claude-opus-4-20250514"
        }

        # Cost per 1M tokens (approximate)
        self.costs = {
            "fast": {"input": 0.25, "output": 1.25},
            "balanced": {"input": 3.00, "output": 15.00},
            "powerful": {"input": 15.00, "output": 75.00}
        }

    def select_model(self, task: str, requirements: dict = None) -> str:
        """Select the most cost-effective model for the task."""

        requirements = requirements or {}

        # Fast model for simple tasks
        simple_indicators = [
            "summarize", "translate", "format",
            "list", "simple", "quick"
        ]
        if any(ind in task.lower() for ind in simple_indicators):
            return self.models["fast"]

        # Powerful model for complex tasks
        complex_indicators = [
            "analyze deeply", "complex", "detailed analysis",
            "multi-step", "reasoning", "creative"
        ]
        if any(ind in task.lower() for ind in complex_indicators):
            return self.models["powerful"]

        # Check explicit requirements
        if requirements.get("quality") == "high":
            return self.models["powerful"]
        if requirements.get("speed") == "fast":
            return self.models["fast"]

        # Default to balanced
        return self.models["balanced"]

    def estimate_cost(self, task: str, model: str) -> float:
        """Estimate cost for a request."""
        # Rough token estimation: 1 token ≈ 4 characters
        input_tokens = len(task) / 4
        output_tokens = 1000  # Assume 1000 output tokens

        model_type = None
        for mtype, mname in self.models.items():
            if mname == model:
                model_type = mtype
                break

        if not model_type:
            model_type = "balanced"

        costs = self.costs[model_type]
        return (
            input_tokens * costs["input"] / 1_000_000 +
            output_tokens * costs["output"] / 1_000_000
        )

class CostTracker:
    """Track API costs."""

    def __init__(self, redis_client: redis.Redis):
        self.redis = redis_client

    def record(self, model: str, input_tokens: int, output_tokens: int):
        """Record token usage."""
        day_key = f"cost:{int(time.time() / 86400)}"

        pipe = self.redis.pipeline()
        pipe.hincrby(day_key, f"{model}:input", input_tokens)
        pipe.hincrby(day_key, f"{model}:output", output_tokens)
        pipe.expire(day_key, 604800)  # Keep 7 days
        pipe.execute()

    def get_daily_cost(self, date: str = None) -> dict:
        """Get cost for a specific day."""
        if date is None:
            day_key = f"cost:{int(time.time() / 86400)}"
        else:
            # Parse date and convert to key
            pass

        usage = self.redis.hgetall(day_key)
        # Calculate costs based on model pricing
        return {"usage": usage, "total_cost": 0}  # Calculate actual cost
```

## Step 5: Horizontal scaling

```python
from flask import Flask, request, jsonify
import os

app = Flask(__name__)

# Shared state via Redis
redis_client = redis.Redis(
    host=os.environ.get("REDIS_HOST", "localhost"),
    port=int(os.environ.get("REDIS_PORT", 6379))
)

# Initialize components
rate_limiter = RateLimiter(redis_client)
cache = ResponseCache(redis_client)
request_queue = RequestQueue()
model_router = ModelRouter()
cost_tracker = CostTracker(redis_client)

@app.route("/agent", methods=["POST"])
def run_agent():
    """Run agent with all optimizations."""

    data = request.json
    task = data.get("task")
    priority = data.get("priority", 5)
    use_cache = data.get("use_cache", True)
    async_mode = data.get("async", False)

    # Check cache
    if use_cache:
        cached = cache.get(task)
        if cached:
            return jsonify({"result": cached, "cached": True})

    # Select model
    model = model_router.select_model(task, data.get("requirements"))

    if async_mode:
        # Queue for async processing
        request_id = request_queue.submit(task, priority)
        return jsonify({"request_id": request_id, "status": "queued"})

    # Synchronous processing
    if not rate_limiter.acquire():
        return jsonify({"error": "Rate limited"}), 429

    # Process request
    client = anthropic.Anthropic()
    response = client.messages.create(
        model=model,
        max_tokens=4096,
        messages=[{"role": "user", "content": task}]
    )

    # Track costs
    cost_tracker.record(
        model,
        response.usage.input_tokens,
        response.usage.output_tokens
    )

    result = ""
    for content in response.content:
        if hasattr(content, 'text'):
            result += content.text

    # Cache result
    if use_cache:
        cache.set(task, result)

    return jsonify({"result": result, "model": model})

@app.route("/agent/<request_id>", methods=["GET"])
def get_result(request_id: str):
    """Get async request result."""
    result = request_queue.get_result(request_id, timeout=1)

    if result is None:
        position = request_queue.queue.qsize()
        return jsonify({"status": "pending", "position": position})

    return jsonify({"status": "completed", "result": result})

@app.route("/stats", methods=["GET"])
def get_stats():
    """Get scaling statistics."""
    return jsonify({
        "cache": cache.get_stats(),
        "queue_size": request_queue.queue.qsize(),
        "costs": cost_tracker.get_daily_cost()
    })

if __name__ == "__main__":
    request_queue.start_workers()
    app.run(host="0.0.0.0", port=8080)
```

Kubernetes HPA for scaling:
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: agent-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: agent
  minReplicas: 2
  maxReplicas: 20
  metrics:
  - type: External
    external:
      metric:
        name: agent_queue_size
      target:
        type: AverageValue
        averageValue: "10"
```

## Summary

Scaling AI agents:

1. **Rate limiting** - Respect API limits with queuing
2. **Caching** - Cache deterministic responses
3. **Model routing** - Use appropriate models for tasks
4. **Cost tracking** - Monitor and optimize spend
5. **Horizontal scaling** - Add instances for load

Build tools with [Gantz](https://gantz.run), scale to production traffic.

From prototype to production. Cost-effectively.

## Related reading

- [Agent Deployment](/post/agent-deployment/) - Deploy to production
- [Agent Job Queues](/post/agent-queues/) - Background processing
- [Agent Observability](/post/agent-observability/) - Monitor at scale

---

*How do you scale AI workloads? Share your strategies.*
