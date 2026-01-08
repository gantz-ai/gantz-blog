+++
title = "Meta-Prompting: Prompts That Write Prompts"
date = 2025-12-09
description = "Use AI to generate better prompts automatically. Meta-prompting techniques for prompt optimization, customization, and self-improvement."
summary = "I got tired of writing prompts, so I wrote a prompt to write prompts for me. Meta-prompting uses AI to generate, optimize, and customize prompts automatically. Give it your use case and constraints, and it produces prompts tailored to specific scenarios. Often produces better results than hand-crafted prompts, with far less effort."
image = "images/agent-neon-03.webp"
draft = false
tags = ['prompting', 'patterns', 'deep-dive']
voice = false
+++


I got tired of writing prompts.

So I wrote a prompt to write prompts for me.

It worked better than my hand-crafted ones.

Here's the technique.

## What is meta-prompting?

Meta-prompting uses an LLM to generate, improve, or customize prompts.

```
Traditional:
Human writes prompt → LLM uses prompt → Output

Meta-prompting:
Human describes goal → LLM writes prompt → LLM uses prompt → Output
```

You tell the AI what you want. It figures out how to ask itself.

## Why bother?

### Reason 1: LLMs know what works for LLMs

```python
# My hand-written prompt
"Analyze this code for bugs"

# LLM-generated prompt
"Analyze the following code systematically:
1. Check for null/undefined access
2. Look for off-by-one errors
3. Identify potential race conditions
4. Find security vulnerabilities (injection, XSS)
5. Note any resource leaks

For each issue found, specify:
- Line number
- Issue type
- Severity (high/medium/low)
- Suggested fix"
```

The LLM knows what structure helps it produce better output.

### Reason 2: Personalization at scale

```
User 1 is a senior developer → Technical, terse prompts
User 2 is a beginner → Explanatory, step-by-step prompts
User 3 prefers Python → Python-focused examples
User 4 prefers TypeScript → TypeScript-focused examples
```

One meta-prompt generates thousands of personalized prompts.

### Reason 3: Dynamic adaptation

```python
# Static prompt - same every time
"Review this code"

# Meta-generated - adapts to input
input_type = detect_type(code)  # Python, JavaScript, SQL...
complexity = estimate_complexity(code)  # Simple, moderate, complex
context = get_project_context()  # Web app, CLI, library...

prompt = generate_prompt(input_type, complexity, context)
# "Review this complex Python web application code, focusing on
#  Django-specific patterns, middleware security, and ORM efficiency..."
```

## The basic pattern

```python
def meta_prompt(goal: str, context: str = "") -> str:
    """Generate a prompt for a specific goal"""

    meta = f"""Create an effective prompt for an AI assistant.

Goal: {goal}
{f'Context: {context}' if context else ''}

The prompt should:
- Be specific and actionable
- Include output format if helpful
- Guide the AI to be thorough
- Avoid ambiguity

Return ONLY the prompt, nothing else."""

    return llm.create(meta)

# Usage
goal = "Review Python code for security issues"
prompt = meta_prompt(goal)

# Generated:
# "Analyze the following Python code for security vulnerabilities:
#  1. SQL injection risks
#  2. Command injection
#  3. Path traversal
#  4. Insecure deserialization
#  5. Hardcoded secrets
#  6. Improper input validation
#
#  For each vulnerability:
#  - Cite the specific line(s)
#  - Explain the attack vector
#  - Provide a secure alternative
#
#  Code:
#  {code}"
```

## Use cases

### 1. Task-specific prompt generation

```python
def generate_task_prompt(task_type: str, details: dict) -> str:
    return llm.create(f"""
Generate a prompt for: {task_type}

Details:
{json.dumps(details, indent=2)}

Create a prompt that will produce high-quality output for this specific task.
Return only the prompt.
""")

# Usage
prompt = generate_task_prompt("code_review", {
    "language": "TypeScript",
    "framework": "React",
    "focus_areas": ["performance", "accessibility"],
    "expertise_level": "senior"
})

# Result: A TypeScript/React specific review prompt focusing on
# performance and a11y, written for senior developer audience
```

### 2. Prompt optimization

```python
def optimize_prompt(original_prompt: str, failure_examples: list) -> str:
    """Improve a prompt based on where it failed"""

    failures = "\n".join([
        f"Input: {f['input']}\nExpected: {f['expected']}\nGot: {f['actual']}"
        for f in failure_examples
    ])

    return llm.create(f"""
This prompt is producing incorrect outputs:

CURRENT PROMPT:
{original_prompt}

FAILURE CASES:
{failures}

Analyze why the prompt fails in these cases and create an improved version.
Return only the improved prompt.
""")

# Usage
original = "Summarize this text"
failures = [
    {"input": "Technical paper", "expected": "Key findings", "got": "Introduction only"},
    {"input": "Long article", "expected": "3-5 sentences", "got": "10 paragraphs"}
]

better_prompt = optimize_prompt(original, failures)
# "Summarize the following text in 3-5 sentences. Focus on:
#  - Main thesis or key findings
#  - Supporting evidence
#  - Conclusions
#  Do not include background or introductory material..."
```

