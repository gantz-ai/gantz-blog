+++
title = "MCP Streaming Patterns: Real-Time AI Agent Responses"
image = "/images/mcp-streaming-patterns.png"
date = 2025-11-04
description = "Implement streaming patterns for MCP tools. Server-sent events, chunked responses, and real-time updates for responsive AI agent experiences."
draft = false
tags = ['mcp', 'streaming', 'real-time']
voice = false

[howto]
name = "Implement MCP Streaming"
totalTime = 30
[[howto.steps]]
name = "Choose streaming transport"
text = "Select SSE, WebSocket, or chunked transfer."
[[howto.steps]]
name = "Implement stream handlers"
text = "Build handlers for streaming data."
[[howto.steps]]
name = "Handle backpressure"
text = "Manage flow control for slow consumers."
[[howto.steps]]
name = "Add error recovery"
text = "Handle stream interruptions gracefully."
[[howto.steps]]
name = "Optimize for latency"
text = "Minimize time to first byte."
+++


Users hate waiting.

Streaming shows progress. Progress builds trust.

Here's how to stream with MCP.

## Why streaming matters

Without streaming:
```
User: "Analyze this document"
[3 seconds of nothing]
[2 more seconds]
Response appears all at once
```

With streaming:
```
User: "Analyze this document"
"Analyzing structure..."
"Found 5 sections..."
"Key findings: ..."
Response builds progressively
```

## Streaming transports

| Transport | Best For | Latency |
|-----------|----------|---------|
| SSE | Server→Client updates | Low |
| WebSocket | Bidirectional | Very Low |
| Chunked HTTP | Large responses | Medium |
| gRPC Stream | High throughput | Very Low |

## Step 1: SSE streaming

