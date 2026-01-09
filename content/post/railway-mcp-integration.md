+++
title = "Railway MCP Integration: Deploy AI Agents with Zero Configuration"
image = "images/railway-mcp-integration.webp"
date = 2025-05-07
description = "Deploy MCP-powered AI agents on Railway. Learn instant deployments, automatic SSL, database provisioning, and environment management with Gantz."
draft = false
tags = ['railway', 'deployment', 'paas', 'mcp', 'devops', 'gantz']
voice = false
summary = "Railway auto-detects your framework, provisions PostgreSQL/Redis/MongoDB in seconds, and gives every PR its own preview environment. No Dockerfiles, no YAML configs - just push code and get a running MCP agent with SSL. This guide covers the full deployment workflow using Gantz CLI."

[howto]
name = "How To Deploy AI Agents on Railway with MCP"
totalTime = 25
[[howto.steps]]
name = "Create Railway project"
text = "Initialize a new Railway project from GitHub or template"
[[howto.steps]]
name = "Configure MCP tools"
text = "Define tool configurations for Railway deployment"
[[howto.steps]]
name = "Set up databases"
text = "Provision PostgreSQL, Redis, or MongoDB with one click"
[[howto.steps]]
name = "Configure environments"
text = "Set up staging and production environments"
[[howto.steps]]
name = "Deploy with Gantz"
text = "Deploy and manage your AI agents using Gantz CLI"
+++

Railway offers the fastest path to deploying MCP-powered AI agents. With automatic builds, instant deployments, and one-click database provisioning, you can focus on building instead of infrastructure.

## Why Railway for MCP?

Railway provides exceptional developer experience:

- **Zero configuration**: Automatic detection of frameworks
- **Instant databases**: PostgreSQL, Redis, MongoDB in seconds
- **Preview environments**: Every PR gets its own deployment
- **Simple pricing**: Pay for what you use
- **Private networking**: Secure service-to-service communication

## Railway MCP Tool Definition

Configure Railway tools in Gantz:

```yaml
# gantz.yaml
name: railway-mcp-tools
version: 1.0.0

tools:
  deploy_service:
    description: "Deploy service to Railway"
    parameters:
      project_id:
        type: string
        description: "Railway project ID"
        required: true
      service_name:
        type: string
        description: "Service name"
        required: true
      source:
        type: string
        description: "GitHub repo URL or Docker image"
        required: true
    handler: railway.deploy_service

  list_projects:
    description: "List Railway projects"
    parameters:
      team_id:
        type: string
        description: "Team ID (optional)"
    handler: railway.list_projects

  create_database:
    description: "Create database service"
    parameters:
      project_id:
        type: string
        required: true
      type:
        type: string
        description: "postgres, redis, or mongodb"
        required: true
      name:
        type: string
        description: "Database service name"
    handler: railway.create_database

  get_deployment_status:
    description: "Get deployment status"
    parameters:
      deployment_id:
        type: string
        required: true
    handler: railway.get_deployment_status

  set_variables:
    description: "Set environment variables"
    parameters:
      project_id:
        type: string
        required: true
      service_id:
        type: string
        required: true
      variables:
        type: object
        description: "Key-value pairs of environment variables"
        required: true
    handler: railway.set_variables

  get_logs:
    description: "Get service logs"
    parameters:
      deployment_id:
        type: string
        required: true
      lines:
        type: integer
        default: 100
    handler: railway.get_logs
```

## Handler Implementation

Build handlers for Railway operations:

```python
# handlers/railway.py
import httpx
import os
from typing import Optional

RAILWAY_API = "https://backboard.railway.app/graphql/v2"


def get_headers():
    """Get authorization headers."""
    return {
        "Authorization": f"Bearer {os.environ['RAILWAY_TOKEN']}",
        "Content-Type": "application/json"
    }


async def graphql(query: str, variables: dict = None) -> dict:
    """Execute GraphQL query."""
    async with httpx.AsyncClient() as client:
        response = await client.post(
            RAILWAY_API,
            json={"query": query, "variables": variables or {}},
            headers=get_headers()
        )
        return response.json()


async def deploy_service(project_id: str, service_name: str,
                         source: str) -> dict:
    """Deploy service to Railway."""
    # Check if source is Docker image or GitHub repo
    if source.startswith("ghcr.io") or source.startswith("docker.io"):
        return await deploy_docker(project_id, service_name, source)
    else:
        return await deploy_github(project_id, service_name, source)


async def deploy_docker(project_id: str, service_name: str,
                        image: str) -> dict:
    """Deploy from Docker image."""
    mutation = """
    mutation($projectId: String!, $name: String!, $image: String!) {
        serviceCreate(input: {
            projectId: $projectId
            name: $name
            source: { image: $image }
        }) {
            id
            name
            projectId
        }
    }
    """

    try:
        result = await graphql(mutation, {
            "projectId": project_id,
            "name": service_name,
            "image": image
        })

        service = result.get("data", {}).get("serviceCreate")

        if not service:
            return {"error": result.get("errors", [{}])[0].get("message")}

        # Trigger deployment
        deploy_mutation = """
        mutation($serviceId: String!) {
            deploymentCreate(input: { serviceId: $serviceId }) {
                id
                status
            }
        }
        """

        deploy_result = await graphql(deploy_mutation, {
            "serviceId": service["id"]
        })

        deployment = deploy_result.get("data", {}).get("deploymentCreate")

        return {
            "service_id": service["id"],
            "service_name": service_name,
            "deployment_id": deployment.get("id") if deployment else None,
            "status": deployment.get("status") if deployment else "pending"
        }

    except Exception as e:
        return {"error": f"Deployment failed: {str(e)}"}


async def deploy_github(project_id: str, service_name: str,
                        repo_url: str) -> dict:
    """Deploy from GitHub repository."""
    mutation = """
    mutation($projectId: String!, $name: String!, $repo: String!) {
        serviceCreate(input: {
            projectId: $projectId
            name: $name
            source: { repo: $repo }
        }) {
            id
            name
        }
    }
    """

    try:
        result = await graphql(mutation, {
            "projectId": project_id,
            "name": service_name,
            "repo": repo_url
        })

        service = result.get("data", {}).get("serviceCreate")

        return {
            "service_id": service["id"] if service else None,
            "service_name": service_name,
            "source": repo_url,
            "status": "building"
        }

    except Exception as e:
        return {"error": f"Deployment failed: {str(e)}"}


async def list_projects(team_id: str = None) -> dict:
    """List Railway projects."""
    query = """
    query($teamId: String) {
        projects(teamId: $teamId) {
            edges {
                node {
                    id
                    name
                    description
                    createdAt
                    services {
                        edges {
                            node {
                                id
                                name
                            }
                        }
                    }
                    environments {
                        edges {
                            node {
                                id
                                name
                            }
                        }
                    }
                }
            }
        }
    }
    """

    try:
        result = await graphql(query, {"teamId": team_id})
        projects = result.get("data", {}).get("projects", {}).get("edges", [])

        return {
            "count": len(projects),
            "projects": [{
                "id": p["node"]["id"],
                "name": p["node"]["name"],
                "description": p["node"].get("description"),
                "services": len(p["node"].get("services", {}).get("edges", [])),
                "environments": [
                    e["node"]["name"]
                    for e in p["node"].get("environments", {}).get("edges", [])
                ]
            } for p in projects]
        }

    except Exception as e:
        return {"error": f"Failed to list projects: {str(e)}"}


async def create_database(project_id: str, db_type: str,
                          name: str = None) -> dict:
    """Create database service."""
    # Map database types to Railway plugins
    db_plugins = {
        "postgres": "postgresql",
        "redis": "redis",
        "mongodb": "mongodb",
        "mysql": "mysql"
    }

    plugin = db_plugins.get(db_type.lower())
    if not plugin:
        return {"error": f"Unsupported database type: {db_type}"}

    mutation = """
    mutation($projectId: String!, $plugin: String!, $name: String) {
        serviceCreate(input: {
            projectId: $projectId
            name: $name
            source: { plugin: $plugin }
        }) {
            id
            name
        }
    }
    """

    try:
        result = await graphql(mutation, {
            "projectId": project_id,
            "plugin": plugin,
            "name": name or f"{db_type}-db"
        })

        service = result.get("data", {}).get("serviceCreate")

        if not service:
            return {"error": result.get("errors", [{}])[0].get("message")}

        return {
            "service_id": service["id"],
            "name": service["name"],
            "type": db_type,
            "status": "provisioning",
            "message": "Database will be ready in a few seconds"
        }

    except Exception as e:
        return {"error": f"Database creation failed: {str(e)}"}


async def get_deployment_status(deployment_id: str) -> dict:
    """Get deployment status."""
    query = """
    query($id: String!) {
        deployment(id: $id) {
            id
            status
            createdAt
            service {
                name
            }
            meta {
                image
            }
        }
    }
    """

    try:
        result = await graphql(query, {"id": deployment_id})
        deployment = result.get("data", {}).get("deployment")

        if not deployment:
            return {"error": f"Deployment {deployment_id} not found"}

        return {
            "id": deployment["id"],
            "status": deployment["status"],
            "service": deployment.get("service", {}).get("name"),
            "created_at": deployment["createdAt"],
            "image": deployment.get("meta", {}).get("image")
        }

    except Exception as e:
        return {"error": f"Failed to get status: {str(e)}"}


async def set_variables(project_id: str, service_id: str,
                        variables: dict) -> dict:
    """Set environment variables."""
    mutation = """
    mutation($input: VariableCollectionUpsertInput!) {
        variableCollectionUpsert(input: $input)
    }
    """

    try:
        result = await graphql(mutation, {
            "input": {
                "projectId": project_id,
                "serviceId": service_id,
                "variables": variables
            }
        })

        return {
            "service_id": service_id,
            "variables_set": list(variables.keys()),
            "status": "updated"
        }

    except Exception as e:
        return {"error": f"Failed to set variables: {str(e)}"}


async def get_logs(deployment_id: str, lines: int = 100) -> dict:
    """Get deployment logs."""
    query = """
    query($deploymentId: String!, $limit: Int) {
        deploymentLogs(deploymentId: $deploymentId, limit: $limit) {
            message
            timestamp
            severity
        }
    }
    """

    try:
        result = await graphql(query, {
            "deploymentId": deployment_id,
            "limit": lines
        })

        logs = result.get("data", {}).get("deploymentLogs", [])

        return {
            "deployment_id": deployment_id,
            "count": len(logs),
            "logs": [{
                "timestamp": log["timestamp"],
                "severity": log["severity"],
                "message": log["message"]
            } for log in logs]
        }

    except Exception as e:
        return {"error": f"Failed to get logs: {str(e)}"}
```

