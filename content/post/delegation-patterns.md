+++
title = "AI Agent Delegation Patterns with MCP: Intelligent Task Assignment"
image = "images/delegation-patterns.webp"
date = 2025-06-13
description = "Master AI agent delegation patterns with MCP and Gantz. Learn task routing, capability matching, and intelligent work distribution."
summary = "Implement intelligent task delegation between AI agents. Build capability registries, task routing logic, and load balancing for efficient work distribution."
draft = false
tags = ['delegation', 'patterns', 'ai', 'mcp', 'multi-agent', 'gantz']
voice = false

[howto]
name = "How To Implement AI Agent Delegation Patterns with MCP"
totalTime = 40
[[howto.steps]]
name = "Understand delegation concepts"
text = "Learn task delegation fundamentals"
[[howto.steps]]
name = "Design capability registry"
text = "Map agent capabilities"
[[howto.steps]]
name = "Implement delegation logic"
text = "Build intelligent task routing"
[[howto.steps]]
name = "Add load balancing"
text = "Create fair work distribution"
[[howto.steps]]
name = "Deploy with Gantz"
text = "Deploy delegation system using Gantz CLI"
+++

AI agent delegation patterns enable intelligent task assignment based on agent capabilities, availability, and workload, ensuring optimal resource utilization.

## Why Use Delegation Patterns?

Agent delegation enables:

- **Capability matching**: Right agent for right task
- **Load balancing**: Even work distribution
- **Specialization**: Leverage agent expertise
- **Scalability**: Dynamic agent allocation
- **Efficiency**: Minimize task completion time

## Delegation Architecture

```yaml
# gantz.yaml
name: delegation-system
version: 1.0.0

tools:
  delegate_task:
    description: "Delegate task to best agent"
    parameters:
      task:
        type: object
        required: true
      constraints:
        type: object
    handler: delegation.delegate_task

  register_capability:
    description: "Register agent capability"
    parameters:
      agent_id:
        type: string
        required: true
      capabilities:
        type: array
        required: true
    handler: delegation.register_capability

  find_best_agent:
    description: "Find best agent for task"
    parameters:
      task_requirements:
        type: object
        required: true
    handler: delegation.find_best_agent

  balance_load:
    description: "Balance workload across agents"
    handler: delegation.balance_load

  escalate_task:
    description: "Escalate task to supervisor"
    parameters:
      task_id:
        type: string
        required: true
      reason:
        type: string
    handler: delegation.escalate_task

  delegation_analytics:
    description: "Analyze delegation patterns"
    parameters:
      timeframe:
        type: string
        default: "7d"
    handler: delegation.delegation_analytics
```

## Handler Implementation

