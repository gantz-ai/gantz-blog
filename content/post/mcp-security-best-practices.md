+++
title = "MCP Security Best Practices: Protect Your AI Tools"
image = "/images/mcp-security-best-practices.png"
date = 2025-11-20
description = "Secure your MCP tools with authentication, authorization, input validation, and secrets management. Complete security guide for AI agent deployments."
draft = false
tags = ['mcp', 'security', 'best-practices']
voice = false

[howto]
name = "Secure MCP Tools"
totalTime = 40
[[howto.steps]]
name = "Implement authentication"
text = "Add token-based authentication to MCP servers."
[[howto.steps]]
name = "Add authorization"
text = "Control which tools users can access."
[[howto.steps]]
name = "Validate inputs"
text = "Sanitize all tool inputs to prevent injection."
[[howto.steps]]
name = "Manage secrets"
text = "Store and access secrets securely."
[[howto.steps]]
name = "Enable audit logging"
text = "Log all tool executions for security monitoring."
+++


AI tools execute code. Code can be dangerous.

MCP gives AI agents real power. That power needs protection.

Here's how to secure your MCP deployments.

## Why MCP security matters

MCP tools can:
- Execute shell commands
- Access databases
- Read/write files
- Make API calls
- Modify infrastructure

One vulnerability = complete system compromise.

## Threat model

Understand what you're protecting against:

| Threat | Description | Impact |
|--------|-------------|--------|
| Prompt injection | Malicious input tricks AI into misusing tools | Command execution |
| Token theft | Stolen API keys/tokens | Unauthorized access |
| Input injection | Unvalidated input leads to command/SQL injection | Data breach |
| Privilege escalation | Tools have more access than needed | System compromise |
| Data exfiltration | Sensitive data exposed through tool outputs | Privacy violation |

## Step 1: Authentication

