+++
title = "Why Your 50-Tool Agent is Worse Than a 5-Tool One"
date = 2026-01-06
image = "images/agent-drones-hud.webp"
draft = false
tags = ['tool-use', 'best-practices', 'architecture']
+++


More tools. More capabilities. Better agent.

Right?

Wrong.

Your 50-tool agent is confused, slow, and picks the wrong tool half the time.

Here's why less is more.

## The tool accumulation problem

It starts innocently:

```yaml
# Week 1: Basic tools
tools:
  - read_file
  - write_file
  - run_command
```

Then requirements come in:

```yaml
# Week 4: "We need more specific tools"
tools:
  - read_file
  - read_file_lines
  - read_file_head
  - read_file_tail
  - read_json_file
  - read_yaml_file
  - read_csv_file
  - write_file
  - write_file_append
  - write_json_file
  - patch_file
  - run_command
  - run_command_async
  - run_command_with_timeout
  # ... 36 more tools
```

50 tools. Maximum capability.

Minimum usefulness.

## Problem 1: Decision paralysis

The LLM sees 50 tools. It has to pick one.

```
User: "Read the config file"

Agent thinking:
- read_file?
- read_file_lines?
- read_json_file? (it might be JSON)
- read_yaml_file? (it might be YAML)
- read_config_file? (there's a specific one?)
- run_command with cat?

Agent: *picks read_yaml_file*
File is actually JSON.
Error.
```

With 5 tools:

```
User: "Read the config file"

Agent thinking:
- read_file

Agent: *uses read_file*
Works.
```

Fewer choices = faster, better decisions.

## Problem 2: Context bloat

Every tool costs tokens:

```python
# Minimal tool definition: ~50 tokens
{
    "name": "read",
    "description": "Read a file",
    "parameters": {"path": {"type": "string"}}
}

# Typical tool definition: ~150 tokens
{
    "name": "read_file_with_line_numbers",
    "description": "Read the contents of a file and return with line numbers prefixed to each line. Useful when you need to reference specific lines.",
    "parameters": {
        "path": {
            "type": "string",
            "description": "The path to the file to read"
        },
        "start_line": {
            "type": "integer",
            "description": "Optional starting line number"
        },
        "end_line": {
            "type": "integer",
            "description": "Optional ending line number"
        }
    }
}
```

Do the math:

```
5 tools × 100 tokens = 500 tokens (fixed cost per request)
50 tools × 150 tokens = 7,500 tokens (fixed cost per request)
```

7,500 tokens before the conversation even starts.

At $0.01/1K tokens, that's $0.075 per request just for tool definitions.

1,000 requests = $75 wasted on tool definitions alone.

## Problem 3: Similar tools confuse models

```yaml
tools:
  - name: search_files
    description: Search for files by name pattern

  - name: search_content
    description: Search for content within files

  - name: search_code
    description: Search for code patterns

  - name: find_files
    description: Find files matching criteria

  - name: grep
    description: Search text in files

  - name: ripgrep
    description: Fast search in files
```

Six search tools. The model will:
- Pick the wrong one 40% of the time
- Waste tokens trying multiple tools
- Sometimes give up and ask the user

One search tool:

```yaml
tools:
  - name: search
    description: Search for text in files. Returns matching lines.
```

No confusion. Works every time.

## Problem 4: Maintenance nightmare

50 tools means:

```python
# 50 tool definitions to maintain
# 50 implementations to keep working
# 50 potential failure points
# 50 things to test
# 50 descriptions to keep accurate

def execute_tool(name, args):
    if name == "read_file":
        ...
    elif name == "read_file_lines":
        ...
    elif name == "read_file_head":
        ...
    # ... 47 more elif statements
```

When something breaks, good luck finding it.

## Problem 5: The illusion of specificity

Developers think:

> "A specific tool for JSON files will be more reliable than a generic read tool"

Reality:

```python
# "Specific" JSON tool
def read_json_file(path):
    with open(path) as f:
        return json.load(f)

# Generic read tool
def read_file(path):
    with open(path) as f:
        return f.read()

# The LLM can parse JSON from read_file output just fine
# It's literally trained on millions of JSON examples
```

The specificity doesn't help. It just adds another tool to confuse things.

## The evidence

I ran an experiment. Same tasks, different tool counts:

```
Task: "Find all TODO comments and list them"

50-tool agent:
- Attempts: 3.2 average (tried wrong tools first)
- Success rate: 76%
- Tokens used: 4,200 average

5-tool agent:
- Attempts: 1.1 average
- Success rate: 94%
- Tokens used: 1,800 average
```

The 5-tool agent was faster, cheaper, and more accurate.

## The right number of tools

For most agents: **4-6 tools**.

### The universal toolkit

```yaml
tools:
  - name: read
    description: Read a file's contents

  - name: write
    description: Write content to a file

  - name: search
    description: Search for text in files

  - name: run
    description: Run a shell command
```

Four tools. Covers 90% of coding tasks.

### When you need more

```yaml
# Add domain-specific tools only
tools:
  - read
  - write
  - search
  - run
  - query_database    # If your agent works with DBs
  - call_api          # If your agent needs external APIs
```

