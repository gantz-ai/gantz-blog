+++
title = "Render MCP Integration: Deploy AI Agents with Managed Infrastructure"
image = "/images/render-mcp-integration.png"
date = 2025-05-08
description = "Deploy MCP-powered AI agents on Render. Learn web services, background workers, cron jobs, and managed databases with Gantz."
draft = false
tags = ['render', 'deployment', 'paas', 'mcp', 'infrastructure', 'gantz']
voice = false

[howto]
name = "How To Deploy AI Agents on Render with MCP"
totalTime = 30
[[howto.steps]]
name = "Create Render service"
text = "Set up a new web service on Render from GitHub"
[[howto.steps]]
name = "Configure MCP tools"
text = "Define tool configurations for Render deployment"
[[howto.steps]]
name = "Set up background workers"
text = "Configure workers for async AI processing"
[[howto.steps]]
name = "Add managed databases"
text = "Provision PostgreSQL and Redis instances"
[[howto.steps]]
name = "Deploy with Gantz"
text = "Deploy and manage your AI agents using Gantz CLI"
+++

Render provides a modern cloud platform for deploying MCP-powered AI agents. With fully managed infrastructure, automatic scaling, and native Docker support, you can focus on building intelligent applications.

## Why Render for MCP?

Render offers compelling features for AI agents:

- **Fully managed**: No DevOps required
- **Auto-scaling**: Scale based on traffic
- **Background workers**: Process AI tasks asynchronously
- **Managed databases**: PostgreSQL, Redis with backups
- **Private services**: Internal networking between services

## Render MCP Tool Definition

Configure Render tools in Gantz:

```yaml
# gantz.yaml
name: render-mcp-tools
version: 1.0.0

tools:
  create_service:
    description: "Create Render web service"
    parameters:
      name:
        type: string
        description: "Service name"
        required: true
      repo:
        type: string
        description: "GitHub repository URL"
        required: true
      branch:
        type: string
        default: "main"
      env:
        type: string
        description: "docker, python, node"
        default: "docker"
      plan:
        type: string
        description: "free, starter, standard, pro"
        default: "starter"
    handler: render.create_service

  list_services:
    description: "List all services"
    parameters:
      type:
        type: string
        description: "web_service, background_worker, private_service"
    handler: render.list_services

  deploy_service:
    description: "Trigger deployment"
    parameters:
      service_id:
        type: string
        required: true
      clear_cache:
        type: boolean
        default: false
    handler: render.deploy_service

  create_database:
    description: "Create managed database"
    parameters:
      name:
        type: string
        required: true
      type:
        type: string
        description: "postgresql or redis"
        required: true
      plan:
        type: string
        default: "starter"
    handler: render.create_database

  create_cron_job:
    description: "Create scheduled cron job"
    parameters:
      name:
        type: string
        required: true
      schedule:
        type: string
        description: "Cron expression"
        required: true
      command:
        type: string
        required: true
      repo:
        type: string
        required: true
    handler: render.create_cron_job

  get_service_logs:
    description: "Get service logs"
    parameters:
      service_id:
        type: string
        required: true
      lines:
        type: integer
        default: 100
    handler: render.get_logs
```

## Handler Implementation

Build handlers for Render operations:

```python
# handlers/render.py
import httpx
import os
from typing import Optional

RENDER_API = "https://api.render.com/v1"


def get_headers():
    """Get authorization headers."""
    return {
        "Authorization": f"Bearer {os.environ['RENDER_API_KEY']}",
        "Content-Type": "application/json"
    }


async def api_request(method: str, path: str,
                      data: dict = None) -> dict:
    """Make API request to Render."""
    async with httpx.AsyncClient() as client:
        response = await client.request(
            method,
            f"{RENDER_API}{path}",
            json=data,
            headers=get_headers()
        )

        if response.status_code >= 400:
            return {"error": response.text}

        return response.json() if response.text else {"success": True}


async def create_service(name: str, repo: str, branch: str = "main",
                         env: str = "docker", plan: str = "starter") -> dict:
    """Create Render web service."""
    # Map environment to Render service type
    env_config = {
        "docker": {"type": "web_service", "runtime": "docker"},
        "python": {"type": "web_service", "runtime": "python"},
        "node": {"type": "web_service", "runtime": "node"}
    }

    config = env_config.get(env, env_config["docker"])

    try:
        result = await api_request("POST", "/services", {
            "type": config["type"],
            "name": name,
            "repo": repo,
            "branch": branch,
            "autoDeploy": "yes",
            "serviceDetails": {
                "runtime": config.get("runtime"),
                "plan": plan,
                "envSpecificDetails": {
                    "dockerfilePath": "./Dockerfile" if env == "docker" else None,
                    "dockerContext": "." if env == "docker" else None
                }
            }
        })

        if "error" in result:
            return result

        service = result.get("service", result)

        return {
            "service_id": service.get("id"),
            "name": service.get("name"),
            "url": service.get("serviceDetails", {}).get("url"),
            "status": service.get("state"),
            "plan": plan
        }

    except Exception as e:
        return {"error": f"Service creation failed: {str(e)}"}


async def list_services(service_type: str = None) -> dict:
    """List all services."""
    try:
        path = "/services"
        if service_type:
            path += f"?type={service_type}"

        result = await api_request("GET", path)

        if "error" in result:
            return result

        services = result if isinstance(result, list) else result.get("services", [])

        return {
            "count": len(services),
            "services": [{
                "id": s.get("service", s).get("id"),
                "name": s.get("service", s).get("name"),
                "type": s.get("service", s).get("type"),
                "status": s.get("service", s).get("state"),
                "url": s.get("service", s).get("serviceDetails", {}).get("url")
            } for s in services]
        }

    except Exception as e:
        return {"error": f"Failed to list services: {str(e)}"}


async def deploy_service(service_id: str,
                         clear_cache: bool = False) -> dict:
    """Trigger deployment."""
    try:
        result = await api_request("POST", f"/services/{service_id}/deploys", {
            "clearCache": "clear" if clear_cache else "do_not_clear"
        })

        if "error" in result:
            return result

        deploy = result.get("deploy", result)

        return {
            "deploy_id": deploy.get("id"),
            "service_id": service_id,
            "status": deploy.get("status"),
            "created_at": deploy.get("createdAt"),
            "message": "Deployment triggered"
        }

    except Exception as e:
        return {"error": f"Deployment failed: {str(e)}"}


async def create_database(name: str, db_type: str,
                          plan: str = "starter") -> dict:
    """Create managed database."""
    endpoint = "/postgres" if db_type == "postgresql" else "/redis"

    try:
        result = await api_request("POST", endpoint, {
            "name": name,
            "plan": plan,
            "region": "oregon"  # or other region
        })

        if "error" in result:
            return result

        db = result.get("postgres") or result.get("redis") or result

        return {
            "id": db.get("id"),
            "name": db.get("name"),
            "type": db_type,
            "plan": plan,
            "status": db.get("status"),
            "connection_info": {
                "internal_url": db.get("internalConnectionString"),
                "external_url": db.get("externalConnectionString")
            } if db_type == "postgresql" else {
                "redis_url": db.get("connectionString")
            }
        }

    except Exception as e:
        return {"error": f"Database creation failed: {str(e)}"}


async def create_cron_job(name: str, schedule: str,
                          command: str, repo: str) -> dict:
    """Create scheduled cron job."""
    try:
        result = await api_request("POST", "/services", {
            "type": "cron_job",
            "name": name,
            "repo": repo,
            "autoDeploy": "yes",
            "serviceDetails": {
                "schedule": schedule,
                "dockerCommand": command
            }
        })

        if "error" in result:
            return result

        service = result.get("service", result)

        return {
            "id": service.get("id"),
            "name": service.get("name"),
            "schedule": schedule,
            "command": command,
            "status": "created"
        }

    except Exception as e:
        return {"error": f"Cron job creation failed: {str(e)}"}


async def get_logs(service_id: str, lines: int = 100) -> dict:
    """Get service logs."""
    try:
        result = await api_request(
            "GET",
            f"/services/{service_id}/logs?limit={lines}"
        )

        if "error" in result:
            return result

        logs = result if isinstance(result, list) else result.get("logs", [])

        return {
            "service_id": service_id,
            "count": len(logs),
            "logs": [{
                "timestamp": log.get("timestamp"),
                "message": log.get("message")
            } for log in logs]
        }

    except Exception as e:
        return {"error": f"Failed to get logs: {str(e)}"}
```

