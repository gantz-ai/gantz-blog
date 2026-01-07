+++
title = "Secure MCP Tool Execution: Prevent Command Injection"
image = "images/secure-tool-execution.webp"
date = 2025-11-16
description = "Execute MCP tools securely. Prevent command injection, validate inputs, use parameterized execution, and audit all tool calls for AI agent safety."
draft = false
tags = ['mcp', 'security', 'tools']
voice = false

[howto]
name = "Execute Tools Securely"
totalTime = 35
[[howto.steps]]
name = "Validate all inputs"
text = "Sanitize and validate parameters before execution."
[[howto.steps]]
name = "Use parameterized execution"
text = "Avoid string interpolation in commands."
[[howto.steps]]
name = "Implement allowlists"
text = "Restrict commands to approved patterns."
[[howto.steps]]
name = "Add execution wrappers"
text = "Wrap tool execution with security checks."
[[howto.steps]]
name = "Audit all executions"
text = "Log every tool call for security review."
+++


AI agents call tools. Tools execute commands.

One unvalidated input = command injection.

Here's how to execute tools securely.

## The injection threat

Consider this tool:

```yaml
tools:
  - name: search_files
    script:
      shell: grep "{{query}}" /data/*.txt
```

What if query is `"; rm -rf / #`?

```bash
grep ""; rm -rf / #" /data/*.txt
```

Catastrophe.

## Step 1: Input validation

Using [Gantz](https://gantz.run) with validation:

```yaml
# gantz.yaml
name: secure-tools

tools:
  - name: search_files
    description: Search for text in files
    parameters:
      - name: query
        type: string
        required: true
        validation:
          pattern: "^[a-zA-Z0-9\\s\\-_]+$"
          max_length: 100
      - name: directory
        type: string
        default: "/data"
        validation:
          allowed_values:
            - "/data"
            - "/logs"
            - "/config"
    script:
      shell: grep -r "{{query}}" "{{directory}}"
```

Comprehensive input validator:

```python
import re
from typing import Any, Dict, List, Optional
from dataclasses import dataclass

@dataclass
class ValidationRule:
    """Validation rule definition."""
    pattern: Optional[str] = None
    max_length: Optional[int] = None
    min_length: Optional[int] = None
    allowed_values: Optional[List[str]] = None
    denied_patterns: Optional[List[str]] = None

class InputValidator:
    """Validate tool inputs for security."""

    # Dangerous patterns to always block
    DANGEROUS_PATTERNS = [
        r'[;&|`$]',           # Shell operators
        r'\$\(',              # Command substitution
        r'`',                 # Backtick execution
        r'\.\.',              # Path traversal
        r'[<>]',              # Redirections
        r'\n|\r',             # Newlines
        r'\\x[0-9a-fA-F]{2}', # Hex escapes
        r'%[0-9a-fA-F]{2}',   # URL encoding
    ]

    @classmethod
    def validate(cls, value: Any, rules: ValidationRule) -> str:
        """Validate and sanitize input."""

        # Convert to string
        if not isinstance(value, str):
            value = str(value)

        # Always check dangerous patterns
        for pattern in cls.DANGEROUS_PATTERNS:
            if re.search(pattern, value):
                raise ValueError(f"Input contains dangerous pattern: {pattern}")

        # Check length
        if rules.max_length and len(value) > rules.max_length:
            raise ValueError(f"Input too long: {len(value)} > {rules.max_length}")

        if rules.min_length and len(value) < rules.min_length:
            raise ValueError(f"Input too short: {len(value)} < {rules.min_length}")

        # Check pattern
        if rules.pattern:
            if not re.match(rules.pattern, value):
                raise ValueError(f"Input doesn't match pattern: {rules.pattern}")

        # Check allowed values
        if rules.allowed_values:
            if value not in rules.allowed_values:
                raise ValueError(f"Value not in allowed list: {rules.allowed_values}")

        # Check denied patterns
        if rules.denied_patterns:
            for pattern in rules.denied_patterns:
                if re.search(pattern, value):
                    raise ValueError(f"Input matches denied pattern: {pattern}")

        return value

    @classmethod
    def sanitize_shell_arg(cls, value: str) -> str:
        """Sanitize value for shell execution."""
        import shlex

        # First validate
        cls.validate(value, ValidationRule(max_length=1000))

        # Then quote properly
        return shlex.quote(value)

    @classmethod
    def sanitize_sql_value(cls, value: str) -> str:
        """Sanitize value for SQL (use with parameterized queries!)."""

        # Block SQL injection patterns
        sql_patterns = [
            r"'",
            r"--",
            r";",
            r"/\*",
            r"\*/",
            r"union\s+select",
            r"drop\s+table",
            r"delete\s+from",
            r"insert\s+into",
            r"update\s+.*\s+set",
        ]

        for pattern in sql_patterns:
            if re.search(pattern, value, re.IGNORECASE):
                raise ValueError(f"Potential SQL injection: {pattern}")

        return value

    @classmethod
    def sanitize_path(cls, value: str, base_dir: str) -> str:
        """Sanitize file path."""
        import os

        # Basic validation
        cls.validate(value, ValidationRule(max_length=256))

        # Normalize and resolve
        normalized = os.path.normpath(value)
        full_path = os.path.join(base_dir, normalized)
        resolved = os.path.realpath(full_path)

        # Ensure within base directory
        if not resolved.startswith(os.path.realpath(base_dir)):
            raise ValueError("Path traversal attempt detected")

        return resolved

