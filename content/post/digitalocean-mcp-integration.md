+++
title = "DigitalOcean MCP Integration: Build AI Agents on App Platform"
image = "images/digitalocean-mcp-integration.webp"
date = 2025-05-09
description = "Deploy MCP-powered AI agents on DigitalOcean App Platform. Learn container deployment, managed databases, and Kubernetes integration with Gantz."
draft = false
tags = ['digitalocean', 'app-platform', 'kubernetes', 'mcp', 'cloud', 'gantz']
voice = false
summary = "DigitalOcean keeps things simple - deploy AI agents without cloud certification. Use App Platform for automatic scaling from GitHub pushes, or DOKS (managed Kubernetes) for complex multi-container workloads. Managed Postgres and Redis are one click away, pricing is predictable, and you won't get a surprise bill at month end."

[howto]
name = "How To Deploy AI Agents on DigitalOcean with MCP"
totalTime = 35
[[howto.steps]]
name = "Create App Platform app"
text = "Initialize a new app on DigitalOcean App Platform"
[[howto.steps]]
name = "Configure MCP tools"
text = "Define tool configurations for DigitalOcean deployment"
[[howto.steps]]
name = "Set up managed databases"
text = "Provision PostgreSQL, Redis, or MongoDB clusters"
[[howto.steps]]
name = "Configure Spaces storage"
text = "Set up object storage for AI model files"
[[howto.steps]]
name = "Deploy with Gantz"
text = "Deploy and manage your AI agents using Gantz CLI"
+++

DigitalOcean offers a straightforward cloud platform for deploying MCP-powered AI agents. With App Platform for quick deployments and Kubernetes for complex workloads, you can scale your AI applications effectively.

## Why DigitalOcean for MCP?

DigitalOcean provides practical advantages for AI agents:

- **App Platform**: Deploy without managing servers
- **Managed Kubernetes**: Run containerized AI workloads
- **Managed databases**: PostgreSQL, Redis, MongoDB
- **Spaces**: S3-compatible object storage
- **Predictable pricing**: Simple, transparent costs

## DigitalOcean MCP Tool Definition

Configure DigitalOcean tools in Gantz:

```yaml
# gantz.yaml
name: digitalocean-mcp-tools
version: 1.0.0

tools:
  create_app:
    description: "Create App Platform application"
    parameters:
      name:
        type: string
        description: "Application name"
        required: true
      repo:
        type: string
        description: "GitHub repository URL"
        required: true
      branch:
        type: string
        default: "main"
      instance_size:
        type: string
        description: "basic-xxs, basic-xs, basic-s, basic-m"
        default: "basic-xs"
    handler: digitalocean.create_app

  list_apps:
    description: "List App Platform applications"
    handler: digitalocean.list_apps

  deploy_app:
    description: "Trigger app deployment"
    parameters:
      app_id:
        type: string
        required: true
    handler: digitalocean.deploy_app

  create_database:
    description: "Create managed database cluster"
    parameters:
      name:
        type: string
        required: true
      engine:
        type: string
        description: "pg, redis, mongodb, mysql"
        required: true
      size:
        type: string
        default: "db-s-1vcpu-1gb"
      region:
        type: string
        default: "nyc1"
    handler: digitalocean.create_database

  create_droplet:
    description: "Create Droplet for custom AI workloads"
    parameters:
      name:
        type: string
        required: true
      size:
        type: string
        default: "s-1vcpu-2gb"
      image:
        type: string
        default: "ubuntu-22-04-x64"
      region:
        type: string
        default: "nyc1"
    handler: digitalocean.create_droplet

  upload_to_spaces:
    description: "Upload file to Spaces object storage"
    parameters:
      space_name:
        type: string
        required: true
      file_path:
        type: string
        required: true
      object_key:
        type: string
        required: true
    handler: digitalocean.upload_to_spaces

  get_app_logs:
    description: "Get application logs"
    parameters:
      app_id:
        type: string
        required: true
      component:
        type: string
        description: "Component name"
    handler: digitalocean.get_app_logs
```

## Handler Implementation

Build handlers for DigitalOcean operations:

```python
# handlers/digitalocean.py
import httpx
import boto3
import os
from typing import Optional

DO_API = "https://api.digitalocean.com/v2"


def get_headers():
    """Get authorization headers."""
    return {
        "Authorization": f"Bearer {os.environ['DIGITALOCEAN_TOKEN']}",
        "Content-Type": "application/json"
    }


async def api_request(method: str, path: str,
                      data: dict = None) -> dict:
    """Make API request to DigitalOcean."""
    async with httpx.AsyncClient() as client:
        response = await client.request(
            method,
            f"{DO_API}{path}",
            json=data,
            headers=get_headers(),
            timeout=60.0
        )

        if response.status_code >= 400:
            return {"error": response.text}

        return response.json() if response.text else {"success": True}


async def create_app(name: str, repo: str, branch: str = "main",
                     instance_size: str = "basic-xs") -> dict:
    """Create App Platform application."""
    spec = {
        "name": name,
        "region": "nyc",
        "services": [{
            "name": name,
            "github": {
                "repo": repo,
                "branch": branch,
                "deploy_on_push": True
            },
            "instance_size_slug": instance_size,
            "instance_count": 1,
            "http_port": 8080,
            "health_check": {
                "http_path": "/health"
            },
            "envs": [{
                "key": "GANTZ_ENABLED",
                "value": "true"
            }]
        }]
    }

    try:
        result = await api_request("POST", "/apps", {"spec": spec})

        if "error" in result:
            return result

        app = result.get("app", {})

        return {
            "app_id": app.get("id"),
            "name": app.get("spec", {}).get("name"),
            "default_ingress": app.get("default_ingress"),
            "status": app.get("phase"),
            "live_url": app.get("live_url")
        }

    except Exception as e:
        return {"error": f"App creation failed: {str(e)}"}


async def list_apps() -> dict:
    """List App Platform applications."""
    try:
        result = await api_request("GET", "/apps")

        if "error" in result:
            return result

        apps = result.get("apps", [])

        return {
            "count": len(apps),
            "apps": [{
                "id": app.get("id"),
                "name": app.get("spec", {}).get("name"),
                "status": app.get("phase"),
                "live_url": app.get("live_url"),
                "updated_at": app.get("updated_at")
            } for app in apps]
        }

    except Exception as e:
        return {"error": f"Failed to list apps: {str(e)}"}


async def deploy_app(app_id: str) -> dict:
    """Trigger app deployment."""
    try:
        result = await api_request(
            "POST",
            f"/apps/{app_id}/deployments",
            {"force_build": True}
        )

        if "error" in result:
            return result

        deployment = result.get("deployment", {})

        return {
            "deployment_id": deployment.get("id"),
            "app_id": app_id,
            "phase": deployment.get("phase"),
            "created_at": deployment.get("created_at"),
            "message": "Deployment triggered"
        }

    except Exception as e:
        return {"error": f"Deployment failed: {str(e)}"}


async def create_database(name: str, engine: str,
                          size: str = "db-s-1vcpu-1gb",
                          region: str = "nyc1") -> dict:
    """Create managed database cluster."""
    # Map engine names
    engine_map = {
        "pg": "pg",
        "postgres": "pg",
        "postgresql": "pg",
        "redis": "redis",
        "mongodb": "mongodb",
        "mysql": "mysql"
    }

    db_engine = engine_map.get(engine.lower())
    if not db_engine:
        return {"error": f"Unsupported engine: {engine}"}

    try:
        result = await api_request("POST", "/databases", {
            "name": name,
            "engine": db_engine,
            "size": size,
            "region": region,
            "num_nodes": 1,
            "version": "15" if db_engine == "pg" else None
        })

        if "error" in result:
            return result

        db = result.get("database", {})

        return {
            "id": db.get("id"),
            "name": db.get("name"),
            "engine": db.get("engine"),
            "status": db.get("status"),
            "connection": {
                "host": db.get("connection", {}).get("host"),
                "port": db.get("connection", {}).get("port"),
                "database": db.get("connection", {}).get("database"),
                "user": db.get("connection", {}).get("user"),
                "uri": db.get("connection", {}).get("uri")
            },
            "region": region
        }

    except Exception as e:
        return {"error": f"Database creation failed: {str(e)}"}


async def create_droplet(name: str, size: str = "s-1vcpu-2gb",
                         image: str = "ubuntu-22-04-x64",
                         region: str = "nyc1") -> dict:
    """Create Droplet for custom workloads."""
    try:
        result = await api_request("POST", "/droplets", {
            "name": name,
            "region": region,
            "size": size,
            "image": image,
            "tags": ["mcp-agent", "gantz"]
        })

        if "error" in result:
            return result

        droplet = result.get("droplet", {})

        return {
            "id": droplet.get("id"),
            "name": droplet.get("name"),
            "status": droplet.get("status"),
            "size": size,
            "region": region,
            "networks": droplet.get("networks"),
            "message": "Droplet is being created"
        }

    except Exception as e:
        return {"error": f"Droplet creation failed: {str(e)}"}


async def upload_to_spaces(space_name: str, file_path: str,
                           object_key: str) -> dict:
    """Upload file to Spaces object storage."""
    try:
        session = boto3.session.Session()
        client = session.client(
            's3',
            region_name=os.environ.get('SPACES_REGION', 'nyc3'),
            endpoint_url=f"https://{os.environ.get('SPACES_REGION', 'nyc3')}.digitaloceanspaces.com",
            aws_access_key_id=os.environ['SPACES_KEY'],
            aws_secret_access_key=os.environ['SPACES_SECRET']
        )

        client.upload_file(file_path, space_name, object_key)

        return {
            "space": space_name,
            "key": object_key,
            "url": f"https://{space_name}.{os.environ.get('SPACES_REGION', 'nyc3')}.digitaloceanspaces.com/{object_key}",
            "status": "uploaded"
        }

    except Exception as e:
        return {"error": f"Upload failed: {str(e)}"}


async def get_app_logs(app_id: str, component: str = None) -> dict:
    """Get application logs."""
    try:
        path = f"/apps/{app_id}/logs"
        if component:
            path += f"?component_name={component}"

        result = await api_request("GET", path)

        if "error" in result:
            return result

        return {
            "app_id": app_id,
            "component": component,
            "logs": result.get("live_url"),  # DO returns a URL to stream logs
            "historic_urls": result.get("historic_urls", [])
        }

    except Exception as e:
        return {"error": f"Failed to get logs: {str(e)}"}
```

