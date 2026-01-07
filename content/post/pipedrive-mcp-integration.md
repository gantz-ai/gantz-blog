+++
title = "Pipedrive MCP Integration: AI-Powered Sales Pipeline Automation"
image = "/images/pipedrive-mcp-integration.png"
date = 2025-06-02
description = "Build intelligent sales agents with Pipedrive and MCP. Learn deal management, activity automation, and AI-driven pipeline optimization with Gantz."
draft = false
tags = ['pipedrive', 'sales', 'pipeline', 'mcp', 'crm', 'gantz']
voice = false

[howto]
name = "How To Build AI Sales Pipeline with Pipedrive and MCP"
totalTime = 30
[[howto.steps]]
name = "Set up Pipedrive API"
text = "Configure Pipedrive API token and access"
[[howto.steps]]
name = "Define MCP tools"
text = "Create tool definitions for sales operations"
[[howto.steps]]
name = "Implement handlers"
text = "Build handlers for deals, persons, and activities"
[[howto.steps]]
name = "Add AI capabilities"
text = "Integrate AI-powered pipeline insights"
[[howto.steps]]
name = "Deploy with Gantz"
text = "Deploy your sales automation using Gantz CLI"
+++

Pipedrive is the sales-focused CRM built for pipeline management, and with MCP integration, you can build AI agents that optimize deals, automate activities, and provide intelligent sales insights.

## Why Pipedrive MCP Integration?

AI-powered sales pipeline enables:

- **Deal scoring**: ML-based win predictions
- **Activity intelligence**: Smart task prioritization
- **Pipeline optimization**: AI-driven stage analysis
- **Email automation**: Personalized outreach
- **Forecast accuracy**: Predictive deal analytics

## Pipedrive MCP Tool Definition

Configure Pipedrive tools in Gantz:

```yaml
# gantz.yaml
name: pipedrive-mcp-tools
version: 1.0.0

tools:
  get_deals:
    description: "Get deals with filters"
    parameters:
      status:
        type: string
        default: "open"
      stage_id:
        type: integer
      owner_id:
        type: integer
    handler: pipedrive.get_deals

  get_deal:
    description: "Get deal by ID"
    parameters:
      deal_id:
        type: integer
        required: true
    handler: pipedrive.get_deal

  create_deal:
    description: "Create new deal"
    parameters:
      title:
        type: string
        required: true
      value:
        type: number
      person_id:
        type: integer
      stage_id:
        type: integer
    handler: pipedrive.create_deal

  update_deal:
    description: "Update deal"
    parameters:
      deal_id:
        type: integer
        required: true
      data:
        type: object
        required: true
    handler: pipedrive.update_deal

  get_activities:
    description: "Get activities"
    parameters:
      deal_id:
        type: integer
      done:
        type: boolean
    handler: pipedrive.get_activities

  create_activity:
    description: "Create activity"
    parameters:
      subject:
        type: string
        required: true
      type:
        type: string
        required: true
      deal_id:
        type: integer
      due_date:
        type: string
    handler: pipedrive.create_activity

  analyze_pipeline:
    description: "AI pipeline analysis"
    handler: pipedrive.analyze_pipeline

  predict_deal:
    description: "AI deal prediction"
    parameters:
      deal_id:
        type: integer
        required: true
    handler: pipedrive.predict_deal
```

## Handler Implementation

Build Pipedrive operation handlers:

```python
# handlers/pipedrive.py
import httpx
import os

PIPEDRIVE_API = "https://api.pipedrive.com/v1"
API_TOKEN = os.environ['PIPEDRIVE_API_TOKEN']


async def api_request(method: str, path: str,
                      data: dict = None, params: dict = None) -> dict:
    """Make Pipedrive API request."""
    async with httpx.AsyncClient() as client:
        params = params or {}
        params['api_token'] = API_TOKEN

        response = await client.request(
            method,
            f"{PIPEDRIVE_API}{path}",
            json=data,
            params=params,
            timeout=30.0
        )

        result = response.json()

        if not result.get('success'):
            return {'error': result.get('error', 'Request failed')}

        return result


async def get_deals(status: str = "open", stage_id: int = None,
                   owner_id: int = None) -> dict:
    """Get deals with filters."""
    try:
        params = {'status': status}
        if stage_id:
            params['stage_id'] = stage_id
        if owner_id:
            params['user_id'] = owner_id

        result = await api_request("GET", "/deals", params=params)

        if 'error' in result:
            return result

        deals = result.get('data', []) or []

        return {
            'count': len(deals),
            'deals': [{
                'id': d.get('id'),
                'title': d.get('title'),
                'value': d.get('value'),
                'currency': d.get('currency'),
                'stage_id': d.get('stage_id'),
                'stage_name': d.get('stage', {}).get('name') if d.get('stage') else None,
                'person_name': d.get('person_name'),
                'org_name': d.get('org_name'),
                'expected_close_date': d.get('expected_close_date'),
                'probability': d.get('probability'),
                'status': d.get('status'),
                'add_time': d.get('add_time')
            } for d in deals]
        }

    except Exception as e:
        return {'error': f'Failed to get deals: {str(e)}'}


async def get_deal(deal_id: int) -> dict:
    """Get deal by ID."""
    try:
        result = await api_request("GET", f"/deals/{deal_id}")

        if 'error' in result:
            return result

        d = result.get('data', {})

        return {
            'id': d.get('id'),
            'title': d.get('title'),
            'value': d.get('value'),
            'currency': d.get('currency'),
            'stage_id': d.get('stage_id'),
            'person_id': d.get('person_id'),
            'person_name': d.get('person_name'),
            'org_id': d.get('org_id'),
            'org_name': d.get('org_name'),
            'expected_close_date': d.get('expected_close_date'),
            'probability': d.get('probability'),
            'status': d.get('status'),
            'won_time': d.get('won_time'),
            'lost_time': d.get('lost_time'),
            'add_time': d.get('add_time'),
            'update_time': d.get('update_time'),
            'activities_count': d.get('activities_count'),
            'email_messages_count': d.get('email_messages_count')
        }

    except Exception as e:
        return {'error': f'Failed to get deal: {str(e)}'}


async def create_deal(title: str, value: float = None,
                     person_id: int = None, stage_id: int = None) -> dict:
    """Create new deal."""
    try:
        data = {'title': title}
        if value:
            data['value'] = value
        if person_id:
            data['person_id'] = person_id
        if stage_id:
            data['stage_id'] = stage_id

        result = await api_request("POST", "/deals", data)

        if 'error' in result:
            return result

        return {
            'id': result.get('data', {}).get('id'),
            'created': True,
            'title': title
        }

    except Exception as e:
        return {'error': f'Failed to create deal: {str(e)}'}


async def update_deal(deal_id: int, data: dict) -> dict:
    """Update deal."""
    try:
        result = await api_request("PUT", f"/deals/{deal_id}", data)

        if 'error' in result:
            return result

        return {
            'id': deal_id,
            'updated': True,
            'changes': data
        }

    except Exception as e:
        return {'error': f'Failed to update deal: {str(e)}'}


async def get_activities(deal_id: int = None, done: bool = None) -> dict:
    """Get activities."""
    try:
        params = {}
        if deal_id:
            params['deal_id'] = deal_id
        if done is not None:
            params['done'] = 1 if done else 0

        result = await api_request("GET", "/activities", params=params)

        if 'error' in result:
            return result

        activities = result.get('data', []) or []

        return {
            'count': len(activities),
            'activities': [{
                'id': a.get('id'),
                'subject': a.get('subject'),
                'type': a.get('type'),
                'due_date': a.get('due_date'),
                'due_time': a.get('due_time'),
                'done': a.get('done'),
                'deal_id': a.get('deal_id'),
                'person_id': a.get('person_id')
            } for a in activities]
        }

    except Exception as e:
        return {'error': f'Failed to get activities: {str(e)}'}


async def create_activity(subject: str, type: str, deal_id: int = None,
                         due_date: str = None) -> dict:
    """Create activity."""
    try:
        data = {
            'subject': subject,
            'type': type
        }
        if deal_id:
            data['deal_id'] = deal_id
        if due_date:
            data['due_date'] = due_date

        result = await api_request("POST", "/activities", data)

        if 'error' in result:
            return result

        return {
            'id': result.get('data', {}).get('id'),
            'created': True,
            'subject': subject
        }

    except Exception as e:
        return {'error': f'Failed to create activity: {str(e)}'}


async def get_pipeline_stages() -> dict:
    """Get pipeline stages."""
    try:
        result = await api_request("GET", "/stages")

        if 'error' in result:
            return result

        stages = result.get('data', []) or []

        return {
            'count': len(stages),
            'stages': [{
                'id': s.get('id'),
                'name': s.get('name'),
                'pipeline_id': s.get('pipeline_id'),
                'order_nr': s.get('order_nr'),
                'deal_probability': s.get('deal_probability')
            } for s in stages]
        }

    except Exception as e:
        return {'error': f'Failed to get stages: {str(e)}'}
```

