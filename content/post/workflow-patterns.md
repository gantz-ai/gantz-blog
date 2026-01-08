+++
title = "AI Agent Workflow Patterns with MCP: Complex Process Automation"
image = "images/workflow-patterns.webp"
date = 2025-06-05
description = "Master AI agent workflow patterns with MCP and Gantz. Learn process orchestration, state machines, and complex business workflow automation."
summary = "Real business processes aren't linear - they branch, loop back, wait for approvals, and handle exceptions. This guide covers workflow patterns that model these complexities: state machines that track where you are, conditional transitions that pick the right path, parallel execution for independent steps, and human-in-the-loop gates for decisions that need oversight. Build workflows that match how your business actually operates."
draft = false
tags = ['workflow', 'patterns', 'ai', 'mcp', 'automation', 'gantz']
voice = false

[howto]
name = "How To Implement AI Agent Workflow Patterns with MCP"
totalTime = 45
[[howto.steps]]
name = "Understand workflow concepts"
text = "Learn process automation fundamentals"
[[howto.steps]]
name = "Design workflow states"
text = "Define workflow state machines"
[[howto.steps]]
name = "Implement transitions"
text = "Build state transition logic"
[[howto.steps]]
name = "Add human-in-the-loop"
text = "Create approval workflows"
[[howto.steps]]
name = "Deploy with Gantz"
text = "Deploy workflow agents using Gantz CLI"
+++

AI agent workflow patterns enable complex business process automation through state machines, conditional branching, and human-in-the-loop approvals.

## Why Use Workflow Patterns?

Agent workflows enable:

- **Process automation**: Automate complex business processes
- **State management**: Track workflow progress
- **Conditional logic**: Dynamic path selection
- **Human integration**: Approval and review steps
- **Auditability**: Complete process history

## Workflow Architecture

```yaml
# gantz.yaml
name: workflow-system
version: 1.0.0

tools:
  create_workflow:
    description: "Create workflow definition"
    parameters:
      name:
        type: string
        required: true
      states:
        type: array
        required: true
      transitions:
        type: array
        required: true
    handler: workflow.create_workflow

  start_workflow:
    description: "Start workflow instance"
    parameters:
      workflow_id:
        type: string
        required: true
      input:
        type: object
    handler: workflow.start_workflow

  transition_workflow:
    description: "Transition workflow state"
    parameters:
      instance_id:
        type: string
        required: true
      action:
        type: string
        required: true
    handler: workflow.transition_workflow

  request_approval:
    description: "Request human approval"
    parameters:
      instance_id:
        type: string
        required: true
      approvers:
        type: array
        required: true
    handler: workflow.request_approval

  handle_timeout:
    description: "Handle workflow timeout"
    parameters:
      instance_id:
        type: string
        required: true
    handler: workflow.handle_timeout

  workflow_analytics:
    description: "Analyze workflow performance"
    parameters:
      workflow_id:
        type: string
        required: true
    handler: workflow.workflow_analytics
```

## Handler Implementation

