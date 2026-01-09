+++
title = "Prompt Chaining: Build Complex AI Workflows"
image = "images/prompt-chaining.webp"
date = 2025-11-14
description = "Chain prompts to build sophisticated AI workflows. Break complex tasks into steps, pass context between stages, and compose reliable agent pipelines."
summary = "Master prompt chaining patterns to break complex AI tasks into manageable sequential steps where each output feeds into the next. Learn to implement basic sequential chains, conditional branching based on intermediate results, parallel execution for independent steps, chains integrated with MCP tools, error handling with retries, and performance optimization through caching and model selection."
draft = false
tags = ['mcp', 'prompts', 'workflows']
voice = false

[howto]
name = "Implement Prompt Chaining"
totalTime = 30
[[howto.steps]]
name = "Decompose tasks"
text = "Break complex tasks into sequential steps."
[[howto.steps]]
name = "Design chain structure"
text = "Define how outputs flow between prompts."
[[howto.steps]]
name = "Implement chain executor"
text = "Build the execution engine for chains."
[[howto.steps]]
name = "Add error handling"
text = "Handle failures gracefully in chains."
[[howto.steps]]
name = "Optimize chain performance"
text = "Parallelize independent steps."
+++


One prompt can't do everything.

Complex tasks need multiple steps. Each step builds on the last.

That's prompt chaining.

## Why chain prompts?

Single prompts fail when tasks are:
- **Multi-step** - Require sequential reasoning
- **Complex** - Too much for one context
- **Specialized** - Need different expertise
- **Validated** - Require intermediate checks

Chaining breaks complexity into manageable pieces.

## Chaining patterns

```text
Sequential:    A → B → C → D
Parallel:      A → [B, C] → D
Conditional:   A → B? → C or D
Loop:          A → B → (back to A if condition)
```

## Step 1: Basic chain structure