## AI-Powered Pipeline Intelligence

Build intelligent sales automation:

```python
# pipedrive_ai.py
from gantz import MCPClient

mcp = MCPClient(config_path='gantz.yaml')


async def analyze_pipeline() -> dict:
    """AI pipeline analysis."""
    # Get all open deals
    deals = mcp.execute_tool('get_deals', {'status': 'open'})
    stages = await get_pipeline_stages()

    # AI analysis
    result = mcp.execute_tool('ai_analyze', {
        'type': 'pipeline_analysis',
        'deals': deals.get('deals', []),
        'stages': stages.get('stages', []),
        'analyze': ['velocity', 'bottlenecks', 'conversion', 'forecast']
    })

    return {
        'total_deals': len(deals.get('deals', [])),
        'total_value': sum(d.get('value', 0) or 0 for d in deals.get('deals', [])),
        'velocity': result.get('velocity'),
        'bottlenecks': result.get('bottlenecks', []),
        'conversion_rates': result.get('conversion', {}),
        'forecast': result.get('forecast'),
        'recommendations': result.get('recommendations', [])
    }


async def predict_deal(deal_id: int) -> dict:
    """AI deal prediction."""
    # Get deal data
    deal = mcp.execute_tool('get_deal', {'deal_id': deal_id})
    activities = mcp.execute_tool('get_activities', {'deal_id': deal_id})

    if 'error' in deal:
        return deal

    # AI prediction
    result = mcp.execute_tool('ai_predict', {
        'type': 'deal_outcome',
        'deal': deal,
        'activities': activities.get('activities', []),
        'predict': ['win_probability', 'close_date', 'risk_factors']
    })

    return {
        'deal_id': deal_id,
        'title': deal.get('title'),
        'win_probability': result.get('probability'),
        'predicted_close': result.get('close_date'),
        'confidence': result.get('confidence'),
        'risk_factors': result.get('risks', []),
        'recommended_actions': result.get('actions', [])
    }


async def prioritize_deals() -> dict:
    """AI deal prioritization."""
    deals = mcp.execute_tool('get_deals', {'status': 'open'})

    # AI prioritization
    result = mcp.execute_tool('ai_analyze', {
        'type': 'deal_prioritization',
        'deals': deals.get('deals', []),
        'factors': ['value', 'probability', 'effort', 'urgency']
    })

    return {
        'prioritized_deals': result.get('ranked_deals', []),
        'high_priority': result.get('high_priority', []),
        'at_risk': result.get('at_risk', []),
        'quick_wins': result.get('quick_wins', [])
    }


async def suggest_next_action(deal_id: int) -> dict:
    """Suggest next best action for deal."""
    deal = mcp.execute_tool('get_deal', {'deal_id': deal_id})
    activities = mcp.execute_tool('get_activities', {'deal_id': deal_id})

    result = mcp.execute_tool('ai_generate', {
        'type': 'next_action',
        'deal': deal,
        'activities': activities.get('activities', []),
        'suggest': ['action', 'timing', 'message']
    })

    return {
        'deal_id': deal_id,
        'recommended_action': result.get('action'),
        'action_type': result.get('type'),
        'suggested_date': result.get('date'),
        'message_template': result.get('message'),
        'reasoning': result.get('reasoning')
    }


async def auto_schedule_activities(deal_id: int) -> dict:
    """Auto-schedule follow-up activities."""
    deal = mcp.execute_tool('get_deal', {'deal_id': deal_id})
    existing = mcp.execute_tool('get_activities', {'deal_id': deal_id, 'done': False})

    # AI scheduling
    result = mcp.execute_tool('ai_generate', {
        'type': 'activity_schedule',
        'deal': deal,
        'existing_activities': existing.get('activities', []),
        'schedule_days': 14
    })

    # Create activities
    created = []
    for activity in result.get('activities', []):
        new_activity = mcp.execute_tool('create_activity', {
            'subject': activity.get('subject'),
            'type': activity.get('type'),
            'deal_id': deal_id,
            'due_date': activity.get('due_date')
        })
        created.append(new_activity)

    return {
        'deal_id': deal_id,
        'activities_created': len(created),
        'schedule': result.get('activities', [])
    }
```

