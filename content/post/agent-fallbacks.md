+++
title = "AI Agent Fallback Strategies: Ensure Service Continuity"
image = "/images/agent-fallbacks.png"
date = 2025-11-18
description = "Implement fallback strategies for AI agents. Model fallbacks, tool alternatives, cached responses, and graceful degradation patterns with MCP."
draft = false
tags = ['mcp', 'reliability', 'fallbacks']
voice = false

[howto]
name = "Implement Agent Fallbacks"
totalTime = 30
[[howto.steps]]
name = "Define fallback hierarchy"
text = "Establish order of fallback options."
[[howto.steps]]
name = "Implement model fallbacks"
text = "Switch to alternative models when primary fails."
[[howto.steps]]
name = "Add tool alternatives"
text = "Provide backup tools for critical functions."
[[howto.steps]]
name = "Cache responses"
text = "Serve cached responses when live calls fail."
[[howto.steps]]
name = "Configure graceful degradation"
text = "Reduce functionality gracefully when needed."
+++


Your primary model is down. Your main tool is rate-limited.

Users are waiting.

What happens next determines your system's reliability.

## Why fallbacks matter

AI systems depend on external services:
- LLM APIs (Anthropic, OpenAI)
- Tool endpoints
- Databases
- Third-party APIs

Any of these can fail. Fallbacks keep your system running.

## Fallback hierarchy

Plan your fallback order:

```
Primary Model → Backup Model → Cached Response → Default Response → Error Message
     ↓              ↓              ↓                 ↓                  ↓
   Best           Good          Stale            Generic           Informative
  Quality        Quality        Data             Response            Error
```

## Step 1: Model fallbacks

