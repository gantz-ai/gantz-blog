+++
title = "ClickUp MCP Integration: AI-Powered Productivity Platform"
image = "/images/clickup-mcp-integration.png"
date = 2025-06-09
description = "Build intelligent productivity agents with ClickUp and MCP. Learn task automation, workspace optimization, and AI-driven workflows with Gantz."
draft = false
tags = ['clickup', 'productivity', 'tasks', 'mcp', 'automation', 'gantz']
voice = false

[howto]
name = "How To Build AI Productivity with ClickUp and MCP"
totalTime = 30
[[howto.steps]]
name = "Set up ClickUp API"
text = "Configure ClickUp API token"
[[howto.steps]]
name = "Define MCP tools"
text = "Create tool definitions for productivity operations"
[[howto.steps]]
name = "Implement handlers"
text = "Build handlers for tasks, lists, and spaces"
[[howto.steps]]
name = "Add AI capabilities"
text = "Integrate AI-powered task automation"
[[howto.steps]]
name = "Deploy with Gantz"
text = "Deploy your productivity automation using Gantz CLI"
+++

ClickUp is the all-in-one productivity platform, and with MCP integration, you can build AI agents that automate task management, optimize workflows, and provide intelligent productivity insights.

## Why ClickUp MCP Integration?

AI-powered productivity enables:

- **Smart task creation**: AI-generated tasks from descriptions
- **Auto-prioritization**: ML-based task ranking
- **Time estimation**: Intelligent effort predictions
- **Workflow optimization**: Automated process improvements
- **Goal tracking**: AI-driven progress analysis

## ClickUp MCP Tool Definition

Configure ClickUp tools in Gantz:

```yaml
# gantz.yaml
name: clickup-mcp-tools
version: 1.0.0

tools:
  get_tasks:
    description: "Get tasks from list"
    parameters:
      list_id:
        type: string
        required: true
      include_closed:
        type: boolean
        default: false
    handler: clickup.get_tasks

  get_task:
    description: "Get task by ID"
    parameters:
      task_id:
        type: string
        required: true
    handler: clickup.get_task

  create_task:
    description: "Create new task"
    parameters:
      list_id:
        type: string
        required: true
      name:
        type: string
        required: true
      description:
        type: string
      priority:
        type: integer
      due_date:
        type: integer
    handler: clickup.create_task

  update_task:
    description: "Update task"
    parameters:
      task_id:
        type: string
        required: true
      data:
        type: object
        required: true
    handler: clickup.update_task

  get_spaces:
    description: "Get workspace spaces"
    parameters:
      team_id:
        type: string
        required: true
    handler: clickup.get_spaces

  get_goals:
    description: "Get team goals"
    parameters:
      team_id:
        type: string
        required: true
    handler: clickup.get_goals

  analyze_productivity:
    description: "AI productivity analysis"
    parameters:
      list_id:
        type: string
        required: true
    handler: clickup.analyze_productivity
```

## Handler Implementation

Build ClickUp operation handlers:

```python
# handlers/clickup.py
import httpx
import os

CLICKUP_API = "https://api.clickup.com/api/v2"
API_TOKEN = os.environ['CLICKUP_API_TOKEN']


def get_headers():
    """Get authorization headers."""
    return {
        "Authorization": API_TOKEN,
        "Content-Type": "application/json"
    }


async def api_request(method: str, path: str,
                      data: dict = None, params: dict = None) -> dict:
    """Make ClickUp API request."""
    async with httpx.AsyncClient() as client:
        response = await client.request(
            method,
            f"{CLICKUP_API}{path}",
            json=data,
            params=params,
            headers=get_headers(),
            timeout=30.0
        )

        if response.status_code >= 400:
            return {'error': response.text}

        return response.json() if response.text else {'success': True}


async def get_tasks(list_id: str, include_closed: bool = False) -> dict:
    """Get tasks from list."""
    try:
        params = {'include_closed': str(include_closed).lower()}

        result = await api_request("GET", f"/list/{list_id}/task", params=params)

        if 'error' in result:
            return result

        tasks = result.get('tasks', [])

        return {
            'list_id': list_id,
            'count': len(tasks),
            'tasks': [{
                'id': t.get('id'),
                'name': t.get('name'),
                'description': t.get('description'),
                'status': t.get('status', {}).get('status'),
                'priority': t.get('priority', {}).get('priority') if t.get('priority') else None,
                'assignees': [a.get('username') for a in t.get('assignees', [])],
                'due_date': t.get('due_date'),
                'time_estimate': t.get('time_estimate'),
                'tags': [tag.get('name') for tag in t.get('tags', [])],
                'date_created': t.get('date_created'),
                'date_updated': t.get('date_updated')
            } for t in tasks]
        }

    except Exception as e:
        return {'error': f'Failed to get tasks: {str(e)}'}


async def get_task(task_id: str) -> dict:
    """Get task by ID."""
    try:
        result = await api_request("GET", f"/task/{task_id}")

        if 'error' in result:
            return result

        return {
            'id': result.get('id'),
            'name': result.get('name'),
            'description': result.get('description'),
            'status': result.get('status', {}).get('status'),
            'priority': result.get('priority', {}).get('priority') if result.get('priority') else None,
            'assignees': [a.get('username') for a in result.get('assignees', [])],
            'due_date': result.get('due_date'),
            'start_date': result.get('start_date'),
            'time_estimate': result.get('time_estimate'),
            'time_spent': result.get('time_spent'),
            'tags': [tag.get('name') for tag in result.get('tags', [])],
            'checklists': result.get('checklists', []),
            'comments_count': result.get('comments_count', 0),
            'custom_fields': result.get('custom_fields', []),
            'date_created': result.get('date_created')
        }

    except Exception as e:
        return {'error': f'Failed to get task: {str(e)}'}


async def create_task(list_id: str, name: str, description: str = None,
                     priority: int = None, due_date: int = None) -> dict:
    """Create new task."""
    try:
        task_data = {'name': name}

        if description:
            task_data['description'] = description
        if priority:
            task_data['priority'] = priority
        if due_date:
            task_data['due_date'] = due_date

        result = await api_request("POST", f"/list/{list_id}/task", task_data)

        if 'error' in result:
            return result

        return {
            'id': result.get('id'),
            'name': result.get('name'),
            'created': True
        }

    except Exception as e:
        return {'error': f'Failed to create task: {str(e)}'}


async def update_task(task_id: str, data: dict) -> dict:
    """Update task."""
    try:
        result = await api_request("PUT", f"/task/{task_id}", data)

        if 'error' in result:
            return result

        return {
            'id': task_id,
            'updated': True
        }

    except Exception as e:
        return {'error': f'Failed to update task: {str(e)}'}


async def get_spaces(team_id: str) -> dict:
    """Get workspace spaces."""
    try:
        result = await api_request("GET", f"/team/{team_id}/space")

        if 'error' in result:
            return result

        spaces = result.get('spaces', [])

        return {
            'team_id': team_id,
            'count': len(spaces),
            'spaces': [{
                'id': s.get('id'),
                'name': s.get('name'),
                'private': s.get('private'),
                'statuses': s.get('statuses', [])
            } for s in spaces]
        }

    except Exception as e:
        return {'error': f'Failed to get spaces: {str(e)}'}


async def get_goals(team_id: str) -> dict:
    """Get team goals."""
    try:
        result = await api_request("GET", f"/team/{team_id}/goal")

        if 'error' in result:
            return result

        goals = result.get('goals', [])

        return {
            'team_id': team_id,
            'count': len(goals),
            'goals': [{
                'id': g.get('id'),
                'name': g.get('name'),
                'due_date': g.get('due_date'),
                'percent_completed': g.get('percent_completed'),
                'key_results': g.get('key_results', [])
            } for g in goals]
        }

    except Exception as e:
        return {'error': f'Failed to get goals: {str(e)}'}


async def add_comment(task_id: str, comment: str) -> dict:
    """Add comment to task."""
    try:
        result = await api_request(
            "POST",
            f"/task/{task_id}/comment",
            {'comment_text': comment}
        )

        if 'error' in result:
            return result

        return {
            'task_id': task_id,
            'comment_added': True
        }

    except Exception as e:
        return {'error': f'Failed to add comment: {str(e)}'}
```

