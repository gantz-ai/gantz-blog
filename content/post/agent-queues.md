+++
title = "Agent Job Queues: Scale AI Workloads"
image = "images/agent-queues.webp"
date = 2025-11-17
description = "Build job queues for AI agents. Handle high-volume workloads, manage priorities, and scale agent processing using MCP tools."
draft = false
tags = ['mcp', 'architecture', 'scaling']
voice = false

[howto]
name = "Build Agent Job Queues"
totalTime = 35
[[howto.steps]]
name = "Design queue architecture"
text = "Create queue structure for different job types."
[[howto.steps]]
name = "Implement job processing"
text = "Build workers that process jobs with agents."
[[howto.steps]]
name = "Add priority handling"
text = "Implement priority queues for urgent jobs."
[[howto.steps]]
name = "Build monitoring"
text = "Track queue depth, processing time, and failures."
[[howto.steps]]
name = "Handle failures"
text = "Implement retry logic and dead letter handling."
+++


One agent handles one request. What about 10,000?

Job queues. Background processing. Scalable AI.

Here's how to build it.

## Why job queues?

Direct agent calls work for:
- Interactive conversations
- Real-time responses
- Single user requests

Job queues work for:
- Batch processing
- High volume workloads
- Long-running tasks
- Background operations
- Rate-limited APIs

## The architecture

```
┌───────────┐    ┌───────────┐    ┌───────────┐
│  Clients  │───▶│   Queue   │───▶│  Workers  │
│ (APIs,    │    │ (Redis,   │    │ (Agents)  │
│  Webhooks)│    │  SQS)     │    │           │
└───────────┘    └───────────┘    └───────────┘
                       │
                ┌──────▼──────┐
                │  Results    │
                │  Store      │
                └─────────────┘
```

## Step 1: Queue infrastructure

