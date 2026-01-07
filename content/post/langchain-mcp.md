+++
title = "LangChain MCP Integration: Use Any Tool"
image = "/images/langchain-mcp.png"
date = 2025-11-04
description = "Connect LangChain to MCP servers. Use your custom tools with any LLM through the LangChain agent framework."
draft = false
tags = ['mcp', 'tutorial', 'langchain']
voice = false

[howto]
name = "Integrate LangChain with MCP"
totalTime = 20
[[howto.steps]]
name = "Install dependencies"
text = "Install LangChain and MCP client packages."
[[howto.steps]]
name = "Create MCP tool wrapper"
text = "Build a LangChain tool class that calls MCP."
[[howto.steps]]
name = "Fetch tools dynamically"
text = "Get tool definitions from MCP server at runtime."
[[howto.steps]]
name = "Create agent"
text = "Build a LangChain agent with MCP tools."
[[howto.steps]]
name = "Run queries"
text = "Execute tasks using the agent with MCP tools."
+++


LangChain agents need tools. MCP provides tools.

Perfect match.

Here's how to connect them.

## Why LangChain + MCP?

LangChain gives you:
- Agent frameworks (ReAct, OpenAI functions, etc.)
- Memory management
- Chain composition
- Multiple LLM support

MCP gives you:
- Standardized tool interface
- Remote tool execution
- Tool discovery
- Authentication

Together: powerful agents with any tools, any LLM.

## Prerequisites

```bash
pip install langchain langchain-openai requests
```

## Step 1: Set up MCP server