## Application Setup

Create the MCP agent application:

```python
# main.py
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from gantz import MCPClient
import os

app = FastAPI(title="MCP Agent on Railway")
mcp = MCPClient(config_path="gantz.yaml")


class ToolRequest(BaseModel):
    tool: str
    parameters: dict = {}


@app.get("/")
async def root():
    return {
        "service": "mcp-agent",
        "environment": os.environ.get("RAILWAY_ENVIRONMENT", "unknown"),
        "status": "running"
    }


@app.get("/health")
async def health():
    return {"status": "healthy"}


@app.post("/api/execute")
async def execute_tool(request: ToolRequest):
    try:
        result = mcp.execute_tool(request.tool, request.parameters)
        return {"tool": request.tool, "result": result}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/api/tools")
async def list_tools():
    return {"tools": mcp.list_tools()}
```

## Railway Configuration

Configure with `railway.json`:

```json
{
  "$schema": "https://railway.app/railway.schema.json",
  "build": {
    "builder": "NIXPACKS"
  },
  "deploy": {
    "startCommand": "uvicorn main:app --host 0.0.0.0 --port $PORT",
    "healthcheckPath": "/health",
    "healthcheckTimeout": 30,
    "restartPolicyType": "ON_FAILURE",
    "restartPolicyMaxRetries": 3
  }
}
```

