+++
title = "New Relic MCP Integration: AI-Powered Application Intelligence"
image = "/images/newrelic-mcp-integration.png"
date = 2025-05-24
description = "Build intelligent observability agents with New Relic and MCP. Learn NRQL queries, AIOps, and performance optimization with Gantz."
draft = false
tags = ['newrelic', 'apm', 'observability', 'mcp', 'aiops', 'gantz']
voice = false

[howto]
name = "How To Build AI Observability with New Relic and MCP"
totalTime = 30
[[howto.steps]]
name = "Set up New Relic API"
text = "Configure New Relic API keys and account access"
[[howto.steps]]
name = "Define MCP tools"
text = "Create tool definitions for observability operations"
[[howto.steps]]
name = "Implement handlers"
text = "Build handlers for NRQL, entities, and alerts"
[[howto.steps]]
name = "Add AI capabilities"
text = "Integrate AI-powered analysis and recommendations"
[[howto.steps]]
name = "Deploy with Gantz"
text = "Deploy your observability automation using Gantz CLI"
+++

New Relic provides comprehensive observability with powerful querying capabilities. With MCP integration, you can build AI agents that analyze performance, detect anomalies, and provide intelligent insights across your stack.

## Why New Relic MCP Integration?

AI-powered New Relic enables:

- **NRQL generation**: Natural language to NRQL
- **AIOps integration**: Intelligent alerting and correlation
- **Entity analysis**: AI-driven service health assessment
- **Performance optimization**: ML-based recommendations
- **Incident intelligence**: Automated root cause analysis

## New Relic MCP Tool Definition

Configure New Relic tools in Gantz:

```yaml
# gantz.yaml
name: newrelic-mcp-tools
version: 1.0.0

tools:
  nrql_query:
    description: "Execute NRQL query"
    parameters:
      query:
        type: string
        required: true
      account_id:
        type: integer
    handler: newrelic.nrql_query

  get_entities:
    description: "Get monitored entities"
    parameters:
      entity_type:
        type: string
      name:
        type: string
    handler: newrelic.get_entities

  get_entity_health:
    description: "Get entity health status"
    parameters:
      entity_guid:
        type: string
        required: true
    handler: newrelic.get_entity_health

  get_alerts:
    description: "Get alert conditions and incidents"
    parameters:
      policy_id:
        type: integer
    handler: newrelic.get_alerts

  create_alert_condition:
    description: "Create NRQL alert condition"
    parameters:
      policy_id:
        type: integer
        required: true
      name:
        type: string
        required: true
      query:
        type: string
        required: true
      threshold:
        type: object
        required: true
    handler: newrelic.create_alert_condition

  natural_query:
    description: "Query using natural language"
    parameters:
      question:
        type: string
        required: true
    handler: newrelic.natural_query

  analyze_service:
    description: "AI analysis of service performance"
    parameters:
      service_name:
        type: string
        required: true
    handler: newrelic.analyze_service
```

## Handler Implementation

Build New Relic operation handlers:

```python
# handlers/newrelic.py
import httpx
import os

NEWRELIC_API = "https://api.newrelic.com"
NERDGRAPH_API = "https://api.newrelic.com/graphql"
API_KEY = os.environ['NEWRELIC_API_KEY']
ACCOUNT_ID = os.environ.get('NEWRELIC_ACCOUNT_ID')


def get_headers():
    """Get authorization headers."""
    return {
        "API-Key": API_KEY,
        "Content-Type": "application/json"
    }


async def nerdgraph_query(query: str, variables: dict = None) -> dict:
    """Execute NerdGraph GraphQL query."""
    async with httpx.AsyncClient() as client:
        response = await client.post(
            NERDGRAPH_API,
            json={"query": query, "variables": variables or {}},
            headers=get_headers(),
            timeout=30.0
        )

        result = response.json()

        if result.get('errors'):
            return {'error': result['errors'][0].get('message')}

        return result.get('data', {})


async def nrql_query(query: str, account_id: int = None) -> dict:
    """Execute NRQL query."""
    try:
        account = account_id or ACCOUNT_ID

        gql = """
        query($accountId: Int!, $nrql: Nrql!) {
            actor {
                account(id: $accountId) {
                    nrql(query: $nrql) {
                        results
                    }
                }
            }
        }
        """

        result = await nerdgraph_query(gql, {
            'accountId': int(account),
            'nrql': query
        })

        if 'error' in result:
            return result

        results = result.get('actor', {}).get('account', {}).get('nrql', {}).get('results', [])

        return {
            'query': query,
            'count': len(results),
            'results': results
        }

    except Exception as e:
        return {'error': f'NRQL query failed: {str(e)}'}


async def get_entities(entity_type: str = None, name: str = None) -> dict:
    """Get monitored entities."""
    try:
        query_filter = ""
        if entity_type:
            query_filter += f" type = '{entity_type}'"
        if name:
            if query_filter:
                query_filter += " AND"
            query_filter += f" name LIKE '%{name}%'"

        gql = f"""
        {{
            actor {{
                entitySearch(query: "{query_filter}") {{
                    results {{
                        entities {{
                            guid
                            name
                            entityType
                            domain
                            alertSeverity
                        }}
                    }}
                }}
            }}
        }}
        """

        result = await nerdgraph_query(gql)

        if 'error' in result:
            return result

        entities = result.get('actor', {}).get('entitySearch', {}).get('results', {}).get('entities', [])

        return {
            'count': len(entities),
            'entities': [{
                'guid': e.get('guid'),
                'name': e.get('name'),
                'type': e.get('entityType'),
                'domain': e.get('domain'),
                'alert_severity': e.get('alertSeverity')
            } for e in entities]
        }

    except Exception as e:
        return {'error': f'Failed to get entities: {str(e)}'}


async def get_entity_health(entity_guid: str) -> dict:
    """Get entity health status."""
    try:
        gql = """
        query($guid: EntityGuid!) {
            actor {
                entity(guid: $guid) {
                    name
                    entityType
                    alertSeverity
                    ... on ApmApplicationEntity {
                        apmSummary {
                            throughput
                            responseTimeAverage
                            errorRate
                            apdexScore
                        }
                    }
                }
            }
        }
        """

        result = await nerdgraph_query(gql, {'guid': entity_guid})

        if 'error' in result:
            return result

        entity = result.get('actor', {}).get('entity', {})
        summary = entity.get('apmSummary', {})

        return {
            'guid': entity_guid,
            'name': entity.get('name'),
            'type': entity.get('entityType'),
            'alert_severity': entity.get('alertSeverity'),
            'metrics': {
                'throughput': summary.get('throughput'),
                'response_time': summary.get('responseTimeAverage'),
                'error_rate': summary.get('errorRate'),
                'apdex': summary.get('apdexScore')
            }
        }

    except Exception as e:
        return {'error': f'Failed to get health: {str(e)}'}


async def get_alerts(policy_id: int = None) -> dict:
    """Get alert conditions and incidents."""
    try:
        # Get open incidents
        gql = """
        {
            actor {
                account(id: %s) {
                    nrql(query: "SELECT * FROM NrAiIncident WHERE event = 'open' SINCE 1 day ago") {
                        results
                    }
                }
            }
        }
        """ % ACCOUNT_ID

        result = await nerdgraph_query(gql)

        if 'error' in result:
            return result

        incidents = result.get('actor', {}).get('account', {}).get('nrql', {}).get('results', [])

        return {
            'open_incidents': len(incidents),
            'incidents': [{
                'id': i.get('incidentId'),
                'title': i.get('title'),
                'priority': i.get('priority'),
                'state': i.get('state'),
                'opened_at': i.get('openTime')
            } for i in incidents]
        }

    except Exception as e:
        return {'error': f'Failed to get alerts: {str(e)}'}


async def create_alert_condition(policy_id: int, name: str,
                                query: str, threshold: dict) -> dict:
    """Create NRQL alert condition."""
    try:
        gql = """
        mutation($accountId: Int!, $policyId: ID!, $condition: AlertsNrqlConditionStaticInput!) {
            alertsNrqlConditionStaticCreate(
                accountId: $accountId
                policyId: $policyId
                condition: $condition
            ) {
                id
                name
            }
        }
        """

        result = await nerdgraph_query(gql, {
            'accountId': int(ACCOUNT_ID),
            'policyId': str(policy_id),
            'condition': {
                'name': name,
                'nrql': {'query': query},
                'terms': [{
                    'threshold': threshold.get('value'),
                    'thresholdDuration': threshold.get('duration', 300),
                    'thresholdOccurrences': 'AT_LEAST_ONCE',
                    'operator': threshold.get('operator', 'ABOVE'),
                    'priority': 'CRITICAL'
                }],
                'enabled': True
            }
        })

        if 'error' in result:
            return result

        condition = result.get('alertsNrqlConditionStaticCreate', {})

        return {
            'id': condition.get('id'),
            'name': name,
            'created': True
        }

    except Exception as e:
        return {'error': f'Failed to create condition: {str(e)}'}
```

## AI-Powered Analysis

Build intelligent observability:

```python
# newrelic_ai.py
from gantz import MCPClient

mcp = MCPClient(config_path='gantz.yaml')


async def natural_query(question: str) -> dict:
    """Query using natural language."""
    # Generate NRQL from natural language
    parsed = mcp.execute_tool('ai_parse', {
        'type': 'nrql',
        'question': question,
        'context': {
            'available_events': ['Transaction', 'SystemSample', 'Log', 'Metric'],
            'common_attributes': ['appName', 'host', 'duration', 'error']
        }
    })

    nrql = parsed.get('query')

    # Execute query
    result = mcp.execute_tool('nrql_query', {'query': nrql})

    # Generate response
    response = mcp.execute_tool('ai_generate', {
        'type': 'nrql_response',
        'question': question,
        'query': nrql,
        'data': result.get('results', [])
    })

    return {
        'question': question,
        'nrql': nrql,
        'answer': response.get('answer'),
        'data': result.get('results', [])
    }


async def analyze_service(service_name: str) -> dict:
    """AI analysis of service performance."""
    # Get entity
    entities = mcp.execute_tool('get_entities', {
        'entity_type': 'APM_APPLICATION',
        'name': service_name
    })

    if not entities.get('entities'):
        return {'error': f'Service {service_name} not found'}

    entity = entities['entities'][0]

    # Get health metrics
    health = mcp.execute_tool('get_entity_health', {
        'entity_guid': entity['guid']
    })

    # Get transaction data
    transactions = mcp.execute_tool('nrql_query', {
        'query': f"SELECT average(duration), count(*), percentage(count(*), WHERE error IS true) FROM Transaction WHERE appName = '{service_name}' SINCE 1 hour ago FACET name LIMIT 20"
    })

    # Get error data
    errors = mcp.execute_tool('nrql_query', {
        'query': f"SELECT count(*) FROM TransactionError WHERE appName = '{service_name}' SINCE 1 hour ago FACET `error.message` LIMIT 10"
    })

    # AI analysis
    result = mcp.execute_tool('ai_analyze', {
        'type': 'service_analysis',
        'service': service_name,
        'health': health.get('metrics'),
        'transactions': transactions.get('results', []),
        'errors': errors.get('results', []),
        'analyze': ['performance', 'errors', 'bottlenecks', 'recommendations']
    })

    return {
        'service': service_name,
        'health_score': result.get('health_score'),
        'status': result.get('status'),
        'key_metrics': health.get('metrics'),
        'top_transactions': result.get('top_transactions', []),
        'error_summary': result.get('error_summary'),
        'bottlenecks': result.get('bottlenecks', []),
        'recommendations': result.get('recommendations', [])
    }


async def detect_anomalies(entity_guid: str) -> dict:
    """Detect anomalies in entity behavior."""
    # Get historical data
    health = mcp.execute_tool('get_entity_health', {'entity_guid': entity_guid})

    historical = mcp.execute_tool('nrql_query', {
        'query': f"SELECT average(duration), average(throughput), percentage(count(*), WHERE error) FROM Transaction WHERE entityGuid = '{entity_guid}' SINCE 7 days ago TIMESERIES 1 hour"
    })

    # AI anomaly detection
    result = mcp.execute_tool('ai_detect_anomalies', {
        'data': historical.get('results', []),
        'current': health.get('metrics'),
        'sensitivity': 'medium'
    })

    return {
        'entity_guid': entity_guid,
        'anomalies_detected': len(result.get('anomalies', [])),
        'anomalies': result.get('anomalies', []),
        'severity': result.get('max_severity'),
        'recommendations': result.get('recommendations', [])
    }
```

## Alert Optimization

Optimize alert configurations:

```python
# alert_optimization.py
from gantz import MCPClient

mcp = MCPClient()


async def optimize_alerts(policy_id: int) -> dict:
    """Optimize alert thresholds."""
    # Get current alerts
    alerts = mcp.execute_tool('get_alerts', {'policy_id': policy_id})

    optimizations = []

    for alert in alerts.get('incidents', []):
        # Analyze alert history
        result = mcp.execute_tool('ai_analyze', {
            'type': 'alert_optimization',
            'alert': alert,
            'analyze': ['noise', 'threshold', 'conditions']
        })

        if result.get('recommendations'):
            optimizations.append({
                'alert_id': alert['id'],
                'current_threshold': result.get('current'),
                'recommended': result.get('recommended'),
                'expected_reduction': result.get('noise_reduction')
            })

    return {
        'policy_id': policy_id,
        'alerts_analyzed': len(alerts.get('incidents', [])),
        'optimizations': optimizations
    }
```

## Deploy with Gantz CLI

Deploy your New Relic automation:

```bash
# Install Gantz
npm install -g gantz

# Initialize New Relic project
gantz init --template newrelic-observability

# Set environment variables
export NEWRELIC_API_KEY=your-api-key
export NEWRELIC_ACCOUNT_ID=your-account-id

# Deploy
gantz deploy --platform kubernetes

# Natural language query
gantz run natural_query \
  --question "What is the average response time for the checkout service?"

# Analyze service
gantz run analyze_service --service-name checkout-service
```

Build intelligent observability at [gantz.run](https://gantz.run).

## Related Reading

- [Datadog MCP Integration](/post/datadog-mcp-integration/) - Alternative platform
- [Prometheus MCP Integration](/post/prometheus-mcp-integration/) - Open-source metrics
- [Sentry MCP Integration](/post/sentry-mcp-integration/) - Error tracking

## Conclusion

New Relic and MCP create powerful AI-driven observability systems. With natural language queries, intelligent analysis, and automated alert optimization, you can transform how you monitor and manage applications.

Start building New Relic AI agents with Gantz today.