```python
# handlers/delegation.py
from datetime import datetime
from typing import List, Dict, Any

# Capability registry
CAPABILITY_REGISTRY = {}
AGENT_WORKLOAD = {}
DELEGATION_HISTORY = []


async def delegate_task(task: dict, constraints: dict = None) -> dict:
    """Delegate task to best available agent."""
    from gantz import MCPClient
    mcp = MCPClient()

    # AI task analysis
    analysis = mcp.execute_tool('ai_analyze', {
        'type': 'task_requirements',
        'task': task,
        'analyze': ['skills_needed', 'complexity', 'urgency', 'estimated_time']
    })

    requirements = {
        'skills': analysis.get('skills_needed', []),
        'complexity': analysis.get('complexity'),
        'urgency': analysis.get('urgency'),
        'estimated_time': analysis.get('estimated_time')
    }

    # Find best agent
    best_agent = await find_best_agent(requirements)

    if not best_agent:
        # Queue or escalate
        if constraints and constraints.get('allow_queue'):
            return await queue_task(task, requirements)
        else:
            return await escalate_task(task.get('id'), 'no_available_agent')

    # Assign task
    assignment = {
        'task_id': task.get('id', generate_task_id()),
        'agent_id': best_agent['agent_id'],
        'task': task,
        'assigned_at': datetime.now().isoformat(),
        'requirements': requirements
    }

    # Update workload
    AGENT_WORKLOAD[best_agent['agent_id']] = \
        AGENT_WORKLOAD.get(best_agent['agent_id'], 0) + 1

    # Record delegation
    DELEGATION_HISTORY.append(assignment)

    return {
        'delegated': True,
        'agent_id': best_agent['agent_id'],
        'agent_name': best_agent.get('name'),
        'match_score': best_agent.get('match_score'),
        'estimated_completion': analysis.get('estimated_time'),
        'task_id': assignment['task_id']
    }


async def register_capability(agent_id: str, capabilities: list) -> dict:
    """Register agent capabilities."""
    from gantz import MCPClient
    mcp = MCPClient()

    # Validate and normalize capabilities
    normalized = mcp.execute_tool('ai_process', {
        'type': 'capability_normalization',
        'capabilities': capabilities,
        'process': ['validate', 'categorize', 'score']
    })

    CAPABILITY_REGISTRY[agent_id] = {
        'agent_id': agent_id,
        'capabilities': normalized.get('capabilities', []),
        'categories': normalized.get('categories', []),
        'proficiency_scores': normalized.get('scores', {}),
        'registered_at': datetime.now().isoformat()
    }

    return {
        'agent_id': agent_id,
        'registered': True,
        'capabilities_count': len(capabilities),
        'categories': normalized.get('categories', [])
    }


async def find_best_agent(task_requirements: dict) -> dict:
    """Find best agent for task requirements."""
    from gantz import MCPClient
    mcp = MCPClient()

    candidates = []

    for agent_id, registration in CAPABILITY_REGISTRY.items():
        # Check capability match
        match = calculate_capability_match(
            registration['capabilities'],
            task_requirements.get('skills', [])
        )

        if match['score'] > 0.5:  # Minimum threshold
            # Check availability
            workload = AGENT_WORKLOAD.get(agent_id, 0)
            max_workload = registration.get('max_concurrent', 5)

            if workload < max_workload:
                candidates.append({
                    'agent_id': agent_id,
                    'name': registration.get('name'),
                    'match_score': match['score'],
                    'matched_skills': match['matched'],
                    'current_workload': workload,
                    'proficiency': registration.get('proficiency_scores', {})
                })

    if not candidates:
        return None

    # AI ranking
    ranking = mcp.execute_tool('ai_rank', {
        'type': 'agent_selection',
        'candidates': candidates,
        'task_requirements': task_requirements,
        'rank_by': ['match_score', 'proficiency', 'workload', 'history']
    })

    return ranking.get('best_agent')


async def balance_load() -> dict:
    """Balance workload across agents."""
    from gantz import MCPClient
    mcp = MCPClient()

    # Get current distribution
    distribution = []
    for agent_id, workload in AGENT_WORKLOAD.items():
        registration = CAPABILITY_REGISTRY.get(agent_id, {})
        distribution.append({
            'agent_id': agent_id,
            'current_workload': workload,
            'max_workload': registration.get('max_concurrent', 5),
            'utilization': workload / registration.get('max_concurrent', 5)
        })

    # AI load analysis
    analysis = mcp.execute_tool('ai_analyze', {
        'type': 'load_balancing',
        'distribution': distribution,
        'analyze': ['imbalance', 'reallocation', 'recommendations']
    })

    # Execute reallocation if needed
    reallocations = []
    for realloc in analysis.get('reallocations', []):
        result = await reallocate_task(
            realloc['task_id'],
            realloc['from_agent'],
            realloc['to_agent']
        )
        reallocations.append(result)

    return {
        'balanced': True,
        'reallocations': len(reallocations),
        'current_distribution': distribution,
        'imbalance_score': analysis.get('imbalance_score'),
        'recommendations': analysis.get('recommendations', [])
    }


async def escalate_task(task_id: str, reason: str) -> dict:
    """Escalate task to supervisor agent."""
    from gantz import MCPClient
    mcp = MCPClient()

    # Find task
    task = find_task_by_id(task_id)

    # Determine escalation path
    escalation = mcp.execute_tool('ai_classify', {
        'type': 'escalation_path',
        'task': task,
        'reason': reason,
        'options': ['supervisor', 'specialist', 'human', 'queue']
    })

    escalation_target = escalation.get('recommended')

    if escalation_target == 'supervisor':
        # Assign to supervisor agent
        supervisor = get_supervisor_agent()
        result = await delegate_task(task, {'agent_id': supervisor})

    elif escalation_target == 'specialist':
        # Find specialist
        specialist = await find_specialist(task)
        result = await delegate_task(task, {'agent_id': specialist})

    elif escalation_target == 'human':
        # Create human review ticket
        result = await create_human_review(task, reason)

    else:
        # Queue for later
        result = await queue_task(task, {})

    return {
        'task_id': task_id,
        'escalated': True,
        'escalation_type': escalation_target,
        'reason': reason,
        'result': result
    }


async def delegation_analytics(timeframe: str = "7d") -> dict:
    """Analyze delegation patterns."""
    from gantz import MCPClient
    mcp = MCPClient()

    # Filter history by timeframe
    days = int(timeframe.replace('d', ''))
    recent = filter_by_timeframe(DELEGATION_HISTORY, days)

    # AI analytics
    analytics = mcp.execute_tool('ai_analyze', {
        'type': 'delegation_analytics',
        'delegations': recent,
        'analyze': [
            'success_rate',
            'agent_performance',
            'bottlenecks',
            'patterns',
            'optimization_opportunities'
        ]
    })

    return {
        'timeframe': timeframe,
        'total_delegations': len(recent),
        'success_rate': analytics.get('success_rate'),
        'average_completion_time': analytics.get('avg_completion'),
        'top_performers': analytics.get('top_agents', []),
        'bottlenecks': analytics.get('bottlenecks', []),
        'patterns': analytics.get('patterns', []),
        'recommendations': analytics.get('recommendations', [])
    }


def calculate_capability_match(agent_caps: list, required: list) -> dict:
    """Calculate capability match score."""
    if not required:
        return {'score': 1.0, 'matched': []}

    matched = [cap for cap in required if cap in agent_caps]
    score = len(matched) / len(required)

    return {
        'score': score,
        'matched': matched,
        'missing': [cap for cap in required if cap not in agent_caps]
    }
```

