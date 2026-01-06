+++
title = "The Minimal Docker Setup for Agents"
date = 2025-12-24
description = "Deploy AI agents with Docker in 5 files. Minimal Dockerfile, docker-compose setup, and best practices for containerizing Python-based agents."
image = "images/robot-billboard.webp"
draft = false
tags = ['docker', 'deployment', 'tutorial']
voice = false
+++


You built an agent. It works on your machine.

Now you need to run it somewhere else. A server. A Kubernetes cluster. Your colleague's machine. Anywhere.

This is where most agent projects stall. The code works locally, but "deployment" feels like a whole other project. Docker configs, environment management, secrets handling, networking — it adds up.

I've done this enough times that I've settled on a minimal setup that just works. Not over-engineered. Not under-powered. Just the files you need to go from local to deployed.

Docker is the answer. Here's the simplest setup that works.

## The goal

```
your-agent/
├── Dockerfile
├── docker-compose.yml
├── agent.py
├── requirements.txt
└── .env
```

Five files. Runs anywhere.

## The Dockerfile

```dockerfile
# Dockerfile
FROM python:3.11-slim

WORKDIR /app

# Install dependencies first (better caching)
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy code
COPY . .

# Don't run as root
RUN useradd -m agent
USER agent

CMD ["python", "agent.py"]
```

That's it. No multi-stage builds. No optimization tricks. Just works.

### Why these choices?

```dockerfile
FROM python:3.11-slim  # slim = smaller image, has what you need
WORKDIR /app           # consistent working directory
USER agent             # security: don't run as root
```

## The requirements

```txt
# requirements.txt
openai>=1.0.0
anthropic>=0.18.0
redis>=4.0.0
```

Pin major versions. Don't over-specify.

## The agent

```python
# agent.py
import os
import openai

client = openai.OpenAI()  # Uses OPENAI_API_KEY from env

tools = [
    {
        "type": "function",
        "function": {
            "name": "run_command",
            "description": "Run a shell command",
            "parameters": {
                "type": "object",
                "properties": {
                    "command": {"type": "string"}
                },
                "required": ["command"]
            }
        }
    }
]

def execute_tool(name, args):
    if name == "run_command":
        import subprocess
        result = subprocess.run(
            args["command"],
            shell=True,
            capture_output=True,
            text=True,
            timeout=30
        )
        return result.stdout + result.stderr
    return "Unknown tool"

def run_agent(message):
    messages = [{"role": "user", "content": message}]

    while True:
        response = client.chat.completions.create(
            model=os.getenv("MODEL", "gpt-4o"),
            messages=messages,
            tools=tools
        )

        msg = response.choices[0].message
        messages.append(msg)

        if not msg.tool_calls:
            return msg.content

        for tc in msg.tool_calls:
            import json
            result = execute_tool(tc.function.name, json.loads(tc.function.arguments))
            messages.append({
                "role": "tool",
                "tool_call_id": tc.id,
                "content": result
            })

if __name__ == "__main__":
    print(run_agent("What files are in the current directory?"))
```

## The environment

```bash
# .env
OPENAI_API_KEY=sk-...
MODEL=gpt-4o
```

Never commit this file:

```bash
# .gitignore
.env
```

## Build and run

```bash
# Build
docker build -t my-agent .

# Run with env file
docker run --env-file .env my-agent

# Run with inline env
docker run -e OPENAI_API_KEY=sk-... my-agent
```

Done. Your agent runs in a container.

## Adding docker-compose

For real projects, use compose:

```yaml
# docker-compose.yml
version: '3.8'

services:
  agent:
    build: .
    env_file:
      - .env
    volumes:
      - ./workspace:/app/workspace  # Persist work
    restart: unless-stopped
```

```bash
# Run
docker-compose up

# Run in background
docker-compose up -d

# Rebuild after changes
docker-compose up --build
```

## Adding Redis for state

Most agents need state storage:

```yaml
# docker-compose.yml
version: '3.8'

services:
  agent:
    build: .
    env_file:
      - .env
    environment:
      - REDIS_URL=redis://redis:6379
    depends_on:
      - redis
    restart: unless-stopped

  redis:
    image: redis:alpine
    volumes:
      - redis_data:/data
    restart: unless-stopped

volumes:
  redis_data:
```

Update your agent:

```python
# agent.py
import os
import redis
import json

redis_client = redis.from_url(os.getenv("REDIS_URL", "redis://localhost:6379"))

def save_conversation(session_id, messages):
    redis_client.setex(f"conv:{session_id}", 3600, json.dumps(messages))

def load_conversation(session_id):
    data = redis_client.get(f"conv:{session_id}")
    return json.loads(data) if data else []
```

## Adding an API

Wrap your agent in an HTTP API:

```python
# api.py
from fastapi import FastAPI
from pydantic import BaseModel
import uvicorn

app = FastAPI()

class ChatRequest(BaseModel):
    message: str
    session_id: str = "default"

class ChatResponse(BaseModel):
    response: str

@app.post("/chat", response_model=ChatResponse)
async def chat(request: ChatRequest):
    response = run_agent(request.message, request.session_id)
    return ChatResponse(response=response)

@app.get("/health")
async def health():
    return {"status": "ok"}

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
```

Update Dockerfile:

```dockerfile
FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

RUN useradd -m agent
USER agent

EXPOSE 8000

CMD ["python", "api.py"]
```

Update requirements:

```txt
# requirements.txt
openai>=1.0.0
redis>=4.0.0
fastapi>=0.100.0
uvicorn>=0.22.0
pydantic>=2.0.0
```

Update compose:

```yaml
# docker-compose.yml
version: '3.8'

services:
  agent:
    build: .
    env_file:
      - .env
    ports:
      - "8000:8000"
    environment:
      - REDIS_URL=redis://redis:6379
    depends_on:
      - redis
    restart: unless-stopped

  redis:
    image: redis:alpine
    volumes:
      - redis_data:/data
    restart: unless-stopped

volumes:
  redis_data:
```

Now you have an API:

```bash
curl -X POST http://localhost:8000/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "Hello", "session_id": "user123"}'
```

## Adding a workspace

Agents need to read/write files. Give them a workspace:

```yaml
# docker-compose.yml
services:
  agent:
    build: .
    env_file:
      - .env
    volumes:
      - ./workspace:/app/workspace  # Mount local folder
      - /tmp/agent-work:/tmp/work   # Temp space
    working_dir: /app/workspace
```

In your agent:

```python
import os

# All file operations happen in workspace
WORKSPACE = os.getenv("WORKSPACE", "/app/workspace")

def read_file(path):
    # Prevent path traversal
    safe_path = os.path.normpath(os.path.join(WORKSPACE, path))
    if not safe_path.startswith(WORKSPACE):
        return "Error: Access denied"

    with open(safe_path) as f:
        return f.read()
```

## Production hardening

### Resource limits

```yaml
services:
  agent:
    build: .
    deploy:
      resources:
        limits:
          cpus: '1'
          memory: 512M
        reservations:
          cpus: '0.25'
          memory: 128M
```

### Health checks

```yaml
services:
  agent:
    build: .
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 10s
```

### Logging

```yaml
services:
  agent:
    build: .
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
```

### Secrets (not env files)

```yaml
services:
  agent:
    build: .
    secrets:
      - openai_key

secrets:
  openai_key:
    file: ./secrets/openai_key.txt
```

In your code:

```python
def get_secret(name):
    try:
        with open(f"/run/secrets/{name}") as f:
            return f.read().strip()
    except FileNotFoundError:
        return os.getenv(name.upper())

openai_key = get_secret("openai_key")
```

## The complete setup

```
your-agent/
├── Dockerfile
├── docker-compose.yml
├── api.py
├── agent.py
├── requirements.txt
├── .env
├── .gitignore
└── workspace/
    └── (user files here)
```