# Usage
validator = InputValidator()

# Validate search query
query = validator.validate(
    user_input,
    ValidationRule(
        pattern=r"^[a-zA-Z0-9\s\-_]+$",
        max_length=100
    )
)

# Sanitize for shell
safe_query = validator.sanitize_shell_arg(query)
```

## Step 2: Parameterized execution

Never interpolate user input into commands:

```python
import subprocess
from typing import List, Dict, Any

class SecureExecutor:
    """Execute commands securely without string interpolation."""

    @staticmethod
    def execute_grep(pattern: str, path: str, options: List[str] = None) -> str:
        """Secure grep execution."""

        # Validate inputs
        if not pattern or not path:
            raise ValueError("Pattern and path required")

        # Build command as list (no shell=True)
        cmd = ["grep"]

        if options:
            for opt in options:
                if opt in ["-r", "-i", "-l", "-n", "-c"]:  # Allowlist options
                    cmd.append(opt)

        cmd.extend(["--", pattern, path])  # -- prevents option injection

        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=30
        )

        return result.stdout

    @staticmethod
    def execute_find(path: str, name: str, file_type: str = "f") -> str:
        """Secure find execution."""

        if file_type not in ["f", "d", "l"]:
            raise ValueError("Invalid file type")

        cmd = [
            "find", path,
            "-type", file_type,
            "-name", name,
            "-print"
        ]

        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=30
        )

        return result.stdout

    @staticmethod
    def execute_sql(query: str, params: tuple, db_url: str) -> List[Dict]:
        """Secure SQL execution with parameterization."""
        import psycopg2

        # Only allow SELECT queries
        if not query.strip().upper().startswith("SELECT"):
            raise ValueError("Only SELECT queries allowed")

        conn = psycopg2.connect(db_url)
        try:
            cursor = conn.cursor()
            cursor.execute(query, params)  # Parameterized!
            columns = [desc[0] for desc in cursor.description]
            return [dict(zip(columns, row)) for row in cursor.fetchall()]
        finally:
            conn.close()

# Usage
executor = SecureExecutor()

# Safe grep - user input is never interpolated into shell
results = executor.execute_grep(
    pattern=user_query,  # Passed as argument, not in shell string
    path="/data",
    options=["-r", "-i"]
)

