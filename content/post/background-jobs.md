+++
title = "Background Jobs for Long-Running Tasks"
date = 2025-12-30
description = "Handle long-running AI agent tasks without HTTP timeouts. Implement background jobs, job queues, and status polling for reliable execution."
summary = "User asks 'run the full test suite' and your agent starts - then the request times out after 30 seconds. Long-running tasks need background processing. Learn job queues that persist work, background workers that execute reliably, status polling so users can check progress, and webhooks for completion notifications. Never lose work to a timeout again."
image = "images/city-drones-crowd.webp"
draft = false
tags = ['architecture', 'scaling', 'patterns']
voice = false
+++


User: "Run the full test suite"

Your agent starts running tests.

30 seconds pass. HTTP times out. Connection drops.

User: "Did it work?"

You don't know. The tests are still running somewhere. Maybe.

Long-running tasks need background jobs. Here's how to build them.

## The problem

HTTP requests have timeouts:

```text
Browser default: 30-60 seconds
Load balancer: 60 seconds
API gateway: 29 seconds (AWS)
User patience: 10 seconds
```

Some agent tasks take longer:

```text
Run full test suite: 2-10 minutes
Build project: 1-5 minutes
Run migrations: 30 seconds - 5 minutes
Deploy to production: 1-10 minutes
Large refactor: Variable
Generate report: 30 seconds - 2 minutes
```

Synchronous doesn't work.

## The solution: Background jobs

```text
Synchronous (broken):
User → Agent → Long task → ... → Timeout 💥

Background (works):
User → Agent → Queue job → "Started, I'll let you know"
                    ↓
              Worker picks up
                    ↓
              Runs task (minutes)
                    ↓
              Notifies user "Done!"
```

The request returns immediately. Work happens in the background.

## Architecture

```text
┌─────────┐     ┌─────────┐     ┌─────────────┐
│  User   │────▶│  Agent  │────▶│    Queue    │
└─────────┘     └─────────┘     └──────┬──────┘
     ▲                                 │
     │                                 ▼
     │                          ┌─────────────┐
     │                          │   Worker    │
     │                          └──────┬──────┘
     │                                 │
     │          ┌─────────────┐        │
     └──────────│   Status    │◀───────┘
                │   Store     │
                └─────────────┘
```

Components:
- **Agent**: Accepts request, queues job, returns job ID
- **Queue**: Holds pending jobs (Redis, RabbitMQ, SQS)
- **Worker**: Picks up jobs, executes them
- **Status store**: Tracks job progress

## Basic implementation

### The job queue

```python
import redis
import json
import uuid
from datetime import datetime

class JobQueue:
    def __init__(self, redis_url="redis://localhost:6379"):
        self.redis = redis.from_url(redis_url)
        self.queue_name = "agent_jobs"

    def enqueue(self, task_type: str, params: dict) -> str:
        """Add job to queue, return job ID"""
        job_id = str(uuid.uuid4())

        job = {
            "id": job_id,
            "type": task_type,
            "params": params,
            "status": "pending",
            "created_at": datetime.utcnow().isoformat(),
        }

        # Store job status
        self.redis.hset(f"job:{job_id}", mapping={
            "status": "pending",
            "created_at": job["created_at"],
            "type": task_type,
        })

        # Add to queue
        self.redis.lpush(self.queue_name, json.dumps(job))

        return job_id

    def dequeue(self) -> dict:
        """Get next job from queue (blocking)"""
        _, job_data = self.redis.brpop(self.queue_name)
        return json.loads(job_data)

    def get_status(self, job_id: str) -> dict:
        """Check job status"""
        return self.redis.hgetall(f"job:{job_id}")

    def update_status(self, job_id: str, status: str, result: str = None):
        """Update job status"""
        updates = {
            "status": status,
            "updated_at": datetime.utcnow().isoformat(),
        }
        if result:
            updates["result"] = result

        self.redis.hset(f"job:{job_id}", mapping=updates)
```

