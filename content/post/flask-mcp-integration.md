+++
title = "Flask MCP Integration: Lightweight AI APIs"
image = "images/flask-mcp-integration.webp"
date = 2025-11-23
description = "Integrate MCP tools with Flask applications. Build lightweight AI-powered APIs with blueprints, async support, and extension patterns."
draft = false
tags = ['mcp', 'flask', 'python', 'api']
voice = false

[howto]
name = "Integrate MCP with Flask"
totalTime = 25
[[howto.steps]]
name = "Set up Flask project"
text = "Create Flask app with MCP configuration."
[[howto.steps]]
name = "Create tool blueprints"
text = "Organize tools with Flask blueprints."
[[howto.steps]]
name = "Add async support"
text = "Enable async tool execution."
[[howto.steps]]
name = "Implement streaming"
text = "Add SSE streaming for responses."
[[howto.steps]]
name = "Configure extensions"
text = "Add caching, rate limiting extensions."
+++


Flask is minimal by design. MCP adds AI capabilities.

Together, they build lean, intelligent APIs.

## Why Flask + MCP

Flask provides:
- Minimal core
- Extension ecosystem
- Blueprint organization
- WSGI compatibility

MCP provides:
- AI tool execution
- LLM integration
- Agent orchestration

## Step 1: Project setup