Using [Gantz](https://gantz.run):

```yaml
# gantz.yaml
name: secure-tools

# Authentication configuration
auth:
  type: token
  tokens:
    - name: production
      value: ${GANTZ_AUTH_TOKEN}
      permissions: ["read", "write"]
    - name: readonly
      value: ${GANTZ_READONLY_TOKEN}
      permissions: ["read"]

tools:
  - name: secure_query
    description: Query with authentication required
    parameters:
      - name: query
        type: string
        required: true
    script:
      shell: echo "Authenticated query: {{query}}"
```

Token validation middleware:

```python
import hashlib
import hmac
import time
from functools import wraps
from flask import request, jsonify

class TokenValidator:
    """Validate MCP authentication tokens."""

    def __init__(self, secret_key: str):
        self.secret_key = secret_key
        self.tokens = {}  # token_hash -> permissions

    def add_token(self, token: str, permissions: list):
        """Add a valid token."""
        token_hash = self._hash_token(token)
        self.tokens[token_hash] = {
            "permissions": permissions,
            "created_at": time.time()
        }

    def _hash_token(self, token: str) -> str:
        """Hash token for storage."""
        return hashlib.sha256(
            f"{self.secret_key}{token}".encode()
        ).hexdigest()

    def validate(self, token: str) -> dict:
        """Validate token and return permissions."""
        if not token:
            return None

        token_hash = self._hash_token(token)
        return self.tokens.get(token_hash)

    def has_permission(self, token: str, permission: str) -> bool:
        """Check if token has specific permission."""
        token_data = self.validate(token)
        if not token_data:
            return False
        return permission in token_data["permissions"]

# Flask decorator
def require_auth(permission: str = None):
    def decorator(f):
        @wraps(f)
        def wrapper(*args, **kwargs):
            token = request.headers.get("Authorization", "").replace("Bearer ", "")

            if not validator.validate(token):
                return jsonify({"error": "Unauthorized"}), 401

            if permission and not validator.has_permission(token, permission):
                return jsonify({"error": "Forbidden"}), 403

            return f(*args, **kwargs)
        return wrapper
    return decorator

validator = TokenValidator(os.environ["SECRET_KEY"])
```

## Step 2: Authorization

Role-based access control for tools:

```yaml
# gantz.yaml
name: rbac-tools

# Define roles
roles:
  admin:
    tools: ["*"]  # All tools
  developer:
    tools: ["query_logs", "deploy_staging", "run_tests"]
  viewer:
    tools: ["query_logs", "get_status"]

tools:
  - name: query_logs
    description: Query application logs
    role: viewer  # Minimum role required
    parameters:
      - name: query
        type: string
        required: true
    script:
      shell: grep "{{query}}" /var/log/app.log | tail -100

  - name: deploy_staging
    description: Deploy to staging environment
    role: developer
    script:
      shell: ./deploy.sh staging

  - name: deploy_production
    description: Deploy to production environment
    role: admin
    script:
      shell: ./deploy.sh production
```

Authorization implementation:

```python
from typing import Dict, List, Set

class RBACAuthorizer:
    """Role-based access control for MCP tools."""

    def __init__(self):
        self.roles: Dict[str, Set[str]] = {}
        self.user_roles: Dict[str, str] = {}
        self.tool_requirements: Dict[str, str] = {}

        # Role hierarchy (higher roles inherit lower)
        self.hierarchy = ["viewer", "developer", "admin"]

    def define_role(self, role: str, tools: List[str]):
        """Define tools accessible by a role."""
        self.roles[role] = set(tools)

    def assign_role(self, user_id: str, role: str):
        """Assign role to user."""
        if role not in self.roles and role not in self.hierarchy:
            raise ValueError(f"Unknown role: {role}")
        self.user_roles[user_id] = role

    def set_tool_requirement(self, tool: str, min_role: str):
        """Set minimum role required for a tool."""
        self.tool_requirements[tool] = min_role

    def can_use_tool(self, user_id: str, tool: str) -> bool:
        """Check if user can use a tool."""
        user_role = self.user_roles.get(user_id)
        if not user_role:
            return False

        # Check tool-specific requirement
        required_role = self.tool_requirements.get(tool, "viewer")

        # Compare role hierarchy
        user_level = self._role_level(user_role)
        required_level = self._role_level(required_role)

        if user_level < required_level:
            return False

        # Check explicit tool permissions
        if "*" in self.roles.get(user_role, set()):
            return True

        return tool in self.roles.get(user_role, set())

    def _role_level(self, role: str) -> int:
        """Get numeric level for role."""
        try:
            return self.hierarchy.index(role)
        except ValueError:
            return -1

    def get_allowed_tools(self, user_id: str) -> List[str]:
        """Get list of tools user can access."""
        user_role = self.user_roles.get(user_id)
        if not user_role:
            return []

        # Collect tools from role and inherited roles
        allowed = set()
        user_level = self._role_level(user_role)

        for level, role in enumerate(self.hierarchy):
            if level <= user_level:
                allowed.update(self.roles.get(role, set()))

        return list(allowed)

# Usage
authorizer = RBACAuthorizer()
authorizer.define_role("viewer", ["query_logs", "get_status"])
authorizer.define_role("developer", ["deploy_staging", "run_tests"])
authorizer.define_role("admin", ["*"])

authorizer.assign_role("user123", "developer")
print(authorizer.can_use_tool("user123", "deploy_staging"))  # True
print(authorizer.can_use_tool("user123", "deploy_production"))  # False
```

## Step 3: Input validation

Prevent injection attacks:

```python
import re
import shlex
from typing import Any, Dict, List

class InputValidator:
    """Validate and sanitize tool inputs."""

    # Dangerous patterns
    SHELL_INJECTION = re.compile(r'[;&|`$(){}[\]<>]')
    SQL_INJECTION = re.compile(r"('|--|;|/\*|\*/|xp_|exec|execute|insert|select|delete|update|drop|create|alter)", re.IGNORECASE)
    PATH_TRAVERSAL = re.compile(r'\.\.')

    @classmethod
    def validate_string(cls, value: str, max_length: int = 1000) -> str:
        """Validate string input."""
        if not isinstance(value, str):
            raise ValueError("Expected string")

        if len(value) > max_length:
            raise ValueError(f"Input too long (max {max_length})")

        return value

    @classmethod
    def sanitize_shell_arg(cls, value: str) -> str:
        """Sanitize input for shell commands."""
        value = cls.validate_string(value, max_length=500)

        # Check for injection patterns
        if cls.SHELL_INJECTION.search(value):
            raise ValueError("Invalid characters in input")

        # Use shlex for proper escaping
        return shlex.quote(value)

    @classmethod
    def sanitize_sql_param(cls, value: str) -> str:
        """Sanitize input for SQL queries."""
        value = cls.validate_string(value)

        # Check for SQL injection patterns
        if cls.SQL_INJECTION.search(value):
            raise ValueError("Invalid SQL characters")

        return value

    @classmethod
    def sanitize_path(cls, value: str, base_dir: str = None) -> str:
        """Sanitize file path."""
        value = cls.validate_string(value, max_length=256)

        # Prevent path traversal
        if cls.PATH_TRAVERSAL.search(value):
            raise ValueError("Path traversal not allowed")

        # Normalize path
        import os
        normalized = os.path.normpath(value)

        # If base directory specified, ensure path is within it
        if base_dir:
            full_path = os.path.join(base_dir, normalized)
            if not full_path.startswith(os.path.abspath(base_dir)):
                raise ValueError("Path outside allowed directory")

        return normalized

    @classmethod
    def validate_parameters(cls, params: Dict[str, Any], schema: List[Dict]) -> Dict[str, Any]:
        """Validate parameters against schema."""
        validated = {}

        for param_def in schema:
            name = param_def["name"]
            param_type = param_def.get("type", "string")
            required = param_def.get("required", False)

            value = params.get(name)

            # Check required
            if required and value is None:
                raise ValueError(f"Missing required parameter: {name}")

            if value is None:
                validated[name] = param_def.get("default")
                continue

            # Type validation
            if param_type == "string":
                validated[name] = cls.validate_string(value)
            elif param_type == "integer":
                validated[name] = int(value)
            elif param_type == "boolean":
                validated[name] = bool(value)
            elif param_type == "shell_safe":
                validated[name] = cls.sanitize_shell_arg(value)
            elif param_type == "path":
                validated[name] = cls.sanitize_path(
                    value,
                    param_def.get("base_dir")
                )
            else:
                validated[name] = value

        return validated

