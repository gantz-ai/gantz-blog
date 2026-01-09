+++
title = "How to Test MCP Tools Before Production"
image = "images/mcp-testing.webp"
date = 2025-11-11
description = "Test MCP tools effectively with unit tests, integration tests, and mock servers. Catch bugs before your AI agents hit production."
summary = "Discover how to thoroughly test MCP tools before deploying them to production where AI agents will use them with unexpected inputs. This guide covers unit testing individual tool functions, integration testing with real dependencies, building mock MCP servers for agent testing, and property-based testing to catch edge cases you never imagined."
draft = false
tags = ['mcp', 'testing', 'best-practices']
voice = false

[howto]
name = "Test MCP Tools Effectively"
totalTime = 30
[[howto.steps]]
name = "Write unit tests for tools"
text = "Test each tool function in isolation with known inputs and outputs."
[[howto.steps]]
name = "Create integration tests"
text = "Test tools with real dependencies like files and databases."
[[howto.steps]]
name = "Build mock MCP server"
text = "Create a test server that simulates tool responses."
[[howto.steps]]
name = "Test error handling"
text = "Verify tools handle invalid inputs and failures gracefully."
[[howto.steps]]
name = "Run end-to-end tests"
text = "Test complete agent workflows with your MCP server."
+++


Your MCP tool works on your machine. You tested it manually. Ship it.

Then your agent uses it in production. With inputs you never imagined.

It breaks.

Testing prevents this.

## Why test MCP tools?

AI agents are creative with tool parameters:

```
You expected: read_file({"path": "config.json"})
Agent sends:  read_file({"path": "../../../etc/passwd"})
```

```
You expected: search_code({"query": "function"})
Agent sends:  search_code({"query": ""})
```

```
You expected: run_command({"cmd": "ls"})
Agent sends:  run_command({"cmd": "rm -rf /"})
```

Testing catches these before production does.

## Testing levels

### Unit tests

Test individual tool functions:

```python
import pytest
from tools import read_file, search_code

class TestReadFile:
    def test_reads_existing_file(self, tmp_path):
        # Create test file
        test_file = tmp_path / "test.txt"
        test_file.write_text("hello world")

        # Test
        result = read_file({"path": str(test_file)})
        assert result == "hello world"

    def test_raises_on_missing_file(self):
        with pytest.raises(FileNotFoundError):
            read_file({"path": "/nonexistent/file.txt"})

    def test_rejects_path_traversal(self):
        with pytest.raises(ValueError, match="path traversal"):
            read_file({"path": "../../../etc/passwd"})

    def test_handles_empty_path(self):
        with pytest.raises(ValueError, match="path required"):
            read_file({"path": ""})

    def test_handles_binary_file(self, tmp_path):
        binary_file = tmp_path / "binary.bin"
        binary_file.write_bytes(b"\x00\x01\x02\x03")

        result = read_file({"path": str(binary_file)})
        assert result is not None  # Should handle gracefully
```

### Integration tests

Test tools with real dependencies:

```python
import subprocess
import pytest

class TestRunCommand:
    def test_executes_simple_command(self):
        result = run_command({"cmd": "echo hello"})
        assert "hello" in result["stdout"]
        assert result["exit_code"] == 0

    def test_captures_stderr(self):
        result = run_command({"cmd": "ls /nonexistent"})
        assert result["exit_code"] != 0
        assert "No such file" in result["stderr"]

    def test_respects_timeout(self):
        result = run_command({"cmd": "sleep 10", "timeout": 1})
        assert result["exit_code"] != 0
        assert "timeout" in result.get("error", "").lower()

    def test_blocks_dangerous_commands(self):
        dangerous_commands = [
            "rm -rf /",
            "mkfs.ext4 /dev/sda",
            ":(){:|:&};:",
            "dd if=/dev/zero of=/dev/sda"
        ]
        for cmd in dangerous_commands:
            with pytest.raises(ValueError, match="blocked"):
                run_command({"cmd": cmd})
```

### End-to-end tests

Test complete MCP server:

