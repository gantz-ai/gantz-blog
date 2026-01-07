+++
title = "Building an AI Onboarding Agent with MCP: Automated User Activation"
image = "/images/onboarding-agent.png"
date = 2025-06-15
description = "Build intelligent onboarding agents with MCP and Gantz. Learn personalized onboarding flows, progress tracking, and AI-driven user activation."
draft = false
tags = ['onboarding', 'agent', 'ai', 'mcp', 'customer-success', 'gantz']
voice = false

[howto]
name = "How To Build an AI Onboarding Agent with MCP"
totalTime = 35
[[howto.steps]]
name = "Design agent architecture"
text = "Plan onboarding agent capabilities"
[[howto.steps]]
name = "Integrate user systems"
text = "Connect to CRM and product analytics"
[[howto.steps]]
name = "Build personalization"
text = "Create adaptive onboarding flows"
[[howto.steps]]
name = "Add intervention logic"
text = "Implement AI-driven nudges"
[[howto.steps]]
name = "Deploy with Gantz"
text = "Deploy your onboarding agent using Gantz CLI"
+++

An AI onboarding agent automates user activation, personalizes onboarding flows, and proactively intervenes to ensure successful product adoption.

## Why Build an Onboarding Agent?

AI-powered onboarding enables:

- **Personalized journeys**: Adaptive onboarding paths
- **Progress tracking**: Real-time activation metrics
- **Proactive intervention**: AI-triggered assistance
- **Resource optimization**: Automated support scaling
- **Conversion optimization**: Improve time-to-value

## Onboarding Agent Architecture

```yaml
# gantz.yaml
name: onboarding-agent
version: 1.0.0

tools:
  create_journey:
    description: "Create personalized onboarding journey"
    parameters:
      user_id:
        type: string
        required: true
      user_profile:
        type: object
    handler: onboarding.create_journey

  track_progress:
    description: "Track onboarding progress"
    parameters:
      user_id:
        type: string
        required: true
    handler: onboarding.track_progress

  trigger_intervention:
    description: "Trigger onboarding intervention"
    parameters:
      user_id:
        type: string
        required: true
      intervention_type:
        type: string
    handler: onboarding.trigger_intervention

  analyze_cohort:
    description: "Analyze onboarding cohort"
    parameters:
      cohort_id:
        type: string
    handler: onboarding.analyze_cohort

  optimize_flow:
    description: "Optimize onboarding flow"
    parameters:
      segment:
        type: string
    handler: onboarding.optimize_flow

  generate_content:
    description: "Generate onboarding content"
    parameters:
      step:
        type: string
        required: true
      user_context:
        type: object
    handler: onboarding.generate_content
```

## Handler Implementation

