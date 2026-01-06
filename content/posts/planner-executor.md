+++
title = 'The Planner-Executor pattern explained'
date = 2025-12-04
draft = false
tags = ['agents', 'ai', 'mcp']
+++


Most AI agents use ReAct: think, act, observe, repeat. Simple and effective.

But for complex tasks, there's a better pattern: **Planner-Executor**.

Here's how it works.

## The problem with ReAct

ReAct is step-by-step. AI thinks one step ahead, acts, then thinks again.

```
User: "Migrate our database to the new schema"

ReAct agent:
1. Think: "I should look at the current schema"
2. Act: [reads schema]
3. Think: "Now I should create a backup"
4. Act: [creates backup]
5. Think: "Hmm, what's next... maybe write migration?"
6. Act: [writes migration]
7. Think: "Should I run it? Let me run it"
8. Act: [runs migration]
9. Think: "Oh no, I forgot to test it first"
```

Problem: No big picture thinking. AI stumbles through, making decisions one at a time.

For complex tasks, this leads to:
- Missed steps
- Wrong order
- No rollback plan
- Inefficient execution

## Planner-Executor: Two-phase approach

Split the work into two distinct phases:

**Phase 1: Plan**
AI creates a complete plan before doing anything.

**Phase 2: Execute**
AI (or a separate executor) follows the plan step by step.

```
User: "Migrate our database to the new schema"

PLANNER:
"Here's my plan:
1. Analyze current schema
2. Create backup
3. Write migration script
4. Test migration on copy
5. If tests pass, run on production
6. Verify data integrity
7. Update application config"

EXECUTOR:
[Executes step 1]
[Executes step 2]
[Executes step 3]
...
```

The planner thinks holistically. The executor just follows instructions.

## Why this works

### 1. Better reasoning

Planning happens without distraction. AI focuses on the full problem, not just the next step.

```
ReAct: "What should I do next?"
Planner: "What's the complete solution?"
```

### 2. Catch mistakes early

Bad plans are caught before execution.

```
Planner: "Step 3: Delete production database"
Human: "Wait, that's wrong"
[Fixed before anything happens]
```

### 3. Parallel execution

Independent steps can run simultaneously.

```
Plan:
1. Backup database        ─┐
2. Backup files           ─┼─→ Can run in parallel
3. Notify team            ─┘
4. Run migration          ← Must wait for 1-3
```

### 4. Easier debugging

When something fails, you know exactly where in the plan it broke.

```
Plan: [1] ✓  [2] ✓  [3] ✗  [4] -  [5] -
"Step 3 failed: migration script syntax error"
```

### 5. Human oversight

Humans can review the plan before execution.

```
Planner: "Here's my plan..."
Human: "Approved" / "Modify step 3"
Executor: [proceeds with approved plan]
```

## Implementation

### Basic structure

```python
class PlannerExecutor:
    def __init__(self, planner_llm, executor_llm, tools):
        self.planner = planner_llm
        self.executor = executor_llm
        self.tools = tools

    def run(self, task):
        # Phase 1: Plan
        plan = self.create_plan(task)

        # Optional: Human approval
        if not self.approve_plan(plan):
            return "Plan rejected"

        # Phase 2: Execute
        results = self.execute_plan(plan)

        return results
```

### The Planner

```python
def create_plan(self, task):
    response = self.planner.create(
        system="""You are a planning agent.
Given a task, create a detailed step-by-step plan.

Rules:
- Break complex tasks into simple steps
- Each step should be one tool call
- Consider dependencies between steps
- Include verification steps
- Plan for failure cases

Output format:
{
  "goal": "what we're trying to achieve",
  "steps": [
    {"id": 1, "action": "tool_name", "params": {...}, "depends_on": []},
    {"id": 2, "action": "tool_name", "params": {...}, "depends_on": [1]},
  ],
  "rollback": [...]
}""",
        messages=[{"role": "user", "content": f"Create a plan for: {task}"}]
    )
    return parse_plan(response)
```

### The Executor

```python
def execute_plan(self, plan):
    results = {}

    for step in plan.steps:
        # Check dependencies
        if not self.dependencies_met(step, results):
            continue  # or wait

        # Execute step
        try:
            result = self.tools.call(step.action, step.params)
            results[step.id] = {"status": "success", "result": result}
        except Exception as e:
            results[step.id] = {"status": "failed", "error": str(e)}

            # Handle failure
            if plan.rollback:
                self.execute_rollback(plan.rollback, results)
            break

    return results
```

## With MCP

MCP fits naturally into this pattern. The executor calls tools via MCP.

```yaml
# gantz.yaml
tools:
  - name: read_schema
    description: Read current database schema
    script:
      shell: pg_dump --schema-only mydb

  - name: backup_database
    description: Create database backup
    script:
      shell: pg_dump mydb > backup_$(date +%Y%m%d).sql

  - name: run_migration
    description: Execute a migration file
    parameters:
      - name: file
        type: string
        required: true
    script:
      shell: psql mydb < {{file}}

  - name: verify_integrity
    description: Check data integrity after migration
    script:
      shell: python scripts/verify_data.py
```

