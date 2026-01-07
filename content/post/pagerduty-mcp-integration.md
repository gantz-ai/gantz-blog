+++
title = "PagerDuty MCP Integration: AI-Powered Incident Response"
image = "images/pagerduty-mcp-integration.webp"
date = 2025-05-26
description = "Build intelligent incident management agents with PagerDuty and MCP. Learn automated escalation, incident analysis, and on-call management with Gantz."
draft = false
tags = ['pagerduty', 'incident-management', 'on-call', 'mcp', 'devops', 'gantz']
voice = false

[howto]
name = "How To Build AI Incident Response with PagerDuty and MCP"
totalTime = 30
[[howto.steps]]
name = "Set up PagerDuty API"
text = "Configure PagerDuty API keys and service access"
[[howto.steps]]
name = "Define MCP tools"
text = "Create tool definitions for incident operations"
[[howto.steps]]
name = "Implement handlers"
text = "Build handlers for incidents, escalations, and on-call"
[[howto.steps]]
name = "Add AI capabilities"
text = "Integrate AI-powered incident analysis and automation"
[[howto.steps]]
name = "Deploy with Gantz"
text = "Deploy your incident response automation using Gantz CLI"
+++

PagerDuty is the leading incident response platform, and with MCP integration, you can build AI agents that automate incident triage, intelligent escalation, and post-incident analysis.

## Why PagerDuty MCP Integration?

AI-powered incident response enables:

- **Auto-triage**: Intelligent incident classification
- **Smart escalation**: Context-aware routing
- **Incident correlation**: Group related alerts
- **Runbook automation**: AI-driven response actions
- **Post-mortem generation**: Automated analysis reports

## PagerDuty MCP Tool Definition

Configure PagerDuty tools in Gantz:

```yaml
# gantz.yaml
name: pagerduty-mcp-tools
version: 1.0.0

tools:
  create_incident:
    description: "Create new incident"
    parameters:
      title:
        type: string
        required: true
      service_id:
        type: string
        required: true
      urgency:
        type: string
        default: "high"
      body:
        type: string
    handler: pagerduty.create_incident

  get_incident:
    description: "Get incident details"
    parameters:
      incident_id:
        type: string
        required: true
    handler: pagerduty.get_incident

  update_incident:
    description: "Update incident status"
    parameters:
      incident_id:
        type: string
        required: true
      status:
        type: string
      resolution:
        type: string
    handler: pagerduty.update_incident

  list_incidents:
    description: "List incidents"
    parameters:
      status:
        type: string
      service_ids:
        type: array
      since:
        type: string
    handler: pagerduty.list_incidents

  get_oncall:
    description: "Get on-call schedule"
    parameters:
      schedule_id:
        type: string
        required: true
    handler: pagerduty.get_oncall

  escalate_incident:
    description: "Escalate incident"
    parameters:
      incident_id:
        type: string
        required: true
      escalation_level:
        type: integer
    handler: pagerduty.escalate_incident

  analyze_incident:
    description: "AI analysis of incident"
    parameters:
      incident_id:
        type: string
        required: true
    handler: pagerduty.analyze_incident
```

## Handler Implementation

Build PagerDuty operation handlers:

```python
# handlers/pagerduty.py
import httpx
import os
from datetime import datetime

PAGERDUTY_API = "https://api.pagerduty.com"
API_KEY = os.environ['PAGERDUTY_API_KEY']
FROM_EMAIL = os.environ.get('PAGERDUTY_FROM_EMAIL')


def get_headers():
    """Get authorization headers."""
    return {
        "Authorization": f"Token token={API_KEY}",
        "Content-Type": "application/json",
        "From": FROM_EMAIL
    }


async def api_request(method: str, path: str,
                      data: dict = None, params: dict = None) -> dict:
    """Make PagerDuty API request."""
    async with httpx.AsyncClient() as client:
        response = await client.request(
            method,
            f"{PAGERDUTY_API}{path}",
            json=data,
            params=params,
            headers=get_headers(),
            timeout=30.0
        )

        if response.status_code >= 400:
            return {'error': response.text}

        return response.json() if response.text else {'success': True}


async def create_incident(title: str, service_id: str,
                         urgency: str = "high", body: str = None) -> dict:
    """Create new incident."""
    try:
        incident_data = {
            "incident": {
                "type": "incident",
                "title": title,
                "service": {
                    "id": service_id,
                    "type": "service_reference"
                },
                "urgency": urgency
            }
        }

        if body:
            incident_data["incident"]["body"] = {
                "type": "incident_body",
                "details": body
            }

        result = await api_request("POST", "/incidents", incident_data)

        if 'error' in result:
            return result

        incident = result.get('incident', {})

        return {
            'id': incident.get('id'),
            'incident_number': incident.get('incident_number'),
            'title': title,
            'status': incident.get('status'),
            'urgency': urgency,
            'created': True
        }

    except Exception as e:
        return {'error': f'Failed to create incident: {str(e)}'}


async def get_incident(incident_id: str) -> dict:
    """Get incident details."""
    try:
        result = await api_request("GET", f"/incidents/{incident_id}")

        if 'error' in result:
            return result

        incident = result.get('incident', {})

        return {
            'id': incident.get('id'),
            'incident_number': incident.get('incident_number'),
            'title': incident.get('title'),
            'status': incident.get('status'),
            'urgency': incident.get('urgency'),
            'service': incident.get('service', {}).get('summary'),
            'created_at': incident.get('created_at'),
            'last_status_change_at': incident.get('last_status_change_at'),
            'assignments': [
                a.get('assignee', {}).get('summary')
                for a in incident.get('assignments', [])
            ],
            'escalation_policy': incident.get('escalation_policy', {}).get('summary'),
            'alerts': incident.get('alert_counts', {})
        }

    except Exception as e:
        return {'error': f'Failed to get incident: {str(e)}'}


async def update_incident(incident_id: str, status: str = None,
                         resolution: str = None) -> dict:
    """Update incident status."""
    try:
        incident_data = {
            "incident": {
                "type": "incident"
            }
        }

        if status:
            incident_data["incident"]["status"] = status
        if resolution:
            incident_data["incident"]["resolution"] = resolution

        result = await api_request("PUT", f"/incidents/{incident_id}", incident_data)

        if 'error' in result:
            return result

        return {
            'id': incident_id,
            'updated': True,
            'status': status
        }

    except Exception as e:
        return {'error': f'Failed to update incident: {str(e)}'}


async def list_incidents(status: str = None, service_ids: list = None,
                        since: str = None) -> dict:
    """List incidents."""
    try:
        params = {}
        if status:
            params['statuses[]'] = status
        if service_ids:
            params['service_ids[]'] = service_ids
        if since:
            params['since'] = since

        result = await api_request("GET", "/incidents", params=params)

        if 'error' in result:
            return result

        incidents = result.get('incidents', [])

        return {
            'count': len(incidents),
            'incidents': [{
                'id': i.get('id'),
                'incident_number': i.get('incident_number'),
                'title': i.get('title'),
                'status': i.get('status'),
                'urgency': i.get('urgency'),
                'service': i.get('service', {}).get('summary'),
                'created_at': i.get('created_at')
            } for i in incidents]
        }

    except Exception as e:
        return {'error': f'Failed to list incidents: {str(e)}'}


async def get_oncall(schedule_id: str) -> dict:
    """Get on-call schedule."""
    try:
        result = await api_request(
            "GET",
            f"/schedules/{schedule_id}",
            params={'include[]': 'users'}
        )

        if 'error' in result:
            return result

        schedule = result.get('schedule', {})

        # Get current on-call
        oncalls = await api_request(
            "GET",
            "/oncalls",
            params={'schedule_ids[]': schedule_id}
        )

        current_oncall = oncalls.get('oncalls', [])

        return {
            'schedule_id': schedule_id,
            'name': schedule.get('name'),
            'time_zone': schedule.get('time_zone'),
            'current_oncall': [{
                'user': o.get('user', {}).get('summary'),
                'start': o.get('start'),
                'end': o.get('end'),
                'escalation_level': o.get('escalation_level')
            } for o in current_oncall]
        }

    except Exception as e:
        return {'error': f'Failed to get on-call: {str(e)}'}


async def escalate_incident(incident_id: str, escalation_level: int = None) -> dict:
    """Escalate incident."""
    try:
        # Get current incident
        incident = await get_incident(incident_id)

        if 'error' in incident:
            return incident

        # Create escalation note
        note_data = {
            "note": {
                "content": f"Incident escalated to level {escalation_level}"
            }
        }

        await api_request("POST", f"/incidents/{incident_id}/notes", note_data)

        return {
            'id': incident_id,
            'escalated': True,
            'level': escalation_level
        }

    except Exception as e:
        return {'error': f'Failed to escalate: {str(e)}'}
```

