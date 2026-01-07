+++
title = "Asana MCP Integration: AI-Powered Project Management"
image = "/images/asana-mcp-integration.png"
date = 2025-06-05
description = "Build intelligent project management agents with Asana and MCP. Learn task automation, resource planning, and AI-driven workflows with Gantz."
draft = false
tags = ['asana', 'project-management', 'tasks', 'mcp', 'automation', 'gantz']
voice = false

[howto]
name = "How To Build AI Project Management with Asana and MCP"
totalTime = 30
[[howto.steps]]
name = "Set up Asana API"
text = "Configure Asana personal access token"
[[howto.steps]]
name = "Define MCP tools"
text = "Create tool definitions for project operations"
[[howto.steps]]
name = "Implement handlers"
text = "Build handlers for tasks, projects, and portfolios"
[[howto.steps]]
name = "Add AI capabilities"
text = "Integrate AI-powered planning and automation"
[[howto.steps]]
name = "Deploy with Gantz"
text = "Deploy your project automation using Gantz CLI"
+++

Asana is the leading work management platform, and with MCP integration, you can build AI agents that automate task management, optimize resource allocation, and provide intelligent project insights.

## Why Asana MCP Integration?

AI-powered project management enables:

- **Smart planning**: AI-generated project plans
- **Auto-assignment**: Intelligent task routing
- **Progress prediction**: ML-based timeline forecasting
- **Workload balancing**: Automated resource optimization
- **Status summaries**: AI-generated reports

## Asana MCP Tool Definition

Configure Asana tools in Gantz:

```yaml
# gantz.yaml
name: asana-mcp-tools
version: 1.0.0

tools:
  get_tasks:
    description: "Get tasks from project"
    parameters:
      project_id:
        type: string
        required: true
      completed:
        type: boolean
    handler: asana.get_tasks

  create_task:
    description: "Create new task"
    parameters:
      name:
        type: string
        required: true
      project_id:
        type: string
        required: true
      assignee:
        type: string
      due_on:
        type: string
      notes:
        type: string
    handler: asana.create_task

  update_task:
    description: "Update task"
    parameters:
      task_id:
        type: string
        required: true
      data:
        type: object
        required: true
    handler: asana.update_task

  get_project:
    description: "Get project details"
    parameters:
      project_id:
        type: string
        required: true
    handler: asana.get_project

  get_workload:
    description: "Get team workload"
    parameters:
      team_id:
        type: string
        required: true
    handler: asana.get_workload

  generate_project_plan:
    description: "AI generate project plan"
    parameters:
      description:
        type: string
        required: true
      project_id:
        type: string
    handler: asana.generate_project_plan
```

## Handler Implementation

Build Asana operation handlers:

```python
# handlers/asana.py
import httpx
import os

ASANA_API = "https://app.asana.com/api/1.0"
ACCESS_TOKEN = os.environ['ASANA_ACCESS_TOKEN']


def get_headers():
    """Get authorization headers."""
    return {
        "Authorization": f"Bearer {ACCESS_TOKEN}",
        "Content-Type": "application/json"
    }


async def api_request(method: str, path: str,
                      data: dict = None, params: dict = None) -> dict:
    """Make Asana API request."""
    async with httpx.AsyncClient() as client:
        response = await client.request(
            method,
            f"{ASANA_API}{path}",
            json={'data': data} if data else None,
            params=params,
            headers=get_headers(),
            timeout=30.0
        )

        result = response.json()

        if result.get('errors'):
            return {'error': result['errors'][0].get('message')}

        return result.get('data', {})


async def get_tasks(project_id: str, completed: bool = None) -> dict:
    """Get tasks from project."""
    try:
        params = {
            'project': project_id,
            'opt_fields': 'name,completed,due_on,assignee.name,notes,custom_fields'
        }

        if completed is not None:
            params['completed_since'] = 'now' if not completed else None

        result = await api_request("GET", "/tasks", params=params)

        if 'error' in result:
            return result

        tasks = result if isinstance(result, list) else []

        return {
            'project_id': project_id,
            'count': len(tasks),
            'tasks': [{
                'id': t.get('gid'),
                'name': t.get('name'),
                'completed': t.get('completed'),
                'due_on': t.get('due_on'),
                'assignee': t.get('assignee', {}).get('name') if t.get('assignee') else None,
                'notes': t.get('notes')
            } for t in tasks]
        }

    except Exception as e:
        return {'error': f'Failed to get tasks: {str(e)}'}


async def create_task(name: str, project_id: str, assignee: str = None,
                     due_on: str = None, notes: str = None) -> dict:
    """Create new task."""
    try:
        task_data = {
            'name': name,
            'projects': [project_id]
        }

        if assignee:
            task_data['assignee'] = assignee
        if due_on:
            task_data['due_on'] = due_on
        if notes:
            task_data['notes'] = notes

        result = await api_request("POST", "/tasks", task_data)

        if 'error' in result:
            return result

        return {
            'id': result.get('gid'),
            'created': True,
            'name': name
        }

    except Exception as e:
        return {'error': f'Failed to create task: {str(e)}'}


async def update_task(task_id: str, data: dict) -> dict:
    """Update task."""
    try:
        result = await api_request("PUT", f"/tasks/{task_id}", data)

        if 'error' in result:
            return result

        return {
            'id': task_id,
            'updated': True
        }

    except Exception as e:
        return {'error': f'Failed to update task: {str(e)}'}


async def get_project(project_id: str) -> dict:
    """Get project details."""
    try:
        result = await api_request(
            "GET",
            f"/projects/{project_id}",
            params={'opt_fields': 'name,notes,due_on,start_on,owner.name,team.name,custom_fields'}
        )

        if 'error' in result:
            return result

        return {
            'id': result.get('gid'),
            'name': result.get('name'),
            'notes': result.get('notes'),
            'start_on': result.get('start_on'),
            'due_on': result.get('due_on'),
            'owner': result.get('owner', {}).get('name') if result.get('owner') else None,
            'team': result.get('team', {}).get('name') if result.get('team') else None
        }

    except Exception as e:
        return {'error': f'Failed to get project: {str(e)}'}


async def get_workload(team_id: str) -> dict:
    """Get team workload."""
    try:
        # Get team members
        members = await api_request(
            "GET",
            f"/teams/{team_id}/users",
            params={'opt_fields': 'name,email'}
        )

        workload = []
        for member in members if isinstance(members, list) else []:
            # Get member's tasks
            tasks = await api_request(
                "GET",
                "/tasks",
                params={
                    'assignee': member.get('gid'),
                    'completed_since': 'now',
                    'opt_fields': 'name,due_on'
                }
            )

            task_list = tasks if isinstance(tasks, list) else []

            workload.append({
                'user_id': member.get('gid'),
                'name': member.get('name'),
                'task_count': len(task_list),
                'tasks': task_list[:10]
            })

        return {
            'team_id': team_id,
            'members': len(workload),
            'workload': workload
        }

    except Exception as e:
        return {'error': f'Failed to get workload: {str(e)}'}


async def add_subtask(parent_task_id: str, name: str) -> dict:
    """Add subtask to task."""
    try:
        result = await api_request(
            "POST",
            f"/tasks/{parent_task_id}/subtasks",
            {'name': name}
        )

        if 'error' in result:
            return result

        return {
            'id': result.get('gid'),
            'created': True,
            'parent_id': parent_task_id
        }

    except Exception as e:
        return {'error': f'Failed to add subtask: {str(e)}'}
```

## AI-Powered Project Intelligence

Build intelligent project automation:

```python
# asana_ai.py
from gantz import MCPClient

mcp = MCPClient(config_path='gantz.yaml')


async def generate_project_plan(description: str, project_id: str = None) -> dict:
    """AI generate project plan."""
    # AI planning
    result = mcp.execute_tool('ai_generate', {
        'type': 'project_plan',
        'description': description,
        'include': ['milestones', 'tasks', 'dependencies', 'timeline']
    })

    created_tasks = []

    if project_id:
        # Create tasks in Asana
        for task in result.get('tasks', []):
            new_task = mcp.execute_tool('create_task', {
                'name': task.get('name'),
                'project_id': project_id,
                'due_on': task.get('due_date'),
                'notes': task.get('description')
            })

            if new_task.get('id'):
                created_tasks.append(new_task)

                # Add subtasks
                for subtask in task.get('subtasks', []):
                    await add_subtask(new_task['id'], subtask.get('name'))

    return {
        'description': description,
        'project_id': project_id,
        'milestones': result.get('milestones', []),
        'tasks_planned': len(result.get('tasks', [])),
        'tasks_created': len(created_tasks),
        'timeline': result.get('timeline')
    }


async def analyze_project_health(project_id: str) -> dict:
    """AI analysis of project health."""
    project = mcp.execute_tool('get_project', {'project_id': project_id})
    tasks = mcp.execute_tool('get_tasks', {'project_id': project_id})

    if 'error' in project:
        return project

    # AI analysis
    result = mcp.execute_tool('ai_analyze', {
        'type': 'project_health',
        'project': project,
        'tasks': tasks.get('tasks', []),
        'analyze': ['progress', 'risks', 'blockers', 'forecast']
    })

    return {
        'project_id': project_id,
        'project_name': project.get('name'),
        'health_score': result.get('score'),
        'progress': result.get('progress'),
        'on_track': result.get('on_track'),
        'risks': result.get('risks', []),
        'blockers': result.get('blockers', []),
        'forecast': result.get('forecast'),
        'recommendations': result.get('recommendations', [])
    }


async def optimize_workload(team_id: str) -> dict:
    """Optimize team workload."""
    workload = mcp.execute_tool('get_workload', {'team_id': team_id})

    if 'error' in workload:
        return workload

    # AI optimization
    result = mcp.execute_tool('ai_analyze', {
        'type': 'workload_optimization',
        'workload': workload.get('workload', []),
        'optimize_for': ['balance', 'skills', 'deadlines']
    })

    return {
        'team_id': team_id,
        'current_distribution': workload.get('workload'),
        'recommendations': result.get('recommendations', []),
        'reassignments': result.get('reassignments', []),
        'overloaded_members': result.get('overloaded', []),
        'underutilized_members': result.get('underutilized', [])
    }


async def auto_assign_task(task_id: str, team_id: str) -> dict:
    """Auto-assign task to best team member."""
    # Get task details
    task = await api_request("GET", f"/tasks/{task_id}")
    workload = mcp.execute_tool('get_workload', {'team_id': team_id})

    # AI assignment
    result = mcp.execute_tool('ai_match', {
        'type': 'task_assignment',
        'task': task,
        'team_workload': workload.get('workload', []),
        'factors': ['skills', 'availability', 'history']
    })

    # Assign task
    if result.get('assignee'):
        mcp.execute_tool('update_task', {
            'task_id': task_id,
            'data': {'assignee': result.get('assignee')}
        })

    return {
        'task_id': task_id,
        'assigned_to': result.get('assignee_name'),
        'reason': result.get('reason'),
        'confidence': result.get('confidence')
    }


async def generate_status_report(project_id: str) -> dict:
    """Generate AI status report."""
    project = mcp.execute_tool('get_project', {'project_id': project_id})
    tasks = mcp.execute_tool('get_tasks', {'project_id': project_id})

    result = mcp.execute_tool('ai_generate', {
        'type': 'status_report',
        'project': project,
        'tasks': tasks.get('tasks', []),
        'sections': ['summary', 'completed', 'in_progress', 'upcoming', 'risks']
    })

    return {
        'project_id': project_id,
        'project_name': project.get('name'),
        'report': result.get('report'),
        'summary': result.get('summary'),
        'metrics': result.get('metrics', {})
    }
```

