+++
title = "Cloudflare Workers MCP Integration: Global AI Agents at the Edge"
image = "images/cloudflare-workers-mcp.webp"
date = 2025-05-05
description = "Deploy MCP-powered AI agents on Cloudflare Workers. Learn edge computing, Durable Objects, Workers AI, and KV storage integration with Gantz."
summary = "Run AI agents at the edge with sub-50ms latency worldwide. Cloudflare Workers deploy to 300+ locations automatically. Use Durable Objects for conversation state that follows users globally, Workers AI for inference without leaving the network, and KV for fast key-value storage. True edge AI without managing infrastructure."
draft = false
tags = ['cloudflare', 'workers', 'edge', 'mcp', 'serverless', 'gantz']
voice = false

[howto]
name = "How To Build AI Agents with Cloudflare Workers and MCP"
totalTime = 35
[[howto.steps]]
name = "Set up Workers project"
text = "Initialize Cloudflare Workers project with Wrangler"
[[howto.steps]]
name = "Define MCP tools"
text = "Create tool configurations for edge deployment"
[[howto.steps]]
name = "Implement Workers handlers"
text = "Build handlers optimized for V8 isolate runtime"
[[howto.steps]]
name = "Configure Durable Objects"
text = "Set up stateful AI agent sessions"
[[howto.steps]]
name = "Deploy with Gantz"
text = "Deploy globally using Gantz CLI"
+++

Cloudflare Workers run on one of the world's largest edge networks, making them ideal for deploying MCP-powered AI agents with ultra-low latency. This guide covers building globally distributed AI workflows with Workers.

## Why Cloudflare Workers for MCP?

Cloudflare offers exceptional capabilities for AI agents:

- **Global edge network**: 300+ locations worldwide
- **Zero cold starts**: V8 isolates start in milliseconds
- **Durable Objects**: Strongly consistent stateful compute
- **Workers AI**: Run AI models at the edge
- **KV/R2/D1**: Multiple storage options

## Cloudflare Workers MCP Tool Definition

Configure edge-optimized tools in Gantz:

```yaml
# gantz.yaml
name: cloudflare-workers-tools
version: 1.0.0

tools:
  invoke_worker:
    description: "Invoke Cloudflare Worker"
    parameters:
      worker_url:
        type: string
        description: "Worker URL"
        required: true
      path:
        type: string
        description: "Route path"
        default: "/"
      method:
        type: string
        default: "POST"
      data:
        type: object
        description: "Request payload"
    handler: cloudflare.invoke_worker

  list_workers:
    description: "List Workers in account"
    parameters:
      account_id:
        type: string
        required: true
    handler: cloudflare.list_workers

  deploy_worker:
    description: "Deploy Worker script"
    parameters:
      account_id:
        type: string
        required: true
      worker_name:
        type: string
        required: true
      script_path:
        type: string
        required: true
    handler: cloudflare.deploy_worker

  kv_get:
    description: "Get value from Workers KV"
    parameters:
      namespace_id:
        type: string
        required: true
      key:
        type: string
        required: true
    handler: cloudflare.kv_get

  kv_put:
    description: "Store value in Workers KV"
    parameters:
      namespace_id:
        type: string
        required: true
      key:
        type: string
        required: true
      value:
        type: string
        required: true
      ttl:
        type: integer
        description: "Time to live in seconds"
    handler: cloudflare.kv_put

  ai_inference:
    description: "Run Workers AI inference"
    parameters:
      model:
        type: string
        description: "AI model identifier"
        required: true
      input:
        type: object
        required: true
    handler: cloudflare.ai_inference
```

## Handler Implementation

Build handlers for Cloudflare operations:

```typescript
// handlers/cloudflare.ts

const CF_API_URL = 'https://api.cloudflare.com/client/v4';

interface CloudflareResponse<T> {
  success: boolean;
  result: T;
  errors: Array<{ message: string }>;
}

async function cfFetch<T>(
  path: string,
  options: RequestInit = {}
): Promise<T> {
  const response = await fetch(`${CF_API_URL}${path}`, {
    ...options,
    headers: {
      'Authorization': `Bearer ${process.env.CLOUDFLARE_API_TOKEN}`,
      'Content-Type': 'application/json',
      ...options.headers
    }
  });

  const data: CloudflareResponse<T> = await response.json();

  if (!data.success) {
    throw new Error(data.errors[0]?.message || 'Cloudflare API error');
  }

  return data.result;
}

export async function invokeWorker(
  workerUrl: string,
  path: string = '/',
  method: string = 'POST',
  data?: object
): Promise<object> {
  const url = `${workerUrl}${path}`;

  try {
    const response = await fetch(url, {
      method,
      headers: {
        'Content-Type': 'application/json'
      },
      body: data ? JSON.stringify(data) : undefined
    });

    const result = await response.json();

    return {
      status: response.status,
      colo: response.headers.get('cf-ray')?.split('-')[1],
      data: result
    };
  } catch (error) {
    return { error: `Worker invocation failed: ${error.message}` };
  }
}

export async function listWorkers(accountId: string): Promise<object> {
  try {
    const workers = await cfFetch<Array<{ id: string; name: string }>>(
      `/accounts/${accountId}/workers/scripts`
    );

    return {
      count: workers.length,
      workers: workers.map(w => ({
        id: w.id,
        name: w.name
      }))
    };
  } catch (error) {
    return { error: `Failed to list workers: ${error.message}` };
  }
}

export async function deployWorker(
  accountId: string,
  workerName: string,
  scriptPath: string
): Promise<object> {
  try {
    const script = await Deno.readTextFile(scriptPath);

    const formData = new FormData();
    formData.append('script', new Blob([script], { type: 'application/javascript' }));

    const result = await cfFetch(
      `/accounts/${accountId}/workers/scripts/${workerName}`,
      {
        method: 'PUT',
        body: formData,
        headers: {} // Let browser set content-type for FormData
      }
    );

    return {
      worker: workerName,
      status: 'deployed',
      result
    };
  } catch (error) {
    return { error: `Deployment failed: ${error.message}` };
  }
}

export async function kvGet(
  namespaceId: string,
  key: string
): Promise<object> {
  try {
    const accountId = process.env.CLOUDFLARE_ACCOUNT_ID;

    const value = await cfFetch<string>(
      `/accounts/${accountId}/storage/kv/namespaces/${namespaceId}/values/${key}`
    );

    return {
      key,
      value,
      found: true
    };
  } catch (error) {
    return { key, found: false, error: error.message };
  }
}

export async function kvPut(
  namespaceId: string,
  key: string,
  value: string,
  ttl?: number
): Promise<object> {
  try {
    const accountId = process.env.CLOUDFLARE_ACCOUNT_ID;
    const params = ttl ? `?expiration_ttl=${ttl}` : '';

    await cfFetch(
      `/accounts/${accountId}/storage/kv/namespaces/${namespaceId}/values/${key}${params}`,
      {
        method: 'PUT',
        body: value,
        headers: {
          'Content-Type': 'text/plain'
        }
      }
    );

    return {
      key,
      stored: true,
      ttl: ttl || 'none'
    };
  } catch (error) {
    return { error: `KV put failed: ${error.message}` };
  }
}

export async function aiInference(
  model: string,
  input: object
): Promise<object> {
  try {
    const accountId = process.env.CLOUDFLARE_ACCOUNT_ID;

    const result = await cfFetch(
      `/accounts/${accountId}/ai/run/${model}`,
      {
        method: 'POST',
        body: JSON.stringify(input)
      }
    );

    return {
      model,
      result
    };
  } catch (error) {
    return { error: `AI inference failed: ${error.message}` };
  }
}
```

## Worker Script Implementation

Create the edge function that handles MCP requests:

```typescript
// src/worker.ts
import { Hono } from 'hono';
import { cors } from 'hono/cors';

type Bindings = {
  MCP_KV: KVNamespace;
  AI: any;
  AGENT_STATE: DurableObjectNamespace;
};

const app = new Hono<{ Bindings: Bindings }>();

app.use('/*', cors());

// MCP tool execution endpoint
app.post('/api/execute', async (c) => {
  const { tool, parameters } = await c.req.json();

  if (!tool) {
    return c.json({ error: 'Tool name required' }, 400);
  }

  try {
    const result = await executeTool(c, tool, parameters);

    return c.json({
      tool,
      result,
      colo: c.req.raw.cf?.colo
    });
  } catch (error) {
    return c.json({ error: error.message }, 500);
  }
});

// AI chat endpoint
app.post('/api/chat', async (c) => {
  const { messages, sessionId } = await c.req.json();

  // Get or create agent session
  const id = c.env.AGENT_STATE.idFromName(sessionId || 'default');
  const stub = c.env.AGENT_STATE.get(id);

  // Forward to Durable Object
  const response = await stub.fetch(c.req.url, {
    method: 'POST',
    headers: c.req.raw.headers,
    body: JSON.stringify({ messages })
  });

  return new Response(response.body, {
    headers: response.headers
  });
});

// Health check
app.get('/health', (c) => {
  return c.json({
    status: 'healthy',
    colo: c.req.raw.cf?.colo,
    timestamp: new Date().toISOString()
  });
});

async function executeTool(
  c: any,
  tool: string,
  parameters: Record<string, unknown>
): Promise<object> {
  switch (tool) {
    case 'analyze':
      return analyzeContent(parameters);

    case 'store':
      await c.env.MCP_KV.put(
        parameters.key as string,
        JSON.stringify(parameters.value),
        { expirationTtl: parameters.ttl as number }
      );
      return { stored: true, key: parameters.key };

    case 'retrieve':
      const value = await c.env.MCP_KV.get(parameters.key as string);
      return { key: parameters.key, value: value ? JSON.parse(value) : null };

    case 'ai_complete':
      const aiResult = await c.env.AI.run('@cf/meta/llama-2-7b-chat-int8', {
        prompt: parameters.prompt as string,
        max_tokens: parameters.maxTokens || 256
      });
      return aiResult;

    default:
      throw new Error(`Unknown tool: ${tool}`);
  }
}

function analyzeContent(params: { content: string }): object {
  const content = params.content || '';
  return {
    length: content.length,
    words: content.split(/\s+/).filter(Boolean).length,
    sentences: content.split(/[.!?]+/).filter(Boolean).length
  };
}

export default app;
```

## Durable Objects for Stateful Agents

Implement stateful AI agent sessions:

```typescript
// src/agent-state.ts
import { DurableObject } from 'cloudflare:workers';

interface Message {
  role: 'user' | 'assistant' | 'tool';
  content: string;
  timestamp: number;
}

interface AgentSession {
  id: string;
  messages: Message[];
  toolCalls: object[];
  createdAt: number;
  lastActive: number;
}

export class AgentStateDO extends DurableObject {
  private session: AgentSession | null = null;

  async fetch(request: Request): Promise<Response> {
    const url = new URL(request.url);

    if (request.method === 'POST') {
      return this.handleChat(request);
    }

    if (request.method === 'GET' && url.pathname === '/state') {
      return this.getState();
    }

    return new Response('Not Found', { status: 404 });
  }

  private async handleChat(request: Request): Promise<Response> {
    const { messages } = await request.json();

    // Initialize or load session
    await this.ensureSession();

    // Add user message
    const userMessage: Message = {
      role: 'user',
      content: messages[messages.length - 1].content,
      timestamp: Date.now()
    };
    this.session!.messages.push(userMessage);

    // Process with AI (example with Workers AI)
    const response = await this.processWithAI(this.session!.messages);

    // Add assistant response
    const assistantMessage: Message = {
      role: 'assistant',
      content: response,
      timestamp: Date.now()
    };
    this.session!.messages.push(assistantMessage);

    // Save state
    await this.saveSession();

    return Response.json({
      message: assistantMessage,
      sessionId: this.session!.id
    });
  }

  private async ensureSession(): Promise<void> {
    if (this.session) return;

    // Try to load from storage
    const stored = await this.ctx.storage.get<AgentSession>('session');

    if (stored) {
      this.session = stored;
    } else {
      this.session = {
        id: crypto.randomUUID(),
        messages: [],
        toolCalls: [],
        createdAt: Date.now(),
        lastActive: Date.now()
      };
    }
  }

  private async saveSession(): Promise<void> {
    if (this.session) {
      this.session.lastActive = Date.now();
      await this.ctx.storage.put('session', this.session);
    }
  }

  private async processWithAI(messages: Message[]): Promise<string> {
    // Implement AI processing logic
    // This would typically call Workers AI or external API
    const prompt = messages.map(m => `${m.role}: ${m.content}`).join('\n');

    // Placeholder response
    return `Processed ${messages.length} messages`;
  }

  private async getState(): Promise<Response> {
    await this.ensureSession();
    return Response.json(this.session);
  }
}
```

## Workers AI Integration

Use AI models at the edge:

```typescript
// src/ai-tools.ts

interface AIBindings {
  AI: any;
}

export async function textGeneration(
  env: AIBindings,
  prompt: string,
  options: {
    model?: string;
    maxTokens?: number;
    temperature?: number;
  } = {}
): Promise<object> {
  const model = options.model || '@cf/meta/llama-2-7b-chat-int8';

  const result = await env.AI.run(model, {
    prompt,
    max_tokens: options.maxTokens || 256,
    temperature: options.temperature || 0.7
  });

  return {
    model,
    response: result.response,
    tokens: result.usage
  };
}

export async function textEmbedding(
  env: AIBindings,
  text: string | string[]
): Promise<object> {
  const input = Array.isArray(text) ? text : [text];

  const result = await env.AI.run('@cf/baai/bge-base-en-v1.5', {
    text: input
  });

  return {
    embeddings: result.data,
    dimensions: result.data[0]?.length || 0
  };
}

export async function imageClassification(
  env: AIBindings,
  imageData: ArrayBuffer
): Promise<object> {
  const result = await env.AI.run('@cf/microsoft/resnet-50', {
    image: [...new Uint8Array(imageData)]
  });

  return {
    classifications: result
  };
}

export async function textToImage(
  env: AIBindings,
  prompt: string,
  options: {
    steps?: number;
    guidance?: number;
  } = {}
): Promise<object> {
  const result = await env.AI.run('@cf/stabilityai/stable-diffusion-xl-base-1.0', {
    prompt,
    num_steps: options.steps || 20,
    guidance: options.guidance || 7.5
  });

  return {
    image: result, // Returns PNG image data
    prompt
  };
}
```

## R2 Storage Integration

Store and retrieve files:

```typescript
// src/r2-tools.ts

interface R2Bindings {
  BUCKET: R2Bucket;
}

export async function uploadFile(
  env: R2Bindings,
  key: string,
  data: ArrayBuffer | string,
  contentType?: string
): Promise<object> {
  const result = await env.BUCKET.put(key, data, {
    httpMetadata: contentType ? { contentType } : undefined
  });

  return {
    key,
    size: result.size,
    etag: result.etag,
    uploaded: new Date().toISOString()
  };
}

export async function downloadFile(
  env: R2Bindings,
  key: string
): Promise<object> {
  const object = await env.BUCKET.get(key);

  if (!object) {
    return { error: `File ${key} not found` };
  }

  return {
    key,
    size: object.size,
    contentType: object.httpMetadata?.contentType,
    data: await object.arrayBuffer()
  };
}

export async function listFiles(
  env: R2Bindings,
  prefix?: string,
  limit: number = 100
): Promise<object> {
  const listed = await env.BUCKET.list({
    prefix,
    limit
  });

  return {
    files: listed.objects.map(obj => ({
      key: obj.key,
      size: obj.size,
      uploaded: obj.uploaded.toISOString()
    })),
    truncated: listed.truncated,
    cursor: listed.cursor
  };
}
```

## Wrangler Configuration

Configure your Worker:

```toml
# wrangler.toml
name = "mcp-agent"
main = "src/worker.ts"
compatibility_date = "2024-01-01"

[vars]
GANTZ_ENABLED = "true"

[[kv_namespaces]]
binding = "MCP_KV"
id = "your-kv-namespace-id"

[[r2_buckets]]
binding = "BUCKET"
bucket_name = "mcp-files"

[[durable_objects.bindings]]
name = "AGENT_STATE"
class_name = "AgentStateDO"

[[migrations]]
tag = "v1"
new_classes = ["AgentStateDO"]

[ai]
binding = "AI"

# Routes
[[routes]]
pattern = "mcp-agent.yourdomain.com/*"
zone_name = "yourdomain.com"
```

## Deploy with Gantz CLI

Deploy your Cloudflare Workers:

```bash
# Install Gantz
npm install -g gantz

# Initialize Cloudflare project
gantz init --template cloudflare-workers

# Login to Cloudflare
wrangler login

# Deploy worker
gantz deploy --platform cloudflare

# Test worker
gantz run invoke_worker \
  --worker-url https://mcp-agent.yourdomain.com \
  --path /api/execute \
  --data '{"tool": "analyze", "parameters": {"content": "test content"}}'
```

Build globally distributed AI agents at [gantz.run](https://gantz.run).

## Related Reading

- [Vercel MCP Integration](/post/vercel-mcp-integration/) - Compare with Vercel Edge
- [AWS Lambda MCP](/post/aws-lambda-mcp/) - Compare with Lambda
- [MCP Connection Pooling](/post/mcp-connection-pooling/) - Optimize edge connections

## Conclusion

Cloudflare Workers provide an exceptional platform for deploying MCP-powered AI agents at the edge. With Durable Objects for state, Workers AI for inference, and global distribution, you can build responsive AI experiences that run close to your users worldwide.

Start deploying edge AI agents with Gantz today.
