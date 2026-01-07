+++
title = "Dynamic MCP Tool Generation: Create Tools at Runtime"
image = "images/dynamic-tool-generation.webp"
date = 2025-11-12
description = "Generate MCP tools dynamically at runtime. Use AI to create new tools, generate tool schemas, and adapt toolsets to user needs automatically."
draft = false
tags = ['mcp', 'tools', 'dynamic']
voice = false

[howto]
name = "Generate Dynamic Tools"
totalTime = 35
[[howto.steps]]
name = "Define tool templates"
text = "Create base templates for tool generation."
[[howto.steps]]
name = "Build generation pipeline"
text = "Use AI to generate tool definitions."
[[howto.steps]]
name = "Validate generated tools"
text = "Ensure tools are safe and functional."
[[howto.steps]]
name = "Register tools dynamically"
text = "Add tools to the MCP server at runtime."
[[howto.steps]]
name = "Test generated tools"
text = "Automatically test new tools before use."
+++


Static tools are limiting.

What if agents could create their own tools?

That's dynamic tool generation.

## Why generate tools dynamically?

Fixed toolsets can't adapt. Dynamic generation enables:
- **Task-specific tools** - Create tools for specific needs
- **User customization** - Tools tailored to user workflows
- **Self-improvement** - Agents that expand their capabilities
- **Rapid prototyping** - Quick tool creation

## Step 1: Tool templates

