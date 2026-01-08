+++
title = "Linear MCP Integration: AI-Powered Modern Issue Tracking"
image = "images/linear-mcp-integration.webp"
date = 2025-06-07
description = "Build intelligent issue tracking agents with Linear and MCP. Learn cycle automation, roadmap planning, and AI-driven development workflows with Gantz."
draft = false
tags = ['linear', 'issue-tracking', 'productivity', 'mcp', 'automation', 'gantz']
voice = false
summary = "Build AI agents for Linear that auto-triage issues with priority and estimate suggestions, plan cycles based on team capacity, analyze sprint health with completion forecasts, prioritize backlogs by impact and effort, and detect duplicate or related issues for auto-linking. Includes GraphQL handlers and roadmap forecasting for modern development teams."

[howto]
name = "How To Build AI Issue Tracking with Linear and MCP"
totalTime = 30
[[howto.steps]]
name = "Set up Linear API"
text = "Configure Linear API key"
[[howto.steps]]
name = "Define MCP tools"
text = "Create tool definitions for issue operations"
[[howto.steps]]
name = "Implement handlers"
text = "Build handlers for issues, cycles, and projects"
[[howto.steps]]
name = "Add AI capabilities"
text = "Integrate AI-powered triage and planning"
[[howto.steps]]
name = "Deploy with Gantz"
text = "Deploy your issue automation using Gantz CLI"
+++

Linear is the modern issue tracking tool built for high-performance teams. With MCP integration, you can build AI agents that automate workflows, optimize cycles, and provide intelligent development insights.

## Why Linear MCP Integration?

AI-powered Linear enables:

- **Smart triage**: Intelligent issue classification
- **Cycle optimization**: AI-driven sprint planning
- **Priority intelligence**: ML-based prioritization
- **Roadmap insights**: Predictive planning
- **Auto-linking**: Intelligent issue relationships

## Linear MCP Tool Definition

Configure Linear tools in Gantz:

```yaml
# gantz.yaml
name: linear-mcp-tools
version: 1.0.0

tools:
  search_issues:
    description: "Search issues"
    parameters:
      query:
        type: string
      team_id:
        type: string
      state:
        type: string
    handler: linear.search_issues

  get_issue:
    description: "Get issue by ID"
    parameters:
      issue_id:
        type: string
        required: true
    handler: linear.get_issue

  create_issue:
    description: "Create new issue"
    parameters:
      title:
        type: string
        required: true
      team_id:
        type: string
        required: true
      description:
        type: string
      priority:
        type: integer
      state_id:
        type: string
    handler: linear.create_issue

  update_issue:
    description: "Update issue"
    parameters:
      issue_id:
        type: string
        required: true
      data:
        type: object
        required: true
    handler: linear.update_issue

  get_cycle:
    description: "Get cycle details"
    parameters:
      cycle_id:
        type: string
        required: true
    handler: linear.get_cycle

  get_team:
    description: "Get team details"
    parameters:
      team_id:
        type: string
        required: true
    handler: linear.get_team

  triage_issue:
    description: "AI triage issue"
    parameters:
      issue_id:
        type: string
        required: true
    handler: linear.triage_issue
```

## Handler Implementation

Build Linear operation handlers:

```python
# handlers/linear.py
import httpx
import os

LINEAR_API = "https://api.linear.app/graphql"
API_KEY = os.environ['LINEAR_API_KEY']


def get_headers():
    """Get authorization headers."""
    return {
        "Authorization": API_KEY,
        "Content-Type": "application/json"
    }


async def graphql_request(query: str, variables: dict = None) -> dict:
    """Make Linear GraphQL request."""
    async with httpx.AsyncClient() as client:
        response = await client.post(
            LINEAR_API,
            json={'query': query, 'variables': variables or {}},
            headers=get_headers(),
            timeout=30.0
        )

        result = response.json()

        if result.get('errors'):
            return {'error': result['errors'][0].get('message')}

        return result.get('data', {})


async def search_issues(query: str = None, team_id: str = None,
                       state: str = None) -> dict:
    """Search issues."""
    try:
        filters = []
        if team_id:
            filters.append(f'team: {{ id: {{ eq: "{team_id}" }} }}')
        if state:
            filters.append(f'state: {{ name: {{ eq: "{state}" }} }}')

        filter_str = ', '.join(filters) if filters else ''

        gql = f"""
        query {{
            issues(filter: {{ {filter_str} }}, first: 50) {{
                nodes {{
                    id
                    identifier
                    title
                    description
                    priority
                    state {{ name }}
                    assignee {{ name }}
                    createdAt
                    updatedAt
                }}
            }}
        }}
        """

        result = await graphql_request(gql)

        if 'error' in result:
            return result

        issues = result.get('issues', {}).get('nodes', [])

        return {
            'count': len(issues),
            'issues': [{
                'id': i.get('id'),
                'identifier': i.get('identifier'),
                'title': i.get('title'),
                'description': i.get('description'),
                'priority': i.get('priority'),
                'state': i.get('state', {}).get('name'),
                'assignee': i.get('assignee', {}).get('name') if i.get('assignee') else None,
                'created_at': i.get('createdAt')
            } for i in issues]
        }

    except Exception as e:
        return {'error': f'Search failed: {str(e)}'}


async def get_issue(issue_id: str) -> dict:
    """Get issue by ID."""
    try:
        gql = """
        query($id: String!) {
            issue(id: $id) {
                id
                identifier
                title
                description
                priority
                estimate
                state { name }
                assignee { name email }
                labels { nodes { name } }
                project { name }
                cycle { name number }
                createdAt
                updatedAt
                comments { nodes { body user { name } } }
            }
        }
        """

        result = await graphql_request(gql, {'id': issue_id})

        if 'error' in result:
            return result

        issue = result.get('issue', {})

        return {
            'id': issue.get('id'),
            'identifier': issue.get('identifier'),
            'title': issue.get('title'),
            'description': issue.get('description'),
            'priority': issue.get('priority'),
            'estimate': issue.get('estimate'),
            'state': issue.get('state', {}).get('name'),
            'assignee': issue.get('assignee', {}).get('name') if issue.get('assignee') else None,
            'labels': [l.get('name') for l in issue.get('labels', {}).get('nodes', [])],
            'project': issue.get('project', {}).get('name') if issue.get('project') else None,
            'cycle': issue.get('cycle', {}).get('name') if issue.get('cycle') else None,
            'created_at': issue.get('createdAt'),
            'comments': [{
                'body': c.get('body'),
                'author': c.get('user', {}).get('name')
            } for c in issue.get('comments', {}).get('nodes', [])]
        }

    except Exception as e:
        return {'error': f'Failed to get issue: {str(e)}'}


async def create_issue(title: str, team_id: str, description: str = None,
                      priority: int = None, state_id: str = None) -> dict:
    """Create new issue."""
    try:
        gql = """
        mutation($input: IssueCreateInput!) {
            issueCreate(input: $input) {
                success
                issue {
                    id
                    identifier
                    title
                }
            }
        }
        """

        input_data = {
            'title': title,
            'teamId': team_id
        }

        if description:
            input_data['description'] = description
        if priority is not None:
            input_data['priority'] = priority
        if state_id:
            input_data['stateId'] = state_id

        result = await graphql_request(gql, {'input': input_data})

        if 'error' in result:
            return result

        issue = result.get('issueCreate', {}).get('issue', {})

        return {
            'id': issue.get('id'),
            'identifier': issue.get('identifier'),
            'created': True,
            'title': title
        }

    except Exception as e:
        return {'error': f'Failed to create issue: {str(e)}'}


async def update_issue(issue_id: str, data: dict) -> dict:
    """Update issue."""
    try:
        gql = """
        mutation($id: String!, $input: IssueUpdateInput!) {
            issueUpdate(id: $id, input: $input) {
                success
                issue {
                    id
                    identifier
                }
            }
        }
        """

        result = await graphql_request(gql, {'id': issue_id, 'input': data})

        if 'error' in result:
            return result

        return {
            'id': issue_id,
            'updated': result.get('issueUpdate', {}).get('success', False)
        }

    except Exception as e:
        return {'error': f'Failed to update issue: {str(e)}'}


async def get_cycle(cycle_id: str) -> dict:
    """Get cycle details."""
    try:
        gql = """
        query($id: String!) {
            cycle(id: $id) {
                id
                name
                number
                startsAt
                endsAt
                progress
                issues { nodes { id identifier title state { name } } }
            }
        }
        """

        result = await graphql_request(gql, {'id': cycle_id})

        if 'error' in result:
            return result

        cycle = result.get('cycle', {})

        return {
            'id': cycle.get('id'),
            'name': cycle.get('name'),
            'number': cycle.get('number'),
            'starts_at': cycle.get('startsAt'),
            'ends_at': cycle.get('endsAt'),
            'progress': cycle.get('progress'),
            'issues': [{
                'id': i.get('id'),
                'identifier': i.get('identifier'),
                'title': i.get('title'),
                'state': i.get('state', {}).get('name')
            } for i in cycle.get('issues', {}).get('nodes', [])]
        }

    except Exception as e:
        return {'error': f'Failed to get cycle: {str(e)}'}


async def get_team(team_id: str) -> dict:
    """Get team details."""
    try:
        gql = """
        query($id: String!) {
            team(id: $id) {
                id
                name
                key
                members { nodes { name email } }
                states { nodes { id name } }
                activeCycle { id name number }
            }
        }
        """

        result = await graphql_request(gql, {'id': team_id})

        if 'error' in result:
            return result

        team = result.get('team', {})

        return {
            'id': team.get('id'),
            'name': team.get('name'),
            'key': team.get('key'),
            'members': [m.get('name') for m in team.get('members', {}).get('nodes', [])],
            'states': [{
                'id': s.get('id'),
                'name': s.get('name')
            } for s in team.get('states', {}).get('nodes', [])],
            'active_cycle': team.get('activeCycle', {}).get('name') if team.get('activeCycle') else None
        }

    except Exception as e:
        return {'error': f'Failed to get team: {str(e)}'}
```

