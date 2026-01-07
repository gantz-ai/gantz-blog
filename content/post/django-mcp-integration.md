+++
title = "Django MCP Integration: AI Tools in Web Apps"
image = "images/django-mcp-integration.webp"
date = 2025-11-17
description = "Integrate MCP tools with Django applications. Build AI-powered web apps with Celery task queues, Django REST framework, and async views."
draft = false
tags = ['mcp', 'django', 'python', 'web']
voice = false

[howto]
name = "Integrate MCP with Django"
totalTime = 35
[[howto.steps]]
name = "Set up Django project"
text = "Create Django app with MCP configuration."
[[howto.steps]]
name = "Create tool models"
text = "Define models for tool execution tracking."
[[howto.steps]]
name = "Build API views"
text = "Create DRF views for tool endpoints."
[[howto.steps]]
name = "Add Celery tasks"
text = "Implement async tool execution with Celery."
[[howto.steps]]
name = "Configure caching"
text = "Cache tool results with Django cache."
+++


Django is batteries-included. MCP adds AI power.

Together, they build production-ready AI applications.

## Why Django + MCP

Django provides:
- ORM for data management
- Admin interface
- Authentication system
- Mature ecosystem

MCP provides:
- AI agent capabilities
- Tool orchestration
- LLM integration

## Step 1: Project setup

