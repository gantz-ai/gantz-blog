+++
title = "Ansible MCP Integration: AI-Powered Configuration Management"
image = "/images/ansible-mcp-integration.png"
date = 2025-05-28
description = "Build intelligent automation with Ansible and MCP. Learn playbook generation, inventory management, and AI-driven configuration with Gantz."
draft = false
tags = ['ansible', 'configuration-management', 'automation', 'mcp', 'devops', 'gantz']
voice = false

[howto]
name = "How To Build AI Automation with Ansible and MCP"
totalTime = 30
[[howto.steps]]
name = "Set up Ansible"
text = "Configure Ansible and inventory"
[[howto.steps]]
name = "Define MCP tools"
text = "Create tool definitions for automation operations"
[[howto.steps]]
name = "Implement handlers"
text = "Build handlers for playbooks, inventory, and tasks"
[[howto.steps]]
name = "Add AI capabilities"
text = "Integrate AI-powered playbook generation and analysis"
[[howto.steps]]
name = "Deploy with Gantz"
text = "Deploy your configuration automation using Gantz CLI"
+++

Ansible is the leading configuration management tool, and with MCP integration, you can build AI agents that generate playbooks, manage inventory, and automate complex infrastructure configurations.

## Why Ansible MCP Integration?

AI-powered configuration management enables:

- **Playbook generation**: Natural language to Ansible YAML
- **Inventory intelligence**: Smart host grouping and targeting
- **Role creation**: AI-generated reusable roles
- **Compliance automation**: Security baseline enforcement
- **Drift remediation**: Automated configuration fixes

## Ansible MCP Tool Definition

Configure Ansible tools in Gantz:

```yaml
# gantz.yaml
name: ansible-mcp-tools
version: 1.0.0

tools:
  run_playbook:
    description: "Execute Ansible playbook"
    parameters:
      playbook:
        type: string
        required: true
      inventory:
        type: string
        required: true
      limit:
        type: string
      tags:
        type: array
      extra_vars:
        type: object
    handler: ansible.run_playbook

  run_adhoc:
    description: "Run ad-hoc Ansible command"
    parameters:
      hosts:
        type: string
        required: true
      module:
        type: string
        required: true
      args:
        type: string
      inventory:
        type: string
        required: true
    handler: ansible.run_adhoc

  get_inventory:
    description: "Get inventory information"
    parameters:
      inventory:
        type: string
        required: true
      host:
        type: string
    handler: ansible.get_inventory

  list_roles:
    description: "List available roles"
    parameters:
      roles_path:
        type: string
    handler: ansible.list_roles

  generate_playbook:
    description: "AI-generate Ansible playbook"
    parameters:
      description:
        type: string
        required: true
      target_os:
        type: string
    handler: ansible.generate_playbook

  analyze_playbook:
    description: "AI analysis of playbook"
    parameters:
      playbook_path:
        type: string
        required: true
    handler: ansible.analyze_playbook
```

## Handler Implementation

Build Ansible operation handlers:

```python
# handlers/ansible.py
import subprocess
import json
import os
import yaml
from pathlib import Path


async def run_command(args: list, env: dict = None) -> dict:
    """Execute command with optional environment."""
    try:
        process_env = os.environ.copy()
        if env:
            process_env.update(env)

        result = subprocess.run(
            args,
            capture_output=True,
            text=True,
            timeout=1800,
            env=process_env
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


async def run_playbook(playbook: str, inventory: str,
                       limit: str = None, tags: list = None,
                       extra_vars: dict = None) -> dict:
    """Execute Ansible playbook."""
    try:
        args = [
            'ansible-playbook',
            playbook,
            '-i', inventory,
            '--json'
        ]

        if limit:
            args.extend(['--limit', limit])
        if tags:
            args.extend(['--tags', ','.join(tags)])
        if extra_vars:
            args.extend(['-e', json.dumps(extra_vars)])

        result = await run_command(args)

        if not result.get('success'):
            return {
                'error': result.get('stderr', 'Playbook failed'),
                'output': result.get('stdout')
            }

        # Parse results
        stats = parse_playbook_output(result.get('stdout', ''))

        return {
            'playbook': playbook,
            'executed': True,
            'stats': stats,
            'output': result.get('stdout')
        }

    except Exception as e:
        return {'error': f'Playbook execution failed: {str(e)}'}


async def run_adhoc(hosts: str, module: str, args: str = None,
                   inventory: str = None) -> dict:
    """Run ad-hoc Ansible command."""
    try:
        cmd_args = [
            'ansible',
            hosts,
            '-m', module,
            '-i', inventory
        ]

        if args:
            cmd_args.extend(['-a', args])

        result = await run_command(cmd_args)

        return {
            'hosts': hosts,
            'module': module,
            'success': result.get('success'),
            'output': result.get('stdout'),
            'errors': result.get('stderr')
        }

    except Exception as e:
        return {'error': f'Ad-hoc command failed: {str(e)}'}


async def get_inventory(inventory: str, host: str = None) -> dict:
    """Get inventory information."""
    try:
        args = ['ansible-inventory', '-i', inventory, '--list']

        result = await run_command(args)

        if not result.get('success'):
            return {'error': result.get('stderr', 'Failed to get inventory')}

        inventory_data = json.loads(result.get('stdout', '{}'))

        if host:
            # Get specific host info
            host_vars = inventory_data.get('_meta', {}).get('hostvars', {}).get(host, {})
            return {
                'host': host,
                'variables': host_vars,
                'groups': find_host_groups(host, inventory_data)
            }

        # Return full inventory
        groups = {k: v for k, v in inventory_data.items() if k != '_meta'}

        return {
            'groups': list(groups.keys()),
            'total_hosts': count_hosts(inventory_data),
            'inventory': groups
        }

    except Exception as e:
        return {'error': f'Failed to get inventory: {str(e)}'}


async def list_roles(roles_path: str = None) -> dict:
    """List available roles."""
    try:
        path = roles_path or './roles'

        if not os.path.exists(path):
            return {'error': f'Roles path not found: {path}'}

        roles = []
        for role_dir in Path(path).iterdir():
            if role_dir.is_dir():
                meta_file = role_dir / 'meta' / 'main.yml'
                meta = {}
                if meta_file.exists():
                    with open(meta_file, 'r') as f:
                        meta = yaml.safe_load(f) or {}

                roles.append({
                    'name': role_dir.name,
                    'description': meta.get('galaxy_info', {}).get('description', ''),
                    'dependencies': meta.get('dependencies', [])
                })

        return {
            'roles_path': path,
            'count': len(roles),
            'roles': roles
        }

    except Exception as e:
        return {'error': f'Failed to list roles: {str(e)}'}


def parse_playbook_output(output: str) -> dict:
    """Parse playbook execution output."""
    stats = {
        'ok': 0,
        'changed': 0,
        'unreachable': 0,
        'failed': 0,
        'skipped': 0
    }

    # Parse PLAY RECAP
    for line in output.split('\n'):
        if ':' in line and any(k in line for k in ['ok=', 'changed=']):
            parts = line.split(':')
            if len(parts) >= 2:
                metrics = parts[1].strip().split()
                for metric in metrics:
                    if '=' in metric:
                        key, value = metric.split('=')
                        if key in stats:
                            stats[key] += int(value)

    return stats


def find_host_groups(host: str, inventory: dict) -> list:
    """Find groups a host belongs to."""
    groups = []
    for group_name, group_data in inventory.items():
        if group_name == '_meta':
            continue
        hosts = group_data.get('hosts', [])
        if host in hosts:
            groups.append(group_name)
    return groups


def count_hosts(inventory: dict) -> int:
    """Count total unique hosts."""
    hosts = set()
    for group_data in inventory.values():
        if isinstance(group_data, dict):
            hosts.update(group_data.get('hosts', []))
    return len(hosts)
```

## AI-Powered Playbook Generation

Generate playbooks from natural language:

```python
# ansible_ai.py
from gantz import MCPClient

mcp = MCPClient(config_path='gantz.yaml')


async def generate_playbook(description: str, target_os: str = None) -> dict:
    """AI-generate Ansible playbook."""
    # Parse requirements
    requirements = mcp.execute_tool('ai_parse', {
        'type': 'automation_requirements',
        'description': description,
        'target_os': target_os,
        'extract': ['tasks', 'packages', 'services', 'files', 'users']
    })

    # Generate playbook
    result = mcp.execute_tool('ai_generate', {
        'type': 'ansible_playbook',
        'requirements': requirements,
        'target_os': target_os,
        'best_practices': True,
        'include_handlers': True
    })

    return {
        'description': description,
        'playbook': result.get('playbook'),
        'tasks_count': result.get('task_count'),
        'handlers': result.get('handlers', []),
        'variables': result.get('variables', {}),
        'notes': result.get('notes', [])
    }


async def analyze_playbook(playbook_path: str) -> dict:
    """AI analysis of playbook."""
    with open(playbook_path, 'r') as f:
        playbook_content = f.read()

    result = mcp.execute_tool('ai_analyze', {
        'type': 'ansible_playbook',
        'content': playbook_content,
        'analyze': ['security', 'idempotency', 'best_practices', 'performance']
    })

    return {
        'playbook': playbook_path,
        'security_issues': result.get('security', []),
        'idempotency_warnings': result.get('idempotency', []),
        'best_practice_violations': result.get('violations', []),
        'performance_suggestions': result.get('performance', []),
        'overall_score': result.get('score'),
        'recommendations': result.get('recommendations', [])
    }


async def generate_role(name: str, description: str,
                       platforms: list = None) -> dict:
    """Generate Ansible role."""
    result = mcp.execute_tool('ai_generate', {
        'type': 'ansible_role',
        'name': name,
        'description': description,
        'platforms': platforms or ['debian', 'redhat'],
        'include': [
            'tasks/main.yml',
            'handlers/main.yml',
            'defaults/main.yml',
            'vars/main.yml',
            'templates/',
            'meta/main.yml',
            'README.md'
        ]
    })

    return {
        'role_name': name,
        'files': result.get('files', {}),
        'supported_platforms': platforms,
        'variables': result.get('default_vars', {}),
        'usage_example': result.get('example')
    }


async def fix_playbook(playbook_path: str, issue: str) -> dict:
    """AI-fix playbook issues."""
    with open(playbook_path, 'r') as f:
        playbook_content = f.read()

    result = mcp.execute_tool('ai_fix', {
        'type': 'ansible_playbook',
        'content': playbook_content,
        'issue': issue,
        'preserve_functionality': True
    })

    return {
        'playbook': playbook_path,
        'fixed_content': result.get('fixed'),
        'changes_made': result.get('changes', []),
        'explanation': result.get('explanation')
    }
```