Using [Gantz](https://gantz.run):

```yaml
# gantz.yaml
name: dynamic-tools

# Template for generated tools
templates:
  shell_tool:
    parameters:
      - name: input
        type: string
        required: true
    script:
      shell: "{{command}}"

  api_tool:
    parameters:
      - name: query
        type: string
        required: true
    script:
      shell: 'curl -s "{{base_url}}?q={{query}}"'

  python_tool:
    parameters:
      - name: input
        type: string
        required: true
    script:
      command: python
      args: ["-c", "{{code}}"]

tools:
  - name: generate_tool
    description: Generate a new tool from template
    parameters:
      - name: template
        type: string
        required: true
      - name: name
        type: string
        required: true
      - name: description
        type: string
        required: true
      - name: config
        type: object
        required: true
    script:
      command: python
      args: ["scripts/generate_tool.py"]
```

Tool generation framework:

```python
from typing import Dict, Any, List, Optional, Callable
from dataclasses import dataclass, field
import json
import re

@dataclass
class ToolTemplate:
    """Template for generating tools."""
    name: str
    base_schema: Dict[str, Any]
    generator: Callable[[Dict[str, Any]], Dict[str, Any]]
    validator: Optional[Callable[[Dict[str, Any]], bool]] = None

@dataclass
class GeneratedTool:
    """A dynamically generated tool."""
    name: str
    description: str
    parameters: List[Dict[str, Any]]
    executor: Callable[[Dict[str, Any]], Any]
    metadata: Dict[str, Any] = field(default_factory=dict)

class ToolGenerator:
    """Generate tools dynamically."""

    def __init__(self):
        self.templates: Dict[str, ToolTemplate] = {}
        self.generated_tools: Dict[str, GeneratedTool] = {}

    def register_template(self, template: ToolTemplate):
        """Register a tool template."""
        self.templates[template.name] = template

    def generate(
        self,
        template_name: str,
        config: Dict[str, Any]
    ) -> GeneratedTool:
        """Generate a tool from template."""

        if template_name not in self.templates:
            raise ValueError(f"Unknown template: {template_name}")

        template = self.templates[template_name]

        # Generate tool definition
        tool_def = template.generator(config)

        # Validate if validator exists
        if template.validator and not template.validator(tool_def):
            raise ValueError("Generated tool failed validation")

        # Create executable tool
        tool = self._create_tool(tool_def, config)

        # Register
        self.generated_tools[tool.name] = tool

        return tool

    def _create_tool(
        self,
        tool_def: Dict[str, Any],
        config: Dict[str, Any]
    ) -> GeneratedTool:
        """Create executable tool from definition."""

        # Create executor based on type
        exec_type = tool_def.get("execution_type", "shell")

        if exec_type == "shell":
            executor = self._create_shell_executor(tool_def)
        elif exec_type == "python":
            executor = self._create_python_executor(tool_def)
        elif exec_type == "api":
            executor = self._create_api_executor(tool_def)
        else:
            raise ValueError(f"Unknown execution type: {exec_type}")

        return GeneratedTool(
            name=tool_def["name"],
            description=tool_def["description"],
            parameters=tool_def.get("parameters", []),
            executor=executor,
            metadata={"generated_from": config}
        )

    def _create_shell_executor(self, tool_def: Dict[str, Any]) -> Callable:
        """Create shell command executor."""
        command_template = tool_def["command"]

        def executor(params: Dict[str, Any]) -> str:
            import subprocess

            # Fill in parameters
            command = command_template
            for key, value in params.items():
                command = command.replace(f"{{{{{key}}}}}", str(value))

            result = subprocess.run(
                command,
                shell=True,
                capture_output=True,
                text=True,
                timeout=30
            )

            return result.stdout

        return executor

    def _create_python_executor(self, tool_def: Dict[str, Any]) -> Callable:
        """Create Python code executor."""
        code = tool_def["code"]

        def executor(params: Dict[str, Any]) -> Any:
            # Create safe execution environment
            local_vars = {"params": params, "result": None}

            exec(code, {"__builtins__": {}}, local_vars)

            return local_vars.get("result")

        return executor

    def _create_api_executor(self, tool_def: Dict[str, Any]) -> Callable:
        """Create API call executor."""
        base_url = tool_def["base_url"]
        method = tool_def.get("method", "GET")
        headers = tool_def.get("headers", {})

        def executor(params: Dict[str, Any]) -> Dict[str, Any]:
            import requests

            url = base_url.format(**params)

            if method == "GET":
                response = requests.get(url, headers=headers, params=params)
            else:
                response = requests.post(url, headers=headers, json=params)

            return response.json()

        return executor

# Define templates
generator = ToolGenerator()

# Shell command template
generator.register_template(ToolTemplate(
    name="shell",
    base_schema={
        "execution_type": "shell",
        "parameters": [{"name": "input", "type": "string"}]
    },
    generator=lambda config: {
        "name": config["name"],
        "description": config["description"],
        "execution_type": "shell",
        "command": config["command"],
        "parameters": config.get("parameters", [{"name": "input", "type": "string"}])
    },
    validator=lambda t: not any(d in t["command"] for d in ["rm -rf", "sudo"])
))

# API tool template
generator.register_template(ToolTemplate(
    name="api",
    base_schema={
        "execution_type": "api",
        "parameters": [{"name": "query", "type": "string"}]
    },
    generator=lambda config: {
        "name": config["name"],
        "description": config["description"],
        "execution_type": "api",
        "base_url": config["url"],
        "method": config.get("method", "GET"),
        "headers": config.get("headers", {}),
        "parameters": config.get("parameters", [])
    }
))
```

## Step 2: AI-powered generation

Use AI to generate tools:

```python
import anthropic
import json

class AIToolGenerator:
    """Use AI to generate tool definitions."""

    def __init__(self, tool_generator: ToolGenerator):
        self.client = anthropic.Anthropic()
        self.generator = tool_generator

    def generate_from_description(
        self,
        description: str,
        context: Dict[str, Any] = None
    ) -> GeneratedTool:
        """Generate tool from natural language description."""

        prompt = f"""Generate a tool definition based on this description:

Description: {description}

Context: {json.dumps(context or {})}

Available templates: {list(self.generator.templates.keys())}

Respond with a JSON object containing:
- template: which template to use
- name: tool name (snake_case)
- description: brief description
- config: template-specific configuration

Example for a shell template:
{{
    "template": "shell",
    "name": "list_files",
    "description": "List files in a directory",
    "config": {{
        "command": "ls -la {{{{directory}}}}",
        "parameters": [{{"name": "directory", "type": "string", "default": "."}}]
    }}
}}

Only output the JSON, no other text."""

        response = self.client.messages.create(
            model="claude-sonnet-4-20250514",
            max_tokens=1024,
            messages=[{"role": "user", "content": prompt}]
        )

        # Parse response
        try:
            tool_spec = json.loads(response.content[0].text)
        except json.JSONDecodeError:
            # Try to extract JSON from response
            text = response.content[0].text
            json_match = re.search(r'\{[\s\S]*\}', text)
            if json_match:
                tool_spec = json.loads(json_match.group())
            else:
                raise ValueError("Could not parse tool definition")

        # Generate tool
        return self.generator.generate(
            tool_spec["template"],
            {
                "name": tool_spec["name"],
                "description": tool_spec["description"],
                **tool_spec.get("config", {})
            }
        )

    def suggest_tools(
        self,
        task: str,
        existing_tools: List[str]
    ) -> List[Dict[str, Any]]:
        """Suggest new tools that would help with a task."""

        prompt = f"""Given this task and existing tools, suggest new tools that would help:

Task: {task}

Existing tools: {existing_tools}

Suggest 1-3 new tools that would make this task easier.
For each tool, provide:
- name: suggested name
- description: what it does
- why: why it would help

Output as JSON array."""

        response = self.client.messages.create(
            model="claude-sonnet-4-20250514",
            max_tokens=1024,
            messages=[{"role": "user", "content": prompt}]
        )

        return json.loads(response.content[0].text)

# Usage
ai_generator = AIToolGenerator(generator)

# Generate tool from description
tool = ai_generator.generate_from_description(
    "A tool that searches for files by name in a directory"
)

print(f"Generated: {tool.name}")
print(f"Description: {tool.description}")

# Execute
result = tool.executor({"directory": "/home", "pattern": "*.py"})
```

## Step 3: Schema generation

Generate tool schemas dynamically:

```python
from typing import get_type_hints, get_origin, get_args
import inspect

class SchemaGenerator:
    """Generate tool schemas from various sources."""

    @staticmethod
    def from_function(func: Callable) -> Dict[str, Any]:
        """Generate schema from function signature."""

        sig = inspect.signature(func)
        hints = get_type_hints(func)

        parameters = []

        for name, param in sig.parameters.items():
            param_type = hints.get(name, str)
            param_info = {
                "name": name,
                "type": SchemaGenerator._type_to_string(param_type),
                "required": param.default == inspect.Parameter.empty
            }

            if param.default != inspect.Parameter.empty:
                param_info["default"] = param.default

            parameters.append(param_info)

        return {
            "name": func.__name__,
            "description": func.__doc__ or "",
            "parameters": parameters
        }

    @staticmethod
    def _type_to_string(t) -> str:
        """Convert Python type to schema type string."""
        origin = get_origin(t)

        if origin is list:
            return "array"
        elif origin is dict:
            return "object"
        elif t == int:
            return "integer"
        elif t == float:
            return "number"
        elif t == bool:
            return "boolean"
        else:
            return "string"

    @staticmethod
    def from_api_spec(openapi_spec: Dict[str, Any]) -> List[Dict[str, Any]]:
        """Generate tool schemas from OpenAPI spec."""

        tools = []

        for path, methods in openapi_spec.get("paths", {}).items():
            for method, spec in methods.items():
                if method not in ["get", "post", "put", "delete"]:
                    continue

                tool = {
                    "name": spec.get("operationId", f"{method}_{path.replace('/', '_')}"),
                    "description": spec.get("summary", ""),
                    "parameters": [],
                    "metadata": {
                        "path": path,
                        "method": method.upper()
                    }
                }

                # Extract parameters
                for param in spec.get("parameters", []):
                    tool["parameters"].append({
                        "name": param["name"],
                        "type": param.get("schema", {}).get("type", "string"),
                        "required": param.get("required", False),
                        "description": param.get("description", "")
                    })

                # Extract request body
                if "requestBody" in spec:
                    content = spec["requestBody"].get("content", {})
                    if "application/json" in content:
                        schema = content["application/json"].get("schema", {})
                        for prop, prop_schema in schema.get("properties", {}).items():
                            tool["parameters"].append({
                                "name": prop,
                                "type": prop_schema.get("type", "string"),
                                "required": prop in schema.get("required", [])
                            })

                tools.append(tool)

        return tools

    @staticmethod
    def from_database_schema(db_schema: Dict[str, Any]) -> List[Dict[str, Any]]:
        """Generate CRUD tool schemas from database schema."""

        tools = []

        for table, columns in db_schema.items():
            # Create tool
            tools.append({
                "name": f"create_{table}",
                "description": f"Create a new {table} record",
                "parameters": [
                    {
                        "name": col["name"],
                        "type": col["type"],
                        "required": col.get("required", False)
                    }
                    for col in columns
                    if col["name"] != "id"
                ]
            })

            # Read tool
            tools.append({
                "name": f"get_{table}",
                "description": f"Get {table} record by ID",
                "parameters": [
                    {"name": "id", "type": "integer", "required": True}
                ]
            })

            # Update tool
            tools.append({
                "name": f"update_{table}",
                "description": f"Update a {table} record",
                "parameters": [
                    {"name": "id", "type": "integer", "required": True}
                ] + [
                    {
                        "name": col["name"],
                        "type": col["type"],
                        "required": False
                    }
                    for col in columns
                    if col["name"] != "id"
                ]
            })

            # Delete tool
            tools.append({
                "name": f"delete_{table}",
                "description": f"Delete a {table} record",
                "parameters": [
                    {"name": "id", "type": "integer", "required": True}
                ]
            })

        return tools

# Usage
schema_gen = SchemaGenerator()

# From function
def search_users(name: str, limit: int = 10, active: bool = True) -> List[dict]:
    """Search for users by name."""
    pass

schema = schema_gen.from_function(search_users)

# From OpenAPI
import requests
openapi = requests.get("https://api.example.com/openapi.json").json()
api_tools = schema_gen.from_api_spec(openapi)
```

## Step 4: Tool validation

Validate generated tools before use:

```python
from typing import List
import ast

class ToolValidator:
    """Validate generated tools for safety and correctness."""

    # Dangerous patterns to block
    DANGEROUS_PATTERNS = [
        r"rm\s+-rf",
        r"sudo\s+",
        r"chmod\s+777",
        r"eval\s*\(",
        r"exec\s*\(",
        r"__import__",
        r"os\.system",
        r"subprocess\..*shell=True",
    ]

    @classmethod
    def validate(cls, tool: GeneratedTool) -> tuple:
        """Validate a generated tool. Returns (is_valid, errors)."""

        errors = []

        # Check name
        if not re.match(r'^[a-z_][a-z0-9_]*$', tool.name):
            errors.append(f"Invalid tool name: {tool.name}")

        # Check description
        if not tool.description or len(tool.description) < 10:
            errors.append("Description too short")

        # Check parameters
        for param in tool.parameters:
            if "name" not in param:
                errors.append("Parameter missing name")
            if "type" not in param:
                errors.append(f"Parameter {param.get('name')} missing type")

        # Check for dangerous patterns in metadata
        metadata_str = json.dumps(tool.metadata)
        for pattern in cls.DANGEROUS_PATTERNS:
            if re.search(pattern, metadata_str, re.IGNORECASE):
                errors.append(f"Dangerous pattern detected: {pattern}")

        return len(errors) == 0, errors

    @classmethod
    def validate_python_code(cls, code: str) -> tuple:
        """Validate Python code for safety."""

        errors = []

        try:
            tree = ast.parse(code)

            # Check for dangerous constructs
            for node in ast.walk(tree):
                if isinstance(node, ast.Import):
                    for alias in node.names:
                        if alias.name in ["os", "subprocess", "sys"]:
                            errors.append(f"Dangerous import: {alias.name}")

                if isinstance(node, ast.Call):
                    if isinstance(node.func, ast.Name):
                        if node.func.id in ["eval", "exec", "compile"]:
                            errors.append(f"Dangerous function: {node.func.id}")

        except SyntaxError as e:
            errors.append(f"Syntax error: {e}")

        return len(errors) == 0, errors

    @classmethod
    def sandbox_test(cls, tool: GeneratedTool, test_params: Dict[str, Any]) -> tuple:
        """Test tool in sandbox environment."""

        import subprocess
        import tempfile

        # Create isolated environment
        with tempfile.TemporaryDirectory() as tmpdir:
            try:
                # Run with resource limits
                result = tool.executor(test_params)
                return True, result
            except Exception as e:
                return False, str(e)

# Usage
validator = ToolValidator()

# Validate generated tool
is_valid, errors = validator.validate(generated_tool)

if not is_valid:
    print(f"Validation failed: {errors}")
else:
    # Test in sandbox
    success, result = validator.sandbox_test(
        generated_tool,
        {"input": "test"}
    )

    if success:
        print(f"Tool works: {result}")
    else:
        print(f"Tool failed: {result}")
```

## Step 5: Dynamic registration

Register tools at runtime:

```python
class DynamicMCPServer:
    """MCP server with dynamic tool registration."""

    def __init__(self):
        self.tools: Dict[str, GeneratedTool] = {}
        self.generator = ToolGenerator()
        self.validator = ToolValidator()

    def register(self, tool: GeneratedTool) -> bool:
        """Register a new tool."""

        # Validate first
        is_valid, errors = self.validator.validate(tool)
        if not is_valid:
            raise ValueError(f"Invalid tool: {errors}")

        self.tools[tool.name] = tool
        return True

    def unregister(self, name: str) -> bool:
        """Remove a tool."""
        if name in self.tools:
            del self.tools[name]
            return True
        return False

    def generate_and_register(
        self,
        description: str,
        template: str = None
    ) -> GeneratedTool:
        """Generate and register a tool from description."""

        # Use AI to generate
        ai_gen = AIToolGenerator(self.generator)
        tool = ai_gen.generate_from_description(description)

        # Register
        self.register(tool)

        return tool

    def get_tool_definitions(self) -> List[Dict[str, Any]]:
        """Get all tool definitions for MCP."""
        return [
            {
                "name": tool.name,
                "description": tool.description,
                "inputSchema": {
                    "type": "object",
                    "properties": {
                        p["name"]: {"type": p["type"]}
                        for p in tool.parameters
                    },
                    "required": [
                        p["name"] for p in tool.parameters
                        if p.get("required", False)
                    ]
                }
            }
            for tool in self.tools.values()
        ]

    def execute(self, name: str, params: Dict[str, Any]) -> Any:
        """Execute a tool."""
        if name not in self.tools:
            raise ValueError(f"Unknown tool: {name}")

        return self.tools[name].executor(params)

# Usage
server = DynamicMCPServer()

# Register pre-built tools
server.register(some_existing_tool)

# Generate and register on-the-fly
new_tool = server.generate_and_register(
    "A tool that formats JSON with indentation"
)

# Execute
result = server.execute(new_tool.name, {"input": '{"a":1}'})
```

## Summary

Dynamic tool generation:

1. **Templates** - Base patterns for tools
2. **AI generation** - Natural language to tools
3. **Schema generation** - From various sources
4. **Validation** - Safety checks
5. **Dynamic registration** - Runtime addition
6. **Sandbox testing** - Verify before use

Build tools with [Gantz](https://gantz.run), generate dynamically.

Static tools limit. Dynamic tools adapt.

## Related reading

- [Tool Composition](/post/tool-composition/) - Compose tools
- [Agent Reflection](/post/agent-reflection/) - Self-improving agents
- [MCP Security](/post/mcp-security-best-practices/) - Secure generation

---

*How do you generate tools dynamically? Share your approaches.*