```python
# Executor uses MCP
def execute_step(self, step):
    return mcp_client.call_tool(
        step.action,
        step.params
    )
```

## Example: Deploy application

**Task:** "Deploy the new version to production"

**Planner output:**

```json
{
  "goal": "Deploy v2.3.1 to production safely",
  "steps": [
    {
      "id": 1,
      "action": "run_tests",
      "params": {},
      "depends_on": [],
      "description": "Run full test suite"
    },
    {
      "id": 2,
      "action": "build_docker",
      "params": {"tag": "v2.3.1"},
      "depends_on": [1],
      "description": "Build Docker image"
    },
    {
      "id": 3,
      "action": "backup_database",
      "params": {},
      "depends_on": [],
      "description": "Backup production database"
    },
    {
      "id": 4,
      "action": "deploy_staging",
      "params": {"tag": "v2.3.1"},
      "depends_on": [2],
      "description": "Deploy to staging"
    },
    {
      "id": 5,
      "action": "run_smoke_tests",
      "params": {"env": "staging"},
      "depends_on": [4],
      "description": "Verify staging works"
    },
    {
      "id": 6,
      "action": "deploy_production",
      "params": {"tag": "v2.3.1"},
      "depends_on": [3, 5],
      "description": "Deploy to production"
    },
    {
      "id": 7,
      "action": "run_smoke_tests",
      "params": {"env": "production"},
      "depends_on": [6],
      "description": "Verify production works"
    },
    {
      "id": 8,
      "action": "notify_team",
      "params": {"message": "v2.3.1 deployed"},
      "depends_on": [7],
      "description": "Send notification"
    }
  ],
  "rollback": [
    {"action": "rollback_production", "params": {"to": "previous"}},
    {"action": "notify_team", "params": {"message": "Rollback executed"}}
  ]
}
```

**Execution:**

```
[1] run_tests         ✓ (parallel with 3)
[3] backup_database   ✓ (parallel with 1)
[2] build_docker      ✓ (after 1)
[4] deploy_staging    ✓ (after 2)
[5] run_smoke_tests   ✓ (after 4)
[6] deploy_production ✓ (after 3, 5)
[7] run_smoke_tests   ✓ (after 6)
[8] notify_team       ✓ (after 7)

Deployment complete!
```

## Variations

### Plan-and-Solve

Planner breaks task into subtasks, executor solves each.

```
Plan: [Subtask A] → [Subtask B] → [Subtask C]
Execute: Solve A, Solve B, Solve C
```

### Hierarchical planning

High-level plan, then detailed plans for each step.

```
High-level: [Phase 1] → [Phase 2] → [Phase 3]
Phase 1 plan: [Step 1.1] → [Step 1.2] → [Step 1.3]
```

### Adaptive planning

Replan if execution fails or context changes.

```
Plan → Execute → Fail → Replan → Execute → Success
```

### Multi-agent

Separate agents for planning and execution.

```
Planner Agent → Plan → Executor Agent → Results
```

## When to use

**Use Planner-Executor when:**
- Complex, multi-step tasks
- Order matters
- Failure has consequences
- Human oversight needed
- Parallel execution possible
- Rollback might be necessary

**Stick with ReAct when:**
- Simple tasks
- Exploratory work
- Unknown number of steps
- Interactive/conversational

## Common mistakes

### Mistake 1: Over-planning

Don't plan trivial tasks.

```
Task: "What time is it?"
Bad: Create 5-step plan
Good: Just call the tool
```

### Mistake 2: Rigid execution

Plans should adapt. If something changes, replan.

```
Step 3 failed → Don't blindly continue
             → Assess, maybe replan
```

### Mistake 3: No rollback plan

For critical operations, always plan for failure.

```
Good plan:
- Steps 1-5: Do the thing
- Rollback: Undo if it breaks
```

### Mistake 4: Planner can't see tools

Planner needs to know what tools exist.

```python
# Give planner the tool list
planner.create(
    system=f"Available tools: {tools.list()}"
)
```

## Tools

**Frameworks:**
- LangChain (Plan-and-Execute agent)
- LlamaIndex (with planning)
- Custom implementation

**MCP Server:**
- [Gantz](https://gantz.run) for tool execution

## Summary

**Planner-Executor separates thinking from doing.**

```
┌────────────┐      ┌────────────┐      ┌─────────┐
│   Task     │─────→│  Planner   │─────→│  Plan   │
└────────────┘      └────────────┘      └────┬────┘
                                             │
                                             ▼
┌────────────┐      ┌────────────┐      ┌─────────┐
│  Results   │←─────│  Executor  │←─────│  Plan   │
└────────────┘      └────────────┘      └─────────┘
```

- Planner: Creates complete plan upfront
- Executor: Follows plan step by step
- Better for complex, critical tasks
- Easier to debug, review, parallelize

Think first, then act.

---

*Using Planner-Executor in your agents? What's worked for you?*
