+++
title = "Kubernetes MCP Integration: AI-Powered Container Orchestration"
image = "images/kubernetes-mcp-integration.webp"
date = 2025-05-29
description = "Build intelligent Kubernetes automation with MCP. Learn deployment management, scaling, troubleshooting, and AI-driven cluster operations with Gantz."
draft = false
tags = ['kubernetes', 'containers', 'orchestration', 'mcp', 'devops', 'gantz']
voice = false

[howto]
name = "How To Build AI Kubernetes Automation with MCP"
totalTime = 35
[[howto.steps]]
name = "Set up Kubernetes access"
text = "Configure kubectl and cluster authentication"
[[howto.steps]]
name = "Define MCP tools"
text = "Create tool definitions for cluster operations"
[[howto.steps]]
name = "Implement handlers"
text = "Build handlers for deployments, services, and pods"
[[howto.steps]]
name = "Add AI capabilities"
text = "Integrate AI-powered troubleshooting and optimization"
[[howto.steps]]
name = "Deploy with Gantz"
text = "Deploy your Kubernetes automation using Gantz CLI"
+++

Kubernetes is the standard for container orchestration, and with MCP integration, you can build AI agents that manage deployments, troubleshoot issues, optimize resources, and automate complex cluster operations.

## Why Kubernetes MCP Integration?

AI-powered Kubernetes enables:

- **Smart deployments**: AI-optimized rollout strategies
- **Auto-troubleshooting**: Intelligent issue detection and resolution
- **Resource optimization**: ML-based capacity planning
- **Security scanning**: Automated vulnerability detection
- **Natural language operations**: kubectl via conversation

## Kubernetes MCP Tool Definition

Configure Kubernetes tools in Gantz:

```yaml
# gantz.yaml
name: kubernetes-mcp-tools
version: 1.0.0

tools:
  get_pods:
    description: "Get pods in namespace"
    parameters:
      namespace:
        type: string
        default: "default"
      selector:
        type: string
    handler: kubernetes.get_pods

  get_deployments:
    description: "Get deployments"
    parameters:
      namespace:
        type: string
        default: "default"
    handler: kubernetes.get_deployments

  apply_manifest:
    description: "Apply Kubernetes manifest"
    parameters:
      manifest:
        type: string
        required: true
      namespace:
        type: string
    handler: kubernetes.apply_manifest

  scale_deployment:
    description: "Scale deployment replicas"
    parameters:
      name:
        type: string
        required: true
      replicas:
        type: integer
        required: true
      namespace:
        type: string
        default: "default"
    handler: kubernetes.scale_deployment

  get_logs:
    description: "Get pod logs"
    parameters:
      pod:
        type: string
        required: true
      namespace:
        type: string
        default: "default"
      container:
        type: string
      tail:
        type: integer
        default: 100
    handler: kubernetes.get_logs

  describe_resource:
    description: "Describe Kubernetes resource"
    parameters:
      kind:
        type: string
        required: true
      name:
        type: string
        required: true
      namespace:
        type: string
    handler: kubernetes.describe_resource

  troubleshoot:
    description: "AI troubleshoot cluster issues"
    parameters:
      namespace:
        type: string
      issue_type:
        type: string
    handler: kubernetes.troubleshoot

  generate_manifest:
    description: "AI-generate Kubernetes manifest"
    parameters:
      description:
        type: string
        required: true
    handler: kubernetes.generate_manifest
```

## Handler Implementation

Build Kubernetes operation handlers:

```python
# handlers/kubernetes.py
from kubernetes import client, config
from kubernetes.client.rest import ApiException
import yaml
import os


def get_k8s_client():
    """Get Kubernetes client."""
    try:
        config.load_incluster_config()
    except config.ConfigException:
        config.load_kube_config()

    return client.CoreV1Api(), client.AppsV1Api()


async def get_pods(namespace: str = "default", selector: str = None) -> dict:
    """Get pods in namespace."""
    try:
        core_v1, _ = get_k8s_client()

        if selector:
            pods = core_v1.list_namespaced_pod(
                namespace,
                label_selector=selector
            )
        else:
            pods = core_v1.list_namespaced_pod(namespace)

        return {
            'namespace': namespace,
            'count': len(pods.items),
            'pods': [{
                'name': p.metadata.name,
                'status': p.status.phase,
                'ready': get_pod_ready_status(p),
                'restarts': get_restart_count(p),
                'age': get_age(p.metadata.creation_timestamp),
                'node': p.spec.node_name,
                'ip': p.status.pod_ip
            } for p in pods.items]
        }

    except ApiException as e:
        return {'error': f'Failed to get pods: {e.reason}'}
    except Exception as e:
        return {'error': str(e)}


async def get_deployments(namespace: str = "default") -> dict:
    """Get deployments in namespace."""
    try:
        _, apps_v1 = get_k8s_client()

        deployments = apps_v1.list_namespaced_deployment(namespace)

        return {
            'namespace': namespace,
            'count': len(deployments.items),
            'deployments': [{
                'name': d.metadata.name,
                'replicas': d.spec.replicas,
                'ready': d.status.ready_replicas or 0,
                'available': d.status.available_replicas or 0,
                'updated': d.status.updated_replicas or 0,
                'age': get_age(d.metadata.creation_timestamp),
                'image': get_deployment_image(d)
            } for d in deployments.items]
        }

    except ApiException as e:
        return {'error': f'Failed to get deployments: {e.reason}'}
    except Exception as e:
        return {'error': str(e)}


async def apply_manifest(manifest: str, namespace: str = None) -> dict:
    """Apply Kubernetes manifest."""
    try:
        from kubernetes import utils

        k8s_client = client.ApiClient()

        # Parse manifest
        if manifest.startswith('---') or '\n---' in manifest:
            docs = list(yaml.safe_load_all(manifest))
        else:
            docs = [yaml.safe_load(manifest)]

        results = []
        for doc in docs:
            if doc is None:
                continue

            if namespace and 'namespace' not in doc.get('metadata', {}):
                doc.setdefault('metadata', {})['namespace'] = namespace

            try:
                utils.create_from_dict(k8s_client, doc)
                results.append({
                    'kind': doc.get('kind'),
                    'name': doc.get('metadata', {}).get('name'),
                    'action': 'created'
                })
            except ApiException as e:
                if e.status == 409:  # Already exists
                    # Update existing resource
                    results.append({
                        'kind': doc.get('kind'),
                        'name': doc.get('metadata', {}).get('name'),
                        'action': 'updated'
                    })
                else:
                    raise

        return {
            'applied': True,
            'resources': results
        }

    except Exception as e:
        return {'error': f'Failed to apply manifest: {str(e)}'}


async def scale_deployment(name: str, replicas: int,
                          namespace: str = "default") -> dict:
    """Scale deployment replicas."""
    try:
        _, apps_v1 = get_k8s_client()

        body = {'spec': {'replicas': replicas}}

        apps_v1.patch_namespaced_deployment_scale(
            name,
            namespace,
            body
        )

        return {
            'deployment': name,
            'namespace': namespace,
            'scaled_to': replicas,
            'success': True
        }

    except ApiException as e:
        return {'error': f'Failed to scale: {e.reason}'}
    except Exception as e:
        return {'error': str(e)}


async def get_logs(pod: str, namespace: str = "default",
                  container: str = None, tail: int = 100) -> dict:
    """Get pod logs."""
    try:
        core_v1, _ = get_k8s_client()

        kwargs = {
            'name': pod,
            'namespace': namespace,
            'tail_lines': tail
        }

        if container:
            kwargs['container'] = container

        logs = core_v1.read_namespaced_pod_log(**kwargs)

        return {
            'pod': pod,
            'namespace': namespace,
            'container': container,
            'lines': tail,
            'logs': logs
        }

    except ApiException as e:
        return {'error': f'Failed to get logs: {e.reason}'}
    except Exception as e:
        return {'error': str(e)}


async def describe_resource(kind: str, name: str,
                           namespace: str = None) -> dict:
    """Describe Kubernetes resource."""
    try:
        core_v1, apps_v1 = get_k8s_client()

        resource = None

        if kind.lower() == 'pod':
            resource = core_v1.read_namespaced_pod(name, namespace or 'default')
        elif kind.lower() == 'deployment':
            resource = apps_v1.read_namespaced_deployment(name, namespace or 'default')
        elif kind.lower() == 'service':
            resource = core_v1.read_namespaced_service(name, namespace or 'default')
        elif kind.lower() == 'configmap':
            resource = core_v1.read_namespaced_config_map(name, namespace or 'default')
        elif kind.lower() == 'secret':
            resource = core_v1.read_namespaced_secret(name, namespace or 'default')
        elif kind.lower() == 'namespace':
            resource = core_v1.read_namespace(name)

        if resource:
            return {
                'kind': kind,
                'name': name,
                'namespace': namespace,
                'resource': resource.to_dict()
            }

        return {'error': f'Unknown resource kind: {kind}'}

    except ApiException as e:
        return {'error': f'Failed to describe: {e.reason}'}
    except Exception as e:
        return {'error': str(e)}


def get_pod_ready_status(pod) -> str:
    """Get pod ready status."""
    conditions = pod.status.conditions or []
    for c in conditions:
        if c.type == 'Ready':
            return c.status
    return 'Unknown'


def get_restart_count(pod) -> int:
    """Get total restart count for pod."""
    count = 0
    if pod.status.container_statuses:
        for cs in pod.status.container_statuses:
            count += cs.restart_count
    return count


def get_deployment_image(deployment) -> str:
    """Get primary container image."""
    containers = deployment.spec.template.spec.containers
    if containers:
        return containers[0].image
    return ''


def get_age(timestamp) -> str:
    """Get human-readable age."""
    from datetime import datetime, timezone

    if not timestamp:
        return 'Unknown'

    now = datetime.now(timezone.utc)
    diff = now - timestamp

    days = diff.days
    hours = diff.seconds // 3600
    minutes = (diff.seconds % 3600) // 60

    if days > 0:
        return f'{days}d'
    elif hours > 0:
        return f'{hours}h'
    else:
        return f'{minutes}m'
```