## AI-Powered Issue Intelligence

Build intelligent issue tracking:

```python
# linear_ai.py
from gantz import MCPClient

mcp = MCPClient(config_path='gantz.yaml')


async def triage_issue(issue_id: str) -> dict:
    """AI triage issue."""
    issue = mcp.execute_tool('get_issue', {'issue_id': issue_id})

    if 'error' in issue:
        return issue

    # AI triage
    result = mcp.execute_tool('ai_classify', {
        'type': 'issue_triage',
        'issue': issue,
        'determine': ['priority', 'estimate', 'labels', 'assignee']
    })

    # Update issue
    update_data = {}
    if result.get('priority'):
        update_data['priority'] = result.get('priority')
    if result.get('estimate'):
        update_data['estimate'] = result.get('estimate')

    if update_data:
        mcp.execute_tool('update_issue', {
            'issue_id': issue_id,
            'data': update_data
        })

    return {
        'issue_id': issue_id,
        'identifier': issue.get('identifier'),
        'triage_result': {
            'priority': result.get('priority'),
            'estimate': result.get('estimate'),
            'suggested_labels': result.get('labels', []),
            'suggested_assignee': result.get('assignee')
        },
        'confidence': result.get('confidence')
    }


async def plan_cycle(team_id: str, capacity: int) -> dict:
    """AI cycle planning."""
    # Get backlog
    issues = mcp.execute_tool('search_issues', {
        'team_id': team_id,
        'state': 'Backlog'
    })

    # AI planning
    result = mcp.execute_tool('ai_plan', {
        'type': 'cycle',
        'issues': issues.get('issues', []),
        'capacity': capacity,
        'optimize_for': ['priority', 'dependencies', 'balance']
    })

    return {
        'team_id': team_id,
        'capacity': capacity,
        'recommended_issues': result.get('selected', []),
        'total_estimate': result.get('total_estimate'),
        'utilization': result.get('utilization'),
        'balance': result.get('balance')
    }


async def analyze_cycle(cycle_id: str) -> dict:
    """AI cycle analysis."""
    cycle = mcp.execute_tool('get_cycle', {'cycle_id': cycle_id})

    if 'error' in cycle:
        return cycle

    # AI analysis
    result = mcp.execute_tool('ai_analyze', {
        'type': 'cycle_analysis',
        'cycle': cycle,
        'analyze': ['progress', 'velocity', 'risks', 'forecast']
    })

    return {
        'cycle_id': cycle_id,
        'cycle_name': cycle.get('name'),
        'progress': cycle.get('progress'),
        'health_score': result.get('health_score'),
        'on_track': result.get('on_track'),
        'risks': result.get('risks', []),
        'forecast': result.get('forecast'),
        'recommendations': result.get('recommendations', [])
    }


async def prioritize_backlog(team_id: str) -> dict:
    """AI backlog prioritization."""
    issues = mcp.execute_tool('search_issues', {
        'team_id': team_id,
        'state': 'Backlog'
    })

    result = mcp.execute_tool('ai_analyze', {
        'type': 'backlog_prioritization',
        'issues': issues.get('issues', []),
        'factors': ['impact', 'effort', 'urgency', 'dependencies']
    })

    return {
        'team_id': team_id,
        'prioritized': result.get('ranked_issues', []),
        'quick_wins': result.get('quick_wins', []),
        'strategic': result.get('strategic', []),
        'recommendations': result.get('recommendations', [])
    }


async def suggest_issue_links(issue_id: str, team_id: str) -> dict:
    """Suggest related issues to link."""
    issue = mcp.execute_tool('get_issue', {'issue_id': issue_id})
    all_issues = mcp.execute_tool('search_issues', {'team_id': team_id})

    result = mcp.execute_tool('ai_match', {
        'type': 'issue_similarity',
        'source': issue,
        'candidates': all_issues.get('issues', []),
        'relationship_types': ['blocks', 'blocked_by', 'related', 'duplicate']
    })

    return {
        'issue_id': issue_id,
        'suggested_links': result.get('matches', []),
        'duplicates': result.get('duplicates', []),
        'related': result.get('related', [])
    }
```

