+++
title = "Make MCP 10x Faster: Performance Optimization Guide"
image = "/images/mcp-performance.png"
date = 2025-11-08
description = "Optimize MCP server performance with connection pooling, async execution, caching, and profiling. Make your AI agent tools lightning fast."
draft = false
tags = ['mcp', 'performance', 'best-practices']
voice = false

[howto]
name = "Optimize MCP Server Performance"
totalTime = 30
[[howto.steps]]
name = "Profile current performance"
text = "Measure baseline latency and identify bottlenecks."
[[howto.steps]]
name = "Implement async execution"
text = "Use async/await to handle concurrent tool calls."
[[howto.steps]]
name = "Add connection pooling"
text = "Reuse database and HTTP connections."
[[howto.steps]]
name = "Enable caching"
text = "Cache frequently accessed data and tool responses."
[[howto.steps]]
name = "Optimize hot paths"
text = "Focus on the most frequently called tools."
+++


Your MCP server works. But it's slow.

500ms per tool call. Agents chain 10 calls. 5 seconds of waiting.

Users notice.

Here's how to make it fast.

## Measuring performance

Before optimizing, measure:

```python
import time
from functools import wraps
from prometheus_client import Histogram

tool_latency = Histogram(
    'mcp_tool_latency_seconds',
    'Tool call latency',
    ['tool'],
    buckets=[.01, .025, .05, .1, .25, .5, 1, 2.5, 5, 10]
)

def measure_latency(f):
    @wraps(f)
    def wrapper(*args, **kwargs):
        tool_name = kwargs.get('tool_name', f.__name__)
        start = time.perf_counter()

        try:
            return f(*args, **kwargs)
        finally:
            duration = time.perf_counter() - start
            tool_latency.labels(tool=tool_name).observe(duration)

    return wrapper

@measure_latency
def handle_tool_call(tool_name, params):
    # ... tool execution
    pass
```

Track these metrics:
- **P50 latency** - Typical response time
- **P99 latency** - Worst case (excluding outliers)
- **Throughput** - Requests per second
- **Error rate** - Failed calls percentage

## Common bottlenecks

### 1. Synchronous I/O

**Problem:**
```python
def read_multiple_files(paths):
    results = []
    for path in paths:
        with open(path) as f:  # Blocking
            results.append(f.read())
    return results
# 10 files × 50ms = 500ms
```

**Solution:**
```python
import asyncio
import aiofiles

async def read_multiple_files(paths):
    async def read_one(path):
        async with aiofiles.open(path) as f:
            return await f.read()

    results = await asyncio.gather(*[read_one(p) for p in paths])
    return results
# 10 files in parallel ≈ 50ms
```

### 2. No connection pooling

**Problem:**
```python
def query_database(sql):
    conn = psycopg2.connect(DATABASE_URL)  # New connection every call
    cursor = conn.cursor()
    cursor.execute(sql)
    result = cursor.fetchall()
    conn.close()
    return result
# Connection overhead: ~100ms per call
```

**Solution:**
```python
from psycopg2 import pool

connection_pool = pool.ThreadedConnectionPool(
    minconn=5,
    maxconn=20,
    dsn=DATABASE_URL
)

def query_database(sql):
    conn = connection_pool.getconn()
    try:
        cursor = conn.cursor()
        cursor.execute(sql)
        return cursor.fetchall()
    finally:
        connection_pool.putconn(conn)
# Reused connection: ~5ms per call
```

### 3. Repeated computations

**Problem:**
```python
def search_code(query, path):
    files = list_all_files(path)  # 200ms every call
    results = []
    for f in files:
        if matches(f, query):
            results.append(f)
    return results
```

**Solution:**
```python
from functools import lru_cache

@lru_cache(maxsize=100)
def list_all_files_cached(path):
    return list_all_files(path)

def search_code(query, path):
    files = list_all_files_cached(path)  # Cached after first call
    # ... rest of search
```

### 4. Large response serialization

**Problem:**
```python
def get_all_data():
    data = query_large_dataset()  # 10MB of data
    return json.dumps(data)  # 500ms to serialize
```

**Solution:**
```python
import orjson  # Faster JSON library

def get_all_data():
    data = query_large_dataset()
    return orjson.dumps(data)  # 50ms to serialize

# Or better - stream the response
def get_all_data_streaming():
    def generate():
        for chunk in query_large_dataset_chunked():
            yield orjson.dumps(chunk) + b'\n'
    return Response(generate(), mimetype='application/x-ndjson')
```

## Async MCP server

Use async for concurrent handling:

```python
from fastapi import FastAPI
from contextlib import asynccontextmanager
import asyncio

app = FastAPI()

# Async tool handlers
async def read_file_async(params):
    async with aiofiles.open(params["path"]) as f:
        return await f.read()

async def search_code_async(params):
    proc = await asyncio.create_subprocess_exec(
        'rg', params["query"], params.get("path", "."),
        stdout=asyncio.subprocess.PIPE
    )
    stdout, _ = await proc.communicate()
    return stdout.decode()

async def query_db_async(params):
    async with async_pool.acquire() as conn:
        result = await conn.fetch(params["sql"])
        return [dict(row) for row in result]

TOOLS = {
    "read_file": read_file_async,
    "search_code": search_code_async,
    "query_db": query_db_async,
}

@app.post("/mcp/tools/call")
async def call_tool(request: dict):
    tool = request["tool"]
    params = request.get("params", {})

    handler = TOOLS.get(tool)
    if not handler:
        return {"error": "Unknown tool"}

    result = await handler(params)
    return {"result": result}
```

## Connection pooling

### HTTP connections

