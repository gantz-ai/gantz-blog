+++
title = "I got tired of ngrok just to test MCP tools, so I built this"
date = 2025-12-06
description = "Expose local MCP servers without ngrok or port forwarding. Gantz CLI creates secure tunnels for testing AI tools with Claude instantly."
image = "images/agent-city-02.webp"
draft = false
tags = ['mcp', 'deployment', 'tutorial']
voice = true
+++


If you've been playing with MCP (Model Context Protocol) to give Claude or other AI agents access to tools, you've probably hit this wall:

You write a cool tool that queries your local Postgres, runs a script, or hits an internal API. Works great locally. Then you want to actually use it with Claude... and now you need to figure out how to expose it.

ngrok? Sure, but it's another thing to set up. Port forwarding? Pain in the ass, especially if you're on a corporate network. Deploy to a server? Now you're maintaining infrastructure for a prototype.

I kept running into this so I built a CLI called **Gantz Run** that just handles it.

## The problem with existing solutions

Before building Gantz, I tried everything:

### ngrok

ngrok is the go-to solution for exposing local services. It works, but:

- Free tier limits: 1 online ngrok process, 40 connections/minute
- URL changes every restart (unless you pay)
- Another service to sign up for and manage
- Not designed for MCP specifically

For quick testing, it's fine. For regular MCP development, the friction adds up.

### localtunnel

Free and open source, but:

- Unreliable connections
- Slower than ngrok
- Random subdomains that change
- No built-in security

### Cloudflare Tunnels

Powerful, but:

- Requires Cloudflare account and domain
- Complex setup with `cloudflared`
- Overkill for local MCP testing
- Configuration isn't trivial

### Port forwarding

The old school approach:

- Requires router access (not always possible)
- Security nightmare if done wrong
- Doesn't work on corporate networks
- Dynamic IPs break everything

### Deploy to a server

The "proper" solution:

- Now you're maintaining infrastructure
- CI/CD for a prototype?
- Costs money
- Slow iteration cycle

## How Gantz Run works

```
┌─────────────┐         ┌──────────────┐         ┌─────────────┐
│  AI Agent   │  HTTPS  │ Gantz Relay  │   WSS   │  Gantz Run  │
│  (Claude)   │────────►│              │◄───────►│  (you)      │
└─────────────┘         └──────────────┘         └─────────────┘
                                                       │
                                                       ▼
                                                 Local Scripts
                                                 & Commands
```

You define your tools in a `gantz.yaml` file:

```yaml
name: my-tools
description: My local MCP tools
version: "1.0.0"

server:
  port: 3000

tools:
  - name: query_db
    description: Run a SQL query on my local database
    parameters:
      - name: query
        type: string
        description: SQL query to execute
        required: true
    script:
      shell: psql -U postgres -d myapp -c "{{query}}"
      timeout: 30s

  - name: list_files
    description: List files in a directory
    parameters:
      - name: path
        type: string
        description: Directory path to list
        default: "."
    script:
      shell: ls -la "{{path}}"
```

Then run:

```bash
gantz run
```

Output:
```
Gantz Run v0.1.0
Loaded 2 tools from gantz.yaml

Connecting to relay server...

  MCP Server URL: https://abc12345.gantz.run

  Add to Claude Desktop config:
  {
    "mcpServers": {
      "my-tools": {
        "url": "https://abc12345.gantz.run"
      }
    }
  }

Press Ctrl+C to stop
```

Point Claude at the URL and your local tools are accessible. No signup required. No port forwarding. Just works.

## What makes it different

### Built for MCP

Gantz isn't a generic tunnel service. It's built specifically for MCP:

- Implements the full MCP protocol (`initialize`, `tools/list`, `tools/call`)
- SSE and WebSocket transport out of the box
- YAML-based tool definitions with parameter schemas
- Automatic tool discovery for AI agents

### Multiple tool types

Define shell scripts:

```yaml
tools:
  - name: git_status
    description: Get git repository status
    script:
      shell: git status
```

Or call HTTP APIs directly:

```yaml
tools:
  - name: get_weather
    description: Get weather for a city
    parameters:
      - name: city
        type: string
        required: true
    http:
      method: GET
      url: "https://api.weather.com/v1/current?city={{city}}"
      headers:
        X-API-Key: "${WEATHER_API_KEY}"
      timeout: 10s
      extract_json: "data"
```

### Zero infrastructure

Your tools run on your machine. The relay server just routes traffic via WebSocket. Nothing is stored or logged beyond what you see in your terminal.

## What I actually use it for

### Database queries

Letting Claude query my dev database without copying data anywhere:

```yaml
tools:
  - name: query_users
    description: Query the users table
    parameters:
      - name: filters
        type: string
        description: WHERE clause conditions
    script:
      shell: psql -U postgres -d myapp -c "SELECT * FROM users WHERE {{filters}} LIMIT 100"
      timeout: 30s
```

Now Claude can explore my data structure, find issues, generate reports.

### File operations

Running local scripts that interact with files on my machine:

```yaml
tools:
  - name: read_logs
    description: Read application logs
    parameters:
      - name: lines
        type: number
        default: "100"
    script:
      shell: tail -n {{lines}} /var/log/myapp/app.log

  - name: search_code
    description: Search codebase for a pattern
    parameters:
      - name: pattern
        type: string
        required: true
    script:
      shell: grep -r "{{pattern}}" ./src --include="*.ts"
```

### Git operations

```yaml
tools:
  - name: git_log
    description: Show recent git commits
    parameters:
      - name: count
        type: number
        default: "5"
    script:
      shell: git log --oneline -n {{count}}

  - name: git_diff
    description: Show uncommitted changes
    script:
      shell: git diff
```

