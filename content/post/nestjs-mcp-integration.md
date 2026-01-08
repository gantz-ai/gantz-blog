+++
title = "NestJS MCP Integration: Enterprise AI APIs"
image = "images/nestjs-mcp-integration.webp"
date = 2025-11-25
description = "Integrate MCP tools with NestJS applications. Build enterprise AI APIs with dependency injection, modules, and decorator patterns."
draft = false
tags = ['mcp', 'nestjs', 'typescript', 'enterprise']
voice = false
summary = "Integrate MCP tools into NestJS applications using dependency injection, modules, and TypeScript decorators for enterprise-grade AI APIs. This guide covers creating injectable MCP services, building REST controllers with validation DTOs, implementing SSE and WebSocket streaming for real-time responses, and adding authentication guards with logging interceptors."

[howto]
name = "Integrate MCP with NestJS"
totalTime = 35
[[howto.steps]]
name = "Set up NestJS project"
text = "Create NestJS app with MCP module."
[[howto.steps]]
name = "Create tool module"
text = "Build MCP tools as NestJS module."
[[howto.steps]]
name = "Implement services"
text = "Create injectable tool services."
[[howto.steps]]
name = "Add controllers"
text = "Build REST controllers for tools."
[[howto.steps]]
name = "Configure guards and interceptors"
text = "Add authentication and logging."
+++


NestJS brings structure to Node.js. MCP brings AI power.

Together, they build enterprise-grade AI applications.

## Why NestJS + MCP

NestJS provides:
- Modular architecture
- Dependency injection
- TypeScript first
- Decorators and metadata

MCP provides:
- AI tool execution
- LLM integration
- Agent orchestration

## Step 1: Project setup