## Task Intelligence

Smart task management:

```python
# task_ai.py
from gantz import MCPClient

mcp = MCPClient()


async def prioritize_tasks(project_id: str) -> dict:
    """AI task prioritization."""
    tasks = mcp.execute_tool('get_tasks', {
        'project_id': project_id,
        'completed': False
    })

    result = mcp.execute_tool('ai_analyze', {
        'type': 'task_prioritization',
        'tasks': tasks.get('tasks', []),
        'factors': ['urgency', 'importance', 'dependencies', 'effort']
    })

    return {
        'project_id': project_id,
        'prioritized_tasks': result.get('ranked_tasks', []),
        'recommended_order': result.get('execution_order', []),
        'quick_wins': result.get('quick_wins', [])
    }


async def estimate_task(task_description: str) -> dict:
    """AI task estimation."""
    result = mcp.execute_tool('ai_estimate', {
        'type': 'task',
        'description': task_description,
        'estimate': ['effort', 'duration', 'complexity']
    })

    return {
        'description': task_description,
        'estimated_hours': result.get('hours'),
        'complexity': result.get('complexity'),
        'confidence': result.get('confidence'),
        'breakdown': result.get('breakdown', [])
    }


async def suggest_task_breakdown(task_id: str) -> dict:
    """Suggest task breakdown into subtasks."""
    task = await api_request("GET", f"/tasks/{task_id}")

    result = mcp.execute_tool('ai_generate', {
        'type': 'task_breakdown',
        'task': task,
        'max_subtasks': 10
    })

    return {
        'task_id': task_id,
        'task_name': task.get('name'),
        'suggested_subtasks': result.get('subtasks', []),
        'estimated_total_effort': result.get('total_effort')
    }
```

## Deploy with Gantz CLI

Deploy your project automation:

```bash
# Install Gantz
npm install -g gantz

# Initialize Asana project
gantz init --template asana-project-management

# Set environment variables
export ASANA_ACCESS_TOKEN=your-access-token

# Deploy
gantz deploy --platform railway

# Generate project plan
gantz run generate_project_plan \
  --description "Launch new marketing website with CMS" \
  --project-id 1234567890

# Analyze project health
gantz run analyze_project_health --project-id 1234567890

# Optimize workload
gantz run optimize_workload --team-id 9876543210

# Generate status report
gantz run generate_status_report --project-id 1234567890
```

Build intelligent project management at [gantz.run](https://gantz.run).

## Related Reading

- [Jira MCP Integration](/post/jira-mcp-integration/) - Issue tracking
- [Linear MCP Integration](/post/linear-mcp-integration/) - Modern issue tracking
- [Notion MCP Integration](/post/notion-mcp-integration/) - Workspace automation

## Conclusion

Asana and MCP create powerful AI-driven project management. With intelligent planning, automated assignments, and workload optimization, you can deliver projects more efficiently and keep teams aligned.

Start building Asana AI agents with Gantz today.