Using [Gantz](https://gantz.run):

```yaml
# gantz.yaml
name: chain-tools

tools:
  - name: analyze_requirements
    description: Analyze user requirements
    parameters:
      - name: input
        type: string
        required: true
    script:
      command: python
      args: ["scripts/analyze.py", "{{input}}"]

  - name: generate_design
    description: Generate design from analysis
    parameters:
      - name: analysis
        type: string
        required: true
    script:
      command: python
      args: ["scripts/design.py", "{{analysis}}"]

  - name: implement_code
    description: Implement code from design
    parameters:
      - name: design
        type: string
        required: true
    script:
      command: python
      args: ["scripts/implement.py", "{{design}}"]
```

Chain implementation:

```python
from typing import List, Dict, Any, Callable, Optional
from dataclasses import dataclass
import anthropic

@dataclass
class ChainStep:
    """A single step in a prompt chain."""
    name: str
    prompt_template: str
    system_prompt: Optional[str] = None
    output_key: str = "output"
    model: str = "claude-sonnet-4-20250514"

class PromptChain:
    """Execute a chain of prompts."""

    def __init__(self):
        self.client = anthropic.Anthropic()
        self.steps: List[ChainStep] = []
        self.context: Dict[str, Any] = {}

    def add_step(self, step: ChainStep) -> 'PromptChain':
        """Add a step to the chain."""
        self.steps.append(step)
        return self

    def execute(self, initial_input: str) -> Dict[str, Any]:
        """Execute the entire chain."""
        self.context["input"] = initial_input

        for step in self.steps:
            print(f"Executing step: {step.name}")

            # Format prompt with current context
            prompt = step.prompt_template.format(**self.context)

            # Call LLM
            response = self.client.messages.create(
                model=step.model,
                max_tokens=4096,
                system=step.system_prompt or "",
                messages=[{"role": "user", "content": prompt}]
            )

            # Extract and store result
            result = response.content[0].text
            self.context[step.output_key] = result
            self.context[f"{step.name}_result"] = result

        return self.context

# Usage
chain = PromptChain()

chain.add_step(ChainStep(
    name="analyze",
    prompt_template="Analyze these requirements and extract key features:\n\n{input}",
    system_prompt="You are a requirements analyst.",
    output_key="analysis"
))

chain.add_step(ChainStep(
    name="design",
    prompt_template="Based on this analysis, create a technical design:\n\n{analysis}",
    system_prompt="You are a software architect.",
    output_key="design"
))

chain.add_step(ChainStep(
    name="implement",
    prompt_template="Implement this design in Python:\n\n{design}",
    system_prompt="You are a Python developer.",
    output_key="code"
))

result = chain.execute("Build a user authentication system with email verification")
print(result["code"])
```

## Step 2: Conditional chains

Branch based on intermediate results:

```python
from typing import Callable

@dataclass
class ConditionalStep(ChainStep):
    """Step with conditional branching."""
    condition: Callable[[Dict[str, Any]], bool] = None
    on_true: Optional[str] = None   # Step name to jump to
    on_false: Optional[str] = None  # Step name to jump to

class ConditionalChain(PromptChain):
    """Chain with conditional branching."""

    def __init__(self):
        super().__init__()
        self.step_map: Dict[str, ChainStep] = {}

    def add_step(self, step: ChainStep) -> 'ConditionalChain':
        super().add_step(step)
        self.step_map[step.name] = step
        return self

    def execute(self, initial_input: str) -> Dict[str, Any]:
        """Execute chain with conditional branching."""
        self.context["input"] = initial_input

        current_index = 0

        while current_index < len(self.steps):
            step = self.steps[current_index]
            print(f"Executing step: {step.name}")

            # Execute step
            prompt = step.prompt_template.format(**self.context)
            response = self.client.messages.create(
                model=step.model,
                max_tokens=4096,
                system=step.system_prompt or "",
                messages=[{"role": "user", "content": prompt}]
            )

            result = response.content[0].text
            self.context[step.output_key] = result

            # Check for conditional branching
            if isinstance(step, ConditionalStep) and step.condition:
                if step.condition(self.context):
                    if step.on_true:
                        current_index = self._find_step_index(step.on_true)
                        continue
                else:
                    if step.on_false:
                        current_index = self._find_step_index(step.on_false)
                        continue

            current_index += 1

        return self.context

    def _find_step_index(self, name: str) -> int:
        for i, step in enumerate(self.steps):
            if step.name == name:
                return i
        raise ValueError(f"Step not found: {name}")

# Usage
chain = ConditionalChain()

chain.add_step(ChainStep(
    name="classify",
    prompt_template="Classify this request as 'simple' or 'complex':\n\n{input}",
    output_key="classification"
))

chain.add_step(ConditionalStep(
    name="route",
    prompt_template="Based on classification: {classification}",
    condition=lambda ctx: "simple" in ctx["classification"].lower(),
    on_true="simple_handler",
    on_false="complex_handler"
))

chain.add_step(ChainStep(
    name="simple_handler",
    prompt_template="Handle this simple request quickly:\n\n{input}",
    output_key="response"
))

chain.add_step(ChainStep(
    name="complex_handler",
    prompt_template="Handle this complex request with detailed analysis:\n\n{input}",
    output_key="response"
))
```

## Step 3: Parallel chains

Execute independent steps concurrently:

```python
import asyncio
from concurrent.futures import ThreadPoolExecutor
from typing import List

class ParallelChain:
    """Chain with parallel execution support."""

    def __init__(self, max_workers: int = 5):
        self.client = anthropic.Anthropic()
        self.executor = ThreadPoolExecutor(max_workers=max_workers)
        self.steps: List[ChainStep] = []
        self.parallel_groups: Dict[str, List[ChainStep]] = {}

    def add_step(self, step: ChainStep) -> 'ParallelChain':
        self.steps.append(step)
        return self

    def add_parallel_group(self, group_name: str, steps: List[ChainStep]) -> 'ParallelChain':
        """Add steps that should run in parallel."""
        self.parallel_groups[group_name] = steps
        return self

    def _execute_step(self, step: ChainStep, context: Dict[str, Any]) -> tuple:
        """Execute a single step."""
        prompt = step.prompt_template.format(**context)

        response = self.client.messages.create(
            model=step.model,
            max_tokens=4096,
            system=step.system_prompt or "",
            messages=[{"role": "user", "content": prompt}]
        )

        return step.output_key, response.content[0].text

    def execute(self, initial_input: str) -> Dict[str, Any]:
        """Execute chain with parallel groups."""
        context = {"input": initial_input}

        for step in self.steps:
            # Check if this is a parallel group trigger
            if step.name in self.parallel_groups:
                # Execute parallel steps
                parallel_steps = self.parallel_groups[step.name]
                futures = [
                    self.executor.submit(self._execute_step, s, context)
                    for s in parallel_steps
                ]

                # Collect results
                for future in futures:
                    key, value = future.result()
                    context[key] = value
            else:
                # Execute single step
                key, value = self._execute_step(step, context)
                context[key] = value

        return context

# Usage
chain = ParallelChain()

# First step: analyze
chain.add_step(ChainStep(
    name="analyze",
    prompt_template="Analyze this task: {input}",
    output_key="analysis"
))

# Parallel steps: multiple analyses
chain.add_parallel_group("parallel_review", [
    ChainStep(
        name="security_review",
        prompt_template="Review security aspects: {analysis}",
        output_key="security"
    ),
    ChainStep(
        name="performance_review",
        prompt_template="Review performance aspects: {analysis}",
        output_key="performance"
    ),
    ChainStep(
        name="maintainability_review",
        prompt_template="Review maintainability: {analysis}",
        output_key="maintainability"
    )
])

chain.add_step(ChainStep(
    name="parallel_review",  # Triggers parallel group
    prompt_template="",
    output_key=""
))

# Final step: combine
chain.add_step(ChainStep(
    name="synthesize",
    prompt_template="""Synthesize these reviews:
    Security: {security}
    Performance: {performance}
    Maintainability: {maintainability}""",
    output_key="final_review"
))

result = chain.execute("Review this new API design")
```

## Step 4: Chain with tools

Integrate MCP tools in chains:

```python
class ToolChain:
    """Chain that uses MCP tools between steps."""

    def __init__(self, mcp_url: str, mcp_token: str):
        self.client = anthropic.Anthropic()
        self.mcp_url = mcp_url
        self.mcp_token = mcp_token
        self.steps: List[ChainStep] = []

    def add_step(self, step: ChainStep, use_tools: bool = False) -> 'ToolChain':
        step.use_tools = use_tools
        self.steps.append(step)
        return self

    def execute(self, initial_input: str) -> Dict[str, Any]:
        context = {"input": initial_input}

        for step in self.steps:
            print(f"Executing: {step.name}")

            prompt = step.prompt_template.format(**context)
            messages = [{"role": "user", "content": prompt}]

            # Build request
            request = {
                "model": step.model,
                "max_tokens": 4096,
                "messages": messages
            }

            if step.system_prompt:
                request["system"] = step.system_prompt

            # Add tools if needed
            if getattr(step, 'use_tools', False):
                request["tools"] = [{
                    "type": "mcp",
                    "server_url": self.mcp_url,
                    "token": self.mcp_token
                }]

                # Run agentic loop
                result = self._run_with_tools(request)
            else:
                response = self.client.messages.create(**request)
                result = response.content[0].text

            context[step.output_key] = result

        return context

    def _run_with_tools(self, request: dict) -> str:
        """Run agentic loop with tool use."""
        messages = request["messages"].copy()

        while True:
            response = self.client.messages.create(**{**request, "messages": messages})

            if response.stop_reason == "end_turn":
                for content in response.content:
                    if hasattr(content, 'text'):
                        return content.text
                return ""

            if response.stop_reason == "tool_use":
                messages.append({"role": "assistant", "content": response.content})

                tool_results = []
                for content in response.content:
                    if hasattr(content, 'type') and content.type == "tool_use":
                        # Tool executed by Claude
                        tool_results.append({
                            "type": "tool_result",
                            "tool_use_id": content.id,
                            "content": "Tool executed"
                        })

                messages.append({"role": "user", "content": tool_results})

# Usage
chain = ToolChain(
    mcp_url="https://tools.gantz.run/sse",
    mcp_token="gtz_your_token"
)

chain.add_step(ChainStep(
    name="gather_data",
    prompt_template="Use tools to gather data about: {input}",
    output_key="data"
), use_tools=True)

chain.add_step(ChainStep(
    name="analyze",
    prompt_template="Analyze this data: {data}",
    output_key="analysis"
), use_tools=False)

chain.add_step(ChainStep(
    name="take_action",
    prompt_template="Based on this analysis, take appropriate action: {analysis}",
    output_key="result"
), use_tools=True)
```

## Step 5: Error handling in chains

Handle failures gracefully:

```python
from typing import Optional
import time

@dataclass
class ChainStepResult:
    """Result of a chain step execution."""
    success: bool
    output: Optional[str] = None
    error: Optional[str] = None
    retries: int = 0

class ResilientChain(PromptChain):
    """Chain with error handling and retries."""

    def __init__(self, max_retries: int = 3, retry_delay: float = 1.0):
        super().__init__()
        self.max_retries = max_retries
        self.retry_delay = retry_delay
        self.results: List[ChainStepResult] = []

    def _execute_with_retry(self, step: ChainStep) -> ChainStepResult:
        """Execute step with retries."""
        retries = 0

        while retries <= self.max_retries:
            try:
                prompt = step.prompt_template.format(**self.context)

                response = self.client.messages.create(
                    model=step.model,
                    max_tokens=4096,
                    system=step.system_prompt or "",
                    messages=[{"role": "user", "content": prompt}]
                )

                return ChainStepResult(
                    success=True,
                    output=response.content[0].text,
                    retries=retries
                )

            except Exception as e:
                retries += 1
                if retries <= self.max_retries:
                    time.sleep(self.retry_delay * retries)
                else:
                    return ChainStepResult(
                        success=False,
                        error=str(e),
                        retries=retries
                    )

    def execute(self, initial_input: str, stop_on_error: bool = True) -> Dict[str, Any]:
        """Execute chain with error handling."""
        self.context["input"] = initial_input
        self.results = []

        for step in self.steps:
            print(f"Executing: {step.name}")

            result = self._execute_with_retry(step)
            self.results.append(result)

            if result.success:
                self.context[step.output_key] = result.output
            else:
                if stop_on_error:
                    self.context["error"] = result.error
                    self.context["failed_step"] = step.name
                    break
                else:
                    self.context[step.output_key] = f"[ERROR: {result.error}]"

        self.context["chain_success"] = all(r.success for r in self.results)
        return self.context

    def get_execution_report(self) -> Dict[str, Any]:
        """Get detailed execution report."""
        return {
            "total_steps": len(self.steps),
            "completed_steps": sum(1 for r in self.results if r.success),
            "failed_steps": sum(1 for r in self.results if not r.success),
            "total_retries": sum(r.retries for r in self.results),
            "step_details": [
                {
                    "step": self.steps[i].name,
                    "success": r.success,
                    "retries": r.retries,
                    "error": r.error
                }
                for i, r in enumerate(self.results)
            ]
        }
```

## Step 6: Chain optimization

Optimize for speed and cost:

```python
class OptimizedChain:
    """Chain with performance optimizations."""

    def __init__(self):
        self.client = anthropic.Anthropic()
        self.steps: List[ChainStep] = []
        self.cache: Dict[str, str] = {}

    def add_step(
        self,
        step: ChainStep,
        cacheable: bool = False,
        model_tier: str = "auto"
    ) -> 'OptimizedChain':
        """Add step with optimization hints."""
        step.cacheable = cacheable
        step.model_tier = model_tier
        self.steps.append(step)
        return self

    def _select_model(self, step: ChainStep, prompt: str) -> str:
        """Select appropriate model based on task."""
        if step.model_tier == "auto":
            # Simple heuristic: short prompts use faster model
            if len(prompt) < 500:
                return "claude-3-haiku-20240307"
            else:
                return "claude-sonnet-4-20250514"
        elif step.model_tier == "fast":
            return "claude-3-haiku-20240307"
        elif step.model_tier == "smart":
            return "claude-sonnet-4-20250514"
        elif step.model_tier == "best":
            return "claude-opus-4-20250514"
        return step.model

    def _get_cache_key(self, step: ChainStep, prompt: str) -> str:
        """Generate cache key."""
        import hashlib
        content = f"{step.name}:{step.system_prompt}:{prompt}"
        return hashlib.sha256(content.encode()).hexdigest()

    def execute(self, initial_input: str) -> Dict[str, Any]:
        """Execute optimized chain."""
        context = {"input": initial_input}

        for step in self.steps:
            prompt = step.prompt_template.format(**context)

            # Check cache
            if getattr(step, 'cacheable', False):
                cache_key = self._get_cache_key(step, prompt)
                if cache_key in self.cache:
                    context[step.output_key] = self.cache[cache_key]
                    print(f"{step.name}: cache hit")
                    continue

            # Select model
            model = self._select_model(step, prompt)
            print(f"{step.name}: using {model}")

            response = self.client.messages.create(
                model=model,
                max_tokens=4096,
                system=step.system_prompt or "",
                messages=[{"role": "user", "content": prompt}]
            )

            result = response.content[0].text
            context[step.output_key] = result

            # Cache if cacheable
            if getattr(step, 'cacheable', False):
                self.cache[cache_key] = result

        return context

# Usage
chain = OptimizedChain()

chain.add_step(
    ChainStep(
        name="classify",
        prompt_template="Classify: {input}",
        output_key="class"
    ),
    cacheable=True,  # Cache classification results
    model_tier="fast"  # Use fast model
)

chain.add_step(
    ChainStep(
        name="analyze",
        prompt_template="Analyze: {input}\nClass: {class}",
        output_key="analysis"
    ),
    model_tier="auto"  # Auto-select based on complexity
)

chain.add_step(
    ChainStep(
        name="generate",
        prompt_template="Generate response for: {analysis}",
        output_key="response"
    ),
    model_tier="smart"  # Use smart model for generation
)
```

## Summary

Prompt chaining patterns:

1. **Sequential chains** - Step-by-step processing
2. **Conditional chains** - Branch on results
3. **Parallel chains** - Concurrent execution
4. **Tool chains** - Integrate MCP tools
5. **Resilient chains** - Handle errors
6. **Optimized chains** - Speed and cost

Build tools with [Gantz](https://gantz.run), chain for complexity.

One prompt isn't enough. Chain them.

## Related reading

- [Tool Composition](/post/tool-composition/) - Compose tools
- [Multi-Agent Systems](/post/multi-agent-systems/) - Agent coordination
- [Agent Evaluation](/post/agent-evaluation/) - Test chains

---

*How do you chain prompts? Share your patterns.*
