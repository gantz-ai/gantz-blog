+++
title = "Vercel MCP Integration: Deploy AI Agents at the Edge"
image = "images/vercel-mcp-integration.webp"
date = 2025-05-04
description = "Build and deploy MCP-powered AI agents on Vercel Edge Functions. Learn serverless deployment, edge computing, and AI SDK integration with Gantz."
draft = false
tags = ['vercel', 'edge-functions', 'serverless', 'mcp', 'nextjs', 'gantz']
voice = false

[howto]
name = "How To Deploy AI Agents on Vercel with MCP"
totalTime = 30
[[howto.steps]]
name = "Set up Vercel project"
text = "Initialize a Vercel project with Edge Function support"
[[howto.steps]]
name = "Create MCP tools"
text = "Define tool configurations for edge deployment"
[[howto.steps]]
name = "Build edge functions"
text = "Implement lightweight handlers optimized for edge runtime"
[[howto.steps]]
name = "Configure AI SDK"
text = "Integrate Vercel AI SDK for streaming responses"
[[howto.steps]]
name = "Deploy with Gantz"
text = "Deploy edge AI agents globally using Gantz CLI"
+++

Vercel provides a powerful platform for deploying MCP-powered AI agents at the edge. With global distribution and minimal latency, you can build responsive AI experiences that scale automatically.

## Why Vercel for MCP?

Vercel offers unique advantages for AI agents:

- **Edge Runtime**: Execute close to users worldwide
- **AI SDK**: First-class streaming and AI support
- **Zero config**: Deploy with git push
- **Next.js integration**: Full-stack AI applications
- **Fast iterations**: Preview deployments for every PR

## Vercel MCP Tool Definition

Configure edge-optimized tools in Gantz:

```yaml
# gantz.yaml
name: vercel-mcp-tools
version: 1.0.0

tools:
  invoke_edge_function:
    description: "Invoke Vercel Edge Function"
    parameters:
      deployment_url:
        type: string
        description: "Vercel deployment URL"
        required: true
      path:
        type: string
        description: "API route path"
        required: true
      data:
        type: object
        description: "Request payload"
        required: true
    handler: vercel.invoke_edge

  list_deployments:
    description: "List Vercel deployments"
    parameters:
      project_id:
        type: string
        description: "Vercel project ID"
        required: true
      limit:
        type: integer
        default: 10
    handler: vercel.list_deployments

  get_deployment_logs:
    description: "Get deployment runtime logs"
    parameters:
      deployment_id:
        type: string
        required: true
    handler: vercel.get_logs

  deploy_project:
    description: "Trigger new deployment"
    parameters:
      project_id:
        type: string
        required: true
      branch:
        type: string
        default: "main"
    handler: vercel.deploy

  ai_completion:
    description: "Get AI completion using Vercel AI SDK"
    parameters:
      prompt:
        type: string
        required: true
      model:
        type: string
        default: "gpt-4"
      stream:
        type: boolean
        default: true
    handler: vercel.ai_completion
```

## Handler Implementation

Build handlers for Vercel operations:

```typescript
// handlers/vercel.ts
import { Vercel } from '@vercel/sdk';

const vercel = new Vercel({
  bearerToken: process.env.VERCEL_TOKEN
});

export async function invokeEdge(
  deploymentUrl: string,
  path: string,
  data: object
): Promise<object> {
  const url = `${deploymentUrl}${path}`;

  try {
    const response = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(data)
    });

    const result = await response.json();

    return {
      status: response.status,
      headers: Object.fromEntries(response.headers.entries()),
      data: result,
      edge_region: response.headers.get('x-vercel-edge-region')
    };
  } catch (error) {
    return { error: `Invocation failed: ${error.message}` };
  }
}

export async function listDeployments(
  projectId: string,
  limit: number = 10
): Promise<object> {
  try {
    const { deployments } = await vercel.deployments.getDeployments({
      projectId,
      limit
    });

    return {
      count: deployments.length,
      deployments: deployments.map(d => ({
        id: d.uid,
        url: d.url,
        state: d.state,
        created: d.created,
        target: d.target,
        meta: d.meta
      }))
    };
  } catch (error) {
    return { error: `Failed to list deployments: ${error.message}` };
  }
}

export async function getLogs(deploymentId: string): Promise<object> {
  try {
    const logs = await vercel.deployments.getDeploymentEvents({
      idOrUrl: deploymentId
    });

    return {
      deployment_id: deploymentId,
      logs: logs.map(log => ({
        timestamp: log.created,
        type: log.type,
        message: log.payload?.text || log.payload
      }))
    };
  } catch (error) {
    return { error: `Failed to get logs: ${error.message}` };
  }
}

export async function deploy(
  projectId: string,
  branch: string = 'main'
): Promise<object> {
  try {
    const deployment = await vercel.deployments.createDeployment({
      name: projectId,
      gitSource: {
        type: 'github',
        ref: branch
      }
    });

    return {
      id: deployment.id,
      url: deployment.url,
      state: deployment.readyState,
      message: 'Deployment triggered'
    };
  } catch (error) {
    return { error: `Deployment failed: ${error.message}` };
  }
}
```

