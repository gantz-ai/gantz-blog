+++
title = "AI Agent Hierarchy Patterns with MCP: Organizational Agent Structures"
image = "images/hierarchy-patterns.webp"
date = 2025-06-08
description = "Master AI agent hierarchy patterns with MCP and Gantz. Learn management layers, reporting structures, and organizational agent architectures."
summary = "Design multi-agent systems with organizational hierarchies featuring management layers, reporting chains, delegated authority, and cascading directives. This guide covers flat, divisional, and matrix hierarchy patterns with implementations for manager assignment, authority delegation with scope limits, issue escalation with severity analysis, status reporting that aggregates up the chain, and circular reference prevention."
draft = false
tags = ['hierarchy', 'patterns', 'ai', 'mcp', 'multi-agent', 'gantz']
voice = false

[howto]
name = "How To Implement AI Agent Hierarchy Patterns with MCP"
totalTime = 45
[[howto.steps]]
name = "Understand hierarchy concepts"
text = "Learn organizational agent fundamentals"
[[howto.steps]]
name = "Design hierarchy structure"
text = "Plan management layers"
[[howto.steps]]
name = "Implement reporting chains"
text = "Build supervision relationships"
[[howto.steps]]
name = "Add delegation authority"
text = "Create permission systems"
[[howto.steps]]
name = "Deploy with Gantz"
text = "Deploy hierarchical agents using Gantz CLI"
+++

AI agent hierarchy patterns create organizational structures with management layers, reporting chains, and delegated authority for complex multi-agent systems.

## Why Use Hierarchy Patterns?

Agent hierarchies enable:

- **Clear authority**: Defined decision-making chains
- **Scalable management**: Handle large agent pools
- **Accountability**: Track responsibility
- **Coordination**: Structured communication
- **Control**: Oversight at multiple levels

## Hierarchy Architecture

```yaml
# gantz.yaml
name: hierarchy-system
version: 1.0.0

tools:
  create_hierarchy:
    description: "Create agent hierarchy"
    parameters:
      name:
        type: string
        required: true
      structure:
        type: object
        required: true
    handler: hierarchy.create_hierarchy

  assign_manager:
    description: "Assign manager to agent"
    parameters:
      agent_id:
        type: string
        required: true
      manager_id:
        type: string
        required: true
    handler: hierarchy.assign_manager

  delegate_authority:
    description: "Delegate authority to agent"
    parameters:
      from_agent:
        type: string
        required: true
      to_agent:
        type: string
        required: true
      authority:
        type: object
    handler: hierarchy.delegate_authority

  escalate_to_manager:
    description: "Escalate issue to manager"
    parameters:
      agent_id:
        type: string
        required: true
      issue:
        type: object
        required: true
    handler: hierarchy.escalate_to_manager

  cascade_directive:
    description: "Cascade directive down hierarchy"
    parameters:
      directive:
        type: object
        required: true
      from_level:
        type: number
    handler: hierarchy.cascade_directive

  report_up:
    description: "Report status up hierarchy"
    parameters:
      agent_id:
        type: string
        required: true
      report:
        type: object
        required: true
    handler: hierarchy.report_up
```

## Handler Implementation

