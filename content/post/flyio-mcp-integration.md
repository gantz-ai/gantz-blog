+++
title = "Fly.io MCP Integration: Deploy AI Agents Globally in Seconds"
image = "images/flyio-mcp-integration.webp"
date = 2025-05-06
description = "Deploy MCP-powered AI agents on Fly.io. Learn multi-region deployment, persistent volumes, and container orchestration with Gantz."
summary = "Deploy AI agents to 30+ regions worldwide with a single command. Fly.io runs your containers close to users, handles automatic failover, and provides persistent volumes for agent state. This guide covers multi-region deployment, volume configuration for conversation history, and scaling strategies that keep latency low for global users."
draft = false
tags = ['flyio', 'containers', 'deployment', 'mcp', 'global', 'gantz']
voice = false

[howto]
name = "How To Deploy AI Agents on Fly.io with MCP"
totalTime = 30
[[howto.steps]]
name = "Create Fly.io app"
text = "Initialize a Fly.io application for your AI agent"
[[howto.steps]]
name = "Configure MCP tools"
text = "Define tool configurations for multi-region deployment"
[[howto.steps]]
name = "Build container"
text = "Create optimized Docker image for AI workloads"
[[howto.steps]]
name = "Deploy globally"
text = "Deploy to multiple regions with automatic scaling"
[[howto.steps]]
name = "Connect with Gantz"
text = "Integrate and manage your deployment using Gantz CLI"
+++

Fly.io makes it easy to deploy MCP-powered AI agents globally. With automatic multi-region distribution and persistent storage, you can build responsive AI applications that run close to your users.

## Why Fly.io for MCP?

Fly.io offers unique advantages for AI agents:

- **Global deployment**: Deploy to 30+ regions with one command
- **Persistent volumes**: Attach storage for models and data
- **Machine API**: Programmatic control over instances
- **Anycast networking**: Automatic routing to nearest region
- **Simple scaling**: Scale up or down instantly

## Fly.io MCP Tool Definition

Configure Fly.io tools in Gantz:

```yaml
# gantz.yaml
name: flyio-mcp-tools
version: 1.0.0

tools:
  deploy_app:
    description: "Deploy application to Fly.io"
    parameters:
      app_name:
        type: string
        description: "Fly.io app name"
        required: true
      image:
        type: string
        description: "Docker image to deploy"
        required: true
      regions:
        type: array
        description: "Regions to deploy to"
        default: ["iad"]
    handler: flyio.deploy_app

  list_apps:
    description: "List Fly.io applications"
    parameters:
      org:
        type: string
        description: "Organization slug"
    handler: flyio.list_apps

  scale_app:
    description: "Scale application instances"
    parameters:
      app_name:
        type: string
        required: true
      count:
        type: integer
        description: "Number of instances"
        required: true
      region:
        type: string
        description: "Specific region to scale"
    handler: flyio.scale_app

  get_app_status:
    description: "Get application status and metrics"
    parameters:
      app_name:
        type: string
        required: true
    handler: flyio.get_status

  invoke_machine:
    description: "Invoke Fly Machine directly"
    parameters:
      app_name:
        type: string
        required: true
      path:
        type: string
        default: "/"
      data:
        type: object
    handler: flyio.invoke_machine

  create_volume:
    description: "Create persistent volume"
    parameters:
      app_name:
        type: string
        required: true
      name:
        type: string
        required: true
      size_gb:
        type: integer
        default: 10
      region:
        type: string
        required: true
    handler: flyio.create_volume
```

## Handler Implementation

Build handlers for Fly.io operations:

```python
# handlers/flyio.py
import httpx
import os
from typing import Optional

FLY_API_URL = "https://api.fly.io/graphql"
FLY_MACHINES_API = "https://api.machines.dev/v1"


def get_headers():
    """Get authorization headers."""
    return {
        "Authorization": f"Bearer {os.environ['FLY_API_TOKEN']}",
        "Content-Type": "application/json"
    }


async def graphql_query(query: str, variables: dict = None) -> dict:
    """Execute GraphQL query against Fly.io API."""
    async with httpx.AsyncClient() as client:
        response = await client.post(
            FLY_API_URL,
            json={"query": query, "variables": variables or {}},
            headers=get_headers()
        )
        return response.json()


async def deploy_app(app_name: str, image: str,
                     regions: list = None) -> dict:
    """Deploy application to Fly.io."""
    regions = regions or ["iad"]

    try:
        # Create app if doesn't exist
        create_query = """
        mutation($input: CreateAppInput!) {
            createApp(input: $input) {
                app {
                    id
                    name
                    status
                }
            }
        }
        """

        await graphql_query(create_query, {
            "input": {
                "name": app_name,
                "organizationId": os.environ.get("FLY_ORG_ID")
            }
        })

        # Deploy to each region using Machines API
        machines = []
        async with httpx.AsyncClient() as client:
            for region in regions:
                response = await client.post(
                    f"{FLY_MACHINES_API}/apps/{app_name}/machines",
                    json={
                        "config": {
                            "image": image,
                            "env": {
                                "GANTZ_ENABLED": "true"
                            },
                            "services": [{
                                "ports": [
                                    {"port": 443, "handlers": ["tls", "http"]},
                                    {"port": 80, "handlers": ["http"]}
                                ],
                                "protocol": "tcp",
                                "internal_port": 8080
                            }],
                            "guest": {
                                "cpu_kind": "shared",
                                "cpus": 1,
                                "memory_mb": 256
                            }
                        },
                        "region": region
                    },
                    headers=get_headers()
                )
                machines.append(response.json())

        return {
            "app": app_name,
            "image": image,
            "regions": regions,
            "machines": machines,
            "url": f"https://{app_name}.fly.dev"
        }

    except Exception as e:
        return {"error": f"Deployment failed: {str(e)}"}


async def list_apps(org: str = None) -> dict:
    """List Fly.io applications."""
    query = """
    query($org: String) {
        apps(organizationSlug: $org) {
            nodes {
                id
                name
                status
                hostname
                currentRelease {
                    version
                    createdAt
                }
                machines {
                    nodes {
                        id
                        region
                        state
                    }
                }
            }
        }
    }
    """

    try:
        result = await graphql_query(query, {"org": org})
        apps = result.get("data", {}).get("apps", {}).get("nodes", [])

        return {
            "count": len(apps),
            "apps": [{
                "name": app["name"],
                "status": app["status"],
                "url": f"https://{app['hostname']}",
                "version": app.get("currentRelease", {}).get("version"),
                "machines": len(app.get("machines", {}).get("nodes", []))
            } for app in apps]
        }

    except Exception as e:
        return {"error": f"Failed to list apps: {str(e)}"}


async def scale_app(app_name: str, count: int,
                    region: str = None) -> dict:
    """Scale application instances."""
    try:
        async with httpx.AsyncClient() as client:
            # Get current machines
            response = await client.get(
                f"{FLY_MACHINES_API}/apps/{app_name}/machines",
                headers=get_headers()
            )
            machines = response.json()

            if region:
                machines = [m for m in machines if m["region"] == region]

            current_count = len(machines)

            if count > current_count:
                # Scale up - create new machines
                template = machines[0] if machines else None
                if not template:
                    return {"error": "No existing machine to use as template"}

                for _ in range(count - current_count):
                    await client.post(
                        f"{FLY_MACHINES_API}/apps/{app_name}/machines",
                        json={
                            "config": template["config"],
                            "region": region or template["region"]
                        },
                        headers=get_headers()
                    )

            elif count < current_count:
                # Scale down - destroy machines
                for machine in machines[count:]:
                    await client.delete(
                        f"{FLY_MACHINES_API}/apps/{app_name}/machines/{machine['id']}",
                        headers=get_headers()
                    )

            return {
                "app": app_name,
                "previous_count": current_count,
                "new_count": count,
                "region": region or "all"
            }

    except Exception as e:
        return {"error": f"Scaling failed: {str(e)}"}


async def get_status(app_name: str) -> dict:
    """Get application status and metrics."""
    query = """
    query($name: String!) {
        app(name: $name) {
            id
            name
            status
            hostname
            organization {
                slug
            }
            machines {
                nodes {
                    id
                    name
                    region
                    state
                    config {
                        image
                        guest {
                            cpuKind
                            cpus
                            memoryMb
                        }
                    }
                    events {
                        type
                        timestamp
                    }
                }
            }
            ipAddresses {
                nodes {
                    address
                    type
                }
            }
        }
    }
    """

    try:
        result = await graphql_query(query, {"name": app_name})
        app = result.get("data", {}).get("app")

        if not app:
            return {"error": f"App {app_name} not found"}

        machines = app.get("machines", {}).get("nodes", [])

        return {
            "name": app["name"],
            "status": app["status"],
            "url": f"https://{app['hostname']}",
            "organization": app.get("organization", {}).get("slug"),
            "machines": [{
                "id": m["id"],
                "region": m["region"],
                "state": m["state"],
                "image": m.get("config", {}).get("image"),
                "resources": m.get("config", {}).get("guest")
            } for m in machines],
            "ips": [ip["address"] for ip in app.get("ipAddresses", {}).get("nodes", [])]
        }

    except Exception as e:
        return {"error": f"Failed to get status: {str(e)}"}


async def invoke_machine(app_name: str, path: str = "/",
                         data: dict = None) -> dict:
    """Invoke Fly Machine directly."""
    url = f"https://{app_name}.fly.dev{path}"

    try:
        async with httpx.AsyncClient() as client:
            if data:
                response = await client.post(
                    url,
                    json=data,
                    headers={"Content-Type": "application/json"},
                    timeout=60.0
                )
            else:
                response = await client.get(url, timeout=60.0)

            return {
                "status": response.status_code,
                "headers": dict(response.headers),
                "data": response.json() if response.headers.get(
                    "content-type", ""
                ).startswith("application/json") else response.text
            }

    except Exception as e:
        return {"error": f"Invocation failed: {str(e)}"}


async def create_volume(app_name: str, name: str,
                        size_gb: int = 10, region: str = "iad") -> dict:
    """Create persistent volume."""
    try:
        async with httpx.AsyncClient() as client:
            response = await client.post(
                f"{FLY_MACHINES_API}/apps/{app_name}/volumes",
                json={
                    "name": name,
                    "size_gb": size_gb,
                    "region": region
                },
                headers=get_headers()
            )

            result = response.json()

            return {
                "volume_id": result.get("id"),
                "name": name,
                "size_gb": size_gb,
                "region": region,
                "status": "created"
            }

    except Exception as e:
        return {"error": f"Volume creation failed: {str(e)}"}
```