## Edge Function Implementation

Create edge-optimized MCP handlers:

```typescript
// app/api/agent/route.ts (Next.js App Router)
import { NextRequest } from 'next/server';

export const runtime = 'edge';
export const preferredRegion = 'auto';

export async function POST(req: NextRequest) {
  const { tool, parameters } = await req.json();

  if (!tool) {
    return Response.json(
      { error: 'Tool name required' },
      { status: 400 }
    );
  }

  try {
    const result = await executeTool(tool, parameters);

    return Response.json(result, {
      headers: {
        'x-gantz-tool': tool,
        'x-execution-region': req.geo?.region || 'unknown'
      }
    });
  } catch (error) {
    return Response.json(
      { error: error.message },
      { status: 500 }
    );
  }
}

async function executeTool(
  tool: string,
  parameters: Record<string, unknown>
): Promise<object> {
  // Tool execution logic
  const tools: Record<string, Function> = {
    'analyze': analyzeContent,
    'summarize': summarizeText,
    'transform': transformData
  };

  const handler = tools[tool];
  if (!handler) {
    throw new Error(`Unknown tool: ${tool}`);
  }

  return handler(parameters);
}

async function analyzeContent(params: { content: string }) {
  // Lightweight analysis for edge
  return {
    length: params.content.length,
    words: params.content.split(/\s+/).length,
    analyzed_at: new Date().toISOString()
  };
}

async function summarizeText(params: { text: string; maxLength?: number }) {
  // Edge-compatible summarization
  const maxLength = params.maxLength || 100;
  return {
    summary: params.text.slice(0, maxLength) + '...',
    original_length: params.text.length
  };
}

async function transformData(params: { data: object; format: string }) {
  return {
    transformed: params.data,
    format: params.format
  };
}
```

## Vercel AI SDK Integration

Build streaming AI agents:

```typescript
// app/api/chat/route.ts
import { OpenAIStream, StreamingTextResponse } from 'ai';
import OpenAI from 'openai';

export const runtime = 'edge';

const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY
});

export async function POST(req: Request) {
  const { messages, tools } = await req.json();

  // Build tool definitions for function calling
  const toolDefinitions = tools?.map((t: any) => ({
    type: 'function',
    function: {
      name: t.name,
      description: t.description,
      parameters: t.parameters
    }
  }));

  const response = await openai.chat.completions.create({
    model: 'gpt-4-turbo-preview',
    messages,
    tools: toolDefinitions,
    tool_choice: 'auto',
    stream: true
  });

  const stream = OpenAIStream(response, {
    async experimental_onToolCall(toolCallPayload, appendToolCallMessage) {
      // Execute MCP tools
      for (const toolCall of toolCallPayload.tools) {
        const result = await executeMCPTool(
          toolCall.func.name,
          JSON.parse(toolCall.func.arguments)
        );

        appendToolCallMessage({
          tool_call_id: toolCall.id,
          function_name: toolCall.func.name,
          tool_call_result: result
        });
      }
    }
  });

  return new StreamingTextResponse(stream);
}

async function executeMCPTool(
  name: string,
  args: Record<string, unknown>
): Promise<string> {
  // Execute tool and return result
  const response = await fetch(`${process.env.MCP_SERVER_URL}/execute`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ tool: name, parameters: args })
  });

  const result = await response.json();
  return JSON.stringify(result);
}
```

## React Components for AI Chat

Build the frontend:

```tsx
// components/AIChat.tsx
'use client';

import { useChat } from 'ai/react';
import { useState } from 'react';

interface Tool {
  name: string;
  description: string;
  parameters: object;
}

export function AIChat({ tools }: { tools: Tool[] }) {
  const { messages, input, handleInputChange, handleSubmit, isLoading } = useChat({
    api: '/api/chat',
    body: { tools }
  });

  return (
    <div className="chat-container">
      <div className="messages">
        {messages.map((m) => (
          <div key={m.id} className={`message ${m.role}`}>
            <div className="content">{m.content}</div>
            {m.toolInvocations && (
              <div className="tool-calls">
                {m.toolInvocations.map((tool, i) => (
                  <div key={i} className="tool-call">
                    <span className="tool-name">{tool.toolName}</span>
                    <pre>{JSON.stringify(tool.result, null, 2)}</pre>
                  </div>
                ))}
              </div>
            )}
          </div>
        ))}
      </div>

      <form onSubmit={handleSubmit}>
        <input
          value={input}
          onChange={handleInputChange}
          placeholder="Ask something..."
          disabled={isLoading}
        />
        <button type="submit" disabled={isLoading}>
          {isLoading ? 'Thinking...' : 'Send'}
        </button>
      </form>
    </div>
  );
}
```

## Middleware for MCP Authentication

Protect your edge functions:

```typescript
// middleware.ts
import { NextResponse } from 'next/server';
import type { NextRequest } from 'next/server';

export const config = {
  matcher: '/api/:path*'
};

export function middleware(request: NextRequest) {
  // Verify API key
  const apiKey = request.headers.get('x-api-key');

  if (!apiKey || apiKey !== process.env.API_KEY) {
    return NextResponse.json(
      { error: 'Unauthorized' },
      { status: 401 }
    );
  }

  // Add request timing
  const response = NextResponse.next();
  response.headers.set('x-request-start', Date.now().toString());

  return response;
}
```

## Edge Config for Dynamic Tools

Use Edge Config for tool configuration:

```typescript
// lib/tools.ts
import { get } from '@vercel/edge-config';

interface ToolConfig {
  name: string;
  enabled: boolean;
  rateLimit: number;
  parameters: object;
}

export async function getToolConfig(toolName: string): Promise<ToolConfig | null> {
  const tools = await get<Record<string, ToolConfig>>('mcp_tools');
  return tools?.[toolName] || null;
}

export async function isToolEnabled(toolName: string): Promise<boolean> {
  const config = await getToolConfig(toolName);
  return config?.enabled ?? false;
}

// Usage in API route
export async function POST(req: NextRequest) {
  const { tool, parameters } = await req.json();

  // Check if tool is enabled
  const enabled = await isToolEnabled(tool);
  if (!enabled) {
    return Response.json(
      { error: `Tool ${tool} is not enabled` },
      { status: 403 }
    );
  }

  // Execute tool...
}
```

## Vercel KV for State Management

Store AI agent state:

```typescript
// lib/state.ts
import { kv } from '@vercel/kv';

interface AgentState {
  sessionId: string;
  messages: object[];
  toolCalls: object[];
  lastActive: number;
}

export async function getAgentState(sessionId: string): Promise<AgentState | null> {
  return kv.get<AgentState>(`agent:${sessionId}`);
}

export async function updateAgentState(
  sessionId: string,
  update: Partial<AgentState>
): Promise<void> {
  const current = await getAgentState(sessionId) || {
    sessionId,
    messages: [],
    toolCalls: [],
    lastActive: Date.now()
  };

  await kv.set(`agent:${sessionId}`, {
    ...current,
    ...update,
    lastActive: Date.now()
  }, { ex: 3600 }); // Expire after 1 hour
}

export async function addToolCall(
  sessionId: string,
  toolCall: object
): Promise<void> {
  const state = await getAgentState(sessionId);
  if (state) {
    await updateAgentState(sessionId, {
      toolCalls: [...state.toolCalls, toolCall]
    });
  }
}
```

## Deployment Configuration

Configure optimal deployment settings:

```json
// vercel.json
{
  "functions": {
    "app/api/agent/route.ts": {
      "memory": 1024,
      "maxDuration": 30
    },
    "app/api/chat/route.ts": {
      "memory": 1024,
      "maxDuration": 60
    }
  },
  "headers": [
    {
      "source": "/api/(.*)",
      "headers": [
        {
          "key": "Cache-Control",
          "value": "no-store"
        }
      ]
    }
  ],
  "env": {
    "GANTZ_ENABLED": "true"
  }
}
```

## Analytics and Monitoring

Track edge function performance:

```typescript
// lib/analytics.ts
import { Analytics } from '@vercel/analytics/react';

export function trackToolExecution(
  toolName: string,
  duration: number,
  success: boolean
) {
  // Custom event tracking
  if (typeof window !== 'undefined') {
    window.va?.track('tool_execution', {
      tool: toolName,
      duration,
      success,
      region: document.querySelector('meta[name="x-vercel-region"]')?.getAttribute('content')
    });
  }
}

// Server-side logging
export function logToolExecution(
  toolName: string,
  duration: number,
  result: object
) {
  console.log(JSON.stringify({
    event: 'tool_execution',
    tool: toolName,
    duration_ms: duration,
    result_size: JSON.stringify(result).length,
    timestamp: new Date().toISOString()
  }));
}
```

## Deploy with Gantz CLI

Deploy your Vercel MCP tools:

```bash
# Install Gantz
npm install -g gantz

# Initialize Vercel project
gantz init --template vercel-edge

# Deploy to Vercel
gantz deploy --platform vercel

# Test edge function
gantz run invoke_edge_function \
  --deployment-url https://my-app.vercel.app \
  --path /api/agent \
  --data '{"tool": "analyze", "parameters": {"content": "test"}}'
```

Build edge AI agents at [gantz.run](https://gantz.run).

## Related Reading

- [Next.js MCP Integration](/post/nextjs-mcp-integration/) - Full Next.js guide
- [MCP Streaming Patterns](/post/mcp-streaming-patterns/) - Stream AI responses
- [MCP Connection Pooling](/post/mcp-connection-pooling/) - Optimize edge connections

## Conclusion

Vercel provides an excellent platform for deploying MCP-powered AI agents at the edge. With the AI SDK, Edge Config, and KV storage, you can build responsive AI experiences that scale globally with minimal latency.

Start deploying edge AI agents with Gantz today.
