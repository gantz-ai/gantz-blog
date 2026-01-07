+++
title = "Multi-Agent Systems: Coordinate AI Workers"
image = "images/multi-agent-systems.webp"
date = 2025-11-18
description = "Build multi-agent systems where specialized AI agents collaborate. Orchestration patterns, communication, and task delegation using MCP."
draft = false
tags = ['mcp', 'architecture', 'multi-agent']
voice = false

[howto]
name = "Build Multi-Agent Systems"
totalTime = 40
[[howto.steps]]
name = "Design agent roles"
text = "Define specialized agents with specific responsibilities."
[[howto.steps]]
name = "Implement orchestration"
text = "Build the coordinator that delegates tasks."
[[howto.steps]]
name = "Create communication"
text = "Enable agents to share information and results."
[[howto.steps]]
name = "Handle coordination"
text = "Manage dependencies and ordering between agents."
[[howto.steps]]
name = "Aggregate results"
text = "Combine outputs from multiple agents."
+++


One agent is smart. Multiple agents are smarter.

Specialized agents. Working together. Solving complex problems.

Here's how to build it.

## Why multi-agent systems?

Single agent limitations:
- Context window constraints
- One perspective/approach
- Can't parallelize
- Limited specialization

Multi-agent benefits:
- Specialized expertise
- Parallel processing
- Check each other's work
- Handle complex workflows

## Patterns

1. **Orchestrator**: One agent delegates to specialists
2. **Pipeline**: Agents process sequentially
3. **Swarm**: Agents work in parallel, aggregate results
4. **Debate**: Agents argue different positions

## Step 1: Define agent roles