```python
import requests
import pytest

@pytest.fixture
def mcp_server():
    """Start MCP server for testing."""
    import subprocess
    import time

    proc = subprocess.Popen(
        ["python", "mcp_server.py", "--port", "8765"],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE
    )
    time.sleep(2)  # Wait for startup

    yield "http://localhost:8765"

    proc.terminate()

class TestMCPServer:
    def test_lists_tools(self, mcp_server):
        response = requests.get(f"{mcp_server}/mcp/tools")
        assert response.status_code == 200

        tools = response.json()
        assert "read_file" in [t["name"] for t in tools]

    def test_calls_tool(self, mcp_server, tmp_path):
        test_file = tmp_path / "test.txt"
        test_file.write_text("test content")

        response = requests.post(
            f"{mcp_server}/mcp/tools/call",
            json={
                "tool": "read_file",
                "params": {"path": str(test_file)}
            }
        )

        assert response.status_code == 200
        assert response.json()["result"] == "test content"

    def test_handles_unknown_tool(self, mcp_server):
        response = requests.post(
            f"{mcp_server}/mcp/tools/call",
            json={"tool": "nonexistent_tool", "params": {}}
        )

        assert response.status_code == 404

    def test_validates_params(self, mcp_server):
        response = requests.post(
            f"{mcp_server}/mcp/tools/call",
            json={"tool": "read_file", "params": {}}  # Missing path
        )

        assert response.status_code == 400
```

## Mock MCP server

Create a mock server for agent testing:

```python
from flask import Flask, jsonify, request

class MockMCPServer:
    def __init__(self):
        self.app = Flask(__name__)
        self.tool_responses = {}
        self.call_history = []
        self._setup_routes()

    def _setup_routes(self):
        @self.app.route("/mcp/tools", methods=["GET"])
        def list_tools():
            return jsonify([
                {"name": name} for name in self.tool_responses.keys()
            ])

        @self.app.route("/mcp/tools/call", methods=["POST"])
        def call_tool():
            data = request.json
            tool = data.get("tool")
            params = data.get("params", {})

            self.call_history.append({"tool": tool, "params": params})

            if tool not in self.tool_responses:
                return jsonify({"error": "Unknown tool"}), 404

            response_fn = self.tool_responses[tool]
            return jsonify({"result": response_fn(params)})

    def mock_tool(self, name, response_fn):
        """Register a mock tool response."""
        self.tool_responses[name] = response_fn

    def get_calls(self, tool_name=None):
        """Get call history, optionally filtered by tool."""
        if tool_name:
            return [c for c in self.call_history if c["tool"] == tool_name]
        return self.call_history

    def reset(self):
        """Clear call history."""
        self.call_history = []

# Usage in tests
@pytest.fixture
def mock_mcp():
    server = MockMCPServer()

    # Mock responses
    server.mock_tool("read_file", lambda p: f"Content of {p['path']}")
    server.mock_tool("search_code", lambda p: [{"file": "test.py", "line": 1}])

    # Run in background
    import threading
    thread = threading.Thread(
        target=lambda: server.app.run(port=8766, use_reloader=False)
    )
    thread.daemon = True
    thread.start()

    yield server

    server.reset()

def test_agent_uses_tools_correctly(mock_mcp):
    agent = Agent(mcp_url="http://localhost:8766")
    agent.run("Find TODO comments in the code")

    # Verify agent called the right tools
    calls = mock_mcp.get_calls("search_code")
    assert len(calls) > 0
    assert "TODO" in calls[0]["params"].get("query", "")
```

## Testing error scenarios

### Input validation errors

```python
@pytest.mark.parametrize("invalid_params,expected_error", [
    ({}, "path required"),
    ({"path": ""}, "path cannot be empty"),
    ({"path": None}, "path must be string"),
    ({"path": 123}, "path must be string"),
    ({"path": "../secret"}, "path traversal"),
])
def test_read_file_validation(invalid_params, expected_error):
    with pytest.raises(ValueError, match=expected_error):
        read_file(invalid_params)
```

### Network errors

```python
def test_handles_network_timeout(mock_mcp):
    mock_mcp.mock_tool("slow_api", lambda p: time.sleep(10))

    with pytest.raises(TimeoutError):
        call_tool_with_timeout("slow_api", {}, timeout=1)
```

### Resource exhaustion

```python
def test_handles_large_file(tmp_path):
    large_file = tmp_path / "large.txt"
    large_file.write_text("x" * 100_000_000)  # 100MB

    result = read_file({"path": str(large_file), "max_size": 1_000_000})
    assert len(result) <= 1_000_000  # Truncated
```