## App Platform Spec

Define your application:

```yaml
# .do/app.yaml
name: mcp-agent
region: nyc
services:
  - name: api
    github:
      repo: yourusername/mcp-agent
      branch: main
      deploy_on_push: true
    dockerfile_path: Dockerfile
    instance_size_slug: basic-xs
    instance_count: 1
    http_port: 8080
    health_check:
      http_path: /health
      initial_delay_seconds: 10
      period_seconds: 30
    envs:
      - key: GANTZ_ENABLED
        value: "true"
      - key: DATABASE_URL
        scope: RUN_TIME
        value: ${db.DATABASE_URL}
      - key: REDIS_URL
        scope: RUN_TIME
        value: ${cache.REDIS_URL}

  - name: worker
    github:
      repo: yourusername/mcp-agent
      branch: main
    dockerfile_path: Dockerfile.worker
    instance_size_slug: basic-xs
    instance_count: 1
    envs:
      - key: REDIS_URL
        scope: RUN_TIME
        value: ${cache.REDIS_URL}

databases:
  - name: db
    engine: PG
    version: "15"
    size: db-s-1vcpu-1gb
    num_nodes: 1

  - name: cache
    engine: REDIS
    version: "7"
    size: db-s-1vcpu-1gb
    num_nodes: 1
```

## Application Code

Create the MCP agent:

```python
# main.py
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from gantz import MCPClient
import os

app = FastAPI(title="MCP Agent on DigitalOcean")
mcp = MCPClient(config_path="gantz.yaml")


class ToolRequest(BaseModel):
    tool: str
    parameters: dict = {}


@app.get("/")
async def root():
    return {
        "service": "mcp-agent",
        "platform": "digitalocean-app-platform",
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

## Dockerfile

Container configuration:

```dockerfile
# Dockerfile
FROM python:3.11-slim

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application
COPY . .

# Run as non-root
RUN useradd -m appuser && chown -R appuser:appuser /app
USER appuser

EXPOSE 8080

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8080"]
```

## Kubernetes Deployment

For complex AI workloads, use DOKS:

```yaml
# k8s/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mcp-agent
  labels:
    app: mcp-agent