## Dockerfile for AI Agents

Create an optimized container:

```dockerfile
# Dockerfile
FROM python:3.11-slim

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application
COPY . .

# Create non-root user
RUN useradd -m appuser && chown -R appuser:appuser /app
USER appuser

# Health check
HEALTHCHECK --interval=30s --timeout=3s \
    CMD curl -f http://localhost:$PORT/health || exit 1

# Run application
CMD uvicorn main:app --host 0.0.0.0 --port $PORT
```

## Application Code

Create the MCP agent application:

```python
# main.py
from fastapi import FastAPI, HTTPException, BackgroundTasks
from pydantic import BaseModel
from gantz import MCPClient
import os
import redis

app = FastAPI(title="MCP Agent on Render")
mcp = MCPClient(config_path="gantz.yaml")

# Redis for task queue (if available)
redis_url = os.environ.get("REDIS_URL")
redis_client = redis.from_url(redis_url) if redis_url else None


class ToolRequest(BaseModel):
    tool: str
    parameters: dict = {}
    async_mode: bool = False


class TaskStatus(BaseModel):
    task_id: str


@app.get("/")
async def root():
    return {
        "service": "mcp-agent",
        "render_service_id": os.environ.get("RENDER_SERVICE_ID"),
        "status": "running"
    }


@app.get("/health")
async def health():
    return {"status": "healthy"}


@app.post("/api/execute")
async def execute_tool(request: ToolRequest,
                       background_tasks: BackgroundTasks):
    if request.async_mode and redis_client:
        # Queue for background processing
        task_id = f"task_{os.urandom(8).hex()}"
        redis_client.lpush("mcp_tasks", json.dumps({
            "task_id": task_id,
            "tool": request.tool,
            "parameters": request.parameters
        }))
        return {"task_id": task_id, "status": "queued"}

    try:
        result = mcp.execute_tool(request.tool, request.parameters)
        return {"tool": request.tool, "result": result}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/api/task/{task_id}")
async def get_task_status(task_id: str):
    if not redis_client:
        raise HTTPException(status_code=503, detail="Task queue not available")

    result = redis_client.get(f"result_{task_id}")
    if result:
        return {"task_id": task_id, "status": "completed", "result": json.loads(result)}

    # Check if still in queue
    return {"task_id": task_id, "status": "processing"}


@app.get("/api/tools")
async def list_tools():
    return {"tools": mcp.list_tools()}
```

## Background Worker

Create a worker for async processing:

```python
# worker.py
import redis
import json
import os
from gantz import MCPClient

redis_url = os.environ.get("REDIS_URL")
redis_client = redis.from_url(redis_url)
mcp = MCPClient(config_path="gantz.yaml")


def process_tasks():
    """Process tasks from Redis queue."""
    print("Worker started, waiting for tasks...")

    while True:
        # Block and wait for task
        _, task_data = redis_client.brpop("mcp_tasks")
        task = json.loads(task_data)

        task_id = task["task_id"]
        tool = task["tool"]
        parameters = task["parameters"]

        print(f"Processing task {task_id}: {tool}")

        try:
            result = mcp.execute_tool(tool, parameters)
            redis_client.setex(
                f"result_{task_id}",
                3600,  # 1 hour expiry
                json.dumps({"success": True, "result": result})
            )
        except Exception as e:
            redis_client.setex(
                f"result_{task_id}",
                3600,
                json.dumps({"success": False, "error": str(e)})
            )

        print(f"Task {task_id} completed")


if __name__ == "__main__":
    process_tasks()
```