```python
# handlers/hierarchy.py
from datetime import datetime
from typing import List, Dict, Any

# Hierarchy state
HIERARCHIES = {}
AGENT_POSITIONS = {}
AUTHORITY_GRANTS = {}
REPORTS = {}


async def create_hierarchy(name: str, structure: dict) -> dict:
    """Create agent hierarchy."""
    from gantz import MCPClient
    mcp = MCPClient()

    hierarchy_id = generate_hierarchy_id()

    # AI structure validation
    validation = mcp.execute_tool('ai_validate', {
        'type': 'hierarchy_structure',
        'structure': structure,
        'validate': ['completeness', 'span_of_control', 'depth', 'balance']
    })

    hierarchy = {
        'id': hierarchy_id,
        'name': name,
        'structure': structure,
        'levels': calculate_levels(structure),
        'created_at': datetime.now().isoformat(),
        'status': 'active'
    }

    # Build position index
    index_positions(hierarchy_id, structure)

    HIERARCHIES[hierarchy_id] = hierarchy

    return {
        'hierarchy_id': hierarchy_id,
        'name': name,
        'levels': hierarchy['levels'],
        'total_positions': count_positions(structure),
        'validation': validation
    }


async def assign_manager(agent_id: str, manager_id: str) -> dict:
    """Assign manager to agent."""
    from gantz import MCPClient
    mcp = MCPClient()

    # Validate relationship
    if manager_id == agent_id:
        return {'error': 'Agent cannot be own manager'}

    # Check for circular reference
    if would_create_cycle(agent_id, manager_id):
        return {'error': 'Would create circular reporting'}

    # Get manager's level
    manager_position = AGENT_POSITIONS.get(manager_id, {})
    agent_position = AGENT_POSITIONS.get(agent_id, {})

    if manager_position.get('level', 0) >= agent_position.get('level', 0):
        return {'error': 'Manager must be at higher level'}

    # Create relationship
    AGENT_POSITIONS[agent_id] = {
        **agent_position,
        'manager': manager_id,
        'assigned_at': datetime.now().isoformat()
    }

    # Update manager's direct reports
    if 'direct_reports' not in AGENT_POSITIONS.get(manager_id, {}):
        AGENT_POSITIONS[manager_id]['direct_reports'] = []
    AGENT_POSITIONS[manager_id]['direct_reports'].append(agent_id)

    return {
        'agent_id': agent_id,
        'manager_id': manager_id,
        'relationship': 'reports_to',
        'established': True
    }


async def delegate_authority(from_agent: str, to_agent: str, authority: dict) -> dict:
    """Delegate authority to subordinate agent."""
    from gantz import MCPClient
    mcp = MCPClient()

    # Verify reporting relationship
    to_position = AGENT_POSITIONS.get(to_agent, {})
    if to_position.get('manager') != from_agent:
        # Check if in chain of command
        if not is_in_chain(to_agent, from_agent):
            return {'error': 'No authority to delegate'}

    # AI authority validation
    validation = mcp.execute_tool('ai_validate', {
        'type': 'authority_delegation',
        'delegator': from_agent,
        'delegate': to_agent,
        'authority': authority,
        'validate': ['scope', 'limits', 'conflicts']
    })

    grant = {
        'id': generate_grant_id(),
        'from_agent': from_agent,
        'to_agent': to_agent,
        'authority': authority,
        'scope': authority.get('scope', 'limited'),
        'expires_at': authority.get('expires'),
        'granted_at': datetime.now().isoformat(),
        'status': 'active'
    }

    key = f"{to_agent}_{from_agent}"
    AUTHORITY_GRANTS[key] = grant

    return {
        'grant_id': grant['id'],
        'delegated': True,
        'from': from_agent,
        'to': to_agent,
        'authority_scope': authority.get('scope'),
        'validation': validation
    }


async def escalate_to_manager(agent_id: str, issue: dict) -> dict:
    """Escalate issue to manager."""
    from gantz import MCPClient
    mcp = MCPClient()

    position = AGENT_POSITIONS.get(agent_id, {})
    manager_id = position.get('manager')

    if not manager_id:
        return {'error': 'No manager assigned'}

    # AI escalation analysis
    analysis = mcp.execute_tool('ai_analyze', {
        'type': 'escalation_analysis',
        'issue': issue,
        'agent': agent_id,
        'manager': manager_id,
        'analyze': ['severity', 'urgency', 'appropriate_level', 'context']
    })

    # Check if should escalate further
    if analysis.get('appropriate_level') > 1:
        # Escalate to manager's manager
        manager_position = AGENT_POSITIONS.get(manager_id, {})
        higher_manager = manager_position.get('manager')
        if higher_manager:
            manager_id = higher_manager

    escalation = {
        'id': generate_escalation_id(),
        'from_agent': agent_id,
        'to_manager': manager_id,
        'issue': issue,
        'severity': analysis.get('severity'),
        'urgency': analysis.get('urgency'),
        'escalated_at': datetime.now().isoformat(),
        'status': 'pending'
    }

    # Notify manager
    await notify_manager(manager_id, escalation)

    return {
        'escalation_id': escalation['id'],
        'escalated_to': manager_id,
        'severity': analysis.get('severity'),
        'urgency': analysis.get('urgency'),
        'expected_response': analysis.get('expected_response_time')
    }


async def cascade_directive(directive: dict, from_level: int = 0) -> dict:
    """Cascade directive down hierarchy."""
    from gantz import MCPClient
    mcp = MCPClient()

    # Find all agents at starting level
    starting_agents = get_agents_at_level(from_level)

    # Track cascade progress
    cascade_results = []

    async def cascade_to_reports(agent_id: str, directive: dict, level: int):
        """Recursively cascade to direct reports."""
        position = AGENT_POSITIONS.get(agent_id, {})
        direct_reports = position.get('direct_reports', [])

        # AI directive adaptation
        adapted = mcp.execute_tool('ai_adapt', {
            'type': 'directive_adaptation',
            'directive': directive,
            'target_level': level + 1,
            'adapt_for': 'subordinates'
        })

        for report_id in direct_reports:
            # Deliver directive
            delivery = await deliver_directive(report_id, adapted.get('adapted'))
            cascade_results.append({
                'agent_id': report_id,
                'level': level + 1,
                'delivered': True
            })

            # Continue cascade
            await cascade_to_reports(report_id, adapted.get('adapted'), level + 1)

    # Start cascade from each starting agent
    for agent_id in starting_agents:
        await cascade_to_reports(agent_id, directive, from_level)

    return {
        'directive_id': directive.get('id'),
        'started_from_level': from_level,
        'agents_reached': len(cascade_results),
        'cascade_results': cascade_results
    }


async def report_up(agent_id: str, report: dict) -> dict:
    """Report status up hierarchy."""
    from gantz import MCPClient
    mcp = MCPClient()

    position = AGENT_POSITIONS.get(agent_id, {})
    manager_id = position.get('manager')

    if not manager_id:
        return {'error': 'No manager to report to'}

    # AI report formatting
    formatted = mcp.execute_tool('ai_format', {
        'type': 'status_report',
        'report': report,
        'format_for': 'manager',
        'include': ['summary', 'metrics', 'issues', 'next_steps']
    })

    report_record = {
        'id': generate_report_id(),
        'from_agent': agent_id,
        'to_manager': manager_id,
        'content': formatted.get('formatted'),
        'summary': formatted.get('summary'),
        'submitted_at': datetime.now().isoformat()
    }

    REPORTS[report_record['id']] = report_record

    # Check if should aggregate up further
    manager_position = AGENT_POSITIONS.get(manager_id, {})
    if manager_position.get('manager'):
        # Collect all reports from this manager's reports
        peer_reports = get_peer_reports(manager_id)

        if len(peer_reports) >= len(manager_position.get('direct_reports', [])):
            # All reports received, aggregate and report up
            aggregated = await aggregate_reports(peer_reports)
            await report_up(manager_id, aggregated)

    return {
        'report_id': report_record['id'],
        'reported_to': manager_id,
        'summary': formatted.get('summary'),
        'acknowledged': True
    }


def calculate_levels(structure: dict, current: int = 0) -> int:
    """Calculate hierarchy depth."""
    if not structure.get('subordinates'):
        return current

    max_depth = current
    for sub in structure.get('subordinates', []):
        depth = calculate_levels(sub, current + 1)
        max_depth = max(max_depth, depth)

    return max_depth


def is_in_chain(agent_id: str, potential_superior: str) -> bool:
    """Check if agent is in chain of command."""
    current = agent_id
    while current:
        position = AGENT_POSITIONS.get(current, {})
        if position.get('manager') == potential_superior:
            return True
        current = position.get('manager')
    return False


def would_create_cycle(agent_id: str, manager_id: str) -> bool:
    """Check if assignment would create circular reference."""
    current = manager_id
    while current:
        if current == agent_id:
            return True
        position = AGENT_POSITIONS.get(current, {})
        current = position.get('manager')
    return False
```

