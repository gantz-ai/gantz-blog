+++
title = "FastAPI MCP Integration: Build AI-Powered APIs"
image = "/images/fastapi-mcp-integration.png"
date = 2025-11-15
description = "Integrate MCP tools with FastAPI applications. Build AI-powered REST APIs with tool execution, async support, and dependency injection patterns."
draft = false
tags = ['mcp', 'fastapi', 'python', 'api']
voice = false

[howto]
name = "Integrate MCP with FastAPI"
totalTime = 30
[[howto.steps]]
name = "Set up FastAPI project"
text = "Create FastAPI app with MCP dependencies."
[[howto.steps]]
name = "Create tool endpoints"
text = "Expose MCP tools as REST endpoints."
[[howto.steps]]
name = "Add async tool execution"
text = "Implement async handlers for tools."
[[howto.steps]]
name = "Configure dependency injection"
text = "Inject MCP clients into routes."
[[howto.steps]]
name = "Add streaming responses"
text = "Stream LLM responses through FastAPI."
+++


FastAPI is fast. MCP tools are powerful.

Together, they build AI-powered APIs.

## Why FastAPI + MCP

FastAPI provides:
- Async support out of the box
- Automatic OpenAPI documentation
- Type validation with Pydantic
- Dependency injection

MCP provides:
- AI agent tool execution
- LLM integration
- Multi-model orchestration

## Step 1: Project setup