Using [Gantz](https://gantz.run) with multiple models:

```yaml
# gantz.yaml
name: fallback-agent

# Model configuration with fallbacks
models:
  primary:
    provider: anthropic
    model: claude-sonnet-4-20250514
    timeout: 30
  backup:
    provider: anthropic
    model: claude-3-haiku-20240307
    timeout: 20
  emergency:
    provider: openai
    model: gpt-4o-mini
    timeout: 15

tools:
  - name: query_with_fallback
    description: Query with automatic model fallback
    parameters:
      - name: question
        type: string
        required: true
    script:
      command: python
      args: ["scripts/fallback_query.py", "{{question}}"]
```

Model fallback implementation:

```python
import anthropic
import openai
from typing import Optional, List
from dataclasses import dataclass
import time

@dataclass
class ModelConfig:
    provider: str
    model: str
    timeout: int
    max_tokens: int = 4096

class ModelFallback:
    """Fallback chain for LLM calls."""

    def __init__(self, configs: List[ModelConfig]):
        self.configs = configs
        self.anthropic = anthropic.Anthropic()
        self.openai = openai.OpenAI()

        # Track model health
        self.health = {c.model: {"failures": 0, "last_failure": 0} for c in configs}

    def call(self, messages: list, system: str = None) -> str:
        """Call LLM with automatic fallback."""

        last_error = None

        for config in self.configs:
            # Skip recently failed models
            if self._is_unhealthy(config.model):
                continue

            try:
                result = self._call_model(config, messages, system)
                self._record_success(config.model)
                return result
            except Exception as e:
                last_error = e
                self._record_failure(config.model)
                continue

        raise Exception(f"All models failed. Last error: {last_error}")

    def _call_model(self, config: ModelConfig, messages: list, system: str) -> str:
        """Call specific model."""

        if config.provider == "anthropic":
            response = self.anthropic.messages.create(
                model=config.model,
                max_tokens=config.max_tokens,
                system=system or "",
                messages=messages,
                timeout=config.timeout
            )
            return response.content[0].text

        elif config.provider == "openai":
            oai_messages = []
            if system:
                oai_messages.append({"role": "system", "content": system})
            oai_messages.extend(messages)

            response = self.openai.chat.completions.create(
                model=config.model,
                max_tokens=config.max_tokens,
                messages=oai_messages,
                timeout=config.timeout
            )
            return response.choices[0].message.content

        raise ValueError(f"Unknown provider: {config.provider}")

    def _is_unhealthy(self, model: str) -> bool:
        """Check if model is temporarily unhealthy."""
        health = self.health[model]

        # If failed recently, check cooldown
        if health["failures"] >= 3:
            cooldown = 60 * health["failures"]  # Exponential cooldown
            if time.time() - health["last_failure"] < cooldown:
                return True

        return False

    def _record_success(self, model: str):
        """Record successful call."""
        self.health[model]["failures"] = 0

    def _record_failure(self, model: str):
        """Record failed call."""
        self.health[model]["failures"] += 1
        self.health[model]["last_failure"] = time.time()

# Usage
fallback = ModelFallback([
    ModelConfig("anthropic", "claude-sonnet-4-20250514", timeout=30),
    ModelConfig("anthropic", "claude-3-haiku-20240307", timeout=20),
    ModelConfig("openai", "gpt-4o-mini", timeout=15),
])

result = fallback.call([{"role": "user", "content": "Hello!"}])
```

## Step 2: Tool fallbacks

Alternative tools for critical operations:

```yaml
# gantz.yaml
name: tool-fallbacks

tools:
  # Primary search tool
  - name: search_primary
    description: Primary search using Elasticsearch
    parameters:
      - name: query
        type: string
        required: true
    script:
      shell: curl -s "http://elasticsearch:9200/index/_search?q={{query}}"

  # Backup search tool
  - name: search_backup
    description: Backup search using PostgreSQL
    parameters:
      - name: query
        type: string
        required: true
    script:
      shell: psql "$DATABASE_URL" -c "SELECT * FROM documents WHERE content ILIKE '%{{query}}%'"

  # Tool with built-in fallback
  - name: search_with_fallback
    description: Search with automatic fallback
    parameters:
      - name: query
        type: string
        required: true
    script:
      command: python
      args: ["scripts/search_fallback.py", "{{query}}"]
```

Tool fallback implementation:

```python
from typing import Callable, Dict, List, Any, Optional
from dataclasses import dataclass
import subprocess
import json

@dataclass
class ToolOption:
    name: str
    executor: Callable
    priority: int
    health_check: Optional[Callable] = None

class ToolFallbackChain:
    """Chain of tool fallbacks."""

    def __init__(self):
        self.tools: Dict[str, List[ToolOption]] = {}
        self.health_status: Dict[str, bool] = {}

    def register(self, operation: str, tool: ToolOption):
        """Register a tool for an operation."""
        if operation not in self.tools:
            self.tools[operation] = []
        self.tools[operation].append(tool)
        self.tools[operation].sort(key=lambda t: t.priority, reverse=True)

    def execute(self, operation: str, params: dict) -> Any:
        """Execute operation with fallbacks."""

        if operation not in self.tools:
            raise ValueError(f"Unknown operation: {operation}")

        last_error = None

        for tool in self.tools[operation]:
            # Check health if checker exists
            if tool.health_check:
                if not self._check_health(tool):
                    continue

            try:
                result = tool.executor(params)
                return result
            except Exception as e:
                last_error = e
                self.health_status[tool.name] = False
                continue

        raise Exception(f"All tools failed for {operation}: {last_error}")

    def _check_health(self, tool: ToolOption) -> bool:
        """Check if tool is healthy."""
        # Check cached status
        if tool.name in self.health_status:
            if not self.health_status[tool.name]:
                return False

        try:
            return tool.health_check()
        except:
            return False

# Example: Search with fallbacks
def elasticsearch_search(params: dict) -> list:
    result = subprocess.run(
        ["curl", "-s", f"http://elasticsearch:9200/_search?q={params['query']}"],
        capture_output=True,
        text=True,
        timeout=10
    )
    return json.loads(result.stdout)["hits"]["hits"]

def postgres_search(params: dict) -> list:
    result = subprocess.run(
        ["psql", os.environ["DATABASE_URL"], "-c",
         f"SELECT * FROM documents WHERE content ILIKE '%{params['query']}%'"],
        capture_output=True,
        text=True,
        timeout=15
    )
    return result.stdout

def elasticsearch_health() -> bool:
    result = subprocess.run(
        ["curl", "-s", "http://elasticsearch:9200/_health"],
        capture_output=True,
        timeout=5
    )
    return result.returncode == 0

# Setup fallback chain
chain = ToolFallbackChain()
chain.register("search", ToolOption(
    name="elasticsearch",
    executor=elasticsearch_search,
    priority=10,
    health_check=elasticsearch_health
))
chain.register("search", ToolOption(
    name="postgres",
    executor=postgres_search,
    priority=5
))

# Execute with automatic fallback
results = chain.execute("search", {"query": "machine learning"})
```

## Step 3: Response caching

Serve cached responses when live calls fail:

```python
import redis
import hashlib
import json
import time
from typing import Optional, Any

class FallbackCache:
    """Cache for fallback responses."""

    def __init__(self, redis_url: str, default_ttl: int = 3600):
        self.redis = redis.from_url(redis_url)
        self.default_ttl = default_ttl

    def _cache_key(self, operation: str, params: dict) -> str:
        """Generate cache key."""
        param_str = json.dumps(params, sort_keys=True)
        content = f"{operation}:{param_str}"
        return f"fallback:{hashlib.sha256(content.encode()).hexdigest()}"

    def get(self, operation: str, params: dict) -> Optional[Any]:
        """Get cached response."""
        key = self._cache_key(operation, params)
        cached = self.redis.get(key)

        if cached:
            data = json.loads(cached)
            return {
                "response": data["response"],
                "cached_at": data["cached_at"],
                "is_stale": time.time() - data["cached_at"] > self.default_ttl
            }

        return None

    def set(self, operation: str, params: dict, response: Any, ttl: int = None):
        """Cache a response."""
        key = self._cache_key(operation, params)
        data = {
            "response": response,
            "cached_at": time.time()
        }
        self.redis.setex(
            key,
            ttl or self.default_ttl * 4,  # Keep 4x TTL for stale serving
            json.dumps(data)
        )

    def delete(self, operation: str, params: dict):
        """Delete cached response."""
        key = self._cache_key(operation, params)
        self.redis.delete(key)

class CacheFallbackAgent:
    """Agent with cache fallback."""

    def __init__(self, cache: FallbackCache, model_fallback: ModelFallback):
        self.cache = cache
        self.model = model_fallback

    def query(self, question: str, allow_stale: bool = True) -> dict:
        """Query with cache fallback."""

        params = {"question": question}

        try:
            # Try live query
            response = self.model.call([{"role": "user", "content": question}])

            # Cache successful response
            self.cache.set("query", params, response)

            return {
                "response": response,
                "source": "live",
                "cached": False
            }

        except Exception as e:
            # Try cache
            cached = self.cache.get("query", params)

            if cached:
                if cached["is_stale"] and not allow_stale:
                    raise Exception(f"Only stale cache available: {e}")

                return {
                    "response": cached["response"],
                    "source": "cache",
                    "cached": True,
                    "stale": cached["is_stale"],
                    "cached_at": cached["cached_at"]
                }

            raise Exception(f"No cache available: {e}")

# Usage
cache = FallbackCache("redis://localhost:6379")
agent = CacheFallbackAgent(cache, fallback)

result = agent.query("What is machine learning?")
if result["cached"]:
    print(f"Served from cache (stale: {result.get('stale', False)})")
```

## Step 4: Graceful degradation

Reduce functionality gracefully:

```python
from enum import Enum
from typing import Dict, Callable

class ServiceLevel(Enum):
    FULL = "full"           # All features available
    DEGRADED = "degraded"   # Some features disabled
    MINIMAL = "minimal"     # Core features only
    EMERGENCY = "emergency" # Read-only / cached only

class GracefulDegradation:
    """Manage service degradation levels."""

    def __init__(self):
        self.current_level = ServiceLevel.FULL
        self.feature_requirements: Dict[str, ServiceLevel] = {}
        self.level_handlers: Dict[ServiceLevel, Callable] = {}

    def register_feature(self, name: str, min_level: ServiceLevel):
        """Register feature with minimum service level."""
        self.feature_requirements[name] = min_level

    def is_available(self, feature: str) -> bool:
        """Check if feature is available at current level."""
        if feature not in self.feature_requirements:
            return True

        required = self.feature_requirements[feature]
        return self._level_value(self.current_level) <= self._level_value(required)

    def _level_value(self, level: ServiceLevel) -> int:
        """Convert level to numeric value."""
        return list(ServiceLevel).index(level)

    def degrade_to(self, level: ServiceLevel, reason: str = None):
        """Degrade to specified level."""
        self.current_level = level

        if level in self.level_handlers:
            self.level_handlers[level](reason)

    def on_level(self, level: ServiceLevel):
        """Decorator for level handlers."""
        def decorator(func):
            self.level_handlers[level] = func
            return func
        return decorator

    def get_available_features(self) -> list:
        """Get list of available features."""
        return [
            name for name, min_level in self.feature_requirements.items()
            if self.is_available(name)
        ]

# Usage
degradation = GracefulDegradation()

# Register features
degradation.register_feature("complex_analysis", ServiceLevel.FULL)
degradation.register_feature("simple_queries", ServiceLevel.DEGRADED)
degradation.register_feature("cached_responses", ServiceLevel.MINIMAL)
degradation.register_feature("status_check", ServiceLevel.EMERGENCY)

@degradation.on_level(ServiceLevel.DEGRADED)
def handle_degraded(reason):
    print(f"Entering degraded mode: {reason}")
    # Disable complex features, increase caching

@degradation.on_level(ServiceLevel.EMERGENCY)
def handle_emergency(reason):
    print(f"Emergency mode: {reason}")
    # Only serve cached responses

class DegradedAgent:
    """Agent with graceful degradation."""

    def __init__(self, degradation: GracefulDegradation):
        self.degradation = degradation
        self.cache = FallbackCache("redis://localhost:6379")

    def process(self, task: str, complexity: str = "complex") -> dict:
        """Process task based on current service level."""

        # Map complexity to feature
        feature_map = {
            "complex": "complex_analysis",
            "simple": "simple_queries",
            "cached": "cached_responses"
        }

        required_feature = feature_map.get(complexity, "simple_queries")

        if not self.degradation.is_available(required_feature):
            # Try to downgrade request
            if complexity == "complex":
                return self.process(task, "simple")
            elif complexity == "simple":
                return self.process(task, "cached")
            else:
                return {
                    "error": "Service unavailable",
                    "available_features": self.degradation.get_available_features()
                }

        return self._execute(task, complexity)

    def _execute(self, task: str, complexity: str) -> dict:
        # Execute based on complexity level
        pass
```

## Step 5: Monitoring fallback usage

Track fallback activation:

```python
from prometheus_client import Counter, Gauge
import logging

fallback_activations = Counter(
    'agent_fallback_activations_total',
    'Total fallback activations',
    ['fallback_type', 'reason']
)

service_level_gauge = Gauge(
    'agent_service_level',
    'Current service level (0=full, 3=emergency)'
)

cache_hit_counter = Counter(
    'agent_cache_hits_total',
    'Cache hits for fallback',
    ['stale']
)

class FallbackMonitor:
    """Monitor fallback usage."""

    def __init__(self):
        self.logger = logging.getLogger("fallback")

    def record_fallback(self, fallback_type: str, reason: str):
        """Record fallback activation."""
        fallback_activations.labels(
            fallback_type=fallback_type,
            reason=reason
        ).inc()

        self.logger.warning(f"Fallback activated: {fallback_type} - {reason}")

    def record_cache_hit(self, stale: bool):
        """Record cache fallback hit."""
        cache_hit_counter.labels(stale=str(stale)).inc()

    def record_service_level(self, level: ServiceLevel):
        """Record current service level."""
        level_value = list(ServiceLevel).index(level)
        service_level_gauge.set(level_value)
```

## Summary

Fallback strategies for AI agents:

1. **Model fallbacks** - Chain of alternative models
2. **Tool alternatives** - Backup tools for critical operations
3. **Response caching** - Serve cached when live fails
4. **Graceful degradation** - Reduce functionality smoothly
5. **Monitor usage** - Track fallback activations

Build tools with [Gantz](https://gantz.run), build reliable agents.

When primary fails, fallbacks save the day.

## Related reading

- [Agent Error Handling](/post/agent-error-handling/) - Handle errors gracefully
- [Agent Scaling](/post/agent-scaling/) - Scale with reliability
- [Agent Observability](/post/agent-observability/) - Monitor fallback health

---

*What fallback strategies do you use? Share your approaches.*
