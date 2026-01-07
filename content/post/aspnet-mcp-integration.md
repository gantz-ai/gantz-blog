+++
title = "ASP.NET MCP Integration: .NET AI Applications"
image = "images/aspnet-mcp-integration.webp"
date = 2025-12-03
description = "Integrate MCP tools with ASP.NET Core. Build AI-powered .NET applications with dependency injection, SignalR streaming, and background services."
draft = false
tags = ['mcp', 'aspnet', 'dotnet', 'csharp']
voice = false

[howto]
name = "Integrate MCP with ASP.NET"
totalTime = 35
[[howto.steps]]
name = "Set up ASP.NET project"
text = "Create ASP.NET Core app with MCP packages."
[[howto.steps]]
name = "Create tool services"
text = "Build DI services for tools."
[[howto.steps]]
name = "Add API controllers"
text = "Create Web API endpoints."
[[howto.steps]]
name = "Implement SignalR"
text = "Add real-time streaming with SignalR."
[[howto.steps]]
name = "Configure background services"
text = "Use hosted services for async execution."
+++


ASP.NET Core is enterprise .NET. MCP adds AI capabilities.

Together, they build powerful AI applications.

## Why ASP.NET + MCP

ASP.NET Core provides:
- High performance
- Dependency injection
- SignalR real-time
- Cross-platform

MCP provides:
- AI tool execution
- LLM integration
- Agent orchestration

## Step 1: Project setup

