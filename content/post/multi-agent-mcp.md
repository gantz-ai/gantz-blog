+++
title = "Building a Multi-Agent System with MCP"
date = 2025-12-07
description = "Build multi-agent systems with MCP. Tutorial on agent specialization, coordination patterns, and shared tool access for complex workflows."
image = "images/warrior-rain-city-04.webp"
draft = false
tags = ['mcp', 'architecture', 'tutorial']
voice = false

[howto]
name = "Build a Multi-Agent System with MCP"
totalTime = 60
[[howto.steps]]
name = "Design agent roles"
text = "Define specialized roles: researcher, writer, editor, or domain-specific agents."
[[howto.steps]]
name = "Create shared MCP tools"
text = "Build tools that multiple agents can access through a single MCP server."
[[howto.steps]]
name = "Implement coordinator"
text = "Create a coordinator agent that routes tasks to specialist agents."
[[howto.steps]]
name = "Set up communication"
text = "Define how agents pass context and results between each other."
[[howto.steps]]
name = "Test the workflow"
text = "Run a complex task through the multi-agent system and verify coordination."
+++


One AI agent is useful. Multiple agents working together? That's where things get interesting.

Here's how to build a multi-agent system using MCP.

## Why multiple agents?

Single agents hit limits:

- Too many tools = confused decisions
- Too much context = lost focus
- Too many responsibilities = jack of all trades, master of none

Multi-agent systems solve this by specialization.

```
Single agent:
"I need to research, write, edit, format, and publish this article"
→ Mediocre at everything

Multi-agent:
Researcher → Writer → Editor → Publisher
→ Each agent excels at one thing
```

## The architecture

```
                    ┌─────────────────┐
                    │   Coordinator   │
                    │     Agent       │
                    └────────┬────────┘
                             │
            ┌────────────────┼────────────────┐
            │                │                │
            ▼                ▼                ▼
    ┌───────────────┐ ┌───────────────┐ ┌───────────────┐
    │  Specialist   │ │  Specialist   │ │  Specialist   │
    │   Agent A     │ │   Agent B     │ │   Agent C     │
    └───────┬───────┘ └───────┬───────┘ └───────┬───────┘
            │                │                │
            ▼                ▼                ▼
    ┌───────────────┐ ┌───────────────┐ ┌───────────────┐
    │  MCP Server   │ │  MCP Server   │ │  MCP Server   │
    │  (Tools A)    │ │  (Tools B)    │ │  (Tools C)    │
    └───────────────┘ └───────────────┘ └───────────────┘
```

**Coordinator**: Breaks down tasks, delegates, synthesizes results

**Specialists**: Deep expertise in one domain, focused toolset

## Example: Content creation system

Let's build a system that researches, writes, and publishes articles.

### The specialists

**Research Agent**
```yaml
# research-tools.yaml
tools:
  - name: web_search
    description: Search the web for information
    parameters:
      - name: query
        type: string
        required: true
    script:
      shell: curl -s "https://api.search.com?q={{query}}"

  - name: fetch_page
    description: Get content from a URL
    parameters:
      - name: url
        type: string
        required: true
    script:
      shell: curl -s "{{url}}" | html2text

  - name: save_notes
    description: Save research notes
    parameters:
      - name: topic
        type: string
      - name: notes
        type: string
    script:
      shell: echo "{{notes}}" >> research/{{topic}}.md
```

**Writer Agent**
```yaml
# writer-tools.yaml
tools:
  - name: read_research
    description: Read research notes on a topic
    parameters:
      - name: topic
        type: string
    script:
      shell: cat research/{{topic}}.md

  - name: write_draft
    description: Save article draft
    parameters:
      - name: filename
        type: string
      - name: content
        type: string
    script:
      shell: echo "{{content}}" > drafts/{{filename}}.md

  - name: get_style_guide
    description: Get the writing style guide
    script:
      shell: cat config/style-guide.md
```

**Publisher Agent**
```yaml
# publisher-tools.yaml
tools:
  - name: read_draft
    description: Read a draft article
    parameters:
      - name: filename
        type: string
    script:
      shell: cat drafts/{{filename}}.md

  - name: publish_devto
    description: Publish to dev.to
    parameters:
      - name: title
        type: string
      - name: content
        type: string
      - name: tags
        type: string
    script:
      shell: |
        curl -X POST https://dev.to/api/articles \
          -H "api-key: $DEVTO_API_KEY" \
          -H "Content-Type: application/json" \
          -d '{"article":{"title":"{{title}}","body_markdown":"{{content}}","tags":["{{tags}}"]}}'

  - name: schedule_social
    description: Schedule social media posts
    parameters:
      - name: platform
        type: string
      - name: message
        type: string
    script:
      shell: echo "{{platform}}: {{message}}" >> scheduled-posts.txt
```

### The coordinator