### Final docker-compose.yml

```yaml
version: '3.8'

services:
  agent:
    build: .
    env_file:
      - .env
    ports:
      - "8000:8000"
    environment:
      - REDIS_URL=redis://redis:6379
      - WORKSPACE=/app/workspace
    volumes:
      - ./workspace:/app/workspace
    depends_on:
      redis:
        condition: service_healthy
    deploy:
      resources:
        limits:
          cpus: '1'
          memory: 512M
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
    restart: unless-stopped

  redis:
    image: redis:alpine
    volumes:
      - redis_data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 3
    restart: unless-stopped

volumes:
  redis_data:
```

### Final Dockerfile

```dockerfile
FROM python:3.11-slim

WORKDIR /app

# Install curl for healthcheck
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

RUN useradd -m agent && chown -R agent:agent /app
USER agent

EXPOSE 8000

CMD ["python", "api.py"]
```

## Running with Gantz

[Gantz](https://gantz.run) simplifies the tool layer:

```yaml
# docker-compose.yml
services:
  gantz:
    image: gantz/gantz
    env_file:
      - .env
    ports:
      - "8000:8000"
    volumes:
      - ./gantz.yaml:/app/gantz.yaml
      - ./workspace:/app/workspace
    restart: unless-stopped
```

```yaml
# gantz.yaml
tools:
  - name: read
    description: Read a file
    parameters:
      - name: path
        type: string
        required: true
    script:
      shell: cat "{{path}}"

  - name: write
    description: Write to a file
    parameters:
      - name: path
        type: string
        required: true
      - name: content
        type: string
        required: true
    script:
      shell: echo "{{content}}" > "{{path}}"

  - name: run
    description: Run a command
    parameters:
      - name: command
        type: string
        required: true
    script:
      shell: "{{command}}"
```

One config file. Ready to deploy.

## Common commands

```bash
# Start everything
docker-compose up -d

# View logs
docker-compose logs -f agent

# Restart after code changes
docker-compose up -d --build

# Stop everything
docker-compose down

# Stop and remove volumes (fresh start)
docker-compose down -v

# Shell into container
docker-compose exec agent bash

# Check resource usage
docker stats
```

## Troubleshooting

### Container exits immediately

Check the logs:
```bash
docker-compose logs agent
```

Common causes:
- Missing environment variables
- Python import errors (missing dependencies)
- API key issues

### Can't connect to Redis

Make sure Redis is healthy before starting the agent:
```yaml
depends_on:
  redis:
    condition: service_healthy
```

### Out of memory

Agents can use a lot of memory during inference. Increase limits:
```yaml
deploy:
  resources:
    limits:
      memory: 1G  # or more
```

### Slow startup

The first run downloads models/embeddings. Subsequent runs use cached data. Use volumes to persist caches:
```yaml
volumes:
  - huggingface_cache:/root/.cache/huggingface
```

## Summary

Minimal Docker setup for agents:

| Component | Purpose |
|-----------|---------|
| Dockerfile | Build your agent image |
| docker-compose.yml | Orchestrate services |
| .env | Store secrets (don't commit) |
| volumes | Persist data and workspace |
| healthcheck | Know when things break |
| resource limits | Don't eat all the RAM |

The key insight: **start minimal, add complexity when you need it**. You don't need Kubernetes on day one. You don't need multi-stage builds for a prototype.

```bash
docker-compose up -d
```

Your agent is now portable. It runs the same everywhere Docker runs.

This setup handles 90% of use cases. When you need to scale further (Kubernetes, multiple replicas, auto-scaling), you'll have a solid foundation to build on.

## Related reading

- [Why Your Agent Works Locally But Fails in Production](/post/local-vs-production/) - Deployment pitfalls
- [Horizontal Scaling for Stateful Agents](/post/horizontal-scaling/) - When you need more instances
- [Background Jobs for Long-Running Tasks](/post/background-jobs/) - Handling timeouts

---

*What's your Docker setup for agents? Any tricks I missed?*
