+++
title = "Your First Agent: From Zero to Working in 30 Minutes"
date = 2025-12-21
description = "Build your first AI agent in 30 minutes with Python. Step-by-step tutorial covering tool use, the agent loop, and practical examples."
image = "images/hero-cyberpunk-city.webp"
draft = false
featured = true
tags = ['tutorial', 'python', 'tool-use']

[[faqs]]
question = "What is an AI agent?"
answer = "An AI agent is an LLM that can use tools to take actions - reading files, searching code, running commands, calling APIs. Unlike a chatbot that only generates text, an agent can actually do things in the real world."

[[faqs]]
question = "What do I need to build an AI agent?"
answer = "You need an API key (OpenAI or Anthropic), Python installed, and about 50 lines of code. No machine learning expertise required. The core agent loop is surprisingly simple."

[[faqs]]
question = "What is the agent loop?"
answer = "The agent loop is: 1) Send user request to LLM with available tools, 2) If LLM returns a tool call, execute it, 3) Send result back to LLM, 4) Repeat until LLM returns a final response. This loop lets agents work autonomously."

[[faqs]]
question = "How long does it take to build an AI agent?"
answer = "You can build a working agent with file reading, code search, and command execution in about 30 minutes. The basic structure is simple - most time goes into defining useful tools and handling edge cases."
voice = false
+++


You don't need a PhD to build an AI agent.

You need an API key, 50 lines of code, and 30 minutes.

Let's go.

## What we're building

An agent that can:
- Read files
- Search code
- Run commands
- Actually be useful

Not a toy. A real, working agent.

## Minute 0-5: Setup

### Get an API key

