+++
title = "Chain of Thought: When It Helps, When It Hurts"
date = 2025-12-29
image = "images/agent-arctic-aurora.webp"
draft = false
tags = ['prompting', 'patterns', 'best-practices']
+++


"Think step by step."

Four words that supposedly make AI smarter.

Sometimes they do. Sometimes they make everything worse.

Here's when to use chain of thought, and when to skip it.

## What is chain of thought?

Chain of thought (CoT) prompts the model to show its reasoning before answering.

```
Without CoT:
Q: If a train travels 120 miles in 2 hours, what's its speed?
A: 60 mph

With CoT:
Q: If a train travels 120 miles in 2 hours, what's its speed? Think step by step.
A: Let me work through this:
   1. Speed = Distance / Time
   2. Distance = 120 miles
   3. Time = 2 hours
   4. Speed = 120 / 2 = 60 mph

   The train's speed is 60 mph.
```

Same answer. But the model "thought" about it first.

## When CoT helps

### Complex multi-step reasoning

```
Task: "Is this code vulnerable to SQL injection?"

Without CoT:
"No, the code looks fine."
(Wrong - missed the vulnerability)

With CoT:
"Let me analyze this step by step:
1. The function takes user input from request.params
2. The input is concatenated directly into the SQL string
3. No parameterization or escaping is used
4. An attacker could input: ' OR '1'='1
5. This would bypass the WHERE clause

Yes, this code is vulnerable to SQL injection."
(Correct - found the issue)
```

CoT forces the model to actually trace through the logic.

### Math and calculations

```
Task: "Calculate the total cost with tax and discount"

Without CoT:
"$127.50"
(Sometimes wrong)

With CoT:
"Let me calculate:
1. Base price: $150
2. Discount (15%): $150 × 0.15 = $22.50
3. After discount: $150 - $22.50 = $127.50
4. Tax (8%): $127.50 × 0.08 = $10.20
5. Total: $127.50 + $10.20 = $137.70"
(Shows work, catches errors)
```

### Ambiguous problems

```
Task: "Should I use Redis or PostgreSQL for this?"

Without CoT:
"Use Redis."
(No reasoning, hard to trust)

With CoT:
"Let me consider the requirements:
1. Data size: ~10GB - both can handle this
2. Query patterns: Complex joins needed - favors PostgreSQL
3. Persistence: Must survive restarts - both support this
4. Latency: <10ms needed - Redis is faster, but PostgreSQL can achieve this with proper indexing
5. Consistency: Strong consistency required - favors PostgreSQL

Recommendation: PostgreSQL, because the complex joins and consistency requirements outweigh the latency advantage of Redis."
```

Shows reasoning. User can evaluate the logic.

### Debugging and analysis

```
Task: "Why is this test failing?"

Without CoT:
"The assertion is wrong."
(Vague, might be wrong)

With CoT:
"Let me trace through the test:
1. Test calls createUser({name: 'Alice'})
2. createUser should return {id, name, createdAt}
3. Test expects response.id to be defined
4. Looking at createUser... it returns {name, createdAt} but NOT id
5. The id is generated but not included in the return object

The test fails because createUser doesn't return the id field."
```

## When CoT hurts

### Simple factual questions

```
Task: "What's the capital of France?"

Without CoT:
"Paris"
(Correct, fast)

With CoT:
"Let me think about this step by step. France is a country in Western Europe. The capital of a country is typically its seat of government. France's government is located in... Paris."

Result: Same answer, 4x the tokens, added latency.
```

CoT adds cost with no benefit for simple lookups.

### Clear-cut decisions

```
Task: "Is 'hello world' a valid Python string?"

Without CoT:
"Yes"
(Correct, instant)

With CoT:
"Let me analyze this:
1. In Python, strings can be defined with single or double quotes
2. 'hello world' uses single quotes
3. The content contains letters and a space
4. Spaces are valid in strings
5. Therefore, yes, this is a valid Python string."

Result: Overthinking a trivial question.
```

### Speed-critical tasks

```
Without CoT:
Response time: 200ms

With CoT:
Response time: 800ms
```

If you're building autocomplete or real-time features, CoT kills your latency.

### When it causes overthinking

