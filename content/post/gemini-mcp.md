+++
title = "Google Gemini + MCP: Full Integration Tutorial"
image = "images/gemini-mcp.webp"
date = 2025-11-05
description = "Connect Google Gemini to MCP servers. Use function calling with your custom tools through the Model Context Protocol."
draft = false
tags = ['mcp', 'tutorial', 'gemini']
voice = false
summary = "Google Gemini uses function calling, MCP uses tools - this guide bridges the gap. Learn to convert MCP tool definitions into Gemini function declarations, handle Gemini's function call responses, route them back to your MCP server, and return results. Works with Gemini Pro and Ultra models through the google-generativeai SDK."

[howto]
name = "Connect Gemini to MCP"
totalTime = 25
[[howto.steps]]
name = "Set up MCP server"
text = "Create and run an MCP server with your tools."
[[howto.steps]]
name = "Install Gemini SDK"
text = "Install google-generativeai Python package."
[[howto.steps]]
name = "Convert tool schemas"
text = "Transform MCP tools to Gemini function declarations."
[[howto.steps]]
name = "Implement agent loop"
text = "Handle function calls and route to MCP server."
[[howto.steps]]
name = "Test integration"
text = "Verify Gemini can discover and use MCP tools."
+++


Google Gemini has function calling. MCP has tools.

Let's connect them.

## The architecture

```text
User → Gemini (Google) → Your Code → MCP Server → Tools
            ↓                ↑
     Function calls     Tool results
```

Gemini doesn't speak MCP natively. Your code bridges the gap:
1. Fetch tools from MCP server
2. Convert to Gemini function declarations
3. Send to Gemini
4. When Gemini calls a function, route to MCP
5. Return results to Gemini

## Prerequisites

```bash
pip install google-generativeai requests
```