## AI-Powered Productivity

Build intelligent task automation:

```python
# clickup_ai.py
from gantz import MCPClient

mcp = MCPClient(config_path='gantz.yaml')


async def analyze_productivity(list_id: str) -> dict:
    """AI productivity analysis."""
    tasks = mcp.execute_tool('get_tasks', {
        'list_id': list_id,
        'include_closed': True
    })

    if 'error' in tasks:
        return tasks

    # AI analysis
    result = mcp.execute_tool('ai_analyze', {
        'type': 'productivity_analysis',
        'tasks': tasks.get('tasks', []),
        'analyze': ['velocity', 'bottlenecks', 'estimation_accuracy', 'patterns']
    })

    return {
        'list_id': list_id,
        'tasks_analyzed': tasks.get('count'),
        'velocity': result.get('velocity'),
        'completion_rate': result.get('completion_rate'),
        'avg_cycle_time': result.get('cycle_time'),
        'estimation_accuracy': result.get('estimation_accuracy'),
        'bottlenecks': result.get('bottlenecks', []),
        'patterns': result.get('patterns', []),
        'recommendations': result.get('recommendations', [])
    }


async def smart_create_tasks(description: str, list_id: str) -> dict:
    """AI-generate tasks from description."""
    # AI task generation
    result = mcp.execute_tool('ai_generate', {
        'type': 'task_breakdown',
        'description': description,
        'include': ['tasks', 'estimates', 'priorities', 'dependencies']
    })

    created_tasks = []
    for task in result.get('tasks', []):
        new_task = mcp.execute_tool('create_task', {
            'list_id': list_id,
            'name': task.get('name'),
            'description': task.get('description'),
            'priority': task.get('priority'),
            'due_date': task.get('due_date')
        })

        if new_task.get('id'):
            created_tasks.append(new_task)

    return {
        'description': description,
        'tasks_created': len(created_tasks),
        'tasks': created_tasks,
        'estimated_total': result.get('total_estimate')
    }


async def prioritize_tasks(list_id: str) -> dict:
    """AI task prioritization."""
    tasks = mcp.execute_tool('get_tasks', {'list_id': list_id})

    result = mcp.execute_tool('ai_analyze', {
        'type': 'task_prioritization',
        'tasks': tasks.get('tasks', []),
        'factors': ['urgency', 'importance', 'effort', 'dependencies']
    })

    return {
        'list_id': list_id,
        'prioritized_tasks': result.get('ranked_tasks', []),
        'quick_wins': result.get('quick_wins', []),
        'critical_path': result.get('critical_path', []),
        'recommendations': result.get('recommendations', [])
    }


async def estimate_task(task_id: str) -> dict:
    """AI task estimation."""
    task = mcp.execute_tool('get_task', {'task_id': task_id})

    if 'error' in task:
        return task

    result = mcp.execute_tool('ai_estimate', {
        'type': 'task',
        'task': task,
        'estimate': ['time', 'complexity', 'risk']
    })

    # Update task with estimate
    if result.get('time_estimate'):
        mcp.execute_tool('update_task', {
            'task_id': task_id,
            'data': {'time_estimate': result.get('time_estimate') * 60000}  # Convert to ms
        })

    return {
        'task_id': task_id,
        'estimated_hours': result.get('time_estimate'),
        'complexity': result.get('complexity'),
        'risk_level': result.get('risk'),
        'confidence': result.get('confidence'),
        'breakdown': result.get('breakdown', [])
    }


async def suggest_assignee(task_id: str, team_id: str) -> dict:
    """Suggest best assignee for task."""
    task = mcp.execute_tool('get_task', {'task_id': task_id})

    # Get team workload
    spaces = mcp.execute_tool('get_spaces', {'team_id': team_id})

    result = mcp.execute_tool('ai_match', {
        'type': 'task_assignment',
        'task': task,
        'team_id': team_id,
        'factors': ['skills', 'workload', 'availability', 'history']
    })

    return {
        'task_id': task_id,
        'suggested_assignee': result.get('assignee'),
        'reason': result.get('reason'),
        'confidence': result.get('confidence'),
        'alternatives': result.get('alternatives', [])
    }
```