```
Task: "Read the config file and tell me the port number"

Without CoT:
*reads file*
"The port is 3000"

With CoT:
"Let me think about how to approach this:
1. First, I should determine the file format
2. Config files can be JSON, YAML, TOML, or INI
3. I should read the file to check the format
4. Then parse it appropriately
5. Look for a 'port' key
6. Consider that it might be nested under 'server' or 'http'
7. Also check for environment variable overrides
..."
*spends 30 seconds planning instead of just reading the file*
```

Analysis paralysis.

### When it introduces errors

Sometimes CoT makes the model talk itself into wrong answers:

```
Task: "Is 0.1 + 0.2 == 0.3 in JavaScript?"

Without CoT:
"No, due to floating point precision."
(Correct)

With CoT:
"Let me think:
1. 0.1 + 0.2 should equal 0.3
2. This is basic arithmetic
3. JavaScript handles numbers fine for simple operations
4. Therefore, yes, 0.1 + 0.2 == 0.3 is true."
(Wrong - talked itself into the intuitive but incorrect answer)
```

The model's "reasoning" followed common sense instead of technical accuracy.

## The cost of CoT

### Token cost

```
Simple question without CoT: ~50 tokens response
Simple question with CoT: ~200 tokens response

1000 queries/day × 150 extra tokens × $0.01/1K = $1.50/day wasted
```

### Latency cost

```
Without CoT:
- Tokens generated: 20
- Time: 200ms

With CoT:
- Tokens generated: 150
- Time: 1.5s
```

7x slower for the same answer.

### Cognitive cost

Users have to read through reasoning they don't need:

```
User: "What's 2 + 2?"

Agent: "Let me work through this carefully. We have the number 2, and we need to add another 2 to it. Addition is the process of combining quantities. When we add 2 + 2, we get 4. Therefore, the answer is 4."

User: "I just wanted to know it's 4."
```

## The decision framework

```
┌─────────────────────────────────────────────────────┐
│                  Use CoT when:                       │
├─────────────────────────────────────────────────────┤
│ ✓ Multi-step reasoning required                      │
│ ✓ Math or calculations involved                      │
│ ✓ Debugging or analysis tasks                        │
│ ✓ User needs to verify the logic                     │
│ ✓ Problem is ambiguous                               │
│ ✓ Accuracy > Speed                                   │
└─────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────┐
│                  Skip CoT when:                      │
├─────────────────────────────────────────────────────┤
│ ✗ Simple factual questions                           │
│ ✗ Clear-cut yes/no decisions                         │
│ ✗ Speed is critical                                  │
│ ✗ Token budget is tight                              │
│ ✗ Answer is obvious                                  │
│ ✗ User doesn't need reasoning                        │
└─────────────────────────────────────────────────────┘
```

## Implementation patterns

### Pattern 1: Conditional CoT

```python
def should_use_cot(query: str) -> bool:
    """Decide if query needs chain of thought"""
    cot_indicators = [
        "why", "how", "explain", "analyze", "debug",
        "calculate", "compare", "evaluate", "which is better",
        "step by step", "reasoning"
    ]

    simple_indicators = [
        "what is", "who is", "when", "where",
        "yes or no", "true or false", "list"
    ]

    query_lower = query.lower()

    if any(ind in query_lower for ind in cot_indicators):
        return True
    if any(ind in query_lower for ind in simple_indicators):
        return False

    # Default: use CoT for longer queries
    return len(query.split()) > 15

def get_response(query: str) -> str:
    if should_use_cot(query):
        prompt = f"{query}\n\nThink through this step by step."
    else:
        prompt = f"{query}\n\nAnswer directly and concisely."

    return llm.create(prompt)
```

### Pattern 2: Hidden CoT

Get the benefits without showing the user:

```python
def get_response_with_hidden_cot(query: str) -> str:
    # First call: get reasoning (hidden from user)
    reasoning = llm.create(
        f"{query}\n\nThink through this step by step, showing your reasoning."
    )

    # Second call: get clean answer using the reasoning
    answer = llm.create(
        f"""Based on this reasoning:
{reasoning}

Now provide a concise, direct answer to: {query}

Don't show the reasoning, just the final answer."""
    )

    return answer
```

User gets accurate answer. Reasoning happens behind the scenes.

### Pattern 3: CoT with extraction