```python
# handlers/onboarding.py
import os
from datetime import datetime, timedelta

DB_URL = os.environ.get('ONBOARDING_DB_URL')


async def create_journey(user_id: str, user_profile: dict = None) -> dict:
    """Create personalized onboarding journey."""
    from gantz import MCPClient
    mcp = MCPClient()

    # Get user data if not provided
    if not user_profile:
        user_profile = await fetch_user_profile(user_id)

    # AI journey personalization
    result = mcp.execute_tool('ai_generate', {
        'type': 'onboarding_journey',
        'user_profile': user_profile,
        'factors': ['role', 'company_size', 'use_case', 'experience_level'],
        'generate': ['steps', 'milestones', 'content', 'timeline']
    })

    journey = {
        'user_id': user_id,
        'journey_id': generate_journey_id(),
        'steps': result.get('steps', []),
        'milestones': result.get('milestones', []),
        'expected_duration': result.get('duration'),
        'personalization_factors': result.get('factors', {}),
        'created_at': datetime.now().isoformat()
    }

    # Save journey
    await save_journey(journey)

    return {
        'journey_id': journey['journey_id'],
        'user_id': user_id,
        'total_steps': len(journey['steps']),
        'milestones': journey['milestones'],
        'first_step': journey['steps'][0] if journey['steps'] else None,
        'personalized_for': list(result.get('factors', {}).keys())
    }


async def track_progress(user_id: str) -> dict:
    """Track onboarding progress."""
    from gantz import MCPClient
    mcp = MCPClient()

    # Get journey and events
    journey = await fetch_user_journey(user_id)
    events = await fetch_user_events(user_id)

    # Calculate progress
    completed_steps = calculate_completed_steps(journey, events)
    current_step = find_current_step(journey, completed_steps)

    # AI progress analysis
    result = mcp.execute_tool('ai_analyze', {
        'type': 'onboarding_progress',
        'journey': journey,
        'events': events,
        'completed_steps': completed_steps,
        'analyze': ['health', 'risks', 'next_actions', 'intervention_needed']
    })

    return {
        'user_id': user_id,
        'journey_id': journey.get('journey_id'),
        'progress_percent': len(completed_steps) / len(journey.get('steps', [1])) * 100,
        'completed_steps': len(completed_steps),
        'total_steps': len(journey.get('steps', [])),
        'current_step': current_step,
        'health_score': result.get('health_score'),
        'days_since_start': (datetime.now() - datetime.fromisoformat(journey.get('created_at', datetime.now().isoformat()))).days,
        'at_risk': result.get('at_risk'),
        'intervention_needed': result.get('intervention_needed'),
        'next_actions': result.get('next_actions', [])
    }


async def trigger_intervention(user_id: str, intervention_type: str = None) -> dict:
    """Trigger onboarding intervention."""
    from gantz import MCPClient
    mcp = MCPClient()

    # Get user context
    progress = await track_progress(user_id)
    user_profile = await fetch_user_profile(user_id)

    # Determine intervention type if not specified
    if not intervention_type:
        type_result = mcp.execute_tool('ai_classify', {
            'type': 'intervention_type',
            'progress': progress,
            'user_profile': user_profile
        })
        intervention_type = type_result.get('recommended_type')

    # Generate intervention
    result = mcp.execute_tool('ai_generate', {
        'type': f'intervention_{intervention_type}',
        'user_profile': user_profile,
        'progress': progress,
        'generate': ['message', 'call_to_action', 'resources']
    })

    # Execute intervention
    intervention = {
        'user_id': user_id,
        'type': intervention_type,
        'message': result.get('message'),
        'cta': result.get('call_to_action'),
        'resources': result.get('resources', []),
        'triggered_at': datetime.now().isoformat()
    }

    await execute_intervention(intervention)

    return {
        'user_id': user_id,
        'intervention_type': intervention_type,
        'message_sent': True,
        'content': result.get('message'),
        'call_to_action': result.get('call_to_action'),
        'resources_shared': len(result.get('resources', []))
    }


async def analyze_cohort(cohort_id: str = None) -> dict:
    """Analyze onboarding cohort."""
    from gantz import MCPClient
    mcp = MCPClient()

    # Get cohort users
    if cohort_id:
        users = await fetch_cohort_users(cohort_id)
    else:
        users = await fetch_recent_users(days=30)

    # Get progress for all users
    progress_data = []
    for user in users:
        progress = await track_progress(user['id'])
        progress_data.append(progress)

    # AI cohort analysis
    result = mcp.execute_tool('ai_analyze', {
        'type': 'cohort_analysis',
        'cohort': progress_data,
        'analyze': ['conversion', 'dropoff', 'patterns', 'segments']
    })

    return {
        'cohort_id': cohort_id,
        'total_users': len(users),
        'completion_rate': result.get('completion_rate'),
        'average_time_to_complete': result.get('avg_completion_time'),
        'dropoff_points': result.get('dropoff_points', []),
        'user_segments': result.get('segments', {}),
        'at_risk_users': result.get('at_risk', []),
        'insights': result.get('insights', []),
        'recommendations': result.get('recommendations', [])
    }


async def optimize_flow(segment: str = None) -> dict:
    """Optimize onboarding flow."""
    from gantz import MCPClient
    mcp = MCPClient()

    # Get historical data
    completions = await fetch_completion_data(segment)
    dropoffs = await fetch_dropoff_data(segment)
    feedback = await fetch_user_feedback(segment)

    # AI optimization
    result = mcp.execute_tool('ai_optimize', {
        'type': 'onboarding_flow',
        'completions': completions,
        'dropoffs': dropoffs,
        'feedback': feedback,
        'optimize': ['step_order', 'content', 'timing', 'interventions']
    })

    return {
        'segment': segment,
        'current_completion_rate': result.get('current_rate'),
        'predicted_improvement': result.get('predicted_improvement'),
        'recommended_changes': result.get('changes', []),
        'step_optimizations': result.get('step_changes', []),
        'timing_adjustments': result.get('timing', []),
        'new_interventions': result.get('interventions', [])
    }


async def generate_content(step: str, user_context: dict = None) -> dict:
    """Generate personalized onboarding content."""
    from gantz import MCPClient
    mcp = MCPClient()

    result = mcp.execute_tool('ai_generate', {
        'type': 'onboarding_content',
        'step': step,
        'user_context': user_context,
        'generate': ['title', 'body', 'tips', 'examples', 'next_steps']
    })

    return {
        'step': step,
        'title': result.get('title'),
        'body': result.get('body'),
        'tips': result.get('tips', []),
        'examples': result.get('examples', []),
        'next_steps': result.get('next_steps', [])
    }


def calculate_completed_steps(journey: dict, events: list) -> list:
    """Calculate completed onboarding steps."""
    completed = []
    step_events = {e['step_id']: e for e in events if e.get('type') == 'step_complete'}

    for step in journey.get('steps', []):
        if step['id'] in step_events:
            completed.append(step['id'])

    return completed


def find_current_step(journey: dict, completed: list) -> dict:
    """Find current onboarding step."""
    for step in journey.get('steps', []):
        if step['id'] not in completed:
            return step
    return None
```