## AI-Powered Incident Analysis

Build intelligent incident management:

```python
# incident_ai.py
from gantz import MCPClient

mcp = MCPClient(config_path='gantz.yaml')


async def analyze_incident(incident_id: str) -> dict:
    """AI analysis of incident."""
    # Get incident details
    incident = mcp.execute_tool('get_incident', {'incident_id': incident_id})

    if 'error' in incident:
        return incident

    # Get related alerts and logs
    alerts = await get_incident_alerts(incident_id)
    timeline = await get_incident_timeline(incident_id)

    # AI analysis
    result = mcp.execute_tool('ai_analyze', {
        'type': 'incident_analysis',
        'incident': incident,
        'alerts': alerts,
        'timeline': timeline,
        'analyze': ['root_cause', 'impact', 'similar_incidents', 'recommendations']
    })

    return {
        'incident_id': incident_id,
        'title': incident['title'],
        'root_cause': result.get('root_cause'),
        'impact_assessment': result.get('impact'),
        'similar_incidents': result.get('similar', []),
        'recommended_actions': result.get('recommendations', []),
        'estimated_resolution': result.get('resolution_time')
    }


async def auto_triage(incident_id: str) -> dict:
    """Automatically triage incident."""
    incident = mcp.execute_tool('get_incident', {'incident_id': incident_id})

    if 'error' in incident:
        return incident

    # AI triage
    result = mcp.execute_tool('ai_classify', {
        'type': 'incident_triage',
        'incident': incident,
        'determine': ['severity', 'category', 'team', 'urgency']
    })

    # Update incident based on triage
    if result.get('urgency') != incident.get('urgency'):
        mcp.execute_tool('update_incident', {
            'incident_id': incident_id,
            'urgency': result.get('urgency')
        })

    return {
        'incident_id': incident_id,
        'triage_result': {
            'severity': result.get('severity'),
            'category': result.get('category'),
            'assigned_team': result.get('team'),
            'urgency': result.get('urgency')
        },
        'confidence': result.get('confidence')
    }


async def correlate_incidents() -> dict:
    """Correlate related incidents."""
    # Get active incidents
    incidents = mcp.execute_tool('list_incidents', {
        'status': 'triggered'
    })

    if not incidents.get('incidents'):
        return {'message': 'No active incidents'}

    # AI correlation
    result = mcp.execute_tool('ai_correlate', {
        'type': 'incidents',
        'items': incidents.get('incidents'),
        'methods': ['temporal', 'service', 'symptom']
    })

    return {
        'total_incidents': len(incidents.get('incidents', [])),
        'correlated_groups': result.get('groups', []),
        'likely_root_cause': result.get('root_cause'),
        'merge_recommendations': result.get('merge_suggestions', [])
    }


async def generate_postmortem(incident_id: str) -> dict:
    """Generate post-incident report."""
    incident = mcp.execute_tool('get_incident', {'incident_id': incident_id})
    timeline = await get_incident_timeline(incident_id)
    notes = await get_incident_notes(incident_id)

    # AI post-mortem generation
    result = mcp.execute_tool('ai_generate', {
        'type': 'postmortem',
        'incident': incident,
        'timeline': timeline,
        'notes': notes,
        'sections': ['summary', 'timeline', 'root_cause', 'impact', 'action_items']
    })

    return {
        'incident_id': incident_id,
        'postmortem': {
            'summary': result.get('summary'),
            'timeline': result.get('timeline'),
            'root_cause_analysis': result.get('root_cause'),
            'impact': result.get('impact'),
            'action_items': result.get('action_items', []),
            'lessons_learned': result.get('lessons', [])
        }
    }


async def suggest_runbook(incident_id: str) -> dict:
    """Suggest runbook for incident."""
    incident = mcp.execute_tool('get_incident', {'incident_id': incident_id})

    result = mcp.execute_tool('ai_generate', {
        'type': 'runbook_suggestion',
        'incident': incident,
        'include': ['diagnosis', 'mitigation', 'verification', 'escalation']
    })

    return {
        'incident_id': incident_id,
        'suggested_runbook': result.get('runbook'),
        'steps': result.get('steps', []),
        'estimated_time': result.get('estimated_time')
    }
```

