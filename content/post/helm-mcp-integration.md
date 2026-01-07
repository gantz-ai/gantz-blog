+++
title = "Helm MCP Integration: AI-Powered Kubernetes Package Management"
image = "/images/helm-mcp-integration.png"
date = 2025-05-30
description = "Build intelligent Helm automation with MCP. Learn chart management, release operations, and AI-driven deployments with Gantz."
draft = false
tags = ['helm', 'kubernetes', 'package-management', 'mcp', 'devops', 'gantz']
voice = false

[howto]
name = "How To Build AI Helm Automation with MCP"
totalTime = 30
[[howto.steps]]
name = "Set up Helm"
text = "Configure Helm CLI and repositories"
[[howto.steps]]
name = "Define MCP tools"
text = "Create tool definitions for chart operations"
[[howto.steps]]
name = "Implement handlers"
text = "Build handlers for releases, charts, and repos"
[[howto.steps]]
name = "Add AI capabilities"
text = "Integrate AI-powered chart generation and analysis"
[[howto.steps]]
name = "Deploy with Gantz"
text = "Deploy your Helm automation using Gantz CLI"
+++

Helm is the package manager for Kubernetes, and with MCP integration, you can build AI agents that manage charts, automate releases, and optimize deployments with intelligent configuration.

## Why Helm MCP Integration?

AI-powered Helm enables:

- **Chart generation**: Natural language to Helm charts
- **Smart upgrades**: AI-optimized release strategies
- **Value optimization**: Intelligent configuration tuning
- **Dependency management**: Automated chart dependencies
- **Release intelligence**: AI-driven rollback decisions

## Helm MCP Tool Definition

Configure Helm tools in Gantz:

```yaml
# gantz.yaml
name: helm-mcp-tools
version: 1.0.0

tools:
  install:
    description: "Install Helm chart"
    parameters:
      release:
        type: string
        required: true
      chart:
        type: string
        required: true
      namespace:
        type: string
        default: "default"
      values:
        type: object
      version:
        type: string
    handler: helm.install

  upgrade:
    description: "Upgrade Helm release"
    parameters:
      release:
        type: string
        required: true
      chart:
        type: string
        required: true
      namespace:
        type: string
        default: "default"
      values:
        type: object
    handler: helm.upgrade

  uninstall:
    description: "Uninstall Helm release"
    parameters:
      release:
        type: string
        required: true
      namespace:
        type: string
        default: "default"
    handler: helm.uninstall

  list_releases:
    description: "List Helm releases"
    parameters:
      namespace:
        type: string
      all_namespaces:
        type: boolean
        default: false
    handler: helm.list_releases

  get_values:
    description: "Get release values"
    parameters:
      release:
        type: string
        required: true
      namespace:
        type: string
        default: "default"
    handler: helm.get_values

  rollback:
    description: "Rollback release"
    parameters:
      release:
        type: string
        required: true
      revision:
        type: integer
      namespace:
        type: string
        default: "default"
    handler: helm.rollback

  search_charts:
    description: "Search for charts"
    parameters:
      keyword:
        type: string
        required: true
      repo:
        type: string
    handler: helm.search_charts

  generate_chart:
    description: "AI-generate Helm chart"
    parameters:
      description:
        type: string
        required: true
      name:
        type: string
        required: true
    handler: helm.generate_chart
```

## Handler Implementation

Build Helm operation handlers:

```python
# handlers/helm.py
import subprocess
import json
import yaml
import os
from pathlib import Path


async def run_helm(args: list) -> dict:
    """Execute Helm command."""
    try:
        result = subprocess.run(
            ['helm'] + args,
            capture_output=True,
            text=True,
            timeout=300
        )

        return {
            'success': result.returncode == 0,
            'stdout': result.stdout,
            'stderr': result.stderr,
            'return_code': result.returncode
        }

    except subprocess.TimeoutExpired:
        return {'error': 'Command timed out'}
    except Exception as e:
        return {'error': str(e)}


async def install(release: str, chart: str, namespace: str = "default",
                 values: dict = None, version: str = None) -> dict:
    """Install Helm chart."""
    try:
        args = [
            'install', release, chart,
            '--namespace', namespace,
            '--create-namespace',
            '-o', 'json'
        ]

        if version:
            args.extend(['--version', version])

        if values:
            # Write values to temp file
            values_file = f'/tmp/helm-values-{release}.yaml'
            with open(values_file, 'w') as f:
                yaml.dump(values, f)
            args.extend(['-f', values_file])

        result = await run_helm(args)

        if not result.get('success'):
            return {'error': result.get('stderr', 'Install failed')}

        release_info = json.loads(result.get('stdout', '{}'))

        return {
            'release': release,
            'chart': chart,
            'namespace': namespace,
            'version': release_info.get('chart', {}).get('metadata', {}).get('version'),
            'status': release_info.get('info', {}).get('status'),
            'installed': True
        }

    except Exception as e:
        return {'error': f'Install failed: {str(e)}'}


async def upgrade(release: str, chart: str, namespace: str = "default",
                 values: dict = None) -> dict:
    """Upgrade Helm release."""
    try:
        args = [
            'upgrade', release, chart,
            '--namespace', namespace,
            '--install',
            '-o', 'json'
        ]

        if values:
            values_file = f'/tmp/helm-values-{release}.yaml'
            with open(values_file, 'w') as f:
                yaml.dump(values, f)
            args.extend(['-f', values_file])

        result = await run_helm(args)

        if not result.get('success'):
            return {'error': result.get('stderr', 'Upgrade failed')}

        release_info = json.loads(result.get('stdout', '{}'))

        return {
            'release': release,
            'chart': chart,
            'namespace': namespace,
            'revision': release_info.get('version'),
            'status': release_info.get('info', {}).get('status'),
            'upgraded': True
        }

    except Exception as e:
        return {'error': f'Upgrade failed: {str(e)}'}


async def uninstall(release: str, namespace: str = "default") -> dict:
    """Uninstall Helm release."""
    try:
        args = ['uninstall', release, '--namespace', namespace]

        result = await run_helm(args)

        if not result.get('success'):
            return {'error': result.get('stderr', 'Uninstall failed')}

        return {
            'release': release,
            'namespace': namespace,
            'uninstalled': True
        }

    except Exception as e:
        return {'error': f'Uninstall failed: {str(e)}'}


async def list_releases(namespace: str = None,
                       all_namespaces: bool = False) -> dict:
    """List Helm releases."""
    try:
        args = ['list', '-o', 'json']

        if all_namespaces:
            args.append('--all-namespaces')
        elif namespace:
            args.extend(['--namespace', namespace])

        result = await run_helm(args)

        if not result.get('success'):
            return {'error': result.get('stderr', 'List failed')}

        releases = json.loads(result.get('stdout', '[]'))

        return {
            'count': len(releases),
            'releases': [{
                'name': r.get('name'),
                'namespace': r.get('namespace'),
                'chart': r.get('chart'),
                'status': r.get('status'),
                'revision': r.get('revision'),
                'updated': r.get('updated')
            } for r in releases]
        }

    except Exception as e:
        return {'error': f'List failed: {str(e)}'}


async def get_values(release: str, namespace: str = "default") -> dict:
    """Get release values."""
    try:
        args = ['get', 'values', release, '--namespace', namespace, '-o', 'json']

        result = await run_helm(args)

        if not result.get('success'):
            return {'error': result.get('stderr', 'Get values failed')}

        values = json.loads(result.get('stdout', '{}'))

        return {
            'release': release,
            'namespace': namespace,
            'values': values
        }

    except Exception as e:
        return {'error': f'Get values failed: {str(e)}'}


async def rollback(release: str, revision: int = None,
                  namespace: str = "default") -> dict:
    """Rollback release."""
    try:
        args = ['rollback', release, '--namespace', namespace]

        if revision:
            args.append(str(revision))

        result = await run_helm(args)

        if not result.get('success'):
            return {'error': result.get('stderr', 'Rollback failed')}

        return {
            'release': release,
            'namespace': namespace,
            'revision': revision,
            'rolled_back': True
        }

    except Exception as e:
        return {'error': f'Rollback failed: {str(e)}'}


async def search_charts(keyword: str, repo: str = None) -> dict:
    """Search for charts."""
    try:
        args = ['search', 'repo', keyword, '-o', 'json']

        if repo:
            args = ['search', 'repo', f'{repo}/{keyword}', '-o', 'json']

        result = await run_helm(args)

        if not result.get('success'):
            return {'error': result.get('stderr', 'Search failed')}

        charts = json.loads(result.get('stdout', '[]'))

        return {
            'keyword': keyword,
            'count': len(charts),
            'charts': [{
                'name': c.get('name'),
                'version': c.get('version'),
                'app_version': c.get('app_version'),
                'description': c.get('description')
            } for c in charts]
        }

    except Exception as e:
        return {'error': f'Search failed: {str(e)}'}


async def get_history(release: str, namespace: str = "default") -> dict:
    """Get release history."""
    try:
        args = ['history', release, '--namespace', namespace, '-o', 'json']

        result = await run_helm(args)

        if not result.get('success'):
            return {'error': result.get('stderr', 'History failed')}

        history = json.loads(result.get('stdout', '[]'))

        return {
            'release': release,
            'namespace': namespace,
            'revisions': [{
                'revision': h.get('revision'),
                'status': h.get('status'),
                'chart': h.get('chart'),
                'updated': h.get('updated'),
                'description': h.get('description')
            } for h in history]
        }

    except Exception as e:
        return {'error': f'History failed: {str(e)}'}
```

