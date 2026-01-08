+++
title = "Grafana MCP Integration: AI-Powered Dashboard and Visualization"
image = "images/grafana-mcp-integration.webp"
date = 2025-05-22
description = "Build intelligent visualization agents with Grafana and MCP. Learn dashboard automation, alert management, and AI insights with Gantz."
summary = "Creating Grafana dashboards means clicking through UI panels one by one. Let AI agents do it instead - describe what you want to visualize and the agent creates the dashboard, configures alert thresholds based on historical baselines, analyzes metric trends to spot anomalies, and explains what your observability data actually means."
draft = false
tags = ['grafana', 'visualization', 'dashboards', 'mcp', 'observability', 'gantz']
voice = false

[howto]
name = "How To Build AI Dashboards with Grafana and MCP"
totalTime = 30
[[howto.steps]]
name = "Set up Grafana API"
text = "Configure Grafana API keys and access"
[[howto.steps]]
name = "Define MCP tools"
text = "Create tool definitions for dashboard operations"
[[howto.steps]]
name = "Implement handlers"
text = "Build handlers for dashboards, panels, and alerts"
[[howto.steps]]
name = "Add AI capabilities"
text = "Integrate AI-powered insights and recommendations"
[[howto.steps]]
name = "Deploy with Gantz"
text = "Deploy your visualization automation using Gantz CLI"
+++

Grafana is the leading visualization platform for metrics and logs. With MCP integration, you can build AI agents that create dashboards, analyze trends, and provide intelligent insights from your observability data.

## Why Grafana MCP Integration?

AI-powered visualization enables:

- **Auto-generated dashboards**: AI creates visualizations from requirements
- **Intelligent insights**: ML-driven data analysis
- **Alert optimization**: Smart threshold recommendations
- **Natural language queries**: Ask questions about data
- **Anomaly highlighting**: Automatic issue detection

## Grafana MCP Tool Definition

Configure Grafana tools in Gantz:

```yaml
# gantz.yaml
name: grafana-mcp-tools
version: 1.0.0

tools:
  create_dashboard:
    description: "Create Grafana dashboard"
    parameters:
      title:
        type: string
        required: true
      panels:
        type: array
        required: true
      folder_id:
        type: integer
    handler: grafana.create_dashboard

  get_dashboard:
    description: "Get dashboard by UID"
    parameters:
      uid:
        type: string
        required: true
    handler: grafana.get_dashboard

  search_dashboards:
    description: "Search dashboards"
    parameters:
      query:
        type: string
      tags:
        type: array
    handler: grafana.search_dashboards

  create_alert_rule:
    description: "Create alert rule"
    parameters:
      name:
        type: string
        required: true
      query:
        type: string
        required: true
      condition:
        type: object
        required: true
      folder_uid:
        type: string
    handler: grafana.create_alert_rule

  get_alerts:
    description: "Get alert instances"
    handler: grafana.get_alerts

  query_datasource:
    description: "Query a datasource"
    parameters:
      datasource_uid:
        type: string
        required: true
      query:
        type: object
        required: true
    handler: grafana.query_datasource

  generate_dashboard:
    description: "AI-generate dashboard from description"
    parameters:
      description:
        type: string
        required: true
      datasources:
        type: array
    handler: grafana.generate_dashboard
```

## Handler Implementation

Build Grafana operation handlers:

```python
# handlers/grafana.py
import httpx
import os
import json

GRAFANA_URL = os.environ.get('GRAFANA_URL', 'http://localhost:3000')
GRAFANA_TOKEN = os.environ['GRAFANA_API_KEY']


def get_headers():
    """Get authorization headers."""
    return {
        "Authorization": f"Bearer {GRAFANA_TOKEN}",
        "Content-Type": "application/json"
    }


async def api_request(method: str, path: str,
                      data: dict = None, params: dict = None) -> dict:
    """Make Grafana API request."""
    async with httpx.AsyncClient() as client:
        response = await client.request(
            method,
            f"{GRAFANA_URL}/api{path}",
            json=data,
            params=params,
            headers=get_headers(),
            timeout=30.0
        )

        if response.status_code >= 400:
            return {'error': response.text}

        return response.json() if response.text else {'success': True}


async def create_dashboard(title: str, panels: list,
                          folder_id: int = None) -> dict:
    """Create Grafana dashboard."""
    try:
        dashboard = {
            "dashboard": {
                "title": title,
                "panels": panels,
                "schemaVersion": 38,
                "version": 0
            },
            "overwrite": False
        }

        if folder_id:
            dashboard["folderId"] = folder_id

        result = await api_request("POST", "/dashboards/db", dashboard)

        if "error" in result:
            return result

        return {
            'uid': result.get('uid'),
            'url': result.get('url'),
            'title': title,
            'created': True
        }

    except Exception as e:
        return {'error': f'Failed to create dashboard: {str(e)}'}


async def get_dashboard(uid: str) -> dict:
    """Get dashboard by UID."""
    try:
        result = await api_request("GET", f"/dashboards/uid/{uid}")

        if "error" in result:
            return result

        dashboard = result.get('dashboard', {})

        return {
            'uid': dashboard.get('uid'),
            'title': dashboard.get('title'),
            'panels': len(dashboard.get('panels', [])),
            'tags': dashboard.get('tags', []),
            'version': dashboard.get('version'),
            'url': result.get('meta', {}).get('url')
        }

    except Exception as e:
        return {'error': f'Failed to get dashboard: {str(e)}'}


async def search_dashboards(query: str = None, tags: list = None) -> dict:
    """Search dashboards."""
    try:
        params = {'type': 'dash-db'}
        if query:
            params['query'] = query
        if tags:
            params['tag'] = tags

        result = await api_request("GET", "/search", params=params)

        if "error" in result:
            return result

        return {
            'count': len(result),
            'dashboards': [{
                'uid': d.get('uid'),
                'title': d.get('title'),
                'url': d.get('url'),
                'tags': d.get('tags', [])
            } for d in result]
        }

    except Exception as e:
        return {'error': f'Search failed: {str(e)}'}


async def create_alert_rule(name: str, query: str,
                           condition: dict, folder_uid: str = None) -> dict:
    """Create alert rule."""
    try:
        rule = {
            "name": name,
            "condition": condition.get('type', 'gt'),
            "data": [{
                "refId": "A",
                "queryType": "",
                "relativeTimeRange": {
                    "from": 600,
                    "to": 0
                },
                "model": {
                    "expr": query,
                    "refId": "A"
                }
            }],
            "noDataState": "NoData",
            "execErrState": "Error",
            "for": condition.get('for', '5m')
        }

        if folder_uid:
            rule["folderUID"] = folder_uid

        result = await api_request("POST", "/v1/provisioning/alert-rules", rule)

        if "error" in result:
            return result

        return {
            'uid': result.get('uid'),
            'name': name,
            'created': True
        }

    except Exception as e:
        return {'error': f'Failed to create alert: {str(e)}'}


async def get_alerts() -> dict:
    """Get alert instances."""
    try:
        result = await api_request("GET", "/alertmanager/grafana/api/v2/alerts")

        if "error" in result:
            return result

        return {
            'total': len(result),
            'firing': len([a for a in result if a.get('status', {}).get('state') == 'firing']),
            'alerts': [{
                'name': a.get('labels', {}).get('alertname'),
                'state': a.get('status', {}).get('state'),
                'severity': a.get('labels', {}).get('severity'),
                'summary': a.get('annotations', {}).get('summary')
            } for a in result]
        }

    except Exception as e:
        return {'error': f'Failed to get alerts: {str(e)}'}


async def query_datasource(datasource_uid: str, query: dict) -> dict:
    """Query a datasource."""
    try:
        result = await api_request(
            "POST",
            "/ds/query",
            {
                "queries": [{
                    "datasourceId": datasource_uid,
                    **query
                }]
            }
        )

        if "error" in result:
            return result

        return {
            'datasource': datasource_uid,
            'results': result.get('results', {})
        }

    except Exception as e:
        return {'error': f'Query failed: {str(e)}'}
```

## AI-Powered Dashboard Generation