Using [Gantz](https://gantz.run):

```yaml
# gantz.yaml
name: nestjs-mcp-api

tools:
  - name: generate_text
    description: Generate AI text
    parameters:
      - name: prompt
        type: string
        required: true
    script:
      command: npx
      args: ["ts-node", "tools/generate.ts"]
```

NestJS module structure:

```typescript
// src/main.ts
import { NestFactory } from '@nestjs/core';
import { ValidationPipe } from '@nestjs/common';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);

  app.useGlobalPipes(new ValidationPipe({
    whitelist: true,
    transform: true,
  }));

  app.enableCors();

  await app.listen(3000);
}
bootstrap();
```

```typescript
// src/app.module.ts
import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { MCPModule } from './mcp/mcp.module';
import { ChatModule } from './chat/chat.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    MCPModule,
    ChatModule,
  ],
})
export class AppModule {}
```

## Step 2: MCP module

Create a dedicated MCP module:

```typescript
// src/mcp/mcp.module.ts
import { Module, Global } from '@nestjs/common';
import { MCPService } from './mcp.service';
import { MCPController } from './mcp.controller';

@Global()
@Module({
  providers: [MCPService],
  controllers: [MCPController],
  exports: [MCPService],
})
export class MCPModule {}
```

```typescript
// src/mcp/mcp.service.ts
import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import Anthropic from '@anthropic-ai/sdk';

export interface ToolDefinition {
  name: string;
  description: string;
}

export interface ToolResult<T = unknown> {
  success: boolean;
  data?: T;
  error?: string;
}

@Injectable()
export class MCPService {
  private readonly logger = new Logger(MCPService.name);
  private readonly anthropic: Anthropic;

  constructor(private configService: ConfigService) {
    this.anthropic = new Anthropic({
      apiKey: this.configService.get('ANTHROPIC_API_KEY'),
    });
  }

  async execute<T = unknown>(
    toolName: string,
    params: Record<string, unknown>,
  ): Promise<ToolResult<T>> {
    this.logger.log(`Executing tool: ${toolName}`);

    try {
      let data: unknown;

      switch (toolName) {
        case 'generate_text':
          data = await this.generateText(params);
          break;
        case 'analyze':
          data = await this.analyze(params);
          break;
        case 'summarize':
          data = await this.summarize(params);
          break;
        default:
          throw new Error(`Unknown tool: ${toolName}`);
      }

      return { success: true, data: data as T };
    } catch (error) {
      this.logger.error(`Tool execution failed: ${error.message}`);
      return {
        success: false,
        error: error instanceof Error ? error.message : 'Unknown error',
      };
    }
  }

  private async generateText(params: Record<string, unknown>) {
    const response = await this.anthropic.messages.create({
      model: 'claude-sonnet-4-20250514',
      max_tokens: (params.maxTokens as number) || 500,
      messages: [{ role: 'user', content: params.prompt as string }],
    });

    return {
      text: response.content[0].type === 'text' ? response.content[0].text : '',
      usage: response.usage,
    };
  }

  private async analyze(params: Record<string, unknown>) {
    const response = await this.anthropic.messages.create({
      model: 'claude-sonnet-4-20250514',
      max_tokens: 1000,
      messages: [{
        role: 'user',
        content: `Analyze this content:\n\n${params.content as string}`,
      }],
    });

    return {
      analysis: response.content[0].type === 'text' ? response.content[0].text : '',
    };
  }

  private async summarize(params: Record<string, unknown>) {
    const response = await this.anthropic.messages.create({
      model: 'claude-sonnet-4-20250514',
      max_tokens: (params.maxLength as number) || 200,
      messages: [{
        role: 'user',
        content: `Summarize:\n\n${params.text as string}`,
      }],
    });

    return {
      summary: response.content[0].type === 'text' ? response.content[0].text : '',
    };
  }

  getTools(): ToolDefinition[] {
    return [
      { name: 'generate_text', description: 'Generate AI text' },
      { name: 'analyze', description: 'Analyze content' },
      { name: 'summarize', description: 'Summarize text' },
    ];
  }

  async *streamText(prompt: string, maxTokens = 500) {
    const stream = this.anthropic.messages.stream({
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
}
```

## Step 3: DTOs and validation

Define DTOs with class-validator:

```typescript
// src/mcp/dto/execute-tool.dto.ts
import { IsString, IsObject, IsOptional, IsInt, Min, Max } from 'class-validator';
import { Type } from 'class-transformer';

export class ExecuteToolDto {
  @IsString()
  toolName: string;

  @IsObject()
  @IsOptional()
  parameters?: Record<string, unknown>;
}

export class GenerateTextDto {
  @IsString()
  prompt: string;

  @IsInt()
  @Min(1)
  @Max(4096)
  @IsOptional()
  @Type(() => Number)
  maxTokens?: number = 500;
}

export class AnalyzeDto {
  @IsString()
  content: string;
}

export class SummarizeDto {
  @IsString()
  text: string;

  @IsInt()
  @Min(50)
  @Max(1000)
  @IsOptional()
  @Type(() => Number)
  maxLength?: number = 200;
}
```

## Step 4: Controllers

REST controllers for tools:

```typescript
// src/mcp/mcp.controller.ts
import {
  Controller,
  Get,
  Post,
  Body,
  Param,
  HttpException,
  HttpStatus,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { MCPService } from './mcp.service';
import { ExecuteToolDto, GenerateTextDto, SummarizeDto } from './dto';
import { AuthGuard } from '../common/guards/auth.guard';
import { LoggingInterceptor } from '../common/interceptors/logging.interceptor';

@Controller('tools')
@UseInterceptors(LoggingInterceptor)
export class MCPController {
  constructor(private readonly mcpService: MCPService) {}

  @Get()
  listTools() {
    return { tools: this.mcpService.getTools() };
  }

  @Post('execute')
  @UseGuards(AuthGuard)
  async execute(@Body() dto: ExecuteToolDto) {
    const result = await this.mcpService.execute(
      dto.toolName,
      dto.parameters || {},
    );

    if (!result.success) {
      throw new HttpException(
        { message: result.error },
        HttpStatus.BAD_REQUEST,
      );
    }

    return result;
  }

  @Post('generate')
  @UseGuards(AuthGuard)
  async generate(@Body() dto: GenerateTextDto) {
    return this.mcpService.execute('generate_text', {
      prompt: dto.prompt,
      maxTokens: dto.maxTokens,
    });
  }

  @Post('summarize')
  @UseGuards(AuthGuard)
  async summarize(@Body() dto: SummarizeDto) {
    return this.mcpService.execute('summarize', {
      text: dto.text,
      maxLength: dto.maxLength,
    });
  }

  @Post(':toolName')
  @UseGuards(AuthGuard)
  async executeTool(
    @Param('toolName') toolName: string,
    @Body() parameters: Record<string, unknown>,
  ) {
    return this.mcpService.execute(toolName, parameters);
  }
}
```

## Step 5: Chat module with streaming

Streaming support:

```typescript
// src/chat/chat.module.ts
import { Module } from '@nestjs/common';
import { ChatController } from './chat.controller';
import { ChatGateway } from './chat.gateway';

@Module({
  controllers: [ChatController],
  providers: [ChatGateway],
})
export class ChatModule {}
```

```typescript
// src/chat/chat.controller.ts
import { Controller, Post, Body, Res, UseGuards } from '@nestjs/common';
import { Response } from 'express';
import { MCPService } from '../mcp/mcp.service';
import { AuthGuard } from '../common/guards/auth.guard';

interface ChatMessage {
  role: 'user' | 'assistant';
  content: string;
}

class ChatDto {
  messages: ChatMessage[];
  maxTokens?: number;
  stream?: boolean;
}

@Controller('chat')
export class ChatController {
  constructor(private readonly mcpService: MCPService) {}

  @Post()
  @UseGuards(AuthGuard)
  async chat(@Body() dto: ChatDto) {
    const result = await this.mcpService.execute('generate_text', {
      prompt: dto.messages[dto.messages.length - 1].content,
      maxTokens: dto.maxTokens || 500,
    });

    return result;
  }

  @Post('stream')
  @UseGuards(AuthGuard)
  async streamChat(@Body() dto: ChatDto, @Res() res: Response) {
    res.setHeader('Content-Type', 'text/event-stream');
    res.setHeader('Cache-Control', 'no-cache');
    res.setHeader('Connection', 'keep-alive');

    const prompt = dto.messages[dto.messages.length - 1].content;

    try {
      for await (const text of this.mcpService.streamText(
        prompt,
        dto.maxTokens,
      )) {
        res.write(`data: ${JSON.stringify({ text })}\n\n`);
      }
      res.write('data: [DONE]\n\n');
    } catch (error) {
      res.write(`data: ${JSON.stringify({ error: error.message })}\n\n`);
    }

    res.end();
  }
}
```

WebSocket gateway:

```typescript
// src/chat/chat.gateway.ts
import {
  WebSocketGateway,
  SubscribeMessage,
  MessageBody,
  ConnectedSocket,
  OnGatewayConnection,
  OnGatewayDisconnect,
} from '@nestjs/websockets';
import { Socket } from 'socket.io';
import { MCPService } from '../mcp/mcp.service';
import { Logger } from '@nestjs/common';

@WebSocketGateway({ cors: true })
export class ChatGateway implements OnGatewayConnection, OnGatewayDisconnect {
  private readonly logger = new Logger(ChatGateway.name);

  constructor(private readonly mcpService: MCPService) {}

  handleConnection(client: Socket) {
    this.logger.log(`Client connected: ${client.id}`);
  }

  handleDisconnect(client: Socket) {
    this.logger.log(`Client disconnected: ${client.id}`);
  }

  @SubscribeMessage('chat')
  async handleChat(
    @MessageBody() data: { prompt: string; maxTokens?: number },
    @ConnectedSocket() client: Socket,
  ) {
    try {
      client.emit('stream_start');

      for await (const text of this.mcpService.streamText(
        data.prompt,
        data.maxTokens,
      )) {
        client.emit('stream_chunk', { text });
      }

      client.emit('stream_end');
    } catch (error) {
      client.emit('error', { message: error.message });
    }
  }
}
```

## Step 6: Guards and interceptors

Authentication guard:

```typescript
// src/common/guards/auth.guard.ts
import {
  Injectable,
  CanActivate,
  ExecutionContext,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

@Injectable()
export class AuthGuard implements CanActivate {
  constructor(private configService: ConfigService) {}

  canActivate(context: ExecutionContext): boolean {
    const request = context.switchToHttp().getRequest();
    const apiKey = request.headers['x-api-key'];

    if (!apiKey) {
      throw new UnauthorizedException('API key required');
    }

    const validKeys = this.configService.get<string>('API_KEYS')?.split(',') || [];

    if (!validKeys.includes(apiKey)) {
      throw new UnauthorizedException('Invalid API key');
    }

    return true;
  }
}
```

Logging interceptor:

```typescript
// src/common/interceptors/logging.interceptor.ts
import {
  Injectable,
  NestInterceptor,
  ExecutionContext,
  CallHandler,
  Logger,
} from '@nestjs/common';
import { Observable } from 'rxjs';
import { tap } from 'rxjs/operators';

@Injectable()
export class LoggingInterceptor implements NestInterceptor {
  private readonly logger = new Logger(LoggingInterceptor.name);

  intercept(context: ExecutionContext, next: CallHandler): Observable<unknown> {
    const request = context.switchToHttp().getRequest();
    const { method, url } = request;
    const start = Date.now();

    return next.handle().pipe(
      tap(() => {
        const duration = Date.now() - start;
        this.logger.log(`${method} ${url} - ${duration}ms`);
      }),
    );
  }
}
```

Rate limiting:

```typescript
// src/common/guards/throttle.guard.ts
import { ThrottlerGuard, ThrottlerModule } from '@nestjs/throttler';
import { Injectable } from '@nestjs/common';

// In app.module.ts
ThrottlerModule.forRoot([{
  ttl: 60000,
  limit: 60,
}]);

@Injectable()
export class CustomThrottleGuard extends ThrottlerGuard {
  protected async getTracker(req: Record<string, unknown>): Promise<string> {
    return req.ip as string;
  }
}
```

## Step 7: Testing

Unit and e2e tests:

```typescript
// src/mcp/mcp.service.spec.ts
import { Test, TestingModule } from '@nestjs/testing';
import { ConfigService } from '@nestjs/config';
import { MCPService } from './mcp.service';

describe('MCPService', () => {
  let service: MCPService;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        MCPService,
        {
          provide: ConfigService,
          useValue: {
            get: jest.fn().mockReturnValue('test-api-key'),
          },
        },
      ],
    }).compile();

    service = module.get<MCPService>(MCPService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  it('should list tools', () => {
    const tools = service.getTools();
    expect(tools).toBeInstanceOf(Array);
    expect(tools.length).toBeGreaterThan(0);
  });

  it('should return error for unknown tool', async () => {
    const result = await service.execute('unknown_tool', {});
    expect(result.success).toBe(false);
    expect(result.error).toContain('Unknown tool');
  });
});
```

## Summary

NestJS + MCP integration:

1. **Module structure** - Organized MCP module
2. **Injectable services** - DI-powered tools
3. **DTOs** - Validated requests
4. **Controllers** - REST endpoints
5. **Streaming** - SSE and WebSocket
6. **Guards** - Authentication
7. **Interceptors** - Logging and metrics

Build APIs with [Gantz](https://gantz.run), power them with NestJS.

Enterprise-ready AI.

## Related reading

- [Express MCP Integration](/post/express-mcp-integration/) - Minimal Node.js
- [MCP Concurrency](/post/mcp-concurrency/) - Parallel execution
- [MCP Testing](/post/mcp-testing/) - Test strategies

---

*How do you structure AI APIs with NestJS? Share your patterns.*