### Python integration

```yaml
tools:
  - name: run_python
    description: Execute Python code
    parameters:
      - name: code
        type: string
        description: Python code to execute
        required: true
    script:
      command: python3
      args: ["-c", "{{code}}"]
      timeout: 30s

  - name: analyze_data
    description: Analyze a CSV file
    parameters:
      - name: file
        type: string
        required: true
    script:
      shell: python3 analyze.py "{{file}}"
      working_dir: /path/to/scripts
    environment:
      PYTHONPATH: "${HOME}/projects/lib"
```

### Quick demos

Client wants to see AI integration? Spin up Gantz, show them Claude using real tools, tear it down. No infrastructure to maintain.

## Connecting to Claude Desktop

Add the MCP server URL to your Claude Desktop config:

**macOS**: `~/Library/Application Support/Claude/claude_desktop_config.json`
**Windows**: `%APPDATA%\Claude\claude_desktop_config.json`

```json
{
  "mcpServers": {
    "my-tools": {
      "url": "https://abc12345.gantz.run"
    }
  }
}
```

Restart Claude Desktop and your tools appear automatically.

## Security considerations

Let's be real about security:

### What Gantz does

- Requests route through the relay server via WebSocket
- TLS encryption in transit
- Parameters are substituted into scripts (be careful with untrusted input)
- No request logging or storage on relay

### What you should do

- Don't expose production databases
- Use read-only credentials where possible
- Keep tunnel URLs private
- Understand that anyone with the URL can call your tools

### Environment variables

Use `${ENV_VAR}` expansion for sensitive values:

```yaml
tools:
  - name: api_call
    environment:
      API_KEY: ${MY_API_KEY}
    script:
      shell: curl -H "Authorization: $API_KEY" {{endpoint}}
```

## Installation

### Quick Install (Recommended)

```bash
curl -fsSL https://gantz.run/install.sh | sh
```

### Homebrew (macOS/Linux)

```bash
brew install gantz-ai/tap/gantz
```

### Go Install

```bash
go install github.com/gantz-ai/gantz-cli/cmd/gantz@latest
```

## CLI Reference

```bash
# Start with default config (gantz.yaml)
gantz run

# Use custom config file
gantz run -c my-tools.yaml

# Check version
gantz version
```

## Troubleshooting

### "Connection refused"

Your tool's script is probably failing. The script should work in your terminal first.

### Tool execution fails

- Verify parameter names match between `parameters` and `{{placeholders}}`
- Check `working_dir` exists if specified
- Test the command manually first

### Slow responses

Large outputs take time. Consider:
- Limiting result sizes
- Adding timeouts to scripts
- Using pagination for data queries

## Advanced configuration

### Environment variables

You can use environment variables for sensitive values:

```yaml
tools:
  - name: query_api
    description: Query our internal API
    parameters:
      - name: endpoint
        type: string
        required: true
    http:
      method: GET
      url: "https://api.internal.com/{{endpoint}}"
      headers:
        Authorization: "Bearer ${API_TOKEN}"
```

The `${API_TOKEN}` is expanded from your shell environment when Gantz runs.

### Working directories

For scripts that need to run in a specific directory:

```yaml
tools:
  - name: npm_test
    description: Run npm tests in the project
    script:
      shell: npm test
      working_dir: /path/to/project
      timeout: 120s
```

### Conditional logic

You can use basic conditionals in scripts:

```yaml
tools:
  - name: search_logs
    description: Search application logs
    parameters:
      - name: pattern
        type: string
        required: true
      - name: case_sensitive
        type: boolean
        default: false
    script:
      shell: grep {{ if not case_sensitive }}-i{{ end }} "{{pattern}}" /var/log/app.log | tail -100
```

## Why this matters

The bigger picture: AI agents need access to real tools to be useful. Not just web searches and text generation — actual capabilities.

Every developer has local scripts, databases, and services that would be useful for AI to access. But exposing them has historically been painful:

1. **Tunneling complexity** — ngrok, port forwarding, firewall rules
2. **Protocol translation** — Converting between what AI expects and what your tool provides
3. **Security concerns** — How do you safely expose local services?

Gantz solves all three:

1. **One command** — `gantz run` and you have a public URL
2. **MCP-native** — AI agents speak MCP directly to your tools
3. **Built-in auth** — Optional authentication keeps your tools private

This isn't about replacing ngrok for generic tunneling. It's about making local tools accessible to AI with minimal friction.

## Comparison with alternatives

| Feature | Gantz | ngrok | localtunnel | Cloudflare |
|---------|-------|-------|-------------|------------|
| MCP-native | Yes | No | No | No |
| Free tier | Unlimited | Limited | Unlimited | Free |
| Setup time | 30 seconds | 2 minutes | 1 minute | 10+ minutes |
| Stable URLs | Per session | Paid only | No | Yes |
| HTTP tools | Built-in | No | No | No |

The key difference: ngrok and alternatives are generic HTTP tunnels. You still need to build the MCP server yourself. Gantz includes the MCP server — you just define tools in YAML.

## Try it

```bash
curl -fsSL https://gantz.run/install.sh | sh
```

Or grab binaries from GitHub: https://github.com/gantz-ai/gantz-cli

Website: https://gantz.run

Still early and probably has bugs. Let me know what breaks or what features would actually be useful.

## Related reading

- [Why Every Dev Will Run an MCP Server](/post/why-every-dev-mcp/) - The future of local tools
- [What is MCP and Where Does it Fit in Your Stack?](/post/mcp-in-stack/) - MCP architecture
- [Running AI Agents in Docker](/post/docker-agents/) - Container deployment

---

*What local tools would you want to expose to AI agents? Curious what use cases people have.*