# Safe SQL - parameterized query
results = executor.execute_sql(
    query="SELECT * FROM users WHERE name = %s",
    params=(user_name,),  # Parameterized!
    db_url=DATABASE_URL
)
```

## Step 3: Command allowlisting

Only allow approved commands:

```python
from typing import Set, Dict, Any, Callable
from dataclasses import dataclass

@dataclass
class AllowedCommand:
    """Definition of an allowed command."""
    name: str
    command: str
    allowed_args: Set[str]
    validator: Callable[[Dict[str, Any]], bool] = None

class CommandAllowlist:
    """Allowlist of permitted commands."""

    def __init__(self):
        self.commands: Dict[str, AllowedCommand] = {}

    def register(self, cmd: AllowedCommand):
        """Register an allowed command."""
        self.commands[cmd.name] = cmd

    def is_allowed(self, name: str, args: Dict[str, Any]) -> bool:
        """Check if command and args are allowed."""

        if name not in self.commands:
            return False

        cmd = self.commands[name]

        # Check args are in allowlist
        for arg in args:
            if arg not in cmd.allowed_args:
                return False

        # Run custom validator if exists
        if cmd.validator and not cmd.validator(args):
            return False

        return True

    def execute(self, name: str, args: Dict[str, Any]) -> str:
        """Execute allowed command."""

        if not self.is_allowed(name, args):
            raise PermissionError(f"Command not allowed: {name}")

        cmd = self.commands[name]
        return self._run_command(cmd, args)

    def _run_command(self, cmd: AllowedCommand, args: Dict[str, Any]) -> str:
        """Run the actual command."""
        import subprocess

        # Build command with validated args
        command_parts = [cmd.command]

        for key, value in args.items():
            if key in cmd.allowed_args:
                command_parts.extend([f"--{key}", str(value)])

        result = subprocess.run(
            command_parts,
            capture_output=True,
            text=True,
            timeout=30
        )

        return result.stdout

# Setup allowlist
allowlist = CommandAllowlist()

# Register allowed commands
allowlist.register(AllowedCommand(
    name="search",
    command="grep",
    allowed_args={"pattern", "path", "recursive", "case_insensitive"},
    validator=lambda args: len(args.get("pattern", "")) < 100
))

allowlist.register(AllowedCommand(
    name="list_files",
    command="ls",
    allowed_args={"path", "all", "long"},
    validator=lambda args: not ".." in args.get("path", "")
))

# Usage
try:
    result = allowlist.execute("search", {
        "pattern": "error",
        "path": "/logs",
        "recursive": True
    })
except PermissionError:
    print("Command not allowed")
```

## Step 4: Execution wrappers

Wrap all tool execution with security:

```python
import time
import uuid
from functools import wraps
from typing import Callable, Any
from contextlib import contextmanager

class SecureToolWrapper:
    """Wrap tool execution with security controls."""

    def __init__(self, validator: InputValidator, allowlist: CommandAllowlist):
        self.validator = validator
        self.allowlist = allowlist
        self.audit_log = []

    def wrap(self, tool_name: str, allowed_params: Dict[str, ValidationRule]):
        """Decorator to wrap tool functions."""

        def decorator(func: Callable) -> Callable:
            @wraps(func)
            def wrapper(**kwargs) -> Any:
                execution_id = str(uuid.uuid4())

                try:
                    # Validate all parameters
                    validated = {}
                    for param, value in kwargs.items():
                        if param in allowed_params:
                            validated[param] = self.validator.validate(
                                value,
                                allowed_params[param]
                            )
                        else:
                            raise ValueError(f"Unknown parameter: {param}")

                    # Log execution start
                    self._log_execution(
                        execution_id, tool_name,
                        validated, "started"
                    )

                    # Execute with timeout
                    with self._timeout(30):
                        result = func(**validated)

                    # Log success
                    self._log_execution(
                        execution_id, tool_name,
                        validated, "completed",
                        result_size=len(str(result))
                    )

                    return result

                except Exception as e:
                    # Log failure
                    self._log_execution(
                        execution_id, tool_name,
                        kwargs, "failed",
                        error=str(e)
                    )
                    raise

            return wrapper
        return decorator

    @contextmanager
    def _timeout(self, seconds: int):
        """Timeout context manager."""
        import signal

        def handler(signum, frame):
            raise TimeoutError(f"Execution timed out after {seconds}s")

        old = signal.signal(signal.SIGALRM, handler)
        signal.alarm(seconds)

        try:
            yield
        finally:
            signal.alarm(0)
            signal.signal(signal.SIGALRM, old)

    def _log_execution(self, exec_id: str, tool: str,
                       params: dict, status: str, **extra):
        """Log tool execution."""
        entry = {
            "id": exec_id,
            "tool": tool,
            "params": {k: "***" if "secret" in k.lower() else v
                      for k, v in params.items()},
            "status": status,
            "timestamp": time.time(),
            **extra
        }
        self.audit_log.append(entry)

        # Also log to external system
        import logging
        logging.info(f"Tool execution: {entry}")