## Sales Coaching

AI-powered sales coaching:

```python
# sales_coaching.py
from gantz import MCPClient

mcp = MCPClient()


async def coach_deal(deal_id: int) -> dict:
    """AI coaching for deal."""
    deal = mcp.execute_tool('get_deal', {'deal_id': deal_id})
    activities = mcp.execute_tool('get_activities', {'deal_id': deal_id})

    result = mcp.execute_tool('ai_analyze', {
        'type': 'sales_coaching',
        'deal': deal,
        'activities': activities.get('activities', []),
        'provide': ['assessment', 'tips', 'objection_handling', 'closing_techniques']
    })

    return {
        'deal_id': deal_id,
        'assessment': result.get('assessment'),
        'coaching_tips': result.get('tips', []),
        'objection_responses': result.get('objections', []),
        'closing_techniques': result.get('closing', [])
    }


async def generate_proposal(deal_id: int) -> dict:
    """Generate proposal for deal."""
    deal = mcp.execute_tool('get_deal', {'deal_id': deal_id})

    result = mcp.execute_tool('ai_generate', {
        'type': 'sales_proposal',
        'deal': deal,
        'include': ['executive_summary', 'solution', 'pricing', 'timeline']
    })

    return {
        'deal_id': deal_id,
        'proposal': result.get('proposal'),
        'sections': result.get('sections', [])
    }
```

## Deploy with Gantz CLI

Deploy your sales automation:

```bash
# Install Gantz
npm install -g gantz

# Initialize Pipedrive project
gantz init --template pipedrive-sales

# Set environment variables
export PIPEDRIVE_API_TOKEN=your-api-token

# Deploy
gantz deploy --platform railway

# Analyze pipeline
gantz run analyze_pipeline

# Predict deal outcome
gantz run predict_deal --deal-id 12345

# Prioritize deals
gantz run prioritize_deals

# Suggest next action
gantz run suggest_next_action --deal-id 12345
```

Build intelligent sales pipelines at [gantz.run](https://gantz.run).

## Related Reading

- [Salesforce MCP Integration](/post/salesforce-mcp-integration/) - Enterprise CRM
- [HubSpot MCP Integration](/post/hubspot-mcp-integration/) - Marketing automation
- [Linear MCP Integration](/post/linear-mcp-integration/) - Issue tracking

## Conclusion

Pipedrive and MCP create powerful AI-driven sales automation. With intelligent deal predictions, automated activities, and pipeline optimization, you can close more deals and accelerate revenue.

Start building Pipedrive AI agents with Gantz today.