## Delegation Strategies

```python
# strategies/delegation.py
from gantz import MCPClient

mcp = MCPClient(config_path='gantz.yaml')


class RoundRobinDelegator:
    """Round-robin delegation strategy."""

    def __init__(self, agents: list):
        self.agents = agents
        self.current_index = 0

    async def delegate(self, task: dict) -> dict:
        """Delegate using round-robin."""
        agent = self.agents[self.current_index]
        self.current_index = (self.current_index + 1) % len(self.agents)

        return await mcp.execute_tool('delegate_task', {
            'task': task,
            'constraints': {'agent_id': agent}
        })


class CapabilityBasedDelegator:
    """Capability-based delegation strategy."""

    async def delegate(self, task: dict) -> dict:
        """Delegate based on capability match."""
        # Find best match
        best_agent = await mcp.execute_tool('find_best_agent', {
            'task_requirements': task.get('requirements', {})
        })

        return await mcp.execute_tool('delegate_task', {
            'task': task,
            'constraints': {'agent_id': best_agent.get('agent_id')}
        })


class LeastLoadedDelegator:
    """Least-loaded delegation strategy."""

    async def delegate(self, task: dict) -> dict:
        """Delegate to least loaded agent."""
        # Get workloads
        monitor = await mcp.execute_tool('monitor_agents', {})

        # Find least loaded
        available = [
            a for a in monitor.get('agents', [])
            if a['status'] == 'available'
        ]

        if not available:
            return {'error': 'No available agents'}

        least_loaded = min(available, key=lambda a: a.get('current_workload', 0))

        return await mcp.execute_tool('delegate_task', {
            'task': task,
            'constraints': {'agent_id': least_loaded['agent_id']}
        })


class PriorityDelegator:
    """Priority-based delegation strategy."""

    def __init__(self, priority_agents: dict):
        # Map priority levels to agent pools
        self.priority_agents = priority_agents

    async def delegate(self, task: dict) -> dict:
        """Delegate based on task priority."""
        priority = task.get('priority', 'normal')
        agent_pool = self.priority_agents.get(priority, self.priority_agents['normal'])

        # Find available in pool
        for agent in agent_pool:
            status = await get_agent_status(agent)
            if status == 'available':
                return await mcp.execute_tool('delegate_task', {
                    'task': task,
                    'constraints': {'agent_id': agent}
                })

        # Escalate if high priority and no agents
        if priority == 'high':
            return await mcp.execute_tool('escalate_task', {
                'task_id': task.get('id'),
                'reason': 'high_priority_no_agents'
            })
```

## Deploy with Gantz CLI

```bash
# Install Gantz
npm install -g gantz

# Initialize delegation system
gantz init --template delegation-system

# Deploy
gantz deploy --platform kubernetes

# Register agent capabilities
gantz run register_capability --agent-id agent1 --capabilities '["nlp", "classification"]'

# Delegate a task
gantz run delegate_task --task '{"type": "classify", "data": {...}}'

# Balance load
gantz run balance_load

# View analytics
gantz run delegation_analytics --timeframe 7d
```

Build intelligent task delegation at [gantz.run](https://gantz.run).

## Related Reading

- [Orchestration Patterns](/post/orchestration-patterns/) - Multi-agent coordination
- [Specialization Patterns](/post/specialization-patterns/) - Agent expertise
- [Hierarchy Patterns](/post/hierarchy-patterns/) - Agent hierarchies

## Conclusion

Delegation patterns enable efficient task distribution across agent pools. With capability matching, load balancing, and intelligent routing, you can maximize resource utilization and task completion rates.

Start building intelligent delegation systems with Gantz today.
