+++
title = "How to Secure Your MCP Server: Authentication Guide"
image = "/images/mcp-authentication.png"
date = 2025-11-15
description = "Implement authentication for MCP servers. Learn token-based auth, OAuth integration, and security best practices to protect your AI agent tools."
draft = false
tags = ['mcp', 'security', 'best-practices']
voice = false

[howto]
name = "Secure Your MCP Server with Authentication"
totalTime = 20
[[howto.steps]]
name = "Choose authentication method"
text = "Decide between token-based auth, OAuth, or API keys based on your use case."
[[howto.steps]]
name = "Generate secure tokens"
text = "Create cryptographically secure tokens for client authentication."
[[howto.steps]]
name = "Implement token validation"
text = "Add middleware to validate tokens on every MCP request."
[[howto.steps]]
name = "Set up token rotation"
text = "Implement automatic token rotation for enhanced security."
[[howto.steps]]
name = "Test authentication flow"
text = "Verify authentication works correctly with your AI clients."
+++


Your MCP server exposes powerful tools. Without authentication, anyone who finds your endpoint can use them.

That's a problem.

Here's how to lock it down properly.

## Why authentication matters

MCP servers can do real things:
- Execute shell commands
- Read and write files
- Query databases
- Send emails
- Access APIs

Without auth, a leaked URL means anyone can:
- Run arbitrary commands on your machine
- Access sensitive data
- Make API calls on your behalf
- Rack up costs on your accounts

Authentication isn't optional. It's essential.

## Authentication options

### Token-based authentication

The simplest approach. Client sends a token with each request.

```
Client → MCP Server
Authorization: Bearer gtz_abc123...
```

If the token matches, request proceeds. If not, rejected.

**Pros:**
- Simple to implement
- Low overhead
- Works everywhere

**Cons:**
- Token management required
- No built-in expiration (unless you add it)
- Single point of failure if token leaks

### OAuth 2.0

Industry standard for delegated authorization.

```
Client → Auth Server → Get Token
Client → MCP Server (with token)
MCP Server → Auth Server → Validate Token
```

**Pros:**
- Standard protocol
- Token expiration built-in
- Refresh tokens for long sessions
- Scope-based permissions

**Cons:**
- More complex setup
- Requires auth server
- Additional latency for validation

### API Keys

Similar to tokens, but typically longer-lived and tied to accounts.

```
Client → MCP Server
X-API-Key: your-api-key-here
```

**Pros:**
- Simple to understand
- Easy to revoke
- Can track usage per key

**Cons:**
- Often sent in headers (can leak in logs)
- Usually no expiration
- Need secure storage

## Implementing token auth

Let's implement token-based auth. It's the best balance of security and simplicity for most MCP servers.

### Generate secure tokens

Never use predictable tokens. Use cryptographically secure random generation:

```python
import secrets

def generate_token():
    # 32 bytes = 256 bits of entropy
    return f"gtz_{secrets.token_urlsafe(32)}"

# Example: gtz_Abc123XyzRandomString...
```