## On-Call Intelligence

Smart on-call management:

```python
# oncall_ai.py
from gantz import MCPClient

mcp = MCPClient()


async def smart_escalation(incident_id: str) -> dict:
    """AI-driven smart escalation."""
    incident = mcp.execute_tool('get_incident', {'incident_id': incident_id})

    # Analyze incident complexity
    result = mcp.execute_tool('ai_analyze', {
        'type': 'escalation_decision',
        'incident': incident,
        'factors': ['severity', 'duration', 'impact', 'expertise_needed']
    })

    if result.get('should_escalate'):
        # Find best responder
        responder = await find_best_responder(
            incident,
            result.get('expertise_needed')
        )

        mcp.execute_tool('escalate_incident', {
            'incident_id': incident_id,
            'escalation_level': result.get('escalation_level')
        })

        return {
            'incident_id': incident_id,
            'escalated': True,
            'reason': result.get('reason'),
            'new_responder': responder
        }

    return {
        'incident_id': incident_id,
        'escalated': False,
        'reason': result.get('reason')
    }


async def find_best_responder(incident: dict, expertise: list) -> dict:
    """Find best responder for incident."""
    # Get available on-call responders
    oncalls = await get_all_oncalls()

    result = mcp.execute_tool('ai_match', {
        'type': 'responder_matching',
        'incident': incident,
        'expertise_needed': expertise,
        'available_responders': oncalls
    })

    return result.get('best_match')


async def predict_fatigue(schedule_id: str) -> dict:
    """Predict on-call fatigue."""
    oncall = mcp.execute_tool('get_oncall', {'schedule_id': schedule_id})

    # Get historical incident data
    result = mcp.execute_tool('ai_analyze', {
        'type': 'fatigue_prediction',
        'schedule': oncall,
        'analyze': ['incident_frequency', 'response_times', 'escalation_rate']
    })

    return {
        'schedule_id': schedule_id,
        'fatigue_risk': result.get('risk_level'),
        'factors': result.get('contributing_factors', []),
        'recommendations': result.get('recommendations', [])
    }
```

## Deploy with Gantz CLI

Deploy your incident response automation:

```bash
# Install Gantz
npm install -g gantz

# Initialize PagerDuty project
gantz init --template pagerduty-incident-response

# Set environment variables
export PAGERDUTY_API_KEY=your-api-key
export PAGERDUTY_FROM_EMAIL=your-email@example.com

# Deploy
gantz deploy --platform kubernetes

# Analyze incident
gantz run analyze_incident --incident-id P1234567

# Auto-triage
gantz run auto_triage --incident-id P1234567

# Generate post-mortem
gantz run generate_postmortem --incident-id P1234567
```

Build intelligent incident response at [gantz.run](https://gantz.run).

## Related Reading

- [Sentry MCP Integration](/post/sentry-mcp-integration/) - Error tracking
- [Datadog MCP Integration](/post/datadog-mcp-integration/) - Full observability
- [Prometheus MCP Integration](/post/prometheus-mcp-integration/) - Metrics alerting

## Conclusion

PagerDuty and MCP create powerful AI-driven incident response systems. With intelligent triage, smart escalation, and automated post-mortems, you can dramatically reduce MTTR and improve incident management.

Start building PagerDuty AI agents with Gantz today.