Using [Gantz](https://gantz.run):

```yaml
# gantz.yaml
name: django-mcp-app

tools:
  - name: summarize_content
    description: Summarize web content
    parameters:
      - name: url
        type: string
        required: true
    script:
      command: python
      args: ["manage.py", "run_tool", "summarize"]

  - name: generate_report
    description: Generate AI report
    parameters:
      - name: data
        type: object
        required: true
    script:
      command: python
      args: ["manage.py", "run_tool", "report"]
```

Django settings:

```python
# settings.py

INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'rest_framework',
    'django_celery_results',
    'mcp_tools',  # Our MCP tools app
]

# Celery configuration
CELERY_BROKER_URL = 'redis://localhost:6379/0'
CELERY_RESULT_BACKEND = 'django-db'
CELERY_ACCEPT_CONTENT = ['json']
CELERY_TASK_SERIALIZER = 'json'

# Cache configuration
CACHES = {
    'default': {
        'BACKEND': 'django.core.cache.backends.redis.RedisCache',
        'LOCATION': 'redis://localhost:6379/1',
    }
}

# REST Framework
REST_FRAMEWORK = {
    'DEFAULT_AUTHENTICATION_CLASSES': [
        'rest_framework.authentication.TokenAuthentication',
    ],
    'DEFAULT_PERMISSION_CLASSES': [
        'rest_framework.permissions.IsAuthenticated',
    ],
}

# MCP Settings
MCP_CONFIG = {
    'DEFAULT_TIMEOUT': 60,
    'MAX_RETRIES': 3,
    'CACHE_TTL': 3600,
}
```

## Step 2: Models

Define models for tool tracking:

```python
# mcp_tools/models.py

from django.db import models
from django.contrib.auth import get_user_model
import uuid

User = get_user_model()

class Tool(models.Model):
    """MCP tool definition."""
    name = models.CharField(max_length=100, unique=True)
    description = models.TextField()
    parameters_schema = models.JSONField(default=dict)
    is_active = models.BooleanField(default=True)
    timeout = models.IntegerField(default=60)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['name']

    def __str__(self):
        return self.name

class ToolExecution(models.Model):
    """Track tool executions."""

    class Status(models.TextChoices):
        PENDING = 'pending', 'Pending'
        RUNNING = 'running', 'Running'
        COMPLETED = 'completed', 'Completed'
        FAILED = 'failed', 'Failed'

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    tool = models.ForeignKey(Tool, on_delete=models.CASCADE, related_name='executions')
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='tool_executions')
    parameters = models.JSONField(default=dict)
    result = models.JSONField(null=True, blank=True)
    error = models.TextField(null=True, blank=True)
    status = models.CharField(
        max_length=20,
        choices=Status.choices,
        default=Status.PENDING
    )
    celery_task_id = models.CharField(max_length=100, null=True, blank=True)
    duration_ms = models.IntegerField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    completed_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.tool.name} - {self.status}"

class ToolUsageStats(models.Model):
    """Aggregate tool usage statistics."""
    tool = models.OneToOneField(Tool, on_delete=models.CASCADE, related_name='stats')
    total_executions = models.IntegerField(default=0)
    successful_executions = models.IntegerField(default=0)
    failed_executions = models.IntegerField(default=0)
    total_duration_ms = models.BigIntegerField(default=0)
    last_execution = models.DateTimeField(null=True, blank=True)

    @property
    def success_rate(self):
        if self.total_executions == 0:
            return 0
        return self.successful_executions / self.total_executions

    @property
    def average_duration_ms(self):
        if self.successful_executions == 0:
            return 0
        return self.total_duration_ms / self.successful_executions
```

## Step 3: Tool service

Service layer for tool execution:

```python
# mcp_tools/services.py

from typing import Dict, Any, Optional
from django.conf import settings
from django.core.cache import cache
from django.utils import timezone
import anthropic
import hashlib
import json

class MCPToolService:
    """Service for MCP tool execution."""

    def __init__(self):
        self.client = anthropic.Anthropic()
        self.config = settings.MCP_CONFIG

    def get_cache_key(self, tool_name: str, params: Dict) -> str:
        """Generate cache key for tool result."""
        param_hash = hashlib.md5(
            json.dumps(params, sort_keys=True).encode()
        ).hexdigest()
        return f"mcp_tool:{tool_name}:{param_hash}"

    def execute(
        self,
        tool_name: str,
        parameters: Dict[str, Any],
        use_cache: bool = True
    ) -> Dict[str, Any]:
        """Execute an MCP tool."""
        # Check cache
        if use_cache:
            cache_key = self.get_cache_key(tool_name, parameters)
            cached = cache.get(cache_key)
            if cached:
                return cached

        # Execute tool
        if tool_name == "summarize_content":
            result = self._summarize_content(parameters)
        elif tool_name == "generate_report":
            result = self._generate_report(parameters)
        else:
            raise ValueError(f"Unknown tool: {tool_name}")

        # Cache result
        if use_cache:
            cache.set(cache_key, result, self.config['CACHE_TTL'])

        return result

    def _summarize_content(self, params: Dict) -> Dict[str, Any]:
        """Summarize web content."""
        import httpx

        # Fetch content
        response = httpx.get(params["url"])
        content = response.text[:10000]  # Limit content

        # Summarize with LLM
        message = self.client.messages.create(
            model="claude-sonnet-4-20250514",
            max_tokens=500,
            messages=[{
                "role": "user",
                "content": f"Summarize this content:\n\n{content}"
            }]
        )

        return {
            "summary": message.content[0].text,
            "url": params["url"],
            "content_length": len(content)
        }

    def _generate_report(self, params: Dict) -> Dict[str, Any]:
        """Generate AI report."""
        data = params["data"]

        message = self.client.messages.create(
            model="claude-sonnet-4-20250514",
            max_tokens=2000,
            messages=[{
                "role": "user",
                "content": f"Generate a detailed report for this data:\n\n{json.dumps(data, indent=2)}"
            }]
        )

        return {
            "report": message.content[0].text,
            "generated_at": timezone.now().isoformat()
        }

# Singleton
tool_service = MCPToolService()
```

## Step 4: Celery tasks

Async execution with Celery:

```python
# mcp_tools/tasks.py

from celery import shared_task
from django.utils import timezone
from .models import ToolExecution, ToolUsageStats
from .services import tool_service
import time

@shared_task(bind=True, max_retries=3)
def execute_tool_async(self, execution_id: str):
    """Execute tool asynchronously."""
    execution = ToolExecution.objects.get(id=execution_id)

    try:
        # Update status
        execution.status = ToolExecution.Status.RUNNING
        execution.save()

        # Execute
        start = time.time()
        result = tool_service.execute(
            execution.tool.name,
            execution.parameters
        )
        duration = int((time.time() - start) * 1000)

        # Update execution
        execution.result = result
        execution.status = ToolExecution.Status.COMPLETED
        execution.duration_ms = duration
        execution.completed_at = timezone.now()
        execution.save()

        # Update stats
        _update_stats(execution.tool, success=True, duration=duration)

        return result

    except Exception as exc:
        execution.status = ToolExecution.Status.FAILED
        execution.error = str(exc)
        execution.completed_at = timezone.now()
        execution.save()

        # Update stats
        _update_stats(execution.tool, success=False)

        # Retry if applicable
        raise self.retry(exc=exc, countdown=60)

def _update_stats(tool, success: bool, duration: int = 0):
    """Update tool usage statistics."""
    stats, _ = ToolUsageStats.objects.get_or_create(tool=tool)

    stats.total_executions += 1
    if success:
        stats.successful_executions += 1
        stats.total_duration_ms += duration
    else:
        stats.failed_executions += 1

    stats.last_execution = timezone.now()
    stats.save()

@shared_task
def cleanup_old_executions(days: int = 30):
    """Clean up old execution records."""
    cutoff = timezone.now() - timezone.timedelta(days=days)
    deleted, _ = ToolExecution.objects.filter(
        created_at__lt=cutoff
    ).delete()
    return {"deleted": deleted}
```

## Step 5: API views

Django REST Framework views:

```python
# mcp_tools/views.py

from rest_framework import viewsets, status
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from django.shortcuts import get_object_or_404
from .models import Tool, ToolExecution
from .serializers import (
    ToolSerializer,
    ToolExecutionSerializer,
    ToolExecuteRequestSerializer
)
from .tasks import execute_tool_async

class ToolViewSet(viewsets.ReadOnlyModelViewSet):
    """ViewSet for MCP tools."""
    queryset = Tool.objects.filter(is_active=True)
    serializer_class = ToolSerializer
    permission_classes = [IsAuthenticated]

    @action(detail=True, methods=['post'])
    def execute(self, request, pk=None):
        """Execute a tool synchronously."""
        tool = self.get_object()

        serializer = ToolExecuteRequestSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        # Create execution record
        execution = ToolExecution.objects.create(
            tool=tool,
            user=request.user,
            parameters=serializer.validated_data.get('parameters', {})
        )

        # Execute synchronously
        try:
            from .services import tool_service
            import time

            execution.status = ToolExecution.Status.RUNNING
            execution.save()

            start = time.time()
            result = tool_service.execute(tool.name, execution.parameters)
            duration = int((time.time() - start) * 1000)

            execution.result = result
            execution.status = ToolExecution.Status.COMPLETED
            execution.duration_ms = duration
            execution.save()

            return Response(
                ToolExecutionSerializer(execution).data,
                status=status.HTTP_200_OK
            )

        except Exception as e:
            execution.status = ToolExecution.Status.FAILED
            execution.error = str(e)
            execution.save()

            return Response(
                {"error": str(e)},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

    @action(detail=True, methods=['post'])
    def execute_async(self, request, pk=None):
        """Execute a tool asynchronously."""
        tool = self.get_object()

        serializer = ToolExecuteRequestSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        # Create execution record
        execution = ToolExecution.objects.create(
            tool=tool,
            user=request.user,
            parameters=serializer.validated_data.get('parameters', {})
        )

        # Queue task
        task = execute_tool_async.delay(str(execution.id))
        execution.celery_task_id = task.id
        execution.save()

        return Response(
            {"execution_id": str(execution.id), "task_id": task.id},
            status=status.HTTP_202_ACCEPTED
        )

class ToolExecutionViewSet(viewsets.ReadOnlyModelViewSet):
    """ViewSet for tool executions."""
    serializer_class = ToolExecutionSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return ToolExecution.objects.filter(user=self.request.user)

    @action(detail=True, methods=['get'])
    def status(self, request, pk=None):
        """Get execution status."""
        execution = self.get_object()
        return Response({
            "id": str(execution.id),
            "status": execution.status,
            "result": execution.result,
            "error": execution.error
        })
```

## Step 6: Serializers

DRF serializers:

```python
# mcp_tools/serializers.py

from rest_framework import serializers
from .models import Tool, ToolExecution, ToolUsageStats

class ToolUsageStatsSerializer(serializers.ModelSerializer):
    success_rate = serializers.FloatField(read_only=True)
    average_duration_ms = serializers.FloatField(read_only=True)

    class Meta:
        model = ToolUsageStats
        fields = [
            'total_executions',
            'successful_executions',
            'failed_executions',
            'success_rate',
            'average_duration_ms',
            'last_execution'
        ]

class ToolSerializer(serializers.ModelSerializer):
    stats = ToolUsageStatsSerializer(read_only=True)

    class Meta:
        model = Tool
        fields = [
            'id', 'name', 'description',
            'parameters_schema', 'timeout',
            'created_at', 'stats'
        ]

class ToolExecutionSerializer(serializers.ModelSerializer):
    tool_name = serializers.CharField(source='tool.name', read_only=True)

    class Meta:
        model = ToolExecution
        fields = [
            'id', 'tool_name', 'parameters',
            'result', 'error', 'status',
            'duration_ms', 'created_at', 'completed_at'
        ]

class ToolExecuteRequestSerializer(serializers.Serializer):
    parameters = serializers.JSONField(required=False, default=dict)
    async_execution = serializers.BooleanField(required=False, default=False)
```

## Step 7: Admin interface

Django admin for tools:

```python
# mcp_tools/admin.py

from django.contrib import admin
from .models import Tool, ToolExecution, ToolUsageStats

@admin.register(Tool)
class ToolAdmin(admin.ModelAdmin):
    list_display = ['name', 'is_active', 'timeout', 'created_at']
    list_filter = ['is_active']
    search_fields = ['name', 'description']

@admin.register(ToolExecution)
class ToolExecutionAdmin(admin.ModelAdmin):
    list_display = ['id', 'tool', 'user', 'status', 'duration_ms', 'created_at']
    list_filter = ['status', 'tool']
    search_fields = ['tool__name', 'user__username']
    readonly_fields = ['id', 'result', 'error', 'created_at', 'completed_at']

@admin.register(ToolUsageStats)
class ToolUsageStatsAdmin(admin.ModelAdmin):
    list_display = [
        'tool', 'total_executions',
        'success_rate', 'average_duration_ms'
    ]
```

## Summary

Django + MCP integration:

1. **Project setup** - Django with MCP configuration
2. **Models** - Track tools and executions
3. **Service layer** - Tool execution logic
4. **Celery tasks** - Async execution
5. **REST API** - DRF views and serializers
6. **Admin** - Manage tools via Django admin

Build apps with [Gantz](https://gantz.run), power them with Django.

Production-ready AI.

## Related reading

- [MCP Caching](/post/mcp-caching/) - Cache tool results
- [Agent Task Queues](/post/agent-task-queues/) - Queue management
- [MCP Observability](/post/mcp-observability/) - Monitor tools

---

*How do you integrate MCP with Django? Share your approach.*