Using [Gantz](https://gantz.run):

```yaml
# gantz.yaml
name: multi-agent

tools:
  - name: delegate_to_agent
    description: Send a task to a specialized agent
    parameters:
      - name: agent_name
        type: string
        required: true
        description: "researcher, analyst, writer, reviewer"
      - name: task
        type: string
        required: true
      - name: context
        type: string
    script:
      command: python
      args: ["scripts/delegate.py", "{{agent_name}}", "{{context}}"]
      stdin: "{{task}}"

  - name: get_agent_result
    description: Get result from a delegated task
    parameters:
      - name: task_id
        type: string
        required: true
    script:
      command: python
      args: ["scripts/get_result.py", "{{task_id}}"]

  - name: broadcast_message
    description: Send a message to all agents
    parameters:
      - name: message
        type: string
        required: true
    script:
      command: python
      args: ["scripts/broadcast.py"]
      stdin: "{{message}}"

  - name: get_agent_state
    description: Get current state of an agent
    parameters:
      - name: agent_name
        type: string
        required: true
    script:
      command: python
      args: ["scripts/get_state.py", "{{agent_name}}"]

  - name: aggregate_results
    description: Combine results from multiple agents
    parameters:
      - name: task_ids
        type: string
        required: true
        description: Comma-separated task IDs
    script:
      command: python
      args: ["scripts/aggregate.py", "{{task_ids}}"]
```

```bash
gantz run --auth
```

## Step 2: Specialized agents

```python
import anthropic
from typing import Dict, Optional
import json

MCP_URL = "https://multi-agent.gantz.run/sse"
MCP_TOKEN = "gtz_abc123"

client = anthropic.Anthropic()

# Define specialized agent prompts
AGENT_PROMPTS = {
    "researcher": """You are a Research Agent.
Your role:
- Find and gather information
- Summarize sources
- Identify key facts
- Note uncertainties

Output: Structured research findings with sources.""",

    "analyst": """You are an Analysis Agent.
Your role:
- Analyze data and findings
- Identify patterns and trends
- Draw conclusions
- Quantify when possible

Output: Clear analysis with supporting evidence.""",

    "writer": """You are a Writing Agent.
Your role:
- Craft clear, engaging content
- Structure information logically
- Adapt tone to audience
- Polish and refine

Output: Well-written content ready for use.""",

    "reviewer": """You are a Review Agent.
Your role:
- Check for errors and issues
- Verify claims and accuracy
- Suggest improvements
- Ensure quality standards

Output: Detailed review with specific feedback.""",

    "planner": """You are a Planning Agent.
Your role:
- Break down complex tasks
- Identify dependencies
- Create execution plans
- Estimate effort

Output: Step-by-step plan with clear actions.""",

    "coder": """You are a Coding Agent.
Your role:
- Write clean, functional code
- Follow best practices
- Handle edge cases
- Document your code

Output: Working code with comments."""
}

def run_agent(agent_name: str, task: str, context: str = "") -> str:
    """Run a specialized agent on a task."""

    system_prompt = AGENT_PROMPTS.get(agent_name, "You are a helpful assistant.")

    full_prompt = f"""{system_prompt}

Context from other agents:
{context if context else 'No additional context.'}

Task: {task}"""

    response = client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=4096,
        system=full_prompt,
        messages=[{
            "role": "user",
            "content": task
        }],
        tools=[{"type": "mcp", "server_url": MCP_URL, "token": MCP_TOKEN}]
    )

    result = ""
    for content in response.content:
        if hasattr(content, 'text'):
            result += content.text

    return result
```

## Step 3: Orchestrator pattern

```python
ORCHESTRATOR_PROMPT = """You are an Orchestrator Agent.

Your role is to coordinate specialized agents to complete complex tasks.

Available agents:
- researcher: Gathers and summarizes information
- analyst: Analyzes data and draws conclusions
- writer: Creates polished content
- reviewer: Checks quality and accuracy
- planner: Creates action plans
- coder: Writes code

When given a task:
1. Break it into subtasks
2. Assign each to the appropriate specialist
3. Coordinate information flow between agents
4. Aggregate final results

Use delegate_to_agent to assign tasks.
Use get_agent_result to retrieve results.
Use aggregate_results to combine outputs."""

def orchestrate(task: str) -> str:
    """Orchestrate multiple agents to complete a task."""

    response = client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=8192,
        system=ORCHESTRATOR_PROMPT,
        messages=[{
            "role": "user",
            "content": f"""Complete this task by coordinating the specialized agents:

{task}

Break it down, delegate to specialists, and provide the final result."""
        }],
        tools=[{"type": "mcp", "server_url": MCP_URL, "token": MCP_TOKEN}]
    )

    result = ""
    for content in response.content:
        if hasattr(content, 'text'):
            result += content.text

    return result

# Example usage
result = orchestrate("""
Write a comprehensive blog post about AI in healthcare.
Requirements:
- Research current applications
- Analyze trends and challenges
- Write engaging content
- Review for accuracy
""")
```

## Step 4: Pipeline pattern

```python
def run_pipeline(stages: list, initial_input: str) -> str:
    """Run agents in a sequential pipeline."""

    current_input = initial_input
    results = []

    for stage in stages:
        agent_name = stage["agent"]
        task_template = stage["task"]

        # Format task with current input
        task = task_template.format(input=current_input)

        # Run agent
        result = run_agent(agent_name, task, context=json.dumps(results[-3:] if results else []))

        results.append({
            "agent": agent_name,
            "input": current_input[:500],
            "output": result
        })

        # Pass output to next stage
        current_input = result

    return current_input

# Example: Content creation pipeline
content_pipeline = [
    {"agent": "researcher", "task": "Research this topic and provide key facts: {input}"},
    {"agent": "planner", "task": "Create an outline for content based on: {input}"},
    {"agent": "writer", "task": "Write the full content following this outline: {input}"},
    {"agent": "reviewer", "task": "Review and improve this content: {input}"}
]

result = run_pipeline(content_pipeline, "The future of renewable energy")
```

## Step 5: Swarm pattern

```python
import asyncio
from concurrent.futures import ThreadPoolExecutor

def run_swarm(task: str, agents: list, aggregation: str = "combine") -> str:
    """Run multiple agents in parallel and aggregate results."""

    with ThreadPoolExecutor(max_workers=len(agents)) as executor:
        futures = {
            executor.submit(run_agent, agent, task): agent
            for agent in agents
        }

        results = {}
        for future in futures:
            agent = futures[future]
            try:
                results[agent] = future.result()
            except Exception as e:
                results[agent] = f"Error: {e}"

    # Aggregate results
    if aggregation == "combine":
        return combine_results(results)
    elif aggregation == "vote":
        return vote_results(results)
    elif aggregation == "synthesize":
        return synthesize_results(results, task)

    return json.dumps(results, indent=2)

def combine_results(results: dict) -> str:
    """Simply combine all results."""
    output = []
    for agent, result in results.items():
        output.append(f"## {agent.title()}'s Analysis\n{result}\n")
    return "\n".join(output)

def vote_results(results: dict) -> str:
    """Have agents vote on a decision."""
    # Extract decisions and count votes
    decisions = {}
    for agent, result in results.items():
        # Simple extraction - in production, parse more carefully
        if "yes" in result.lower():
            decisions["yes"] = decisions.get("yes", 0) + 1
        elif "no" in result.lower():
            decisions["no"] = decisions.get("no", 0) + 1

    winner = max(decisions, key=decisions.get) if decisions else "undecided"
    return f"Decision: {winner} ({decisions.get(winner, 0)}/{len(results)} votes)"

def synthesize_results(results: dict, original_task: str) -> str:
    """Use an agent to synthesize multiple results."""

    synthesis_prompt = f"""Multiple agents analyzed this task: {original_task}

Their results:
{json.dumps(results, indent=2)}

Synthesize these perspectives into a coherent final answer.
Identify agreements, disagreements, and create a balanced conclusion."""

    return run_agent("analyst", synthesis_prompt)

# Example: Multiple perspectives on a question
result = run_swarm(
    "Should we migrate our monolith to microservices?",
    ["analyst", "planner", "reviewer"],
    aggregation="synthesize"
)
```

## Step 6: Debate pattern

```python
def run_debate(topic: str, rounds: int = 3) -> str:
    """Have agents debate a topic from different perspectives."""

    ADVOCATE_PROMPT = """You argue IN FAVOR of the proposition.
Make your best case. Be persuasive but honest.
Respond to opposing arguments directly."""

    CRITIC_PROMPT = """You argue AGAINST the proposition.
Identify weaknesses and problems. Be critical but fair.
Respond to supporting arguments directly."""

    JUDGE_PROMPT = """You are an impartial judge.
Evaluate both sides of the argument.
Declare a winner based on argument quality, not your opinion."""

    messages = []
    debate_history = []

    for round_num in range(rounds):
        # Advocate's turn
        advocate_context = "\n".join([
            f"Round {m['round']}: {m['speaker']}: {m['argument'][:200]}..."
            for m in debate_history
        ])

        advocate_response = client.messages.create(
            model="claude-sonnet-4-20250514",
            max_tokens=1024,
            system=ADVOCATE_PROMPT,
            messages=[{
                "role": "user",
                "content": f"""Topic: {topic}

Previous debate:
{advocate_context or 'This is the opening statement.'}

Make your argument (round {round_num + 1}/{rounds})."""
            }]
        )

        advocate_argument = ""
        for content in advocate_response.content:
            if hasattr(content, 'text'):
                advocate_argument = content.text

        debate_history.append({
            "round": round_num + 1,
            "speaker": "Advocate",
            "argument": advocate_argument
        })

        # Critic's turn
        critic_context = "\n".join([
            f"Round {m['round']}: {m['speaker']}: {m['argument'][:200]}..."
            for m in debate_history
        ])

        critic_response = client.messages.create(
            model="claude-sonnet-4-20250514",
            max_tokens=1024,
            system=CRITIC_PROMPT,
            messages=[{
                "role": "user",
                "content": f"""Topic: {topic}

Previous debate:
{critic_context}

Counter the advocate's arguments (round {round_num + 1}/{rounds})."""
            }]
        )

        critic_argument = ""
        for content in critic_response.content:
            if hasattr(content, 'text'):
                critic_argument = content.text

        debate_history.append({
            "round": round_num + 1,
            "speaker": "Critic",
            "argument": critic_argument
        })

    # Judge's verdict
    full_debate = "\n\n".join([
        f"**Round {m['round']} - {m['speaker']}:**\n{m['argument']}"
        for m in debate_history
    ])

    judge_response = client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=1024,
        system=JUDGE_PROMPT,
        messages=[{
            "role": "user",
            "content": f"""Topic: {topic}

Full debate:
{full_debate}

Provide your verdict. Who made the stronger argument and why?"""
        }]
    )

    verdict = ""
    for content in judge_response.content:
        if hasattr(content, 'text'):
            verdict = content.text

    return f"""# Debate: {topic}

{full_debate}

---

## Judge's Verdict

{verdict}
"""

# Example
result = run_debate("AI will create more jobs than it eliminates", rounds=3)
```

## Step 7: Hierarchical agents

```python
class AgentTeam:
    """A team of agents with a leader."""

    def __init__(self, name: str, leader_prompt: str, members: dict):
        self.name = name
        self.leader_prompt = leader_prompt
        self.members = members  # {role: prompt}

    def run(self, task: str) -> str:
        """Execute task with team coordination."""

        # Leader creates plan
        leader_response = client.messages.create(
            model="claude-sonnet-4-20250514",
            max_tokens=2048,
            system=f"""{self.leader_prompt}

Your team members: {', '.join(self.members.keys())}

Create a plan assigning tasks to team members.""",
            messages=[{
                "role": "user",
                "content": f"Complete this task with your team: {task}"
            }]
        )

        plan = ""
        for content in leader_response.content:
            if hasattr(content, 'text'):
                plan = content.text

        # Execute member tasks
        member_results = {}
        for role, prompt in self.members.items():
            member_task = f"As part of the team plan: {plan}\n\nYour role ({role}): Complete your assigned portion."

            result = run_agent(role, member_task)
            member_results[role] = result

        # Leader synthesizes
        synthesis_response = client.messages.create(
            model="claude-sonnet-4-20250514",
            max_tokens=4096,
            system=self.leader_prompt,
            messages=[{
                "role": "user",
                "content": f"""Original task: {task}

Team results:
{json.dumps(member_results, indent=2)}

Synthesize into final deliverable."""
            }]
        )

        final_result = ""
        for content in synthesis_response.content:
            if hasattr(content, 'text'):
                final_result = content.text

        return final_result

# Create teams for different purposes
research_team = AgentTeam(
    name="Research Team",
    leader_prompt="You lead a research team. Coordinate research efforts and synthesize findings.",
    members={
        "researcher": AGENT_PROMPTS["researcher"],
        "analyst": AGENT_PROMPTS["analyst"]
    }
)

content_team = AgentTeam(
    name="Content Team",
    leader_prompt="You lead a content creation team. Ensure high-quality output.",
    members={
        "writer": AGENT_PROMPTS["writer"],
        "reviewer": AGENT_PROMPTS["reviewer"]
    }
)

# Use teams
research_result = research_team.run("Analyze the competitive landscape for AI coding assistants")
```

## Summary

Multi-agent system patterns:

1. **Orchestrator** - Central coordinator delegates to specialists
2. **Pipeline** - Sequential processing through agents
3. **Swarm** - Parallel processing with aggregation
4. **Debate** - Adversarial reasoning for better conclusions
5. **Hierarchical** - Teams with leaders and members

Build tools with [Gantz](https://gantz.run), coordinate AI workers.

Multiple agents. One solution.

## Related reading

- [Event-Driven Agents](/post/event-driven-agents/) - Reactive systems
- [Agent Memory](/post/agent-memory/) - Persistent context
- [Agent Observability](/post/agent-observability/) - Debug multi-agent systems

---

*How do you coordinate AI agents? Share your patterns.*
