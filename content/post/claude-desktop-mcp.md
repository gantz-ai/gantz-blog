+++
title = "Claude Desktop MCP Setup: Complete 2025 Guide"
image = "images/claude-desktop-mcp.webp"
date = 2025-11-07
description = "Connect Claude Desktop to MCP servers step-by-step. Configure local tools, remote servers, and authentication for AI-powered automation."
draft = false
tags = ['mcp', 'tutorial', 'claude']
voice = false
summary = "Give Claude Desktop superpowers by connecting it to MCP servers. Edit claude_desktop_config.json to add local tools like file access and shell commands, connect to remote MCP servers for APIs and databases, and set up authentication. Turn the Claude Desktop app into a full-featured AI assistant that can actually do things on your computer."

[howto]
name = "Set Up MCP in Claude Desktop"
totalTime = 15
[[howto.steps]]
name = "Install Claude Desktop"
text = "Download and install Claude Desktop from anthropic.com."
[[howto.steps]]
name = "Create config file"
text = "Create claude_desktop_config.json in the correct location."
[[howto.steps]]
name = "Add MCP server"
text = "Configure your MCP server URL and authentication."
[[howto.steps]]
name = "Restart Claude"
text = "Restart Claude Desktop to load the new configuration."
[[howto.steps]]
name = "Test tools"
text = "Verify tools are available by asking Claude to use them."
+++


Claude Desktop can use MCP tools. Your local tools. Remote tools. Any tools.

But the setup isn't obvious.

Here's the complete guide.

## What you'll get

After setup, Claude Desktop can:
- Read and write files on your machine
- Run shell commands
- Query databases
- Call APIs
- Use any custom tools you build

All through natural conversation.

## Prerequisites