```python
# handlers/workflow.py
import asyncio
from datetime import datetime, timedelta
from typing import List, Dict, Any

# Workflow state
WORKFLOWS = {}
INSTANCES = {}
APPROVALS = {}
TIMERS = {}


async def create_workflow(name: str, states: list, transitions: list) -> dict:
    """Create workflow definition."""
    from gantz import MCPClient
    mcp = MCPClient()

    workflow_id = generate_workflow_id()

    # Validate workflow structure
    validation = mcp.execute_tool('ai_validate', {
        'type': 'workflow_definition',
        'states': states,
        'transitions': transitions,
        'validate': ['reachability', 'completeness', 'deadlocks', 'cycles']
    })

    # Build state machine
    state_map = {}
    for state in states:
        state_map[state['name']] = {
            'type': state.get('type', 'normal'),  # start, normal, end, approval
            'on_enter': state.get('on_enter'),
            'on_exit': state.get('on_exit'),
            'timeout': state.get('timeout'),
            'handlers': state.get('handlers', [])
        }

    # Build transition map
    transition_map = {}
    for trans in transitions:
        from_state = trans['from']
        if from_state not in transition_map:
            transition_map[from_state] = []
        transition_map[from_state].append({
            'to': trans['to'],
            'action': trans['action'],
            'condition': trans.get('condition'),
            'guards': trans.get('guards', [])
        })

    workflow = {
        'id': workflow_id,
        'name': name,
        'states': state_map,
        'transitions': transition_map,
        'start_state': next((s['name'] for s in states if s.get('type') == 'start'), states[0]['name']),
        'end_states': [s['name'] for s in states if s.get('type') == 'end'],
        'created_at': datetime.now().isoformat(),
        'version': 1
    }

    WORKFLOWS[workflow_id] = workflow

    return {
        'workflow_id': workflow_id,
        'name': name,
        'states_count': len(states),
        'transitions_count': len(transitions),
        'validation': validation
    }


async def start_workflow(workflow_id: str, input: dict = None) -> dict:
    """Start workflow instance."""
    from gantz import MCPClient
    mcp = MCPClient()

    workflow = WORKFLOWS.get(workflow_id)
    if not workflow:
        return {'error': 'Workflow not found'}

    instance_id = generate_instance_id()

    instance = {
        'id': instance_id,
        'workflow_id': workflow_id,
        'current_state': workflow['start_state'],
        'input': input or {},
        'context': {},
        'history': [],
        'started_at': datetime.now().isoformat(),
        'status': 'active'
    }

    # Record state entry
    instance['history'].append({
        'state': workflow['start_state'],
        'action': 'start',
        'timestamp': datetime.now().isoformat()
    })

    INSTANCES[instance_id] = instance

    # Execute on_enter for start state
    start_state = workflow['states'][workflow['start_state']]
    if start_state.get('on_enter'):
        await execute_handler(start_state['on_enter'], instance)

    # Set up timeout if configured
    if start_state.get('timeout'):
        schedule_timeout(instance_id, start_state['timeout'])

    # Check for auto-transitions
    await check_auto_transitions(instance_id)

    return {
        'instance_id': instance_id,
        'workflow_id': workflow_id,
        'current_state': instance['current_state'],
        'status': 'active',
        'started_at': instance['started_at']
    }


async def transition_workflow(instance_id: str, action: str) -> dict:
    """Transition workflow to new state."""
    from gantz import MCPClient
    mcp = MCPClient()

    instance = INSTANCES.get(instance_id)
    if not instance:
        return {'error': 'Instance not found'}

    workflow = WORKFLOWS.get(instance['workflow_id'])
    current_state = instance['current_state']

    # Find matching transition
    transitions = workflow['transitions'].get(current_state, [])
    matching = None

    for trans in transitions:
        if trans['action'] == action:
            # Check guards
            guards_pass = True
            for guard in trans.get('guards', []):
                if not await evaluate_guard(guard, instance):
                    guards_pass = False
                    break

            if guards_pass:
                matching = trans
                break

    if not matching:
        return {
            'error': 'No valid transition',
            'current_state': current_state,
            'action': action
        }

    # Execute on_exit for current state
    current_state_def = workflow['states'][current_state]
    if current_state_def.get('on_exit'):
        await execute_handler(current_state_def['on_exit'], instance)

    # Transition
    new_state = matching['to']
    instance['current_state'] = new_state

    # Record transition
    instance['history'].append({
        'from_state': current_state,
        'to_state': new_state,
        'action': action,
        'timestamp': datetime.now().isoformat()
    })

    # Execute on_enter for new state
    new_state_def = workflow['states'][new_state]
    if new_state_def.get('on_enter'):
        await execute_handler(new_state_def['on_enter'], instance)

    # Check if end state
    if new_state in workflow['end_states']:
        instance['status'] = 'completed'
        instance['completed_at'] = datetime.now().isoformat()

    # Set up timeout for new state
    if new_state_def.get('timeout'):
        schedule_timeout(instance_id, new_state_def['timeout'])

    return {
        'instance_id': instance_id,
        'previous_state': current_state,
        'current_state': new_state,
        'action': action,
        'status': instance['status']
    }


async def request_approval(instance_id: str, approvers: list) -> dict:
    """Request human approval for workflow."""
    from gantz import MCPClient
    mcp = MCPClient()

    instance = INSTANCES.get(instance_id)
    if not instance:
        return {'error': 'Instance not found'}

    approval_id = generate_approval_id()

    approval = {
        'id': approval_id,
        'instance_id': instance_id,
        'approvers': approvers,
        'status': 'pending',
        'requested_at': datetime.now().isoformat(),
        'responses': {}
    }

    APPROVALS[approval_id] = approval

    # AI approval content generation
    content = mcp.execute_tool('ai_generate', {
        'type': 'approval_request',
        'instance': instance,
        'generate': ['summary', 'context', 'recommendation']
    })

    # Notify approvers
    for approver in approvers:
        await notify_approver(approver, {
            'approval_id': approval_id,
            'instance_id': instance_id,
            'summary': content.get('summary'),
            'context': content.get('context'),
            'recommendation': content.get('recommendation')
        })

    return {
        'approval_id': approval_id,
        'instance_id': instance_id,
        'approvers': approvers,
        'status': 'pending'
    }


async def handle_approval_response(approval_id: str, approver: str, decision: str, comment: str = None) -> dict:
    """Handle approval response."""
    approval = APPROVALS.get(approval_id)
    if not approval:
        return {'error': 'Approval not found'}

    approval['responses'][approver] = {
        'decision': decision,
        'comment': comment,
        'timestamp': datetime.now().isoformat()
    }

    # Check if all responses received
    if len(approval['responses']) == len(approval['approvers']):
        # Determine final decision
        approvals = sum(1 for r in approval['responses'].values() if r['decision'] == 'approve')
        rejections = sum(1 for r in approval['responses'].values() if r['decision'] == 'reject')

        if approvals > rejections:
            approval['status'] = 'approved'
            action = 'approve'
        else:
            approval['status'] = 'rejected'
            action = 'reject'

        # Transition workflow
        await transition_workflow(approval['instance_id'], action)

    return {
        'approval_id': approval_id,
        'approver': approver,
        'decision': decision,
        'approval_status': approval['status']
    }


async def handle_timeout(instance_id: str) -> dict:
    """Handle workflow timeout."""
    from gantz import MCPClient
    mcp = MCPClient()

    instance = INSTANCES.get(instance_id)
    if not instance:
        return {'error': 'Instance not found'}

    workflow = WORKFLOWS.get(instance['workflow_id'])
    current_state = instance['current_state']
    state_def = workflow['states'][current_state]

    # AI timeout decision
    decision = mcp.execute_tool('ai_decide', {
        'type': 'timeout_handling',
        'instance': instance,
        'state': current_state,
        'decide': ['action', 'escalation', 'retry']
    })

    if decision.get('action') == 'escalate':
        await escalate_workflow(instance_id, 'timeout')
    elif decision.get('action') == 'retry':
        await transition_workflow(instance_id, 'retry')
    else:
        await transition_workflow(instance_id, 'timeout')

    return {
        'instance_id': instance_id,
        'timeout_handled': True,
        'action_taken': decision.get('action')
    }


async def workflow_analytics(workflow_id: str) -> dict:
    """Analyze workflow performance."""
    from gantz import MCPClient
    mcp = MCPClient()

    workflow = WORKFLOWS.get(workflow_id)
    if not workflow:
        return {'error': 'Workflow not found'}

    # Get all instances
    instances = [
        i for i in INSTANCES.values()
        if i['workflow_id'] == workflow_id
    ]

    # Calculate metrics
    completed = [i for i in instances if i['status'] == 'completed']
    active = [i for i in instances if i['status'] == 'active']

    # Duration analysis
    durations = []
    for instance in completed:
        start = datetime.fromisoformat(instance['started_at'])
        end = datetime.fromisoformat(instance['completed_at'])
        durations.append((end - start).total_seconds())

    # State time analysis
    state_times = {}
    for instance in instances:
        for i, event in enumerate(instance['history'][:-1]):
            state = event['state']
            next_event = instance['history'][i + 1]
            duration = (
                datetime.fromisoformat(next_event['timestamp']) -
                datetime.fromisoformat(event['timestamp'])
            ).total_seconds()

            if state not in state_times:
                state_times[state] = []
            state_times[state].append(duration)

    # AI analysis
    analysis = mcp.execute_tool('ai_analyze', {
        'type': 'workflow_analytics',
        'workflow': workflow,
        'instances': instances,
        'analyze': ['bottlenecks', 'optimization', 'patterns', 'predictions']
    })

    return {
        'workflow_id': workflow_id,
        'total_instances': len(instances),
        'completed': len(completed),
        'active': len(active),
        'completion_rate': len(completed) / len(instances) * 100 if instances else 0,
        'avg_duration_seconds': sum(durations) / len(durations) if durations else 0,
        'state_avg_times': {s: sum(t) / len(t) for s, t in state_times.items()},
        'bottlenecks': analysis.get('bottlenecks', []),
        'optimization_suggestions': analysis.get('optimization', []),
        'patterns': analysis.get('patterns', [])
    }


async def execute_handler(handler: dict, instance: dict):
    """Execute state handler."""
    from gantz import MCPClient
    mcp = MCPClient()

    handler_type = handler.get('type')

    if handler_type == 'ai':
        result = mcp.execute_tool('ai_execute', {
            'action': handler.get('action'),
            'context': instance['context'],
            'input': instance['input']
        })
        instance['context'].update(result)

    elif handler_type == 'tool':
        result = mcp.execute_tool(handler.get('tool'), handler.get('params', {}))
        instance['context'][handler.get('output_key', 'result')] = result

    elif handler_type == 'webhook':
        await call_webhook(handler.get('url'), instance)


async def evaluate_guard(guard: dict, instance: dict) -> bool:
    """Evaluate transition guard condition."""
    guard_type = guard.get('type')

    if guard_type == 'condition':
        return eval(guard['expression'], {'context': instance['context']})

    elif guard_type == 'ai':
        from gantz import MCPClient
        mcp = MCPClient()
        result = mcp.execute_tool('ai_evaluate', {
            'condition': guard['condition'],
            'context': instance['context']
        })
        return result.get('passes', False)

    return True
```