## AI-Powered Kubernetes Operations

Build intelligent cluster management:

```python
# kubernetes_ai.py
from gantz import MCPClient

mcp = MCPClient(config_path='gantz.yaml')


async def troubleshoot(namespace: str = None, issue_type: str = None) -> dict:
    """AI troubleshoot cluster issues."""
    # Gather cluster state
    pods = mcp.execute_tool('get_pods', {'namespace': namespace or 'default'})
    deployments = mcp.execute_tool('get_deployments', {'namespace': namespace or 'default'})

    # Find problematic resources
    issues = []

    for pod in pods.get('pods', []):
        if pod['status'] != 'Running' or pod['restarts'] > 5:
            logs = mcp.execute_tool('get_logs', {
                'pod': pod['name'],
                'namespace': namespace or 'default',
                'tail': 50
            })
            issues.append({
                'type': 'pod',
                'name': pod['name'],
                'status': pod['status'],
                'restarts': pod['restarts'],
                'logs': logs.get('logs', '')
            })

    # AI analysis
    result = mcp.execute_tool('ai_analyze', {
        'type': 'kubernetes_troubleshoot',
        'issues': issues,
        'cluster_state': {
            'pods': pods,
            'deployments': deployments
        },
        'analyze': ['root_cause', 'impact', 'resolution']
    })

    return {
        'namespace': namespace,
        'issues_found': len(issues),
        'diagnoses': result.get('diagnoses', []),
        'root_causes': result.get('root_causes', []),
        'recommended_actions': result.get('actions', []),
        'commands': result.get('kubectl_commands', [])
    }


async def generate_manifest(description: str) -> dict:
    """AI-generate Kubernetes manifest."""
    result = mcp.execute_tool('ai_generate', {
        'type': 'kubernetes_manifest',
        'description': description,
        'best_practices': True,
        'include': ['deployment', 'service', 'configmap', 'hpa']
    })

    return {
        'description': description,
        'manifest': result.get('manifest'),
        'resources': result.get('resources', []),
        'notes': result.get('notes', [])
    }


async def optimize_resources(namespace: str) -> dict:
    """Optimize resource requests and limits."""
    deployments = mcp.execute_tool('get_deployments', {'namespace': namespace})

    # Get metrics for each deployment
    metrics = []
    for d in deployments.get('deployments', []):
        # Fetch resource usage metrics
        usage = await get_resource_metrics(d['name'], namespace)
        metrics.append({
            'deployment': d['name'],
            'current_requests': d.get('resources', {}),
            'actual_usage': usage
        })

    # AI optimization
    result = mcp.execute_tool('ai_analyze', {
        'type': 'resource_optimization',
        'metrics': metrics,
        'optimize_for': ['cost', 'performance', 'reliability']
    })

    return {
        'namespace': namespace,
        'optimizations': result.get('optimizations', []),
        'estimated_savings': result.get('savings'),
        'updated_manifests': result.get('manifests', [])
    }


async def security_scan(namespace: str = None) -> dict:
    """Scan cluster for security issues."""
    pods = mcp.execute_tool('get_pods', {'namespace': namespace or 'default'})

    # AI security analysis
    result = mcp.execute_tool('ai_analyze', {
        'type': 'kubernetes_security',
        'pods': pods.get('pods', []),
        'checks': [
            'privileged_containers',
            'host_networking',
            'root_user',
            'sensitive_mounts',
            'image_vulnerabilities'
        ]
    })

    return {
        'namespace': namespace,
        'findings': result.get('findings', []),
        'severity_summary': result.get('severity_counts'),
        'remediation': result.get('remediation', []),
        'compliance_score': result.get('score')
    }


async def rollout_strategy(deployment: str, namespace: str,
                          strategy: str = 'auto') -> dict:
    """AI-optimized rollout strategy."""
    # Get current deployment
    current = mcp.execute_tool('describe_resource', {
        'kind': 'deployment',
        'name': deployment,
        'namespace': namespace
    })

    # AI strategy recommendation
    result = mcp.execute_tool('ai_analyze', {
        'type': 'rollout_strategy',
        'deployment': current.get('resource'),
        'strategy_preference': strategy,
        'analyze': ['risk', 'downtime', 'rollback_plan']
    })

    return {
        'deployment': deployment,
        'recommended_strategy': result.get('strategy'),
        'max_surge': result.get('max_surge'),
        'max_unavailable': result.get('max_unavailable'),
        'estimated_duration': result.get('duration'),
        'rollback_plan': result.get('rollback'),
        'manifest_patch': result.get('patch')
    }
```

