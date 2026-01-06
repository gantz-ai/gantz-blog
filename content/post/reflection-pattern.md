+++
title = "The Reflection pattern: AI that checks its own work"
date = 2025-11-30
description = "Build self-correcting AI agents with the Reflection pattern. Implement output verification, error detection, and iterative improvement loops."
image = "images/agent-train-04.webp"
draft = false
tags = ['patterns', 'architecture', 'deep-dive']
voice = false
+++


AI makes mistakes. It hallucinates. It misses things. It gets stuck in loops.

What if AI could catch its own errors?

That's the Reflection pattern.

## The problem

Standard AI agents act and move on. They don't look back.

```
User: "Write a function to calculate factorial"

AI: [writes code]
def factorial(n):
    return n * factorial(n-1)  # Bug: no base case

AI: "Here's your function!"
# Infinite recursion. AI didn't notice.
```

The AI completed the task but didn't verify its work. No human would submit code without at least glancing at it.

## Reflection: Think twice

Reflection adds a verification step. After acting, AI reviews its own output.

```
User: "Write a function to calculate factorial"

AI: [writes code]
def factorial(n):
    return n * factorial(n-1)

AI [REFLECT]: "Let me check this...
- Does it handle base case? No, missing n==0 or n==1
- Will it terminate? No, infinite recursion
- This is wrong. Let me fix it."

AI: [rewrites code]
def factorial(n):
    if n <= 1:
        return 1
    return n * factorial(n-1)

AI: "Here's your function!"
```

Same AI, better result. Just by thinking twice.

## How it works

```
┌─────────┐     ┌─────────┐     ┌─────────┐
│  Task   │────→│  Actor  │────→│ Output  │
└─────────┘     └─────────┘     └────┬────┘
                                     │
                                     ▼
                               ┌──────────┐
                               │ Reflector│
                               └────┬─────┘
                                    │
                    ┌───────────────┼───────────────┐
                    │               │               │
                    ▼               ▼               ▼
               [Looks good]    [Minor fix]    [Major issue]
                    │               │               │
                    ▼               ▼               ▼
                 Return         Fix & Return    Redo task
```

1. AI does the task (Actor)
2. AI reviews its work (Reflector)
3. Based on review: accept, fix, or redo

## Implementation

### Basic reflection

```python
def reflect_and_act(task, tools):
    # Step 1: Act
    result = actor.run(task, tools)

    # Step 2: Reflect
    reflection = reflector.analyze(
        task=task,
        result=result,
        prompt="""Review this output:
        - Does it correctly solve the task?
        - Are there any errors or issues?
        - What could be improved?

        Rate: GOOD / NEEDS_FIX / REDO"""
    )

    # Step 3: Handle reflection
    if reflection.rating == "GOOD":
        return result
    elif reflection.rating == "NEEDS_FIX":
        return actor.fix(result, reflection.feedback)
    else:  # REDO
        return reflect_and_act(task, tools)  # Try again
```

### Reflection prompt

The reflector needs clear criteria:

```python
REFLECTION_PROMPT = """
You are reviewing work done by an AI assistant.

Original task: {task}
Output produced: {output}

Evaluate the output:

1. CORRECTNESS: Does it solve the task correctly?
2. COMPLETENESS: Is anything missing?
3. ERRORS: Are there bugs, mistakes, or issues?
4. QUALITY: Is it well-structured and clear?

Based on your evaluation:
- GOOD: Output is correct and complete
- NEEDS_FIX: Minor issues that can be fixed
- REDO: Fundamentally wrong, needs complete redo

Provide specific feedback on what's wrong and how to fix it.
"""
```

### With MCP tools

Reflection works great with tool use. The reflector can verify tool results.

```python
def execute_with_reflection(task, mcp_client):
    # Actor uses tools
    result = actor.run(
        task=task,
        tools=mcp_client.get_tools()
    )

    # Reflector checks the work
    reflection = reflector.analyze(
        task=task,
        tool_calls=result.tool_calls,
        output=result.output
    )

    if reflection.needs_verification:
        # Use tools to verify
        verification = mcp_client.call_tool(
            "verify_result",
            {"expected": task, "actual": result.output}
        )
        if not verification.passed:
            return execute_with_reflection(task, mcp_client)  # Retry

    return result
```

## Example: Code generation

**Task:** "Write a function to find the second largest number in a list"

**Without reflection:**

```
AI: Here's the function:

def second_largest(nums):
    sorted_nums = sorted(nums, reverse=True)
    return sorted_nums[1]

# Bugs:
# - Fails on empty list
# - Fails on single element
# - Doesn't handle duplicates [5,5,3] returns 5 not 3
```

**With reflection:**

```
AI [ACT]: Here's the function:

def second_largest(nums):
    sorted_nums = sorted(nums, reverse=True)
    return sorted_nums[1]

AI [REFLECT]: Let me verify this...
- Empty list: sorted_nums[1] will IndexError ❌
- Single element: same issue ❌
- Duplicates [5,5,3]: returns 5, should return 3 ❌
- Rating: REDO

AI [ACT]: Let me rewrite:

def second_largest(nums):
    if len(nums) < 2:
        raise ValueError("Need at least 2 numbers")
    unique = list(set(nums))
    if len(unique) < 2:
        raise ValueError("Need at least 2 unique numbers")
    unique.sort(reverse=True)
    return unique[1]

AI [REFLECT]: Checking again...
- Empty list: raises ValueError ✓
- Single element: raises ValueError ✓
- Duplicates: handles correctly ✓
- Rating: GOOD
```