Using [Gantz](https://gantz.run):

```yaml
# gantz.yaml
name: streaming-tools

streaming:
  enabled: true
  transport: sse
  keepalive: 30

tools:
  - name: analyze_document
    description: Analyze document with progress updates
    streaming: true
    parameters:
      - name: document_url
        type: string
        required: true
    script:
      command: python
      args: ["scripts/analyze_stream.py", "{{document_url}}"]
```

SSE server implementation:

```python
from flask import Flask, Response, request
import json
import time
from typing import Generator, Any

app = Flask(__name__)

def stream_response(generator: Generator[str, None, None]) -> Response:
    """Create SSE response from generator."""
    def generate():
        for chunk in generator:
            yield f"data: {json.dumps(chunk)}\n\n"
        yield "data: [DONE]\n\n"

    return Response(
        generate(),
        mimetype='text/event-stream',
        headers={
            'Cache-Control': 'no-cache',
            'Connection': 'keep-alive',
            'X-Accel-Buffering': 'no'
        }
    )

def analyze_document_stream(url: str) -> Generator[dict, None, None]:
    """Stream document analysis progress."""

    # Phase 1: Fetching
    yield {"type": "status", "message": "Fetching document..."}
    document = fetch_document(url)

    # Phase 2: Parsing
    yield {"type": "status", "message": "Parsing content..."}
    sections = parse_document(document)
    yield {"type": "progress", "sections_found": len(sections)}

    # Phase 3: Analysis
    for i, section in enumerate(sections):
        yield {
            "type": "progress",
            "message": f"Analyzing section {i+1}/{len(sections)}..."
        }

        analysis = analyze_section(section)
        yield {
            "type": "partial_result",
            "section": i + 1,
            "analysis": analysis
        }

    # Phase 4: Summary
    yield {"type": "status", "message": "Generating summary..."}
    summary = generate_summary(sections)

    yield {
        "type": "complete",
        "summary": summary,
        "sections_analyzed": len(sections)
    }

@app.route('/tools/analyze_document', methods=['POST'])
def analyze_document_endpoint():
    """Streaming analysis endpoint."""
    data = request.json
    url = data.get('document_url')

    return stream_response(analyze_document_stream(url))

# Client usage
import requests

def consume_stream(url: str, params: dict):
    """Consume SSE stream."""
    response = requests.post(
        url,
        json=params,
        stream=True,
        headers={'Accept': 'text/event-stream'}
    )

    for line in response.iter_lines():
        if line:
            line = line.decode('utf-8')
            if line.startswith('data: '):
                data = line[6:]
                if data != '[DONE]':
                    chunk = json.loads(data)
                    yield chunk

# Usage
for chunk in consume_stream(
    'http://localhost:5000/tools/analyze_document',
    {'document_url': 'https://example.com/doc.pdf'}
):
    if chunk['type'] == 'status':
        print(f"Status: {chunk['message']}")
    elif chunk['type'] == 'progress':
        print(f"Progress: {chunk}")
    elif chunk['type'] == 'complete':
        print(f"Done: {chunk['summary']}")
```

## Step 2: LLM response streaming

Stream AI responses as they generate:

```python
import anthropic
from typing import Generator

class StreamingAgent:
    """Agent with streaming responses."""

    def __init__(self, mcp_url: str, mcp_token: str):
        self.client = anthropic.Anthropic()
        self.mcp_url = mcp_url
        self.mcp_token = mcp_token

    def stream_response(self, task: str) -> Generator[dict, None, None]:
        """Stream agent response."""

        with self.client.messages.stream(
            model="claude-sonnet-4-20250514",
            max_tokens=4096,
            messages=[{"role": "user", "content": task}],
            tools=[{
                "type": "mcp",
                "server_url": self.mcp_url,
                "token": self.mcp_token
            }]
        ) as stream:
            current_text = ""

            for event in stream:
                if event.type == "content_block_start":
                    if hasattr(event.content_block, 'type'):
                        if event.content_block.type == "text":
                            yield {"type": "text_start"}
                        elif event.content_block.type == "tool_use":
                            yield {
                                "type": "tool_start",
                                "tool": event.content_block.name
                            }

                elif event.type == "content_block_delta":
                    if hasattr(event.delta, 'text'):
                        current_text += event.delta.text
                        yield {
                            "type": "text_delta",
                            "text": event.delta.text
                        }

                elif event.type == "content_block_stop":
                    yield {"type": "block_complete"}

                elif event.type == "message_stop":
                    yield {
                        "type": "complete",
                        "full_text": current_text
                    }

    def stream_with_tool_execution(self, task: str) -> Generator[dict, None, None]:
        """Stream with tool execution updates."""

        messages = [{"role": "user", "content": task}]

        while True:
            response_text = ""
            tool_uses = []

            # Stream the response
            with self.client.messages.stream(
                model="claude-sonnet-4-20250514",
                max_tokens=4096,
                messages=messages,
                tools=[{
                    "type": "mcp",
                    "server_url": self.mcp_url,
                    "token": self.mcp_token
                }]
            ) as stream:
                for event in stream:
                    if event.type == "content_block_delta":
                        if hasattr(event.delta, 'text'):
                            response_text += event.delta.text
                            yield {
                                "type": "text",
                                "delta": event.delta.text
                            }

                response = stream.get_final_message()

            # Check for tool use
            if response.stop_reason == "tool_use":
                for content in response.content:
                    if hasattr(content, 'type') and content.type == "tool_use":
                        yield {
                            "type": "tool_executing",
                            "tool": content.name,
                            "input": content.input
                        }

                        # Execute tool (would stream from tool too)
                        result = self._execute_tool(content.name, content.input)

                        yield {
                            "type": "tool_complete",
                            "tool": content.name,
                            "result": result[:200]  # Preview
                        }

                        tool_uses.append({
                            "type": "tool_result",
                            "tool_use_id": content.id,
                            "content": result
                        })

                # Continue conversation
                messages.append({"role": "assistant", "content": response.content})
                messages.append({"role": "user", "content": tool_uses})
            else:
                yield {"type": "complete"}
                break

    def _execute_tool(self, name: str, params: dict) -> str:
        """Execute tool and return result."""
        # Tool execution logic
        pass

# Usage
agent = StreamingAgent(
    mcp_url="https://tools.gantz.run/sse",
    mcp_token="gtz_your_token"
)

for chunk in agent.stream_with_tool_execution("Analyze the sales data"):
    if chunk["type"] == "text":
        print(chunk["delta"], end="", flush=True)
    elif chunk["type"] == "tool_executing":
        print(f"\n[Executing {chunk['tool']}...]")
    elif chunk["type"] == "tool_complete":
        print(f"[Done: {chunk['result'][:50]}...]")
```

## Step 3: Backpressure handling

Manage slow consumers:

```python
import asyncio
from asyncio import Queue
from typing import AsyncGenerator

class BackpressureStream:
    """Stream with backpressure handling."""

    def __init__(self, max_buffer: int = 100):
        self.queue: Queue = Queue(maxsize=max_buffer)
        self.overflow_strategy = "drop_oldest"

    async def produce(self, item: dict):
        """Add item to stream with backpressure."""
        try:
            self.queue.put_nowait(item)
        except asyncio.QueueFull:
            if self.overflow_strategy == "drop_oldest":
                # Remove oldest, add new
                try:
                    self.queue.get_nowait()
                except asyncio.QueueEmpty:
                    pass
                await self.queue.put(item)
            elif self.overflow_strategy == "drop_newest":
                # Just drop the new item
                pass
            elif self.overflow_strategy == "block":
                # Wait for space
                await self.queue.put(item)

    async def consume(self) -> AsyncGenerator[dict, None]:
        """Consume items from stream."""
        while True:
            try:
                item = await asyncio.wait_for(
                    self.queue.get(),
                    timeout=30
                )
                yield item

                if item.get("type") == "complete":
                    break
            except asyncio.TimeoutError:
                yield {"type": "keepalive"}

class AdaptiveStreamer:
    """Adjust streaming rate based on consumer speed."""

    def __init__(self):
        self.consumer_rate = 1.0  # Items per second
        self.last_ack = time.time()

    async def stream_adaptive(
        self,
        generator: AsyncGenerator[dict, None]
    ) -> AsyncGenerator[dict, None]:
        """Stream with adaptive rate limiting."""

        batch = []
        batch_size = 1

        async for item in generator:
            batch.append(item)

            if len(batch) >= batch_size:
                # Send batch
                yield {
                    "type": "batch",
                    "items": batch
                }
                batch = []

                # Adjust batch size based on consumer rate
                elapsed = time.time() - self.last_ack
                if elapsed > 1.0:
                    # Consumer is slow, increase batch size
                    batch_size = min(batch_size * 2, 50)
                elif elapsed < 0.1:
                    # Consumer is fast, decrease batch size
                    batch_size = max(batch_size // 2, 1)

        # Send remaining
        if batch:
            yield {"type": "batch", "items": batch}

    def ack(self):
        """Acknowledge receipt from consumer."""
        self.last_ack = time.time()
```

## Step 4: Error recovery

Handle stream interruptions:

```python
from typing import Generator, Optional
import time

class ResilientStream:
    """Stream with automatic recovery."""

    def __init__(self, max_retries: int = 3):
        self.max_retries = max_retries
        self.last_event_id: Optional[str] = None

    def stream_with_recovery(
        self,
        stream_func,
        *args,
        **kwargs
    ) -> Generator[dict, None, None]:
        """Stream with automatic reconnection."""

        retries = 0

        while retries <= self.max_retries:
            try:
                # Resume from last event if reconnecting
                if self.last_event_id:
                    kwargs['resume_from'] = self.last_event_id

                for event in stream_func(*args, **kwargs):
                    # Track event ID for recovery
                    if 'id' in event:
                        self.last_event_id = event['id']

                    yield event

                    # Reset retries on successful event
                    retries = 0

                # Stream completed successfully
                break

            except ConnectionError as e:
                retries += 1
                if retries <= self.max_retries:
                    yield {
                        "type": "reconnecting",
                        "attempt": retries,
                        "error": str(e)
                    }
                    time.sleep(2 ** retries)  # Exponential backoff
                else:
                    yield {
                        "type": "error",
                        "message": "Max retries exceeded",
                        "error": str(e)
                    }
                    raise

class CheckpointedStream:
    """Stream with checkpointing for long operations."""

    def __init__(self, checkpoint_interval: int = 10):
        self.checkpoint_interval = checkpoint_interval
        self.checkpoints = {}

    def stream_with_checkpoints(
        self,
        operation_id: str,
        items: list
    ) -> Generator[dict, None, None]:
        """Stream with periodic checkpoints."""

        # Check for existing checkpoint
        start_index = self.checkpoints.get(operation_id, 0)

        if start_index > 0:
            yield {
                "type": "resuming",
                "from_index": start_index
            }

        for i, item in enumerate(items[start_index:], start=start_index):
            # Process item
            result = self._process_item(item)

            yield {
                "type": "item",
                "index": i,
                "result": result
            }

            # Checkpoint periodically
            if (i + 1) % self.checkpoint_interval == 0:
                self.checkpoints[operation_id] = i + 1
                yield {
                    "type": "checkpoint",
                    "index": i + 1
                }

        # Clear checkpoint on completion
        if operation_id in self.checkpoints:
            del self.checkpoints[operation_id]

        yield {"type": "complete"}

    def _process_item(self, item) -> dict:
        """Process single item."""
        pass
```

## Step 5: Client-side streaming

Handle streams in the client:

```python
import aiohttp
import asyncio
from typing import AsyncGenerator, Callable

class StreamingClient:
    """Client for consuming MCP streams."""

    def __init__(self, base_url: str):
        self.base_url = base_url

    async def stream_tool(
        self,
        tool_name: str,
        params: dict,
        on_chunk: Callable[[dict], None] = None
    ) -> AsyncGenerator[dict, None]:
        """Stream tool execution."""

        async with aiohttp.ClientSession() as session:
            async with session.post(
                f"{self.base_url}/tools/{tool_name}",
                json=params,
                headers={"Accept": "text/event-stream"}
            ) as response:
                async for line in response.content:
                    line = line.decode('utf-8').strip()

                    if line.startswith('data: '):
                        data = line[6:]
                        if data != '[DONE]':
                            chunk = json.loads(data)

                            if on_chunk:
                                on_chunk(chunk)

                            yield chunk

    async def stream_with_ui(
        self,
        tool_name: str,
        params: dict,
        ui_callback: Callable[[str, dict], None]
    ):
        """Stream with UI updates."""

        async for chunk in self.stream_tool(tool_name, params):
            chunk_type = chunk.get("type", "unknown")

            if chunk_type == "status":
                ui_callback("status", chunk)
            elif chunk_type == "progress":
                ui_callback("progress", chunk)
            elif chunk_type == "text":
                ui_callback("text", chunk)
            elif chunk_type == "error":
                ui_callback("error", chunk)
            elif chunk_type == "complete":
                ui_callback("complete", chunk)

# React/JS client example
"""
async function streamTool(toolName, params, onChunk) {
  const response = await fetch(`/tools/${toolName}`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'text/event-stream'
    },
    body: JSON.stringify(params)
  });

  const reader = response.body.getReader();
  const decoder = new TextDecoder();

  while (true) {
    const { done, value } = await reader.read();
    if (done) break;

    const text = decoder.decode(value);
    const lines = text.split('\\n');

    for (const line of lines) {
      if (line.startsWith('data: ')) {
        const data = line.slice(6);
        if (data !== '[DONE]') {
          onChunk(JSON.parse(data));
        }
      }
    }
  }
}

// Usage
streamTool('analyze_document', { url: docUrl }, (chunk) => {
  if (chunk.type === 'text') {
    appendToOutput(chunk.delta);
  } else if (chunk.type === 'progress') {
    updateProgressBar(chunk.percent);
  }
});
"""
```

## Summary

MCP streaming patterns:

1. **SSE transport** - Server-sent events for updates
2. **LLM streaming** - Stream AI responses
3. **Backpressure** - Handle slow consumers
4. **Error recovery** - Resume interrupted streams
5. **Client handling** - Process streams in UI

Build tools with [Gantz](https://gantz.run), stream for responsiveness.

Don't make users wait. Stream progress.

## Related reading

- [MCP Performance](/post/mcp-performance/) - Optimize latency
- [Agent Observability](/post/agent-observability/) - Monitor streams
- [Real-Time Agents](/post/event-driven-agents/) - Event-driven patterns

---

*How do you handle streaming in your agents? Share your patterns.*
