+++
title = "MCP Versioning: Update Tools Without Breaking Agents"
image = "images/mcp-versioning.webp"
date = 2025-11-10
description = "Version your MCP tools safely. Learn semantic versioning, backward compatibility, and migration strategies for AI agent tool updates."
summary = "Update MCP tools safely without breaking existing agents by implementing URL, header, or parameter versioning strategies. This guide covers identifying breaking vs non-breaking changes, building version registries with backward-compatible handlers, gradual rollout with feature flags, deprecation warnings, and testing across multiple versions."
draft = false
tags = ['mcp', 'architecture', 'best-practices']
voice = false

[howto]
name = "Version MCP Tools Safely"
totalTime = 20
[[howto.steps]]
name = "Choose versioning strategy"
text = "Decide between URL versioning, header versioning, or parameter versioning."
[[howto.steps]]
name = "Define compatibility rules"
text = "Establish what changes are breaking vs. non-breaking."
[[howto.steps]]
name = "Implement version handling"
text = "Add version detection and routing to your MCP server."
[[howto.steps]]
name = "Document changes"
text = "Maintain a changelog for each tool version."
[[howto.steps]]
name = "Plan deprecation"
text = "Create a timeline for removing old versions."
+++


You need to change a tool. New parameter. Different output format.

But agents are already using the old version. In production.

How do you update without breaking everything?

Versioning.

## Why version MCP tools?

AI agents learn your tool signatures. They expect:
- Specific parameters
- Specific output formats
- Specific behavior

Change any of these, and the agent breaks:

```python
# Before: Agent learned this
read_file({"path": "config.json"})
# Returns: "file content as string"

# After: You changed it
read_file({"path": "config.json"})
# Returns: {"content": "...", "size": 123, "modified": "..."}

# Agent: "Wait, where's my string?"
```

Versioning lets you update tools while keeping old behavior available.

## Types of changes

### Non-breaking changes

Safe to deploy without version bump:

- Adding optional parameters with defaults
- Adding new fields to output (if agent ignores unknown fields)
- Performance improvements
- Bug fixes that don't change behavior
- Adding new tools

```python
# Before
def read_file(params):
    path = params["path"]
    return open(path).read()

# After - non-breaking (new optional param)
def read_file(params):
    path = params["path"]
    encoding = params.get("encoding", "utf-8")  # Optional with default
    return open(path, encoding=encoding).read()
```

### Breaking changes

Require version bump:

- Removing parameters
- Changing required parameters
- Changing output format
- Changing behavior
- Renaming tools
- Removing tools

```python
# Before - v1
def search_code(params):
    query = params["query"]
    return ["file1.py", "file2.py"]  # List of strings

# After - v2 (BREAKING: different output format)
def search_code(params):
    query = params["query"]
    return [
        {"file": "file1.py", "line": 10, "match": "..."},
        {"file": "file2.py", "line": 25, "match": "..."}
    ]  # List of objects
```

## Versioning strategies

### URL versioning

Version in the URL path:

```
/v1/mcp/tools/call
/v2/mcp/tools/call
```

```python
from flask import Flask, Blueprint

app = Flask(__name__)

# Version 1 tools
v1 = Blueprint('v1', __name__, url_prefix='/v1')

@v1.route('/mcp/tools/call', methods=['POST'])
def call_tool_v1():
    return handle_v1_call(request.json)

# Version 2 tools
v2 = Blueprint('v2', __name__, url_prefix='/v2')

@v2.route('/mcp/tools/call', methods=['POST'])
def call_tool_v2():
    return handle_v2_call(request.json)

app.register_blueprint(v1)
app.register_blueprint(v2)
```

**Pros:**
- Clear and explicit
- Easy to route
- Cacheable

**Cons:**
- Multiple endpoints to maintain
- Client must update URLs

### Header versioning

Version in request header:

```
X-MCP-Version: 2
```

```python
@app.route('/mcp/tools/call', methods=['POST'])
def call_tool():
    version = request.headers.get('X-MCP-Version', '1')

    if version == '1':
        return handle_v1_call(request.json)
    elif version == '2':
        return handle_v2_call(request.json)
    else:
        return jsonify({"error": f"Unknown version: {version}"}), 400
```

**Pros:**
- Single endpoint
- Clean URLs

**Cons:**
- Less discoverable
- Harder to cache

### Parameter versioning

Version in tool parameters:

```python
@app.route('/mcp/tools/call', methods=['POST'])
def call_tool():
    data = request.json
    tool = data.get("tool")
    params = data.get("params", {})
    version = params.pop("_version", "1")

    handler = get_tool_handler(tool, version)
    return jsonify({"result": handler(params)})
```

**Pros:**
- Per-tool versioning
- Flexible

**Cons:**
- Pollutes parameters
- Easy to forget

## Implementation

### Version registry

```python
from typing import Dict, Callable

class ToolRegistry:
    def __init__(self):
        self.tools: Dict[str, Dict[str, Callable]] = {}
        self.latest: Dict[str, str] = {}

    def register(self, name: str, version: str, handler: Callable):
        if name not in self.tools:
            self.tools[name] = {}
        self.tools[name][version] = handler
        self.latest[name] = version

    def get(self, name: str, version: str = None) -> Callable:
        if name not in self.tools:
            raise ValueError(f"Unknown tool: {name}")

        version = version or self.latest[name]

        if version not in self.tools[name]:
            raise ValueError(f"Unknown version {version} for tool {name}")

        return self.tools[name][version]

    def list_tools(self, version: str = None):
        result = []
        for name, versions in self.tools.items():
            v = version or self.latest[name]
            if v in versions:
                result.append({"name": name, "version": v})
        return result

registry = ToolRegistry()

# Register versions
registry.register("read_file", "1", read_file_v1)
registry.register("read_file", "2", read_file_v2)
registry.register("search_code", "1", search_code_v1)
```