Generate dashboards from natural language:

```python
# dashboard_ai.py
from gantz import MCPClient

mcp = MCPClient(config_path='gantz.yaml')


async def generate_dashboard(description: str, datasources: list = None) -> dict:
    """AI-generate dashboard from description."""
    # Parse requirements
    requirements = mcp.execute_tool('ai_parse', {
        'type': 'dashboard_requirements',
        'description': description,
        'extract': ['metrics', 'visualizations', 'layout', 'filters']
    })

    # Get available datasources if not specified
    if not datasources:
        datasources = await get_datasources()

    # Generate panel configurations
    panels = []
    for i, metric in enumerate(requirements.get('metrics', [])):
        panel = await generate_panel(
            metric,
            requirements.get('visualizations', {}).get(metric['name'], 'timeseries'),
            i,
            datasources
        )
        panels.append(panel)

    # Create dashboard
    result = mcp.execute_tool('create_dashboard', {
        'title': requirements.get('title', description[:50]),
        'panels': panels
    })

    return {
        'dashboard_uid': result.get('uid'),
        'url': result.get('url'),
        'panels_created': len(panels),
        'requirements_parsed': requirements
    }


async def generate_panel(metric: dict, viz_type: str,
                        index: int, datasources: list) -> dict:
    """Generate panel configuration."""
    # Find best datasource for metric
    datasource = find_datasource(metric.get('type', 'prometheus'), datasources)

    # Generate query
    query = mcp.execute_tool('ai_generate', {
        'type': 'grafana_query',
        'metric': metric,
        'datasource_type': datasource.get('type')
    })

    # Calculate grid position
    x = (index % 2) * 12
    y = (index // 2) * 8

    return {
        "type": viz_type,
        "title": metric.get('name'),
        "gridPos": {"x": x, "y": y, "w": 12, "h": 8},
        "datasource": {"uid": datasource.get('uid')},
        "targets": [{
            "expr": query.get('query'),
            "refId": "A"
        }],
        "options": get_viz_options(viz_type)
    }


def get_viz_options(viz_type: str) -> dict:
    """Get visualization options."""
    options = {
        'timeseries': {
            'legend': {'displayMode': 'list', 'placement': 'bottom'}
        },
        'stat': {
            'reduceOptions': {'calcs': ['lastNotNull']}
        },
        'gauge': {
            'showThresholdLabels': True
        },
        'table': {
            'showHeader': True
        }
    }
    return options.get(viz_type, {})


async def get_datasources() -> list:
    """Get available datasources."""
    result = await api_request("GET", "/datasources")
    return result if isinstance(result, list) else []


def find_datasource(metric_type: str, datasources: list) -> dict:
    """Find appropriate datasource for metric type."""
    type_mapping = {
        'prometheus': ['prometheus', 'victoriametrics'],
        'logs': ['loki', 'elasticsearch'],
        'traces': ['tempo', 'jaeger'],
        'database': ['postgres', 'mysql', 'influxdb']
    }

    preferred = type_mapping.get(metric_type, [])

    for ds in datasources:
        if ds.get('type', '').lower() in preferred:
            return ds

    return datasources[0] if datasources else {'uid': 'default'}


async def suggest_improvements(dashboard_uid: str) -> dict:
    """AI suggestions for dashboard improvements."""
    dashboard = mcp.execute_tool('get_dashboard', {'uid': dashboard_uid})

    result = mcp.execute_tool('ai_analyze', {
        'type': 'dashboard_review',
        'dashboard': dashboard,
        'evaluate': ['layout', 'queries', 'visualizations', 'alerts']
    })

    return {
        'dashboard': dashboard_uid,
        'score': result.get('score'),
        'improvements': result.get('suggestions', []),
        'missing_panels': result.get('recommended_panels', []),
        'alert_recommendations': result.get('alert_suggestions', [])
    }
```

## Alert Intelligence

Smart alert management:

```python
# alert_ai.py
from gantz import MCPClient

mcp = MCPClient()


async def optimize_alert_thresholds(alert_name: str) -> dict:
    """Optimize alert thresholds using AI."""
    # Get alert configuration
    alerts = mcp.execute_tool('get_alerts', {})

    alert = next((a for a in alerts.get('alerts', [])
                  if a.get('name') == alert_name), None)

    if not alert:
        return {'error': f'Alert {alert_name} not found'}

    # Analyze historical data
    result = mcp.execute_tool('ai_analyze', {
        'type': 'threshold_optimization',
        'alert': alert,
        'analyze': ['historical_triggers', 'noise_level', 'miss_rate']
    })

    return {
        'alert': alert_name,
        'current_threshold': result.get('current'),
        'recommended_threshold': result.get('recommended'),
        'expected_reduction': result.get('noise_reduction'),
        'confidence': result.get('confidence')
    }


async def create_smart_alerts(dashboard_uid: str) -> dict:
    """Generate smart alerts for dashboard."""
    dashboard = mcp.execute_tool('get_dashboard', {'uid': dashboard_uid})

    # AI generates alert rules
    result = mcp.execute_tool('ai_generate', {
        'type': 'alert_rules',
        'dashboard': dashboard,
        'strategies': ['anomaly', 'threshold', 'trend']
    })

    created_alerts = []
    for rule in result.get('rules', []):
        alert = mcp.execute_tool('create_alert_rule', {
            'name': rule['name'],
            'query': rule['query'],
            'condition': rule['condition']
        })
        created_alerts.append(alert)

    return {
        'dashboard': dashboard_uid,
        'alerts_created': len(created_alerts),
        'alerts': created_alerts
    }
```

## Natural Language Insights

Get insights from data:

```python
# insights.py
from gantz import MCPClient

mcp = MCPClient()


async def get_dashboard_insights(dashboard_uid: str) -> dict:
    """Get AI insights from dashboard data."""
    dashboard = mcp.execute_tool('get_dashboard', {'uid': dashboard_uid})

    # Query all panels
    panel_data = []
    for panel in dashboard.get('panels', []):
        data = await query_panel(panel)
        panel_data.append({
            'title': panel.get('title'),
            'data': data
        })

    # AI analysis
    result = mcp.execute_tool('ai_analyze', {
        'type': 'dashboard_insights',
        'panels': panel_data,
        'generate': ['summary', 'anomalies', 'trends', 'recommendations']
    })

    return {
        'dashboard': dashboard_uid,
        'summary': result.get('summary'),
        'key_findings': result.get('findings', []),
        'anomalies': result.get('anomalies', []),
        'trends': result.get('trends', []),
        'recommendations': result.get('recommendations', [])
    }


async def ask_about_data(question: str, dashboard_uid: str = None) -> dict:
    """Ask natural language questions about data."""
    result = mcp.execute_tool('ai_query', {
        'type': 'data_question',
        'question': question,
        'dashboard_uid': dashboard_uid,
        'response_format': 'conversational'
    })

    return {
        'question': question,
        'answer': result.get('answer'),
        'supporting_data': result.get('data'),
        'visualization_suggestion': result.get('viz_suggestion')
    }
```

## Deploy with Gantz CLI

Deploy your visualization automation:

```bash
# Install Gantz
npm install -g gantz

# Initialize Grafana project
gantz init --template grafana-dashboards

# Set environment variables
export GRAFANA_URL=http://grafana:3000
export GRAFANA_API_KEY=your-api-key

# Deploy
gantz deploy --platform kubernetes

# Generate dashboard from description
gantz run generate_dashboard \
  --description "Kubernetes cluster monitoring with CPU, memory, and pod metrics"
```

Build intelligent visualization at [gantz.run](https://gantz.run).

## Related Reading

- [Prometheus MCP Integration](/post/prometheus-mcp-integration/) - Metrics source
- [Datadog MCP Integration](/post/datadog-mcp-integration/) - Alternative platform
- [MCP Streaming Patterns](/post/mcp-streaming-patterns/) - Real-time dashboards

## Conclusion

Grafana and MCP create powerful AI-driven visualization systems. With automatic dashboard generation, intelligent alerts, and natural language insights, you can transform how teams understand and act on data.

Start building Grafana AI agents with Gantz today.
