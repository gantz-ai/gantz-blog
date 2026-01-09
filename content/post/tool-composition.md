+++
title = "MCP Tool Composition: Combine Tools for Power"
image = "images/tool-composition.webp"
date = 2025-11-13
description = "Compose MCP tools to create powerful capabilities. Build composite tools, tool pipelines, and orchestration patterns for AI agents."
summary = "A search tool and a summarize tool aren't that useful alone. Compose them into a research tool that searches, reads, and summarizes in one call. Learn pipe patterns that chain tool outputs to inputs, combine patterns that run tools in parallel and merge results, and orchestration patterns for complex multi-step workflows. Build powerful compound capabilities from simple primitives."
draft = false
tags = ['mcp', 'tools', 'composition']
voice = false

[howto]
name = "Compose MCP Tools"
totalTime = 30
[[howto.steps]]
name = "Identify composable tools"
text = "Find tools that work well together."
[[howto.steps]]
name = "Define composition patterns"
text = "Choose pipe, combine, or orchestrate patterns."
[[howto.steps]]
name = "Build composite tools"
text = "Create new tools from existing ones."
[[howto.steps]]
name = "Handle data transformation"
text = "Transform outputs between tools."
[[howto.steps]]
name = "Test compositions"
text = "Verify composite tools work correctly."
+++


One tool does one thing.

Combine tools, do more.

That's composition.

## Why compose tools?

Individual tools are limited. Composition enables:
- **Complex workflows** - Multi-step processes
- **Reusability** - Combine existing tools
- **Abstraction** - Hide complexity
- **Flexibility** - Mix and match

## Composition patterns

```text
Pipe:        A | B | C        (output → input)
Combine:     [A, B, C] → D    (parallel → merge)
Orchestrate: D(A, B, C)       (coordinator)
Transform:   A → T → B        (adapt between)
```

## Step 1: Basic pipe composition