## Onboarding Agent Orchestration

```python
# onboarding_agent.py
from gantz import MCPClient

mcp = MCPClient(config_path='gantz.yaml')


async def monitor_onboarding() -> dict:
    """Monitor all active onboarding users."""
    # Get users in onboarding
    active_users = await fetch_users_in_onboarding()

    at_risk = []
    interventions_triggered = []

    for user in active_users:
        progress = mcp.execute_tool('track_progress', {'user_id': user['id']})

        if progress.get('at_risk') or progress.get('intervention_needed'):
            at_risk.append(user['id'])

            # Trigger intervention
            intervention = mcp.execute_tool('trigger_intervention', {
                'user_id': user['id']
            })
            interventions_triggered.append(intervention)

    # Daily cohort analysis
    cohort = mcp.execute_tool('analyze_cohort', {})

    return {
        'date': datetime.now().isoformat(),
        'active_users': len(active_users),
        'at_risk_users': len(at_risk),
        'interventions_sent': len(interventions_triggered),
        'cohort_completion_rate': cohort.get('completion_rate'),
        'insights': cohort.get('insights', [])
    }


async def onboard_new_user(user_id: str, signup_data: dict) -> dict:
    """Complete onboarding setup for new user."""
    # Create personalized journey
    journey = mcp.execute_tool('create_journey', {
        'user_id': user_id,
        'user_profile': signup_data
    })

    # Generate welcome content
    welcome = mcp.execute_tool('generate_content', {
        'step': 'welcome',
        'user_context': signup_data
    })

    # Send welcome message
    await send_welcome_message(user_id, welcome)

    return {
        'user_id': user_id,
        'journey_created': True,
        'journey_id': journey.get('journey_id'),
        'first_step': journey.get('first_step'),
        'welcome_sent': True
    }
```

## Deploy with Gantz CLI

```bash
# Install Gantz
npm install -g gantz

# Initialize onboarding agent
gantz init --template onboarding-agent

# Set database connection
export ONBOARDING_DB_URL=your-database-url

# Deploy
gantz deploy --platform vercel

# Create journey for new user
gantz run onboard_new_user --user-id user123 --signup-data '{}'

# Track progress
gantz run track_progress --user-id user123

# Monitor all onboarding
gantz run monitor_onboarding

# Analyze cohort
gantz run analyze_cohort --cohort-id march2025
```

Build intelligent onboarding at [gantz.run](https://gantz.run).

## Related Reading

- [Churn Prevention Agent](/post/churn-prevention-agent/) - Retention automation
- [Feedback Agent](/post/feedback-agent/) - User feedback analysis
- [Customer Success](/post/customer-success-mcp/) - Customer automation

## Conclusion

An AI onboarding agent transforms user activation from generic to personalized. With adaptive journeys, proactive interventions, and continuous optimization, you can improve time-to-value and reduce churn.

Start building your onboarding agent with Gantz today.