# Usage in tool execution
def execute_tool(tool_name: str, params: dict, schema: list):
    """Execute tool with validated parameters."""
    try:
        validated = InputValidator.validate_parameters(params, schema)
        # Execute with validated params
        return run_tool(tool_name, validated)
    except ValueError as e:
        return {"error": str(e)}
```

Gantz configuration with validation:

```yaml
# gantz.yaml
name: validated-tools

tools:
  - name: search_files
    description: Search files in allowed directory
    parameters:
      - name: query
        type: string
        required: true
        validation:
          max_length: 100
          pattern: "^[a-zA-Z0-9_\\-\\s]+$"
      - name: directory
        type: string
        default: "/app/data"
        validation:
          allowed_values:
            - "/app/data"
            - "/app/logs"
            - "/app/config"
    script:
      shell: grep -r "{{query}}" "{{directory}}"

  - name: run_query
    description: Run a read-only database query
    parameters:
      - name: table
        type: string
        required: true
        validation:
          allowed_values:
            - "users"
            - "orders"
            - "products"
      - name: limit
        type: integer
        default: 10
        validation:
          min: 1
          max: 100
    script:
      shell: psql "$DATABASE_URL" -c "SELECT * FROM {{table}} LIMIT {{limit}}"
```

## Step 4: Secrets management

Never hardcode secrets:

```yaml
# gantz.yaml
name: secrets-example

# Secrets loaded from environment
secrets:
  - name: DATABASE_URL
    env: DATABASE_URL
  - name: API_KEY
    env: EXTERNAL_API_KEY
  - name: ENCRYPTION_KEY
    env: ENCRYPTION_KEY

tools:
  - name: query_database
    description: Query the database
    parameters:
      - name: query
        type: string
        required: true
    script:
      # Secret referenced but never exposed
      shell: psql "$DATABASE_URL" -c "{{query}}"

  - name: call_api
    description: Call external API
    parameters:
      - name: endpoint
        type: string
        required: true
    script:
      shell: curl -H "Authorization: Bearer $API_KEY" "{{endpoint}}"
```

Secrets manager integration:

```python
import os
from abc import ABC, abstractmethod
from typing import Optional

class SecretsManager(ABC):
    """Abstract secrets manager."""

    @abstractmethod
    def get_secret(self, name: str) -> Optional[str]:
        pass

class EnvironmentSecrets(SecretsManager):
    """Load secrets from environment variables."""

    def __init__(self, prefix: str = ""):
        self.prefix = prefix

    def get_secret(self, name: str) -> Optional[str]:
        return os.environ.get(f"{self.prefix}{name}")

