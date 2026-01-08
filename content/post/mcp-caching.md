+++
title = "Speed Up AI Agents with MCP Response Caching"
image = "images/mcp-caching.webp"
date = 2025-11-13
description = "Implement caching for MCP tool responses. Reduce latency, cut API costs, and make your AI agents faster with smart caching strategies."
summary = "Learn how to implement caching for MCP tool responses using in-memory, Redis, or file-based storage solutions. This guide covers cache key generation, TTL configuration, invalidation strategies, and metrics monitoring to reduce latency by up to 90% and significantly cut API costs."
draft = false
tags = ['mcp', 'performance', 'architecture']
voice = false

[howto]
name = "Add Caching to MCP Tools"
totalTime = 20
[[howto.steps]]
name = "Identify cacheable tools"
text = "Determine which tool responses can be safely cached."
[[howto.steps]]
name = "Choose cache storage"
text = "Select in-memory, Redis, or file-based caching based on needs."
[[howto.steps]]
name = "Implement cache logic"
text = "Add caching middleware with proper key generation."
[[howto.steps]]
name = "Set TTL values"
text = "Configure appropriate expiration times for each tool."
[[howto.steps]]
name = "Add cache invalidation"
text = "Implement manual and automatic cache clearing when needed."
+++


Your agent calls the same tool with the same parameters. Again and again.

Each call takes 500ms. Each call costs money.

Caching fixes this.

## Why cache MCP responses?

AI agents are repetitive. They often:

- Read the same files multiple times
- Search for the same patterns repeatedly
- Query the same database rows
- Call the same APIs with identical parameters

Without caching:
- Every call hits the actual resource
- Latency adds up
- Costs multiply
- Resources get hammered

With caching:
- Repeated calls return instantly
- Costs stay flat
- Resources stay calm
- Agents feel faster

## What to cache

### Good candidates

**File reads** - Files don't change mid-conversation
```
read_file("config.json") → Cache for 5 minutes
```

**Search results** - Codebase doesn't change while agent works
```
search_code("function login") → Cache for 10 minutes
```

**API responses** - External data often stable
```
get_weather("NYC") → Cache for 30 minutes
```

**Database queries** - Reference data rarely changes
```
get_user_permissions(user_id) → Cache for 1 hour
```

### Bad candidates

**Write operations** - Never cache mutations
```
write_file("config.json", data) → Never cache
```

**Time-sensitive data** - Stale data is wrong data
```
get_stock_price("AAPL") → Don't cache (or very short TTL)
```

**User-specific real-time data** - Must be fresh
```
get_unread_messages(user_id) → Don't cache
```

**Random/unique operations** - Each call should differ
```
generate_uuid() → Never cache
```

## Caching strategies

### In-memory cache

Fastest option. Good for single-server deployments.

```python
from functools import lru_cache
from datetime import datetime, timedelta

class TTLCache:
    def __init__(self, ttl_seconds=300):
        self.cache = {}
        self.ttl = timedelta(seconds=ttl_seconds)

    def get(self, key):
        if key in self.cache:
            value, timestamp = self.cache[key]
            if datetime.now() - timestamp < self.ttl:
                return value
            del self.cache[key]
        return None

    def set(self, key, value):
        self.cache[key] = (value, datetime.now())

    def clear(self):
        self.cache.clear()

# Usage
cache = TTLCache(ttl_seconds=300)

def read_file_cached(path):
    cached = cache.get(f"file:{path}")
    if cached:
        return cached

    content = read_file(path)
    cache.set(f"file:{path}", content)
    return content
```

### Redis cache

For distributed systems with multiple servers.

```python
import redis
import json
import hashlib

class RedisCache:
    def __init__(self, host='localhost', port=6379, prefix='mcp'):
        self.redis = redis.Redis(host=host, port=port, decode_responses=True)
        self.prefix = prefix

    def _key(self, key):
        return f"{self.prefix}:{key}"

    def get(self, key):
        value = self.redis.get(self._key(key))
        if value:
            return json.loads(value)
        return None

    def set(self, key, value, ttl=300):
        self.redis.setex(
            self._key(key),
            ttl,
            json.dumps(value)
        )

    def delete(self, key):
        self.redis.delete(self._key(key))

    def clear_pattern(self, pattern):
        keys = self.redis.keys(self._key(pattern))
        if keys:
            self.redis.delete(*keys)
```