```python
class CoordinatorAgent:
    def __init__(self):
        self.specialists = {
            "researcher": ResearchAgent(),
            "writer": WriterAgent(),
            "publisher": PublisherAgent()
        }

    def execute(self, task):
        # Break down the task
        plan = self.plan(task)

        results = {}
        for step in plan:
            specialist = self.specialists[step.agent]
            result = specialist.execute(step.task)
            results[step.id] = result

            # Pass context to next step
            if step.next:
                self.pass_context(results, step.next)

        return self.synthesize(results)

    def plan(self, task):
        response = llm.create(
            system="""You are a coordinator that breaks down tasks.
Given a task, create a plan with steps assigned to specialists.

Available specialists:
- researcher: Finds and gathers information
- writer: Creates written content
- publisher: Publishes and promotes content

Output format:
[
  {"id": 1, "agent": "researcher", "task": "...", "next": 2},
  {"id": 2, "agent": "writer", "task": "...", "next": 3},
  {"id": 3, "agent": "publisher", "task": "...", "next": null}
]""",
            messages=[{"role": "user", "content": task}]
        )
        return parse_plan(response)
```

### Running it

```python
coordinator = CoordinatorAgent()

result = coordinator.execute(
    "Write and publish an article about MCP tool servers"
)

# Execution flow:
# 1. Coordinator plans: research → write → publish
# 2. Research agent: searches web, gathers info, saves notes
# 3. Writer agent: reads notes, writes draft following style guide
# 4. Publisher agent: publishes to dev.to, schedules tweets
```

## Communication patterns

### Pattern 1: Sequential handoff

Each agent completes before the next starts.

```
Researcher → Writer → Editor → Publisher
     ↓          ↓        ↓         ↓
  Research   Draft    Edited   Published
   notes              draft     article
```

```python
def sequential_handoff(task, agents):
    context = {"original_task": task}

    for agent in agents:
        result = agent.execute(task, context)
        context[agent.name] = result

    return context
```

### Pattern 2: Parallel specialists

Multiple agents work simultaneously.

```
                    Coordinator
                         │
         ┌───────────────┼───────────────┐
         ▼               ▼               ▼
    Research A      Research B      Research C
         │               │               │
         └───────────────┼───────────────┘
                         ▼
                    Synthesize
```

```python
import asyncio

async def parallel_research(topics):
    tasks = [
        research_agent.execute(topic)
        for topic in topics
    ]
    results = await asyncio.gather(*tasks)
    return synthesize(results)
```

### Pattern 3: Hierarchical delegation

Specialists can delegate to sub-specialists.

```
Coordinator
     │
     ▼
Research Lead
     │
     ├── Web Researcher
     ├── Academic Researcher
     └── Social Media Researcher
```

```python
class ResearchLead:
    def __init__(self):
        self.team = {
            "web": WebResearcher(),
            "academic": AcademicResearcher(),
            "social": SocialResearcher()
        }

    def execute(self, task):
        # Delegate based on task type
        subtasks = self.analyze(task)
        results = {}

        for subtask in subtasks:
            researcher = self.team[subtask.type]
            results[subtask.id] = researcher.execute(subtask)

        return self.combine(results)
```

### Pattern 4: Feedback loops

Agents can request revisions from each other.

```
Writer → Editor
   ↑        │
   └────────┘
   (revisions)
```

```python
def write_with_feedback(task, max_revisions=3):
    draft = writer.execute(task)

    for i in range(max_revisions):
        feedback = editor.review(draft)

        if feedback.approved:
            return draft

        draft = writer.revise(draft, feedback.comments)

    return draft  # Best effort after max revisions
```

## Specialist design principles

### 1. Single responsibility

Each agent does one thing well.

```
Bad:
GeneralAgent → research, write, edit, publish, analyze, summarize...

Good:
ResearchAgent → find information
WriterAgent → create content
EditorAgent → improve content
PublisherAgent → distribute content
```

### 2. Focused toolset

Specialists only get tools they need.

```python
research_agent = Agent(
    tools=["web_search", "fetch_page", "save_notes"],
    system="You are a research specialist..."
)

writer_agent = Agent(
    tools=["read_notes", "write_draft", "get_style_guide"],
    system="You are a writing specialist..."
)
```

### 3. Clear interfaces

Define what goes in and what comes out.

```python
@dataclass
class ResearchOutput:
    topic: str
    summary: str
    sources: list[str]
    key_points: list[str]
    raw_notes: str

@dataclass
class WriterOutput:
    title: str
    content: str
    word_count: int
    reading_time: int
```

### 4. Specialized prompts

Each agent gets a focused system prompt.

```python
RESEARCH_PROMPT = """You are a research specialist.
Your job is to find accurate, relevant information.

Guidelines:
- Verify facts from multiple sources
- Note contradictions
- Cite all sources
- Focus on recent information
- Flag uncertain claims

You have access to: web_search, fetch_page, save_notes"""

WRITER_PROMPT = """You are a writing specialist.
Your job is to create clear, engaging content.

Guidelines:
- Follow the style guide
- Use active voice
- Keep paragraphs short
- Include examples
- Write for developers

You have access to: read_notes, write_draft, get_style_guide"""
```

## MCP server per specialist

Each specialist gets its own MCP server with relevant tools.