## Natural Language Operations

kubectl via conversation:

```python
# kubectl_ai.py
from gantz import MCPClient

mcp = MCPClient()


async def natural_kubectl(command: str) -> dict:
    """Execute kubectl from natural language."""
    # Parse natural language to kubectl
    parsed = mcp.execute_tool('ai_parse', {
        'type': 'kubectl_command',
        'input': command,
        'context': {
            'available_namespaces': await get_namespaces(),
            'common_operations': ['get', 'describe', 'logs', 'scale', 'delete']
        }
    })

    kubectl_cmd = parsed.get('command')

    if not kubectl_cmd:
        return {'error': 'Could not parse command'}

    # Execute appropriate MCP tool
    result = await execute_kubectl_equivalent(kubectl_cmd)

    # Generate response
    response = mcp.execute_tool('ai_generate', {
        'type': 'kubectl_response',
        'command': command,
        'kubectl': kubectl_cmd,
        'result': result
    })

    return {
        'input': command,
        'kubectl_equivalent': kubectl_cmd,
        'result': result,
        'summary': response.get('summary')
    }


async def explain_resource(kind: str, name: str, namespace: str) -> dict:
    """AI explanation of resource."""
    resource = mcp.execute_tool('describe_resource', {
        'kind': kind,
        'name': name,
        'namespace': namespace
    })

    result = mcp.execute_tool('ai_explain', {
        'type': 'kubernetes_resource',
        'resource': resource.get('resource'),
        'explain': ['purpose', 'configuration', 'relationships', 'health']
    })

    return {
        'kind': kind,
        'name': name,
        'explanation': result.get('explanation'),
        'configuration_notes': result.get('config_notes', []),
        'relationships': result.get('relationships', []),
        'health_assessment': result.get('health')
    }
```

## Deploy with Gantz CLI

Deploy your Kubernetes automation:

```bash
# Install Gantz
npm install -g gantz

# Initialize Kubernetes project
gantz init --template kubernetes-automation

# Generate manifest from description
gantz run generate_manifest \
  --description "Web app with 3 replicas, ingress, and autoscaling"

# Troubleshoot namespace
gantz run troubleshoot --namespace production

# Optimize resources
gantz run optimize_resources --namespace default

# Natural language kubectl
gantz run natural_kubectl \
  --command "show me all pods that are not running in production"
```

Build intelligent Kubernetes operations at [gantz.run](https://gantz.run).

## Related Reading

- [Helm MCP Integration](/post/helm-mcp-integration/) - Package management
- [Terraform MCP Integration](/post/terraform-mcp-integration/) - Infrastructure provisioning
- [Prometheus MCP Integration](/post/prometheus-mcp-integration/) - Cluster monitoring

## Conclusion

Kubernetes and MCP create powerful AI-driven container orchestration. With intelligent troubleshooting, resource optimization, and natural language operations, you can manage clusters more efficiently and reliably.

Start building Kubernetes AI agents with Gantz today.