# Usage
wrapper = SecureToolWrapper(InputValidator(), CommandAllowlist())

@wrapper.wrap("search_files", {
    "query": ValidationRule(pattern=r"^[a-zA-Z0-9\s]+$", max_length=100),
    "path": ValidationRule(allowed_values=["/data", "/logs"])
})
def search_files(query: str, path: str) -> str:
    """Search files securely."""
    import subprocess
    result = subprocess.run(
        ["grep", "-r", query, path],
        capture_output=True,
        text=True
    )
    return result.stdout
```

## Step 5: Audit logging

Log all tool executions:

```python
import json
import time
import hashlib
from typing import Dict, Any, Optional
from dataclasses import dataclass, asdict

@dataclass
class AuditEntry:
    """Audit log entry."""
    timestamp: float
    execution_id: str
    tool_name: str
    user_id: str
    parameters: Dict[str, Any]
    status: str
    duration_ms: Optional[float] = None
    error: Optional[str] = None
    result_hash: Optional[str] = None
    ip_address: Optional[str] = None
    user_agent: Optional[str] = None

class SecurityAuditLog:
    """Audit log for tool executions."""

    def __init__(self, log_path: str = "/var/log/tool-audit.jsonl"):
        self.log_path = log_path

    def log(self, entry: AuditEntry):
        """Log audit entry."""

        # Write to file
        with open(self.log_path, "a") as f:
            f.write(json.dumps(asdict(entry)) + "\n")

        # Also send to SIEM
        self._send_to_siem(entry)

        # Alert on suspicious activity
        self._check_alerts(entry)

    def _send_to_siem(self, entry: AuditEntry):
        """Send to SIEM system."""
        # Implement integration with your SIEM
        pass

    def _check_alerts(self, entry: AuditEntry):
        """Check for suspicious patterns."""

        if entry.status == "failed":
            if "injection" in entry.error.lower():
                self._alert("Possible injection attempt", entry)

        if self._is_rate_exceeded(entry.user_id):
            self._alert("Rate limit exceeded", entry)

    def _is_rate_exceeded(self, user_id: str) -> bool:
        """Check if user is exceeding rate limits."""
        # Implement rate checking
        return False

    def _alert(self, message: str, entry: AuditEntry):
        """Send security alert."""
        import logging
        logging.critical(f"SECURITY ALERT: {message}", extra=asdict(entry))

