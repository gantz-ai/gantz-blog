+++
title = "Express.js MCP Integration: Node.js AI APIs"
image = "images/express-mcp-integration.webp"
date = 2025-11-19
description = "Integrate MCP tools with Express.js applications. Build AI-powered Node.js APIs with middleware, streaming, and TypeScript patterns."
summary = "Integrate MCP with Express.js for AI-powered Node.js APIs. Build middleware for tool execution, add streaming responses, and use TypeScript patterns."
draft = false
tags = ['mcp', 'express', 'nodejs', 'typescript']
voice = false

[howto]
name = "Integrate MCP with Express.js"
totalTime = 30
[[howto.steps]]
name = "Set up Express project"
text = "Create Express app with TypeScript and MCP."
[[howto.steps]]
name = "Create tool middleware"
text = "Build middleware for tool execution."
[[howto.steps]]
name = "Add API routes"
text = "Create routes for MCP tool endpoints."
[[howto.steps]]
name = "Implement streaming"
text = "Add SSE streaming for LLM responses."
[[howto.steps]]
name = "Handle errors"
text = "Add comprehensive error handling."
+++


Express.js is minimal and flexible. MCP adds AI superpowers.

Together, they build lean, powerful APIs.

## Why Express + MCP

Express provides:
- Minimal footprint
- Middleware architecture
- Large ecosystem
- Full control

MCP provides:
- AI tool execution
- LLM integration
- Agent orchestration

## Step 1: Project setup