### The worker

```python
import subprocess
import traceback

class Worker:
    def __init__(self, queue: JobQueue):
        self.queue = queue
        self.handlers = {
            "run_tests": self.run_tests,
            "build": self.build,
            "deploy": self.deploy,
            "refactor": self.refactor,
        }

    def run_forever(self):
        """Main worker loop"""
        print("Worker started, waiting for jobs...")

        while True:
            job = self.queue.dequeue()
            self.process_job(job)

    def process_job(self, job: dict):
        job_id = job["id"]
        task_type = job["type"]

        print(f"Processing job {job_id}: {task_type}")

        try:
            self.queue.update_status(job_id, "running")

            handler = self.handlers.get(task_type)
            if not handler:
                raise ValueError(f"Unknown task type: {task_type}")

            result = handler(job["params"])

            self.queue.update_status(job_id, "completed", result)
            print(f"Job {job_id} completed")

        except Exception as e:
            error = f"{str(e)}\n{traceback.format_exc()}"
            self.queue.update_status(job_id, "failed", error)
            print(f"Job {job_id} failed: {e}")

    def run_tests(self, params: dict) -> str:
        """Run test suite"""
        cmd = params.get("command", "npm test")
        timeout = params.get("timeout", 600)  # 10 min default

        result = subprocess.run(
            cmd,
            shell=True,
            capture_output=True,
            text=True,
            timeout=timeout
        )

        return f"Exit code: {result.returncode}\n\nOutput:\n{result.stdout}\n\nErrors:\n{result.stderr}"

    def build(self, params: dict) -> str:
        """Build project"""
        cmd = params.get("command", "npm run build")
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
        return result.stdout + result.stderr

    def deploy(self, params: dict) -> str:
        """Deploy to environment"""
        # Your deployment logic
        pass

    def refactor(self, params: dict) -> str:
        """Run large refactor"""
        # Your refactor logic
        pass
```

### The agent integration

```python
class AgentWithBackgroundJobs:
    def __init__(self, llm, queue: JobQueue):
        self.llm = llm
        self.queue = queue
        self.tools = self.build_tools()

    def build_tools(self):
        return [
            {
                "type": "function",
                "function": {
                    "name": "run_tests_background",
                    "description": "Run test suite in background. Returns job ID for tracking.",
                    "parameters": {
                        "type": "object",
                        "properties": {
                            "command": {
                                "type": "string",
                                "description": "Test command (default: npm test)"
                            }
                        }
                    }
                }
            },
            {
                "type": "function",
                "function": {
                    "name": "check_job_status",
                    "description": "Check status of a background job",
                    "parameters": {
                        "type": "object",
                        "properties": {
                            "job_id": {"type": "string"}
                        },
                        "required": ["job_id"]
                    }
                }
            }
        ]

    def execute_tool(self, name: str, args: dict) -> str:
        if name == "run_tests_background":
            job_id = self.queue.enqueue("run_tests", args)
            return f"Tests started. Job ID: {job_id}\n\nUse check_job_status to monitor progress."

        if name == "check_job_status":
            status = self.queue.get_status(args["job_id"])
            if not status:
                return "Job not found"

            response = f"Status: {status.get('status', 'unknown')}"
            if status.get("result"):
                response += f"\n\nResult:\n{status['result']}"
            return response

        return "Unknown tool"
```

## Conversation flow

```text
User: "Run the full test suite"

Agent: 🔧 run_tests_background({"command": "npm test"})

"I've started the test suite in the background.
Job ID: a1b2c3d4-e5f6-7890-abcd-ef1234567890

I'll check on it in a moment, or you can ask me for the status."

[30 seconds later]

User: "Are the tests done?"

Agent: 🔧 check_job_status({"job_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890"})

"Tests completed! Here are the results:

✓ 47 tests passed
✗ 2 tests failed

Failures:
- test_auth.py::test_login_timeout
- test_api.py::test_rate_limit

Want me to look at the failures?"
```