## Render Blueprint

Define infrastructure as code:

```yaml
# render.yaml
services:
  # Web service
  - type: web
    name: mcp-agent
    runtime: docker
    repo: https://github.com/yourusername/mcp-agent
    branch: main
    plan: starter
    healthCheckPath: /health
    envVars:
      - key: GANTZ_ENABLED
        value: "true"
      - key: DATABASE_URL
        fromDatabase:
          name: mcp-db
          property: connectionString
      - key: REDIS_URL
        fromService:
          type: redis
          name: mcp-cache
          property: connectionString

  # Background worker
  - type: worker
    name: mcp-worker
    runtime: docker
    repo: https://github.com/yourusername/mcp-agent
    branch: main
    plan: starter
    dockerCommand: python worker.py
    envVars:
      - key: REDIS_URL
        fromService:
          type: redis
          name: mcp-cache
          property: connectionString

  # Cron job for scheduled tasks
  - type: cron
    name: mcp-scheduler
    runtime: docker
    repo: https://github.com/yourusername/mcp-agent
    branch: main
    schedule: "0 * * * *"  # Every hour
    dockerCommand: python scheduled_tasks.py
    envVars:
      - key: DATABASE_URL
        fromDatabase:
          name: mcp-db
          property: connectionString

databases:
  - name: mcp-db
    plan: starter
    databaseName: mcpagent

  - name: mcp-cache
    plan: starter
    type: redis
```

## Scheduled Tasks

Create cron jobs for periodic AI tasks:

```python
# scheduled_tasks.py
from gantz import MCPClient
import os
from datetime import datetime

mcp = MCPClient(config_path="gantz.yaml")


def run_scheduled_tasks():
    """Run scheduled AI agent tasks."""
    print(f"Running scheduled tasks at {datetime.now().isoformat()}")

    # Example: Daily summary generation
    result = mcp.execute_tool("generate_daily_summary", {
        "date": datetime.now().strftime("%Y-%m-%d")
    })
    print(f"Daily summary: {result}")

    # Example: Data cleanup
    cleanup_result = mcp.execute_tool("cleanup_old_data", {
        "days": 30
    })
    print(f"Cleanup result: {cleanup_result}")


if __name__ == "__main__":
    run_scheduled_tasks()
```

## Private Services

Set up internal AI processing service:

```python
# internal_ai_service.py
from fastapi import FastAPI
from gantz import MCPClient
import os

app = FastAPI()
mcp = MCPClient()

# This service is only accessible internally
# Configure as "private" service type in Render


@app.post("/internal/process")
async def process_internal(data: dict):
    """Internal processing endpoint."""
    result = mcp.execute_tool("ai_process", data)
    return result


# In your main service, call this internally:
# async with httpx.AsyncClient() as client:
#     response = await client.post(
#         "http://internal-ai-service:10000/internal/process",
#         json=data
#     )
```

## Deploy with Gantz CLI

Deploy your Render application:

```bash
# Install Gantz
npm install -g gantz

# Initialize Render project
gantz init --template render

# Deploy using blueprint
render blueprint sync

# Or deploy individual service
gantz deploy --platform render

# Create database
gantz run create_database \
  --name mcp-db \
  --type postgresql \
  --plan starter

# Trigger deployment
gantz run deploy_service \
  --service-id srv-xxxxx

# Check logs
gantz run get_service_logs --service-id srv-xxxxx --lines 200
```

Build managed AI infrastructure at [gantz.run](https://gantz.run).

## Related Reading

- [Railway MCP Integration](/post/railway-mcp-integration/) - Compare with Railway
- [PostgreSQL MCP Integration](/post/postgresql-mcp-integration/) - Database integration
- [Redis MCP Tools](/post/redis-mcp-tools/) - Task queue patterns

## Conclusion

Render provides fully managed infrastructure for deploying MCP-powered AI agents. With web services, background workers, cron jobs, and managed databases, you can build complete AI applications without infrastructure complexity.

Start deploying AI agents to Render with Gantz today.