## AI-Powered Chart Operations

Build intelligent Helm management:

```python
# helm_ai.py
from gantz import MCPClient

mcp = MCPClient(config_path='gantz.yaml')


async def generate_chart(description: str, name: str) -> dict:
    """AI-generate Helm chart."""
    # Parse requirements
    requirements = mcp.execute_tool('ai_parse', {
        'type': 'helm_requirements',
        'description': description,
        'extract': ['resources', 'config', 'dependencies', 'ingress']
    })

    # Generate chart structure
    result = mcp.execute_tool('ai_generate', {
        'type': 'helm_chart',
        'name': name,
        'requirements': requirements,
        'include': [
            'Chart.yaml',
            'values.yaml',
            'templates/deployment.yaml',
            'templates/service.yaml',
            'templates/configmap.yaml',
            'templates/ingress.yaml',
            'templates/_helpers.tpl',
            'templates/NOTES.txt'
        ]
    })

    return {
        'chart_name': name,
        'files': result.get('files', {}),
        'default_values': result.get('values'),
        'dependencies': result.get('dependencies', []),
        'notes': result.get('notes', [])
    }


async def analyze_chart(chart_path: str) -> dict:
    """AI analysis of Helm chart."""
    # Read chart files
    chart_files = {}
    chart_dir = Path(chart_path)

    for f in chart_dir.rglob('*'):
        if f.is_file() and f.suffix in ['.yaml', '.yml', '.tpl']:
            with open(f, 'r') as file:
                chart_files[str(f.relative_to(chart_dir))] = file.read()

    result = mcp.execute_tool('ai_analyze', {
        'type': 'helm_chart',
        'files': chart_files,
        'analyze': ['security', 'best_practices', 'compatibility', 'documentation']
    })

    return {
        'chart': chart_path,
        'security_issues': result.get('security', []),
        'best_practice_violations': result.get('violations', []),
        'compatibility_notes': result.get('compatibility', []),
        'documentation_score': result.get('doc_score'),
        'recommendations': result.get('recommendations', [])
    }


async def optimize_values(release: str, namespace: str) -> dict:
    """Optimize release values."""
    # Get current values
    current = mcp.execute_tool('get_values', {
        'release': release,
        'namespace': namespace
    })

    # Get resource metrics
    metrics = await get_release_metrics(release, namespace)

    # AI optimization
    result = mcp.execute_tool('ai_analyze', {
        'type': 'helm_values_optimization',
        'current_values': current.get('values'),
        'metrics': metrics,
        'optimize_for': ['performance', 'cost', 'reliability']
    })

    return {
        'release': release,
        'optimized_values': result.get('values'),
        'changes': result.get('changes', []),
        'expected_improvement': result.get('improvement'),
        'upgrade_command': result.get('command')
    }


async def smart_upgrade(release: str, chart: str, namespace: str,
                       values: dict = None) -> dict:
    """AI-optimized upgrade strategy."""
    # Get current release info
    history = await get_history(release, namespace)
    current_values = mcp.execute_tool('get_values', {
        'release': release,
        'namespace': namespace
    })

    # AI upgrade analysis
    analysis = mcp.execute_tool('ai_analyze', {
        'type': 'helm_upgrade',
        'release': release,
        'chart': chart,
        'current_values': current_values.get('values'),
        'new_values': values,
        'history': history.get('revisions', []),
        'analyze': ['risk', 'breaking_changes', 'rollback_plan']
    })

    # Perform upgrade if safe
    if analysis.get('risk_level') in ['low', 'medium']:
        result = mcp.execute_tool('upgrade', {
            'release': release,
            'chart': chart,
            'namespace': namespace,
            'values': values
        })

        return {
            'release': release,
            'upgraded': result.get('upgraded'),
            'risk_analysis': analysis.get('risks', []),
            'breaking_changes': analysis.get('breaking', []),
            'rollback_revision': history.get('revisions', [{}])[0].get('revision')
        }

    return {
        'release': release,
        'upgraded': False,
        'reason': 'High risk upgrade blocked',
        'risk_analysis': analysis.get('risks', []),
        'recommendations': analysis.get('recommendations', [])
    }


async def auto_rollback_decision(release: str, namespace: str) -> dict:
    """AI-driven rollback decision."""
    # Get release health
    health = await check_release_health(release, namespace)
    history = await get_history(release, namespace)

    # AI decision
    result = mcp.execute_tool('ai_analyze', {
        'type': 'rollback_decision',
        'release': release,
        'health': health,
        'history': history.get('revisions', []),
        'decide': ['should_rollback', 'target_revision', 'reason']
    })

    if result.get('should_rollback'):
        rollback_result = mcp.execute_tool('rollback', {
            'release': release,
            'namespace': namespace,
            'revision': result.get('target_revision')
        })

        return {
            'release': release,
            'rolled_back': rollback_result.get('rolled_back'),
            'to_revision': result.get('target_revision'),
            'reason': result.get('reason')
        }

    return {
        'release': release,
        'rolled_back': False,
        'health_status': health,
        'decision': result.get('reason')
    }
```