Using [Gantz](https://gantz.run):

```yaml
# gantz.yaml
name: agent-queue

tools:
  - name: enqueue_job
    description: Add a job to the queue
    parameters:
      - name: queue_name
        type: string
        required: true
      - name: job_type
        type: string
        required: true
      - name: payload
        type: string
        required: true
      - name: priority
        type: integer
        default: 5
        description: "1-10, higher is more urgent"
    script:
      command: python
      args: ["scripts/enqueue.py", "{{queue_name}}", "{{job_type}}", "{{priority}}"]
      stdin: "{{payload}}"

  - name: dequeue_job
    description: Get the next job from a queue
    parameters:
      - name: queue_name
        type: string
        required: true
      - name: timeout
        type: integer
        default: 30
    script:
      command: python
      args: ["scripts/dequeue.py", "{{queue_name}}", "{{timeout}}"]

  - name: complete_job
    description: Mark a job as completed
    parameters:
      - name: job_id
        type: string
        required: true
      - name: result
        type: string
    script:
      command: python
      args: ["scripts/complete_job.py", "{{job_id}}"]
      stdin: "{{result}}"

  - name: fail_job
    description: Mark a job as failed
    parameters:
      - name: job_id
        type: string
        required: true
      - name: error
        type: string
        required: true
      - name: retry
        type: boolean
        default: true
    script:
      command: python
      args: ["scripts/fail_job.py", "{{job_id}}", "{{error}}", "{{retry}}"]

  - name: get_job_status
    description: Get status of a job
    parameters:
      - name: job_id
        type: string
        required: true
    script:
      command: python
      args: ["scripts/get_status.py", "{{job_id}}"]

  - name: get_queue_stats
    description: Get queue statistics
    parameters:
      - name: queue_name
        type: string
    script:
      command: python
      args: ["scripts/queue_stats.py", "{{queue_name}}"]
```

Queue management script:

```python
# scripts/enqueue.py
import sys
import json
import redis
import uuid
from datetime import datetime

def enqueue_job(queue_name: str, job_type: str, payload: str, priority: int) -> dict:
    """Add a job to the queue."""

    r = redis.Redis(host='localhost', port=6379, db=0)

    job = {
        "id": str(uuid.uuid4()),
        "type": job_type,
        "payload": payload,
        "priority": priority,
        "status": "pending",
        "created_at": datetime.utcnow().isoformat(),
        "attempts": 0
    }

    # Use sorted set for priority queue
    # Score = timestamp - priority * 1000 (higher priority = lower score = processed first)
    score = datetime.utcnow().timestamp() - (priority * 1000)
    r.zadd(f"queue:{queue_name}", {json.dumps(job): score})

    # Store job details
    r.hset(f"job:{job['id']}", mapping=job)

    return job

if __name__ == "__main__":
    queue_name = sys.argv[1]
    job_type = sys.argv[2]
    priority = int(sys.argv[3]) if len(sys.argv) > 3 else 5
    payload = sys.stdin.read()

    job = enqueue_job(queue_name, job_type, payload, priority)
    print(json.dumps(job, indent=2))
```

Dequeue script:

```python
# scripts/dequeue.py
import sys
import json
import redis
from datetime import datetime

def dequeue_job(queue_name: str, timeout: int = 30) -> dict:
    """Get the next job from the queue."""

    r = redis.Redis(host='localhost', port=6379, db=0)

    # Get job with lowest score (highest priority, oldest)
    result = r.bzpopmin(f"queue:{queue_name}", timeout)

    if not result:
        return None

    _, job_data, score = result
    job = json.loads(job_data)

    # Update job status
    job["status"] = "processing"
    job["started_at"] = datetime.utcnow().isoformat()
    job["attempts"] += 1

    r.hset(f"job:{job['id']}", mapping={
        "status": "processing",
        "started_at": job["started_at"],
        "attempts": job["attempts"]
    })

    # Add to processing set (for monitoring)
    r.sadd(f"processing:{queue_name}", job["id"])

    return job

if __name__ == "__main__":
    queue_name = sys.argv[1]
    timeout = int(sys.argv[2]) if len(sys.argv) > 2 else 30

    job = dequeue_job(queue_name, timeout)
    if job:
        print(json.dumps(job, indent=2))
    else:
        print(json.dumps({"status": "empty"}))
```

```bash
gantz run --auth
```

## Step 2: Agent workers

```python
import anthropic
import json
import redis
import signal
import sys
from typing import Dict, Callable

MCP_URL = "https://agent-queue.gantz.run/sse"
MCP_TOKEN = "gtz_abc123"

client = anthropic.Anthropic()

class AgentWorker:
    """Worker that processes jobs using AI agents."""

    def __init__(self, queue_name: str, job_handlers: Dict[str, Callable]):
        self.queue_name = queue_name
        self.handlers = job_handlers
        self.redis = redis.Redis(host='localhost', port=6379, db=0)
        self.running = False

    def start(self):
        """Start processing jobs."""
        self.running = True
        print(f"Worker started for queue: {self.queue_name}")

        # Handle graceful shutdown
        signal.signal(signal.SIGTERM, self.stop)
        signal.signal(signal.SIGINT, self.stop)

        while self.running:
            try:
                self.process_next_job()
            except Exception as e:
                print(f"Worker error: {e}")

    def stop(self, signum=None, frame=None):
        """Stop the worker gracefully."""
        print("Stopping worker...")
        self.running = False

    def process_next_job(self):
        """Get and process the next job."""

        # Dequeue job
        result = self.redis.bzpopmin(f"queue:{self.queue_name}", 5)

        if not result:
            return  # No job available

        _, job_data, score = result
        job = json.loads(job_data)

        print(f"Processing job {job['id']} (type: {job['type']})")

        try:
            # Get handler for job type
            handler = self.handlers.get(job['type'], self.default_handler)

            # Process job
            result = handler(job)

            # Mark complete
            self.complete_job(job['id'], result)
            print(f"Job {job['id']} completed")

        except Exception as e:
            # Handle failure
            self.fail_job(job, str(e))
            print(f"Job {job['id']} failed: {e}")

    def default_handler(self, job: dict) -> str:
        """Default handler uses generic AI agent."""

        response = client.messages.create(
            model="claude-sonnet-4-20250514",
            max_tokens=4096,
            system=f"""You are processing a background job.
            Job type: {job['type']}
            Process the job payload and return the result.""",
            messages=[{
                "role": "user",
                "content": f"Process this job:\n{job['payload']}"
            }],
            tools=[{"type": "mcp", "server_url": MCP_URL, "token": MCP_TOKEN}]
        )

        for content in response.content:
            if hasattr(content, 'text'):
                return content.text

        return ""

    def complete_job(self, job_id: str, result: str):
        """Mark job as completed."""
        self.redis.hset(f"job:{job_id}", mapping={
            "status": "completed",
            "result": result,
            "completed_at": datetime.utcnow().isoformat()
        })
        self.redis.srem(f"processing:{self.queue_name}", job_id)

    def fail_job(self, job: dict, error: str):
        """Handle job failure with retry logic."""
        job_id = job['id']
        attempts = job.get('attempts', 0)

        if attempts < 3:
            # Retry with exponential backoff
            delay = 2 ** attempts
            priority = job.get('priority', 5) + 1  # Slight priority boost

            job['status'] = 'retry'
            job['last_error'] = error

            # Re-enqueue with delay
            score = datetime.utcnow().timestamp() + delay - (priority * 1000)
            self.redis.zadd(f"queue:{self.queue_name}", {json.dumps(job): score})

        else:
            # Move to dead letter queue
            self.redis.hset(f"job:{job_id}", mapping={
                "status": "failed",
                "error": error,
                "failed_at": datetime.utcnow().isoformat()
            })
            self.redis.lpush("dlq:jobs", json.dumps(job))

        self.redis.srem(f"processing:{self.queue_name}", job_id)
```

## Step 3: Specialized job handlers

```python
def create_ai_handler(system_prompt: str) -> Callable:
    """Create a job handler with custom AI instructions."""

    def handler(job: dict) -> str:
        response = client.messages.create(
            model="claude-sonnet-4-20250514",
            max_tokens=4096,
            system=system_prompt,
            messages=[{
                "role": "user",
                "content": job['payload']
            }],
            tools=[{"type": "mcp", "server_url": MCP_URL, "token": MCP_TOKEN}]
        )

        for content in response.content:
            if hasattr(content, 'text'):
                return content.text

        return ""

    return handler

# Create handlers for different job types
code_review_handler = create_ai_handler("""
You are a code reviewer processing pull requests.
Review the code for:
- Security issues
- Bugs and errors
- Performance problems
- Style violations
Provide constructive feedback.
""")

document_handler = create_ai_handler("""
You process documents and extract structured data.
Output clean JSON with all extracted fields.
""")

email_handler = create_ai_handler("""
You draft professional emails based on instructions.
Consider tone, context, and recipient.
Output only the email content.
""")

report_handler = create_ai_handler("""
You generate reports from data.
Include summary, key findings, and recommendations.
Format for readability.
""")

# Register handlers with worker
handlers = {
    "code_review": code_review_handler,
    "document_processing": document_handler,
    "email_draft": email_handler,
    "report_generation": report_handler
}

# Start worker
worker = AgentWorker("default", handlers)
worker.start()
```

## Step 4: Job submission API

```python
from flask import Flask, request, jsonify

app = Flask(__name__)

@app.route("/jobs", methods=["POST"])
def submit_job():
    """Submit a new job to the queue."""

    data = request.json
    queue = data.get("queue", "default")
    job_type = data.get("type")
    payload = data.get("payload")
    priority = data.get("priority", 5)

    if not job_type or not payload:
        return jsonify({"error": "type and payload required"}), 400

    # Enqueue the job
    response = client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=256,
        messages=[{
            "role": "user",
            "content": f"""Use enqueue_job:
queue_name: {queue}
job_type: {job_type}
payload: {json.dumps(payload)}
priority: {priority}"""
        }],
        tools=[{"type": "mcp", "server_url": MCP_URL, "token": MCP_TOKEN}]
    )

    for content in response.content:
        if hasattr(content, 'text'):
            result = json.loads(content.text)
            return jsonify(result), 201

    return jsonify({"error": "Failed to enqueue"}), 500

@app.route("/jobs/<job_id>", methods=["GET"])
def get_job(job_id: str):
    """Get job status and result."""

    response = client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=256,
        messages=[{
            "role": "user",
            "content": f"Use get_job_status for job_id: {job_id}"
        }],
        tools=[{"type": "mcp", "server_url": MCP_URL, "token": MCP_TOKEN}]
    )

    for content in response.content:
        if hasattr(content, 'text'):
            return jsonify(json.loads(content.text))

    return jsonify({"error": "Job not found"}), 404

@app.route("/queues/<queue_name>/stats", methods=["GET"])
def queue_stats(queue_name: str):
    """Get queue statistics."""

    response = client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=256,
        messages=[{
            "role": "user",
            "content": f"Use get_queue_stats for queue_name: {queue_name}"
        }],
        tools=[{"type": "mcp", "server_url": MCP_URL, "token": MCP_TOKEN}]
    )

    for content in response.content:
        if hasattr(content, 'text'):
            return jsonify(json.loads(content.text))

    return jsonify({"error": "Queue not found"}), 404

if __name__ == "__main__":
    app.run(port=5000)
```

## Step 5: Batch processing

```python
def submit_batch(jobs: list, queue: str = "default") -> list:
    """Submit multiple jobs as a batch."""

    batch_id = str(uuid.uuid4())
    job_ids = []

    r = redis.Redis(host='localhost', port=6379, db=0)

    for i, job_data in enumerate(jobs):
        job = {
            "id": str(uuid.uuid4()),
            "batch_id": batch_id,
            "batch_index": i,
            "type": job_data.get("type", "generic"),
            "payload": json.dumps(job_data.get("payload", {})),
            "priority": job_data.get("priority", 5),
            "status": "pending",
            "created_at": datetime.utcnow().isoformat(),
            "attempts": 0
        }

        score = datetime.utcnow().timestamp() - (job["priority"] * 1000)
        r.zadd(f"queue:{queue}", {json.dumps(job): score})
        r.hset(f"job:{job['id']}", mapping=job)
        job_ids.append(job["id"])

    # Track batch
    r.hset(f"batch:{batch_id}", mapping={
        "total": len(jobs),
        "completed": 0,
        "failed": 0,
        "created_at": datetime.utcnow().isoformat()
    })
    r.sadd(f"batch:{batch_id}:jobs", *job_ids)

    return {
        "batch_id": batch_id,
        "job_count": len(jobs),
        "job_ids": job_ids
    }

def get_batch_status(batch_id: str) -> dict:
    """Get status of a batch of jobs."""

    r = redis.Redis(host='localhost', port=6379, db=0)

    batch_info = r.hgetall(f"batch:{batch_id}")
    job_ids = r.smembers(f"batch:{batch_id}:jobs")

    statuses = {"pending": 0, "processing": 0, "completed": 0, "failed": 0}

    for job_id in job_ids:
        status = r.hget(f"job:{job_id.decode()}", "status")
        if status:
            statuses[status.decode()] = statuses.get(status.decode(), 0) + 1

    return {
        "batch_id": batch_id,
        "total": int(batch_info.get(b"total", 0)),
        "statuses": statuses,
        "progress": (statuses["completed"] + statuses["failed"]) / int(batch_info.get(b"total", 1)) * 100
    }
```

## Step 6: Monitoring dashboard

```python
def get_system_metrics() -> dict:
    """Get overall system metrics."""

    r = redis.Redis(host='localhost', port=6379, db=0)

    # Get all queue names
    queues = [key.decode().split(":")[1] for key in r.keys("queue:*")]

    metrics = {
        "queues": {},
        "total_pending": 0,
        "total_processing": 0,
        "dlq_size": r.llen("dlq:jobs")
    }

    for queue in queues:
        pending = r.zcard(f"queue:{queue}")
        processing = r.scard(f"processing:{queue}")

        metrics["queues"][queue] = {
            "pending": pending,
            "processing": processing
        }
        metrics["total_pending"] += pending
        metrics["total_processing"] += processing

    return metrics

@app.route("/metrics", methods=["GET"])
def metrics():
    """Prometheus-style metrics endpoint."""

    m = get_system_metrics()

    output = []
    output.append(f"# HELP agent_queue_pending Number of pending jobs")
    output.append(f"# TYPE agent_queue_pending gauge")
    for queue, stats in m["queues"].items():
        output.append(f'agent_queue_pending{{queue="{queue}"}} {stats["pending"]}')

    output.append(f"# HELP agent_queue_processing Number of processing jobs")
    output.append(f"# TYPE agent_queue_processing gauge")
    for queue, stats in m["queues"].items():
        output.append(f'agent_queue_processing{{queue="{queue}"}} {stats["processing"]}')

    output.append(f"# HELP agent_dlq_size Dead letter queue size")
    output.append(f"# TYPE agent_dlq_size gauge")
    output.append(f"agent_dlq_size {m['dlq_size']}")

    return "\n".join(output), 200, {"Content-Type": "text/plain"}
```

## Summary

Building agent job queues:

1. **Queue infrastructure** - Redis or SQS for job storage
2. **Workers** - Processes that run agents on jobs
3. **Priority handling** - Urgent jobs processed first
4. **Batch processing** - Handle bulk workloads
5. **Monitoring** - Track queue health and performance

Build tools with [Gantz](https://gantz.run), scale agent workloads.

From one request to millions. Same agents.

## Related reading

- [Event-Driven Agents](/post/event-driven-agents/) - Real-time processing
- [Agent Scaling](/post/agent-scaling/) - Production scaling
- [Agent Observability](/post/agent-observability/) - Monitoring

---

*How do you scale AI workloads? Share your architecture.*
