+++
title = "Laravel MCP Integration: PHP AI Applications"
image = "images/laravel-mcp-integration.webp"
date = 2025-12-01
description = "Integrate MCP tools with Laravel. Build AI-powered PHP applications with queues, broadcasting, and elegant syntax."
summary = "Laravel developers: add AI capabilities to your PHP apps without leaving the framework you know. Wrap MCP tools in service classes, use Laravel queues for async agent processing that won't block requests, and broadcast real-time updates via WebSockets as agents complete work. Includes Eloquent integration patterns and facade examples."
draft = false
tags = ['mcp', 'laravel', 'php', 'web']
voice = false

[howto]
name = "Integrate MCP with Laravel"
totalTime = 30
[[howto.steps]]
name = "Set up Laravel project"
text = "Create Laravel app with MCP package."
[[howto.steps]]
name = "Create tool services"
text = "Build service classes for tools."
[[howto.steps]]
name = "Add API routes"
text = "Create API endpoints for tools."
[[howto.steps]]
name = "Implement queues"
text = "Use Laravel queues for async execution."
[[howto.steps]]
name = "Add broadcasting"
text = "Stream with Laravel Echo."
+++


Laravel is elegant PHP. MCP adds AI intelligence.

Together, they build beautiful AI applications.

## Why Laravel + MCP

Laravel provides:
- Elegant syntax
- Queue system
- Broadcasting
- Blade templates

MCP provides:
- AI tool execution
- LLM integration
- Agent orchestration

## Step 1: Project setup

