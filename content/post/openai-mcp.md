+++
title = "Connect OpenAI GPT to MCP Tools (Step-by-Step)"
image = "images/openai-mcp.webp"
date = 2025-11-06
description = "Integrate OpenAI GPT models with MCP servers. Use function calling with your custom tools through the Model Context Protocol."
summary = "OpenAI's function calling and MCP's tool protocol speak different languages. This guide shows you how to convert MCP tool schemas to OpenAI's function format, handle GPT's function call responses, route them to your MCP server, and return results. Works with GPT-4, GPT-4o, and future models that support function calling."
draft = false
tags = ['mcp', 'tutorial', 'openai']
voice = false

[howto]
name = "Connect OpenAI GPT to MCP"
totalTime = 25
[[howto.steps]]
name = "Set up MCP server"
text = "Create and run an MCP server with your tools."
[[howto.steps]]
name = "Fetch tool definitions"
text = "Get tool schemas from MCP server for OpenAI format."
[[howto.steps]]
name = "Convert to OpenAI format"
text = "Transform MCP tool schemas to OpenAI function definitions."
[[howto.steps]]
name = "Implement the agent loop"
text = "Handle function calls and route to MCP server."
[[howto.steps]]
name = "Test the integration"
text = "Verify GPT can discover and use MCP tools."
+++


OpenAI's GPT models have function calling. MCP has tools.

They're compatible. You just need a bridge.

Here's how to connect them.

## The architecture

```text
User → GPT (OpenAI) → Your Code → MCP Server → Tools
         ↓                ↑
    Function calls    Tool results
```

GPT doesn't speak MCP directly. Your code translates:
1. Fetch tools from MCP server
2. Convert to OpenAI function format
3. Send to GPT
4. When GPT calls a function, route to MCP
5. Return results to GPT

## Step 1: Set up MCP server