## Dockerfile for AI Agents

Create an optimized container:

```dockerfile
# Dockerfile
FROM python:3.11-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application
COPY . .

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s \
    CMD curl -f http://localhost:8080/health || exit 1

# Run application
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8080"]
```

## Application Code

Create the MCP agent application:

```python
# main.py
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from gantz import MCPClient
import os

app = FastAPI()
mcp = MCPClient(config_path="gantz.yaml")


class ToolRequest(BaseModel):
    tool: str
    parameters: dict = {}


@app.get("/health")
async def health():
    return {
        "status": "healthy",
        "region": os.environ.get("FLY_REGION", "unknown"),
        "app": os.environ.get("FLY_APP_NAME", "unknown")
    }


@app.post("/api/execute")
async def execute_tool(request: ToolRequest):
    try:
        result = mcp.execute_tool(request.tool, request.parameters)
        return {
            "tool": request.tool,
            "result": result,
            "region": os.environ.get("FLY_REGION")
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/api/tools")
async def list_tools():
    return {
        "tools": mcp.list_tools(),
        "region": os.environ.get("FLY_REGION")
    }
```

## Fly.io Configuration

Configure your deployment:

```toml
# fly.toml
app = "mcp-agent"
primary_region = "iad"

[build]
  dockerfile = "Dockerfile"

[env]
  GANTZ_ENABLED = "true"
  LOG_LEVEL = "info"

[http_service]
  internal_port = 8080
  force_https = true
  auto_stop_machines = true
  auto_start_machines = true
  min_machines_running = 1

  [http_service.concurrency]
    type = "requests"
    soft_limit = 200
    hard_limit = 250

[[vm]]
  cpu_kind = "shared"
  cpus = 1
  memory_mb = 512

[mounts]
  source = "mcp_data"
  destination = "/data"

[metrics]
  port = 9091
  path = "/metrics"
```

## Multi-Region Deployment

Deploy globally with one command:

```bash
# Deploy to multiple regions
fly deploy --regions iad,lhr,sin,syd

# Or configure in fly.toml
# [deploy]
#   release_command = "python migrate.py"
```

## Persistent Storage for Models

Store AI models with volumes:

```python
# model_storage.py
import os
from pathlib import Path

MODEL_PATH = Path("/data/models")


def ensure_model_directory():
    """Ensure model directory exists."""
    MODEL_PATH.mkdir(parents=True, exist_ok=True)


def download_model(model_name: str, model_url: str) -> str:
    """Download model if not cached."""
    model_file = MODEL_PATH / model_name

    if model_file.exists():
        return str(model_file)

    import httpx

    with httpx.stream("GET", model_url) as response:
        with open(model_file, "wb") as f:
            for chunk in response.iter_bytes():
                f.write(chunk)

    return str(model_file)


def list_cached_models() -> list:
    """List cached models."""
    ensure_model_directory()
    return [f.name for f in MODEL_PATH.iterdir() if f.is_file()]
```

## Auto-Scaling Configuration

Configure automatic scaling:

```toml
# fly.toml additions for auto-scaling

[http_service]
  auto_stop_machines = true
  auto_start_machines = true
  min_machines_running = 1

# Scale based on CPU/memory
[[services.autoscaling]]
  metric = "cpu"
  min_machines = 1
  max_machines = 10
  target = 70
```

## Deploy with Gantz CLI

Deploy your Fly.io application:

```bash
# Install Gantz
npm install -g gantz

# Initialize Fly.io project
gantz init --template flyio

# Login to Fly.io
fly auth login

# Deploy globally
gantz deploy --platform flyio --regions iad,lhr,sin

# Test invocation
gantz run invoke_machine \
  --app-name mcp-agent \
  --path /api/execute \
  --data '{"tool": "analyze", "parameters": {"content": "test"}}'

# Check status
gantz run get_app_status --app-name mcp-agent
```

Build globally distributed AI agents at [gantz.run](https://gantz.run).

## Related Reading

- [Vercel MCP Integration](/post/vercel-mcp-integration/) - Compare with Vercel Edge
- [Cloudflare Workers MCP](/post/cloudflare-workers-mcp/) - Compare with Cloudflare
- [MCP Connection Pooling](/post/mcp-connection-pooling/) - Optimize connections

## Conclusion

Fly.io provides an excellent platform for deploying MCP-powered AI agents globally. With simple multi-region deployment, persistent volumes for model storage, and automatic scaling, you can build responsive AI applications that run close to your users.

Start deploying AI agents to Fly.io with Gantz today.