## Example: Tool use

**Task:** "Find all users who signed up last month and email them a survey"

**Without reflection:**

```
AI: [calls get_users tool]
AI: [calls send_email tool for each user]
AI: "Done! Sent emails to 150 users."

# Problem: Didn't verify the date filter worked
# Actually sent to ALL users, not just last month
```

**With reflection:**

```
AI [ACT]:
[calls get_users(filter="signup_date > 2024-11-01")]
Got 150 users

AI [REFLECT]: Wait, let me verify this is correct.
[calls count_users(filter="signup_date > 2024-11-01")]
Count: 42

That doesn't match. 150 vs 42. Something's wrong.
Let me check the first query...

[calls get_users with correct filter]
Got 42 users. The first query ignored my filter.

AI [ACT]:
[calls send_email for 42 users]

AI [REFLECT]: Verify emails sent:
[calls get_email_log(campaign="survey")]
42 emails sent. Matches user count. ✓

AI: "Done! Sent survey to 42 users who signed up last month."
```

## Reflection strategies

### Self-critique

AI critiques its own output.

```python
reflection = llm.create(
    messages=[
        {"role": "assistant", "content": output},
        {"role": "user", "content": "Critique your response. What's wrong?"}
    ]
)
```

### Verification tools

Use tools to verify results.

```yaml
tools:
  - name: run_tests
    description: Run tests against code
  - name: validate_json
    description: Check if JSON is valid
  - name: check_sql
    description: Verify SQL query syntax
  - name: count_results
    description: Verify expected count
```

### Multi-perspective

Different prompts catch different issues.

```python
perspectives = [
    "Check for logical errors",
    "Check for edge cases",
    "Check for security issues",
    "Check for performance issues"
]

for perspective in perspectives:
    reflection = reflector.analyze(output, focus=perspective)
    if reflection.found_issue:
        output = fix(output, reflection)
```

### Constitutional AI

Check against rules.

```python
RULES = [
    "Output must be valid JSON",
    "No sensitive data in response",
    "Must handle empty input",
    "Response under 1000 tokens"
]

for rule in RULES:
    if not check_rule(output, rule):
        output = fix_for_rule(output, rule)
```

## When to use reflection

**Use reflection when:**
- Output quality matters
- Mistakes are costly
- Tasks are complex
- AI tends to make specific errors
- Verification is possible

**Skip reflection when:**
- Simple, low-stakes tasks
- Speed is critical
- Output is obviously correct
- Resources are limited

## Costs and trade-offs

### More tokens

Reflection means more LLM calls.

```
Without: 1 call
With: 2-3 calls (act + reflect + maybe fix)
```

### More latency

Extra round trips take time.

```
Without: 500ms
With: 1000-1500ms
```

### When it's worth it

```
Cost of reflection: ~2x tokens/latency
Cost of wrong output: Much higher

If mistakes matter, reflect.
```

## Integration with MCP

MCP tools can both cause errors and help catch them.

**Tools that help reflection:**

```yaml
tools:
  - name: validate_output
    description: Check if output meets requirements
    parameters:
      - name: output
        type: string
      - name: requirements
        type: string

  - name: run_tests
    description: Execute test cases
    parameters:
      - name: code
        type: string
      - name: tests
        type: array

  - name: diff_check
    description: Compare expected vs actual
    parameters:
      - name: expected
        type: string
      - name: actual
        type: string

  - name: syntax_check
    description: Validate code/data syntax
    parameters:
      - name: content
        type: string
      - name: type
        type: string
```

Run these with [Gantz](https://gantz.run) to give your reflector verification capabilities.

## Patterns

### Reflect-then-act

Reflect on the plan before executing.

```
Plan → Reflect on plan → Execute → Done
```

### Act-then-reflect

Reflect on the result after executing.

```
Execute → Reflect on result → Fix if needed → Done
```

### Continuous reflection

Reflect at every step.

```
Act → Reflect → Act → Reflect → Act → Reflect → Done
```

### Ensemble reflection

Multiple reflectors vote.

```
Output → Reflector A → Good
       → Reflector B → Good
       → Reflector C → Needs fix

Majority: Good (2/3)
```

## Summary

Reflection makes AI check its work.

```
Without reflection:
Task → Act → Output (might be wrong)

With reflection:
Task → Act → Output → Reflect → Fix → Verified Output
```

**Benefits:**
- Catches errors before delivery
- Improves output quality
- Handles edge cases
- Builds trust

**Costs:**
- More tokens
- More latency
- More complexity

For anything that matters, reflection is worth it.

Start with simple output verification. Add more sophisticated checks as you understand your failure modes. The goal isn't perfect — it's catching the obvious mistakes before users do.

The pattern scales well: simple reflection for simple tasks, multi-step verification for critical operations. Either way, you're building an agent that catches its mistakes.

## Related reading

- [Chain of Thought: When It Helps, When It Hurts](/post/chain-of-thought/) - Related reasoning pattern
- [Debugging Agent Thoughts](/post/debugging-thoughts/) - Understanding agent reasoning
- [Why Agents Get Stuck in Loops](/post/agent-loops/) - When reflection goes wrong

---

*Using reflection in your agents? What patterns work best for you?*
