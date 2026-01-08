+++
title = "Terraform MCP Integration: AI-Powered Infrastructure as Code"
image = "images/terraform-mcp-integration.webp"
date = 2025-05-27
description = "Build intelligent infrastructure automation with Terraform and MCP. Learn IaC generation, drift detection, and cost optimization with Gantz."
summary = "Generate Terraform configs from natural language, detect infrastructure drift automatically, get AI-powered cost optimization recommendations, and run security compliance scans. Includes handlers for plan, apply, state management, and change impact analysis."
draft = false
tags = ['terraform', 'infrastructure', 'iac', 'mcp', 'devops', 'gantz']
voice = false

[howto]
name = "How To Build AI Infrastructure Automation with Terraform and MCP"
totalTime = 35
[[howto.steps]]
name = "Set up Terraform"
text = "Configure Terraform CLI and state backend"
[[howto.steps]]
name = "Define MCP tools"
text = "Create tool definitions for IaC operations"
[[howto.steps]]
name = "Implement handlers"
text = "Build handlers for plan, apply, and state management"
[[howto.steps]]
name = "Add AI capabilities"
text = "Integrate AI-powered code generation and analysis"
[[howto.steps]]
name = "Deploy with Gantz"
text = "Deploy your infrastructure automation using Gantz CLI"
+++

Terraform is the industry standard for infrastructure as code, and with MCP integration, you can build AI agents that generate configurations, detect drift, optimize costs, and automate infrastructure management.

## Why Terraform MCP Integration?

AI-powered infrastructure enables:

- **IaC generation**: Natural language to Terraform
- **Drift detection**: Automated state analysis
- **Cost optimization**: AI-driven resource recommendations
- **Security scanning**: Automated compliance checks
- **Change impact analysis**: Predict deployment effects

## Terraform MCP Tool Definition

Configure Terraform tools in Gantz:

```yaml
# gantz.yaml
name: terraform-mcp-tools
version: 1.0.0

tools:
  init:
    description: "Initialize Terraform workspace"
    parameters:
      working_dir:
        type: string
        required: true
      backend_config:
        type: object
    handler: terraform.init

  plan:
    description: "Generate Terraform plan"
    parameters:
      working_dir:
        type: string
        required: true
      var_file:
        type: string
      target:
        type: string
    handler: terraform.plan

  apply:
    description: "Apply Terraform changes"
    parameters:
      working_dir:
        type: string
        required: true
      auto_approve:
        type: boolean
        default: false
    handler: terraform.apply

  destroy:
    description: "Destroy Terraform resources"
    parameters:
      working_dir:
        type: string
        required: true
      target:
        type: string
    handler: terraform.destroy

  state_list:
    description: "List resources in state"
    parameters:
      working_dir:
        type: string
        required: true
    handler: terraform.state_list

  generate_config:
    description: "AI-generate Terraform configuration"
    parameters:
      description:
        type: string
        required: true
      provider:
        type: string
        required: true
    handler: terraform.generate_config

  analyze_plan:
    description: "AI analysis of Terraform plan"
    parameters:
      plan_file:
        type: string
        required: true
    handler: terraform.analyze_plan
```

## Handler Implementation

Build Terraform operation handlers:

```python
# handlers/terraform.py
import subprocess
import json
import os
from pathlib import Path


async def run_terraform(args: list, working_dir: str) -> dict:
    """Execute Terraform command."""
    try:
        result = subprocess.run(
            ['terraform'] + args,
            cwd=working_dir,
            capture_output=True,
            text=True,
            timeout=600
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


async def init(working_dir: str, backend_config: dict = None) -> dict:
    """Initialize Terraform workspace."""
    try:
        args = ['init', '-no-color']

        if backend_config:
            for key, value in backend_config.items():
                args.extend([f'-backend-config={key}={value}'])

        result = await run_terraform(args, working_dir)

        if not result.get('success'):
            return {'error': result.get('stderr', 'Init failed')}

        return {
            'initialized': True,
            'working_dir': working_dir,
            'message': 'Terraform initialized successfully'
        }

    except Exception as e:
        return {'error': f'Init failed: {str(e)}'}


async def plan(working_dir: str, var_file: str = None,
               target: str = None) -> dict:
    """Generate Terraform plan."""
    try:
        plan_file = os.path.join(working_dir, 'tfplan')
        args = ['plan', '-no-color', '-out=' + plan_file]

        if var_file:
            args.append(f'-var-file={var_file}')
        if target:
            args.append(f'-target={target}')

        result = await run_terraform(args, working_dir)

        if not result.get('success'):
            return {'error': result.get('stderr', 'Plan failed')}

        # Get plan in JSON format
        json_result = await run_terraform(
            ['show', '-json', plan_file],
            working_dir
        )

        plan_data = {}
        if json_result.get('success'):
            plan_data = json.loads(json_result.get('stdout', '{}'))

        # Parse changes
        changes = parse_plan_changes(plan_data)

        return {
            'plan_file': plan_file,
            'has_changes': len(changes['create']) + len(changes['update']) + len(changes['delete']) > 0,
            'summary': {
                'create': len(changes['create']),
                'update': len(changes['update']),
                'delete': len(changes['delete'])
            },
            'changes': changes,
            'raw_output': result.get('stdout')
        }

    except Exception as e:
        return {'error': f'Plan failed: {str(e)}'}


async def apply(working_dir: str, auto_approve: bool = False) -> dict:
    """Apply Terraform changes."""
    try:
        plan_file = os.path.join(working_dir, 'tfplan')
        args = ['apply', '-no-color']

        if auto_approve:
            args.append('-auto-approve')

        if os.path.exists(plan_file):
            args.append(plan_file)
        elif auto_approve:
            pass  # Apply without plan file
        else:
            return {'error': 'No plan file found. Run plan first or use auto_approve'}

        result = await run_terraform(args, working_dir)

        if not result.get('success'):
            return {'error': result.get('stderr', 'Apply failed')}

        return {
            'applied': True,
            'working_dir': working_dir,
            'output': result.get('stdout')
        }

    except Exception as e:
        return {'error': f'Apply failed: {str(e)}'}


async def destroy(working_dir: str, target: str = None) -> dict:
    """Destroy Terraform resources."""
    try:
        args = ['destroy', '-no-color', '-auto-approve']

        if target:
            args.append(f'-target={target}')

        result = await run_terraform(args, working_dir)

        if not result.get('success'):
            return {'error': result.get('stderr', 'Destroy failed')}

        return {
            'destroyed': True,
            'target': target or 'all',
            'output': result.get('stdout')
        }

    except Exception as e:
        return {'error': f'Destroy failed: {str(e)}'}


async def state_list(working_dir: str) -> dict:
    """List resources in state."""
    try:
        result = await run_terraform(['state', 'list'], working_dir)

        if not result.get('success'):
            return {'error': result.get('stderr', 'State list failed')}

        resources = result.get('stdout', '').strip().split('\n')
        resources = [r for r in resources if r]

        return {
            'count': len(resources),
            'resources': resources
        }

    except Exception as e:
        return {'error': f'State list failed: {str(e)}'}


def parse_plan_changes(plan_data: dict) -> dict:
    """Parse plan changes from JSON."""
    changes = {'create': [], 'update': [], 'delete': [], 'replace': []}

    resource_changes = plan_data.get('resource_changes', [])

    for rc in resource_changes:
        actions = rc.get('change', {}).get('actions', [])
        resource = {
            'address': rc.get('address'),
            'type': rc.get('type'),
            'name': rc.get('name')
        }

        if 'create' in actions and 'delete' in actions:
            changes['replace'].append(resource)
        elif 'create' in actions:
            changes['create'].append(resource)
        elif 'update' in actions:
            changes['update'].append(resource)
        elif 'delete' in actions:
            changes['delete'].append(resource)

    return changes
```

## AI-Powered IaC Generation

Generate Terraform from natural language:

```python
# terraform_ai.py
from gantz import MCPClient

mcp = MCPClient(config_path='gantz.yaml')


async def generate_config(description: str, provider: str) -> dict:
    """AI-generate Terraform configuration."""
    # Parse requirements
    requirements = mcp.execute_tool('ai_parse', {
        'type': 'infrastructure_requirements',
        'description': description,
        'provider': provider,
        'extract': ['resources', 'networking', 'security', 'scaling']
    })

    # Generate Terraform code
    result = mcp.execute_tool('ai_generate', {
        'type': 'terraform',
        'requirements': requirements,
        'provider': provider,
        'best_practices': True,
        'include': ['main.tf', 'variables.tf', 'outputs.tf']
    })

    return {
        'description': description,
        'provider': provider,
        'files': result.get('files', {}),
        'resources_created': result.get('resource_count'),
        'estimated_cost': result.get('cost_estimate'),
        'security_notes': result.get('security_notes', [])
    }


async def analyze_plan(plan_file: str) -> dict:
    """AI analysis of Terraform plan."""
    # Read plan file
    with open(plan_file, 'r') as f:
        plan_content = f.read()

    # AI analysis
    result = mcp.execute_tool('ai_analyze', {
        'type': 'terraform_plan',
        'plan': plan_content,
        'analyze': ['impact', 'risks', 'cost', 'security', 'best_practices']
    })

    return {
        'plan_file': plan_file,
        'impact_assessment': result.get('impact'),
        'risk_analysis': result.get('risks', []),
        'cost_impact': result.get('cost'),
        'security_findings': result.get('security', []),
        'best_practice_violations': result.get('violations', []),
        'recommendations': result.get('recommendations', []),
        'approval_recommendation': result.get('should_approve')
    }


async def detect_drift(working_dir: str) -> dict:
    """Detect infrastructure drift."""
    # Refresh state
    await run_terraform(['refresh', '-no-color'], working_dir)

    # Generate plan to detect drift
    plan = mcp.execute_tool('plan', {'working_dir': working_dir})

    if 'error' in plan:
        return plan

    if not plan.get('has_changes'):
        return {
            'drift_detected': False,
            'message': 'No drift detected'
        }

    # AI analysis of drift
    result = mcp.execute_tool('ai_analyze', {
        'type': 'drift_analysis',
        'changes': plan.get('changes'),
        'analyze': ['cause', 'impact', 'remediation']
    })

    return {
        'drift_detected': True,
        'changes': plan.get('changes'),
        'likely_causes': result.get('causes', []),
        'impact': result.get('impact'),
        'remediation_options': result.get('remediation', [])
    }


async def optimize_cost(working_dir: str) -> dict:
    """Optimize infrastructure costs."""
    # Get current state
    resources = mcp.execute_tool('state_list', {'working_dir': working_dir})

    # Read current configuration
    config = await read_terraform_config(working_dir)

    # AI cost optimization
    result = mcp.execute_tool('ai_analyze', {
        'type': 'cost_optimization',
        'resources': resources.get('resources', []),
        'config': config,
        'analyze': ['rightsizing', 'reserved_instances', 'spot_instances', 'unused']
    })

    return {
        'current_resources': len(resources.get('resources', [])),
        'optimization_opportunities': result.get('opportunities', []),
        'estimated_savings': result.get('savings'),
        'recommended_changes': result.get('changes', []),
        'terraform_updates': result.get('code_changes', [])
    }


async def security_scan(working_dir: str) -> dict:
    """Scan Terraform for security issues."""
    config = await read_terraform_config(working_dir)

    result = mcp.execute_tool('ai_analyze', {
        'type': 'security_scan',
        'config': config,
        'frameworks': ['cis', 'soc2', 'hipaa'],
        'severity_threshold': 'medium'
    })

    return {
        'working_dir': working_dir,
        'findings': result.get('findings', []),
        'severity_summary': result.get('severity_counts'),
        'compliance_status': result.get('compliance'),
        'remediation': result.get('remediation', [])
    }


async def read_terraform_config(working_dir: str) -> dict:
    """Read Terraform configuration files."""
    config = {}
    tf_files = Path(working_dir).glob('*.tf')

    for tf_file in tf_files:
        with open(tf_file, 'r') as f:
            config[tf_file.name] = f.read()

    return config
```

## Module Generation

Generate reusable modules:

```python
# module_generator.py
from gantz import MCPClient

mcp = MCPClient()


async def generate_module(name: str, description: str,
                         provider: str) -> dict:
    """Generate Terraform module."""
    result = mcp.execute_tool('ai_generate', {
        'type': 'terraform_module',
        'name': name,
        'description': description,
        'provider': provider,
        'include': [
            'main.tf',
            'variables.tf',
            'outputs.tf',
            'README.md',
            'examples/'
        ]
    })

    return {
        'module_name': name,
        'files': result.get('files', {}),
        'inputs': result.get('variables', []),
        'outputs': result.get('outputs', []),
        'usage_example': result.get('example')
    }


async def refactor_to_modules(working_dir: str) -> dict:
    """Refactor configuration into modules."""
    config = await read_terraform_config(working_dir)

    result = mcp.execute_tool('ai_analyze', {
        'type': 'module_refactoring',
        'config': config,
        'identify': ['repeated_patterns', 'logical_groups', 'reusable_components']
    })

    return {
        'suggested_modules': result.get('modules', []),
        'refactored_code': result.get('refactored', {}),
        'benefits': result.get('benefits', [])
    }
```

## Deploy with Gantz CLI

Deploy your infrastructure automation:

```bash
# Install Gantz
npm install -g gantz

# Initialize Terraform project
gantz init --template terraform-automation

# Generate infrastructure from description
gantz run generate_config \
  --description "VPC with public/private subnets, EKS cluster, and RDS PostgreSQL" \
  --provider aws

# Analyze plan before applying
gantz run analyze_plan --plan-file ./tfplan

# Detect drift
gantz run detect_drift --working-dir ./infrastructure

# Optimize costs
gantz run optimize_cost --working-dir ./infrastructure
```

Build intelligent infrastructure at [gantz.run](https://gantz.run).

## Related Reading

- [Ansible MCP Integration](/post/ansible-mcp-integration/) - Configuration management
- [Kubernetes MCP Integration](/post/kubernetes-mcp-integration/) - Container orchestration
- [AWS Lambda MCP Integration](/post/aws-lambda-mcp/) - Serverless functions

## Conclusion

Terraform and MCP create powerful AI-driven infrastructure automation. With intelligent code generation, drift detection, and cost optimization, you can manage infrastructure more efficiently and securely.

Start building Terraform AI agents with Gantz today.