### 3. Few-shot example generation

```python
def generate_examples(task: str, num_examples: int = 3) -> list:
    """Generate few-shot examples for a task"""

    response = llm.create(f"""
Create {num_examples} diverse examples for this task: {task}

Each example should have:
- Input: realistic input
- Output: ideal output

Format as JSON array: [{{"input": "...", "output": "..."}}, ...]
""")

    return json.loads(response)

def build_few_shot_prompt(task: str, actual_input: str) -> str:
    examples = generate_examples(task)

    prompt = f"Task: {task}\n\n"
    for i, ex in enumerate(examples, 1):
        prompt += f"Example {i}:\nInput: {ex['input']}\nOutput: {ex['output']}\n\n"

    prompt += f"Now complete this:\nInput: {actual_input}\nOutput:"

    return prompt
```

### 4. User preference learning

```python
class AdaptivePromptGenerator:
    def __init__(self):
        self.user_preferences = {}

    def learn_from_feedback(self, user_id: str, prompt: str, output: str, feedback: str):
        """Learn what the user likes"""
        self.user_preferences[user_id] = self.user_preferences.get(user_id, [])
        self.user_preferences[user_id].append({
            "prompt": prompt,
            "output": output,
            "feedback": feedback
        })

    def generate_prompt(self, user_id: str, task: str) -> str:
        """Generate prompt tailored to user preferences"""
        prefs = self.user_preferences.get(user_id, [])

        if not prefs:
            return self.default_prompt(task)

        # Use past feedback to shape prompt
        pref_summary = llm.create(f"""
Analyze this user's feedback history and identify their preferences:
{json.dumps(prefs[-10:], indent=2)}

What style, format, and approach does this user prefer?
""")

        return llm.create(f"""
Create a prompt for: {task}

User preferences: {pref_summary}

Generate a prompt that matches their preferred style.
""")
```

### 5. Tool description generation

```python
def generate_tool_description(tool_name: str, code: str) -> str:
    """Generate optimal tool description for LLM consumption"""

    return llm.create(f"""
Analyze this tool and create a description optimized for AI assistants.

Tool name: {tool_name}
Implementation:
{code}

Create a description that:
- Clearly states what the tool does
- Specifies when to use it vs alternatives
- Mentions important parameters
- Notes any limitations

Keep it under 100 words. Be precise.
""")

# Usage
code = '''
def search_files(query: str, path: str = ".", file_type: str = None):
    """Search for text in files"""
    cmd = f"rg '{query}' {path}"
    if file_type:
        cmd += f" --type {file_type}"
    return subprocess.run(cmd, capture_output=True, text=True)
'''

description = generate_tool_description("search_files", code)
# "Search for text patterns in files using ripgrep. Use for finding code,
#  text, or patterns across a directory. Parameters: query (required),
#  path (default: current dir), file_type (e.g., 'py', 'js'). Fast for
#  large codebases. Use instead of read_file when you don't know which
#  file contains what you're looking for."
```

## Advanced: Self-improving prompts

```python
class SelfImprovingPrompt:
    def __init__(self, initial_prompt: str, eval_fn):
        self.prompt = initial_prompt
        self.eval_fn = eval_fn  # Returns score 0-1
        self.history = []

    def run(self, input_data: str) -> str:
        output = llm.create(f"{self.prompt}\n\nInput: {input_data}")
        return output

    def improve(self, test_cases: list) -> bool:
        """Run test cases and improve if needed"""

        # Evaluate current prompt
        results = []
        for case in test_cases:
            output = self.run(case["input"])
            score = self.eval_fn(output, case["expected"])
            results.append({
                "input": case["input"],
                "expected": case["expected"],
                "output": output,
                "score": score
            })

        avg_score = sum(r["score"] for r in results) / len(results)

        if avg_score >= 0.9:
            return False  # Good enough

        # Find failures
        failures = [r for r in results if r["score"] < 0.8]

        # Generate improved prompt
        new_prompt = llm.create(f"""
Current prompt (avg score: {avg_score:.2f}):
{self.prompt}

Failed cases:
{json.dumps(failures, indent=2)}

Analyze the failures and create an improved prompt.
Return only the new prompt.
""")

        self.history.append({
            "prompt": self.prompt,
            "score": avg_score
        })
        self.prompt = new_prompt

        return True  # Improved

    def iterate(self, test_cases: list, max_iterations: int = 5):
        """Keep improving until good enough or max iterations"""
        for i in range(max_iterations):
            improved = self.improve(test_cases)
            if not improved:
                print(f"Converged after {i+1} iterations")
                break
        return self.prompt
```