Using [Gantz](https://gantz.run):

```yaml
# gantz.yaml
name: aspnet-mcp-api

tools:
  - name: generate_text
    description: Generate AI text
    parameters:
      - name: prompt
        type: string
        required: true
    script:
      command: dotnet
      args: ["run", "--project", "Tools/Generate"]
```

NuGet packages:

```xml
<!-- MCP.Api.csproj -->
<Project Sdk="Microsoft.NET.Sdk.Web">
  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="Microsoft.AspNetCore.SignalR" Version="1.1.0" />
    <PackageReference Include="System.Text.Json" Version="8.0.0" />
  </ItemGroup>
</Project>
```

Configuration:

```csharp
// appsettings.json
{
  "Anthropic": {
    "ApiKey": "",
    "Model": "claude-sonnet-4-20250514",
    "MaxTokens": 500
  },
  "MCP": {
    "CacheEnabled": true,
    "CacheTtlSeconds": 3600
  }
}
```

```csharp
// Program.cs
using MCP.Api.Services;
using MCP.Api.Hubs;

var builder = WebApplication.CreateBuilder(args);

// Add services
builder.Services.Configure<AnthropicSettings>(
    builder.Configuration.GetSection("Anthropic"));
builder.Services.Configure<MCPSettings>(
    builder.Configuration.GetSection("MCP"));

builder.Services.AddHttpClient<IAnthropicClient, AnthropicClient>();
builder.Services.AddSingleton<IToolService, ToolService>();
builder.Services.AddHostedService<ToolExecutionService>();

builder.Services.AddControllers();
builder.Services.AddSignalR();
builder.Services.AddMemoryCache();

var app = builder.Build();

app.UseRouting();
app.MapControllers();
app.MapHub<ChatHub>("/hubs/chat");

app.Run();
```

## Step 2: Configuration and models

Settings and models:

```csharp
// Settings/AnthropicSettings.cs
namespace MCP.Api.Settings;

public class AnthropicSettings
{
    public string ApiKey { get; set; } = string.Empty;
    public string Model { get; set; } = "claude-sonnet-4-20250514";
    public int MaxTokens { get; set; } = 500;
}

public class MCPSettings
{
    public bool CacheEnabled { get; set; } = true;
    public int CacheTtlSeconds { get; set; } = 3600;
}
```

```csharp
// Models/ToolModels.cs
namespace MCP.Api.Models;

public record ToolRequest(string ToolName, Dictionary<string, object>? Parameters);

public record ToolResult<T>(bool Success, T? Data, string? Error)
{
    public static ToolResult<T> SuccessResult(T data) => new(true, data, null);
    public static ToolResult<T> FailureResult(string error) => new(false, default, error);
}

public record ToolDefinition(string Name, string Description);

public record GenerateRequest(string Prompt, int? MaxTokens);

public record ChatMessage(string Role, string Content);

public record ChatRequest(List<ChatMessage> Messages, int? MaxTokens, bool Stream = false);
```

## Step 3: Anthropic client

HTTP client for API:

```csharp
// Services/AnthropicClient.cs
using System.Text.Json;
using Microsoft.Extensions.Options;
using MCP.Api.Settings;

namespace MCP.Api.Services;

public interface IAnthropicClient
{
    Task<string> MessageAsync(string prompt, int maxTokens, CancellationToken ct = default);
    IAsyncEnumerable<string> StreamMessageAsync(string prompt, int maxTokens, CancellationToken ct = default);
}

public class AnthropicClient : IAnthropicClient
{
    private readonly HttpClient _httpClient;
    private readonly AnthropicSettings _settings;

    public AnthropicClient(HttpClient httpClient, IOptions<AnthropicSettings> settings)
    {
        _httpClient = httpClient;
        _settings = settings.Value;

        _httpClient.BaseAddress = new Uri("https://api.anthropic.com/v1/");
        _httpClient.DefaultRequestHeaders.Add("x-api-key", _settings.ApiKey);
        _httpClient.DefaultRequestHeaders.Add("anthropic-version", "2023-06-01");
    }

    public async Task<string> MessageAsync(string prompt, int maxTokens, CancellationToken ct = default)
    {
        var request = new
        {
            model = _settings.Model,
            max_tokens = maxTokens,
            messages = new[] { new { role = "user", content = prompt } }
        };

        var response = await _httpClient.PostAsJsonAsync("messages", request, ct);
        response.EnsureSuccessStatusCode();

        var result = await response.Content.ReadFromJsonAsync<JsonElement>(ct);
        return result.GetProperty("content")[0].GetProperty("text").GetString() ?? "";
    }

    public async IAsyncEnumerable<string> StreamMessageAsync(
        string prompt,
        int maxTokens,
        [System.Runtime.CompilerServices.EnumeratorCancellation] CancellationToken ct = default)
    {
        var request = new
        {
            model = _settings.Model,
            max_tokens = maxTokens,
            stream = true,
            messages = new[] { new { role = "user", content = prompt } }
        };

        var httpRequest = new HttpRequestMessage(HttpMethod.Post, "messages")
        {
            Content = JsonContent.Create(request)
        };

        var response = await _httpClient.SendAsync(
            httpRequest,
            HttpCompletionOption.ResponseHeadersRead,
            ct);

        response.EnsureSuccessStatusCode();

        await using var stream = await response.Content.ReadAsStreamAsync(ct);
        using var reader = new StreamReader(stream);

        while (!reader.EndOfStream && !ct.IsCancellationRequested)
        {
            var line = await reader.ReadLineAsync(ct);

            if (line?.StartsWith("data: ") == true)
            {
                var data = line[6..];

                if (data != "[DONE]")
                {
                    var json = JsonSerializer.Deserialize<JsonElement>(data);

                    if (json.TryGetProperty("delta", out var delta) &&
                        delta.TryGetProperty("text", out var text))
                    {
                        yield return text.GetString() ?? "";
                    }
                }
            }
        }
    }
}
```

## Step 4: Tool service

Service for tool execution:

```csharp
// Services/ToolService.cs
using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.Options;
using MCP.Api.Models;
using MCP.Api.Settings;

namespace MCP.Api.Services;

public interface IToolService
{
    Task<ToolResult<Dictionary<string, object>>> ExecuteAsync(
        string toolName,
        Dictionary<string, object>? parameters,
        CancellationToken ct = default);

    IReadOnlyList<ToolDefinition> ListTools();
}

public class ToolService : IToolService
{
    private readonly IAnthropicClient _client;
    private readonly IMemoryCache _cache;
    private readonly MCPSettings _settings;

    private static readonly Dictionary<string, ToolDefinition> _tools = new()
    {
        ["generate_text"] = new("generate_text", "Generate AI text"),
        ["summarize"] = new("summarize", "Summarize text"),
        ["analyze"] = new("analyze", "Analyze content"),
        ["classify"] = new("classify", "Classify text")
    };

    public ToolService(
        IAnthropicClient client,
        IMemoryCache cache,
        IOptions<MCPSettings> settings)
    {
        _client = client;
        _cache = cache;
        _settings = settings.Value;
    }

    public IReadOnlyList<ToolDefinition> ListTools() => _tools.Values.ToList();

    public async Task<ToolResult<Dictionary<string, object>>> ExecuteAsync(
        string toolName,
        Dictionary<string, object>? parameters,
        CancellationToken ct = default)
    {
        parameters ??= new Dictionary<string, object>();

        if (_settings.CacheEnabled)
        {
            var cacheKey = GetCacheKey(toolName, parameters);

            if (_cache.TryGetValue(cacheKey, out ToolResult<Dictionary<string, object>>? cached))
            {
                return cached!;
            }
        }

        var result = toolName switch
        {
            "generate_text" => await GenerateTextAsync(parameters, ct),
            "summarize" => await SummarizeAsync(parameters, ct),
            "analyze" => await AnalyzeAsync(parameters, ct),
            "classify" => await ClassifyAsync(parameters, ct),
            _ => ToolResult<Dictionary<string, object>>.FailureResult($"Unknown tool: {toolName}")
        };

        if (_settings.CacheEnabled && result.Success)
        {
            var cacheKey = GetCacheKey(toolName, parameters);
            _cache.Set(cacheKey, result, TimeSpan.FromSeconds(_settings.CacheTtlSeconds));
        }

        return result;
    }

    private async Task<ToolResult<Dictionary<string, object>>> GenerateTextAsync(
        Dictionary<string, object> parameters,
        CancellationToken ct)
    {
        if (!parameters.TryGetValue("prompt", out var promptObj))
        {
            return ToolResult<Dictionary<string, object>>.FailureResult("Prompt required");
        }

        var prompt = promptObj.ToString()!;
        var maxTokens = parameters.TryGetValue("maxTokens", out var mt) ? Convert.ToInt32(mt) : 500;

        try
        {
            var text = await _client.MessageAsync(prompt, maxTokens, ct);

            return ToolResult<Dictionary<string, object>>.SuccessResult(new Dictionary<string, object>
            {
                ["text"] = text
            });
        }
        catch (Exception ex)
        {
            return ToolResult<Dictionary<string, object>>.FailureResult(ex.Message);
        }
    }

    private async Task<ToolResult<Dictionary<string, object>>> SummarizeAsync(
        Dictionary<string, object> parameters,
        CancellationToken ct)
    {
        if (!parameters.TryGetValue("text", out var textObj))
        {
            return ToolResult<Dictionary<string, object>>.FailureResult("Text required");
        }

        var text = textObj.ToString()!;
        var maxLength = parameters.TryGetValue("maxLength", out var ml) ? Convert.ToInt32(ml) : 200;

        var prompt = $"Summarize this text concisely:\n\n{text}";
        var summary = await _client.MessageAsync(prompt, maxLength, ct);

        return ToolResult<Dictionary<string, object>>.SuccessResult(new Dictionary<string, object>
        {
            ["summary"] = summary,
            ["originalLength"] = text.Length
        });
    }

    private async Task<ToolResult<Dictionary<string, object>>> AnalyzeAsync(
        Dictionary<string, object> parameters,
        CancellationToken ct)
    {
        if (!parameters.TryGetValue("content", out var contentObj))
        {
            return ToolResult<Dictionary<string, object>>.FailureResult("Content required");
        }

        var content = contentObj.ToString()!;
        var prompt = $"Analyze this content and provide insights:\n\n{content}";
        var analysis = await _client.MessageAsync(prompt, 1000, ct);

        return ToolResult<Dictionary<string, object>>.SuccessResult(new Dictionary<string, object>
        {
            ["analysis"] = analysis
        });
    }

    private async Task<ToolResult<Dictionary<string, object>>> ClassifyAsync(
        Dictionary<string, object> parameters,
        CancellationToken ct)
    {
        if (!parameters.TryGetValue("text", out var textObj))
        {
            return ToolResult<Dictionary<string, object>>.FailureResult("Text required");
        }

        var text = textObj.ToString()!;
        var categories = parameters.TryGetValue("categories", out var cats)
            ? cats.ToString()!
            : "positive, negative, neutral";

        var prompt = $"Classify this text into one of these categories: {categories}\n\nText: {text}\n\nRespond with only the category name.";
        var category = await _client.MessageAsync(prompt, 50, ct);

        return ToolResult<Dictionary<string, object>>.SuccessResult(new Dictionary<string, object>
        {
            ["category"] = category.Trim()
        });
    }

    private static string GetCacheKey(string toolName, Dictionary<string, object> parameters)
    {
        var paramHash = string.Join(",", parameters.OrderBy(p => p.Key).Select(p => $"{p.Key}={p.Value}"));
        return $"mcp:tool:{toolName}:{paramHash.GetHashCode()}";
    }
}
```

## Step 5: API controllers

ASP.NET controllers:

```csharp
// Controllers/ToolsController.cs
using Microsoft.AspNetCore.Mvc;
using MCP.Api.Models;
using MCP.Api.Services;

namespace MCP.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class ToolsController : ControllerBase
{
    private readonly IToolService _toolService;

    public ToolsController(IToolService toolService)
    {
        _toolService = toolService;
    }

    [HttpGet]
    public ActionResult<IEnumerable<ToolDefinition>> List()
    {
        return Ok(new { tools = _toolService.ListTools() });
    }

    [HttpPost("execute")]
    public async Task<ActionResult> Execute(
        [FromBody] ToolRequest request,
        CancellationToken ct)
    {
        var result = await _toolService.ExecuteAsync(
            request.ToolName,
            request.Parameters,
            ct);

        return result.Success ? Ok(result) : BadRequest(result);
    }

    [HttpPost("{toolName}")]
    public async Task<ActionResult> ExecuteTool(
        string toolName,
        [FromBody] Dictionary<string, object>? parameters,
        CancellationToken ct)
    {
        var result = await _toolService.ExecuteAsync(toolName, parameters, ct);
        return result.Success ? Ok(result) : BadRequest(result);
    }
}
```

Chat controller with streaming:

```csharp
// Controllers/ChatController.cs
using Microsoft.AspNetCore.Mvc;
using MCP.Api.Models;
using MCP.Api.Services;

namespace MCP.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class ChatController : ControllerBase
{
    private readonly IAnthropicClient _client;
    private readonly IToolService _toolService;

    public ChatController(IAnthropicClient client, IToolService toolService)
    {
        _client = client;
        _toolService = toolService;
    }

    [HttpPost]
    public async Task<ActionResult> Chat(
        [FromBody] ChatRequest request,
        CancellationToken ct)
    {
        var lastMessage = request.Messages.Last().Content;
        var maxTokens = request.MaxTokens ?? 500;

        var result = await _toolService.ExecuteAsync("generate_text", new Dictionary<string, object>
        {
            ["prompt"] = lastMessage,
            ["maxTokens"] = maxTokens
        }, ct);

        return Ok(result);
    }

    [HttpPost("stream")]
    public async Task Stream([FromBody] ChatRequest request, CancellationToken ct)
    {
        Response.ContentType = "text/event-stream";
        Response.Headers.CacheControl = "no-cache";

        var lastMessage = request.Messages.Last().Content;
        var maxTokens = request.MaxTokens ?? 500;

        await foreach (var text in _client.StreamMessageAsync(lastMessage, maxTokens, ct))
        {
            var data = System.Text.Json.JsonSerializer.Serialize(new { text });
            await Response.WriteAsync($"data: {data}\n\n", ct);
            await Response.Body.FlushAsync(ct);
        }

        await Response.WriteAsync("data: [DONE]\n\n", ct);
    }
}
```

## Step 6: SignalR hub

Real-time streaming:

```csharp
// Hubs/ChatHub.cs
using Microsoft.AspNetCore.SignalR;
using MCP.Api.Services;

namespace MCP.Api.Hubs;

public class ChatHub : Hub
{
    private readonly IAnthropicClient _client;

    public ChatHub(IAnthropicClient client)
    {
        _client = client;
    }

    public async Task SendMessage(string prompt, int maxTokens = 500)
    {
        await Clients.Caller.SendAsync("StreamStart");

        try
        {
            await foreach (var text in _client.StreamMessageAsync(prompt, maxTokens))
            {
                await Clients.Caller.SendAsync("StreamChunk", text);
            }

            await Clients.Caller.SendAsync("StreamEnd");
        }
        catch (Exception ex)
        {
            await Clients.Caller.SendAsync("Error", ex.Message);
        }
    }
}
```

## Step 7: Background service

Hosted service for async execution:

```csharp
// Services/ToolExecutionService.cs
using System.Collections.Concurrent;
using MCP.Api.Models;

namespace MCP.Api.Services;

public record ExecutionTask(
    string Id,
    string ToolName,
    Dictionary<string, object>? Parameters,
    TaskCompletionSource<ToolResult<Dictionary<string, object>>> Completion);

public class ToolExecutionService : BackgroundService
{
    private readonly IServiceProvider _serviceProvider;
    private readonly ConcurrentQueue<ExecutionTask> _queue = new();
    private readonly ConcurrentDictionary<string, ExecutionStatus> _status = new();

    public record ExecutionStatus(
        string Status,
        ToolResult<Dictionary<string, object>>? Result);

    public ToolExecutionService(IServiceProvider serviceProvider)
    {
        _serviceProvider = serviceProvider;
    }

    public string QueueExecution(string toolName, Dictionary<string, object>? parameters)
    {
        var id = Guid.NewGuid().ToString();
        var completion = new TaskCompletionSource<ToolResult<Dictionary<string, object>>>();

        _queue.Enqueue(new ExecutionTask(id, toolName, parameters, completion));
        _status[id] = new ExecutionStatus("pending", null);

        return id;
    }

    public ExecutionStatus? GetStatus(string id) =>
        _status.TryGetValue(id, out var status) ? status : null;

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            if (_queue.TryDequeue(out var task))
            {
                _status[task.Id] = new ExecutionStatus("running", null);

                using var scope = _serviceProvider.CreateScope();
                var toolService = scope.ServiceProvider.GetRequiredService<IToolService>();

                try
                {
                    var result = await toolService.ExecuteAsync(
                        task.ToolName,
                        task.Parameters,
                        stoppingToken);

                    _status[task.Id] = new ExecutionStatus(
                        result.Success ? "completed" : "failed",
                        result);

                    task.Completion.SetResult(result);
                }
                catch (Exception ex)
                {
                    var errorResult = ToolResult<Dictionary<string, object>>
                        .FailureResult(ex.Message);

                    _status[task.Id] = new ExecutionStatus("failed", errorResult);
                    task.Completion.SetResult(errorResult);
                }
            }
            else
            {
                await Task.Delay(100, stoppingToken);
            }
        }
    }
}
```

## Summary

ASP.NET Core + MCP integration:

1. **Configuration** - Strongly typed settings
2. **DI services** - Clean architecture
3. **Controllers** - Web API endpoints
4. **Streaming** - SSE responses
5. **SignalR** - Real-time communication
6. **Background services** - Async execution

Build apps with [Gantz](https://gantz.run), power them with ASP.NET.

Enterprise .NET AI.

## Related reading

- [Spring MCP Integration](/post/spring-mcp-integration/) - Java enterprise
- [MCP Concurrency](/post/mcp-concurrency/) - Parallel execution
- [MCP Caching](/post/mcp-caching/) - Cache strategies

---

*How do you build AI apps with ASP.NET? Share your patterns.*