Using [Gantz](https://gantz.run):

```yaml
# gantz.yaml
name: fastapi-mcp-api

tools:
  - name: generate_text
    description: Generate text using LLM
    parameters:
      - name: prompt
        type: string
        required: true
      - name: max_tokens
        type: integer
        default: 500
    script:
      command: python
      args: ["tools/generate.py"]

  - name: analyze_data
    description: Analyze data with AI
    parameters:
      - name: data
        type: object
        required: true
    script:
      command: python
      args: ["tools/analyze.py"]
```

FastAPI application setup:

```python
from fastapi import FastAPI, HTTPException, Depends, BackgroundTasks
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
from typing import Optional, List, Dict, Any
import asyncio

app = FastAPI(
    title="MCP Tools API",
    description="AI-powered API with MCP tools",
    version="1.0.0"
)

# Pydantic models
class ToolRequest(BaseModel):
    tool_name: str
    parameters: Dict[str, Any]

class ToolResponse(BaseModel):
    success: bool
    result: Optional[Dict[str, Any]] = None
    error: Optional[str] = None

class GenerateRequest(BaseModel):
    prompt: str
    max_tokens: int = 500
    stream: bool = False

class AnalyzeRequest(BaseModel):
    data: Dict[str, Any]
    analysis_type: str = "summary"
```

## Step 2: MCP tool service

Create a service to manage MCP tools:

```python
from typing import Dict, Any, Callable, Awaitable
import subprocess
import json
import asyncio

class MCPToolService:
    """Service for executing MCP tools."""

    def __init__(self):
        self.tools: Dict[str, Dict] = {}
        self._load_tools()

    def _load_tools(self):
        """Load tool definitions from config."""
        # In production, load from gantz.yaml
        self.tools = {
            "generate_text": {
                "description": "Generate text using LLM",
                "handler": self._generate_text
            },
            "analyze_data": {
                "description": "Analyze data with AI",
                "handler": self._analyze_data
            }
        }

    async def execute(
        self,
        tool_name: str,
        parameters: Dict[str, Any]
    ) -> Dict[str, Any]:
        """Execute a tool asynchronously."""
        if tool_name not in self.tools:
            raise ValueError(f"Tool not found: {tool_name}")

        handler = self.tools[tool_name]["handler"]
        return await handler(parameters)

    async def _generate_text(self, params: Dict[str, Any]) -> Dict[str, Any]:
        """Generate text with LLM."""
        import anthropic

        client = anthropic.AsyncAnthropic()

        response = await client.messages.create(
            model="claude-sonnet-4-20250514",
            max_tokens=params.get("max_tokens", 500),
            messages=[{"role": "user", "content": params["prompt"]}]
        )

        return {
            "text": response.content[0].text,
            "model": response.model,
            "usage": {
                "input_tokens": response.usage.input_tokens,
                "output_tokens": response.usage.output_tokens
            }
        }

    async def _analyze_data(self, params: Dict[str, Any]) -> Dict[str, Any]:
        """Analyze data with AI."""
        data = params["data"]
        analysis_type = params.get("analysis_type", "summary")

        prompt = f"Analyze this data and provide a {analysis_type}:\n{json.dumps(data, indent=2)}"

        result = await self._generate_text({"prompt": prompt, "max_tokens": 1000})
        return {
            "analysis": result["text"],
            "type": analysis_type
        }

    def list_tools(self) -> List[Dict[str, str]]:
        """List available tools."""
        return [
            {"name": name, "description": info["description"]}
            for name, info in self.tools.items()
        ]

# Singleton instance
tool_service = MCPToolService()
```

## Step 3: Dependency injection

Inject MCP services into routes:

```python
from fastapi import Depends

# Dependency to get tool service
async def get_tool_service() -> MCPToolService:
    return tool_service

# Dependency for rate limiting
class RateLimiter:
    def __init__(self, requests_per_minute: int = 60):
        self.requests_per_minute = requests_per_minute
        self.requests: Dict[str, List[float]] = {}

    async def __call__(self, request: Request) -> bool:
        import time

        client_ip = request.client.host
        now = time.time()

        if client_ip not in self.requests:
            self.requests[client_ip] = []

        # Remove old requests
        self.requests[client_ip] = [
            t for t in self.requests[client_ip]
            if now - t < 60
        ]

        if len(self.requests[client_ip]) >= self.requests_per_minute:
            raise HTTPException(
                status_code=429,
                detail="Rate limit exceeded"
            )

        self.requests[client_ip].append(now)
        return True

rate_limiter = RateLimiter(requests_per_minute=60)

# Dependency for API key authentication
async def verify_api_key(
    x_api_key: str = Header(None)
) -> str:
    if not x_api_key:
        raise HTTPException(
            status_code=401,
            detail="API key required"
        )

    # Validate API key
    if not is_valid_api_key(x_api_key):
        raise HTTPException(
            status_code=403,
            detail="Invalid API key"
        )

    return x_api_key
```

## Step 4: Tool endpoints

Create REST endpoints for tools:

```python
from fastapi import Request, Header

@app.get("/tools")
async def list_tools(
    service: MCPToolService = Depends(get_tool_service)
) -> List[Dict[str, str]]:
    """List all available MCP tools."""
    return service.list_tools()

@app.post("/tools/execute", response_model=ToolResponse)
async def execute_tool(
    request: ToolRequest,
    service: MCPToolService = Depends(get_tool_service),
    _: bool = Depends(rate_limiter)
) -> ToolResponse:
    """Execute an MCP tool."""
    try:
        result = await service.execute(
            request.tool_name,
            request.parameters
        )
        return ToolResponse(success=True, result=result)
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except Exception as e:
        return ToolResponse(success=False, error=str(e))

@app.post("/generate")
async def generate_text(
    request: GenerateRequest,
    service: MCPToolService = Depends(get_tool_service)
):
    """Generate text with LLM."""
    if request.stream:
        return StreamingResponse(
            stream_generation(request.prompt, request.max_tokens),
            media_type="text/event-stream"
        )

    result = await service.execute("generate_text", {
        "prompt": request.prompt,
        "max_tokens": request.max_tokens
    })

    return result

@app.post("/analyze")
async def analyze_data(
    request: AnalyzeRequest,
    service: MCPToolService = Depends(get_tool_service)
) -> Dict[str, Any]:
    """Analyze data with AI."""
    return await service.execute("analyze_data", {
        "data": request.data,
        "analysis_type": request.analysis_type
    })
```

## Step 5: Streaming responses

Stream LLM responses:

```python
from fastapi.responses import StreamingResponse
import anthropic

async def stream_generation(
    prompt: str,
    max_tokens: int = 500
):
    """Stream text generation."""
    client = anthropic.AsyncAnthropic()

    async with client.messages.stream(
        model="claude-sonnet-4-20250514",
        max_tokens=max_tokens,
        messages=[{"role": "user", "content": prompt}]
    ) as stream:
        async for text in stream.text_stream:
            yield f"data: {json.dumps({'text': text})}\n\n"

    yield "data: [DONE]\n\n"

@app.post("/chat/stream")
async def stream_chat(
    request: GenerateRequest,
    _: str = Depends(verify_api_key)
):
    """Stream chat response."""
    return StreamingResponse(
        stream_generation(request.prompt, request.max_tokens),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive"
        }
    )

# WebSocket for bidirectional streaming
from fastapi import WebSocket, WebSocketDisconnect

@app.websocket("/ws/chat")
async def websocket_chat(websocket: WebSocket):
    """WebSocket endpoint for chat."""
    await websocket.accept()

    client = anthropic.AsyncAnthropic()

    try:
        while True:
            # Receive message
            data = await websocket.receive_json()
            prompt = data.get("prompt", "")

            # Stream response
            async with client.messages.stream(
                model="claude-sonnet-4-20250514",
                max_tokens=data.get("max_tokens", 500),
                messages=[{"role": "user", "content": prompt}]
            ) as stream:
                async for text in stream.text_stream:
                    await websocket.send_json({"text": text, "done": False})

            await websocket.send_json({"text": "", "done": True})

    except WebSocketDisconnect:
        pass
```

## Step 6: Background tasks

Execute tools in background:

```python
from fastapi import BackgroundTasks
from uuid import uuid4

# Task storage
tasks: Dict[str, Dict] = {}

class TaskStatus(BaseModel):
    task_id: str
    status: str  # pending, running, completed, failed
    result: Optional[Dict] = None
    error: Optional[str] = None

async def run_tool_background(
    task_id: str,
    tool_name: str,
    parameters: Dict[str, Any]
):
    """Run tool in background."""
    tasks[task_id]["status"] = "running"

    try:
        result = await tool_service.execute(tool_name, parameters)
        tasks[task_id]["status"] = "completed"
        tasks[task_id]["result"] = result
    except Exception as e:
        tasks[task_id]["status"] = "failed"
        tasks[task_id]["error"] = str(e)

@app.post("/tools/execute/async")
async def execute_tool_async(
    request: ToolRequest,
    background_tasks: BackgroundTasks
) -> Dict[str, str]:
    """Execute tool asynchronously."""
    task_id = str(uuid4())

    tasks[task_id] = {
        "status": "pending",
        "result": None,
        "error": None
    }

    background_tasks.add_task(
        run_tool_background,
        task_id,
        request.tool_name,
        request.parameters
    )

    return {"task_id": task_id}

@app.get("/tasks/{task_id}", response_model=TaskStatus)
async def get_task_status(task_id: str) -> TaskStatus:
    """Get task status."""
    if task_id not in tasks:
        raise HTTPException(status_code=404, detail="Task not found")

    task = tasks[task_id]
    return TaskStatus(
        task_id=task_id,
        status=task["status"],
        result=task["result"],
        error=task["error"]
    )
```

## Step 7: Error handling

Global error handling:

```python
from fastapi import Request
from fastapi.responses import JSONResponse
from fastapi.exceptions import RequestValidationError

@app.exception_handler(RequestValidationError)
async def validation_exception_handler(
    request: Request,
    exc: RequestValidationError
):
    """Handle validation errors."""
    return JSONResponse(
        status_code=422,
        content={
            "success": False,
            "error": "Validation error",
            "details": exc.errors()
        }
    )

@app.exception_handler(Exception)
async def global_exception_handler(
    request: Request,
    exc: Exception
):
    """Handle all other exceptions."""
    return JSONResponse(
        status_code=500,
        content={
            "success": False,
            "error": str(exc)
        }
    )

# Middleware for logging
@app.middleware("http")
async def log_requests(request: Request, call_next):
    """Log all requests."""
    import time

    start = time.time()
    response = await call_next(request)
    duration = time.time() - start

    print(f"{request.method} {request.url.path} - {response.status_code} ({duration:.2f}s)")

    return response
```

## Summary

FastAPI + MCP integration:

1. **Project setup** - FastAPI with MCP dependencies
2. **Tool service** - Async tool execution
3. **Dependency injection** - Clean service management
4. **REST endpoints** - Expose tools as APIs
5. **Streaming** - SSE and WebSocket support
6. **Background tasks** - Async execution
7. **Error handling** - Robust error management

Build APIs with [Gantz](https://gantz.run), power them with FastAPI.

Fast and powerful.

## Related reading

- [MCP Streaming Patterns](/post/mcp-streaming-patterns/) - Stream responses
- [MCP Concurrency](/post/mcp-concurrency/) - Parallel execution
- [Agent API Design](/post/agent-api-design/) - API best practices

---

*How do you integrate MCP with FastAPI? Share your patterns.*
