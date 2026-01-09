+++
title = "MCP Server Discovery: Auto-Detect Available Tools"
image = "images/mcp-discovery.webp"
date = 2025-11-09
description = "Implement tool discovery for MCP servers. Let AI agents automatically find and use available tools without hardcoding configurations."
summary = "Enable AI agents to automatically discover available MCP tools through the standard tools/list endpoint and dynamic registries. Learn how to write rich tool descriptions with examples, implement capability-based grouping, add conditional tool exposure based on context, and cache discovery responses for optimal performance."
draft = false
tags = ['mcp', 'architecture', 'patterns']
voice = false

[howto]
name = "Implement MCP Tool Discovery"
totalTime = 25
[[howto.steps]]
name = "Create tool manifest"
text = "Define all available tools with descriptions and schemas."
[[howto.steps]]
name = "Implement discovery endpoint"
text = "Create an endpoint that returns the tool manifest."
[[howto.steps]]
name = "Add rich descriptions"
text = "Write clear descriptions that help AI choose the right tool."
[[howto.steps]]
name = "Include examples"
text = "Provide example inputs and outputs for each tool."
[[howto.steps]]
name = "Enable dynamic discovery"
text = "Allow tools to be added or removed without restarts."
+++


Your agent needs to know what tools exist.

Hardcoding? Fragile. Manual config? Error-prone.

Auto-discovery is the answer.

## Why discovery matters

AI agents work best when they understand their tools:

```text
Agent: "I need to read a file, but what tools do I have?"

Without discovery:
- Agent guesses tool names
- Wrong parameters
- Frustrating errors

With discovery:
- Agent queries available tools
- Sees exact parameters
- Works correctly first time
```

Discovery makes agents self-sufficient.

## The MCP tools/list method

MCP defines a standard discovery protocol:

```text
Client → Server: tools/list
Server → Client: [list of all available tools with schemas]
```

Response format:

```json
{
  "tools": [
    {
      "name": "read_file",
      "description": "Read the contents of a file",
      "inputSchema": {
        "type": "object",
        "properties": {
          "path": {
            "type": "string",
            "description": "Path to the file to read"
          }
        },
        "required": ["path"]
      }
    },
    {
      "name": "search_code",
      "description": "Search for patterns in code files",
      "inputSchema": {
        "type": "object",
        "properties": {
          "query": {
            "type": "string",
            "description": "Search pattern (regex supported)"
          },
          "path": {
            "type": "string",
            "description": "Directory to search in",
            "default": "."
          }
        },
        "required": ["query"]
      }
    }
  ]
}
```

## Implementation

### Basic discovery endpoint

```python
from flask import Flask, jsonify

app = Flask(__name__)

TOOLS = [
    {
        "name": "read_file",
        "description": "Read the contents of a file from the filesystem",
        "inputSchema": {
            "type": "object",
            "properties": {
                "path": {
                    "type": "string",
                    "description": "Absolute or relative path to the file"
                }
            },
            "required": ["path"]
        }
    },
    {
        "name": "write_file",
        "description": "Write content to a file, creating it if it doesn't exist",
        "inputSchema": {
            "type": "object",
            "properties": {
                "path": {
                    "type": "string",
                    "description": "Path where the file should be written"
                },
                "content": {
                    "type": "string",
                    "description": "Content to write to the file"
                }
            },
            "required": ["path", "content"]
        }
    }
]

@app.route("/mcp/tools", methods=["GET"])
def list_tools():
    return jsonify({"tools": TOOLS})
```

### Dynamic tool registry

Tools can be added at runtime:

```python
class ToolRegistry:
    def __init__(self):
        self.tools = {}

    def register(self, name: str, handler, schema: dict, description: str):
        self.tools[name] = {
            "name": name,
            "description": description,
            "inputSchema": schema,
            "handler": handler
        }

    def unregister(self, name: str):
        self.tools.pop(name, None)

    def list(self):
        return [
            {k: v for k, v in tool.items() if k != "handler"}
            for tool in self.tools.values()
        ]

    def get_handler(self, name: str):
        tool = self.tools.get(name)
        return tool["handler"] if tool else None

registry = ToolRegistry()

# Register tools
registry.register(
    name="read_file",
    handler=read_file_handler,
    schema={
        "type": "object",
        "properties": {
            "path": {"type": "string", "description": "File path"}
        },
        "required": ["path"]
    },
    description="Read file contents"
)

@app.route("/mcp/tools", methods=["GET"])
def list_tools():
    return jsonify({"tools": registry.list()})
```