class AWSSecretsManager(SecretsManager):
    """Load secrets from AWS Secrets Manager."""

    def __init__(self, region: str = "us-east-1"):
        import boto3
        self.client = boto3.client('secretsmanager', region_name=region)
        self._cache = {}

    def get_secret(self, name: str) -> Optional[str]:
        if name in self._cache:
            return self._cache[name]

        try:
            response = self.client.get_secret_value(SecretId=name)
            secret = response['SecretString']
            self._cache[name] = secret
            return secret
        except Exception:
            return None

class VaultSecretsManager(SecretsManager):
    """Load secrets from HashiCorp Vault."""

    def __init__(self, url: str, token: str):
        import hvac
        self.client = hvac.Client(url=url, token=token)

    def get_secret(self, name: str) -> Optional[str]:
        try:
            secret = self.client.secrets.kv.read_secret_version(path=name)
            return secret['data']['data'].get('value')
        except Exception:
            return None

class SecureToolExecutor:
    """Execute tools with secure secret injection."""

    def __init__(self, secrets_manager: SecretsManager):
        self.secrets = secrets_manager

    def execute(self, command: str, required_secrets: list) -> str:
        """Execute command with secrets injected into environment."""
        import subprocess

        # Build secure environment
        env = os.environ.copy()

        for secret_name in required_secrets:
            secret_value = self.secrets.get_secret(secret_name)
            if secret_value:
                env[secret_name] = secret_value
            else:
                raise ValueError(f"Missing required secret: {secret_name}")

        # Execute with secrets in environment (not command line)
        result = subprocess.run(
            command,
            shell=True,
            env=env,
            capture_output=True,
            text=True
        )

        # Never log secrets
        return result.stdout

# Usage
secrets = AWSSecretsManager()
executor = SecureToolExecutor(secrets)

result = executor.execute(
    'psql "$DATABASE_URL" -c "SELECT 1"',
    required_secrets=["DATABASE_URL"]
)
```

## Step 5: Output sanitization

Prevent sensitive data leakage:

```python
import re
from typing import List, Pattern

class OutputSanitizer:
    """Sanitize tool outputs to prevent data leakage."""

    # Patterns to redact
    SENSITIVE_PATTERNS: List[Pattern] = [
        # API keys
        re.compile(r'(sk-[a-zA-Z0-9]{20,})', re.IGNORECASE),
        re.compile(r'(api[_-]?key["\s:=]+)["\']?([a-zA-Z0-9_\-]{16,})', re.IGNORECASE),

        # Passwords
        re.compile(r'(password["\s:=]+)["\']?([^\s"\']+)', re.IGNORECASE),

        # Tokens
        re.compile(r'(bearer\s+)([a-zA-Z0-9_\-\.]+)', re.IGNORECASE),
        re.compile(r'(token["\s:=]+)["\']?([a-zA-Z0-9_\-]{16,})', re.IGNORECASE),

        # AWS credentials
        re.compile(r'(AKIA[0-9A-Z]{16})'),
        re.compile(r'([a-zA-Z0-9/+]{40})'),  # AWS secret key pattern

        # Database URLs
        re.compile(r'(postgres|mysql|mongodb)://[^@]+@', re.IGNORECASE),

        # Credit cards
        re.compile(r'\b(\d{4}[\s\-]?\d{4}[\s\-]?\d{4}[\s\-]?\d{4})\b'),

        # SSN
        re.compile(r'\b(\d{3}[\s\-]?\d{2}[\s\-]?\d{4})\b'),

        # Email (optional)
        re.compile(r'\b([a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,})\b'),
    ]

    REDACTION = "[REDACTED]"

    @classmethod
    def sanitize(cls, output: str, additional_patterns: List[str] = None) -> str:
        """Sanitize output by redacting sensitive information."""

        result = output

        # Apply built-in patterns
        for pattern in cls.SENSITIVE_PATTERNS:
            result = pattern.sub(cls.REDACTION, result)

        # Apply additional patterns
        if additional_patterns:
            for pattern_str in additional_patterns:
                pattern = re.compile(pattern_str, re.IGNORECASE)
                result = pattern.sub(cls.REDACTION, result)

        return result

    @classmethod
    def sanitize_structured(cls, data: dict, sensitive_keys: List[str] = None) -> dict:
        """Sanitize structured data."""

        default_sensitive = [
            "password", "secret", "token", "api_key", "apikey",
            "credential", "private_key", "auth"
        ]

        sensitive_keys = sensitive_keys or default_sensitive

        def redact_dict(d):
            result = {}
            for key, value in d.items():
                key_lower = key.lower()

                if any(s in key_lower for s in sensitive_keys):
                    result[key] = cls.REDACTION
                elif isinstance(value, dict):
                    result[key] = redact_dict(value)
                elif isinstance(value, list):
                    result[key] = [redact_dict(i) if isinstance(i, dict) else i for i in value]
                elif isinstance(value, str):
                    result[key] = cls.sanitize(value)
                else:
                    result[key] = value

            return result

        return redact_dict(data)