## Meta-prompts for agents

### Generate system prompts

```python
def generate_agent_prompt(agent_type: str, tools: list, constraints: list) -> str:
    tool_list = "\n".join([f"- {t['name']}: {t['description']}" for t in tools])
    constraint_list = "\n".join([f"- {c}" for c in constraints])

    return llm.create(f"""
Create a system prompt for an AI agent.

Agent type: {agent_type}

Available tools:
{tool_list}

Constraints:
{constraint_list}

Generate a system prompt that:
- Clearly defines the agent's role
- Explains when to use each tool
- Enforces the constraints
- Guides effective tool usage patterns

Return only the system prompt.
""")

# Usage
tools = [
    {"name": "read", "description": "Read file contents"},
    {"name": "write", "description": "Write to file"},
    {"name": "run", "description": "Run shell command"},
]
constraints = [
    "Always read before modifying",
    "Confirm before deleting",
    "Stay within /workspace directory"
]

system_prompt = generate_agent_prompt("coding assistant", tools, constraints)
```

### Generate tool selection rules

```python
def generate_tool_rules(tools: list, past_mistakes: list) -> str:
    """Generate rules for when to use which tool"""

    return llm.create(f"""
Given these tools and past mistakes, create clear rules for tool selection.

Tools:
{json.dumps(tools, indent=2)}

Past mistakes (wrong tool chosen):
{json.dumps(past_mistakes, indent=2)}

Create a decision guide:
- When to use each tool
- When NOT to use each tool
- Order of preference for common tasks

Be specific and actionable.
""")
```

## When meta-prompting helps

| Scenario | Benefit |
|----------|---------|
| Many similar tasks | Generate specialized prompts automatically |
| User personalization | Adapt to preferences at scale |
| Prompt optimization | Improve based on failures |
| Dynamic contexts | Adapt prompts to input characteristics |
| Few-shot generation | Create examples automatically |

## When to avoid

| Scenario | Why |
|----------|-----|
| Simple, static tasks | Overhead not worth it |
| Latency-critical | Extra LLM call adds delay |
| Highly regulated | Need deterministic, auditable prompts |
| Tight token budget | Meta-prompting uses extra tokens |

## With Gantz

[Gantz](https://gantz.run) focuses on tools, but your client can use meta-prompting to generate tool descriptions:

```python
# Generate descriptions for gantz tools
def generate_gantz_config(tools_code: dict) -> str:
    tools_yaml = []

    for name, code in tools_code.items():
        description = llm.create(f"""
Create a concise tool description for AI assistants.

Tool: {name}
Code: {code}

Return only the description (1-2 sentences).
""")
        tools_yaml.append(f"""  - name: {name}
    description: {description}
    script:
      shell: {code}""")

    return "tools:\n" + "\n".join(tools_yaml)

# Usage
tools = {
    "search": 'rg "{{query}}" . --max-count=20',
    "read": 'cat "{{path}}"',
    "run": '"{{command}}"'
}

config = generate_gantz_config(tools)
# Generates gantz.yaml with AI-optimized descriptions
```

## The meta-meta level

Yes, you can go deeper:

```python
def generate_meta_prompt(goal: str) -> str:
    """Generate a prompt that generates prompts"""

    return llm.create(f"""
Create a meta-prompt (a prompt that generates other prompts).

The meta-prompt should help generate prompts for: {goal}

The generated meta-prompt should:
- Ask the right questions about the specific task
- Include guidelines for good prompt structure
- Produce consistent, high-quality prompts

Return only the meta-prompt.
""")
```

But usually one level of meta is enough. Don't overthink it.

## Summary

Meta-prompting patterns:

| Pattern | Use case |
|---------|----------|
| Task-specific generation | Create prompts for different task types |
| Prompt optimization | Improve based on failures |
| Few-shot generation | Create examples automatically |
| User personalization | Adapt to preferences |
| Self-improving | Iterate until quality target met |

When to use:
- Many variations needed
- Personalization at scale
- Optimizing existing prompts
- Dynamic adaptation required

When to skip:
- Simple, static tasks
- Latency matters
- Need auditability

Let the AI write its own instructions. It often knows better.

## Related reading

- [Dynamic Prompts: Changing Instructions Mid-Conversation](/post/dynamic-prompts/) - Adaptive prompting
- [Chain of Thought: When It Helps, When It Hurts](/post/chain-of-thought/) - Reasoning patterns
- [Writing Tool Descriptions That Work](/post/tool-descriptions/) - Optimizing tool prompts

---

*Have you used meta-prompting? What worked best?*