### Plugin-based discovery

Load tools from plugins:

```python
import importlib
import pkgutil

class PluginLoader:
    def __init__(self, plugin_package: str):
        self.plugin_package = plugin_package
        self.tools = {}

    def discover(self):
        """Discover and load all tool plugins."""
        package = importlib.import_module(self.plugin_package)

        for _, name, _ in pkgutil.iter_modules(package.__path__):
            module = importlib.import_module(f"{self.plugin_package}.{name}")

            if hasattr(module, "TOOL_DEFINITION"):
                definition = module.TOOL_DEFINITION
                self.tools[definition["name"]] = {
                    **definition,
                    "handler": module.handle
                }

        return self.tools

# Plugin example: plugins/read_file.py
TOOL_DEFINITION = {
    "name": "read_file",
    "description": "Read file contents",
    "inputSchema": {
        "type": "object",
        "properties": {
            "path": {"type": "string"}
        },
        "required": ["path"]
    }
}

def handle(params):
    with open(params["path"]) as f:
        return f.read()
```

## Rich tool descriptions

Good descriptions help AI choose correctly:

### Bad descriptions

```json
{
  "name": "search",
  "description": "Search stuff"
}
```

AI doesn't know what "stuff" means or when to use this.

### Good descriptions

```json
{
  "name": "search_code",
  "description": "Search for text patterns in source code files. Supports regex patterns. Use this when you need to find function definitions, variable usages, or specific code patterns. Returns matching lines with file paths and line numbers.",
  "inputSchema": {
    "type": "object",
    "properties": {
      "query": {
        "type": "string",
        "description": "Search pattern. Can be plain text or regex. Examples: 'function login', 'def \\w+\\(', 'TODO:'"
      },
      "path": {
        "type": "string",
        "description": "Directory to search in. Defaults to current directory.",
        "default": "."
      },
      "file_types": {
        "type": "array",
        "items": {"type": "string"},
        "description": "File extensions to include. Examples: ['.py', '.js']",
        "default": []
      }
    },
    "required": ["query"]
  }
}
```

### Include examples

```json
{
  "name": "run_command",
  "description": "Execute a shell command and return the output",
  "inputSchema": {
    "type": "object",
    "properties": {
      "command": {
        "type": "string",
        "description": "Shell command to execute",
        "examples": [
          "ls -la",
          "git status",
          "npm test"
        ]
      }
    },
    "required": ["command"]
  },
  "examples": [
    {
      "input": {"command": "echo hello"},
      "output": {"stdout": "hello\n", "exit_code": 0}
    }
  ]
}
```

## Capability-based discovery

Group tools by capability:

```python
CAPABILITIES = {
    "filesystem": {
        "description": "Read and write files",
        "tools": ["read_file", "write_file", "list_files", "delete_file"]
    },
    "code": {
        "description": "Search and analyze code",
        "tools": ["search_code", "parse_ast", "find_references"]
    },
    "shell": {
        "description": "Execute shell commands",
        "tools": ["run_command"]
    },
    "database": {
        "description": "Query databases",
        "tools": ["query_sql", "list_tables"]
    }
}

@app.route("/mcp/capabilities", methods=["GET"])
def list_capabilities():
    return jsonify({"capabilities": CAPABILITIES})

@app.route("/mcp/tools", methods=["GET"])
def list_tools():
    capability = request.args.get("capability")

    if capability:
        tool_names = CAPABILITIES.get(capability, {}).get("tools", [])
        tools = [t for t in TOOLS if t["name"] in tool_names]
    else:
        tools = TOOLS

    return jsonify({"tools": tools})
```

## Conditional tools

Show tools based on context:

```python
def get_available_tools(context: dict) -> list:
    """Return tools available in this context."""
    tools = []

    # Always available
    tools.extend(get_core_tools())

    # File tools if working directory set
    if context.get("working_directory"):
        tools.extend(get_file_tools())

    # Database tools if connection configured
    if context.get("database_url"):
        tools.extend(get_database_tools())

    # Admin tools if user is admin
    if context.get("user_role") == "admin":
        tools.extend(get_admin_tools())

    return tools

@app.route("/mcp/tools", methods=["GET"])
def list_tools():
    context = {
        "working_directory": request.headers.get("X-Working-Dir"),
        "database_url": request.headers.get("X-Database-URL"),
        "user_role": get_user_role(request)
    }

    tools = get_available_tools(context)
    return jsonify({"tools": tools})
```

## Caching discovery

Cache tool lists for performance:

```python
from functools import lru_cache
import hashlib

@lru_cache(maxsize=100)
def get_tools_cached(context_hash: str) -> list:
    # Expensive operation - load from plugins, etc.
    return load_all_tools()

@app.route("/mcp/tools", methods=["GET"])
def list_tools():
    # Create hash of context that affects available tools
    context = {
        "user": get_user_id(request),
        "capabilities": request.args.get("capabilities", "")
    }
    context_hash = hashlib.md5(str(context).encode()).hexdigest()

    tools = get_tools_cached(context_hash)
    return jsonify({"tools": tools})
```

## Discovery in Claude Desktop

Claude Desktop automatically discovers tools:

```json
// claude_desktop_config.json
{
  "mcpServers": {
    "my-tools": {
      "url": "https://my-server.gantz.run/sse",
      "authorization_token": "gtz_abc123"
    }
  }
}
```

Claude calls `tools/list` on startup and learns available tools.

## Quick setup with Gantz

[Gantz](https://gantz.run) handles discovery automatically:

```yaml
# gantz.yaml
name: my-tools

tools:
  - name: read_file
    description: Read file contents from the filesystem
    parameters:
      - name: path
        type: string
        required: true
        description: Path to the file
    script:
      shell: cat "{{path}}"

  - name: search_code
    description: Search for patterns in source code
    parameters:
      - name: query
        type: string
        required: true
        description: Search pattern (regex)
    script:
      shell: rg "{{query}}" .
```

```bash
gantz run
# Discovery endpoint automatically available at /mcp/tools
```

## Monitoring discovery

Track what clients discover:

```python
from prometheus_client import Counter

discovery_requests = Counter(
    'mcp_discovery_requests_total',
    'Number of tool discovery requests',
    ['client_id']
)

@app.route("/mcp/tools", methods=["GET"])
def list_tools():
    client_id = get_client_id(request)
    discovery_requests.labels(client_id=client_id).inc()

    logger.info("tools_discovered", extra={
        "client_id": client_id,
        "tool_count": len(TOOLS)
    })

    return jsonify({"tools": TOOLS})
```

## Best practices

1. **Rich descriptions** - Help AI understand when to use each tool
2. **Include examples** - Show expected inputs and outputs
3. **Group by capability** - Make discovery intuitive
4. **Cache responses** - Discovery is called frequently
5. **Version your schema** - Include version in discovery response
6. **Monitor usage** - Track which tools are discovered and used
7. **Test descriptions** - Verify AI picks the right tools

## Summary

Tool discovery makes agents self-sufficient:

1. **Standard endpoint** - `tools/list` returns all available tools
2. **Rich schemas** - Include descriptions, types, examples
3. **Dynamic registration** - Add/remove tools at runtime
4. **Context-aware** - Show different tools based on permissions
5. **Cache effectively** - Discovery is called often

Good discovery means agents find the right tool for the job without guessing.

Make your tools discoverable. Make your agents smarter.

## Related reading

- [Writing Tool Descriptions That Work](/post/tool-descriptions/) - Better descriptions
- [50 MCP Tool Ideas](/post/50-tools/) - Tools to implement
- [MCP in Your Stack](/post/mcp-in-stack/) - Architecture guide

---

*How do you handle tool discovery? Share your patterns.*
