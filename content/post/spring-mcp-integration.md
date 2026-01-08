+++
title = "Spring Boot MCP Integration: Java AI Applications"
image = "images/spring-mcp-integration.webp"
date = 2025-11-29
description = "Integrate MCP tools with Spring Boot. Build enterprise Java AI applications with dependency injection, WebFlux streaming, and microservices patterns."
summary = "Integrate MCP tools into enterprise Java applications with Spring Boot. Use dependency injection for tool services, WebFlux for reactive streaming responses, @Async for background processing, and microservices patterns for scalable AI deployments."
draft = false
tags = ['mcp', 'spring', 'java', 'enterprise']
voice = false

[howto]
name = "Integrate MCP with Spring Boot"
totalTime = 40
[[howto.steps]]
name = "Set up Spring project"
text = "Create Spring Boot app with dependencies."
[[howto.steps]]
name = "Create tool services"
text = "Build Spring services for MCP tools."
[[howto.steps]]
name = "Add REST controllers"
text = "Create REST endpoints for tools."
[[howto.steps]]
name = "Implement WebFlux streaming"
text = "Add reactive streaming support."
[[howto.steps]]
name = "Configure async execution"
text = "Use @Async for background processing."
+++


Spring Boot powers enterprise Java. MCP adds AI capabilities.

Together, they build robust AI applications.

## Why Spring Boot + MCP

Spring Boot provides:
- Dependency injection
- Production-ready features
- WebFlux reactive
- Enterprise ecosystem

MCP provides:
- AI tool execution
- LLM integration
- Agent orchestration

## Step 1: Project setup