Get a Gemini API key from [Google AI Studio](https://aistudio.google.com/).

## Step 1: Set up MCP server

Using [Gantz](https://gantz.run):

```yaml
# gantz.yaml
name: gemini-tools

tools:
  - name: read_file
    description: Read the contents of a file from the filesystem
    parameters:
      - name: path
        type: string
        required: true
        description: Path to the file to read
    script:
      shell: cat "{{path}}"

  - name: write_file
    description: Write content to a file
    parameters:
      - name: path
        type: string
        required: true
        description: Path to write to
      - name: content
        type: string
        required: true
        description: Content to write
    script:
      shell: echo "{{content}}" > "{{path}}"

  - name: list_directory
    description: List files and directories
    parameters:
      - name: path
        type: string
        default: "."
        description: Directory path
    script:
      shell: ls -la "{{path}}"
```

```bash
gantz run --auth
# Tunnel URL: https://happy-dog.gantz.run
# Auth Token: gtz_xyz789
```

## Step 2: Fetch and convert tools

Convert MCP tools to Gemini format:

```python
import requests
import google.generativeai as genai
from google.generativeai.types import FunctionDeclaration, Tool

MCP_URL = "https://happy-dog.gantz.run"
MCP_TOKEN = "gtz_xyz789"

def fetch_mcp_tools():
    """Fetch tool definitions from MCP server."""
    response = requests.get(
        f"{MCP_URL}/mcp/tools",
        headers={"Authorization": f"Bearer {MCP_TOKEN}"}
    )
    return response.json().get("tools", [])

def mcp_schema_to_gemini(schema):
    """Convert MCP/JSON Schema to Gemini Schema format."""
    if not schema:
        return {}

    gemini_schema = {"type": schema.get("type", "object").upper()}

    if "properties" in schema:
        gemini_schema["properties"] = {}
        for name, prop in schema["properties"].items():
            gemini_schema["properties"][name] = {
                "type": prop.get("type", "string").upper(),
                "description": prop.get("description", "")
            }

    if "required" in schema:
        gemini_schema["required"] = schema["required"]

    return gemini_schema

def mcp_to_gemini_function(mcp_tool):
    """Convert MCP tool to Gemini FunctionDeclaration."""
    return FunctionDeclaration(
        name=mcp_tool["name"],
        description=mcp_tool.get("description", ""),
        parameters=mcp_schema_to_gemini(mcp_tool.get("inputSchema", {}))
    )

def get_gemini_tools():
    """Get tools in Gemini format."""
    mcp_tools = fetch_mcp_tools()
    function_declarations = [mcp_to_gemini_function(t) for t in mcp_tools]
    return Tool(function_declarations=function_declarations)
```

## Step 3: Call MCP tools

Execute tools via MCP server:

```python
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
            "params": dict(arguments) if arguments else {}
        }
    )

    if response.status_code != 200:
        return {"error": response.text}

    return response.json().get("result", response.json())
```

## Step 4: The agent loop

Implement the conversation loop:

```python
import google.generativeai as genai
from google.generativeai.types import content_types

# Configure Gemini
genai.configure(api_key="YOUR_GEMINI_API_KEY")

def run_agent(user_message: str, model_name: str = "gemini-1.5-pro"):
    """Run agent with MCP tools."""

    # Get tools from MCP server
    tools = get_gemini_tools()

    # Create model with tools
    model = genai.GenerativeModel(
        model_name=model_name,
        tools=[tools]
    )

    # Start chat
    chat = model.start_chat()

    # Send user message
    response = chat.send_message(user_message)

    # Handle function calls
    while response.candidates[0].content.parts:
        part = response.candidates[0].content.parts[0]

        # Check if it's a function call
        if hasattr(part, 'function_call') and part.function_call:
            function_call = part.function_call
            tool_name = function_call.name
            arguments = function_call.args

            print(f"Calling tool: {tool_name}")
            print(f"Arguments: {dict(arguments)}")

            # Execute MCP tool
            result = call_mcp_tool(tool_name, arguments)

            print(f"Result: {result}")

            # Send function response back to Gemini
            response = chat.send_message(
                content_types.to_content({
                    "function_response": {
                        "name": tool_name,
                        "response": {"result": result}
                    }
                })
            )
            continue

        # No function call - return text response
        if hasattr(part, 'text'):
            return part.text

    return "No response generated"

# Usage
response = run_agent("List all files in the current directory")
print(response)
```

## Step 5: Handle multiple function calls

Gemini can request multiple function calls:

```python
def run_agent_multi(user_message: str, model_name: str = "gemini-1.5-pro"):
    """Run agent handling multiple function calls."""

    tools = get_gemini_tools()
    model = genai.GenerativeModel(model_name=model_name, tools=[tools])
    chat = model.start_chat()

    response = chat.send_message(user_message)

    while True:
        function_calls = []

        # Collect all function calls from response
        for part in response.candidates[0].content.parts:
            if hasattr(part, 'function_call') and part.function_call:
                function_calls.append(part.function_call)
            elif hasattr(part, 'text') and part.text:
                # Got text response - we're done
                return part.text

        if not function_calls:
            break

        # Execute all function calls
        function_responses = []
        for fc in function_calls:
            print(f"Calling: {fc.name}({dict(fc.args)})")
            result = call_mcp_tool(fc.name, fc.args)
            function_responses.append({
                "function_response": {
                    "name": fc.name,
                    "response": {"result": result}
                }
            })

        # Send all responses back
        response = chat.send_message(
            [content_types.to_content(fr) for fr in function_responses]
        )

    return "No response generated"
```

## Complete example

Full working code:

```python
import requests
import google.generativeai as genai
from google.generativeai.types import FunctionDeclaration, Tool, content_types

# Configuration
MCP_URL = "https://happy-dog.gantz.run"
MCP_TOKEN = "gtz_xyz789"
GEMINI_API_KEY = "your-gemini-api-key"

genai.configure(api_key=GEMINI_API_KEY)

# MCP functions
def fetch_mcp_tools():
    response = requests.get(
        f"{MCP_URL}/mcp/tools",
        headers={"Authorization": f"Bearer {MCP_TOKEN}"}
    )
    return response.json().get("tools", [])

def call_mcp_tool(tool_name, arguments):
    response = requests.post(
        f"{MCP_URL}/mcp/tools/call",
        headers={"Authorization": f"Bearer {MCP_TOKEN}"},
        json={"tool": tool_name, "params": dict(arguments) if arguments else {}}
    )
    return response.json().get("result", response.json())

# Schema conversion
def mcp_schema_to_gemini(schema):
    if not schema:
        return {}

    result = {"type": schema.get("type", "object").upper()}

    if "properties" in schema:
        result["properties"] = {
            name: {
                "type": prop.get("type", "string").upper(),
                "description": prop.get("description", "")
            }
            for name, prop in schema["properties"].items()
        }

    if "required" in schema:
        result["required"] = schema["required"]

    return result

def get_gemini_tools():
    mcp_tools = fetch_mcp_tools()
    declarations = [
        FunctionDeclaration(
            name=t["name"],
            description=t.get("description", ""),
            parameters=mcp_schema_to_gemini(t.get("inputSchema", {}))
        )
        for t in mcp_tools
    ]
    return Tool(function_declarations=declarations)

# Agent
def chat(user_message):
    tools = get_gemini_tools()
    model = genai.GenerativeModel("gemini-1.5-pro", tools=[tools])
    chat_session = model.start_chat()

    response = chat_session.send_message(user_message)

    while True:
        function_calls = []

        for part in response.candidates[0].content.parts:
            if hasattr(part, 'function_call') and part.function_call:
                function_calls.append(part.function_call)
            elif hasattr(part, 'text') and part.text:
                return part.text

        if not function_calls:
            break

        responses = []
        for fc in function_calls:
            result = call_mcp_tool(fc.name, fc.args)
            responses.append({
                "function_response": {
                    "name": fc.name,
                    "response": {"result": result}
                }
            })

        response = chat_session.send_message(
            [content_types.to_content(r) for r in responses]
        )

    return "No response"

# Interactive loop
if __name__ == "__main__":
    print("Gemini + MCP Agent")
    print("Type 'quit' to exit\n")

    while True:
        user_input = input("You: ")
        if user_input.lower() in ["quit", "exit"]:
            break

        response = chat(user_input)
        print(f"\nGemini: {response}\n")
```

## Error handling

Handle errors gracefully:

```python
def call_mcp_tool_safe(tool_name, arguments):
    """Call MCP tool with error handling."""
    try:
        response = requests.post(
            f"{MCP_URL}/mcp/tools/call",
            headers={"Authorization": f"Bearer {MCP_TOKEN}"},
            json={"tool": tool_name, "params": dict(arguments) if arguments else {}},
            timeout=30
        )

        if response.status_code == 401:
            return {"error": "Authentication failed"}
        if response.status_code == 404:
            return {"error": f"Tool '{tool_name}' not found"}
        if response.status_code != 200:
            return {"error": f"MCP error: {response.text}"}

        return response.json().get("result", response.json())

    except requests.exceptions.Timeout:
        return {"error": "Tool execution timed out"}
    except requests.exceptions.ConnectionError:
        return {"error": "Cannot connect to MCP server"}
    except Exception as e:
        return {"error": str(e)}
```

## Gemini-specific features

### System instructions

```python
model = genai.GenerativeModel(
    "gemini-1.5-pro",
    tools=[tools],
    system_instruction="""You are a helpful coding assistant.
    Use the available tools to help users with file operations and code tasks.
    Always explain what you're doing before using tools."""
)
```

### Safety settings

```python
from google.generativeai.types import HarmCategory, HarmBlockThreshold

model = genai.GenerativeModel(
    "gemini-1.5-pro",
    tools=[tools],
    safety_settings={
        HarmCategory.HARM_CATEGORY_HARASSMENT: HarmBlockThreshold.BLOCK_NONE,
        HarmCategory.HARM_CATEGORY_HATE_SPEECH: HarmBlockThreshold.BLOCK_NONE,
    }
)
```

### Generation config

```python
model = genai.GenerativeModel(
    "gemini-1.5-pro",
    tools=[tools],
    generation_config={
        "temperature": 0.7,
        "top_p": 0.95,
        "max_output_tokens": 2048,
    }
)
```

## Summary

Connecting Gemini to MCP:

1. **Run MCP server** with [Gantz](https://gantz.run) or custom
2. **Convert schemas** from MCP to Gemini format
3. **Create model** with function declarations
4. **Handle function calls** in chat loop
5. **Route calls** to MCP server

Same MCP tools work with Gemini, GPT, Claude, or any MCP-compatible client.

Build once, use everywhere.

## Related reading

- [Connect OpenAI GPT to MCP](/post/openai-mcp/) - GPT integration
- [LangChain MCP Integration](/post/langchain-mcp/) - Use with LangChain
- [MCP vs Function Calling](/post/mcp-vs-function-calling/) - Understanding the difference

---

*Have you connected Gemini to MCP? Share your setup.*