spec:
  replicas: 3
  selector:
    matchLabels:
      app: mcp-agent
  template:
    metadata:
      labels:
        app: mcp-agent
    spec:
      containers:
        - name: mcp-agent
          image: registry.digitalocean.com/your-registry/mcp-agent:latest
          ports:
            - containerPort: 8080
          env:
            - name: GANTZ_ENABLED
              value: "true"
            - name: DATABASE_URL
              valueFrom:
                secretKeyRef:
                  name: db-credentials
                  key: url
          resources:
            requests:
              memory: "256Mi"
              cpu: "250m"
            limits:
              memory: "512Mi"
              cpu: "500m"
          livenessProbe:
            httpGet:
              path: /health
              port: 8080
            initialDelaySeconds: 10
            periodSeconds: 30
          readinessProbe:
            httpGet:
              path: /health
              port: 8080
            initialDelaySeconds: 5
            periodSeconds: 10
---
apiVersion: v1
kind: Service
metadata:
  name: mcp-agent-service
spec:
  selector:
    app: mcp-agent
  ports:
    - port: 80
      targetPort: 8080
  type: LoadBalancer
```

## Spaces for Model Storage

Store AI models in Spaces:

```python
# model_storage.py
import boto3
import os
from pathlib import Path

SPACES_REGION = os.environ.get('SPACES_REGION', 'nyc3')
SPACES_BUCKET = os.environ.get('SPACES_BUCKET', 'mcp-models')


def get_spaces_client():
    """Get Spaces (S3-compatible) client."""
    return boto3.client(
        's3',
        region_name=SPACES_REGION,
        endpoint_url=f"https://{SPACES_REGION}.digitaloceanspaces.com",
        aws_access_key_id=os.environ['SPACES_KEY'],
        aws_secret_access_key=os.environ['SPACES_SECRET']
    )


def download_model(model_name: str, local_path: str) -> str:
    """Download model from Spaces."""
    client = get_spaces_client()

    local_file = Path(local_path) / model_name
    local_file.parent.mkdir(parents=True, exist_ok=True)

    if not local_file.exists():
        client.download_file(SPACES_BUCKET, f"models/{model_name}", str(local_file))

    return str(local_file)


def upload_model(local_path: str, model_name: str) -> str:
    """Upload model to Spaces."""
    client = get_spaces_client()

    key = f"models/{model_name}"
    client.upload_file(local_path, SPACES_BUCKET, key)

    return f"https://{SPACES_BUCKET}.{SPACES_REGION}.digitaloceanspaces.com/{key}"


def list_models() -> list:
    """List available models."""
    client = get_spaces_client()

    response = client.list_objects_v2(
        Bucket=SPACES_BUCKET,
        Prefix="models/"
    )

    return [
        obj['Key'].replace('models/', '')
        for obj in response.get('Contents', [])
    ]
```

## Deploy with Gantz CLI

Deploy to DigitalOcean:

```bash
# Install Gantz
npm install -g gantz

# Initialize DigitalOcean project
gantz init --template digitalocean

# Create App Platform app
gantz run create_app \
  --name mcp-agent \
  --repo yourusername/mcp-agent \
  --instance-size basic-xs

# Create database
gantz run create_database \
  --name mcp-db \
  --engine pg \
  --size db-s-1vcpu-1gb

# Trigger deployment
gantz run deploy_app --app-id your-app-id

# Upload model to Spaces
gantz run upload_to_spaces \
  --space-name mcp-models \
  --file-path ./models/my-model.bin \
  --object-key models/my-model.bin
```

Build cloud AI agents at [gantz.run](https://gantz.run).

## Related Reading

- [Render MCP Integration](/post/render-mcp-integration/) - Compare with Render
- [S3 MCP Integration](/post/s3-mcp-integration/) - Object storage patterns
- [PostgreSQL MCP Integration](/post/postgresql-mcp-integration/) - Database tools

## Conclusion

DigitalOcean provides a straightforward platform for deploying MCP-powered AI agents. With App Platform for simple deployments, DOKS for Kubernetes workloads, and Spaces for model storage, you have the flexibility to build AI applications at any scale.

Start deploying AI agents to DigitalOcean with Gantz today.