```python
def get_response_with_cot(query: str) -> dict:
    response = llm.create(
        f"""{query}

Think through this step by step, then provide your final answer.

Format:
REASONING:
[your step by step thinking]

ANSWER:
[your final answer]"""
    )

    # Parse out the parts
    parts = response.split("ANSWER:")
    reasoning = parts[0].replace("REASONING:", "").strip()
    answer = parts[1].strip() if len(parts) > 1 else response

    return {
        "reasoning": reasoning,
        "answer": answer
    }

# Usage - show reasoning only when needed
result = get_response_with_cot("Why is the build failing?")
print(result["answer"])  # User sees this

if user_wants_details:
    print(result["reasoning"])  # Optional detail
```

### Pattern 4: CoT for agents

For agents, CoT helps with tool selection:

```python
SYSTEM_PROMPT = """
You are a coding assistant with tools: read, write, search, run.

When deciding which tool to use, briefly think through:
1. What does the user need?
2. What information do I need first?
3. Which tool gets me that information?

Then use the appropriate tool.
"""
```

Example:

```
User: "Fix the bug in auth.py"

Agent thinking:
"User wants to fix a bug.
1. I need to see the current code first
2. I should read auth.py
3. Then identify the bug
4. Then fix it"

Agent: 🔧 read({"path": "auth.py"})
```

Without CoT, agents sometimes skip straight to modifications without reading first.

### Pattern 5: Minimal CoT

Just enough reasoning, not verbose:

```python
SYSTEM_PROMPT = """
When solving problems:
- State your approach in one line
- Then execute

Don't explain basic concepts or obvious steps.
"""
```

Result:

```
User: "Calculate compound interest: $1000, 5%, 10 years"

Agent: "Using A = P(1 + r)^t: $1000 × (1.05)^10 = $1,628.89"
```

Shows the formula used (verifiable) without paragraphs of explanation.

## For RAG pipelines

CoT can help with answer synthesis:

```python
def rag_with_cot(query: str, context: str) -> str:
    return llm.create(f"""
Context:
{context}

Question: {query}

Think through which parts of the context are relevant, then answer.
Keep reasoning brief.
""")
```

This helps the model:
1. Identify relevant passages
2. Ignore irrelevant retrieved content
3. Synthesize from multiple sources

## Tool descriptions as CoT hints

With [Gantz](https://gantz.run), tool descriptions can hint when to think:

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

  - name: analyze
    description: Analyze code for issues. Think through potential bugs, security issues, and performance problems before reporting.
    parameters:
      - name: path
        type: string
        required: true
    script:
      shell: cat "{{path}}"
```

The `analyze` tool's description encourages reasoning. The `read` tool's description is direct - just do it.

## Measuring CoT impact

```python
def evaluate_cot_impact(test_cases: list) -> dict:
    results = {"with_cot": [], "without_cot": []}

    for case in test_cases:
        # Without CoT
        start = time.time()
        answer_no_cot = get_response(case["query"], use_cot=False)
        time_no_cot = time.time() - start
        correct_no_cot = answer_no_cot == case["expected"]

        # With CoT
        start = time.time()
        answer_cot = get_response(case["query"], use_cot=True)
        time_cot = time.time() - start
        correct_cot = answer_cot == case["expected"]

        results["without_cot"].append({
            "correct": correct_no_cot,
            "time": time_no_cot
        })
        results["with_cot"].append({
            "correct": correct_cot,
            "time": time_cot
        })

    # Summarize
    return {
        "accuracy_without_cot": sum(r["correct"] for r in results["without_cot"]) / len(test_cases),
        "accuracy_with_cot": sum(r["correct"] for r in results["with_cot"]) / len(test_cases),
        "avg_time_without_cot": sum(r["time"] for r in results["without_cot"]) / len(test_cases),
        "avg_time_with_cot": sum(r["time"] for r in results["with_cot"]) / len(test_cases),
    }
```

Run this on your actual queries to see if CoT helps your use case.

## Summary

Chain of thought:

| Scenario | Use CoT? | Why |
|----------|----------|-----|
| Math problems | ✅ Yes | Reduces calculation errors |
| Code analysis | ✅ Yes | Forces thorough review |
| Debugging | ✅ Yes | Traces through logic |
| Ambiguous questions | ✅ Yes | Shows reasoning for trust |
| Simple lookups | ❌ No | Wastes tokens |
| Yes/no questions | ❌ No | Overthinking |
| Speed-critical | ❌ No | Adds latency |
| Obvious answers | ❌ No | Unnecessary |

The rule: **Use CoT when thinking helps. Skip it when it doesn't.**

Don't add "think step by step" to everything. Be selective.

---

*Do you use chain of thought in your prompts? When does it help most?*