Six tools. Covers 98% of tasks.

## How to consolidate

### Before: File reading explosion

```yaml
tools:
  - read_file
  - read_file_lines
  - read_file_head
  - read_file_tail
  - read_json_file
  - read_yaml_file
  - read_csv_file
  - read_binary_file
```

### After: One tool, smart implementation

```yaml
tools:
  - name: read
    description: Read a file. Supports text, JSON, YAML, CSV. Use 'lines' param for partial reads.
    parameters:
      - name: path
        type: string
        required: true
      - name: lines
        type: string
        description: "Optional. Format: 'start:end' (e.g., '1:50' for first 50 lines)"
```

```python
def read(path, lines=None):
    content = open(path).read()

    if lines:
        start, end = map(int, lines.split(':'))
        content = '\n'.join(content.split('\n')[start-1:end])

    # Auto-detect and parse structured formats
    if path.endswith('.json'):
        return f"[JSON file]\n{content}"
    elif path.endswith('.yaml') or path.endswith('.yml'):
        return f"[YAML file]\n{content}"

    return content
```

One tool. Same capabilities. No confusion.

### Before: Search tool sprawl

```yaml
tools:
  - search_files
  - search_content
  - search_code
  - find_files
  - grep_files
  - regex_search
```

### After: One search tool

```yaml
tools:
  - name: search
    description: Search files. Use query for content, pattern for filenames.
    parameters:
      - name: query
        type: string
        description: Text or regex to search for in file contents
      - name: pattern
        type: string
        description: Glob pattern for filenames (e.g., "*.py")
      - name: path
        type: string
        description: Directory to search in (default: current)
```

```python
def search(query=None, pattern=None, path="."):
    if query:
        # Content search
        result = subprocess.run(
            f'rg "{query}" {path} --max-count=30',
            shell=True, capture_output=True, text=True
        )
        return result.stdout or "No matches"

    if pattern:
        # Filename search
        result = subprocess.run(
            f'find {path} -name "{pattern}" | head -30',
            shell=True, capture_output=True, text=True
        )
        return result.stdout or "No files found"

    return "Provide either query or pattern"
```

### Before: Command execution variants

```yaml
tools:
  - run_command
  - run_command_async
  - run_command_background
  - run_command_with_timeout
  - run_shell
  - execute_script
```

### After: One run tool

```yaml
tools:
  - name: run
    description: Run a shell command
    parameters:
      - name: command
        type: string
        required: true
      - name: timeout
        type: integer
        description: Timeout in seconds (default: 30)
```

## The consolidation checklist

When reviewing your tools, ask:

1. **Can these be merged?**
   - `read_file` + `read_json` + `read_yaml` → `read`
   - `search_files` + `search_content` → `search`

2. **Is this just a parameter?**
   - `read_file_head` → `read` with `lines` parameter
   - `run_command_with_timeout` → `run` with `timeout` parameter

3. **Does the LLM need this distinction?**
   - `grep` vs `ripgrep` → The LLM doesn't care, use one
   - `write_file` vs `write_file_append` → One tool, `mode` parameter

4. **Is this actually used?**
   - Log tool usage for a week
   - Delete tools with <5% usage

## Building lean with Gantz

With [Gantz](https://gantz.run), start minimal:

```yaml
# gantz.yaml - The lean toolkit
tools:
  - name: read
    description: Read a file
    parameters:
      - name: path
        type: string
        required: true
    script:
      shell: cat "{{path}}"

  - name: write
    description: Write to a file
    parameters:
      - name: path
        type: string
        required: true
      - name: content
        type: string
        required: true
    script:
      shell: |
        cat > "{{path}}" << 'CONTENT'
        {{content}}
        CONTENT

  - name: search
    description: Search for text in files
    parameters:
      - name: query
        type: string
        required: true
    script:
      shell: rg "{{query}}" . --max-count=30 || echo "No matches"

  - name: run
    description: Run a shell command
    parameters:
      - name: command
        type: string
        required: true
    script:
      shell: "{{command}}"
```

Four tools. Complete agent. Add more only when you have evidence you need them.

## The mindset shift

**Old thinking:**
> "What tools might the agent need?"
> *Builds 50 tools to cover every case*

**New thinking:**
> "What's the minimum toolkit that works?"
> *Builds 5 tools, adds more based on real failures*

## Summary

| Aspect | 50 Tools | 5 Tools |
|--------|----------|---------|
| Decision speed | Slow (many choices) | Fast (few choices) |
| Accuracy | ~75% right tool | ~95% right tool |
| Token cost | 7,500+ per request | 500 per request |
| Maintenance | Nightmare | Simple |
| Debugging | Hard | Easy |

The best agent isn't the one with the most tools.

It's the one with the right tools.

Start with 5. Add only what you prove you need.

## Related reading

- [The 80/20 Rule for AI Agents](/post/80-20-rule/) - Focus on what actually matters
- [Writing Tool Descriptions That Work](/post/tool-descriptions/) - Better descriptions for fewer tools
- [Atomic vs Compound Tools](/post/atomic-compound-tools/) - When to combine functionality

---

*How many tools does your agent have? Have you tried cutting them down?*