Using [Gantz](https://gantz.run):

```yaml
# gantz.yaml
name: composed-tools

tools:
  # Individual tools
  - name: fetch_data
    description: Fetch data from API
    parameters:
      - name: url
        type: string
        required: true
    script:
      shell: curl -s "{{url}}"

  - name: parse_json
    description: Parse JSON and extract field
    parameters:
      - name: json_data
        type: string
        required: true
      - name: field
        type: string
        required: true
    script:
      shell: echo '{{json_data}}' | jq -r '.{{field}}'

  - name: format_output
    description: Format data for display
    parameters:
      - name: data
        type: string
        required: true
      - name: format
        type: string
        default: "table"
    script:
      command: python
      args: ["scripts/format.py", "{{data}}", "{{format}}"]

  # Composed tool
  - name: fetch_and_display
    description: Fetch API data and display formatted
    parameters:
      - name: url
        type: string
        required: true
      - name: field
        type: string
        required: true
      - name: format
        type: string
        default: "table"
    script:
      shell: |
        data=$(curl -s "{{url}}")
        extracted=$(echo "$data" | jq -r '.{{field}}')
        python scripts/format.py "$extracted" "{{format}}"
```

Python composition framework:

```python
from typing import Callable, Any, Dict, List, Optional
from dataclasses import dataclass
import subprocess

@dataclass
class Tool:
    """Represents an MCP tool."""
    name: str
    executor: Callable[[Dict[str, Any]], Any]
    input_schema: Dict[str, Any]
    output_type: str = "string"

class ToolComposer:
    """Compose tools into pipelines."""

    def __init__(self):
        self.tools: Dict[str, Tool] = {}

    def register(self, tool: Tool):
        """Register a tool."""
        self.tools[tool.name] = tool

    def pipe(self, *tool_names: str, transformers: Dict[str, Callable] = None) -> Tool:
        """Create a pipe composition: A | B | C."""

        transformers = transformers or {}

        def executor(params: Dict[str, Any]) -> Any:
            result = params

            for i, name in enumerate(tool_names):
                tool = self.tools[name]

                # Apply transformer if exists
                if name in transformers:
                    result = transformers[name](result)

                # Execute tool
                result = tool.executor(result if isinstance(result, dict) else {"input": result})

            return result

        return Tool(
            name=f"pipe_{'_'.join(tool_names)}",
            executor=executor,
            input_schema=self.tools[tool_names[0]].input_schema
        )

    def combine(
        self,
        tool_names: List[str],
        merger: Callable[[List[Any]], Any]
    ) -> Tool:
        """Create a combine composition: [A, B, C] → merge."""

        def executor(params: Dict[str, Any]) -> Any:
            results = []

            for name in tool_names:
                tool = self.tools[name]
                result = tool.executor(params)
                results.append(result)

            return merger(results)

        return Tool(
            name=f"combine_{'_'.join(tool_names)}",
            executor=executor,
            input_schema={}  # Union of all schemas
        )

    def orchestrate(
        self,
        coordinator: Callable[[Dict[str, Tool], Dict[str, Any]], Any],
        tool_names: List[str]
    ) -> Tool:
        """Create an orchestrated composition."""

        available_tools = {name: self.tools[name] for name in tool_names}

        def executor(params: Dict[str, Any]) -> Any:
            return coordinator(available_tools, params)

        return Tool(
            name=f"orchestrate_{'_'.join(tool_names)}",
            executor=executor,
            input_schema={}
        )

# Define tools
def fetch_data(params: Dict[str, Any]) -> str:
    result = subprocess.run(
        ["curl", "-s", params["url"]],
        capture_output=True, text=True
    )
    return result.stdout

def parse_json(params: Dict[str, Any]) -> Any:
    import json
    data = json.loads(params["input"])
    return data.get(params.get("field", "data"))

def format_output(params: Dict[str, Any]) -> str:
    data = params["input"]
    fmt = params.get("format", "text")

    if fmt == "json":
        import json
        return json.dumps(data, indent=2)
    elif fmt == "csv":
        if isinstance(data, list):
            return "\n".join(str(item) for item in data)
    return str(data)

# Compose
composer = ToolComposer()

composer.register(Tool("fetch", fetch_data, {"url": "string"}))
composer.register(Tool("parse", parse_json, {"input": "string", "field": "string"}))
composer.register(Tool("format", format_output, {"input": "any", "format": "string"}))

# Create pipe: fetch | parse | format
fetch_parse_format = composer.pipe(
    "fetch", "parse", "format",
    transformers={
        "parse": lambda result: {"input": result, "field": "items"},
        "format": lambda result: {"input": result, "format": "json"}
    }
)

# Use composed tool
result = fetch_parse_format.executor({"url": "https://api.example.com/data"})
```

## Step 2: Parallel composition

Execute tools concurrently and merge:

```python
from concurrent.futures import ThreadPoolExecutor, as_completed
from typing import List, Any

class ParallelComposer:
    """Compose tools for parallel execution."""

    def __init__(self, max_workers: int = 5):
        self.executor = ThreadPoolExecutor(max_workers=max_workers)
        self.tools: Dict[str, Tool] = {}

    def register(self, tool: Tool):
        self.tools[tool.name] = tool

    def parallel(
        self,
        tool_configs: List[Dict[str, Any]],
        merger: Callable[[Dict[str, Any]], Any]
    ) -> Tool:
        """Execute tools in parallel and merge results."""

        def executor(params: Dict[str, Any]) -> Any:
            futures = {}

            for config in tool_configs:
                tool_name = config["tool"]
                tool_params = {**params, **config.get("params", {})}

                future = self.executor.submit(
                    self.tools[tool_name].executor,
                    tool_params
                )
                futures[future] = config.get("output_key", tool_name)

            results = {}
            for future in as_completed(futures):
                key = futures[future]
                try:
                    results[key] = future.result()
                except Exception as e:
                    results[key] = {"error": str(e)}

            return merger(results)

        return Tool(
            name="parallel_composition",
            executor=executor,
            input_schema={}
        )

# Usage
parallel = ParallelComposer()

# Register analysis tools
parallel.register(Tool("sentiment", analyze_sentiment, {}))
parallel.register(Tool("entities", extract_entities, {}))
parallel.register(Tool("keywords", extract_keywords, {}))

# Compose parallel analysis
comprehensive_analysis = parallel.parallel(
    [
        {"tool": "sentiment", "output_key": "sentiment"},
        {"tool": "entities", "output_key": "entities"},
        {"tool": "keywords", "output_key": "keywords"}
    ],
    merger=lambda results: {
        "analysis": results,
        "summary": f"Sentiment: {results['sentiment']}, "
                   f"Entities: {len(results['entities'])}, "
                   f"Keywords: {len(results['keywords'])}"
    }
)

result = comprehensive_analysis.executor({"text": "Some text to analyze"})
```

## Step 3: Conditional composition

Branch based on conditions:

```python
from typing import Callable

class ConditionalComposer:
    """Compose tools with conditional logic."""

    def __init__(self):
        self.tools: Dict[str, Tool] = {}

    def register(self, tool: Tool):
        self.tools[tool.name] = tool

    def conditional(
        self,
        condition: Callable[[Dict[str, Any]], str],
        branches: Dict[str, str]
    ) -> Tool:
        """Execute different tools based on condition."""

        def executor(params: Dict[str, Any]) -> Any:
            branch = condition(params)

            if branch not in branches:
                raise ValueError(f"Unknown branch: {branch}")

            tool_name = branches[branch]
            return self.tools[tool_name].executor(params)

        return Tool(
            name="conditional_composition",
            executor=executor,
            input_schema={}
        )

    def fallback(
        self,
        primary: str,
        fallback: str,
        error_handler: Callable[[Exception], bool] = None
    ) -> Tool:
        """Execute fallback if primary fails."""

        def executor(params: Dict[str, Any]) -> Any:
            try:
                return self.tools[primary].executor(params)
            except Exception as e:
                if error_handler and not error_handler(e):
                    raise
                return self.tools[fallback].executor(params)

        return Tool(
            name=f"{primary}_with_fallback",
            executor=executor,
            input_schema=self.tools[primary].input_schema
        )

# Usage
conditional = ConditionalComposer()

conditional.register(Tool("quick_search", quick_search, {}))
conditional.register(Tool("deep_search", deep_search, {}))
conditional.register(Tool("cached_search", cached_search, {}))

# Conditional based on urgency
smart_search = conditional.conditional(
    condition=lambda p: "quick" if p.get("urgent") else "deep",
    branches={
        "quick": "quick_search",
        "deep": "deep_search"
    }
)

# With fallback
resilient_search = conditional.fallback(
    primary="deep_search",
    fallback="cached_search",
    error_handler=lambda e: "timeout" in str(e).lower()
)
```

## Step 4: Data transformation

Transform data between tools:

```python
from typing import TypeVar, Generic

T = TypeVar('T')
U = TypeVar('U')

class Transformer:
    """Transform data between tools."""

    @staticmethod
    def json_to_dict(json_str: str) -> dict:
        import json
        return json.loads(json_str)

    @staticmethod
    def dict_to_json(data: dict) -> str:
        import json
        return json.dumps(data)

    @staticmethod
    def extract_field(data: dict, field: str) -> Any:
        return data.get(field)

    @staticmethod
    def wrap_in_key(data: Any, key: str) -> dict:
        return {key: data}

    @staticmethod
    def flatten_list(data: List[List[Any]]) -> List[Any]:
        return [item for sublist in data for item in sublist]

class TransformingComposer:
    """Compose tools with transformations."""

    def __init__(self):
        self.tools: Dict[str, Tool] = {}

    def register(self, tool: Tool):
        self.tools[tool.name] = tool

    def transform_pipe(
        self,
        steps: List[Dict[str, Any]]
    ) -> Tool:
        """Create pipe with transformations between steps."""

        def executor(params: Dict[str, Any]) -> Any:
            result = params

            for step in steps:
                # Pre-transform
                if "pre_transform" in step:
                    result = step["pre_transform"](result)

                # Execute tool
                tool = self.tools[step["tool"]]
                result = tool.executor(result if isinstance(result, dict) else {"input": result})

                # Post-transform
                if "post_transform" in step:
                    result = step["post_transform"](result)

            return result

        return Tool(
            name="transform_pipe",
            executor=executor,
            input_schema={}
        )

# Usage
composer = TransformingComposer()

composer.register(Tool("fetch_api", fetch_api, {}))
composer.register(Tool("process_data", process_data, {}))
composer.register(Tool("store_result", store_result, {}))

# Pipe with transformations
etl_pipeline = composer.transform_pipe([
    {
        "tool": "fetch_api",
        "post_transform": Transformer.json_to_dict
    },
    {
        "tool": "process_data",
        "pre_transform": lambda d: {"data": d["items"]},
        "post_transform": lambda r: {"processed": r, "count": len(r)}
    },
    {
        "tool": "store_result",
        "pre_transform": Transformer.dict_to_json
    }
])
```

## Step 5: Orchestrated composition

Complex coordination patterns:

```python
class Orchestrator:
    """Orchestrate complex tool compositions."""

    def __init__(self, composer: ToolComposer):
        self.composer = composer
        self.workflows: Dict[str, Callable] = {}

    def define_workflow(
        self,
        name: str,
        workflow: Callable[[Dict[str, Tool], Dict[str, Any]], Any]
    ):
        """Define a named workflow."""
        self.workflows[name] = workflow

    def execute(self, workflow_name: str, params: Dict[str, Any]) -> Any:
        """Execute a workflow."""
        if workflow_name not in self.workflows:
            raise ValueError(f"Unknown workflow: {workflow_name}")

        return self.workflows[workflow_name](self.composer.tools, params)

# Define workflows
def research_workflow(tools: Dict[str, Tool], params: Dict[str, Any]) -> Dict[str, Any]:
    """Research a topic using multiple tools."""

    topic = params["topic"]
    results = {}

    # Step 1: Search for sources
    search_result = tools["web_search"].executor({"query": topic})
    results["sources"] = search_result

    # Step 2: Fetch and analyze each source (parallel)
    from concurrent.futures import ThreadPoolExecutor
    analyses = []

    with ThreadPoolExecutor(max_workers=5) as executor:
        futures = []
        for source in search_result[:5]:  # Top 5 sources
            future = executor.submit(
                tools["fetch_and_analyze"].executor,
                {"url": source["url"]}
            )
            futures.append(future)

        for future in futures:
            try:
                analyses.append(future.result())
            except Exception as e:
                analyses.append({"error": str(e)})

    results["analyses"] = analyses

    # Step 3: Synthesize findings
    synthesis = tools["synthesize"].executor({
        "topic": topic,
        "analyses": analyses
    })
    results["synthesis"] = synthesis

    # Step 4: Generate report
    report = tools["generate_report"].executor({
        "synthesis": synthesis,
        "format": params.get("format", "markdown")
    })
    results["report"] = report

    return results

# Register and use
orchestrator = Orchestrator(composer)
orchestrator.define_workflow("research", research_workflow)

result = orchestrator.execute("research", {
    "topic": "AI agent architectures",
    "format": "markdown"
})
```

## Step 6: MCP integration

Expose composed tools via MCP:

```python
class MCPComposedServer:
    """Serve composed tools via MCP."""

    def __init__(self, composer: ToolComposer):
        self.composer = composer
        self.composed_tools: Dict[str, Tool] = {}

    def expose(self, name: str, tool: Tool, description: str):
        """Expose a composed tool."""
        self.composed_tools[name] = {
            "tool": tool,
            "description": description
        }

    def get_tool_definitions(self) -> List[Dict[str, Any]]:
        """Get MCP tool definitions."""
        return [
            {
                "name": name,
                "description": config["description"],
                "inputSchema": config["tool"].input_schema
            }
            for name, config in self.composed_tools.items()
        ]

    def execute_tool(self, name: str, params: Dict[str, Any]) -> Any:
        """Execute a composed tool."""
        if name not in self.composed_tools:
            raise ValueError(f"Unknown tool: {name}")

        tool = self.composed_tools[name]["tool"]
        return tool.executor(params)

# Create server
server = MCPComposedServer(composer)

# Expose composed tools
server.expose(
    "comprehensive_search",
    comprehensive_analysis,
    "Search and analyze from multiple sources"
)

server.expose(
    "etl_pipeline",
    etl_pipeline,
    "Extract, transform, and load data"
)

# These can now be used by AI agents
```

## Summary

Tool composition patterns:

1. **Pipe** - Chain tools sequentially
2. **Parallel** - Execute concurrently
3. **Conditional** - Branch on conditions
4. **Transform** - Adapt between tools
5. **Orchestrate** - Complex coordination
6. **MCP expose** - Serve composed tools

Build tools with [Gantz](https://gantz.run), compose for power.

Simple tools, powerful compositions.

## Related reading

- [Prompt Chaining](/post/prompt-chaining/) - Chain prompts
- [Dynamic Tool Generation](/post/dynamic-tool-generation/) - Generate tools
- [Multi-Agent Systems](/post/multi-agent-systems/) - Agent coordination

---

*How do you compose tools? Share your patterns.*