Using [Gantz](https://gantz.run):

```yaml
# gantz.yaml
name: langchain-tools

tools:
  - name: read_file
    description: Read file contents from the filesystem
    parameters:
      - name: path
        type: string
        required: true
        description: Path to the file
    script:
      shell: cat "{{path}}"

  - name: write_file
    description: Write content to a file
    parameters:
      - name: path
        type: string
        required: true
      - name: content
        type: string
        required: true
    script:
      shell: echo "{{content}}" > "{{path}}"

  - name: search_code
    description: Search for patterns in code files
    parameters:
      - name: query
        type: string
        required: true
        description: Search pattern (regex)
      - name: path
        type: string
        default: "."
    script:
      shell: rg "{{query}}" "{{path}}" --max-count 20
```

```bash
gantz run --auth
# Tunnel URL: https://smart-fox.gantz.run
# Auth Token: gtz_abc123
```

## Step 2: Create MCP tool wrapper

Build a LangChain tool that wraps MCP:

```python
import requests
from typing import Any, Dict, Optional, Type
from langchain.tools import BaseTool
from pydantic import BaseModel, Field, create_model

class MCPClient:
    """Client for interacting with MCP servers."""

    def __init__(self, url: str, token: str):
        self.url = url.rstrip('/')
        self.token = token
        self.headers = {
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json"
        }

    def list_tools(self) -> list:
        """Fetch available tools from MCP server."""
        response = requests.get(
            f"{self.url}/mcp/tools",
            headers=self.headers
        )
        response.raise_for_status()
        return response.json().get("tools", [])

    def call_tool(self, name: str, params: dict) -> Any:
        """Execute a tool on the MCP server."""
        response = requests.post(
            f"{self.url}/mcp/tools/call",
            headers=self.headers,
            json={"tool": name, "params": params}
        )
        response.raise_for_status()
        return response.json().get("result", response.json())


def create_mcp_tool(mcp_client: MCPClient, tool_def: dict) -> BaseTool:
    """Create a LangChain tool from MCP tool definition."""

    tool_name = tool_def["name"]
    tool_description = tool_def.get("description", "")
    input_schema = tool_def.get("inputSchema", {})

    # Build Pydantic model for args
    fields = {}
    properties = input_schema.get("properties", {})
    required = input_schema.get("required", [])

    for prop_name, prop_def in properties.items():
        prop_type = prop_def.get("type", "string")
        prop_desc = prop_def.get("description", "")
        default = ... if prop_name in required else prop_def.get("default", None)

        # Map JSON Schema types to Python types
        type_map = {
            "string": str,
            "integer": int,
            "number": float,
            "boolean": bool,
            "array": list,
            "object": dict
        }
        python_type = type_map.get(prop_type, str)

        fields[prop_name] = (
            python_type,
            Field(default=default, description=prop_desc)
        )

    # Create args schema
    ArgsSchema = create_model(f"{tool_name}Args", **fields) if fields else None

    class MCPTool(BaseTool):
        name: str = tool_name
        description: str = tool_description
        args_schema: Optional[Type[BaseModel]] = ArgsSchema

        def _run(self, **kwargs) -> str:
            result = mcp_client.call_tool(tool_name, kwargs)
            return str(result)

        async def _arun(self, **kwargs) -> str:
            # For async, you'd use aiohttp
            return self._run(**kwargs)

    return MCPTool()
```

## Step 3: Load tools dynamically

Fetch tools from MCP at runtime:

```python
def load_mcp_tools(mcp_url: str, mcp_token: str) -> list:
    """Load all tools from an MCP server as LangChain tools."""

    client = MCPClient(mcp_url, mcp_token)
    tool_defs = client.list_tools()

    tools = []
    for tool_def in tool_defs:
        try:
            tool = create_mcp_tool(client, tool_def)
            tools.append(tool)
            print(f"Loaded tool: {tool.name}")
        except Exception as e:
            print(f"Failed to load {tool_def['name']}: {e}")

    return tools

# Load tools
MCP_URL = "https://smart-fox.gantz.run"
MCP_TOKEN = "gtz_abc123"

tools = load_mcp_tools(MCP_URL, MCP_TOKEN)
```

## Step 4: Create agent

Build a LangChain agent with MCP tools:

```python
from langchain_openai import ChatOpenAI
from langchain.agents import AgentExecutor, create_openai_tools_agent
from langchain_core.prompts import ChatPromptTemplate, MessagesPlaceholder

# Load MCP tools
tools = load_mcp_tools(MCP_URL, MCP_TOKEN)

# Create LLM
llm = ChatOpenAI(model="gpt-4o", temperature=0)

# Create prompt
prompt = ChatPromptTemplate.from_messages([
    ("system", "You are a helpful assistant with access to various tools. "
               "Use them to help users with their tasks."),
    ("human", "{input}"),
    MessagesPlaceholder(variable_name="agent_scratchpad")
])

# Create agent
agent = create_openai_tools_agent(llm, tools, prompt)

# Create executor
executor = AgentExecutor(
    agent=agent,
    tools=tools,
    verbose=True,
    handle_parsing_errors=True
)

# Run
result = executor.invoke({"input": "Read the contents of package.json"})
print(result["output"])
```

## Step 5: Use with different LLMs

### With Claude

```python
from langchain_anthropic import ChatAnthropic

llm = ChatAnthropic(model="claude-sonnet-4-20250514", temperature=0)
agent = create_openai_tools_agent(llm, tools, prompt)
executor = AgentExecutor(agent=agent, tools=tools, verbose=True)
```

### With local models

```python
from langchain_community.llms import Ollama

llm = Ollama(model="llama2")
# Use ReAct agent for models without native function calling
from langchain.agents import create_react_agent

react_prompt = ChatPromptTemplate.from_template("""
Answer the following questions as best you can. You have access to the following tools:

{tools}

Use the following format:

Question: the input question you must answer
Thought: you should always think about what to do
Action: the action to take, should be one of [{tool_names}]
Action Input: the input to the action
Observation: the result of the action
... (this Thought/Action/Action Input/Observation can repeat N times)
Thought: I now know the final answer
Final Answer: the final answer to the original input question

Begin!

Question: {input}
Thought:{agent_scratchpad}
""")

agent = create_react_agent(llm, tools, react_prompt)
executor = AgentExecutor(agent=agent, tools=tools, verbose=True)
```

## Complete example

```python
import requests
from typing import Any, Dict, Optional, Type
from langchain.tools import BaseTool
from langchain_openai import ChatOpenAI
from langchain.agents import AgentExecutor, create_openai_tools_agent
from langchain_core.prompts import ChatPromptTemplate, MessagesPlaceholder
from pydantic import BaseModel, Field, create_model

# Configuration
MCP_URL = "https://smart-fox.gantz.run"
MCP_TOKEN = "gtz_abc123"

class MCPClient:
    def __init__(self, url: str, token: str):
        self.url = url.rstrip('/')
        self.headers = {"Authorization": f"Bearer {token}"}

    def list_tools(self):
        resp = requests.get(f"{self.url}/mcp/tools", headers=self.headers)
        return resp.json().get("tools", [])

    def call_tool(self, name: str, params: dict):
        resp = requests.post(
            f"{self.url}/mcp/tools/call",
            headers=self.headers,
            json={"tool": name, "params": params}
        )
        return resp.json().get("result", resp.json())

def create_mcp_tool(client: MCPClient, tool_def: dict) -> BaseTool:
    tool_name = tool_def["name"]
    schema = tool_def.get("inputSchema", {})

    # Build args schema
    fields = {}
    for name, prop in schema.get("properties", {}).items():
        required = name in schema.get("required", [])
        fields[name] = (
            str,
            Field(default=... if required else None, description=prop.get("description", ""))
        )

    ArgsSchema = create_model(f"{tool_name}Args", **fields) if fields else None

    class Tool(BaseTool):
        name: str = tool_name
        description: str = tool_def.get("description", "")
        args_schema: Optional[Type[BaseModel]] = ArgsSchema

        def _run(self, **kwargs):
            return str(client.call_tool(tool_name, kwargs))

    return Tool()

def create_agent(mcp_url: str, mcp_token: str):
    # Load tools
    client = MCPClient(mcp_url, mcp_token)
    tools = [create_mcp_tool(client, t) for t in client.list_tools()]

    # Create agent
    llm = ChatOpenAI(model="gpt-4o")
    prompt = ChatPromptTemplate.from_messages([
        ("system", "You are a helpful assistant with tools."),
        ("human", "{input}"),
        MessagesPlaceholder(variable_name="agent_scratchpad")
    ])

    agent = create_openai_tools_agent(llm, tools, prompt)
    return AgentExecutor(agent=agent, tools=tools, verbose=True)

# Usage
if __name__ == "__main__":
    agent = create_agent(MCP_URL, MCP_TOKEN)

    while True:
        user_input = input("\nYou: ")
        if user_input.lower() in ["quit", "exit"]:
            break

        result = agent.invoke({"input": user_input})
        print(f"\nAgent: {result['output']}")
```

## Advanced: MCP Toolkit

Create a reusable toolkit:

```python
from langchain.tools import BaseToolkit

class MCPToolkit(BaseToolkit):
    """Toolkit for MCP server tools."""

    mcp_url: str
    mcp_token: str
    _client: MCPClient = None
    _tools: list = None

    class Config:
        arbitrary_types_allowed = True

    @property
    def client(self):
        if self._client is None:
            self._client = MCPClient(self.mcp_url, self.mcp_token)
        return self._client

    def get_tools(self) -> list:
        if self._tools is None:
            self._tools = [
                create_mcp_tool(self.client, t)
                for t in self.client.list_tools()
            ]
        return self._tools

# Usage
toolkit = MCPToolkit(mcp_url=MCP_URL, mcp_token=MCP_TOKEN)
tools = toolkit.get_tools()
```

## With memory

Add conversation memory:

```python
from langchain.memory import ConversationBufferMemory

memory = ConversationBufferMemory(
    memory_key="chat_history",
    return_messages=True
)

prompt = ChatPromptTemplate.from_messages([
    ("system", "You are a helpful assistant."),
    MessagesPlaceholder(variable_name="chat_history"),
    ("human", "{input}"),
    MessagesPlaceholder(variable_name="agent_scratchpad")
])

executor = AgentExecutor(
    agent=agent,
    tools=tools,
    memory=memory,
    verbose=True
)
```

## Error handling

```python
from langchain.callbacks import StdOutCallbackHandler

class ErrorHandlingExecutor(AgentExecutor):
    def invoke(self, inputs, **kwargs):
        try:
            return super().invoke(inputs, **kwargs)
        except Exception as e:
            return {"output": f"Error: {str(e)}"}

executor = ErrorHandlingExecutor(
    agent=agent,
    tools=tools,
    handle_parsing_errors=True,
    max_iterations=10,
    callbacks=[StdOutCallbackHandler()]
)
```

## Summary

LangChain + MCP gives you:

1. **Dynamic tools** - Load from any MCP server
2. **LLM flexibility** - Works with any model
3. **Agent patterns** - ReAct, OpenAI functions, etc.
4. **Memory** - Conversation context
5. **Composability** - Chain multiple agents

Build tools once with [Gantz](https://gantz.run), use them with any LangChain agent.

## Related reading

- [Connect OpenAI GPT to MCP](/post/openai-mcp/) - Direct OpenAI integration
- [Google Gemini + MCP](/post/gemini-mcp/) - Gemini integration
- [MCP vs ReAct](/post/mcp-vs-react/) - Understanding the patterns

---

*How do you use MCP with LangChain? Share your patterns.*