First, create an MCP server. Using [Gantz](https://gantz.run):

```yaml
# gantz.yaml
name: gpt-tools

tools:
  - name: read_file
    description: Read the contents of a file
    parameters:
      - name: path
        type: string
        required: true
        description: Path to the file to read
    script:
      shell: cat "{{path}}"

  - name: search_code
    description: Search for text patterns in code files
    parameters:
      - name: query
        type: string
        required: true
        description: Search pattern (regex supported)
      - name: path
        type: string
        default: "."
        description: Directory to search
    script:
      shell: rg "{{query}}" "{{path}}" --max-count 20

  - name: run_command
    description: Execute a shell command
    parameters:
      - name: command
        type: string
        required: true
        description: Command to execute
    script:
      shell: "{{command}}"
```

```bash
gantz run --auth
# Tunnel URL: https://cool-cat.gantz.run
# Auth Token: gtz_abc123
```

## Step 2: Fetch and convert tools

Get tools from MCP and convert to OpenAI format:

```python
import requests
from openai import OpenAI

MCP_URL = "https://cool-cat.gantz.run"
MCP_TOKEN = "gtz_abc123"

def fetch_mcp_tools():
    """Fetch tool definitions from MCP server."""
    response = requests.get(
        f"{MCP_URL}/mcp/tools",
        headers={"Authorization": f"Bearer {MCP_TOKEN}"}
    )
    return response.json().get("tools", [])

def mcp_to_openai_function(mcp_tool):
    """Convert MCP tool schema to OpenAI function format."""
    return {
        "type": "function",
        "function": {
            "name": mcp_tool["name"],
            "description": mcp_tool.get("description", ""),
            "parameters": mcp_tool.get("inputSchema", {
                "type": "object",
                "properties": {},
                "required": []
            })
        }
    }

def get_openai_tools():
    """Get tools in OpenAI format."""
    mcp_tools = fetch_mcp_tools()
    return [mcp_to_openai_function(t) for t in mcp_tools]
```

## Step 3: Call MCP tools

When GPT returns a function call, execute it via MCP:

```python
import json

def call_mcp_tool(tool_name, arguments):
    """Execute a tool via MCP server."""
    response = requests.post(
        f"{MCP_URL}/mcp/tools/call",
        headers={
            "Authorization": f"Bearer {MCP_TOKEN}",
            "Content-Type": "application/json"
        },
        json={
            "tool": tool_name,
            "params": arguments
        }
    )

    if response.status_code != 200:
        return {"error": response.text}

    return response.json().get("result", response.json())
```

## Step 4: The agent loop

Implement the full conversation loop:

```python
from openai import OpenAI

client = OpenAI()

def run_agent(user_message: str, model: str = "gpt-4o"):
    """Run agent with MCP tools."""

    # Get tools from MCP server
    tools = get_openai_tools()

    messages = [
        {"role": "system", "content": "You are a helpful assistant with access to tools."},
        {"role": "user", "content": user_message}
    ]

    while True:
        # Call GPT
        response = client.chat.completions.create(
            model=model,
            messages=messages,
            tools=tools if tools else None,
            tool_choice="auto"
        )

        message = response.choices[0].message

        # Check if GPT wants to use tools
        if message.tool_calls:
            # Add assistant message with tool calls
            messages.append(message)

            # Execute each tool call
            for tool_call in message.tool_calls:
                tool_name = tool_call.function.name
                arguments = json.loads(tool_call.function.arguments)

                print(f"Calling tool: {tool_name}")
                print(f"Arguments: {arguments}")

                # Call MCP tool
                result = call_mcp_tool(tool_name, arguments)

                print(f"Result: {result}")

                # Add tool result to messages
                messages.append({
                    "role": "tool",
                    "tool_call_id": tool_call.id,
                    "content": json.dumps(result) if isinstance(result, dict) else str(result)
                })

            # Continue loop to get GPT's response with tool results
            continue

        # No tool calls - return final response
        return message.content

# Usage
response = run_agent("Read the contents of package.json and tell me what dependencies it has")
print(response)
```

## Step 5: Handle streaming

For better UX, stream responses:

```python
def run_agent_streaming(user_message: str, model: str = "gpt-4o"):
    """Run agent with streaming responses."""

    tools = get_openai_tools()
    messages = [
        {"role": "system", "content": "You are a helpful assistant with access to tools."},
        {"role": "user", "content": user_message}
    ]

    while True:
        # Stream response
        stream = client.chat.completions.create(
            model=model,
            messages=messages,
            tools=tools if tools else None,
            tool_choice="auto",
            stream=True
        )

        # Collect the full response
        collected_content = ""
        collected_tool_calls = []
        current_tool_call = None

        for chunk in stream:
            delta = chunk.choices[0].delta

            # Handle content
            if delta.content:
                collected_content += delta.content
                print(delta.content, end="", flush=True)

            # Handle tool calls
            if delta.tool_calls:
                for tc in delta.tool_calls:
                    if tc.index >= len(collected_tool_calls):
                        collected_tool_calls.append({
                            "id": tc.id,
                            "type": "function",
                            "function": {"name": "", "arguments": ""}
                        })

                    if tc.function.name:
                        collected_tool_calls[tc.index]["function"]["name"] = tc.function.name
                    if tc.function.arguments:
                        collected_tool_calls[tc.index]["function"]["arguments"] += tc.function.arguments

        # Check for tool calls
        if collected_tool_calls:
            # Process tool calls
            messages.append({
                "role": "assistant",
                "content": collected_content or None,
                "tool_calls": collected_tool_calls
            })

            for tool_call in collected_tool_calls:
                tool_name = tool_call["function"]["name"]
                arguments = json.loads(tool_call["function"]["arguments"])

                result = call_mcp_tool(tool_name, arguments)

                messages.append({
                    "role": "tool",
                    "tool_call_id": tool_call["id"],
                    "content": json.dumps(result) if isinstance(result, dict) else str(result)
                })

            continue

        # No tool calls - done
        print()  # New line after streaming
        return collected_content
```

## Complete example

Here's a full working example:

```python
import json
import requests
from openai import OpenAI

# Configuration
MCP_URL = "https://cool-cat.gantz.run"
MCP_TOKEN = "gtz_abc123"
OPENAI_MODEL = "gpt-4o"

client = OpenAI()

def fetch_mcp_tools():
    response = requests.get(
        f"{MCP_URL}/mcp/tools",
        headers={"Authorization": f"Bearer {MCP_TOKEN}"}
    )
    return response.json().get("tools", [])

def mcp_to_openai_function(mcp_tool):
    return {
        "type": "function",
        "function": {
            "name": mcp_tool["name"],
            "description": mcp_tool.get("description", ""),
            "parameters": mcp_tool.get("inputSchema", {"type": "object", "properties": {}})
        }
    }

def call_mcp_tool(tool_name, arguments):
    response = requests.post(
        f"{MCP_URL}/mcp/tools/call",
        headers={"Authorization": f"Bearer {MCP_TOKEN}"},
        json={"tool": tool_name, "params": arguments}
    )
    return response.json().get("result", response.json())

def chat(user_message):
    tools = [mcp_to_openai_function(t) for t in fetch_mcp_tools()]
    messages = [{"role": "user", "content": user_message}]

    while True:
        response = client.chat.completions.create(
            model=OPENAI_MODEL,
            messages=messages,
            tools=tools
        )

        message = response.choices[0].message

        if message.tool_calls:
            messages.append(message)

            for tc in message.tool_calls:
                result = call_mcp_tool(
                    tc.function.name,
                    json.loads(tc.function.arguments)
                )
                messages.append({
                    "role": "tool",
                    "tool_call_id": tc.id,
                    "content": str(result)
                })
            continue

        return message.content

# Use it
if __name__ == "__main__":
    while True:
        user_input = input("\nYou: ")
        if user_input.lower() in ["quit", "exit"]:
            break

        response = chat(user_input)
        print(f"\nGPT: {response}")
```

## Error handling

Handle common errors gracefully:

```python
def call_mcp_tool_safe(tool_name, arguments):
    """Call MCP tool with error handling."""
    try:
        response = requests.post(
            f"{MCP_URL}/mcp/tools/call",
            headers={"Authorization": f"Bearer {MCP_TOKEN}"},
            json={"tool": tool_name, "params": arguments},
            timeout=30
        )

        if response.status_code == 401:
            return {"error": "Authentication failed. Check MCP token."}

        if response.status_code == 404:
            return {"error": f"Tool '{tool_name}' not found."}

        if response.status_code == 429:
            return {"error": "Rate limited. Please wait."}

        if response.status_code != 200:
            return {"error": f"MCP error: {response.text}"}

        return response.json().get("result", response.json())

    except requests.exceptions.Timeout:
        return {"error": "Tool execution timed out."}

    except requests.exceptions.ConnectionError:
        return {"error": "Cannot connect to MCP server."}

    except Exception as e:
        return {"error": f"Unexpected error: {str(e)}"}
```

## Using with LangChain

If you prefer LangChain:

```python
from langchain_openai import ChatOpenAI
from langchain.tools import StructuredTool
from langchain.agents import AgentExecutor, create_openai_tools_agent
from langchain_core.prompts import ChatPromptTemplate

# Create tools from MCP
def create_langchain_tools():
    mcp_tools = fetch_mcp_tools()
    tools = []

    for mcp_tool in mcp_tools:
        def make_tool_func(name):
            def tool_func(**kwargs):
                return call_mcp_tool(name, kwargs)
            return tool_func

        tool = StructuredTool.from_function(
            func=make_tool_func(mcp_tool["name"]),
            name=mcp_tool["name"],
            description=mcp_tool.get("description", ""),
            args_schema=mcp_tool.get("inputSchema")
        )
        tools.append(tool)

    return tools

# Create agent
llm = ChatOpenAI(model="gpt-4o")
tools = create_langchain_tools()
prompt = ChatPromptTemplate.from_messages([
    ("system", "You are a helpful assistant."),
    ("human", "{input}"),
    ("placeholder", "{agent_scratchpad}")
])

agent = create_openai_tools_agent(llm, tools, prompt)
executor = AgentExecutor(agent=agent, tools=tools, verbose=True)

# Use
result = executor.invoke({"input": "List files in the current directory"})
```

## Summary

Connecting OpenAI GPT to MCP:

1. **Run MCP server** with [Gantz](https://gantz.run) or custom
2. **Fetch tools** from MCP endpoint
3. **Convert format** from MCP to OpenAI functions
4. **Implement loop** that handles function calls
5. **Route calls** to MCP server

GPT gains access to all your MCP tools. Same tools work with Claude, Gemini, or any MCP-compatible client.

Build once, use everywhere.

## Related reading

- [Google Gemini + MCP Integration](/post/gemini-mcp/) - Connect Gemini
- [LangChain MCP Integration](/post/langchain-mcp/) - Use with LangChain
- [MCP vs Function Calling](/post/mcp-vs-function-calling/) - Understanding the difference

---

*Have you connected GPT to MCP? Share your integration patterns.*