- Claude Desktop installed ([download here](https://claude.ai/desktop))
- An MCP server (local or remote)
- 15 minutes

## Step 1: Find the config location

Claude Desktop looks for config in specific locations:

**macOS:**
```
~/Library/Application Support/Claude/claude_desktop_config.json
```

**Windows:**
```
%APPDATA%\Claude\claude_desktop_config.json
```

**Linux:**
```
~/.config/Claude/claude_desktop_config.json
```

Create the file if it doesn't exist:

```bash
# macOS
mkdir -p ~/Library/Application\ Support/Claude
touch ~/Library/Application\ Support/Claude/claude_desktop_config.json

# Linux
mkdir -p ~/.config/Claude
touch ~/.config/Claude/claude_desktop_config.json
```

## Step 2: Configure MCP servers

### Local MCP server

For a server running on your machine:

```json
{
  "mcpServers": {
    "local-tools": {
      "command": "python",
      "args": ["/path/to/your/mcp_server.py"],
      "env": {
        "SOME_VAR": "value"
      }
    }
  }
}
```

Claude Desktop will start this process automatically.

### Remote MCP server (via Gantz)

For a [Gantz](https://gantz.run) tunnel or remote server:

```json
{
  "mcpServers": {
    "remote-tools": {
      "url": "https://cool-penguin.gantz.run/sse",
      "authorization_token": "gtz_your_token_here"
    }
  }
}
```

### Multiple servers

You can configure multiple MCP servers:

```json
{
  "mcpServers": {
    "file-tools": {
      "command": "npx",
      "args": ["-y", "@anthropic/mcp-server-filesystem", "/home/user/documents"]
    },
    "code-tools": {
      "url": "https://code-tools.gantz.run/sse",
      "authorization_token": "gtz_abc123"
    },
    "database": {
      "command": "python",
      "args": ["./db_server.py"],
      "env": {
        "DATABASE_URL": "postgresql://localhost/mydb"
      }
    }
  }
}
```

## Step 3: Restart Claude Desktop

After editing the config:

1. Quit Claude Desktop completely
2. Reopen Claude Desktop
3. Wait for initialization

Check the logs if something goes wrong:

**macOS:**
```bash
tail -f ~/Library/Logs/Claude/mcp*.log
```

## Step 4: Verify tools

Ask Claude to list available tools:

```
You: What tools do you have access to?

Claude: I have access to the following tools:
- read_file: Read contents of a file
- write_file: Write content to a file
- search_code: Search for patterns in code
...
```

Test a tool:

```
You: Read the contents of package.json

Claude: [uses read_file tool]
Here are the contents of package.json:
{
  "name": "my-project",
  ...
}
```

## Common configurations

### File system tools

Access local files:

```json
{
  "mcpServers": {
    "filesystem": {
      "command": "npx",
      "args": ["-y", "@anthropic/mcp-server-filesystem", "/path/to/allowed/directory"]
    }
  }
}
```

### Git tools

Work with Git repositories:

```json
{
  "mcpServers": {
    "git": {
      "command": "npx",
      "args": ["-y", "@anthropic/mcp-server-git"]
    }
  }
}
```

### Custom Gantz server

Your own tools via [Gantz](https://gantz.run):

```yaml
# gantz.yaml
name: my-tools

tools:
  - name: run_tests
    description: Run project tests
    script:
      shell: npm test

  - name: deploy
    description: Deploy to production
    script:
      shell: ./deploy.sh
```

```bash
gantz run --auth
# Get URL and token
```

```json
{
  "mcpServers": {
    "my-tools": {
      "url": "https://awesome-cat.gantz.run/sse",
      "authorization_token": "gtz_xyz789"
    }
  }
}
```

## Troubleshooting

### Tools not appearing

1. Check config file syntax:
```bash
cat ~/Library/Application\ Support/Claude/claude_desktop_config.json | jq .
```

2. Verify server is running:
```bash
curl https://your-server.gantz.run/mcp/tools
```

3. Check Claude logs:
```bash
tail -100 ~/Library/Logs/Claude/mcp*.log
```

### Authentication errors

Ensure token is correct:

```json
{
  "mcpServers": {
    "tools": {
      "url": "https://server.gantz.run/sse",
      "authorization_token": "gtz_..."  // Must start with correct prefix
    }
  }
}
```

### Server crashes

For local servers, check stderr:

```json
{
  "mcpServers": {
    "tools": {
      "command": "python",
      "args": ["server.py"],
      "env": {
        "PYTHONUNBUFFERED": "1"  // See output immediately
      }
    }
  }
}
```

### Timeout errors

Increase timeout for slow tools:

```json
{
  "mcpServers": {
    "slow-tools": {
      "url": "https://server.gantz.run/sse",
      "timeout": 120000
    }
  }
}
```

## Security considerations

### Local servers

Local MCP servers run with your user permissions. They can:
- Access any file you can access
- Run any command you can run
- Use your credentials

Only run trusted code.

### Remote servers

Remote servers accessed via URL should use authentication:

```json
{
  "mcpServers": {
    "remote": {
      "url": "https://server.gantz.run/sse",
      "authorization_token": "gtz_secret"  // Always use auth
    }
  }
}
```

Never expose MCP servers without authentication.

### Environment variables

Don't put secrets directly in config. Use environment references:

```json
{
  "mcpServers": {
    "database": {
      "command": "python",
      "args": ["db_server.py"],
      "env": {
        "DATABASE_URL": "${DATABASE_URL}"  // From environment
      }
    }
  }
}
```

## Advanced configuration

### Conditional servers

Use different servers for different projects:

```bash
# Create project-specific config
cd ~/projects/frontend
cat > .claude_config.json << EOF
{
  "mcpServers": {
    "frontend-tools": {
      "url": "https://frontend.gantz.run/sse"
    }
  }
}
EOF
```

### Server groups

Organize related tools:

```json
{
  "mcpServers": {
    "dev-file-tools": {
      "command": "npx",
      "args": ["-y", "@anthropic/mcp-server-filesystem", "~/dev"]
    },
    "dev-git-tools": {
      "command": "npx",
      "args": ["-y", "@anthropic/mcp-server-git"]
    },
    "dev-docker-tools": {
      "url": "https://docker-tools.gantz.run/sse",
      "authorization_token": "gtz_docker123"
    }
  }
}
```

## Quick start with Gantz

The fastest way to get tools in Claude Desktop:

1. Create tools:
```yaml
# gantz.yaml
name: quick-tools

tools:
  - name: read_file
    description: Read file contents
    parameters:
      - name: path
        type: string
        required: true
    script:
      shell: cat "{{path}}"

  - name: list_files
    description: List files in directory
    parameters:
      - name: path
        type: string
        default: "."
    script:
      shell: ls -la "{{path}}"
```

2. Start server:
```bash
gantz run --auth
# Tunnel URL: https://happy-dolphin.gantz.run
# Auth Token: gtz_abc123
```

3. Add to Claude config:
```json
{
  "mcpServers": {
    "quick-tools": {
      "url": "https://happy-dolphin.gantz.run/sse",
      "authorization_token": "gtz_abc123"
    }
  }
}
```

4. Restart Claude Desktop

5. Use:
```
You: List all Python files in the current directory

Claude: [uses list_files tool]
Here are the Python files...
```

## Summary

Claude Desktop + MCP = powerful automation:

1. **Create config** at the right location
2. **Add servers** - local or remote
3. **Restart Claude** to load config
4. **Verify tools** work correctly

Start with a simple [Gantz](https://gantz.run) server. Add more tools as needed. Your Claude Desktop becomes infinitely extensible.

## Related reading

- [Your First Agent in 30 Minutes](/post/first-agent/) - Build custom tools
- [MCP in Your Stack](/post/mcp-in-stack/) - Architecture guide
- [50 MCP Tool Ideas](/post/50-tools/) - Inspiration for tools

---

*What tools have you connected to Claude Desktop? Share your setup.*