## Fixtures for testing

### Temporary files

```python
@pytest.fixture
def test_files(tmp_path):
    """Create common test files."""
    files = {
        "config.json": '{"debug": true}',
        "main.py": 'def main():\n    print("hello")',
        "empty.txt": "",
        "binary.bin": b"\x00\x01\x02\x03"
    }

    for name, content in files.items():
        path = tmp_path / name
        if isinstance(content, bytes):
            path.write_bytes(content)
        else:
            path.write_text(content)

    return tmp_path
```

### Database fixtures

```python
@pytest.fixture
def test_db():
    """Create test database."""
    import sqlite3

    conn = sqlite3.connect(":memory:")
    cursor = conn.cursor()

    cursor.execute("""
        CREATE TABLE users (
            id INTEGER PRIMARY KEY,
            name TEXT,
            email TEXT
        )
    """)

    cursor.executemany(
        "INSERT INTO users (name, email) VALUES (?, ?)",
        [
            ("Alice", "alice@example.com"),
            ("Bob", "bob@example.com")
        ]
    )
    conn.commit()

    yield conn

    conn.close()
```

## Snapshot testing

Compare tool outputs against known good outputs:

```python
import json
from pathlib import Path

SNAPSHOTS_DIR = Path("tests/snapshots")

def test_search_results_match_snapshot():
    result = search_code({"query": "function", "path": "src/"})

    snapshot_file = SNAPSHOTS_DIR / "search_function.json"

    if not snapshot_file.exists():
        # First run - create snapshot
        snapshot_file.write_text(json.dumps(result, indent=2))
        pytest.skip("Snapshot created")

    expected = json.loads(snapshot_file.read_text())
    assert result == expected
```

## Property-based testing

Test with generated inputs:

```python
from hypothesis import given, strategies as st

@given(st.text())
def test_search_handles_any_query(query):
    """Search should handle any string without crashing."""
    try:
        result = search_code({"query": query, "path": "."})
        assert isinstance(result, list)
    except ValueError:
        pass  # Invalid query is acceptable

@given(st.binary())
def test_read_handles_any_file_content(content, tmp_path):
    """Read should handle any file content."""
    test_file = tmp_path / "test.bin"
    test_file.write_bytes(content)

    result = read_file({"path": str(test_file)})
    assert result is not None
```

## CI/CD integration

Run tests automatically:

```yaml
# .github/workflows/test.yml
name: Test MCP Tools

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.11'

      - name: Install dependencies
        run: pip install -r requirements.txt -r requirements-test.txt

      - name: Run unit tests
        run: pytest tests/unit -v

      - name: Run integration tests
        run: pytest tests/integration -v

      - name: Run e2e tests
        run: pytest tests/e2e -v
```

## Quick setup with Gantz

[Gantz](https://gantz.run) includes testing utilities:

```yaml
# gantz.yaml
name: my-mcp-server

tools:
  - name: read_file
    test:
      - input: {"path": "test.txt"}
        expect: {"contains": "content"}
      - input: {"path": ""}
        expect: {"error": "path required"}
```

```bash
# Run tool tests
gantz test

# Output:
# ✓ read_file: 2/2 tests passed
# ✓ search_code: 3/3 tests passed
```

## Best practices

1. **Test edge cases** - Empty inputs, huge inputs, special characters
2. **Test error paths** - What happens when things fail?
3. **Use fixtures** - Don't create test data manually each time
4. **Mock external services** - Don't hit real APIs in tests
5. **Run tests in CI** - Catch regressions automatically
6. **Test security** - Path traversal, injection, etc.
7. **Snapshot test outputs** - Detect unexpected changes

## Summary

Testing MCP tools prevents production surprises:

- **Unit tests** catch logic errors
- **Integration tests** verify real dependencies
- **E2E tests** validate complete workflows
- **Mock servers** enable agent testing
- **Property tests** find edge cases you didn't imagine

Your agent will send inputs you never expected. Tests ensure your tools handle them gracefully.

Test before deploy. Always.

## Related reading

- [Error Recovery Patterns](/post/error-recovery/) - Handle failures

---

*What's your MCP testing strategy? Share your approach.*
