+++
title = "Heroku MCP Integration: Deploy AI Agents with Git Push"
image = "/images/heroku-mcp-integration.png"
date = 2025-05-10
description = "Deploy MCP-powered AI agents on Heroku. Learn dyno management, add-ons integration, pipeline deployments, and review apps with Gantz."
draft = false
tags = ['heroku', 'paas', 'deployment', 'mcp', 'git', 'gantz']
voice = false

[howto]
name = "How To Deploy AI Agents on Heroku with MCP"
totalTime = 25
[[howto.steps]]
name = "Create Heroku app"
text = "Initialize a new Heroku application"
[[howto.steps]]
name = "Configure MCP tools"
text = "Define tool configurations for Heroku deployment"
[[howto.steps]]
name = "Set up add-ons"
text = "Provision Postgres, Redis, and other services"
[[howto.steps]]
name = "Configure pipelines"
text = "Set up staging and production environments"
[[howto.steps]]
name = "Deploy with Gantz"
text = "Deploy and manage your AI agents using Gantz CLI"
+++

Heroku pioneered platform-as-a-service deployment, making it simple to deploy MCP-powered AI agents with just a git push. With a rich ecosystem of add-ons and mature deployment pipelines, Heroku remains a solid choice for AI applications.

## Why Heroku for MCP?

Heroku offers proven advantages for AI agents:

- **Git-based deployment**: Deploy with `git push`
- **Add-on ecosystem**: 200+ services available
- **Pipelines**: Staging to production workflows
- **Review apps**: Test PRs in isolated environments
- **Heroku Postgres**: Managed database with AI extensions

## Heroku MCP Tool Definition

Configure Heroku tools in Gantz:

```yaml
# gantz.yaml
name: heroku-mcp-tools
version: 1.0.0

tools:
  create_app:
    description: "Create Heroku application"
    parameters:
      name:
        type: string
        description: "Application name"
        required: true
      region:
        type: string
        description: "us or eu"
        default: "us"
      stack:
        type: string
        description: "heroku-22 or container"
        default: "heroku-22"
    handler: heroku.create_app

  list_apps:
    description: "List Heroku applications"
    handler: heroku.list_apps

  deploy_app:
    description: "Deploy application"
    parameters:
      app_name:
        type: string
        required: true
      source_url:
        type: string
        description: "Tarball URL for source deployment"
    handler: heroku.deploy_app

  scale_dynos:
    description: "Scale application dynos"
    parameters:
      app_name:
        type: string
        required: true
      dyno_type:
        type: string
        description: "web, worker, etc."
        required: true
      quantity:
        type: integer
        required: true
    handler: heroku.scale_dynos

  add_addon:
    description: "Add add-on to application"
    parameters:
      app_name:
        type: string
        required: true
      addon:
        type: string
        description: "Add-on name (e.g., heroku-postgresql)"
        required: true
      plan:
        type: string
        default: "hobby-dev"
    handler: heroku.add_addon

  set_config:
    description: "Set configuration variables"
    parameters:
      app_name:
        type: string
        required: true
      config:
        type: object
        description: "Key-value pairs"
        required: true
    handler: heroku.set_config

  get_logs:
    description: "Get application logs"
    parameters:
      app_name:
        type: string
        required: true
      lines:
        type: integer
        default: 100
      dyno:
        type: string
        description: "Specific dyno to get logs from"
    handler: heroku.get_logs

  run_command:
    description: "Run one-off dyno command"
    parameters:
      app_name:
        type: string
        required: true
      command:
        type: string
        required: true
    handler: heroku.run_command
```

## Handler Implementation

Build handlers for Heroku operations:

```python
# handlers/heroku.py
import httpx
import os
from typing import Optional

HEROKU_API = "https://api.heroku.com"


def get_headers():
    """Get authorization headers."""
    return {
        "Authorization": f"Bearer {os.environ['HEROKU_API_KEY']}",
        "Accept": "application/vnd.heroku+json; version=3",
        "Content-Type": "application/json"
    }


async def api_request(method: str, path: str,
                      data: dict = None) -> dict:
    """Make API request to Heroku."""
    async with httpx.AsyncClient() as client:
        response = await client.request(
            method,
            f"{HEROKU_API}{path}",
            json=data,
            headers=get_headers(),
            timeout=60.0
        )

        if response.status_code >= 400:
            return {"error": response.json().get("message", response.text)}

        return response.json() if response.text else {"success": True}


async def create_app(name: str, region: str = "us",
                     stack: str = "heroku-22") -> dict:
    """Create Heroku application."""
    try:
        result = await api_request("POST", "/apps", {
            "name": name,
            "region": region,
            "stack": stack
        })

        if "error" in result:
            return result

        return {
            "id": result.get("id"),
            "name": result.get("name"),
            "web_url": result.get("web_url"),
            "git_url": result.get("git_url"),
            "region": result.get("region", {}).get("name"),
            "stack": result.get("stack", {}).get("name")
        }

    except Exception as e:
        return {"error": f"App creation failed: {str(e)}"}


async def list_apps() -> dict:
    """List Heroku applications."""
    try:
        result = await api_request("GET", "/apps")

        if isinstance(result, dict) and "error" in result:
            return result

        return {
            "count": len(result),
            "apps": [{
                "id": app.get("id"),
                "name": app.get("name"),
                "web_url": app.get("web_url"),
                "region": app.get("region", {}).get("name"),
                "updated_at": app.get("updated_at")
            } for app in result]
        }

    except Exception as e:
        return {"error": f"Failed to list apps: {str(e)}"}


async def deploy_app(app_name: str, source_url: str = None) -> dict:
    """Deploy application."""
    try:
        if source_url:
            # Source deployment
            result = await api_request(
                "POST",
                f"/apps/{app_name}/builds",
                {"source_blob": {"url": source_url}}
            )
        else:
            # Trigger rebuild
            result = await api_request(
                "POST",
                f"/apps/{app_name}/builds",
                {}
            )

        if "error" in result:
            return result

        return {
            "build_id": result.get("id"),
            "app": app_name,
            "status": result.get("status"),
            "created_at": result.get("created_at"),
            "message": "Build started"
        }

    except Exception as e:
        return {"error": f"Deployment failed: {str(e)}"}


async def scale_dynos(app_name: str, dyno_type: str,
                      quantity: int) -> dict:
    """Scale application dynos."""
    try:
        result = await api_request(
            "PATCH",
            f"/apps/{app_name}/formation/{dyno_type}",
            {"quantity": quantity}
        )

        if "error" in result:
            return result

        return {
            "app": app_name,
            "dyno_type": dyno_type,
            "quantity": result.get("quantity"),
            "size": result.get("size"),
            "message": "Dynos scaled"
        }

    except Exception as e:
        return {"error": f"Scaling failed: {str(e)}"}


async def add_addon(app_name: str, addon: str,
                    plan: str = "hobby-dev") -> dict:
    """Add add-on to application."""
    try:
        result = await api_request(
            "POST",
            f"/apps/{app_name}/addons",
            {"plan": f"{addon}:{plan}"}
        )

        if "error" in result:
            return result

        return {
            "id": result.get("id"),
            "addon": result.get("addon_service", {}).get("name"),
            "plan": result.get("plan", {}).get("name"),
            "state": result.get("state"),
            "config_vars": result.get("config_vars"),
            "message": "Add-on provisioned"
        }

    except Exception as e:
        return {"error": f"Add-on provisioning failed: {str(e)}"}


async def set_config(app_name: str, config: dict) -> dict:
    """Set configuration variables."""
    try:
        result = await api_request(
            "PATCH",
            f"/apps/{app_name}/config-vars",
            config
        )

        if "error" in result:
            return result

        return {
            "app": app_name,
            "variables_set": list(config.keys()),
            "message": "Config vars updated"
        }

    except Exception as e:
        return {"error": f"Failed to set config: {str(e)}"}


async def get_logs(app_name: str, lines: int = 100,
                   dyno: str = None) -> dict:
    """Get application logs."""
    try:
        params = {"lines": lines, "tail": False}
        if dyno:
            params["dyno"] = dyno

        # Get log session
        result = await api_request(
            "POST",
            f"/apps/{app_name}/log-sessions",
            params
        )

        if "error" in result:
            return result

        # Fetch actual logs from the URL
        log_url = result.get("logplex_url")

        async with httpx.AsyncClient() as client:
            log_response = await client.get(log_url, timeout=30.0)
            logs = log_response.text.split("\n")

        return {
            "app": app_name,
            "dyno": dyno,
            "lines": len(logs),
            "logs": logs
        }

    except Exception as e:
        return {"error": f"Failed to get logs: {str(e)}"}


async def run_command(app_name: str, command: str) -> dict:
    """Run one-off dyno command."""
    try:
        result = await api_request(
            "POST",
            f"/apps/{app_name}/dynos",
            {
                "command": command,
                "attach": False,
                "type": "run"
            }
        )

        if "error" in result:
            return result

        return {
            "dyno_id": result.get("id"),
            "name": result.get("name"),
            "command": command,
            "state": result.get("state"),
            "message": "One-off dyno started"
        }

    except Exception as e:
        return {"error": f"Command execution failed: {str(e)}"}
```