Using [Gantz](https://gantz.run):

```yaml
# gantz.yaml
name: express-mcp-api

tools:
  - name: chat_completion
    description: Generate chat response
    parameters:
      - name: messages
        type: array
        required: true
      - name: max_tokens
        type: integer
        default: 500
    script:
      command: npx
      args: ["ts-node", "tools/chat.ts"]

  - name: text_analysis
    description: Analyze text content
    parameters:
      - name: text
        type: string
        required: true
    script:
      command: npx
      args: ["ts-node", "tools/analyze.ts"]
```

Express setup with TypeScript:

```typescript
// src/app.ts
import express, { Express, Request, Response, NextFunction } from 'express';
import cors from 'cors';
import helmet from 'helmet';
import { toolRouter } from './routes/tools';
import { chatRouter } from './routes/chat';
import { errorHandler } from './middleware/errorHandler';

const app: Express = express();

// Middleware
app.use(helmet());
app.use(cors());
app.use(express.json());

// Routes
app.use('/api/tools', toolRouter);
app.use('/api/chat', chatRouter);

// Error handling
app.use(errorHandler);

// Health check
app.get('/health', (req: Request, res: Response) => {
  res.json({ status: 'healthy', timestamp: new Date().toISOString() });
});

export default app;
```

```typescript
// src/index.ts
import app from './app';

const PORT = process.env.PORT || 3000;

app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
```

## Step 2: Tool service

TypeScript service for MCP tools:

```typescript
// src/services/MCPToolService.ts
import Anthropic from '@anthropic-ai/sdk';

interface ToolDefinition {
  name: string;
  description: string;
  handler: (params: Record<string, unknown>) => Promise<unknown>;
}

interface ToolResult {
  success: boolean;
  data?: unknown;
  error?: string;
}

export class MCPToolService {
  private tools: Map<string, ToolDefinition> = new Map();
  private anthropic: Anthropic;

  constructor() {
    this.anthropic = new Anthropic();
    this.registerDefaultTools();
  }

  private registerDefaultTools(): void {
    this.register({
      name: 'chat_completion',
      description: 'Generate chat response',
      handler: this.chatCompletion.bind(this)
    });

    this.register({
      name: 'text_analysis',
      description: 'Analyze text content',
      handler: this.textAnalysis.bind(this)
    });

    this.register({
      name: 'summarize',
      description: 'Summarize text',
      handler: this.summarize.bind(this)
    });
  }

  register(tool: ToolDefinition): void {
    this.tools.set(tool.name, tool);
  }

  async execute(toolName: string, params: Record<string, unknown>): Promise<ToolResult> {
    const tool = this.tools.get(toolName);

    if (!tool) {
      return { success: false, error: `Tool not found: ${toolName}` };
    }

    try {
      const data = await tool.handler(params);
      return { success: true, data };
    } catch (error) {
      const message = error instanceof Error ? error.message : 'Unknown error';
      return { success: false, error: message };
    }
  }

  listTools(): Array<{ name: string; description: string }> {
    return Array.from(this.tools.values()).map(({ name, description }) => ({
      name,
      description
    }));
  }

  private async chatCompletion(params: Record<string, unknown>): Promise<unknown> {
    const messages = params.messages as Array<{ role: string; content: string }>;
    const maxTokens = (params.max_tokens as number) || 500;

    const response = await this.anthropic.messages.create({
      model: 'claude-sonnet-4-20250514',
      max_tokens: maxTokens,
      messages: messages.map(m => ({
        role: m.role as 'user' | 'assistant',
        content: m.content
      }))
    });

    return {
      content: response.content[0].type === 'text' ? response.content[0].text : '',
      model: response.model,
      usage: response.usage
    };
  }

  private async textAnalysis(params: Record<string, unknown>): Promise<unknown> {
    const text = params.text as string;

    const response = await this.anthropic.messages.create({
      model: 'claude-sonnet-4-20250514',
      max_tokens: 1000,
      messages: [{
        role: 'user',
        content: `Analyze this text and provide insights about sentiment, key themes, and summary:\n\n${text}`
      }]
    });

    return {
      analysis: response.content[0].type === 'text' ? response.content[0].text : '',
      text_length: text.length
    };
  }

  private async summarize(params: Record<string, unknown>): Promise<unknown> {
    const text = params.text as string;
    const maxLength = (params.max_length as number) || 200;

    const response = await this.anthropic.messages.create({
      model: 'claude-sonnet-4-20250514',
      max_tokens: maxLength,
      messages: [{
        role: 'user',
        content: `Summarize this text concisely:\n\n${text}`
      }]
    });

    return {
      summary: response.content[0].type === 'text' ? response.content[0].text : '',
      original_length: text.length
    };
  }
}

// Singleton
export const toolService = new MCPToolService();
```

## Step 3: Middleware

Express middleware for tools:

```typescript
// src/middleware/toolMiddleware.ts
import { Request, Response, NextFunction } from 'express';
import { toolService } from '../services/MCPToolService';

export interface ToolRequest extends Request {
  toolService?: typeof toolService;
}

export const attachToolService = (
  req: ToolRequest,
  res: Response,
  next: NextFunction
): void => {
  req.toolService = toolService;
  next();
};

// Rate limiting middleware
interface RateLimitStore {
  [key: string]: { count: number; resetTime: number };
}

const rateLimitStore: RateLimitStore = {};

export const rateLimit = (maxRequests: number, windowMs: number) => {
  return (req: Request, res: Response, next: NextFunction): void => {
    const key = req.ip || 'unknown';
    const now = Date.now();

    if (!rateLimitStore[key] || rateLimitStore[key].resetTime < now) {
      rateLimitStore[key] = { count: 1, resetTime: now + windowMs };
      next();
      return;
    }

    if (rateLimitStore[key].count >= maxRequests) {
      res.status(429).json({
        error: 'Too many requests',
        retryAfter: Math.ceil((rateLimitStore[key].resetTime - now) / 1000)
      });
      return;
    }

    rateLimitStore[key].count++;
    next();
  };
};

// Validation middleware
export const validateToolRequest = (
  req: Request,
  res: Response,
  next: NextFunction
): void => {
  const { tool_name, parameters } = req.body;

  if (!tool_name || typeof tool_name !== 'string') {
    res.status(400).json({ error: 'tool_name is required' });
    return;
  }

  if (parameters && typeof parameters !== 'object') {
    res.status(400).json({ error: 'parameters must be an object' });
    return;
  }

  next();
};

// Logging middleware
export const logToolExecution = (
  req: Request,
  res: Response,
  next: NextFunction
): void => {
  const start = Date.now();

  res.on('finish', () => {
    const duration = Date.now() - start;
    console.log(
      `[${new Date().toISOString()}] ${req.method} ${req.path} - ${res.statusCode} (${duration}ms)`
    );
  });

  next();
};
```

## Step 4: Routes

Express routes for tools:

```typescript
// src/routes/tools.ts
import { Router, Request, Response } from 'express';
import { toolService } from '../services/MCPToolService';
import {
  attachToolService,
  validateToolRequest,
  rateLimit,
  ToolRequest
} from '../middleware/toolMiddleware';

const router = Router();

// Apply middleware
router.use(attachToolService);
router.use(rateLimit(60, 60000)); // 60 requests per minute

// List available tools
router.get('/', (req: Request, res: Response) => {
  const tools = toolService.listTools();
  res.json({ tools });
});

// Execute tool
router.post(
  '/execute',
  validateToolRequest,
  async (req: ToolRequest, res: Response) => {
    const { tool_name, parameters = {} } = req.body;

    try {
      const result = await toolService.execute(tool_name, parameters);

      if (result.success) {
        res.json(result);
      } else {
        res.status(400).json(result);
      }
    } catch (error) {
      res.status(500).json({
        success: false,
        error: error instanceof Error ? error.message : 'Internal error'
      });
    }
  }
);

// Execute specific tool by name
router.post('/:toolName', async (req: Request, res: Response) => {
  const { toolName } = req.params;
  const parameters = req.body;

  try {
    const result = await toolService.execute(toolName, parameters);

    if (result.success) {
      res.json(result);
    } else {
      res.status(400).json(result);
    }
  } catch (error) {
    res.status(500).json({
      success: false,
      error: error instanceof Error ? error.message : 'Internal error'
    });
  }
});

export { router as toolRouter };
```

## Step 5: Streaming routes

SSE streaming for chat:

```typescript
// src/routes/chat.ts
import { Router, Request, Response } from 'express';
import Anthropic from '@anthropic-ai/sdk';

const router = Router();
const anthropic = new Anthropic();

interface ChatMessage {
  role: 'user' | 'assistant';
  content: string;
}

// Regular chat endpoint
router.post('/', async (req: Request, res: Response) => {
  const { messages, max_tokens = 500 } = req.body as {
    messages: ChatMessage[];
    max_tokens?: number;
  };

  try {
    const response = await anthropic.messages.create({
      model: 'claude-sonnet-4-20250514',
      max_tokens,
      messages
    });

    res.json({
      content: response.content[0].type === 'text' ? response.content[0].text : '',
      usage: response.usage
    });
  } catch (error) {
    res.status(500).json({
      error: error instanceof Error ? error.message : 'Chat failed'
    });
  }
});

// Streaming chat endpoint
router.post('/stream', async (req: Request, res: Response) => {
  const { messages, max_tokens = 500 } = req.body as {
    messages: ChatMessage[];
    max_tokens?: number;
  };

  // Set SSE headers
  res.setHeader('Content-Type', 'text/event-stream');
  res.setHeader('Cache-Control', 'no-cache');
  res.setHeader('Connection', 'keep-alive');

  try {
    const stream = anthropic.messages.stream({
      model: 'claude-sonnet-4-20250514',
      max_tokens,
      messages
    });

    stream.on('text', (text) => {
      res.write(`data: ${JSON.stringify({ text })}\n\n`);
    });

    stream.on('message', (message) => {
      res.write(`data: ${JSON.stringify({ done: true, usage: message.usage })}\n\n`);
      res.end();
    });

    stream.on('error', (error) => {
      res.write(`data: ${JSON.stringify({ error: error.message })}\n\n`);
      res.end();
    });

    // Handle client disconnect
    req.on('close', () => {
      stream.abort();
    });

  } catch (error) {
    res.write(`data: ${JSON.stringify({ error: 'Stream failed' })}\n\n`);
    res.end();
  }
});

export { router as chatRouter };
```

## Step 6: Error handling

Comprehensive error handling:

```typescript
// src/middleware/errorHandler.ts
import { Request, Response, NextFunction } from 'express';

interface AppError extends Error {
  statusCode?: number;
  isOperational?: boolean;
}

export class ToolError extends Error {
  statusCode: number;
  isOperational: boolean;

  constructor(message: string, statusCode: number = 500) {
    super(message);
    this.statusCode = statusCode;
    this.isOperational = true;

    Error.captureStackTrace(this, this.constructor);
  }
}

export const errorHandler = (
  err: AppError,
  req: Request,
  res: Response,
  next: NextFunction
): void => {
  const statusCode = err.statusCode || 500;
  const message = err.message || 'Internal Server Error';

  // Log error
  console.error(`[ERROR] ${req.method} ${req.path}:`, {
    message: err.message,
    stack: err.stack,
    statusCode
  });

  // Send response
  res.status(statusCode).json({
    success: false,
    error: message,
    ...(process.env.NODE_ENV === 'development' && { stack: err.stack })
  });
};

// Async wrapper
export const asyncHandler = (
  fn: (req: Request, res: Response, next: NextFunction) => Promise<void>
) => {
  return (req: Request, res: Response, next: NextFunction): void => {
    Promise.resolve(fn(req, res, next)).catch(next);
  };
};

// Not found handler
export const notFoundHandler = (
  req: Request,
  res: Response,
  next: NextFunction
): void => {
  res.status(404).json({
    success: false,
    error: `Route not found: ${req.method} ${req.path}`
  });
};
```

## Step 7: WebSocket support

Add WebSocket for real-time chat:

```typescript
// src/websocket/chatSocket.ts
import { Server as HTTPServer } from 'http';
import { WebSocket, WebSocketServer } from 'ws';
import Anthropic from '@anthropic-ai/sdk';

const anthropic = new Anthropic();

interface ChatMessage {
  type: 'message' | 'stream_start' | 'stream_chunk' | 'stream_end' | 'error';
  content?: string;
  done?: boolean;
}

export const setupWebSocket = (server: HTTPServer): void => {
  const wss = new WebSocketServer({ server, path: '/ws/chat' });

  wss.on('connection', (ws: WebSocket) => {
    console.log('WebSocket client connected');

    ws.on('message', async (data: Buffer) => {
      try {
        const { messages, max_tokens = 500 } = JSON.parse(data.toString());

        // Send stream start
        ws.send(JSON.stringify({ type: 'stream_start' }));

        const stream = anthropic.messages.stream({
          model: 'claude-sonnet-4-20250514',
          max_tokens,
          messages
        });

        stream.on('text', (text) => {
          if (ws.readyState === WebSocket.OPEN) {
            ws.send(JSON.stringify({
              type: 'stream_chunk',
              content: text
            }));
          }
        });

        stream.on('message', () => {
          if (ws.readyState === WebSocket.OPEN) {
            ws.send(JSON.stringify({
              type: 'stream_end',
              done: true
            }));
          }
        });

        stream.on('error', (error) => {
          if (ws.readyState === WebSocket.OPEN) {
            ws.send(JSON.stringify({
              type: 'error',
              content: error.message
            }));
          }
        });

      } catch (error) {
        ws.send(JSON.stringify({
          type: 'error',
          content: error instanceof Error ? error.message : 'Unknown error'
        }));
      }
    });

    ws.on('close', () => {
      console.log('WebSocket client disconnected');
    });
  });
};
```

## Summary

Express + MCP integration:

1. **Project setup** - Express with TypeScript
2. **Tool service** - Async tool execution
3. **Middleware** - Rate limiting, validation
4. **REST routes** - Tool API endpoints
5. **Streaming** - SSE for LLM responses
6. **Error handling** - Comprehensive errors
7. **WebSocket** - Real-time chat

Build APIs with [Gantz](https://gantz.run), power them with Express.

Minimal and powerful.

## Related reading

- [MCP Streaming Patterns](/post/mcp-streaming-patterns/) - Stream responses
- [MCP Concurrency](/post/mcp-concurrency/) - Parallel execution
- [Next.js MCP Integration](/post/nextjs-mcp-integration/) - Full-stack React

---

*How do you integrate MCP with Express? Share your patterns.*