Using [Gantz](https://gantz.run):

```yaml
# gantz.yaml
name: spring-mcp-api

tools:
  - name: generate_text
    description: Generate AI text
    parameters:
      - name: prompt
        type: string
        required: true
    script:
      command: java
      args: ["-jar", "tools/generate.jar"]
```

Maven dependencies:

```xml
<!-- pom.xml -->
<dependencies>
    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-webflux</artifactId>
    </dependency>
    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-validation</artifactId>
    </dependency>
    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-cache</artifactId>
    </dependency>

    <!-- HTTP Client -->
    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-webflux</artifactId>
    </dependency>

    <!-- Lombok -->
    <dependency>
        <groupId>org.projectlombok</groupId>
        <artifactId>lombok</artifactId>
        <optional>true</optional>
    </dependency>
</dependencies>
```

Application configuration:

```yaml
# src/main/resources/application.yml
spring:
  application:
    name: spring-mcp-api

anthropic:
  api-key: ${ANTHROPIC_API_KEY}
  model: claude-sonnet-4-20250514
  default-max-tokens: 500

mcp:
  cache:
    enabled: true
    ttl: 3600
```

## Step 2: Configuration classes

Spring configuration:

```java
// src/main/java/com/example/config/AnthropicConfig.java
package com.example.config;

import lombok.Data;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.context.annotation.Configuration;

@Data
@Configuration
@ConfigurationProperties(prefix = "anthropic")
public class AnthropicConfig {
    private String apiKey;
    private String model = "claude-sonnet-4-20250514";
    private int defaultMaxTokens = 500;
}
```

```java
// src/main/java/com/example/config/WebClientConfig.java
package com.example.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.reactive.function.client.WebClient;

@Configuration
public class WebClientConfig {

    @Bean
    public WebClient anthropicWebClient(AnthropicConfig config) {
        return WebClient.builder()
            .baseUrl("https://api.anthropic.com/v1")
            .defaultHeader("x-api-key", config.getApiKey())
            .defaultHeader("anthropic-version", "2023-06-01")
            .defaultHeader("Content-Type", "application/json")
            .build();
    }
}
```

## Step 3: Domain models

Request and response models:

```java
// src/main/java/com/example/model/ToolRequest.java
package com.example.model;

import jakarta.validation.constraints.NotBlank;
import lombok.Data;
import java.util.Map;

@Data
public class ToolRequest {
    @NotBlank(message = "Tool name is required")
    private String toolName;
    private Map<String, Object> parameters;
}

// src/main/java/com/example/model/ToolResult.java
package com.example.model;

import lombok.Builder;
import lombok.Data;

@Data
@Builder
public class ToolResult<T> {
    private boolean success;
    private T data;
    private String error;

    public static <T> ToolResult<T> success(T data) {
        return ToolResult.<T>builder()
            .success(true)
            .data(data)
            .build();
    }

    public static <T> ToolResult<T> failure(String error) {
        return ToolResult.<T>builder()
            .success(false)
            .error(error)
            .build();
    }
}

// src/main/java/com/example/model/GenerateRequest.java
package com.example.model;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import lombok.Data;

@Data
public class GenerateRequest {
    @NotBlank(message = "Prompt is required")
    private String prompt;

    @Min(1) @Max(4096)
    private int maxTokens = 500;
}

// src/main/java/com/example/model/ChatMessage.java
package com.example.model;

import lombok.Data;
import lombok.AllArgsConstructor;
import lombok.NoArgsConstructor;

@Data
@AllArgsConstructor
@NoArgsConstructor
public class ChatMessage {
    private String role;
    private String content;
}
```

## Step 4: MCP service

Tool execution service:

```java
// src/main/java/com/example/service/MCPToolService.java
package com.example.service;

import com.example.config.AnthropicConfig;
import com.example.model.*;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.cache.annotation.Cacheable;
import org.springframework.stereotype.Service;
import org.springframework.web.reactive.function.client.WebClient;
import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;

import java.util.*;

@Slf4j
@Service
@RequiredArgsConstructor
public class MCPToolService {

    private final WebClient anthropicWebClient;
    private final AnthropicConfig config;

    private static final Map<String, String> TOOL_DESCRIPTIONS = Map.of(
        "generate_text", "Generate AI text content",
        "summarize", "Summarize text",
        "analyze", "Analyze content",
        "classify", "Classify text"
    );

    public List<Map<String, String>> listTools() {
        return TOOL_DESCRIPTIONS.entrySet().stream()
            .map(e -> Map.of("name", e.getKey(), "description", e.getValue()))
            .toList();
    }

    public Mono<ToolResult<Map<String, Object>>> execute(
            String toolName,
            Map<String, Object> params) {

        return switch (toolName) {
            case "generate_text" -> generateText(params);
            case "summarize" -> summarize(params);
            case "analyze" -> analyze(params);
            case "classify" -> classify(params);
            default -> Mono.just(ToolResult.failure("Unknown tool: " + toolName));
        };
    }

    @Cacheable(value = "tool-results", key = "#toolName + '-' + #params.hashCode()")
    public Mono<ToolResult<Map<String, Object>>> executeCached(
            String toolName,
            Map<String, Object> params) {
        return execute(toolName, params);
    }

    private Mono<ToolResult<Map<String, Object>>> generateText(Map<String, Object> params) {
        String prompt = (String) params.get("prompt");
        int maxTokens = params.containsKey("maxTokens")
            ? (int) params.get("maxTokens")
            : config.getDefaultMaxTokens();

        return callClaude(prompt, maxTokens)
            .map(response -> {
                Map<String, Object> data = new HashMap<>();
                data.put("text", response);
                return ToolResult.success(data);
            })
            .onErrorResume(e -> Mono.just(ToolResult.failure(e.getMessage())));
    }

    private Mono<ToolResult<Map<String, Object>>> summarize(Map<String, Object> params) {
        String text = (String) params.get("text");
        int maxLength = params.containsKey("maxLength")
            ? (int) params.get("maxLength")
            : 200;

        String prompt = "Summarize this text concisely:\n\n" + text;

        return callClaude(prompt, maxLength)
            .map(response -> {
                Map<String, Object> data = new HashMap<>();
                data.put("summary", response);
                data.put("originalLength", text.length());
                return ToolResult.success(data);
            })
            .onErrorResume(e -> Mono.just(ToolResult.failure(e.getMessage())));
    }

    private Mono<ToolResult<Map<String, Object>>> analyze(Map<String, Object> params) {
        String content = (String) params.get("content");
        String prompt = "Analyze this content and provide insights:\n\n" + content;

        return callClaude(prompt, 1000)
            .map(response -> {
                Map<String, Object> data = new HashMap<>();
                data.put("analysis", response);
                return ToolResult.success(data);
            })
            .onErrorResume(e -> Mono.just(ToolResult.failure(e.getMessage())));
    }

    private Mono<ToolResult<Map<String, Object>>> classify(Map<String, Object> params) {
        String text = (String) params.get("text");
        @SuppressWarnings("unchecked")
        List<String> categories = (List<String>) params.getOrDefault(
            "categories",
            List.of("positive", "negative", "neutral")
        );

        String prompt = String.format(
            "Classify this text into one of these categories: %s\n\nText: %s\n\nRespond with only the category name.",
            String.join(", ", categories),
            text
        );

        return callClaude(prompt, 50)
            .map(response -> {
                Map<String, Object> data = new HashMap<>();
                data.put("category", response.trim());
                return ToolResult.success(data);
            })
            .onErrorResume(e -> Mono.just(ToolResult.failure(e.getMessage())));
    }

    private Mono<String> callClaude(String prompt, int maxTokens) {
        Map<String, Object> requestBody = Map.of(
            "model", config.getModel(),
            "max_tokens", maxTokens,
            "messages", List.of(Map.of("role", "user", "content", prompt))
        );

        return anthropicWebClient.post()
            .uri("/messages")
            .bodyValue(requestBody)
            .retrieve()
            .bodyToMono(Map.class)
            .map(response -> {
                @SuppressWarnings("unchecked")
                List<Map<String, Object>> content =
                    (List<Map<String, Object>>) response.get("content");
                return (String) content.get(0).get("text");
            });
    }

    public Flux<String> streamText(String prompt, int maxTokens) {
        Map<String, Object> requestBody = Map.of(
            "model", config.getModel(),
            "max_tokens", maxTokens,
            "stream", true,
            "messages", List.of(Map.of("role", "user", "content", prompt))
        );

        return anthropicWebClient.post()
            .uri("/messages")
            .bodyValue(requestBody)
            .retrieve()
            .bodyToFlux(String.class)
            .filter(line -> line.startsWith("data: "))
            .map(line -> line.substring(6))
            .filter(data -> !data.equals("[DONE]"))
            .mapNotNull(this::extractTextFromEvent);
    }

    private String extractTextFromEvent(String json) {
        try {
            if (json.contains("content_block_delta")) {
                int start = json.indexOf("\"text\":\"") + 8;
                int end = json.indexOf("\"", start);
                return json.substring(start, end);
            }
        } catch (Exception e) {
            log.debug("Could not parse event: {}", json);
        }
        return null;
    }
}
```

## Step 5: REST controllers

Spring REST controllers:

```java
// src/main/java/com/example/controller/ToolController.java
package com.example.controller;

import com.example.model.*;
import com.example.service.MCPToolService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import reactor.core.publisher.Mono;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/tools")
@RequiredArgsConstructor
public class ToolController {

    private final MCPToolService toolService;

    @GetMapping
    public List<Map<String, String>> listTools() {
        return toolService.listTools();
    }

    @PostMapping("/execute")
    public Mono<ResponseEntity<ToolResult<Map<String, Object>>>> execute(
            @Valid @RequestBody ToolRequest request) {

        return toolService.execute(request.getToolName(), request.getParameters())
            .map(result -> result.isSuccess()
                ? ResponseEntity.ok(result)
                : ResponseEntity.badRequest().body(result));
    }

    @PostMapping("/{toolName}")
    public Mono<ResponseEntity<ToolResult<Map<String, Object>>>> executeTool(
            @PathVariable String toolName,
            @RequestBody Map<String, Object> parameters) {

        return toolService.execute(toolName, parameters)
            .map(result -> result.isSuccess()
                ? ResponseEntity.ok(result)
                : ResponseEntity.badRequest().body(result));
    }

    @PostMapping("/generate")
    public Mono<ResponseEntity<ToolResult<Map<String, Object>>>> generate(
            @Valid @RequestBody GenerateRequest request) {

        Map<String, Object> params = Map.of(
            "prompt", request.getPrompt(),
            "maxTokens", request.getMaxTokens()
        );

        return toolService.execute("generate_text", params)
            .map(ResponseEntity::ok);
    }
}
```

## Step 6: WebFlux streaming

Reactive streaming:

```java
// src/main/java/com/example/controller/ChatController.java
package com.example.controller;

import com.example.model.ChatMessage;
import com.example.service.MCPToolService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.MediaType;
import org.springframework.http.codec.ServerSentEvent;
import org.springframework.web.bind.annotation.*;
import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/chat")
@RequiredArgsConstructor
public class ChatController {

    private final MCPToolService toolService;

    @PostMapping
    public Mono<Map<String, Object>> chat(@RequestBody Map<String, Object> request) {
        @SuppressWarnings("unchecked")
        List<ChatMessage> messages = (List<ChatMessage>) request.get("messages");
        int maxTokens = (int) request.getOrDefault("maxTokens", 500);

        String lastMessage = messages.get(messages.size() - 1).getContent();

        return toolService.execute("generate_text", Map.of(
            "prompt", lastMessage,
            "maxTokens", maxTokens
        )).map(result -> Map.of(
            "content", result.getData().get("text"),
            "success", result.isSuccess()
        ));
    }

    @PostMapping(value = "/stream", produces = MediaType.TEXT_EVENT_STREAM_VALUE)
    public Flux<ServerSentEvent<String>> streamChat(
            @RequestBody Map<String, Object> request) {

        String prompt = (String) request.get("prompt");
        int maxTokens = (int) request.getOrDefault("maxTokens", 500);

        return toolService.streamText(prompt, maxTokens)
            .map(text -> ServerSentEvent.<String>builder()
                .data(text)
                .build())
            .concatWith(Flux.just(ServerSentEvent.<String>builder()
                .event("done")
                .data("[DONE]")
                .build()));
    }
}
```

## Step 7: Async execution

Background task execution:

```java
// src/main/java/com/example/service/AsyncToolExecutor.java
package com.example.service;

import com.example.model.ToolResult;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;

import java.util.Map;
import java.util.UUID;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.ConcurrentHashMap;

@Slf4j
@Service
@RequiredArgsConstructor
public class AsyncToolExecutor {

    private final MCPToolService toolService;
    private final Map<String, TaskStatus> tasks = new ConcurrentHashMap<>();

    public record TaskStatus(
        String status,
        Map<String, Object> result,
        String error
    ) {}

    public String submitTask(String toolName, Map<String, Object> params) {
        String taskId = UUID.randomUUID().toString();
        tasks.put(taskId, new TaskStatus("pending", null, null));

        executeAsync(taskId, toolName, params);

        return taskId;
    }

    @Async
    public CompletableFuture<Void> executeAsync(
            String taskId,
            String toolName,
            Map<String, Object> params) {

        tasks.put(taskId, new TaskStatus("running", null, null));

        return toolService.execute(toolName, params)
            .map(result -> {
                if (result.isSuccess()) {
                    tasks.put(taskId, new TaskStatus(
                        "completed",
                        result.getData(),
                        null
                    ));
                } else {
                    tasks.put(taskId, new TaskStatus(
                        "failed",
                        null,
                        result.getError()
                    ));
                }
                return result;
            })
            .toFuture()
            .thenApply(r -> null);
    }

    public TaskStatus getTaskStatus(String taskId) {
        return tasks.get(taskId);
    }
}
```

```java
// src/main/java/com/example/controller/AsyncController.java
package com.example.controller;

import com.example.model.ToolRequest;
import com.example.service.AsyncToolExecutor;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api/async")
@RequiredArgsConstructor
public class AsyncController {

    private final AsyncToolExecutor asyncExecutor;

    @PostMapping("/execute")
    public ResponseEntity<Map<String, String>> submitTask(
            @Valid @RequestBody ToolRequest request) {

        String taskId = asyncExecutor.submitTask(
            request.getToolName(),
            request.getParameters()
        );

        return ResponseEntity.status(HttpStatus.ACCEPTED)
            .body(Map.of("taskId", taskId));
    }

    @GetMapping("/status/{taskId}")
    public ResponseEntity<?> getStatus(@PathVariable String taskId) {
        var status = asyncExecutor.getTaskStatus(taskId);

        if (status == null) {
            return ResponseEntity.notFound().build();
        }

        return ResponseEntity.ok(status);
    }
}
```

## Summary

Spring Boot + MCP integration:

1. **Configuration** - Spring properties
2. **Services** - DI-powered tools
3. **REST controllers** - API endpoints
4. **WebFlux** - Reactive streaming
5. **Caching** - Spring Cache
6. **Async** - Background execution

Build apps with [Gantz](https://gantz.run), power them with Spring.

Enterprise Java AI.

## Related reading

- [NestJS MCP Integration](/post/nestjs-mcp-integration/) - TypeScript enterprise
- [MCP Concurrency](/post/mcp-concurrency/) - Parallel execution
- [MCP Caching](/post/mcp-caching/) - Cache strategies

---

*How do you build AI apps with Spring? Share your approach.*