## Workflow Templates

```python
# templates/workflows.py
from gantz import MCPClient

mcp = MCPClient(config_path='gantz.yaml')


class ApprovalWorkflow:
    """Standard approval workflow template."""

    async def create(self, name: str, approval_levels: int = 1) -> dict:
        states = [
            {'name': 'submitted', 'type': 'start'},
            *[{'name': f'approval_level_{i+1}', 'type': 'approval'}
              for i in range(approval_levels)],
            {'name': 'approved', 'type': 'end'},
            {'name': 'rejected', 'type': 'end'}
        ]

        transitions = [
            {'from': 'submitted', 'to': 'approval_level_1', 'action': 'submit'}
        ]

        for i in range(approval_levels):
            level = f'approval_level_{i+1}'
            next_level = f'approval_level_{i+2}' if i < approval_levels - 1 else 'approved'

            transitions.extend([
                {'from': level, 'to': next_level, 'action': 'approve'},
                {'from': level, 'to': 'rejected', 'action': 'reject'}
            ])

        return await mcp.execute_tool('create_workflow', {
            'name': name,
            'states': states,
            'transitions': transitions
        })


class OrderWorkflow:
    """E-commerce order workflow template."""

    async def create(self) -> dict:
        states = [
            {'name': 'pending', 'type': 'start', 'timeout': 3600},
            {'name': 'payment_processing', 'timeout': 300},
            {'name': 'paid'},
            {'name': 'fulfilling'},
            {'name': 'shipped'},
            {'name': 'delivered', 'type': 'end'},
            {'name': 'cancelled', 'type': 'end'},
            {'name': 'refunded', 'type': 'end'}
        ]

        transitions = [
            {'from': 'pending', 'to': 'payment_processing', 'action': 'process_payment'},
            {'from': 'pending', 'to': 'cancelled', 'action': 'cancel'},
            {'from': 'payment_processing', 'to': 'paid', 'action': 'payment_success'},
            {'from': 'payment_processing', 'to': 'pending', 'action': 'payment_failed'},
            {'from': 'paid', 'to': 'fulfilling', 'action': 'start_fulfillment'},
            {'from': 'paid', 'to': 'refunded', 'action': 'refund'},
            {'from': 'fulfilling', 'to': 'shipped', 'action': 'ship'},
            {'from': 'shipped', 'to': 'delivered', 'action': 'deliver'},
            {'from': 'shipped', 'to': 'refunded', 'action': 'return'}
        ]

        return await mcp.execute_tool('create_workflow', {
            'name': 'order_workflow',
            'states': states,
            'transitions': transitions
        })


class TicketWorkflow:
    """Support ticket workflow template."""

    async def create(self) -> dict:
        states = [
            {'name': 'new', 'type': 'start'},
            {'name': 'triaged'},
            {'name': 'in_progress'},
            {'name': 'pending_customer'},
            {'name': 'resolved', 'type': 'end'},
            {'name': 'closed', 'type': 'end'}
        ]

        transitions = [
            {'from': 'new', 'to': 'triaged', 'action': 'triage'},
            {'from': 'triaged', 'to': 'in_progress', 'action': 'assign'},
            {'from': 'in_progress', 'to': 'pending_customer', 'action': 'request_info'},
            {'from': 'in_progress', 'to': 'resolved', 'action': 'resolve'},
            {'from': 'pending_customer', 'to': 'in_progress', 'action': 'customer_responded'},
            {'from': 'pending_customer', 'to': 'closed', 'action': 'timeout'},
            {'from': 'resolved', 'to': 'closed', 'action': 'close'},
            {'from': 'resolved', 'to': 'in_progress', 'action': 'reopen'}
        ]

        return await mcp.execute_tool('create_workflow', {
            'name': 'ticket_workflow',
            'states': states,
            'transitions': transitions
        })
```

## Deploy with Gantz CLI

```bash
# Install Gantz
npm install -g gantz

# Initialize workflow system
gantz init --template workflow-system

# Deploy
gantz deploy --platform kubernetes

# Create workflow
gantz run create_workflow --name "approval" --states '[...]' --transitions '[...]'

# Start instance
gantz run start_workflow --workflow-id wf_123 --input '{"data": ...}'

# Transition state
gantz run transition_workflow --instance-id inst_456 --action "approve"

# Request approval
gantz run request_approval --instance-id inst_456 --approvers '["user1", "user2"]'

# View analytics
gantz run workflow_analytics --workflow-id wf_123
```

Build complex process automation at [gantz.run](https://gantz.run).

## Related Reading

- [Pipeline Patterns](/post/pipeline-patterns/) - Sequential processing
- [Orchestration Patterns](/post/orchestration-patterns/) - Multi-agent coordination
- [Consensus Patterns](/post/consensus-patterns/) - Agreement building

## Conclusion

Workflow patterns enable sophisticated business process automation. With state machines, conditional transitions, and human-in-the-loop approvals, you can automate complex processes while maintaining control and visibility.

Start building workflow automation with Gantz today.