For [Gantz](https://gantz.run), the `--auth` flag handles this automatically:

```bash
gantz run --auth
# Generates secure token and displays it
# Tunnel URL: https://cool-penguin.gantz.run
# Auth Token: gtz_abc123...
```

### Validate tokens on requests

Every incoming request must be validated:

```python
from functools import wraps
from flask import request, jsonify

VALID_TOKENS = {"gtz_your_secure_token_here"}

def require_auth(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        auth_header = request.headers.get("Authorization")

        if not auth_header:
            return jsonify({"error": "Missing authorization header"}), 401

        if not auth_header.startswith("Bearer "):
            return jsonify({"error": "Invalid authorization format"}), 401

        token = auth_header[7:]  # Remove "Bearer " prefix

        if token not in VALID_TOKENS:
            return jsonify({"error": "Invalid token"}), 403

        return f(*args, **kwargs)
    return decorated

@app.route("/mcp/tools/call", methods=["POST"])
@require_auth
def call_tool():
    # Token validated, proceed with tool call
    ...
```

### Token storage

Never hardcode tokens. Use environment variables:

```python
import os

VALID_TOKENS = set(os.environ.get("MCP_AUTH_TOKENS", "").split(","))

if not VALID_TOKENS or VALID_TOKENS == {""}:
    raise ValueError("MCP_AUTH_TOKENS environment variable required")
```

```bash
export MCP_AUTH_TOKENS="gtz_token1,gtz_token2"
```

### Token rotation

Tokens should be rotated periodically. Here's a simple approach:

```python
import time
from dataclasses import dataclass

@dataclass
class Token:
    value: str
    created_at: float
    expires_at: float

class TokenManager:
    def __init__(self, ttl_seconds=86400):  # 24 hours
        self.tokens = {}
        self.ttl = ttl_seconds

    def create_token(self):
        token = Token(
            value=f"gtz_{secrets.token_urlsafe(32)}",
            created_at=time.time(),
            expires_at=time.time() + self.ttl
        )
        self.tokens[token.value] = token
        return token

    def validate(self, token_value):
        token = self.tokens.get(token_value)
        if not token:
            return False
        if time.time() > token.expires_at:
            del self.tokens[token_value]
            return False
        return True

    def revoke(self, token_value):
        self.tokens.pop(token_value, None)
```

## Implementing OAuth

For production systems with multiple users, OAuth is better.

### OAuth flow

```
1. Client requests authorization
2. User authenticates with auth provider
3. Auth provider returns authorization code
4. Client exchanges code for access token
5. Client uses token with MCP server
6. MCP server validates token with auth provider
```

### Using Auth0 (example)

```python
from authlib.integrations.flask_client import OAuth

oauth = OAuth(app)
auth0 = oauth.register(
    'auth0',
    client_id='YOUR_CLIENT_ID',
    client_secret='YOUR_CLIENT_SECRET',
    api_base_url='https://YOUR_DOMAIN.auth0.com',
    access_token_url='https://YOUR_DOMAIN.auth0.com/oauth/token',
    authorize_url='https://YOUR_DOMAIN.auth0.com/authorize',
    client_kwargs={
        'scope': 'openid profile email',
    },
)

def validate_oauth_token(token):
    # Validate with Auth0
    resp = requests.get(
        'https://YOUR_DOMAIN.auth0.com/userinfo',
        headers={'Authorization': f'Bearer {token}'}
    )
    return resp.status_code == 200
```

### JWT validation

If using JWTs, validate locally without calling auth server:

```python
import jwt
from jwt import PyJWKClient

jwks_client = PyJWKClient("https://YOUR_DOMAIN.auth0.com/.well-known/jwks.json")

def validate_jwt(token):
    try:
        signing_key = jwks_client.get_signing_key_from_jwt(token)
        payload = jwt.decode(
            token,
            signing_key.key,
            algorithms=["RS256"],
            audience="YOUR_API_IDENTIFIER",
            issuer="https://YOUR_DOMAIN.auth0.com/"
        )
        return payload
    except jwt.InvalidTokenError:
        return None
```

## Scope-based permissions

Not all clients should access all tools. Implement scopes:

```python
TOOL_SCOPES = {
    "read_files": ["file:read"],
    "write_files": ["file:write"],
    "run_commands": ["shell:execute"],
    "query_database": ["db:read"],
}

def check_scope(required_scope, token_scopes):
    return required_scope in token_scopes

@app.route("/mcp/tools/call", methods=["POST"])
@require_auth
def call_tool():
    tool_name = request.json.get("tool")
    token_scopes = get_scopes_from_token(request.headers.get("Authorization"))

    required_scopes = TOOL_SCOPES.get(tool_name, [])
    for scope in required_scopes:
        if not check_scope(scope, token_scopes):
            return jsonify({
                "error": f"Missing required scope: {scope}"
            }), 403

    # Proceed with tool execution
    ...
```

## Security best practices

### 1. Always use HTTPS

Never send tokens over unencrypted connections:

```python
@app.before_request
def require_https():
    if not request.is_secure and not app.debug:
        return jsonify({"error": "HTTPS required"}), 400
```

### 2. Rate limit authentication attempts

Prevent brute force attacks:

```python
from flask_limiter import Limiter

limiter = Limiter(app, key_func=get_remote_address)

@app.route("/mcp/tools/call", methods=["POST"])
@limiter.limit("100 per minute")
@require_auth
def call_tool():
    ...
```

### 3. Log authentication failures

Track failed attempts for security monitoring:

```python
import logging

auth_logger = logging.getLogger("auth")

def require_auth(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        auth_header = request.headers.get("Authorization")

        if not validate_token(auth_header):
            auth_logger.warning(
                f"Auth failed: {request.remote_addr} - {request.path}"
            )
            return jsonify({"error": "Unauthorized"}), 401

        return f(*args, **kwargs)
    return decorated
```

### 4. Use short-lived tokens

Prefer tokens that expire quickly:

```python
# Good: 1 hour expiration
token = create_token(expires_in=3600)

# Bad: No expiration
token = create_token()  # Lives forever
```

### 5. Implement token revocation

Allow immediate token invalidation:

```python
REVOKED_TOKENS = set()

def revoke_token(token):
    REVOKED_TOKENS.add(token)

def is_token_valid(token):
    if token in REVOKED_TOKENS:
        return False
    return validate_token(token)
```

## Testing authentication

### Test valid tokens

```python
def test_valid_token():
    response = client.post(
        "/mcp/tools/call",
        headers={"Authorization": "Bearer valid_token"},
        json={"tool": "read_file", "params": {"path": "test.txt"}}
    )
    assert response.status_code == 200
```

### Test missing tokens

```python
def test_missing_token():
    response = client.post(
        "/mcp/tools/call",
        json={"tool": "read_file", "params": {"path": "test.txt"}}
    )
    assert response.status_code == 401
```

### Test invalid tokens

```python
def test_invalid_token():
    response = client.post(
        "/mcp/tools/call",
        headers={"Authorization": "Bearer invalid_token"},
        json={"tool": "read_file", "params": {"path": "test.txt"}}
    )
    assert response.status_code == 403
```

### Test expired tokens

```python
def test_expired_token():
    token = create_token(expires_in=-1)  # Already expired
    response = client.post(
        "/mcp/tools/call",
        headers={"Authorization": f"Bearer {token}"},
        json={"tool": "read_file", "params": {"path": "test.txt"}}
    )
    assert response.status_code == 401
```
 
## Quick setup with Gantz

[Gantz](https://gantz.run) handles authentication automatically:

```bash
# Start with authentication enabled
gantz run --auth

# Output:
# Tunnel URL: https://cool-penguin.gantz.run/sse
# Auth Token: gtz_abc123...
```

Use the token in your AI client:

```python
response = client.messages.create(
    model="claude-sonnet-4-5-20250929",
    messages=[{"role": "user", "content": "List files"}],
    mcp_servers=[{
        "type": "url",
        "url": "https://cool-penguin.gantz.run/sse",
        "authorization_token": "gtz_abc123..."
    }]
)
```

No manual token generation, validation, or middleware required.

## Summary

Secure your MCP server:

1. **Always use authentication** - Never expose tools without auth
2. **Choose the right method** - Tokens for simple, OAuth for complex
3. **Generate secure tokens** - Use cryptographic randomness
4. **Validate every request** - No exceptions
5. **Implement expiration** - Short-lived tokens are safer
6. **Log failures** - Track suspicious activity
7. **Use HTTPS** - Never send tokens in plain text

Authentication is the first line of defense. Get it right, and your MCP tools stay yours. Get it wrong, and you've given strangers the keys to your system.

Start with token auth. Upgrade to OAuth when you need multiple users or finer permissions. Either way, never skip this step.

## Related reading

- [MCP Security Checklist](/post/mcp-security-checklist/) - Complete security guide
- [Input Validation for AI Agents](/post/agent-input-validation/) - Block bad requests
- [Sandboxing MCP Tools](/post/sandboxing-mcp-tools/) - Limit tool access

---

*How do you handle authentication in your MCP servers? Token auth or OAuth?*