## Application Setup

Create the MCP agent application:

```python
# main.py
from flask import Flask, request, jsonify
from gantz import MCPClient
import os

app = Flask(__name__)
mcp = MCPClient(config_path="gantz.yaml")


@app.route("/")
def root():
    return jsonify({
        "service": "mcp-agent",
        "platform": "heroku",
        "dyno": os.environ.get("DYNO", "unknown"),
        "status": "running"
    })


@app.route("/health")
def health():
    return jsonify({"status": "healthy"})


@app.route("/api/execute", methods=["POST"])
def execute_tool():
    data = request.get_json()
    tool = data.get("tool")
    parameters = data.get("parameters", {})

    if not tool:
        return jsonify({"error": "Tool name required"}), 400

    try:
        result = mcp.execute_tool(tool, parameters)
        return jsonify({"tool": tool, "result": result})
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/api/tools")
def list_tools():
    return jsonify({"tools": mcp.list_tools()})


if __name__ == "__main__":
    port = int(os.environ.get("PORT", 5000))
    app.run(host="0.0.0.0", port=port)
```

## Procfile Configuration

Define your dynos:

```procfile
# Procfile
web: gunicorn main:app
worker: python worker.py
release: python manage.py migrate
```

## Requirements

```txt
# requirements.txt
flask==3.0.0
gunicorn==21.2.0
gantz>=1.0.0
psycopg2-binary==2.9.9
redis==5.0.0
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
                3600,
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

## Pipeline Configuration

Set up deployment pipeline:

```json
// app.json
{
  "name": "MCP Agent",
  "description": "MCP-powered AI agent on Heroku",
  "repository": "https://github.com/yourusername/mcp-agent",
  "keywords": ["mcp", "ai", "agent", "gantz"],
  "stack": "heroku-22",
  "env": {
    "GANTZ_ENABLED": {
      "description": "Enable Gantz MCP",
      "value": "true"
    },
    "LOG_LEVEL": {
      "description": "Logging level",
      "value": "INFO"
    }
  },
  "formation": {
    "web": {
      "quantity": 1,
      "size": "basic"
    },
    "worker": {
      "quantity": 1,
      "size": "basic"
    }
  },
  "addons": [
    {
      "plan": "heroku-postgresql:essential-0"
    },
    {
      "plan": "heroku-redis:mini"
    }
  ],
  "buildpacks": [
    {
      "url": "heroku/python"
    }
  ],
  "environments": {
    "test": {
      "addons": [
        "heroku-postgresql:essential-0"
      ],
      "scripts": {
        "test": "pytest"
      }
    },
    "review": {
      "addons": [
        "heroku-postgresql:essential-0"
      ]
    }
  }
}
```

## Heroku Postgres with pgvector

Enable vector search for AI:

```python
# database.py
import os
import psycopg2
from pgvector.psycopg2 import register_vector

DATABASE_URL = os.environ.get("DATABASE_URL")