```
┌─────────────────┐
│   Coordinator   │
└────────┬────────┘
         │
    ┌────┴────┐
    │         │
    ▼         ▼
┌───────┐ ┌───────┐
│Gantz A│ │Gantz B│  ← Separate MCP servers
└───┬───┘ └───┬───┘
    │         │
    ▼         ▼
[Research] [Writing]
 tools      tools
```

Run multiple [Gantz](https://gantz.run) servers:

```bash
# Terminal 1: Research tools
cd research-tools && gantz

# Terminal 2: Writer tools
cd writer-tools && gantz

# Terminal 3: Publisher tools
cd publisher-tools && gantz
```

Or use different ports:

```bash
gantz --config research-tools.yaml --port 3001
gantz --config writer-tools.yaml --port 3002
gantz --config publisher-tools.yaml --port 3003
```

Connect agents to their servers:

```python
research_agent = Agent(
    mcp_server="http://localhost:3001/sse"
)

writer_agent = Agent(
    mcp_server="http://localhost:3002/sse"
)

publisher_agent = Agent(
    mcp_server="http://localhost:3003/sse"
)
```

## Error handling

### Agent failure

```python
def execute_with_fallback(task, primary_agent, backup_agent):
    try:
        return primary_agent.execute(task)
    except AgentError as e:
        logger.warning(f"Primary agent failed: {e}")
        return backup_agent.execute(task)
```

### Partial completion

```python
def execute_plan(plan, agents):
    results = {}
    failed_steps = []

    for step in plan:
        try:
            results[step.id] = agents[step.agent].execute(step.task)
        except Exception as e:
            failed_steps.append({"step": step, "error": str(e)})
            if step.critical:
                raise PlanFailure(f"Critical step failed: {step.id}")

    return {"results": results, "failures": failed_steps}
```

### Timeout handling

```python
import asyncio

async def execute_with_timeout(agent, task, timeout=60):
    try:
        return await asyncio.wait_for(
            agent.execute(task),
            timeout=timeout
        )
    except asyncio.TimeoutError:
        return {"status": "timeout", "partial": agent.get_partial_result()}
```

## Monitoring multi-agent systems

Track what each agent is doing:

```python
class AgentMonitor:
    def __init__(self):
        self.logs = []

    def log_event(self, agent, event_type, data):
        self.logs.append({
            "timestamp": datetime.now(),
            "agent": agent,
            "type": event_type,
            "data": data
        })

    def get_timeline(self):
        return sorted(self.logs, key=lambda x: x["timestamp"])

# Usage
monitor = AgentMonitor()

# In coordinator
monitor.log_event("coordinator", "plan_created", plan)
monitor.log_event("researcher", "task_started", task)
monitor.log_event("researcher", "tool_called", {"tool": "web_search"})
monitor.log_event("researcher", "task_completed", result)
```

## Real example: Code review system

**Coordinator**: Receives PR, orchestrates review

**Security Agent**: Checks for vulnerabilities
```yaml
tools:
  - name: scan_secrets
  - name: check_dependencies
  - name: analyze_auth_code
```

**Performance Agent**: Checks for bottlenecks
```yaml
tools:
  - name: profile_code
  - name: check_complexity
  - name: find_n_plus_one
```

**Style Agent**: Checks formatting and conventions
```yaml
tools:
  - name: run_linter
  - name: check_naming
  - name: verify_docs
```

```python
coordinator.execute("Review PR #123")

# Flow:
# 1. Coordinator fetches PR diff
# 2. Security agent scans for vulnerabilities
# 3. Performance agent checks for issues (parallel)
# 4. Style agent checks conventions (parallel)
# 5. Coordinator synthesizes into single review
```

## When to use multi-agent

**Use multi-agent when:**
- Tasks have distinct phases
- Different expertise needed
- Parallelization possible
- Single agent overwhelmed
- Clear handoff points

**Stick with single agent when:**
- Simple tasks
- Tight coupling needed
- Latency critical
- Context must stay unified

## Summary

Multi-agent systems = divide and conquer.

```
┌─────────────┐
│ Coordinator │  Breaks down, delegates, synthesizes
└──────┬──────┘
       │
   ┌───┴───┐
   ▼       ▼
┌─────┐ ┌─────┐
│Agent│ │Agent│  Specialists with focused tools
└──┬──┘ └──┬──┘
   │       │
   ▼       ▼
┌─────┐ ┌─────┐
│ MCP │ │ MCP │  Each with its own MCP server
└─────┘ └─────┘
```

Key principles:
- Single responsibility per agent
- Focused toolsets
- Clear interfaces
- Specialized prompts
- Proper error handling

Start simple. One coordinator, two specialists. Add complexity as needed.

## Related reading

- [The Planner-Executor Pattern](/post/planner-executor/) - Task orchestration pattern
- [Monolith vs Microservices for Agents](/post/monolith-microservices/) - Architecture decisions
- [Error Recovery Patterns for AI Agents](/post/error-recovery/) - Handling failures

---

*Building multi-agent systems? What patterns have worked for you?*