### Backward compatible handlers

```python
def read_file_v1(params):
    """Original implementation - returns string."""
    path = params["path"]
    with open(path) as f:
        return f.read()

def read_file_v2(params):
    """New implementation - returns object with metadata."""
    path = params["path"]
    include_metadata = params.get("include_metadata", True)

    with open(path) as f:
        content = f.read()

    if include_metadata:
        stat = os.stat(path)
        return {
            "content": content,
            "size": stat.st_size,
            "modified": stat.st_mtime
        }
    else:
        # Backward compatible mode
        return content
```

### Version negotiation

```python
def negotiate_version(requested: str, available: list) -> str:
    """Find best matching version."""
    if requested in available:
        return requested

    # Try to find compatible version
    requested_major = int(requested.split('.')[0])

    for v in sorted(available, reverse=True):
        v_major = int(v.split('.')[0])
        if v_major == requested_major:
            return v

    # Fall back to latest
    return available[-1]
```

## Migration strategies

### Gradual rollout

```python
import random

class GradualMigration:
    def __init__(self, new_version: str, rollout_percent: int = 0):
        self.new_version = new_version
        self.rollout_percent = rollout_percent

    def should_use_new_version(self, client_id: str) -> bool:
        # Consistent for same client
        hash_value = hash(client_id) % 100
        return hash_value < self.rollout_percent

migration = GradualMigration("2", rollout_percent=10)  # 10% of traffic

@app.route('/mcp/tools/call', methods=['POST'])
def call_tool():
    client_id = get_client_id(request)

    if migration.should_use_new_version(client_id):
        version = migration.new_version
    else:
        version = "1"

    # ... handle with version
```

### Feature flags

```python
FEATURE_FLAGS = {
    "use_v2_search": False,
    "use_v2_read_file": True,
}

def get_tool_version(tool_name: str) -> str:
    flag = f"use_v2_{tool_name}"
    if FEATURE_FLAGS.get(flag, False):
        return "2"
    return "1"
```

### Deprecation warnings

```python
DEPRECATED_VERSIONS = {
    "read_file": {"1": "2025-06-01"},  # v1 deprecated, remove after date
}

def check_deprecation(tool: str, version: str):
    if tool in DEPRECATED_VERSIONS:
        if version in DEPRECATED_VERSIONS[tool]:
            deadline = DEPRECATED_VERSIONS[tool][version]
            logger.warning(
                f"Tool {tool} v{version} is deprecated. "
                f"Please upgrade before {deadline}"
            )
            return {
                "warning": f"Version {version} deprecated",
                "upgrade_by": deadline,
                "latest_version": registry.latest[tool]
            }
    return None

@app.route('/mcp/tools/call', methods=['POST'])
def call_tool():
    # ... get tool and version

    deprecation = check_deprecation(tool, version)
    result = registry.get(tool, version)(params)

    response = {"result": result}
    if deprecation:
        response["deprecation_warning"] = deprecation

    return jsonify(response)
```

## Changelog

Document every change:

```markdown
# MCP Tools Changelog

## read_file

### v2 (2025-01-15)
- **BREAKING**: Returns object instead of string
- Added `size` and `modified` fields
- Added optional `include_metadata` parameter

### v1 (2024-06-01)
- Initial release
- Returns file content as string

## search_code

### v2 (2025-02-01)
- **BREAKING**: Results include line numbers and context
- Added `context_lines` parameter
- Improved performance for large codebases

### v1 (2024-06-01)
- Initial release
- Returns list of matching file paths
```

## Quick setup with Gantz

[Gantz](https://gantz.run) supports tool versioning:

```yaml
# gantz.yaml
name: my-mcp-server
version: "2.0"

tools:
  - name: read_file
    version: "2"
    deprecated_versions: ["1"]
    # ...

  - name: search_code
    version: "1"
    # ...
```

```bash
# Clients can request specific version
gantz run --version 1  # Serve v1 tools
gantz run --version 2  # Serve v2 tools (default)
```

## Best practices

1. **Semantic versioning** - Major.Minor.Patch
2. **Never remove without deprecation** - Warn first, remove later
3. **Default to latest** - New clients get newest version
4. **Document breaking changes** - Be explicit about what changed
5. **Provide migration guides** - Help clients upgrade
6. **Monitor version usage** - Know who's using what
7. **Set deprecation timelines** - Give clear deadlines

## Testing versions

```python
@pytest.mark.parametrize("version", ["1", "2"])
def test_read_file_works_all_versions(version):
    result = registry.get("read_file", version)({"path": "test.txt"})
    # v1 returns string, v2 returns object
    content = result if version == "1" else result["content"]
    assert content == "expected content"
```

## Summary

Versioning MCP tools lets you evolve without breaking:

1. **Identify breaking changes** - Know what requires a new version
2. **Choose a strategy** - URL, header, or parameter versioning
3. **Maintain multiple versions** - Old and new side by side
4. **Deprecate gracefully** - Warn before removing
5. **Document everything** - Changelogs are essential

Your agents depend on stable tools. Versioning gives you flexibility to improve while maintaining that stability.

Change carefully. Version always.

## Related reading

- [MCP Testing Best Practices](/post/mcp-testing/) - Test your versions
- [From Prototype to Production](/post/prototype-to-production/) - Deploy safely
- [Error Recovery Patterns](/post/error-recovery/) - Handle version mismatches

---

*How do you handle versioning in your MCP tools? Share your approach.*
