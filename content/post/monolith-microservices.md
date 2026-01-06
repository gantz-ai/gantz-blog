+++
title = "Monolith vs Microservices for Agents"
date = 2025-12-08
image = "/images/robot-billboard-04.png"
draft = false
tags = ['agents', 'ai', 'mcp']
+++


Do you build one agent that does everything?

Or many specialized agents that talk to each other?

The same debate that haunts backend architecture haunts agents too.

Here's how to choose.

## The monolith agent

One agent. One system prompt. All capabilities.

```python
class MonolithAgent:
    def __init__(self):
        self.tools = [
            read_file,
            write_file,
            search_code,
            run_tests,
            query_database,
            send_email,
            create_ticket,
            deploy,
            monitor_metrics,
            # ... 30 more tools
        ]

        self.system_prompt = """
You are an all-in-one development assistant.
You can:
- Read and write code
- Run tests and debug
- Query databases
- Send notifications
- Deploy applications
- Monitor systems
...
"""

    def run(self, user_request):
        return agent_loop(self.system_prompt, self.tools, user_request)
```

One agent handles everything.

## The microservices approach

Many specialized agents. Each does one thing well.

```python
# Separate agents
coding_agent = Agent(
    tools=[read_file, write_file, search_code],
    prompt="You are a coding assistant. You read and write code."
)

testing_agent = Agent(
    tools=[run_tests, analyze_coverage, debug],
    prompt="You are a testing specialist. You run and debug tests."
)

database_agent = Agent(
    tools=[query, migrate, backup],
    prompt="You are a database administrator. You manage data."
)

deploy_agent = Agent(
    tools=[build, deploy, rollback],
    prompt="You are a deployment specialist. You ship code safely."
)

# Orchestrator routes to specialists
class Orchestrator:
    def __init__(self):
        self.agents = {
            "coding": coding_agent,
            "testing": testing_agent,
            "database": database_agent,
            "deploy": deploy_agent,
        }

    def route(self, request):
        agent_type = self.classify(request)
        return self.agents[agent_type].run(request)
```

## Comparison

| Aspect | Monolith | Microservices |
|--------|----------|---------------|
| Complexity | Simple | Complex |
| Context | Shared | Isolated |
| Latency | Lower | Higher (routing) |
| Failure blast radius | Everything | One service |
| Prompt size | Large | Small, focused |
| Tool confusion | Higher | Lower |
| Development speed | Faster initially | Faster at scale |
| Debugging | Harder | Easier (isolated) |

## When monolith wins

### Small scope

```
Total tools: 5-10
Use cases: Focused (just coding, just support, etc.)
Team size: 1-3 developers
```

One agent handles it fine. Don't over-engineer.

### Highly connected tasks

```
User: "Read the config, update the database URL, then run migrations"

Monolith: One agent, full context, executes sequentially
Microservices: Config agent → Database agent → Migration agent
              (Context lost between handoffs)
```

When tasks need shared context, monolith is simpler.

### Speed matters

```
Monolith:
User → Agent → Response
Latency: ~2s

Microservices:
User → Router → Classify → Agent → Response
Latency: ~4s (extra LLM call for routing)
```

If you need fast responses, avoid the routing overhead.

### Early stage

```
Week 1: Build monolith
Week 2: Ship to users
Week 3: Learn what's actually needed
Week 4: Refactor if necessary

vs.

Week 1-4: Design perfect microservices architecture
Week 5: Ship
Week 6: Realize requirements were wrong
```

Start monolith. Split when you feel pain.

## When microservices win

### Many tools cause confusion

```python
# Monolith with 40 tools
tools = [
    read_file, write_file, search_code,    # coding
    run_tests, debug, coverage,            # testing
    query_db, migrate, backup,             # database
    build, deploy, rollback,               # deployment
    send_email, send_slack, create_ticket, # notifications
    # ... 25 more tools
]

# Agent thinks:
# "User wants to 'run the tests'...
#  Should I use run_tests? Or debug? Or coverage?
#  Maybe I should query_db first to check test data?
#  Let me send_slack to ask..."
```

Too many tools = wrong tool selection.

```python
# Microservice: Testing agent with 3 tools
tools = [run_tests, debug, coverage]

# Agent thinks:
# "User wants to 'run the tests'...
#  I'll use run_tests."
```

Fewer tools = better decisions.

### Different trust levels

```python
# Coding agent: Can read/write user's code
# Allowed: read_file, write_file, search

# Deploy agent: Can push to production
# Requires: Extra confirmation, audit log, approval

# Admin agent: Can modify infrastructure
# Requires: 2FA, senior approval, change ticket
```

Microservices let you apply different security policies.

### Different models for different tasks

```python
# Simple routing: Fast, cheap model
router = Agent(model="haiku", ...)

# Complex coding: Smart, expensive model
coding_agent = Agent(model="opus", ...)

# Simple lookups: Fast model is fine
docs_agent = Agent(model="haiku", ...)
```

Microservices let you optimize cost per task type.

### Independent scaling

```
Coding requests: 1000/day → needs fast responses
Deploy requests: 10/day → can be slower, more careful

Monolith: Scale everything together
Microservices: Scale coding agent, keep deploy agent minimal
```

### Independent deployment

```
# Coding agent updated → deploy coding agent only
# Deploy agent unchanged → no risk to deployments

vs.

# Monolith updated → everything changes
# Bug in coding → might affect deployments
```

Blast radius is smaller.

## The hybrid: Monolith with modules

You don't have to go full microservices. Modularize within one agent:

```python
class ModularAgent:
    def __init__(self):
        self.modules = {
            "coding": CodingModule(),
            "testing": TestingModule(),
            "database": DatabaseModule(),
        }

        self.system_prompt = self.build_prompt()

    def build_prompt(self):
        prompt = "You are a development assistant.\n\n"

        # Only include relevant module instructions
        for name, module in self.modules.items():
            prompt += f"## {name.title()}\n{module.instructions}\n\n"

        return prompt

    def get_tools(self, context):
        """Return relevant tools based on context"""
        relevant = self.detect_relevant_modules(context)
        tools = []
        for module_name in relevant:
            tools.extend(self.modules[module_name].tools)
        return tools

    def run(self, request):
        # Dynamic tool selection based on request
        tools = self.get_tools(request)
        return agent_loop(self.system_prompt, tools, request)
```

One agent, but tool set changes based on context.

## The routing problem

If you go microservices, how do you route?

### Option 1: Keyword routing

```python
def route(request: str) -> str:
    keywords = {
        "coding": ["code", "file", "function", "bug", "implement"],
        "testing": ["test", "coverage", "debug", "failing"],
        "database": ["query", "database", "sql", "migrate"],
        "deploy": ["deploy", "release", "rollback", "production"],
    }

    request_lower = request.lower()
    for agent, words in keywords.items():
        if any(word in request_lower for word in words):
            return agent

    return "coding"  # default
```

Fast, no LLM call. But brittle.

### Option 2: LLM routing

```python
def route(request: str) -> str:
    response = llm.create(
        model="haiku",  # Fast, cheap
        messages=[{
            "role": "user",
            "content": f"""Classify this request into one category:
- coding: Reading, writing, or modifying code
- testing: Running tests, debugging, coverage
- database: Database queries, migrations
- deploy: Deployment, releases, rollbacks

Request: {request}

Return only the category name."""
        }]
    )
    return response.strip().lower()
```

More accurate, but adds latency and cost.

### Option 3: Embedding routing

```python
from sklearn.metrics.pairwise import cosine_similarity

class EmbeddingRouter:
    def __init__(self):
        # Pre-compute embeddings for each agent type
        self.agent_embeddings = {
            "coding": embed("code files functions implementation"),
            "testing": embed("tests debugging coverage failures"),
            "database": embed("queries sql migrations data"),
            "deploy": embed("deployment release production rollback"),
        }

    def route(self, request: str) -> str:
        request_embedding = embed(request)

        best_match = None
        best_score = -1

        for agent, agent_emb in self.agent_embeddings.items():
            score = cosine_similarity([request_embedding], [agent_emb])[0][0]
            if score > best_score:
                best_score = score
                best_match = agent

        return best_match
```

No LLM call, reasonably accurate.

## Context handoff

The hardest part of microservices: passing context between agents.

### Bad: No context

```
User: "Check if the users table has an email column"
Database Agent: "Yes, it has an email column."

User: "Great, now write code to validate emails"
Coding Agent: "What users table? What email column?"
```

Context lost between agents.

### Better: Explicit handoff

```python
class Orchestrator:
    def __init__(self):
        self.context = {}

    def run(self, request):
        agent = self.route(request)

        # Pass accumulated context
        result = agent.run(request, context=self.context)

        # Capture context from result
        self.context.update(result.get("context", {}))

        return result["response"]
```

### Best: Shared memory

```python
class SharedMemory:
    def __init__(self, redis_client):
        self.redis = redis_client

    def store(self, session_id: str, key: str, value: str):
        self.redis.hset(f"session:{session_id}", key, value)

    def get(self, session_id: str, key: str) -> str:
        return self.redis.hget(f"session:{session_id}", key)

    def get_all(self, session_id: str) -> dict:
        return self.redis.hgetall(f"session:{session_id}")

# All agents read/write to shared memory
class Agent:
    def __init__(self, memory: SharedMemory):
        self.memory = memory

    def run(self, request, session_id):
        # Get shared context
        context = self.memory.get_all(session_id)

        # Do work
        result = self.execute(request, context)

        # Store discoveries
        for key, value in result.discoveries.items():
            self.memory.store(session_id, key, value)

        return result.response
```

## Migration path

Start simple, split when needed:

```
Stage 1: Monolith
- One agent, all tools
- Ship fast, learn

Stage 2: Monolith with modules
- Group tools logically
- Dynamic tool loading
- Still one agent

Stage 3: Extract high-value specialists
- Keep monolith for most tasks
- Extract: deploy agent (needs extra safety)
- Extract: database agent (needs audit)

Stage 4: Full microservices (if needed)
- Router + specialists
- Only if scale/complexity demands it
```

Most projects never need Stage 4.

## With Gantz

[Gantz](https://gantz.run) naturally supports the modular approach - group tools into focused configs:

```yaml
# gantz-coding.yaml
name: coding-tools
tools:
  - name: read
    description: Read a file
    script:
      shell: cat "{{path}}"

  - name: write
    description: Write to a file
    script:
      shell: echo "{{content}}" > "{{path}}"

  - name: search
    description: Search code
    script:
      shell: rg "{{query}}" . --max-count=20
```

```yaml
# gantz-testing.yaml
name: testing-tools
tools:
  - name: run_tests
    description: Run test suite
    script:
      shell: npm test

  - name: coverage
    description: Check test coverage
    script:
      shell: npm run coverage
```

Run different MCP servers for different agent specializations. Your client decides which to connect.

## Summary

| Situation | Recommendation |
|-----------|----------------|
| < 10 tools | Monolith |
| Early stage, learning | Monolith |
| Tightly coupled tasks | Monolith |
| Latency critical | Monolith |
| > 20 tools | Consider splitting |
| Different security needs | Microservices |
| Different model needs | Microservices |
| Independent scaling | Microservices |
| Large team | Microservices |

The rule: **Start monolith. Split when you feel the pain.**

Don't architect for problems you don't have.

---

*Are your agents monoliths or microservices? What drove the decision?*
