+++
title = "Next.js MCP Integration: Full-Stack AI Apps"
image = "/images/nextjs-mcp-integration.png"
date = 2025-11-21
description = "Integrate MCP tools with Next.js applications. Build AI-powered full-stack apps with API routes, server components, and streaming UI patterns."
draft = false
tags = ['mcp', 'nextjs', 'react', 'typescript']
voice = false

[howto]
name = "Integrate MCP with Next.js"
totalTime = 35
[[howto.steps]]
name = "Set up Next.js project"
text = "Create Next.js app with App Router and MCP."
[[howto.steps]]
name = "Create API routes"
text = "Build API routes for tool execution."
[[howto.steps]]
name = "Add server actions"
text = "Implement server actions for tools."
[[howto.steps]]
name = "Build streaming UI"
text = "Create streaming components for AI responses."
[[howto.steps]]
name = "Handle client state"
text = "Manage AI state with React hooks."
+++


Next.js is the React framework. MCP adds AI intelligence.

Together, they build modern AI applications.

## Why Next.js + MCP

Next.js provides:
- Server components
- API routes
- Streaming support
- Edge runtime

MCP provides:
- AI tool execution
- LLM integration
- Agent capabilities

## Step 1: Project setup

Using [Gantz](https://gantz.run):

```yaml
# gantz.yaml
name: nextjs-mcp-app

tools:
  - name: generate_content
    description: Generate AI content
    parameters:
      - name: prompt
        type: string
        required: true
      - name: type
        type: string
        default: article
    script:
      command: npx
      args: ["ts-node", "tools/generate.ts"]
```

Next.js configuration:

```typescript
// next.config.js
/** @type {import('next').NextConfig} */
const nextConfig = {
  experimental: {
    serverActions: {
      bodySizeLimit: '2mb',
    },
  },
  // Enable streaming
  reactStrictMode: true,
}

module.exports = nextConfig
```

Environment setup:

```typescript
// lib/env.ts
export const env = {
  ANTHROPIC_API_KEY: process.env.ANTHROPIC_API_KEY!,
  NODE_ENV: process.env.NODE_ENV || 'development',
}
```

## Step 2: MCP service

Server-side MCP service:

```typescript
// lib/mcp/service.ts
import Anthropic from '@anthropic-ai/sdk';

const anthropic = new Anthropic();

export interface ToolResult<T = unknown> {
  success: boolean;
  data?: T;
  error?: string;
}

export interface GenerateContentParams {
  prompt: string;
  type?: 'article' | 'summary' | 'code' | 'creative';
  maxTokens?: number;
}

export interface GeneratedContent {
  content: string;
  type: string;
  tokens: {
    input: number;
    output: number;
  };
}

export async function generateContent(
  params: GenerateContentParams
): Promise<ToolResult<GeneratedContent>> {
  const { prompt, type = 'article', maxTokens = 1000 } = params;

  const systemPrompts: Record<string, string> = {
    article: 'You are a professional writer. Write engaging, well-structured content.',
    summary: 'You are a summarization expert. Provide concise, accurate summaries.',
    code: 'You are a coding assistant. Write clean, documented code.',
    creative: 'You are a creative writer. Be imaginative and engaging.',
  };

  try {
    const response = await anthropic.messages.create({
      model: 'claude-sonnet-4-20250514',
      max_tokens: maxTokens,
      system: systemPrompts[type] || systemPrompts.article,
      messages: [{ role: 'user', content: prompt }],
    });

    const content = response.content[0];

    return {
      success: true,
      data: {
        content: content.type === 'text' ? content.text : '',
        type,
        tokens: {
          input: response.usage.input_tokens,
          output: response.usage.output_tokens,
        },
      },
    };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Generation failed',
    };
  }
}

export async function* streamContent(
  params: GenerateContentParams
): AsyncGenerator<string, void, unknown> {
  const { prompt, type = 'article', maxTokens = 1000 } = params;

  const stream = anthropic.messages.stream({
    model: 'claude-sonnet-4-20250514',
    max_tokens: maxTokens,
    messages: [{ role: 'user', content: prompt }],
  });

  for await (const event of stream) {
    if (
      event.type === 'content_block_delta' &&
      event.delta.type === 'text_delta'
    ) {
      yield event.delta.text;
    }
  }
}
```

## Step 3: API routes

Next.js API routes:

```typescript
// app/api/tools/route.ts
import { NextRequest, NextResponse } from 'next/server';
import { generateContent } from '@/lib/mcp/service';

export async function GET() {
  return NextResponse.json({
    tools: [
      { name: 'generate_content', description: 'Generate AI content' },
      { name: 'summarize', description: 'Summarize text' },
      { name: 'analyze', description: 'Analyze content' },
    ],
  });
}

export async function POST(request: NextRequest) {
  const body = await request.json();
  const { tool_name, parameters } = body;

  switch (tool_name) {
    case 'generate_content':
      const result = await generateContent(parameters);
      return NextResponse.json(result);

    default:
      return NextResponse.json(
        { success: false, error: `Unknown tool: ${tool_name}` },
        { status: 400 }
      );
  }
}
```

Streaming API route:

```typescript
// app/api/chat/stream/route.ts
import { NextRequest } from 'next/server';
import Anthropic from '@anthropic-ai/sdk';

const anthropic = new Anthropic();

export async function POST(request: NextRequest) {
  const { messages, maxTokens = 1000 } = await request.json();

  const encoder = new TextEncoder();

  const stream = new ReadableStream({
    async start(controller) {
      try {
        const response = anthropic.messages.stream({
          model: 'claude-sonnet-4-20250514',
          max_tokens: maxTokens,
          messages,
        });

        for await (const event of response) {
          if (
            event.type === 'content_block_delta' &&
            event.delta.type === 'text_delta'
          ) {
            const data = `data: ${JSON.stringify({ text: event.delta.text })}\n\n`;
            controller.enqueue(encoder.encode(data));
          }
        }

        controller.enqueue(encoder.encode('data: [DONE]\n\n'));
        controller.close();
      } catch (error) {
        const errorMessage = error instanceof Error ? error.message : 'Stream error';
        controller.enqueue(
          encoder.encode(`data: ${JSON.stringify({ error: errorMessage })}\n\n`)
        );
        controller.close();
      }
    },
  });

  return new Response(stream, {
    headers: {
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache',
      'Connection': 'keep-alive',
    },
  });
}
```

## Step 4: Server actions

Server actions for tools:

```typescript
// app/actions/tools.ts
'use server';

import { generateContent, GenerateContentParams } from '@/lib/mcp/service';
import { revalidatePath } from 'next/cache';

export async function generateContentAction(params: GenerateContentParams) {
  const result = await generateContent(params);

  if (result.success) {
    revalidatePath('/');
  }

  return result;
}

export async function analyzeTextAction(text: string) {
  const result = await generateContent({
    prompt: `Analyze this text and provide insights:\n\n${text}`,
    type: 'summary',
    maxTokens: 500,
  });

  return result;
}

// Streaming server action using AI SDK
import { createStreamableValue } from 'ai/rsc';
import Anthropic from '@anthropic-ai/sdk';

const anthropic = new Anthropic();

export async function streamGenerateAction(prompt: string) {
  const stream = createStreamableValue('');

  (async () => {
    const response = anthropic.messages.stream({
      model: 'claude-sonnet-4-20250514',
      max_tokens: 1000,
      messages: [{ role: 'user', content: prompt }],
    });

    for await (const event of response) {
      if (
        event.type === 'content_block_delta' &&
        event.delta.type === 'text_delta'
      ) {
        stream.update(event.delta.text);
      }
    }

    stream.done();
  })();

  return { output: stream.value };
}
```

## Step 5: React components

Client components for AI interactions:

```typescript
// components/AIChat.tsx
'use client';

import { useState, useRef, useEffect } from 'react';

interface Message {
  role: 'user' | 'assistant';
  content: string;
}

export function AIChat() {
  const [messages, setMessages] = useState<Message[]>([]);
  const [input, setInput] = useState('');
  const [isStreaming, setIsStreaming] = useState(false);
  const messagesEndRef = useRef<HTMLDivElement>(null);

  const scrollToBottom = () => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  };

  useEffect(() => {
    scrollToBottom();
  }, [messages]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!input.trim() || isStreaming) return;

    const userMessage: Message = { role: 'user', content: input };
    setMessages((prev) => [...prev, userMessage]);
    setInput('');
    setIsStreaming(true);

    // Add empty assistant message for streaming
    setMessages((prev) => [...prev, { role: 'assistant', content: '' }]);

    try {
      const response = await fetch('/api/chat/stream', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          messages: [...messages, userMessage].map((m) => ({
            role: m.role,
            content: m.content,
          })),
        }),
      });

      const reader = response.body?.getReader();
      const decoder = new TextDecoder();

      while (reader) {
        const { done, value } = await reader.read();
        if (done) break;

        const chunk = decoder.decode(value);
        const lines = chunk.split('\n');

        for (const line of lines) {
          if (line.startsWith('data: ')) {
            const data = line.slice(6);
            if (data === '[DONE]') continue;

            try {
              const parsed = JSON.parse(data);
              if (parsed.text) {
                setMessages((prev) => {
                  const newMessages = [...prev];
                  const lastMessage = newMessages[newMessages.length - 1];
                  lastMessage.content += parsed.text;
                  return newMessages;
                });
              }
            } catch {
              // Skip invalid JSON
            }
          }
        }
      }
    } catch (error) {
      console.error('Chat error:', error);
    } finally {
      setIsStreaming(false);
    }
  };

  return (
    <div className="flex flex-col h-[600px] border rounded-lg">
      <div className="flex-1 overflow-y-auto p-4 space-y-4">
        {messages.map((message, index) => (
          <div
            key={index}
            className={`p-3 rounded-lg ${
              message.role === 'user'
                ? 'bg-blue-100 ml-auto max-w-[80%]'
                : 'bg-gray-100 mr-auto max-w-[80%]'
            }`}
          >
            <p className="whitespace-pre-wrap">{message.content}</p>
          </div>
        ))}
        <div ref={messagesEndRef} />
      </div>

      <form onSubmit={handleSubmit} className="p-4 border-t">
        <div className="flex gap-2">
          <input
            type="text"
            value={input}
            onChange={(e) => setInput(e.target.value)}
            placeholder="Type a message..."
            className="flex-1 p-2 border rounded"
            disabled={isStreaming}
          />
          <button
            type="submit"
            disabled={isStreaming}
            className="px-4 py-2 bg-blue-500 text-white rounded disabled:opacity-50"
          >
            {isStreaming ? 'Sending...' : 'Send'}
          </button>
        </div>
      </form>
    </div>
  );
}
```

## Step 6: Server components

Server components with AI:

```typescript
// app/page.tsx
import { Suspense } from 'react';
import { AIChat } from '@/components/AIChat';
import { ContentGenerator } from '@/components/ContentGenerator';

export default function Home() {
  return (
    <main className="container mx-auto p-8">
      <h1 className="text-3xl font-bold mb-8">AI-Powered App</h1>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
        <section>
          <h2 className="text-xl font-semibold mb-4">AI Chat</h2>
          <AIChat />
        </section>

        <section>
          <h2 className="text-xl font-semibold mb-4">Content Generator</h2>
          <Suspense fallback={<div>Loading...</div>}>
            <ContentGenerator />
          </Suspense>
        </section>
      </div>
    </main>
  );
}
```

```typescript
// components/ContentGenerator.tsx
'use client';

import { useState, useTransition } from 'react';
import { generateContentAction } from '@/app/actions/tools';

export function ContentGenerator() {
  const [prompt, setPrompt] = useState('');
  const [content, setContent] = useState('');
  const [isPending, startTransition] = useTransition();

  const handleGenerate = () => {
    startTransition(async () => {
      const result = await generateContentAction({
        prompt,
        type: 'article',
        maxTokens: 1000,
      });

      if (result.success && result.data) {
        setContent(result.data.content);
      }
    });
  };

  return (
    <div className="space-y-4">
      <textarea
        value={prompt}
        onChange={(e) => setPrompt(e.target.value)}
        placeholder="Enter your prompt..."
        className="w-full p-3 border rounded h-32"
      />

      <button
        onClick={handleGenerate}
        disabled={isPending || !prompt}
        className="px-4 py-2 bg-green-500 text-white rounded disabled:opacity-50"
      >
        {isPending ? 'Generating...' : 'Generate Content'}
      </button>

      {content && (
        <div className="p-4 bg-gray-50 rounded border">
          <h3 className="font-semibold mb-2">Generated Content:</h3>
          <p className="whitespace-pre-wrap">{content}</p>
        </div>
      )}
    </div>
  );
}
```

## Step 7: Custom hooks

React hooks for AI state:

```typescript
// hooks/useAI.ts
'use client';

import { useState, useCallback } from 'react';

interface UseAIOptions {
  onError?: (error: Error) => void;
}

export function useAI(options: UseAIOptions = {}) {
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<Error | null>(null);

  const execute = useCallback(
    async <T>(
      toolName: string,
      parameters: Record<string, unknown>
    ): Promise<T | null> => {
      setIsLoading(true);
      setError(null);

      try {
        const response = await fetch('/api/tools', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ tool_name: toolName, parameters }),
        });

        const result = await response.json();

        if (!result.success) {
          throw new Error(result.error);
        }

        return result.data as T;
      } catch (err) {
        const error = err instanceof Error ? err : new Error('Unknown error');
        setError(error);
        options.onError?.(error);
        return null;
      } finally {
        setIsLoading(false);
      }
    },
    [options]
  );

  return { execute, isLoading, error };
}

// Hook for streaming
export function useStreamingAI() {
  const [content, setContent] = useState('');
  const [isStreaming, setIsStreaming] = useState(false);

  const stream = useCallback(async (prompt: string) => {
    setIsStreaming(true);
    setContent('');

    try {
      const response = await fetch('/api/chat/stream', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          messages: [{ role: 'user', content: prompt }],
        }),
      });

      const reader = response.body?.getReader();
      const decoder = new TextDecoder();

      while (reader) {
        const { done, value } = await reader.read();
        if (done) break;

        const chunk = decoder.decode(value);
        const lines = chunk.split('\n');

        for (const line of lines) {
          if (line.startsWith('data: ') && line !== 'data: [DONE]') {
            try {
              const { text } = JSON.parse(line.slice(6));
              if (text) setContent((prev) => prev + text);
            } catch {
              // Skip
            }
          }
        }
      }
    } finally {
      setIsStreaming(false);
    }
  }, []);

  return { content, isStreaming, stream };
}
```

## Summary

Next.js + MCP integration:

1. **Project setup** - App Router with MCP
2. **MCP service** - Server-side tool execution
3. **API routes** - REST and streaming endpoints
4. **Server actions** - Direct tool invocation
5. **React components** - Interactive AI UI
6. **Server components** - SSR with AI
7. **Custom hooks** - Reusable AI state

Build apps with [Gantz](https://gantz.run), power them with Next.js.

Full-stack AI.

## Related reading

- [MCP Streaming Patterns](/post/mcp-streaming-patterns/) - Stream responses
- [React AI Patterns](/post/react-ai-patterns/) - React best practices
- [Express MCP Integration](/post/express-mcp-integration/) - Node.js APIs

---

*How do you build AI apps with Next.js? Share your approach.*