class AuditedToolExecutor:
    """Execute tools with full audit logging."""

    def __init__(self, audit: SecurityAuditLog):
        self.audit = audit

    def execute(
        self,
        tool_name: str,
        params: Dict[str, Any],
        user_id: str,
        request_context: Dict[str, Any] = None
    ) -> Any:
        """Execute tool with audit logging."""

        import uuid
        execution_id = str(uuid.uuid4())
        start_time = time.time()

        entry = AuditEntry(
            timestamp=start_time,
            execution_id=execution_id,
            tool_name=tool_name,
            user_id=user_id,
            parameters=self._sanitize_params(params),
            status="started",
            ip_address=request_context.get("ip") if request_context else None,
            user_agent=request_context.get("user_agent") if request_context else None
        )

        self.audit.log(entry)

        try:
            result = self._execute_tool(tool_name, params)

            entry.status = "completed"
            entry.duration_ms = (time.time() - start_time) * 1000
            entry.result_hash = hashlib.sha256(str(result).encode()).hexdigest()

            self.audit.log(entry)
            return result

        except Exception as e:
            entry.status = "failed"
            entry.duration_ms = (time.time() - start_time) * 1000
            entry.error = str(e)

            self.audit.log(entry)
            raise

    def _sanitize_params(self, params: Dict[str, Any]) -> Dict[str, Any]:
        """Sanitize parameters for logging."""
        return {
            k: "***" if any(s in k.lower() for s in ["password", "secret", "key", "token"])
            else v
            for k, v in params.items()
        }

    def _execute_tool(self, name: str, params: dict) -> Any:
        """Actually execute the tool."""
        # Implementation
        pass

# Usage
audit = SecurityAuditLog()
executor = AuditedToolExecutor(audit)

result = executor.execute(
    tool_name="search_files",
    params={"query": "error", "path": "/logs"},
    user_id="user123",
    request_context={"ip": "192.168.1.1"}
)
```

## Step 6: Defense in depth

Combine all layers:

```python
class SecureMCPToolExecutor:
    """Complete secure tool execution pipeline."""

    def __init__(self):
        self.validator = InputValidator()
        self.allowlist = CommandAllowlist()
        self.audit = SecurityAuditLog()
        self.wrapper = SecureToolWrapper(self.validator, self.allowlist)

        # Setup allowed commands
        self._setup_allowlist()

    def _setup_allowlist(self):
        """Configure allowed commands."""
        self.allowlist.register(AllowedCommand(
            name="grep",
            command="grep",
            allowed_args={"pattern", "path", "recursive"},
            validator=self._validate_grep
        ))

    def _validate_grep(self, args: dict) -> bool:
        """Validate grep arguments."""
        pattern = args.get("pattern", "")
        path = args.get("path", "")

        # Check pattern
        if len(pattern) > 100:
            return False

        # Check path
        allowed_paths = ["/data", "/logs", "/config"]
        if not any(path.startswith(p) for p in allowed_paths):
            return False

        return True

    def execute(
        self,
        tool_name: str,
        params: Dict[str, Any],
        user_id: str,
        context: Dict[str, Any] = None
    ) -> Any:
        """Execute tool through complete security pipeline."""

        # 1. Validate inputs
        validated_params = {}
        for key, value in params.items():
            validated_params[key] = self.validator.validate(
                value,
                ValidationRule(max_length=1000)
            )

        # 2. Check allowlist
        if not self.allowlist.is_allowed(tool_name, validated_params):
            raise PermissionError(f"Tool or params not allowed: {tool_name}")

        # 3. Execute with auditing
        return AuditedToolExecutor(self.audit).execute(
            tool_name,
            validated_params,
            user_id,
            context
        )

# Gantz integration
executor = SecureMCPToolExecutor()
```

## Summary

Secure tool execution:

1. **Validate inputs** - Block dangerous patterns
2. **Parameterize commands** - Never interpolate
3. **Allowlist commands** - Only approved operations
4. **Wrap execution** - Add security controls
5. **Audit everything** - Log all executions
6. **Defense in depth** - Layer security

Build tools with [Gantz](https://gantz.run), execute securely.

One injection = game over. Prevent it.

## Related reading

- [MCP Security](/post/mcp-security-best-practices/) - Security fundamentals
- [Agent Sandboxing](/post/agent-sandboxing/) - Isolate execution
- [Agent Audit Logging](/post/agent-audit-logging/) - Complete audit trails

---

*How do you secure tool execution? Share your approaches.*