Using [Gantz](https://gantz.run):

```yaml
# gantz.yaml
name: laravel-mcp-app

tools:
  - name: generate_content
    description: Generate AI content
    parameters:
      - name: prompt
        type: string
        required: true
    script:
      command: php
      args: ["artisan", "mcp:execute", "generate"]
```

Composer dependencies:

```json
{
    "require": {
        "guzzlehttp/guzzle": "^7.0",
        "predis/predis": "^2.0"
    }
}
```

Configuration:

```php
// config/mcp.php
<?php

return [
    'anthropic' => [
        'api_key' => env('ANTHROPIC_API_KEY'),
        'model' => env('ANTHROPIC_MODEL', 'claude-sonnet-4-20250514'),
        'max_tokens' => env('ANTHROPIC_MAX_TOKENS', 500),
    ],

    'cache' => [
        'enabled' => env('MCP_CACHE_ENABLED', true),
        'ttl' => env('MCP_CACHE_TTL', 3600),
    ],

    'queue' => [
        'connection' => env('MCP_QUEUE_CONNECTION', 'redis'),
        'queue' => env('MCP_QUEUE_NAME', 'mcp-tools'),
    ],
];
```

## Step 2: Anthropic client

HTTP client for Anthropic API:

```php
// app/Services/MCP/AnthropicClient.php
<?php

namespace App\Services\MCP;

use Illuminate\Support\Facades\Http;
use Illuminate\Http\Client\Response;
use Generator;

class AnthropicClient
{
    private string $apiKey;
    private string $model;
    private string $baseUrl = 'https://api.anthropic.com/v1';

    public function __construct()
    {
        $this->apiKey = config('mcp.anthropic.api_key');
        $this->model = config('mcp.anthropic.model');
    }

    public function message(string $prompt, int $maxTokens = 500): array
    {
        $response = Http::withHeaders([
            'x-api-key' => $this->apiKey,
            'anthropic-version' => '2023-06-01',
            'Content-Type' => 'application/json',
        ])->post("{$this->baseUrl}/messages", [
            'model' => $this->model,
            'max_tokens' => $maxTokens,
            'messages' => [
                ['role' => 'user', 'content' => $prompt]
            ]
        ]);

        return $response->json();
    }

    public function streamMessage(string $prompt, int $maxTokens = 500): Generator
    {
        $response = Http::withHeaders([
            'x-api-key' => $this->apiKey,
            'anthropic-version' => '2023-06-01',
            'Content-Type' => 'application/json',
        ])->withOptions([
            'stream' => true,
        ])->post("{$this->baseUrl}/messages", [
            'model' => $this->model,
            'max_tokens' => $maxTokens,
            'stream' => true,
            'messages' => [
                ['role' => 'user', 'content' => $prompt]
            ]
        ]);

        $body = $response->getBody();

        while (!$body->eof()) {
            $line = $body->read(1024);

            if (str_starts_with($line, 'data: ')) {
                $data = substr($line, 6);

                if ($data !== '[DONE]') {
                    $event = json_decode($data, true);

                    if (isset($event['delta']['text'])) {
                        yield $event['delta']['text'];
                    }
                }
            }
        }
    }
}
```

## Step 3: Tool service

Service for tool execution:

```php
// app/Services/MCP/ToolService.php
<?php

namespace App\Services\MCP;

use Illuminate\Support\Facades\Cache;
use App\Services\MCP\Tools\ToolInterface;
use App\Services\MCP\Tools\GenerateContent;
use App\Services\MCP\Tools\Summarize;
use App\Services\MCP\Tools\Analyze;

class ToolService
{
    private array $tools = [];
    private AnthropicClient $client;

    public function __construct(AnthropicClient $client)
    {
        $this->client = $client;
        $this->registerDefaultTools();
    }

    private function registerDefaultTools(): void
    {
        $this->register('generate_content', new GenerateContent($this->client));
        $this->register('summarize', new Summarize($this->client));
        $this->register('analyze', new Analyze($this->client));
    }

    public function register(string $name, ToolInterface $tool): void
    {
        $this->tools[$name] = $tool;
    }

    public function execute(string $toolName, array $params = []): ToolResult
    {
        if (!isset($this->tools[$toolName])) {
            return ToolResult::failure("Unknown tool: {$toolName}");
        }

        try {
            $tool = $this->tools[$toolName];
            $data = $tool->execute($params);
            return ToolResult::success($data);
        } catch (\Exception $e) {
            return ToolResult::failure($e->getMessage());
        }
    }

    public function executeCached(string $toolName, array $params = []): ToolResult
    {
        if (!config('mcp.cache.enabled')) {
            return $this->execute($toolName, $params);
        }

        $cacheKey = $this->getCacheKey($toolName, $params);
        $ttl = config('mcp.cache.ttl');

        return Cache::remember($cacheKey, $ttl, function () use ($toolName, $params) {
            return $this->execute($toolName, $params);
        });
    }

    public function listTools(): array
    {
        return collect($this->tools)->map(function ($tool, $name) {
            return [
                'name' => $name,
                'description' => $tool->getDescription(),
            ];
        })->values()->all();
    }

    private function getCacheKey(string $toolName, array $params): string
    {
        $paramHash = md5(json_encode($params));
        return "mcp:tool:{$toolName}:{$paramHash}";
    }
}

// app/Services/MCP/ToolResult.php
<?php

namespace App\Services\MCP;

class ToolResult
{
    public bool $success;
    public ?array $data;
    public ?string $error;

    private function __construct(bool $success, ?array $data, ?string $error)
    {
        $this->success = $success;
        $this->data = $data;
        $this->error = $error;
    }

    public static function success(array $data): self
    {
        return new self(true, $data, null);
    }

    public static function failure(string $error): self
    {
        return new self(false, null, $error);
    }

    public function toArray(): array
    {
        return [
            'success' => $this->success,
            'data' => $this->data,
            'error' => $this->error,
        ];
    }
}
```

Tool implementations:

```php
// app/Services/MCP/Tools/ToolInterface.php
<?php

namespace App\Services\MCP\Tools;

interface ToolInterface
{
    public function execute(array $params): array;
    public function getDescription(): string;
}

// app/Services/MCP/Tools/GenerateContent.php
<?php

namespace App\Services\MCP\Tools;

use App\Services\MCP\AnthropicClient;

class GenerateContent implements ToolInterface
{
    private AnthropicClient $client;

    public function __construct(AnthropicClient $client)
    {
        $this->client = $client;
    }

    public function execute(array $params): array
    {
        $prompt = $params['prompt'] ?? throw new \InvalidArgumentException('Prompt required');
        $maxTokens = $params['max_tokens'] ?? config('mcp.anthropic.max_tokens');

        $response = $this->client->message($prompt, $maxTokens);

        return [
            'content' => $response['content'][0]['text'] ?? '',
            'usage' => $response['usage'] ?? [],
        ];
    }

    public function getDescription(): string
    {
        return 'Generate AI content based on a prompt';
    }
}

// app/Services/MCP/Tools/Summarize.php
<?php

namespace App\Services\MCP\Tools;

use App\Services\MCP\AnthropicClient;

class Summarize implements ToolInterface
{
    private AnthropicClient $client;

    public function __construct(AnthropicClient $client)
    {
        $this->client = $client;
    }

    public function execute(array $params): array
    {
        $text = $params['text'] ?? throw new \InvalidArgumentException('Text required');
        $maxLength = $params['max_length'] ?? 200;

        $prompt = "Summarize this text concisely:\n\n{$text}";
        $response = $this->client->message($prompt, $maxLength);

        return [
            'summary' => $response['content'][0]['text'] ?? '',
            'original_length' => strlen($text),
        ];
    }

    public function getDescription(): string
    {
        return 'Summarize text content';
    }
}
```

## Step 4: API controllers

Laravel controllers:

```php
// app/Http/Controllers/Api/ToolController.php
<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\MCP\ToolService;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;

class ToolController extends Controller
{
    private ToolService $toolService;

    public function __construct(ToolService $toolService)
    {
        $this->toolService = $toolService;
    }

    public function index(): JsonResponse
    {
        return response()->json([
            'tools' => $this->toolService->listTools()
        ]);
    }

    public function execute(Request $request): JsonResponse
    {
        $request->validate([
            'tool_name' => 'required|string',
            'parameters' => 'array',
        ]);

        $result = $this->toolService->execute(
            $request->input('tool_name'),
            $request->input('parameters', [])
        );

        return response()->json(
            $result->toArray(),
            $result->success ? 200 : 400
        );
    }

    public function executeTool(Request $request, string $toolName): JsonResponse
    {
        $result = $this->toolService->execute(
            $toolName,
            $request->all()
        );

        return response()->json(
            $result->toArray(),
            $result->success ? 200 : 400
        );
    }
}
```

Routes:

```php
// routes/api.php
<?php

use App\Http\Controllers\Api\ToolController;
use App\Http\Controllers\Api\ChatController;
use Illuminate\Support\Facades\Route;

Route::middleware('auth:sanctum')->group(function () {
    Route::get('/tools', [ToolController::class, 'index']);
    Route::post('/tools/execute', [ToolController::class, 'execute']);
    Route::post('/tools/{toolName}', [ToolController::class, 'executeTool']);

    Route::post('/chat', [ChatController::class, 'chat']);
    Route::post('/chat/stream', [ChatController::class, 'stream']);
});
```

## Step 5: Queue jobs

Laravel queues for async execution:

```php
// app/Jobs/ExecuteToolJob.php
<?php

namespace App\Jobs;

use App\Models\ToolExecution;
use App\Services\MCP\ToolService;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;

class ExecuteToolJob implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public function __construct(
        private ToolExecution $execution
    ) {
        $this->onQueue(config('mcp.queue.queue'));
    }

    public function handle(ToolService $toolService): void
    {
        $this->execution->update(['status' => 'running']);

        $startTime = microtime(true);

        try {
            $result = $toolService->execute(
                $this->execution->tool_name,
                $this->execution->parameters
            );

            $duration = (int) ((microtime(true) - $startTime) * 1000);

            if ($result->success) {
                $this->execution->update([
                    'status' => 'completed',
                    'result' => $result->data,
                    'duration_ms' => $duration,
                ]);
            } else {
                $this->execution->update([
                    'status' => 'failed',
                    'error' => $result->error,
                    'duration_ms' => $duration,
                ]);
            }
        } catch (\Exception $e) {
            $this->execution->update([
                'status' => 'failed',
                'error' => $e->getMessage(),
            ]);

            throw $e;
        }
    }
}
```

Execution model:

```php
// app/Models/ToolExecution.php
<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Concerns\HasUuids;

class ToolExecution extends Model
{
    use HasUuids;

    protected $fillable = [
        'tool_name',
        'parameters',
        'result',
        'error',
        'status',
        'duration_ms',
    ];

    protected $casts = [
        'parameters' => 'array',
        'result' => 'array',
    ];
}
```

Async controller:

```php
// app/Http/Controllers/Api/AsyncController.php
<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\ToolExecution;
use App\Jobs\ExecuteToolJob;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;

class AsyncController extends Controller
{
    public function submit(Request $request): JsonResponse
    {
        $request->validate([
            'tool_name' => 'required|string',
            'parameters' => 'array',
        ]);

        $execution = ToolExecution::create([
            'tool_name' => $request->input('tool_name'),
            'parameters' => $request->input('parameters', []),
            'status' => 'pending',
        ]);

        ExecuteToolJob::dispatch($execution);

        return response()->json([
            'execution_id' => $execution->id,
            'status' => $execution->status,
        ], 202);
    }

    public function status(string $executionId): JsonResponse
    {
        $execution = ToolExecution::findOrFail($executionId);

        return response()->json([
            'id' => $execution->id,
            'status' => $execution->status,
            'result' => $execution->result,
            'error' => $execution->error,
            'duration_ms' => $execution->duration_ms,
        ]);
    }
}
```

## Step 6: Streaming with broadcasting

Laravel Echo for real-time:

```php
// app/Http/Controllers/Api/ChatController.php
<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\MCP\AnthropicClient;
use App\Services\MCP\ToolService;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\StreamedResponse;

class ChatController extends Controller
{
    public function __construct(
        private ToolService $toolService,
        private AnthropicClient $client
    ) {}

    public function chat(Request $request)
    {
        $request->validate([
            'prompt' => 'required|string',
            'max_tokens' => 'integer|min:1|max:4096',
        ]);

        $result = $this->toolService->execute('generate_content', [
            'prompt' => $request->input('prompt'),
            'max_tokens' => $request->input('max_tokens', 500),
        ]);

        return response()->json($result->toArray());
    }

    public function stream(Request $request): StreamedResponse
    {
        $request->validate([
            'prompt' => 'required|string',
            'max_tokens' => 'integer|min:1|max:4096',
        ]);

        $prompt = $request->input('prompt');
        $maxTokens = $request->input('max_tokens', 500);

        return response()->stream(function () use ($prompt, $maxTokens) {
            foreach ($this->client->streamMessage($prompt, $maxTokens) as $text) {
                echo "data: " . json_encode(['text' => $text]) . "\n\n";
                ob_flush();
                flush();
            }

            echo "data: [DONE]\n\n";
            ob_flush();
            flush();
        }, 200, [
            'Content-Type' => 'text/event-stream',
            'Cache-Control' => 'no-cache',
            'Connection' => 'keep-alive',
        ]);
    }
}
```

Broadcasting event:

```php
// app/Events/ToolExecutionCompleted.php
<?php

namespace App\Events;

use App\Models\ToolExecution;
use Illuminate\Broadcasting\Channel;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Contracts\Broadcasting\ShouldBroadcast;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class ToolExecutionCompleted implements ShouldBroadcast
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public function __construct(
        public ToolExecution $execution
    ) {}

    public function broadcastOn(): Channel
    {
        return new Channel('tool-executions');
    }

    public function broadcastAs(): string
    {
        return 'execution.completed';
    }

    public function broadcastWith(): array
    {
        return [
            'id' => $this->execution->id,
            'status' => $this->execution->status,
            'result' => $this->execution->result,
        ];
    }
}
```

## Summary

Laravel + MCP integration:

1. **Service classes** - Elegant tool execution
2. **API controllers** - RESTful endpoints
3. **Queue jobs** - Async processing
4. **Streaming** - SSE responses
5. **Broadcasting** - Real-time events
6. **Caching** - Performance optimization

Build apps with [Gantz](https://gantz.run), power them with Laravel.

Elegant AI applications.

## Related reading

- [Rails MCP Integration](/post/rails-mcp-integration/) - Ruby framework
- [MCP Caching](/post/mcp-caching/) - Cache strategies
- [Agent Task Queues](/post/agent-task-queues/) - Queue management

---

*How do you build AI apps with Laravel? Share your patterns.*