def get_connection():
    """Get database connection with pgvector support."""
    conn = psycopg2.connect(DATABASE_URL)
    register_vector(conn)
    return conn


def setup_vector_extension():
    """Enable pgvector extension."""
    conn = get_connection()
    cur = conn.cursor()

    cur.execute("CREATE EXTENSION IF NOT EXISTS vector")
    cur.execute("""
        CREATE TABLE IF NOT EXISTS embeddings (
            id SERIAL PRIMARY KEY,
            content TEXT,
            embedding vector(1536),
            metadata JSONB
        )
    """)
    cur.execute("""
        CREATE INDEX IF NOT EXISTS embeddings_idx
        ON embeddings USING ivfflat (embedding vector_cosine_ops)
    """)

    conn.commit()
    cur.close()
    conn.close()


def search_similar(embedding: list, limit: int = 10) -> list:
    """Search for similar embeddings."""
    conn = get_connection()
    cur = conn.cursor()

    cur.execute("""
        SELECT id, content, metadata, 1 - (embedding <=> %s) as similarity
        FROM embeddings
        ORDER BY embedding <=> %s
        LIMIT %s
    """, (embedding, embedding, limit))

    results = cur.fetchall()
    cur.close()
    conn.close()

    return [{
        "id": r[0],
        "content": r[1],
        "metadata": r[2],
        "similarity": r[3]
    } for r in results]
```

## Review Apps

Configure review apps for PR testing:

```json
// app.json (review app section)
{
  "environments": {
    "review": {
      "scripts": {
        "postdeploy": "python setup_review.py"
      },
      "addons": [
        "heroku-postgresql:essential-0",
        "heroku-redis:mini"
      ],
      "env": {
        "REVIEW_APP": "true"
      }
    }
  }
}
```

## Scheduler for Cron Jobs

Use Heroku Scheduler for periodic tasks:

```python
# scheduled_task.py
from gantz import MCPClient
from datetime import datetime
import os

mcp = MCPClient()


def run_scheduled_task():
    """Run scheduled AI task."""
    print(f"Running scheduled task at {datetime.now()}")

    result = mcp.execute_tool("daily_summary", {
        "date": datetime.now().strftime("%Y-%m-%d")
    })

    print(f"Task result: {result}")


if __name__ == "__main__":
    run_scheduled_task()
```

Add to Heroku Scheduler:
```bash
heroku addons:create scheduler:standard
heroku addons:open scheduler
# Add job: python scheduled_task.py
```

## Deploy with Gantz CLI

Deploy your Heroku application:

```bash
# Install Gantz
npm install -g gantz

# Initialize Heroku project
gantz init --template heroku

# Create app
gantz run create_app \
  --name mcp-agent \
  --region us

# Add database
gantz run add_addon \
  --app-name mcp-agent \
  --addon heroku-postgresql \
  --plan essential-0

# Add Redis
gantz run add_addon \
  --app-name mcp-agent \
  --addon heroku-redis \
  --plan mini

# Set config vars
gantz run set_config \
  --app-name mcp-agent \
  --config '{"GANTZ_ENABLED": "true", "LOG_LEVEL": "INFO"}'

# Deploy via Git
git push heroku main

# Scale dynos
gantz run scale_dynos \
  --app-name mcp-agent \
  --dyno-type web \
  --quantity 2

# View logs
gantz run get_logs --app-name mcp-agent --lines 200
```

Build and deploy AI agents simply at [gantz.run](https://gantz.run).

## Related Reading

- [Railway MCP Integration](/post/railway-mcp-integration/) - Compare with Railway
- [PostgreSQL MCP Integration](/post/postgresql-mcp-integration/) - Database integration
- [Redis MCP Tools](/post/redis-mcp-tools/) - Caching and queues

## Conclusion

Heroku provides a mature, reliable platform for deploying MCP-powered AI agents. With git-based deployments, a rich add-on ecosystem, and features like review apps and pipelines, Heroku makes it easy to build, test, and ship AI applications.

Start deploying AI agents to Heroku with Gantz today.