Pick one:
- [OpenAI](https://platform.openai.com/api-keys) - GPT-4o
- [Anthropic](https://console.anthropic.com/) - Claude
- [Google](https://aistudio.google.com/apikey) - Gemini

Export it:

```bash
export OPENAI_API_KEY="sk-..."
# or
export ANTHROPIC_API_KEY="sk-ant-..."
```

### Install dependencies

```bash
pip install openai
# or
pip install anthropic
```

That's it. No frameworks. No LangChain. No vector databases.

## Minute 5-15: The core loop

Here's the entire agent:

```python
# agent.py
import openai
import json
import subprocess

client = openai.OpenAI()

# Define what tools the agent can use
tools = [
    {
        "type": "function",
        "function": {
            "name": "read_file",
            "description": "Read the contents of a file",
            "parameters": {
                "type": "object",
                "properties": {
                    "path": {"type": "string", "description": "Path to the file"}
                },
                "required": ["path"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "run_command",
            "description": "Run a shell command",
            "parameters": {
                "type": "object",
                "properties": {
                    "command": {"type": "string", "description": "Command to run"}
                },
                "required": ["command"]
            }
        }
    }
]

# Execute a tool
def execute_tool(name, args):
    if name == "read_file":
        try:
            with open(args["path"]) as f:
                return f.read()
        except Exception as e:
            return f"Error: {e}"

    elif name == "run_command":
        try:
            result = subprocess.run(
                args["command"],
                shell=True,
                capture_output=True,
                text=True,
                timeout=30
            )
            return result.stdout + result.stderr
        except Exception as e:
            return f"Error: {e}"

    return f"Unknown tool: {name}"

# The agent loop
def run_agent(user_message):
    messages = [
        {"role": "system", "content": "You are a helpful coding assistant."},
        {"role": "user", "content": user_message}
    ]

    while True:
        # Get response from LLM
        response = client.chat.completions.create(
            model="gpt-4o",
            messages=messages,
            tools=tools
        )

        message = response.choices[0].message
        messages.append(message)

        # If no tool calls, we're done
        if not message.tool_calls:
            return message.content

        # Execute each tool call
        for tool_call in message.tool_calls:
            name = tool_call.function.name
            args = json.loads(tool_call.function.arguments)

            print(f"🔧 {name}({args})")

            result = execute_tool(name, args)

            messages.append({
                "role": "tool",
                "tool_call_id": tool_call.id,
                "content": str(result)
            })

# Run it
if __name__ == "__main__":
    while True:
        user_input = input("\n> ")
        if user_input.lower() in ["quit", "exit"]:
            break
        response = run_agent(user_input)
        print(f"\n{response}")
```

50 lines. That's your agent.

## Minute 15-20: Test it

```bash
python agent.py
```

Try these:

```
> Read my package.json and tell me what dependencies I have

🔧 read_file({'path': 'package.json'})

You have the following dependencies:
- react: ^18.2.0
- typescript: ^5.0.0
...
```

```
> What files are in the current directory?

🔧 run_command({'command': 'ls -la'})

Here are the files in your directory:
- agent.py (the script you're running)
- package.json
- src/ (directory)
...
```

```
> Find all TODO comments in my code

🔧 run_command({'command': 'grep -r "TODO" . --include="*.py"'})

I found 3 TODO comments:
1. ./agent.py:42 - TODO: add error handling
...
```

It works. You have a working agent.

## Minute 20-25: Add more tools

Let's add search:

```python
# Add to tools list
{
    "type": "function",
    "function": {
        "name": "search",
        "description": "Search for text in files",
        "parameters": {
            "type": "object",
            "properties": {
                "query": {"type": "string", "description": "Text to search for"},
                "path": {"type": "string", "description": "Directory to search in", "default": "."}
            },
            "required": ["query"]
        }
    }
},
{
    "type": "function",
    "function": {
        "name": "write_file",
        "description": "Write content to a file",
        "parameters": {
            "type": "object",
            "properties": {
                "path": {"type": "string", "description": "Path to the file"},
                "content": {"type": "string", "description": "Content to write"}
            },
            "required": ["path", "content"]
        }
    }
}
```

```python
# Add to execute_tool function
elif name == "search":
    try:
        result = subprocess.run(
            f'grep -r "{args["query"]}" {args.get("path", ".")} --include="*.py" --include="*.js" --include="*.ts" | head -20',
            shell=True,
            capture_output=True,
            text=True
        )
        return result.stdout or "No matches found"
    except Exception as e:
        return f"Error: {e}"

elif name == "write_file":
    try:
        with open(args["path"], "w") as f:
            f.write(args["content"])
        return f"Wrote {len(args['content'])} bytes to {args['path']}"
    except Exception as e:
        return f"Error: {e}"
```

Now your agent can read, write, search, and run commands. That covers most coding tasks.

## Minute 25-30: Make it conversational

The agent forgets after each message. Let's fix that:

```python
def run_agent_conversation():
    messages = [
        {"role": "system", "content": "You are a helpful coding assistant."}
    ]

    while True:
        user_input = input("\n> ")
        if user_input.lower() in ["quit", "exit"]:
            break

        messages.append({"role": "user", "content": user_input})

        while True:
            response = client.chat.completions.create(
                model="gpt-4o",
                messages=messages,
                tools=tools
            )

            message = response.choices[0].message
            messages.append(message)

            if not message.tool_calls:
                print(f"\n{message.content}")
                break

            for tool_call in message.tool_calls:
                name = tool_call.function.name
                args = json.loads(tool_call.function.arguments)

                print(f"🔧 {name}({args})")
                result = execute_tool(name, args)

                messages.append({
                    "role": "tool",
                    "tool_call_id": tool_call.id,
                    "content": str(result)[:10000]  # Truncate large results
                })

if __name__ == "__main__":
    run_agent_conversation()
```

Now it remembers the conversation:

```
> Read my config.py file

🔧 read_file({'path': 'config.py'})

Your config.py contains database settings and API keys...

> What database is it using?

Based on the config.py I just read, you're using PostgreSQL
with the connection string: postgresql://localhost:5432/myapp
```

## You're done

In 30 minutes, you built an agent that:
- ✅ Reads files
- ✅ Writes files
- ✅ Searches code
- ✅ Runs commands
- ✅ Maintains conversation context

## The complete code

```python
# agent.py - Complete working agent
import openai
import json
import subprocess

client = openai.OpenAI()

tools = [
    {
        "type": "function",
        "function": {
            "name": "read_file",
            "description": "Read the contents of a file",
            "parameters": {
                "type": "object",
                "properties": {
                    "path": {"type": "string", "description": "Path to the file"}
                },
                "required": ["path"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "write_file",
            "description": "Write content to a file",
            "parameters": {
                "type": "object",
                "properties": {
                    "path": {"type": "string", "description": "Path to the file"},
                    "content": {"type": "string", "description": "Content to write"}
                },
                "required": ["path", "content"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "search",
            "description": "Search for text in files",
            "parameters": {
                "type": "object",
                "properties": {
                    "query": {"type": "string", "description": "Text to search for"}
                },
                "required": ["query"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "run_command",
            "description": "Run a shell command",
            "parameters": {
                "type": "object",
                "properties": {
                    "command": {"type": "string", "description": "Command to run"}
                },
                "required": ["command"]
            }
        }
    }
]

def execute_tool(name, args):
    if name == "read_file":
        try:
            with open(args["path"]) as f:
                return f.read()
        except Exception as e:
            return f"Error: {e}"

    elif name == "write_file":
        try:
            with open(args["path"], "w") as f:
                f.write(args["content"])
            return f"Wrote {len(args['content'])} bytes to {args['path']}"
        except Exception as e:
            return f"Error: {e}"

    elif name == "search":
        try:
            result = subprocess.run(
                f'grep -r "{args["query"]}" . --include="*.py" --include="*.js" | head -20',
                shell=True,
                capture_output=True,
                text=True
            )
            return result.stdout or "No matches found"
        except Exception as e:
            return f"Error: {e}"

    elif name == "run_command":
        try:
            result = subprocess.run(
                args["command"],
                shell=True,
                capture_output=True,
                text=True,
                timeout=30
            )
            return result.stdout + result.stderr
        except Exception as e:
            return f"Error: {e}"

    return f"Unknown tool: {name}"

def main():
    messages = [
        {"role": "system", "content": "You are a helpful coding assistant."}
    ]

    print("Agent ready. Type 'quit' to exit.\n")

    while True:
        user_input = input("> ")
        if user_input.lower() in ["quit", "exit"]:
            break

        messages.append({"role": "user", "content": user_input})

        while True:
            response = client.chat.completions.create(
                model="gpt-4o",
                messages=messages,
                tools=tools
            )

            message = response.choices[0].message
            messages.append(message)

            if not message.tool_calls:
                print(f"\n{message.content}\n")
                break

            for tool_call in message.tool_calls:
                name = tool_call.function.name
                args = json.loads(tool_call.function.arguments)

                print(f"🔧 {name}({args})")
                result = execute_tool(name, args)

                messages.append({
                    "role": "tool",
                    "tool_call_id": tool_call.id,
                    "content": str(result)[:10000]
                })

if __name__ == "__main__":
    main()
```

## Skip the boilerplate

If you want to skip writing tool implementations, use [Gantz](https://gantz.run):

```yaml
# gantz.yaml
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
      shell: echo "{{content}}" > "{{path}}"

  - name: search
    description: Search for text in files
    parameters:
      - name: query
        type: string
        required: true
    script:
      shell: grep -r "{{query}}" . | head -20

  - name: run
    description: Run a shell command
    parameters:
      - name: command
        type: string
        required: true
    script:
      shell: "{{command}}"
```

```bash
gantz
```

Same result. Zero boilerplate.

## What to do next

Now that you have a working agent:

1. **Add more tools** - Database queries, API calls, git operations
2. **Improve the prompt** - Be more specific about behavior
3. **Add guardrails** - Confirm before destructive operations
4. **Handle errors better** - Retry logic, better error messages

But first: use it. Build something. See where it fails.

You learn more from 10 minutes of using a broken agent than 10 hours of reading about perfect architectures.

## Common mistakes to avoid

### Mistake 1: Too many tools

```yaml
# Don't do this
tools:
  - read_file
  - read_file_lines
  - read_file_head
  - read_file_tail
  - read_json
  - read_yaml
  # ... 30 more tools
```

Start with 4-5 tools. Add more only when you need them.

### Mistake 2: Over-engineering

```python
# Don't do this for your first agent
class Agent:
    def __init__(self):
        self.memory = VectorDatabase()
        self.planner = HierarchicalPlanner()
        self.reflector = SelfReflectionModule()
        self.evaluator = QualityEvaluator()
```

The simple loop is enough. Add complexity when you hit real limits.

### Mistake 3: Not testing early

Build → Test → Fix → Repeat

Don't build for a week then test. Build for 5 minutes then test.

## Summary

Building an agent isn't complicated:

1. **API key** (2 minutes)
2. **Core loop**: LLM → Tool → Result → LLM (10 minutes)
3. **Basic tools**: read, write, search, run (10 minutes)
4. **Conversation context** (5 minutes)
5. **Test and iterate** (3 minutes)

Total: 30 minutes to a working agent.

Stop reading tutorials. Start building.

## Related reading

- [Writing Tool Descriptions That Work](/post/tool-descriptions/) - Better tool design
- [The 80/20 Rule for AI Agents](/post/80-20-rule/) - Focus on what matters
- [Error Recovery Patterns for AI Agents](/post/error-recovery/) - When things go wrong

---

*What was the hardest part of building your first agent?*