Or use `Procfile`:

```text
web: uvicorn main:app --host 0.0.0.0 --port $PORT
worker: python worker.py
```

## Database Integration

Connect to Railway databases:

```python
# database.py
import os
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
import redis

# PostgreSQL - automatically injected by Railway
DATABASE_URL = os.environ.get("DATABASE_URL")

if DATABASE_URL:
    engine = create_engine(DATABASE_URL)
    SessionLocal = sessionmaker(bind=engine)


def get_db():
    """Get database session."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


# Redis - automatically injected by Railway
REDIS_URL = os.environ.get("REDIS_URL")

if REDIS_URL:
    redis_client = redis.from_url(REDIS_URL)


def get_redis():
    """Get Redis client."""
    return redis_client
```

## Private Networking

Configure service-to-service communication:

```python
# internal_service.py
import os
import httpx

# Railway provides internal DNS
# Format: service-name.railway.internal

async def call_internal_service(service_name: str, path: str,
                                data: dict = None) -> dict:
    """Call internal Railway service."""
    url = f"http://{service_name}.railway.internal{path}"

    async with httpx.AsyncClient() as client:
        if data:
            response = await client.post(url, json=data)
        else:
            response = await client.get(url)

        return response.json()


# Example: Call AI processing service
async def process_with_ai(content: str) -> dict:
    return await call_internal_service(
        "ai-processor",
        "/api/process",
        {"content": content}
    )
```

## Environment Management

Set up multiple environments:

```python
# config.py
import os
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    environment: str = os.environ.get("RAILWAY_ENVIRONMENT", "development")
    database_url: str = os.environ.get("DATABASE_URL", "")
    redis_url: str = os.environ.get("REDIS_URL", "")
    gantz_enabled: bool = True

    # Different settings per environment
    debug: bool = environment != "production"
    log_level: str = "DEBUG" if environment != "production" else "INFO"

    class Config:
        env_file = ".env"


settings = Settings()
```

## Nixpacks Configuration

Customize the build process:

```toml
# nixpacks.toml
[phases.setup]
nixPkgs = ["python311", "gcc"]

[phases.install]
cmds = ["pip install -r requirements.txt"]

[phases.build]
cmds = ["python -m compileall ."]

[start]
cmd = "uvicorn main:app --host 0.0.0.0 --port $PORT"

[variables]
GANTZ_ENABLED = "true"
```

## Deploy with Gantz CLI

Deploy your Railway application:

```bash
# Install Gantz
npm install -g gantz

# Initialize Railway project
gantz init --template railway

# Login to Railway
railway login

# Deploy service
gantz deploy --platform railway

# Create database
gantz run create_database \
  --project-id your-project-id \
  --type postgres \
  --name mcp-db

# Set environment variables
gantz run set_variables \
  --project-id your-project-id \
  --service-id your-service-id \
  --variables '{"GANTZ_ENABLED": "true", "LOG_LEVEL": "INFO"}'

# Check status
gantz run get_deployment_status --deployment-id your-deployment-id
```

Build and deploy AI agents instantly at [gantz.run](https://gantz.run).

## Related Reading

- [Fly.io MCP Integration](/post/flyio-mcp-integration/) - Compare with Fly.io
- [PostgreSQL MCP Integration](/post/postgresql-mcp-integration/) - Database tools
- [Redis MCP Tools](/post/redis-mcp-tools/) - Caching and sessions

## Conclusion

Railway provides the fastest path to deploying MCP-powered AI agents. With automatic builds, instant database provisioning, and environment management, you can ship AI applications without infrastructure complexity.

Start deploying AI agents to Railway with Gantz today.