## Hierarchy Types

```python
# hierarchies/types.py
from gantz import MCPClient

mcp = MCPClient(config_path='gantz.yaml')


class FlatHierarchy:
    """Flat organizational hierarchy."""

    def __init__(self, coordinator: str, members: list):
        self.coordinator = coordinator
        self.members = members

    async def create(self) -> dict:
        structure = {
            'role': 'coordinator',
            'agent': self.coordinator,
            'subordinates': [
                {'role': 'member', 'agent': m}
                for m in self.members
            ]
        }

        return await mcp.execute_tool('create_hierarchy', {
            'name': 'flat_org',
            'structure': structure
        })


class DivisionalHierarchy:
    """Divisional organizational hierarchy."""

    def __init__(self, ceo: str, divisions: dict):
        self.ceo = ceo
        self.divisions = divisions

    async def create(self) -> dict:
        structure = {
            'role': 'ceo',
            'agent': self.ceo,
            'subordinates': [
                {
                    'role': f'{name}_head',
                    'agent': div['head'],
                    'subordinates': [
                        {'role': 'member', 'agent': m}
                        for m in div.get('members', [])
                    ]
                }
                for name, div in self.divisions.items()
            ]
        }

        return await mcp.execute_tool('create_hierarchy', {
            'name': 'divisional_org',
            'structure': structure
        })


class MatrixHierarchy:
    """Matrix organizational hierarchy."""

    def __init__(self, executives: list, projects: list, members: list):
        self.executives = executives
        self.projects = projects
        self.members = members
        self.assignments = {}

    async def assign_to_project(self, member: str, project: str, functional_head: str):
        """Assign member to project with dual reporting."""
        self.assignments[member] = {
            'project': project,
            'functional_head': functional_head
        }

        # Create dual reporting relationship
        await mcp.execute_tool('assign_manager', {
            'agent_id': member,
            'manager_id': functional_head
        })

        # Project authority delegation
        project_lead = self.get_project_lead(project)
        await mcp.execute_tool('delegate_authority', {
            'from_agent': functional_head,
            'to_agent': project_lead,
            'authority': {
                'scope': 'project',
                'project': project,
                'over_agent': member
            }
        })
```

## Deploy with Gantz CLI

```bash
# Install Gantz
npm install -g gantz

# Initialize hierarchy system
gantz init --template hierarchy-system

# Deploy
gantz deploy --platform kubernetes

# Create hierarchy
gantz run create_hierarchy --name "engineering" --structure '{"role": "vp", "subordinates": [...]}'

# Assign manager
gantz run assign_manager --agent-id dev1 --manager-id tech_lead

# Delegate authority
gantz run delegate_authority --from-agent tech_lead --to-agent dev1 --authority '{"scope": "code_review"}'

# Escalate issue
gantz run escalate_to_manager --agent-id dev1 --issue '{"type": "blocker", "description": "..."}'
```

Build organizational agent structures at [gantz.run](https://gantz.run).

## Related Reading

- [Delegation Patterns](/post/delegation-patterns/) - Task delegation
- [Orchestration Patterns](/post/orchestration-patterns/) - Coordination
- [Specialization Patterns](/post/specialization-patterns/) - Expert agents

## Conclusion

Hierarchy patterns enable structured multi-agent organizations. With clear reporting chains, delegated authority, and cascading communication, you can manage large agent pools effectively.

Start building hierarchical agent systems with Gantz today.