## Progress updates

For long tasks, track progress:

```python
class ProgressTracker:
    def __init__(self, redis_client, job_id: str):
        self.redis = redis_client
        self.job_id = job_id

    def update(self, progress: int, message: str):
        """Update progress (0-100) with message"""
        self.redis.hset(f"job:{self.job_id}", mapping={
            "progress": progress,
            "progress_message": message,
            "updated_at": datetime.utcnow().isoformat()
        })

# In worker:
def run_tests(self, params: dict) -> str:
    tracker = ProgressTracker(self.redis, params["job_id"])

    tracker.update(0, "Starting tests...")
    # discover tests
    tracker.update(10, "Found 47 tests")
    # run tests
    tracker.update(50, "Running tests... 23/47")
    tracker.update(100, "Tests complete")

    return results
```

Agent can report progress:

```text
Agent: "Tests are 50% complete. 23 of 47 tests done."
```

## Notifications

Don't make users poll. Notify them.

### Option 1: Webhooks

```python
class NotifyingWorker(Worker):
    def process_job(self, job: dict):
        result = super().process_job(job)

        # Notify via webhook
        if job.get("webhook_url"):
            requests.post(job["webhook_url"], json={
                "job_id": job["id"],
                "status": "completed",
                "result": result
            })
```

### Option 2: WebSocket

```python
# Server
from fastapi import WebSocket

connected_clients = {}

@app.websocket("/ws/{session_id}")
async def websocket_endpoint(websocket: WebSocket, session_id: str):
    await websocket.accept()
    connected_clients[session_id] = websocket

    try:
        while True:
            await websocket.receive_text()
    except:
        del connected_clients[session_id]

# When job completes
async def notify_completion(session_id: str, job_id: str, result: str):
    if session_id in connected_clients:
        await connected_clients[session_id].send_json({
            "type": "job_complete",
            "job_id": job_id,
            "result": result
        })
```

### Option 3: Server-Sent Events

```python
from fastapi import FastAPI
from fastapi.responses import StreamingResponse
import asyncio

@app.get("/jobs/{job_id}/stream")
async def stream_job_status(job_id: str):
    async def event_stream():
        while True:
            status = queue.get_status(job_id)

            yield f"data: {json.dumps(status)}\n\n"

            if status.get("status") in ["completed", "failed"]:
                break

            await asyncio.sleep(2)

    return StreamingResponse(
        event_stream(),
        media_type="text/event-stream"
    )
```

## Error handling

Background jobs fail differently:

```python
class RobustWorker(Worker):
    MAX_RETRIES = 3

    def process_job(self, job: dict):
        job_id = job["id"]
        retries = job.get("retries", 0)

        try:
            self.queue.update_status(job_id, "running")
            result = self.execute(job)
            self.queue.update_status(job_id, "completed", result)

        except RetryableError as e:
            # Transient error - retry
            if retries < self.MAX_RETRIES:
                job["retries"] = retries + 1
                self.queue.enqueue_retry(job, delay=30 * (retries + 1))
                self.queue.update_status(job_id, "retrying", str(e))
            else:
                self.queue.update_status(job_id, "failed", f"Max retries exceeded: {e}")

        except Exception as e:
            # Permanent failure
            self.queue.update_status(job_id, "failed", str(e))
            self.notify_failure(job_id, e)
```

## Timeouts and cancellation