Using [Gantz](https://gantz.run):

```yaml
# gantz.yaml
name: flask-mcp-api

tools:
  - name: generate_response
    description: Generate AI response
    parameters:
      - name: prompt
        type: string
        required: true
    script:
      command: python
      args: ["tools/generate.py"]

  - name: classify_text
    description: Classify text content
    parameters:
      - name: text
        type: string
        required: true
    script:
      command: python
      args: ["tools/classify.py"]
```

Flask application setup:

```python
# app/__init__.py
from flask import Flask
from flask_cors import CORS
from flask_caching import Cache
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address

cache = Cache()
limiter = Limiter(key_func=get_remote_address)

def create_app(config_name='default'):
    app = Flask(__name__)

    # Load config
    app.config.from_object(f'config.{config_name}')

    # Initialize extensions
    CORS(app)
    cache.init_app(app)
    limiter.init_app(app)

    # Register blueprints
    from app.tools import tools_bp
    from app.chat import chat_bp

    app.register_blueprint(tools_bp, url_prefix='/api/tools')
    app.register_blueprint(chat_bp, url_prefix='/api/chat')

    # Health check
    @app.route('/health')
    def health():
        return {'status': 'healthy'}

    return app
```

Configuration:

```python
# config.py
import os

class default:
    SECRET_KEY = os.environ.get('SECRET_KEY', 'dev-secret')
    ANTHROPIC_API_KEY = os.environ.get('ANTHROPIC_API_KEY')

    # Cache config
    CACHE_TYPE = 'redis'
    CACHE_REDIS_URL = os.environ.get('REDIS_URL', 'redis://localhost:6379/0')
    CACHE_DEFAULT_TIMEOUT = 300

    # Rate limiting
    RATELIMIT_STORAGE_URL = os.environ.get('REDIS_URL', 'redis://localhost:6379/1')
    RATELIMIT_DEFAULT = '60/minute'

class production(default):
    DEBUG = False

class development(default):
    DEBUG = True
```

## Step 2: MCP service

Tool execution service:

```python
# app/services/mcp_service.py
import anthropic
from typing import Dict, Any, Optional
from flask import current_app

class MCPToolService:
    """Service for MCP tool execution."""

    def __init__(self):
        self._client = None

    @property
    def client(self):
        if self._client is None:
            self._client = anthropic.Anthropic()
        return self._client

    def execute(self, tool_name: str, params: Dict[str, Any]) -> Dict[str, Any]:
        """Execute an MCP tool."""
        handlers = {
            'generate_response': self._generate_response,
            'classify_text': self._classify_text,
            'summarize': self._summarize,
            'extract_entities': self._extract_entities,
        }

        handler = handlers.get(tool_name)
        if not handler:
            raise ValueError(f'Unknown tool: {tool_name}')

        return handler(params)

    def _generate_response(self, params: Dict) -> Dict[str, Any]:
        """Generate AI response."""
        response = self.client.messages.create(
            model='claude-sonnet-4-20250514',
            max_tokens=params.get('max_tokens', 500),
            messages=[{'role': 'user', 'content': params['prompt']}]
        )

        return {
            'response': response.content[0].text,
            'usage': {
                'input': response.usage.input_tokens,
                'output': response.usage.output_tokens
            }
        }

    def _classify_text(self, params: Dict) -> Dict[str, Any]:
        """Classify text content."""
        categories = params.get('categories', ['positive', 'negative', 'neutral'])

        response = self.client.messages.create(
            model='claude-sonnet-4-20250514',
            max_tokens=100,
            messages=[{
                'role': 'user',
                'content': f'Classify this text into one of these categories: {categories}\n\nText: {params["text"]}\n\nRespond with only the category name.'
            }]
        )

        return {
            'category': response.content[0].text.strip(),
            'text': params['text'][:100]
        }

    def _summarize(self, params: Dict) -> Dict[str, Any]:
        """Summarize text."""
        response = self.client.messages.create(
            model='claude-sonnet-4-20250514',
            max_tokens=params.get('max_length', 200),
            messages=[{
                'role': 'user',
                'content': f'Summarize this text concisely:\n\n{params["text"]}'
            }]
        )

        return {
            'summary': response.content[0].text,
            'original_length': len(params['text'])
        }

    def _extract_entities(self, params: Dict) -> Dict[str, Any]:
        """Extract named entities."""
        response = self.client.messages.create(
            model='claude-sonnet-4-20250514',
            max_tokens=500,
            messages=[{
                'role': 'user',
                'content': f'Extract named entities (people, places, organizations, dates) from this text. Return as JSON:\n\n{params["text"]}'
            }]
        )

        import json
        try:
            entities = json.loads(response.content[0].text)
        except json.JSONDecodeError:
            entities = {'raw': response.content[0].text}

        return {'entities': entities}

    def list_tools(self):
        """List available tools."""
        return [
            {'name': 'generate_response', 'description': 'Generate AI response'},
            {'name': 'classify_text', 'description': 'Classify text content'},
            {'name': 'summarize', 'description': 'Summarize text'},
            {'name': 'extract_entities', 'description': 'Extract named entities'},
        ]

# Singleton
tool_service = MCPToolService()
```

## Step 3: Tool blueprints

Organize routes with blueprints:

```python
# app/tools/__init__.py
from flask import Blueprint

tools_bp = Blueprint('tools', __name__)

from . import routes
```

```python
# app/tools/routes.py
from flask import request, jsonify
from . import tools_bp
from app.services.mcp_service import tool_service
from app import cache, limiter

@tools_bp.route('/', methods=['GET'])
def list_tools():
    """List all available tools."""
    return jsonify({'tools': tool_service.list_tools()})

@tools_bp.route('/execute', methods=['POST'])
@limiter.limit('30/minute')
def execute_tool():
    """Execute an MCP tool."""
    data = request.get_json()

    if not data:
        return jsonify({'error': 'Request body required'}), 400

    tool_name = data.get('tool_name')
    parameters = data.get('parameters', {})

    if not tool_name:
        return jsonify({'error': 'tool_name required'}), 400

    try:
        result = tool_service.execute(tool_name, parameters)
        return jsonify({'success': True, 'data': result})
    except ValueError as e:
        return jsonify({'success': False, 'error': str(e)}), 404
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@tools_bp.route('/<tool_name>', methods=['POST'])
@limiter.limit('30/minute')
def execute_specific_tool(tool_name):
    """Execute a specific tool."""
    parameters = request.get_json() or {}

    try:
        result = tool_service.execute(tool_name, parameters)
        return jsonify({'success': True, 'data': result})
    except ValueError as e:
        return jsonify({'success': False, 'error': str(e)}), 404
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

# Cached endpoint
@tools_bp.route('/cached/<tool_name>', methods=['POST'])
@cache.cached(timeout=300, query_string=True)
def execute_cached_tool(tool_name):
    """Execute tool with caching."""
    parameters = request.get_json() or {}

    try:
        result = tool_service.execute(tool_name, parameters)
        return jsonify({'success': True, 'data': result, 'cached': True})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500
```

## Step 4: Chat blueprint with streaming

Streaming responses:

```python
# app/chat/__init__.py
from flask import Blueprint

chat_bp = Blueprint('chat', __name__)

from . import routes
```

```python
# app/chat/routes.py
from flask import request, jsonify, Response, stream_with_context
from . import chat_bp
from app import limiter
import anthropic
import json

client = anthropic.Anthropic()

@chat_bp.route('/', methods=['POST'])
@limiter.limit('20/minute')
def chat():
    """Regular chat endpoint."""
    data = request.get_json()

    if not data or 'messages' not in data:
        return jsonify({'error': 'messages required'}), 400

    try:
        response = client.messages.create(
            model='claude-sonnet-4-20250514',
            max_tokens=data.get('max_tokens', 500),
            messages=data['messages']
        )

        return jsonify({
            'content': response.content[0].text,
            'usage': {
                'input': response.usage.input_tokens,
                'output': response.usage.output_tokens
            }
        })
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@chat_bp.route('/stream', methods=['POST'])
@limiter.limit('20/minute')
def chat_stream():
    """Streaming chat endpoint."""
    data = request.get_json()

    if not data or 'messages' not in data:
        return jsonify({'error': 'messages required'}), 400

    def generate():
        try:
            with client.messages.stream(
                model='claude-sonnet-4-20250514',
                max_tokens=data.get('max_tokens', 500),
                messages=data['messages']
            ) as stream:
                for text in stream.text_stream:
                    yield f'data: {json.dumps({"text": text})}\n\n'

            yield 'data: [DONE]\n\n'
        except Exception as e:
            yield f'data: {json.dumps({"error": str(e)})}\n\n'

    return Response(
        stream_with_context(generate()),
        mimetype='text/event-stream',
        headers={
            'Cache-Control': 'no-cache',
            'Connection': 'keep-alive'
        }
    )

@chat_bp.route('/completions', methods=['POST'])
def completions():
    """OpenAI-compatible completions endpoint."""
    data = request.get_json()

    prompt = data.get('prompt', '')
    messages = data.get('messages', [])

    if prompt and not messages:
        messages = [{'role': 'user', 'content': prompt}]

    stream = data.get('stream', False)

    if stream:
        def generate():
            with client.messages.stream(
                model='claude-sonnet-4-20250514',
                max_tokens=data.get('max_tokens', 500),
                messages=messages
            ) as stream:
                for text in stream.text_stream:
                    chunk = {
                        'choices': [{
                            'delta': {'content': text},
                            'index': 0
                        }]
                    }
                    yield f'data: {json.dumps(chunk)}\n\n'

            yield 'data: [DONE]\n\n'

        return Response(
            generate(),
            mimetype='text/event-stream'
        )

    response = client.messages.create(
        model='claude-sonnet-4-20250514',
        max_tokens=data.get('max_tokens', 500),
        messages=messages
    )

    return jsonify({
        'choices': [{
            'message': {
                'role': 'assistant',
                'content': response.content[0].text
            },
            'index': 0
        }],
        'usage': {
            'prompt_tokens': response.usage.input_tokens,
            'completion_tokens': response.usage.output_tokens
        }
    })
```

## Step 5: Async support

Add async execution with Celery or threading:

```python
# app/services/async_executor.py
from concurrent.futures import ThreadPoolExecutor
from functools import wraps
import uuid

executor = ThreadPoolExecutor(max_workers=10)
tasks = {}

def async_task(func):
    """Decorator for async task execution."""
    @wraps(func)
    def wrapper(*args, **kwargs):
        task_id = str(uuid.uuid4())
        tasks[task_id] = {'status': 'pending', 'result': None, 'error': None}

        def run_task():
            tasks[task_id]['status'] = 'running'
            try:
                result = func(*args, **kwargs)
                tasks[task_id]['status'] = 'completed'
                tasks[task_id]['result'] = result
            except Exception as e:
                tasks[task_id]['status'] = 'failed'
                tasks[task_id]['error'] = str(e)

        executor.submit(run_task)
        return task_id

    return wrapper

def get_task_status(task_id):
    """Get task status."""
    return tasks.get(task_id)
```

```python
# app/tools/async_routes.py
from flask import request, jsonify
from . import tools_bp
from app.services.mcp_service import tool_service
from app.services.async_executor import async_task, get_task_status

@async_task
def execute_tool_async(tool_name, params):
    """Execute tool asynchronously."""
    return tool_service.execute(tool_name, params)

@tools_bp.route('/async/execute', methods=['POST'])
def submit_async_tool():
    """Submit tool for async execution."""
    data = request.get_json()

    tool_name = data.get('tool_name')
    parameters = data.get('parameters', {})

    if not tool_name:
        return jsonify({'error': 'tool_name required'}), 400

    task_id = execute_tool_async(tool_name, parameters)
    return jsonify({'task_id': task_id}), 202

@tools_bp.route('/async/status/<task_id>', methods=['GET'])
def check_task_status(task_id):
    """Check async task status."""
    status = get_task_status(task_id)

    if not status:
        return jsonify({'error': 'Task not found'}), 404

    return jsonify(status)
```

## Step 6: Error handling

Flask error handlers:

```python
# app/errors.py
from flask import jsonify

class ToolError(Exception):
    """Custom tool error."""
    def __init__(self, message, status_code=400):
        self.message = message
        self.status_code = status_code

def register_error_handlers(app):
    """Register error handlers."""

    @app.errorhandler(ToolError)
    def handle_tool_error(error):
        return jsonify({
            'success': False,
            'error': error.message
        }), error.status_code

    @app.errorhandler(400)
    def bad_request(error):
        return jsonify({
            'success': False,
            'error': 'Bad request'
        }), 400

    @app.errorhandler(404)
    def not_found(error):
        return jsonify({
            'success': False,
            'error': 'Not found'
        }), 404

    @app.errorhandler(429)
    def rate_limited(error):
        return jsonify({
            'success': False,
            'error': 'Rate limit exceeded'
        }), 429

    @app.errorhandler(500)
    def internal_error(error):
        return jsonify({
            'success': False,
            'error': 'Internal server error'
        }), 500
```

## Step 7: Flask CLI commands

Management commands:

```python
# app/commands.py
import click
from flask.cli import with_appcontext
from app.services.mcp_service import tool_service

@click.command('list-tools')
@with_appcontext
def list_tools_cmd():
    """List available MCP tools."""
    tools = tool_service.list_tools()
    for tool in tools:
        click.echo(f"  - {tool['name']}: {tool['description']}")

@click.command('execute-tool')
@click.argument('tool_name')
@click.option('--param', '-p', multiple=True, help='Parameters as key=value')
@with_appcontext
def execute_tool_cmd(tool_name, param):
    """Execute an MCP tool from CLI."""
    params = {}
    for p in param:
        key, value = p.split('=', 1)
        params[key] = value

    try:
        result = tool_service.execute(tool_name, params)
        click.echo(f"Result: {result}")
    except Exception as e:
        click.echo(f"Error: {e}", err=True)

def register_commands(app):
    app.cli.add_command(list_tools_cmd)
    app.cli.add_command(execute_tool_cmd)
```

## Summary

Flask + MCP integration:

1. **Project setup** - Flask with extensions
2. **MCP service** - Tool execution logic
3. **Blueprints** - Organized routes
4. **Streaming** - SSE responses
5. **Async execution** - Background tasks
6. **Error handling** - Comprehensive errors
7. **CLI commands** - Management tools

Build APIs with [Gantz](https://gantz.run), power them with Flask.

Minimal and capable.

## Related reading

- [Django MCP Integration](/post/django-mcp-integration/) - Full-featured Django
- [FastAPI MCP Integration](/post/fastapi-mcp-integration/) - Async FastAPI
- [MCP Caching](/post/mcp-caching/) - Cache responses

---

*How do you build AI APIs with Flask? Share your approach.*