## Inventory Intelligence

Smart inventory management:

```python
# inventory_ai.py
from gantz import MCPClient

mcp = MCPClient()


async def generate_inventory(hosts: list, grouping_strategy: str = 'auto') -> dict:
    """AI-generate inventory from hosts."""
    result = mcp.execute_tool('ai_generate', {
        'type': 'ansible_inventory',
        'hosts': hosts,
        'strategy': grouping_strategy,
        'include_variables': True
    })

    return {
        'inventory': result.get('inventory'),
        'groups_created': result.get('groups', []),
        'host_vars': result.get('host_vars', {}),
        'group_vars': result.get('group_vars', {})
    }


async def analyze_inventory(inventory: str) -> dict:
    """Analyze inventory for improvements."""
    inv_data = mcp.execute_tool('get_inventory', {'inventory': inventory})

    result = mcp.execute_tool('ai_analyze', {
        'type': 'ansible_inventory',
        'inventory': inv_data,
        'analyze': ['grouping', 'variables', 'organization']
    })

    return {
        'current_groups': inv_data.get('groups', []),
        'suggested_restructure': result.get('suggestions', []),
        'variable_consolidation': result.get('var_suggestions', []),
        'best_practices': result.get('best_practices', [])
    }


async def dynamic_inventory_generator(cloud: str, filters: dict = None) -> dict:
    """Generate dynamic inventory for cloud."""
    result = mcp.execute_tool('ai_generate', {
        'type': 'dynamic_inventory',
        'cloud_provider': cloud,
        'filters': filters,
        'include': ['script', 'configuration']
    })

    return {
        'cloud': cloud,
        'inventory_script': result.get('script'),
        'configuration': result.get('config'),
        'usage': result.get('usage_instructions')
    }
```

## Compliance Automation

Automate security baselines:

```python
# compliance_ai.py
from gantz import MCPClient

mcp = MCPClient()


async def generate_compliance_playbook(framework: str,
                                       target_os: str) -> dict:
    """Generate compliance playbook."""
    result = mcp.execute_tool('ai_generate', {
        'type': 'compliance_playbook',
        'framework': framework,
        'target_os': target_os,
        'include': ['checks', 'remediation', 'reporting']
    })

    return {
        'framework': framework,
        'playbook': result.get('playbook'),
        'controls_covered': result.get('controls', []),
        'remediation_tasks': result.get('remediation_count')
    }


async def audit_compliance(inventory: str, framework: str) -> dict:
    """Audit infrastructure compliance."""
    # Run compliance check playbook
    check_result = mcp.execute_tool('run_playbook', {
        'playbook': f'compliance-{framework}-check.yml',
        'inventory': inventory
    })

    # AI analysis of results
    result = mcp.execute_tool('ai_analyze', {
        'type': 'compliance_audit',
        'framework': framework,
        'results': check_result,
        'generate': ['report', 'remediation_plan']
    })

    return {
        'framework': framework,
        'compliance_score': result.get('score'),
        'passed_controls': result.get('passed', []),
        'failed_controls': result.get('failed', []),
        'remediation_plan': result.get('remediation'),
        'report': result.get('report')
    }
```

## Deploy with Gantz CLI

Deploy your configuration automation:

```bash
# Install Gantz
npm install -g gantz

# Initialize Ansible project
gantz init --template ansible-automation

# Generate playbook from description
gantz run generate_playbook \
  --description "Install and configure Nginx with SSL, PHP-FPM, and MySQL"

# Analyze existing playbook
gantz run analyze_playbook --playbook-path ./site.yml

# Generate compliance playbook
gantz run generate_compliance_playbook \
  --framework cis \
  --target-os ubuntu2204

# Run playbook with AI analysis
gantz run run_playbook \
  --playbook site.yml \
  --inventory production
```

Build intelligent configuration management at [gantz.run](https://gantz.run).

## Related Reading

- [Terraform MCP Integration](/post/terraform-mcp-integration/) - Infrastructure as code
- [Kubernetes MCP Integration](/post/kubernetes-mcp-integration/) - Container orchestration
- [Prometheus MCP Integration](/post/prometheus-mcp-integration/) - Monitoring automation

## Conclusion

Ansible and MCP create powerful AI-driven configuration management. With intelligent playbook generation, compliance automation, and inventory management, you can automate complex infrastructure tasks efficiently.

Start building Ansible AI agents with Gantz today.