# Usage in tool execution
def execute_and_sanitize(tool_name: str, params: dict) -> str:
    """Execute tool and sanitize output."""
    raw_output = execute_tool(tool_name, params)
    return OutputSanitizer.sanitize(raw_output)
```

## Step 6: Rate limiting and abuse prevention

```python
import time
from collections import defaultdict
from typing import Dict, Tuple

class AbusePreventor:
    """Prevent tool abuse and detect anomalies."""

    def __init__(self, redis_client):
        self.redis = redis_client

        # Limits per user per minute
        self.limits = {
            "requests_per_minute": 60,
            "expensive_tools_per_minute": 10,
            "data_bytes_per_minute": 1_000_000
        }

        # Tools that are expensive or dangerous
        self.expensive_tools = [
            "deploy_production",
            "run_migration",
            "bulk_delete"
        ]

    def check_and_record(self, user_id: str, tool_name: str,
                          data_size: int = 0) -> Tuple[bool, str]:
        """Check if request is allowed and record it."""

        minute_key = f"abuse:{user_id}:{int(time.time() / 60)}"

        # Check request count
        request_count = int(self.redis.hget(minute_key, "requests") or 0)
        if request_count >= self.limits["requests_per_minute"]:
            return False, "Rate limit exceeded"

        # Check expensive tools
        if tool_name in self.expensive_tools:
            expensive_count = int(self.redis.hget(minute_key, "expensive") or 0)
            if expensive_count >= self.limits["expensive_tools_per_minute"]:
                return False, "Expensive operation limit exceeded"

        # Check data volume
        data_total = int(self.redis.hget(minute_key, "data_bytes") or 0)
        if data_total + data_size > self.limits["data_bytes_per_minute"]:
            return False, "Data volume limit exceeded"

        # Record this request
        pipe = self.redis.pipeline()
        pipe.hincrby(minute_key, "requests", 1)
        if tool_name in self.expensive_tools:
            pipe.hincrby(minute_key, "expensive", 1)
        pipe.hincrby(minute_key, "data_bytes", data_size)
        pipe.expire(minute_key, 120)
        pipe.execute()

        return True, "OK"

    def detect_anomalies(self, user_id: str) -> list:
        """Detect unusual patterns."""

        anomalies = []

        # Check for unusual tools
        hour_key = f"tools:{user_id}:{int(time.time() / 3600)}"
        tool_counts = self.redis.hgetall(hour_key)

        for tool, count in tool_counts.items():
            if int(count) > 100:  # Unusually high usage
                anomalies.append({
                    "type": "high_usage",
                    "tool": tool,
                    "count": int(count)
                })

        # Check for new tools (user hasn't used before)
        # Implementation depends on historical data

        return anomalies
```

## Security checklist

Before deploying MCP tools:

- [ ] Authentication enabled on all endpoints
- [ ] Authorization (RBAC) configured
- [ ] Input validation for all parameters
- [ ] Shell injection prevention
- [ ] SQL injection prevention (use parameterized queries)
- [ ] Path traversal prevention
- [ ] Secrets stored in environment/secrets manager
- [ ] No secrets in code or configs
- [ ] Output sanitization enabled
- [ ] Rate limiting configured
- [ ] Audit logging enabled
- [ ] Network policies restricting tool access
- [ ] Regular security audits scheduled

## Summary

Securing MCP tools:

1. **Authentication** - Verify who is calling
2. **Authorization** - Control what they can do
3. **Input validation** - Sanitize all inputs
4. **Secrets management** - Never hardcode secrets
5. **Output sanitization** - Prevent data leakage
6. **Rate limiting** - Prevent abuse

Build tools with [Gantz](https://gantz.run), deploy securely.

Security is not optional. It's foundational.

## Related reading

- [Secure Tool Execution](/post/secure-tool-execution/) - Sandbox tool execution
- [Agent Sandboxing](/post/agent-sandboxing/) - Isolate agents
- [Agent Audit Logging](/post/agent-audit-logging/) - Track everything

---

*How do you secure your AI tools? Share your security practices.*