```python
class CancellableWorker(Worker):
    def __init__(self, queue):
        super().__init__(queue)
        self.current_job = None
        self.current_process = None

    def process_job(self, job: dict):
        self.current_job = job["id"]

        try:
            # Check for cancellation before starting
            if self.is_cancelled(job["id"]):
                return

            # Run with timeout
            result = self.run_with_timeout(job, timeout=600)

            # Check cancellation after completion
            if not self.is_cancelled(job["id"]):
                self.queue.update_status(job["id"], "completed", result)

        finally:
            self.current_job = None
            self.current_process = None

    def is_cancelled(self, job_id: str) -> bool:
        status = self.queue.get_status(job_id)
        return status.get("status") == "cancelled"

    def run_with_timeout(self, job: dict, timeout: int):
        import signal

        def handle_timeout(signum, frame):
            raise TimeoutError("Job exceeded time limit")

        signal.signal(signal.SIGALRM, handle_timeout)
        signal.alarm(timeout)

        try:
            return self.execute(job)
        finally:
            signal.alarm(0)

# API endpoint to cancel
@app.post("/jobs/{job_id}/cancel")
async def cancel_job(job_id: str):
    queue.update_status(job_id, "cancelled")
    return {"status": "cancellation requested"}
```

## Full API example

```python
from fastapi import FastAPI, BackgroundTasks
from pydantic import BaseModel

app = FastAPI()
queue = JobQueue()

class JobRequest(BaseModel):
    type: str
    params: dict = {}

class JobResponse(BaseModel):
    job_id: str
    status: str

@app.post("/jobs", response_model=JobResponse)
async def create_job(request: JobRequest):
    job_id = queue.enqueue(request.type, request.params)
    return JobResponse(job_id=job_id, status="pending")

@app.get("/jobs/{job_id}")
async def get_job(job_id: str):
    status = queue.get_status(job_id)
    if not status:
        raise HTTPException(404, "Job not found")
    return status

@app.post("/jobs/{job_id}/cancel")
async def cancel_job(job_id: str):
    queue.update_status(job_id, "cancelled")
    return {"status": "cancelled"}

@app.get("/jobs")
async def list_jobs(status: str = None, limit: int = 10):
    return queue.list_jobs(status=status, limit=limit)
```

## Running workers

### Single worker

```bash
python worker.py
```

### Multiple workers (for parallel jobs)

```bash
# Terminal 1
python worker.py

# Terminal 2
python worker.py

# Terminal 3
python worker.py
```

### With Docker Compose

```yaml
# docker-compose.yml
services:
  agent:
    build: .
    ports:
      - "8000:8000"

  worker:
    build: .
    command: python worker.py
    deploy:
      replicas: 3  # 3 parallel workers

  redis:
    image: redis:alpine
```

## Implementation with Gantz

Using [Gantz](https://gantz.run), you can expose background job tools:

```yaml
# gantz.yaml
tools:
  - name: run_tests
    description: Run tests in background. Returns job ID.
    parameters:
      - name: command
        type: string
        default: "npm test"
    script:
      shell: |
        job_id=$(uuidgen)
        echo '{"type":"run_tests","command":"{{command}}"}' | redis-cli lpush jobs -
        echo "Job started: $job_id"

  - name: check_job
    description: Check background job status
    parameters:
      - name: job_id
        type: string
        required: true
    script:
      shell: redis-cli hgetall "job:{{job_id}}"

  - name: cancel_job
    description: Cancel a background job
    parameters:
      - name: job_id
        type: string
        required: true
    script:
      shell: redis-cli hset "job:{{job_id}}" status cancelled
```

## Summary

Background jobs for agents:

| Component | Purpose |
|-----------|---------|
| Queue | Hold pending jobs |
| Worker | Execute jobs |
| Status store | Track progress |
| Notifications | Tell user when done |

When to use background jobs:
- Tests (> 30 seconds)
- Builds
- Deployments
- Large refactors
- Report generation
- Any task > user patience

Pattern:
1. Agent queues job
2. Returns job ID immediately
3. Worker processes in background
4. User can check status
5. Notification when complete

Don't make users wait. Queue it.

## Related reading

- [Horizontal Scaling for Stateful Agents](/post/horizontal-scaling/) - Managing state at scale
- [Running AI Agents in Docker](/post/docker-agents/) - Container deployment strategies
- [Error Recovery Patterns for AI Agents](/post/error-recovery/) - Handling job failures

---

*How do you handle long-running tasks in your agents?*