### File-based cache

For persistent caching across restarts.

```python
import os
import json
import hashlib
import time

class FileCache:
    def __init__(self, cache_dir=".cache", ttl=300):
        self.cache_dir = cache_dir
        self.ttl = ttl
        os.makedirs(cache_dir, exist_ok=True)

    def _path(self, key):
        hashed = hashlib.md5(key.encode()).hexdigest()
        return os.path.join(self.cache_dir, f"{hashed}.json")

    def get(self, key):
        path = self._path(key)
        if not os.path.exists(path):
            return None

        # Check TTL
        if time.time() - os.path.getmtime(path) > self.ttl:
            os.remove(path)
            return None

        with open(path) as f:
            return json.load(f)

    def set(self, key, value):
        path = self._path(key)
        with open(path, 'w') as f:
            json.dump(value, f)
```

## Implementation

### Cache key generation

Keys must be unique and deterministic:

```python
import hashlib
import json

def generate_cache_key(tool_name, params):
    """Generate unique cache key from tool and params."""
    # Sort params for consistent ordering
    sorted_params = json.dumps(params, sort_keys=True)
    key_string = f"{tool_name}:{sorted_params}"
    return hashlib.sha256(key_string.encode()).hexdigest()

# Examples:
# read_file({"path": "config.json"})
# → "a1b2c3d4..."

# search_code({"query": "TODO", "path": "src/"})
# → "e5f6g7h8..."
```

### Caching middleware

Add caching to your MCP server:

```python
from functools import wraps

cache = RedisCache()

# Per-tool TTL configuration
CACHE_CONFIG = {
    "read_file": {"enabled": True, "ttl": 300},
    "search_code": {"enabled": True, "ttl": 600},
    "list_files": {"enabled": True, "ttl": 60},
    "write_file": {"enabled": False},  # Never cache writes
    "run_command": {"enabled": False},  # Side effects
}

def cached_tool(tool_name):
    def decorator(f):
        @wraps(f)
        def wrapper(params):
            config = CACHE_CONFIG.get(tool_name, {"enabled": False})

            if not config.get("enabled"):
                return f(params)

            # Generate cache key
            cache_key = generate_cache_key(tool_name, params)

            # Check cache
            cached = cache.get(cache_key)
            if cached is not None:
                return {"result": cached, "cached": True}

            # Execute and cache
            result = f(params)
            cache.set(cache_key, result, ttl=config.get("ttl", 300))

            return {"result": result, "cached": False}
        return wrapper
    return decorator

@cached_tool("read_file")
def read_file(params):
    path = params["path"]
    with open(path) as f:
        return f.read()
```

### Cache invalidation

Clear cache when underlying data changes:

```python
class CacheAwareTools:
    def __init__(self, cache):
        self.cache = cache

    def write_file(self, params):
        path = params["path"]
        content = params["content"]

        # Write the file
        with open(path, 'w') as f:
            f.write(content)

        # Invalidate cache for this file
        cache_key = generate_cache_key("read_file", {"path": path})
        self.cache.delete(cache_key)

        # Also invalidate any search results that might include this file
        self.cache.clear_pattern("search_*")

        return {"success": True}
```

### Conditional caching

Cache based on response characteristics:

```python
def smart_cache(tool_name, params, result):
    """Only cache if result meets criteria."""

    # Don't cache errors
    if "error" in result:
        return False

    # Don't cache empty results
    if result.get("data") is None:
        return False

    # Don't cache large results (memory concern)
    if len(str(result)) > 100000:  # 100KB
        return False

    # Tool-specific rules
    if tool_name == "search_code":
        # Don't cache if too many results (probably wrong query)
        if len(result.get("matches", [])) > 1000:
            return False

    return True
```

## Cache warming

Pre-populate cache for common requests:

```python
async def warm_cache():
    """Pre-load common tool responses into cache."""

    common_files = [
        "package.json",
        "README.md",
        "src/index.ts",
        ".env.example"
    ]

    for file in common_files:
        try:
            result = read_file({"path": file})
            cache_key = generate_cache_key("read_file", {"path": file})
            cache.set(cache_key, result, ttl=600)
        except FileNotFoundError:
            pass

    print(f"Warmed cache with {len(common_files)} files")

# Run on server startup
@app.on_event("startup")
async def startup():
    await warm_cache()
```

## Metrics and monitoring

Track cache effectiveness:

```python
from prometheus_client import Counter, Histogram

cache_hits = Counter('mcp_cache_hits_total', 'Cache hits', ['tool'])
cache_misses = Counter('mcp_cache_misses_total', 'Cache misses', ['tool'])
cache_latency = Histogram('mcp_cache_latency_seconds', 'Cache lookup latency')

def cached_tool_with_metrics(tool_name):
    def decorator(f):
        @wraps(f)
        def wrapper(params):
            cache_key = generate_cache_key(tool_name, params)

            with cache_latency.time():
                cached = cache.get(cache_key)

            if cached is not None:
                cache_hits.labels(tool=tool_name).inc()
                return cached

            cache_misses.labels(tool=tool_name).inc()
            result = f(params)
            cache.set(cache_key, result)
            return result
        return wrapper
    return decorator
```

## Quick setup with Gantz

[Gantz](https://gantz.run) supports caching configuration:

```yaml
# gantz.yaml
name: my-mcp-server

cache:
  enabled: true
  type: memory  # or redis
  default_ttl: 300

tools:
  - name: read_file
    cache:
      enabled: true
      ttl: 600

  - name: search_code
    cache:
      enabled: true
      ttl: 300

  - name: run_command
    cache:
      enabled: false  # Never cache commands
```

## Best practices

### 1. Start with conservative TTLs

```python
# Start short, increase based on data
CACHE_TTL = {
    "read_file": 60,       # 1 minute initially
    "search_code": 120,    # 2 minutes
    "list_files": 30,      # 30 seconds
}

# After observing patterns, adjust:
# - File rarely changes? Increase to 10 min
# - Search results stale quickly? Decrease to 30 sec
```

### 2. Include version in cache keys

```python
CACHE_VERSION = "v1"

def generate_cache_key(tool_name, params):
    key_string = f"{CACHE_VERSION}:{tool_name}:{json.dumps(params, sort_keys=True)}"
    return hashlib.sha256(key_string.encode()).hexdigest()

# Bump version to invalidate all cache
# CACHE_VERSION = "v2"
```

### 3. Log cache behavior

```python
import logging

logger = logging.getLogger("cache")

def get_cached(key):
    result = cache.get(key)
    if result:
        logger.debug(f"Cache HIT: {key[:16]}...")
    else:
        logger.debug(f"Cache MISS: {key[:16]}...")
    return result
```

### 4. Handle cache failures gracefully

```python
def get_with_fallback(cache_key, fallback_fn):
    try:
        cached = cache.get(cache_key)
        if cached is not None:
            return cached
    except Exception as e:
        logger.warning(f"Cache error: {e}")
        # Continue to fallback

    # Cache miss or error - execute function
    result = fallback_fn()

    try:
        cache.set(cache_key, result)
    except Exception as e:
        logger.warning(f"Cache set error: {e}")

    return result
```

## Summary

Caching makes AI agents faster and cheaper:

1. **Identify cacheable tools** - Reads yes, writes no
2. **Choose storage** - Memory for simple, Redis for distributed
3. **Generate good keys** - Tool name + sorted params
4. **Set appropriate TTLs** - Start short, adjust based on data
5. **Invalidate on writes** - Keep cache consistent
6. **Monitor hit rates** - Measure effectiveness

A well-cached MCP server can cut response times by 90% and costs by half. The agent doesn't know the difference between cached and fresh - it just gets faster answers.

Start simple with in-memory caching. Move to Redis when you scale. Your agents will feel instant.

## Related reading

- [MCP Performance Optimization](/post/mcp-performance/) - More speed tips
- [Token Budgeting Strategies](/post/token-budgeting/) - Control costs
- [Agent Cost Optimization](/post/agent-cost-optimization/) - Cut costs 80%

---

*What's your cache hit rate? Share your caching strategies.*
