+++
title = "Why Your Agent Works Locally But Fails in Production"
date = 2025-12-15
description = "Debug common AI agent deployment issues: environment variables, file paths, network topology, rate limits, timeouts, and memory limits. Includes fixes and best practices."
image = "images/warrior-rain-city-02.webp"
draft = false
tags = ['deployment', 'debugging', 'best-practices']
+++


It worked on your machine. It doesn't work in production.

Classic.

AI agents have their own special reasons for this. Here's what's actually going wrong.

## The usual suspects

### 1. Environment variables aren't there

Local:
```bash
export OPENAI_API_KEY="sk-..."
export DATABASE_URL="postgres://localhost/dev"
```

Production:
```
Error: OPENAI_API_KEY not found
```

You forgot to set them. Or you set them wrong. Or they're in the wrong format.

```python
# This works locally
api_key = os.environ["OPENAI_API_KEY"]

# This crashes in production if not set
# KeyError: 'OPENAI_API_KEY'
```

**Fix:**

```python
# Fail fast with clear error
api_key = os.environ.get("OPENAI_API_KEY")
if not api_key:
    raise ValueError("OPENAI_API_KEY environment variable is required")
```

### 2. File paths are wrong

Local:
```python
config = open("./config.yaml")  # Works from project root
```

Production:
```
FileNotFoundError: ./config.yaml
```

Your working directory is different in production.

**Fix:**

```python
from pathlib import Path

# Relative to this file, not working directory
CONFIG_PATH = Path(__file__).parent / "config.yaml"
config = open(CONFIG_PATH)
```

### 3. Network is different

Local:
```
localhost:5432 → PostgreSQL ✓
localhost:6379 → Redis ✓
api.example.com → Internet ✓
```

Production:
```
localhost:5432 → Nothing (database is on different host)
db.internal:5432 → PostgreSQL (but you're still using localhost)
```

**Fix:**

```python
# Use environment variables for all hosts
DATABASE_HOST = os.environ.get("DATABASE_HOST", "localhost")
REDIS_HOST = os.environ.get("REDIS_HOST", "localhost")
```

### 4. Permissions are different

Local:
```bash
# You're running as yourself with full access
./script.sh  # Works
```

Production:
```bash
# Running as restricted user
./script.sh  # Permission denied
```

**Fix:**

```yaml
# Dockerfile
RUN chmod +x /app/scripts/*.sh
USER appuser  # Test with restricted user locally too
```

## Agent-specific problems

### 5. Tool binaries aren't installed

Your MCP tools call system binaries.

Local:
```yaml
- name: search
  script:
    shell: rg "{{query}}" .  # ripgrep installed
```

Production:
```
Command not found: rg
```

**Fix:**

```dockerfile
# Dockerfile
RUN apt-get update && apt-get install -y \
    ripgrep \
    jq \
    curl
```