```python
import httpx

# Global client with connection pooling
http_client = httpx.AsyncClient(
    limits=httpx.Limits(
        max_connections=100,
        max_keepalive_connections=20
    ),
    timeout=30.0
)

async def call_external_api(url, data):
    response = await http_client.post(url, json=data)
    return response.json()
```

### Database connections

```python
import asyncpg

async def create_pool():
    return await asyncpg.create_pool(
        DATABASE_URL,
        min_size=5,
        max_size=20,
        command_timeout=60
    )

pool = None

@app.on_event("startup")
async def startup():
    global pool
    pool = await create_pool()

@app.on_event("shutdown")
async def shutdown():
    await pool.close()
```

### Redis connections

```python
import aioredis

redis_pool = None

async def get_redis():
    global redis_pool
    if redis_pool is None:
        redis_pool = await aioredis.create_redis_pool(
            REDIS_URL,
            minsize=5,
            maxsize=20
        )
    return redis_pool
```

## Caching strategies

### In-memory LRU cache

```python
from cachetools import TTLCache

# Cache with 1000 items max, 5 minute TTL
cache = TTLCache(maxsize=1000, ttl=300)

async def read_file_cached(params):
    path = params["path"]

    if path in cache:
        return cache[path]

    content = await read_file_async(params)
    cache[path] = content
    return content
```

### Redis cache

```python
async def cached_tool_call(tool, params, ttl=300):
    cache_key = f"tool:{tool}:{hash(frozenset(params.items()))}"

    redis = await get_redis()

    # Check cache
    cached = await redis.get(cache_key)
    if cached:
        return json.loads(cached)

    # Execute and cache
    result = await TOOLS[tool](params)
    await redis.setex(cache_key, ttl, json.dumps(result))

    return result
```

## Parallel tool execution

When agent calls multiple tools, run in parallel:

```python
async def execute_tools_parallel(tool_calls: list):
    """Execute multiple tool calls concurrently."""
    tasks = []

    for call in tool_calls:
        tool = call["tool"]
        params = call.get("params", {})
        handler = TOOLS.get(tool)

        if handler:
            tasks.append(handler(params))

    results = await asyncio.gather(*tasks, return_exceptions=True)

    return [
        {"result": r} if not isinstance(r, Exception) else {"error": str(r)}
        for r in results
    ]
```

## Response streaming

For large outputs, stream instead of buffering:

```python
from fastapi.responses import StreamingResponse

@app.post("/mcp/tools/call")
async def call_tool(request: dict):
    tool = request["tool"]

    if tool == "search_code":
        async def generate():
            async for match in search_code_streaming(request["params"]):
                yield json.dumps(match) + "\n"

        return StreamingResponse(
            generate(),
            media_type="application/x-ndjson"
        )

    # Regular response for other tools
    result = await TOOLS[tool](request.get("params", {}))
    return {"result": result}
```

## Profiling

Find bottlenecks with profiling:

```python
import cProfile
import pstats
from io import StringIO

def profile_tool(tool_name, params, iterations=100):
    """Profile a tool's performance."""
    profiler = cProfile.Profile()

    profiler.enable()
    for _ in range(iterations):
        TOOLS[tool_name](params)
    profiler.disable()

    stream = StringIO()
    stats = pstats.Stats(profiler, stream=stream)
    stats.sort_stats('cumulative')
    stats.print_stats(20)

    print(stream.getvalue())

# Usage
profile_tool("search_code", {"query": "TODO", "path": "src/"})
```

## Quick setup with Gantz

[Gantz](https://gantz.run) includes performance optimizations:

```yaml
# gantz.yaml
name: my-mcp-server

performance:
  async: true
  connection_pool_size: 20
  cache:
    enabled: true
    ttl: 300
  timeout: 30

tools:
  - name: read_file
    cache: true  # Enable caching for this tool
    timeout: 5   # Tool-specific timeout
    # ...
```

## Benchmarking

Test performance before and after:

```python
import asyncio
import time
import statistics

async def benchmark_tool(tool, params, iterations=100):
    """Benchmark a tool's performance."""
    latencies = []

    for _ in range(iterations):
        start = time.perf_counter()
        await TOOLS[tool](params)
        latencies.append(time.perf_counter() - start)

    return {
        "min": min(latencies),
        "max": max(latencies),
        "mean": statistics.mean(latencies),
        "median": statistics.median(latencies),
        "p95": sorted(latencies)[int(len(latencies) * 0.95)],
        "p99": sorted(latencies)[int(len(latencies) * 0.99)]
    }

# Run benchmark
results = asyncio.run(benchmark_tool("search_code", {"query": "TODO"}))
print(f"P50: {results['median']*1000:.1f}ms")
print(f"P99: {results['p99']*1000:.1f}ms")
```

## Best practices

1. **Measure first** - Know your baseline before optimizing
2. **Async everything** - Blocking I/O kills performance
3. **Pool connections** - Reuse expensive resources
4. **Cache aggressively** - Repeated calls should be instant
5. **Stream large responses** - Don't buffer huge data
6. **Set timeouts** - Prevent slow tools from blocking
7. **Profile regularly** - Performance regresses over time

## Summary

Fast MCP servers need:

- **Async I/O** - Don't block on file/network operations
- **Connection pools** - Reuse database and HTTP connections
- **Smart caching** - Avoid repeated work
- **Parallel execution** - Run independent tools concurrently
- **Response streaming** - Don't buffer large outputs

The goal: sub-100ms tool calls. Your agents (and users) will thank you.

## Related reading

- [MCP Caching Strategies](/post/mcp-caching/) - Deep dive on caching
- [Agent Cost Optimization](/post/agent-cost-optimization/) - Reduce costs
- [Horizontal Scaling](/post/horizontal-scaling/) - Scale MCP servers

---

*What's your MCP server's P99 latency? Share your optimization wins.*