## Chart Templates

Generate chart templates:

```python
# chart_templates.py
from gantz import MCPClient

mcp = MCPClient()


async def generate_template(template_type: str, config: dict) -> dict:
    """Generate specific template file."""
    result = mcp.execute_tool('ai_generate', {
        'type': f'helm_template_{template_type}',
        'config': config,
        'best_practices': True
    })

    return {
        'template_type': template_type,
        'content': result.get('template'),
        'helpers_required': result.get('helpers', [])
    }


async def create_umbrella_chart(charts: list, name: str) -> dict:
    """Create umbrella chart for multiple services."""
    result = mcp.execute_tool('ai_generate', {
        'type': 'umbrella_chart',
        'name': name,
        'subcharts': charts,
        'include_global_values': True
    })

    return {
        'chart_name': name,
        'structure': result.get('structure'),
        'dependencies': result.get('dependencies'),
        'global_values': result.get('global_values')
    }


async def convert_manifests_to_chart(manifests: list, name: str) -> dict:
    """Convert raw manifests to Helm chart."""
    result = mcp.execute_tool('ai_convert', {
        'type': 'manifests_to_helm',
        'manifests': manifests,
        'chart_name': name,
        'parameterize': ['image', 'replicas', 'resources', 'env']
    })

    return {
        'chart_name': name,
        'files': result.get('files'),
        'values': result.get('values'),
        'templated_fields': result.get('templated', [])
    }
```

## Deploy with Gantz CLI

Deploy your Helm automation:

```bash
# Install Gantz
npm install -g gantz

# Initialize Helm project
gantz init --template helm-automation

# Generate chart from description
gantz run generate_chart \
  --description "Node.js API with Redis cache and PostgreSQL" \
  --name my-api

# Smart upgrade with analysis
gantz run smart_upgrade \
  --release my-app \
  --chart ./charts/my-app \
  --namespace production

# Analyze existing chart
gantz run analyze_chart --chart-path ./charts/my-app

# Optimize release values
gantz run optimize_values \
  --release my-app \
  --namespace production
```

Build intelligent Helm operations at [gantz.run](https://gantz.run).

## Related Reading

- [Kubernetes MCP Integration](/post/kubernetes-mcp-integration/) - Container orchestration
- [Terraform MCP Integration](/post/terraform-mcp-integration/) - Infrastructure provisioning
- [Ansible MCP Integration](/post/ansible-mcp-integration/) - Configuration management

## Conclusion

Helm and MCP create powerful AI-driven package management for Kubernetes. With intelligent chart generation, smart upgrades, and automated rollback decisions, you can manage complex deployments with confidence.

Start building Helm AI agents with Gantz today.