## Goal Intelligence

AI-powered goal tracking:

```python
# goal_ai.py
from gantz import MCPClient

mcp = MCPClient()


async def analyze_goals(team_id: str) -> dict:
    """AI goal analysis."""
    goals = mcp.execute_tool('get_goals', {'team_id': team_id})

    result = mcp.execute_tool('ai_analyze', {
        'type': 'goal_analysis',
        'goals': goals.get('goals', []),
        'analyze': ['progress', 'risk', 'forecast']
    })

    return {
        'team_id': team_id,
        'goals_analyzed': len(goals.get('goals', [])),
        'on_track': result.get('on_track', []),
        'at_risk': result.get('at_risk', []),
        'forecast': result.get('forecast'),
        'recommendations': result.get('recommendations', [])
    }


async def suggest_key_results(goal_description: str) -> dict:
    """Suggest key results for goal."""
    result = mcp.execute_tool('ai_generate', {
        'type': 'key_results',
        'goal': goal_description,
        'count': 5,
        'include': ['metric', 'target', 'timeline']
    })

    return {
        'goal': goal_description,
        'suggested_key_results': result.get('key_results', [])
    }


async def generate_weekly_summary(team_id: str) -> dict:
    """Generate AI weekly summary."""
    goals = mcp.execute_tool('get_goals', {'team_id': team_id})
    spaces = mcp.execute_tool('get_spaces', {'team_id': team_id})

    result = mcp.execute_tool('ai_generate', {
        'type': 'weekly_summary',
        'goals': goals.get('goals', []),
        'spaces': spaces.get('spaces', []),
        'sections': ['accomplishments', 'progress', 'blockers', 'focus_areas']
    })

    return {
        'team_id': team_id,
        'summary': result.get('summary'),
        'accomplishments': result.get('accomplishments', []),
        'metrics': result.get('metrics', {}),
        'focus_areas': result.get('focus_areas', [])
    }
```

## Deploy with Gantz CLI

Deploy your productivity automation:

```bash
# Install Gantz
npm install -g gantz

# Initialize ClickUp project
gantz init --template clickup-productivity

# Set environment variables
export CLICKUP_API_TOKEN=your-api-token

# Deploy
gantz deploy --platform vercel

# Analyze productivity
gantz run analyze_productivity --list-id abc123

# Smart create tasks
gantz run smart_create_tasks \
  --description "Build user authentication system with OAuth" \
  --list-id abc123

# Prioritize tasks
gantz run prioritize_tasks --list-id abc123

# Estimate task
gantz run estimate_task --task-id xyz789
```

Build intelligent productivity at [gantz.run](https://gantz.run).

## Related Reading

- [Asana MCP Integration](/post/asana-mcp-integration/) - Project management
- [Monday MCP Integration](/post/monday-mcp-integration/) - Work management
- [Notion MCP Integration](/post/notion-mcp-integration/) - Workspace automation

## Conclusion

ClickUp and MCP create powerful AI-driven productivity systems. With intelligent task automation, smart prioritization, and goal tracking, you can transform how teams work and achieve results.

Start building ClickUp AI agents with Gantz today.
