+++
title = "Sentry MCP Integration: AI-Powered Error Tracking and Analysis"
image = "images/sentry-mcp-integration.webp"
date = 2025-05-25
description = "Build intelligent error tracking agents with Sentry and MCP. Learn issue management, release tracking, and AI-driven debugging with Gantz."
summary = "Let AI analyze your Sentry errors - auto-triage by severity, identify root causes from stack traces, suggest code fixes, detect regression patterns, and group similar issues. Includes handlers for issue management, event analysis, and release tracking integration."
draft = false
tags = ['sentry', 'error-tracking', 'debugging', 'mcp', 'devops', 'gantz']
voice = false

[howto]
name = "How To Build AI Error Tracking with Sentry and MCP"
totalTime = 30
[[howto.steps]]
name = "Set up Sentry API"
text = "Configure Sentry organization and API tokens"
[[howto.steps]]
name = "Define MCP tools"
text = "Create tool definitions for error tracking operations"
[[howto.steps]]
name = "Implement handlers"
text = "Build handlers for issues, events, and releases"
[[howto.steps]]
name = "Add AI capabilities"
text = "Integrate AI-powered debugging and analysis"
[[howto.steps]]
name = "Deploy with Gantz"
text = "Deploy your error tracking automation using Gantz CLI"
+++

Sentry is the leading error tracking platform, and with MCP integration, you can build AI agents that analyze errors, suggest fixes, and automate issue triage, dramatically reducing debugging time.

## Why Sentry MCP Integration?

AI-powered error tracking enables:

- **Auto-triage**: Intelligent issue prioritization
- **Root cause analysis**: AI-driven debugging
- **Fix suggestions**: Code recommendations
- **Pattern detection**: Group similar errors
- **Regression detection**: Track fix effectiveness

## Sentry MCP Tool Definition

Configure Sentry tools in Gantz:

```yaml
# gantz.yaml
name: sentry-mcp-tools
version: 1.0.0

tools:
  get_issues:
    description: "Get project issues"
    parameters:
      project:
        type: string
        required: true
      query:
        type: string
      status:
        type: string
        default: "unresolved"
    handler: sentry.get_issues

  get_issue_details:
    description: "Get issue details and events"
    parameters:
      issue_id:
        type: string
        required: true
    handler: sentry.get_issue_details

  update_issue:
    description: "Update issue status or assignment"
    parameters:
      issue_id:
        type: string
        required: true
      status:
        type: string
      assignee:
        type: string
    handler: sentry.update_issue

  get_events:
    description: "Get error events"
    parameters:
      project:
        type: string
        required: true
      limit:
        type: integer
        default: 100
    handler: sentry.get_events

  get_releases:
    description: "Get project releases"
    parameters:
      project:
        type: string
        required: true
    handler: sentry.get_releases

  analyze_issue:
    description: "AI analysis of issue"
    parameters:
      issue_id:
        type: string
        required: true
    handler: sentry.analyze_issue

  suggest_fix:
    description: "Get AI fix suggestions"
    parameters:
      issue_id:
        type: string
        required: true
    handler: sentry.suggest_fix
```

## Handler Implementation

Build Sentry operation handlers:

```python
# handlers/sentry.py
import httpx
import os

SENTRY_API = "https://sentry.io/api/0"
SENTRY_TOKEN = os.environ['SENTRY_AUTH_TOKEN']
SENTRY_ORG = os.environ['SENTRY_ORG']


def get_headers():
    """Get authorization headers."""
    return {
        "Authorization": f"Bearer {SENTRY_TOKEN}",
        "Content-Type": "application/json"
    }


async def api_request(method: str, path: str,
                      data: dict = None, params: dict = None) -> dict:
    """Make Sentry API request."""
    async with httpx.AsyncClient() as client:
        response = await client.request(
            method,
            f"{SENTRY_API}{path}",
            json=data,
            params=params,
            headers=get_headers(),
            timeout=30.0
        )

        if response.status_code >= 400:
            return {'error': response.text}

        return response.json() if response.text else {'success': True}


async def get_issues(project: str, query: str = None,
                    status: str = "unresolved") -> dict:
    """Get project issues."""
    try:
        params = {'query': f'is:{status}'}
        if query:
            params['query'] += f' {query}'

        result = await api_request(
            "GET",
            f"/projects/{SENTRY_ORG}/{project}/issues/",
            params=params
        )

        if 'error' in result:
            return result

        return {
            'project': project,
            'count': len(result),
            'issues': [{
                'id': i.get('id'),
                'title': i.get('title'),
                'culprit': i.get('culprit'),
                'level': i.get('level'),
                'count': i.get('count'),
                'first_seen': i.get('firstSeen'),
                'last_seen': i.get('lastSeen'),
                'status': i.get('status')
            } for i in result]
        }

    except Exception as e:
        return {'error': f'Failed to get issues: {str(e)}'}


async def get_issue_details(issue_id: str) -> dict:
    """Get issue details and latest events."""
    try:
        # Get issue
        issue = await api_request("GET", f"/issues/{issue_id}/")

        if 'error' in issue:
            return issue

        # Get latest event
        latest_event = await api_request(
            "GET",
            f"/issues/{issue_id}/events/latest/"
        )

        # Get events
        events = await api_request(
            "GET",
            f"/issues/{issue_id}/events/",
            params={'limit': 10}
        )

        return {
            'id': issue.get('id'),
            'title': issue.get('title'),
            'culprit': issue.get('culprit'),
            'type': issue.get('type'),
            'level': issue.get('level'),
            'count': issue.get('count'),
            'users_affected': issue.get('userCount'),
            'first_seen': issue.get('firstSeen'),
            'last_seen': issue.get('lastSeen'),
            'status': issue.get('status'),
            'assignee': issue.get('assignedTo', {}).get('name'),
            'latest_event': {
                'id': latest_event.get('eventID'),
                'message': latest_event.get('message'),
                'platform': latest_event.get('platform'),
                'stacktrace': extract_stacktrace(latest_event),
                'tags': latest_event.get('tags', []),
                'context': latest_event.get('contexts', {})
            },
            'recent_events': len(events) if isinstance(events, list) else 0
        }

    except Exception as e:
        return {'error': f'Failed to get issue: {str(e)}'}


def extract_stacktrace(event: dict) -> list:
    """Extract stacktrace from event."""
    frames = []
    entries = event.get('entries', [])

    for entry in entries:
        if entry.get('type') == 'exception':
            values = entry.get('data', {}).get('values', [])
            for value in values:
                stacktrace = value.get('stacktrace', {})
                for frame in stacktrace.get('frames', [])[-10:]:  # Last 10 frames
                    frames.append({
                        'filename': frame.get('filename'),
                        'function': frame.get('function'),
                        'lineno': frame.get('lineNo'),
                        'context': frame.get('context', [])
                    })

    return frames


async def update_issue(issue_id: str, status: str = None,
                      assignee: str = None) -> dict:
    """Update issue status or assignment."""
    try:
        data = {}
        if status:
            data['status'] = status
        if assignee:
            data['assignedTo'] = assignee

        result = await api_request("PUT", f"/issues/{issue_id}/", data)

        if 'error' in result:
            return result

        return {
            'id': issue_id,
            'updated': True,
            'changes': data
        }

    except Exception as e:
        return {'error': f'Failed to update issue: {str(e)}'}


async def get_events(project: str, limit: int = 100) -> dict:
    """Get error events."""
    try:
        result = await api_request(
            "GET",
            f"/projects/{SENTRY_ORG}/{project}/events/",
            params={'limit': limit}
        )

        if 'error' in result:
            return result

        return {
            'project': project,
            'count': len(result),
            'events': [{
                'id': e.get('eventID'),
                'title': e.get('title'),
                'message': e.get('message'),
                'level': e.get('level'),
                'timestamp': e.get('dateCreated'),
                'user': e.get('user', {}).get('email')
            } for e in result]
        }

    except Exception as e:
        return {'error': f'Failed to get events: {str(e)}'}


async def get_releases(project: str) -> dict:
    """Get project releases."""
    try:
        result = await api_request(
            "GET",
            f"/projects/{SENTRY_ORG}/{project}/releases/"
        )

        if 'error' in result:
            return result

        return {
            'project': project,
            'count': len(result),
            'releases': [{
                'version': r.get('version'),
                'date_released': r.get('dateReleased'),
                'new_groups': r.get('newGroups'),
                'commit_count': r.get('commitCount'),
                'authors': [a.get('name') for a in r.get('authors', [])]
            } for r in result]
        }

    except Exception as e:
        return {'error': f'Failed to get releases: {str(e)}'}
```

## AI-Powered Error Analysis

Build intelligent debugging:

```python
# error_ai.py
from gantz import MCPClient

mcp = MCPClient(config_path='gantz.yaml')


async def analyze_issue(issue_id: str) -> dict:
    """AI analysis of Sentry issue."""
    # Get issue details
    issue = mcp.execute_tool('get_issue_details', {'issue_id': issue_id})

    if 'error' in issue:
        return issue

    # AI analysis
    result = mcp.execute_tool('ai_analyze', {
        'type': 'error_analysis',
        'error': {
            'title': issue['title'],
            'type': issue['type'],
            'stacktrace': issue['latest_event']['stacktrace'],
            'context': issue['latest_event']['context'],
            'tags': issue['latest_event']['tags']
        },
        'analyze': ['root_cause', 'impact', 'patterns', 'severity']
    })

    return {
        'issue_id': issue_id,
        'title': issue['title'],
        'root_cause': result.get('root_cause'),
        'impact_assessment': result.get('impact'),
        'error_pattern': result.get('pattern'),
        'severity_assessment': result.get('severity'),
        'similar_issues': result.get('similar', []),
        'insights': result.get('insights', [])
    }


async def suggest_fix(issue_id: str) -> dict:
    """Get AI fix suggestions."""
    # Get issue details
    issue = mcp.execute_tool('get_issue_details', {'issue_id': issue_id})

    if 'error' in issue:
        return issue

    # Generate fix suggestions
    result = mcp.execute_tool('ai_generate', {
        'type': 'code_fix',
        'error': {
            'title': issue['title'],
            'type': issue['type'],
            'stacktrace': issue['latest_event']['stacktrace'],
            'message': issue['latest_event']['message']
        },
        'generate': ['fix', 'explanation', 'prevention', 'test']
    })

    return {
        'issue_id': issue_id,
        'title': issue['title'],
        'suggested_fix': result.get('fix'),
        'explanation': result.get('explanation'),
        'prevention_tips': result.get('prevention', []),
        'suggested_test': result.get('test'),
        'confidence': result.get('confidence')
    }


async def auto_triage(project: str) -> dict:
    """Automatically triage new issues."""
    # Get unresolved issues
    issues = mcp.execute_tool('get_issues', {
        'project': project,
        'status': 'unresolved'
    })

    triaged = []

    for issue in issues.get('issues', [])[:20]:  # Process top 20
        # AI triage
        result = mcp.execute_tool('ai_classify', {
            'type': 'issue_triage',
            'issue': issue,
            'determine': ['priority', 'category', 'assignee', 'action']
        })

        # Update issue
        if result.get('priority') in ['critical', 'high']:
            mcp.execute_tool('update_issue', {
                'issue_id': issue['id'],
                'assignee': result.get('assignee')
            })

        triaged.append({
            'id': issue['id'],
            'title': issue['title'],
            'priority': result.get('priority'),
            'category': result.get('category'),
            'recommended_action': result.get('action')
        })

    return {
        'project': project,
        'triaged': len(triaged),
        'issues': triaged
    }


async def detect_regression(project: str) -> dict:
    """Detect regressions in recent releases."""
    # Get releases
    releases = mcp.execute_tool('get_releases', {'project': project})

    if not releases.get('releases'):
        return {'error': 'No releases found'}

    latest = releases['releases'][0]
    previous = releases['releases'][1] if len(releases['releases']) > 1 else None

    # Get issues for comparison
    latest_issues = mcp.execute_tool('get_issues', {
        'project': project,
        'query': f'release:{latest["version"]}'
    })

    # AI analysis
    result = mcp.execute_tool('ai_analyze', {
        'type': 'regression_detection',
        'latest_release': latest,
        'previous_release': previous,
        'new_issues': latest_issues.get('issues', [])
    })

    return {
        'release': latest['version'],
        'regressions_detected': result.get('regressions', []),
        'new_error_types': result.get('new_types', []),
        'increased_frequency': result.get('increased', []),
        'recommendations': result.get('recommendations', [])
    }
```

## Error Patterns

Identify error patterns:

```python
# pattern_detection.py
from gantz import MCPClient

mcp = MCPClient()


async def find_patterns(project: str, timeframe: str = '7d') -> dict:
    """Find error patterns across issues."""
    # Get recent issues
    issues = mcp.execute_tool('get_issues', {
        'project': project,
        'query': f'lastSeen:-{timeframe}'
    })

    # Get details for top issues
    issue_details = []
    for issue in issues.get('issues', [])[:50]:
        details = mcp.execute_tool('get_issue_details', {
            'issue_id': issue['id']
        })
        issue_details.append(details)

    # AI pattern detection
    result = mcp.execute_tool('ai_analyze', {
        'type': 'error_patterns',
        'issues': issue_details,
        'detect': ['common_causes', 'related_errors', 'trends', 'hotspots']
    })

    return {
        'project': project,
        'timeframe': timeframe,
        'issues_analyzed': len(issue_details),
        'common_causes': result.get('common_causes', []),
        'error_clusters': result.get('clusters', []),
        'code_hotspots': result.get('hotspots', []),
        'trends': result.get('trends', []),
        'recommendations': result.get('recommendations', [])
    }
```

## Deploy with Gantz CLI

Deploy your error tracking automation:

```bash
# Install Gantz
npm install -g gantz

# Initialize Sentry project
gantz init --template sentry-error-tracking

# Set environment variables
export SENTRY_AUTH_TOKEN=your-auth-token
export SENTRY_ORG=your-org

# Deploy
gantz deploy --platform railway

# Analyze issue
gantz run analyze_issue --issue-id 123456

# Get fix suggestions
gantz run suggest_fix --issue-id 123456

# Auto-triage issues
gantz run auto_triage --project my-project
```

Build intelligent error tracking at [gantz.run](https://gantz.run).

## Related Reading

- [Datadog MCP Integration](/post/datadog-mcp-integration/) - Full observability
- [PagerDuty MCP Integration](/post/pagerduty-mcp-integration/) - Incident response
- [MCP Debugging](/post/mcp-debugging/) - Debug MCP tools

## Conclusion

Sentry and MCP create powerful AI-driven error tracking systems. With intelligent analysis, auto-triage, and fix suggestions, you can dramatically reduce debugging time and improve code quality.

Start building Sentry AI agents with Gantz today.