Or use [Gantz](https://gantz.run) which handles tool dependencies.

### 6. Rate limits hit differently

Local:
```
You: Test one query
API: 200 OK
You: Works!
```

Production:
```
Users: 1000 queries/minute
API: 429 Too Many Requests
Agent: Crashes
```

**Fix:**

```python
import time
from functools import wraps

def rate_limited(max_per_minute):
    min_interval = 60.0 / max_per_minute
    last_call = [0]

    def decorator(func):
        @wraps(func)
        def wrapper(*args, **kwargs):
            elapsed = time.time() - last_call[0]
            if elapsed < min_interval:
                time.sleep(min_interval - elapsed)
            result = func(*args, **kwargs)
            last_call[0] = time.time()
            return result
        return wrapper
    return decorator

@rate_limited(max_per_minute=60)
def call_api(query):
    return api.search(query)
```

### 7. Timeouts are too short

Local:
```
Tool execution: 2 seconds (fast local disk)
Timeout: 30 seconds
Result: Success
```

Production:
```
Tool execution: 45 seconds (slow network storage)
Timeout: 30 seconds
Result: Timeout error
```

**Fix:**

```python
# Environment-aware timeouts
TIMEOUT = int(os.environ.get("TOOL_TIMEOUT", 30))

# Or dynamic based on operation
def get_timeout(operation):
    timeouts = {
        "quick_search": 10,
        "file_read": 30,
        "large_query": 120,
        "external_api": 60
    }
    return timeouts.get(operation, 30)
```

### 8. Memory limits

Local:
```
RAM: 32GB
Load entire codebase: Works
```

Production:
```
Container RAM: 512MB
Load entire codebase: OOM Killed
```

**Fix:**

```python
# Stream instead of load all
def search_files(pattern):
    # Bad: loads everything
    # all_files = list(Path(".").rglob("*"))

    # Good: streams results
    for file in Path(".").rglob("*"):
        if pattern in file.read_text():
            yield file
```

### 9. Concurrent requests

Local:
```
You: One request at a time
Agent: Handles it fine
```

Production:
```
Users: 50 concurrent requests
Agent: Race conditions, shared state corruption
```

**Fix:**

```python
# Don't use global mutable state
class Agent:
    def __init__(self):
        self.context = {}  # Instance state, not global

# Or use proper locks
import threading

class SharedResource:
    def __init__(self):
        self.lock = threading.Lock()
        self.data = {}

    def update(self, key, value):
        with self.lock:
            self.data[key] = value
```

### 10. Different model behavior

Local:
```
Model: gpt-4-turbo-preview (latest)
Response: Perfect
```

Production:
```
Model: gpt-4-turbo-preview (but it's a different version now!)
Response: Slightly different, breaks your parsing
```

**Fix:**

```python
# Pin model versions
MODEL = "gpt-4-0125-preview"  # Specific version, not "latest"

# And handle response variations
def parse_response(response):
    try:
        return json.loads(response)
    except json.JSONDecodeError:
        # Model didn't return JSON, try to extract it
        match = re.search(r'\{.*\}', response, re.DOTALL)
        if match:
            return json.loads(match.group())
        raise
```

### 11. Cold starts

Local:
```
Agent: Already running, warm
First request: 100ms
```

Production (serverless):
```
Agent: Cold, needs to initialize
First request: 5000ms (timeout!)
```

**Fix:**

```python
# Lazy loading for heavy dependencies
_model = None

def get_model():
    global _model
    if _model is None:
        _model = load_model()  # Only on first call
    return _model

# Or pre-warm in background
@app.on_event("startup")
async def startup():
    asyncio.create_task(warm_up_agent())
```

### 12. Log verbosity

Local:
```python
logging.basicConfig(level=logging.DEBUG)
# See everything, debug easily
```

Production:
```python
logging.basicConfig(level=logging.ERROR)
# See nothing, debug impossible
```

**Fix:**

```python
# Structured logging with appropriate levels
import structlog

logger = structlog.get_logger()

def handle_tool_call(tool, params):
    logger.info("tool_call_start", tool=tool, params=params)

    try:
        result = execute(tool, params)
        logger.info("tool_call_success", tool=tool, result_size=len(str(result)))
        return result
    except Exception as e:
        logger.error("tool_call_failed", tool=tool, error=str(e), exc_info=True)
        raise
```

## The checklist

Before deploying, verify:

### Environment
- [ ] All environment variables set
- [ ] Correct values (not copy-paste of local values)
- [ ] Secrets in secure storage (not in code)

### Dependencies
- [ ] All system binaries installed
- [ ] Correct versions of packages
- [ ] No dev-only dependencies missing

### Network
- [ ] Correct hostnames for databases, APIs
- [ ] Firewall allows outbound connections
- [ ] DNS resolves correctly

### Resources
- [ ] Adequate memory limits
- [ ] Adequate CPU
- [ ] Disk space for temp files

### Timeouts
- [ ] API timeouts appropriate for production latency
- [ ] Tool execution timeouts realistic
- [ ] Request timeouts configured

### Concurrency
- [ ] No shared mutable state
- [ ] Connection pools sized correctly
- [ ] Rate limiting in place

### Observability
- [ ] Logging configured
- [ ] Metrics exposed
- [ ] Errors reported

## Testing for production

### Test with production-like config

```python
# tests/conftest.py
import pytest

@pytest.fixture
def production_like_env(monkeypatch):
    """Simulate production environment."""
    # Restrictive timeouts
    monkeypatch.setenv("TOOL_TIMEOUT", "5")
    # Memory pressure
    monkeypatch.setenv("MAX_CONTEXT_SIZE", "1000")
    # No debug mode
    monkeypatch.setenv("DEBUG", "false")
```

### Test failure cases

```python
def test_handles_api_timeout():
    with mock.patch("api.call", side_effect=TimeoutError):
        result = agent.run("do something")
        assert result.status == "error"
        assert "timeout" in result.message.lower()

def test_handles_missing_tool():
    agent = Agent(tools=[])  # No tools
    result = agent.run("use a tool")
    assert result.status == "error"
    assert "tool" in result.message.lower()
```

### Load testing

```python
import asyncio
import aiohttp

async def load_test(n_requests=100, concurrency=10):
    semaphore = asyncio.Semaphore(concurrency)

    async def single_request():
        async with semaphore:
            async with aiohttp.ClientSession() as session:
                start = time.time()
                async with session.post("/agent", json={"query": "test"}) as resp:
                    duration = time.time() - start
                    return resp.status, duration

    results = await asyncio.gather(*[single_request() for _ in range(n_requests)])

    success = sum(1 for status, _ in results if status == 200)
    avg_time = sum(d for _, d in results) / len(results)

    print(f"Success rate: {success}/{n_requests}")
    print(f"Average time: {avg_time:.2f}s")
```

## Debugging production

### Add request tracing

```python
import uuid

class Agent:
    def run(self, query, request_id=None):
        request_id = request_id or str(uuid.uuid4())

        logger.info("request_start", request_id=request_id, query=query[:100])

        try:
            result = self._execute(query)
            logger.info("request_success", request_id=request_id)
            return result
        except Exception as e:
            logger.error("request_failed", request_id=request_id, error=str(e))
            raise
```

### Capture failing inputs

```python
def run_with_capture(self, query):
    try:
        return self.run(query)
    except Exception as e:
        # Save failing case for reproduction
        with open(f"/var/log/agent/failed_{time.time()}.json", "w") as f:
            json.dump({
                "query": query,
                "error": str(e),
                "traceback": traceback.format_exc(),
                "context": self.context
            }, f)
        raise
```

### Health check endpoint

```python
@app.get("/health")
async def health():
    checks = {
        "database": check_database(),
        "api_key": bool(os.environ.get("OPENAI_API_KEY")),
        "tools": check_tools_available(),
        "memory": get_memory_usage() < 90,  # percent
    }

    healthy = all(checks.values())

    return {
        "status": "healthy" if healthy else "unhealthy",
        "checks": checks
    }
```

## Summary

Your agent fails in production because:

**Environment:**
- Missing env vars
- Wrong file paths
- Different network topology
- Restricted permissions

**Scale:**
- Rate limits hit
- Timeouts too short
- Memory limits exceeded
- Concurrent request issues

**Dependencies:**
- Missing binaries
- Version mismatches
- Model behavior differences

**Fix it by:**
- Using environment variables for everything configurable
- Testing with production-like constraints
- Adding comprehensive logging
- Implementing proper error handling
- Load testing before deploy

The agent isn't broken. The environment is different.

## Related reading

- [Horizontal Scaling for Stateful Agents](/post/horizontal-scaling/) - Scale without losing conversations
- [Running AI Agents in Docker](/post/docker-agents/) - Containerize your agents
- [Error Recovery Patterns for AI Agents](/post/error-recovery/) - Handle failures gracefully

---

*What's the weirdest production-only bug you've encountered with AI agents?*