## Roadmap Intelligence

AI-powered roadmap planning:

```python
# roadmap_ai.py
from gantz import MCPClient

mcp = MCPClient()


async def forecast_roadmap(team_id: str, timeframe: str) -> dict:
    """Forecast roadmap completion."""
    issues = mcp.execute_tool('search_issues', {'team_id': team_id})

    result = mcp.execute_tool('ai_predict', {
        'type': 'roadmap_forecast',
        'issues': issues.get('issues', []),
        'timeframe': timeframe,
        'predict': ['completion', 'risks', 'capacity_needs']
    })

    return {
        'team_id': team_id,
        'timeframe': timeframe,
        'forecast': result.get('forecast'),
        'milestones': result.get('milestones', []),
        'risks': result.get('risks', []),
        'capacity_recommendations': result.get('capacity', [])
    }


async def generate_changelog(team_id: str, period: str) -> dict:
    """Generate AI changelog."""
    issues = mcp.execute_tool('search_issues', {
        'team_id': team_id,
        'state': 'Done'
    })

    result = mcp.execute_tool('ai_generate', {
        'type': 'changelog',
        'issues': issues.get('issues', []),
        'period': period,
        'sections': ['features', 'improvements', 'fixes']
    })

    return {
        'period': period,
        'changelog': result.get('changelog'),
        'highlights': result.get('highlights', [])
    }
```

## Deploy with Gantz CLI

Deploy your issue tracking automation:

```bash
# Install Gantz
npm install -g gantz

# Initialize Linear project
gantz init --template linear-issue-tracking

# Set environment variables
export LINEAR_API_KEY=your-api-key

# Deploy
gantz deploy --platform vercel

# Triage issue
gantz run triage_issue --issue-id abc123

# Plan cycle
gantz run plan_cycle --team-id xyz789 --capacity 40

# Analyze cycle
gantz run analyze_cycle --cycle-id cycle123

# Prioritize backlog
gantz run prioritize_backlog --team-id xyz789
```

Build intelligent issue tracking at [gantz.run](https://gantz.run).

## Related Reading

- [Jira MCP Integration](/post/jira-mcp-integration/) - Enterprise issue tracking
- [Asana MCP Integration](/post/asana-mcp-integration/) - Project management
- [GitHub MCP Integration](/post/github-mcp-integration/) - Code and issues

## Conclusion

Linear and MCP create powerful AI-driven issue tracking for modern teams. With intelligent triage, cycle optimization, and roadmap insights, you can ship faster and more predictably.

Start building Linear AI agents with Gantz today.
