+++
title = "Azure Functions MCP Integration: Build AI Agents on Microsoft Cloud"
image = "images/azure-functions-mcp.webp"
date = 2025-05-03
description = "Deploy MCP-powered AI agents on Azure Functions. Learn durable functions, event hubs integration, and Azure AI services with Gantz."
summary = "Microsoft shop? Deploy AI agents on Azure Functions with enterprise-grade infrastructure. Use Durable Functions for long-running orchestrations that survive restarts, connect to Event Hubs for real-time event processing, integrate with Azure AI services and Cosmos DB. Full Azure ecosystem integration with pay-per-execution pricing."
draft = false
tags = ['azure', 'azure-functions', 'serverless', 'mcp', 'microsoft', 'gantz']
voice = false

[howto]
name = "How To Build AI Agents with Azure Functions and MCP"
totalTime = 35
[[howto.steps]]
name = "Create Azure Function"
text = "Set up Azure Function App with Python or Node.js runtime"
[[howto.steps]]
name = "Define MCP tools"
text = "Create tool definitions for Azure Functions operations"
[[howto.steps]]
name = "Implement Durable Functions"
text = "Build orchestrations for complex AI workflows"
[[howto.steps]]
name = "Configure triggers"
text = "Set up HTTP, Queue, or Event Hub triggers"
[[howto.steps]]
name = "Deploy with Gantz"
text = "Deploy AI agents to Azure using Gantz CLI"
+++

Azure Functions provides enterprise-grade serverless computing for MCP-powered AI agents. This guide covers building robust AI workflows with Azure's durable functions, event hubs, and AI services integration.

## Why Azure Functions for MCP?

Azure offers compelling features for AI agents:

- **Durable Functions**: Complex orchestrations with state management
- **Event Hubs**: High-throughput event ingestion
- **Azure OpenAI**: Native integration with GPT models
- **Enterprise security**: Azure AD, Key Vault, managed identities
- **Hybrid support**: Connect to on-premises resources

## Azure Functions MCP Tool Definition

Configure Azure-based tools in Gantz:

```yaml
# gantz.yaml
name: azure-functions-tools
version: 1.0.0

tools:
  invoke_function:
    description: "Invoke Azure Function"
    parameters:
      function_app:
        type: string
        description: "Function App name"
        required: true
      function_name:
        type: string
        description: "Function name"
        required: true
      data:
        type: object
        description: "Request payload"
        required: true
      method:
        type: string
        default: "POST"
    handler: azure_functions.invoke

  list_functions:
    description: "List functions in Function App"
    parameters:
      function_app:
        type: string
        required: true
      resource_group:
        type: string
        required: true
    handler: azure_functions.list_functions

  start_orchestration:
    description: "Start Durable Function orchestration"
    parameters:
      function_app:
        type: string
        required: true
      orchestrator_name:
        type: string
        required: true
      input_data:
        type: object
        required: true
    handler: azure_functions.start_orchestration

  get_orchestration_status:
    description: "Get orchestration instance status"
    parameters:
      function_app:
        type: string
        required: true
      instance_id:
        type: string
        required: true
    handler: azure_functions.get_orchestration_status

  send_event_hub:
    description: "Send event to Azure Event Hub"
    parameters:
      namespace:
        type: string
        required: true
      event_hub:
        type: string
        required: true
      events:
        type: array
        description: "List of events to send"
        required: true
    handler: azure_functions.send_event_hub
```

## Handler Implementation

Build handlers for Azure Functions operations:

```python
# handlers/azure_functions.py
import json
import aiohttp
from azure.identity import DefaultAzureCredential
from azure.mgmt.web import WebSiteManagementClient
from azure.eventhub import EventHubProducerClient, EventData
from azure.eventhub.aio import EventHubProducerClient as AsyncEventHubProducer

# Cache credentials
_credential = None
_web_client = None


def get_credential():
    """Get Azure credential."""
    global _credential
    if _credential is None:
        _credential = DefaultAzureCredential()
    return _credential


def get_web_client(subscription_id: str):
    """Get Web Site Management client."""
    global _web_client
    if _web_client is None:
        _web_client = WebSiteManagementClient(
            get_credential(),
            subscription_id
        )
    return _web_client


async def invoke(function_app: str, function_name: str,
                data: dict, method: str = 'POST') -> dict:
    """Invoke Azure Function via HTTP."""
    url = f'https://{function_app}.azurewebsites.net/api/{function_name}'

    try:
        async with aiohttp.ClientSession() as session:
            # Get function key if needed
            headers = {'Content-Type': 'application/json'}

            async with session.request(
                method,
                url,
                json=data,
                headers=headers,
                timeout=aiohttp.ClientTimeout(total=60)
            ) as response:

                response_text = await response.text()

                try:
                    response_data = json.loads(response_text)
                except json.JSONDecodeError:
                    response_data = response_text

                return {
                    'status_code': response.status,
                    'response': response_data,
                    'headers': dict(response.headers)
                }

    except aiohttp.ClientError as e:
        return {'error': f'Request failed: {str(e)}'}
    except Exception as e:
        return {'error': f'Invocation error: {str(e)}'}


async def list_functions(function_app: str,
                         resource_group: str,
                         subscription_id: str = None) -> dict:
    """List functions in Function App."""
    import os
    subscription_id = subscription_id or os.environ.get('AZURE_SUBSCRIPTION_ID')

    client = get_web_client(subscription_id)

    try:
        functions = []

        # Get functions
        result = client.web_apps.list_functions(
            resource_group,
            function_app
        )

        for func in result:
            functions.append({
                'name': func.name.split('/')[-1],
                'trigger_type': func.config.get('bindings', [{}])[0].get('type'),
                'is_disabled': func.is_disabled,
                'language': func.language
            })

        return {
            'function_app': function_app,
            'count': len(functions),
            'functions': functions
        }

    except Exception as e:
        return {'error': f'Failed to list functions: {str(e)}'}


async def start_orchestration(function_app: str,
                             orchestrator_name: str,
                             input_data: dict) -> dict:
    """Start Durable Function orchestration."""
    url = (f'https://{function_app}.azurewebsites.net'
           f'/runtime/webhooks/durabletask/orchestrators/{orchestrator_name}')

    try:
        async with aiohttp.ClientSession() as session:
            async with session.post(
                url,
                json=input_data,
                headers={'Content-Type': 'application/json'}
            ) as response:

                if response.status in [200, 202]:
                    result = await response.json()
                    return {
                        'instance_id': result.get('id'),
                        'status_url': result.get('statusQueryGetUri'),
                        'terminate_url': result.get('terminatePostUri'),
                        'message': 'Orchestration started'
                    }
                else:
                    return {
                        'error': f'Failed to start: {await response.text()}'
                    }

    except Exception as e:
        return {'error': f'Orchestration error: {str(e)}'}


async def get_orchestration_status(function_app: str,
                                   instance_id: str) -> dict:
    """Get orchestration instance status."""
    url = (f'https://{function_app}.azurewebsites.net'
           f'/runtime/webhooks/durabletask/instances/{instance_id}')

    try:
        async with aiohttp.ClientSession() as session:
            async with session.get(url) as response:
                if response.status == 200:
                    result = await response.json()
                    return {
                        'instance_id': result.get('instanceId'),
                        'runtime_status': result.get('runtimeStatus'),
                        'input': result.get('input'),
                        'output': result.get('output'),
                        'created_time': result.get('createdTime'),
                        'last_updated': result.get('lastUpdatedTime')
                    }
                elif response.status == 404:
                    return {'error': f'Instance {instance_id} not found'}
                else:
                    return {'error': await response.text()}

    except Exception as e:
        return {'error': f'Status check failed: {str(e)}'}


async def send_event_hub(namespace: str, event_hub: str,
                        events: list) -> dict:
    """Send events to Azure Event Hub."""
    connection_str = (
        f'Endpoint=sb://{namespace}.servicebus.windows.net/;'
        f'SharedAccessKeyName=RootManageSharedAccessKey;'
        f'SharedAccessKey=<your-key>'
    )

    try:
        async with AsyncEventHubProducer.from_connection_string(
            connection_str,
            eventhub_name=event_hub
        ) as producer:

            event_data_batch = await producer.create_batch()

            for event in events:
                event_data = EventData(json.dumps(event))
                event_data_batch.add(event_data)

            await producer.send_batch(event_data_batch)

            return {
                'namespace': namespace,
                'event_hub': event_hub,
                'events_sent': len(events),
                'status': 'success'
            }

    except Exception as e:
        return {'error': f'Event Hub send failed: {str(e)}'}
```

## Durable Functions for AI Workflows

Build complex orchestrations for AI agents:

```python
# orchestrators.py
import azure.functions as func
import azure.durable_functions as df
from gantz import MCPClient

mcp = MCPClient()


def orchestrator_function(context: df.DurableOrchestrationContext):
    """Main orchestrator for multi-step AI workflow."""
    input_data = context.get_input()

    # Step 1: Analyze input
    analysis = yield context.call_activity(
        'analyze_input',
        input_data
    )

    # Step 2: Process in parallel
    parallel_tasks = []
    for item in analysis.get('items', []):
        task = context.call_activity('process_item', item)
        parallel_tasks.append(task)

    results = yield context.task_all(parallel_tasks)

    # Step 3: Aggregate results
    final_result = yield context.call_activity(
        'aggregate_results',
        {'results': results, 'context': input_data}
    )

    return final_result


main = df.Orchestrator.create(orchestrator_function)


# Activity functions
def analyze_input(input_data: dict) -> dict:
    """Analyze input using MCP tool."""
    return mcp.execute_tool('analyze', input_data)


def process_item(item: dict) -> dict:
    """Process individual item with AI."""
    return mcp.execute_tool('process', item)


def aggregate_results(data: dict) -> dict:
    """Aggregate all results."""
    return mcp.execute_tool('aggregate', data)
```

## Azure Function Entry Point

Create the function that processes MCP requests:

```python
# function_app.py
import azure.functions as func
import json
from gantz import MCPClient

app = func.FunctionApp()
mcp = MCPClient(config_path='gantz.yaml')


@app.function_name(name="MCPAgent")
@app.route(route="agent", methods=["POST"])
async def mcp_agent(req: func.HttpRequest) -> func.HttpResponse:
    """HTTP triggered function for MCP tool execution."""
    try:
        body = req.get_json()

        tool_name = body.get('tool')
        parameters = body.get('parameters', {})

        if not tool_name:
            return func.HttpResponse(
                json.dumps({'error': 'Tool name required'}),
                status_code=400,
                mimetype='application/json'
            )

        result = mcp.execute_tool(tool_name, parameters)

        return func.HttpResponse(
            json.dumps(result),
            status_code=200,
            mimetype='application/json'
        )

    except Exception as e:
        return func.HttpResponse(
            json.dumps({'error': str(e)}),
            status_code=500,
            mimetype='application/json'
        )


@app.function_name(name="QueueAgent")
@app.queue_trigger(
    arg_name="msg",
    queue_name="mcp-tasks",
    connection="AzureWebJobsStorage"
)
async def queue_agent(msg: func.QueueMessage) -> None:
    """Queue triggered function for async processing."""
    message = json.loads(msg.get_body().decode('utf-8'))

    tool_name = message.get('tool')
    parameters = message.get('parameters', {})

    result = mcp.execute_tool(tool_name, parameters)

    # Store result or send notification
    await store_result(msg.id, result)


@app.function_name(name="EventHubAgent")
@app.event_hub_message_trigger(
    arg_name="events",
    event_hub_name="mcp-events",
    connection="EventHubConnection"
)
async def eventhub_agent(events: list[func.EventHubEvent]) -> None:
    """Event Hub triggered function for high-throughput processing."""
    for event in events:
        data = json.loads(event.get_body().decode('utf-8'))

        result = mcp.execute_tool(
            data.get('tool'),
            data.get('parameters', {})
        )

        print(f'Processed event: {event.sequence_number}')


@app.function_name(name="TimerAgent")
@app.timer_trigger(
    schedule="0 */5 * * * *",  # Every 5 minutes
    arg_name="timer"
)
async def timer_agent(timer: func.TimerRequest) -> None:
    """Timer triggered function for scheduled tasks."""
    if timer.past_due:
        print('Timer is running late!')

    # Execute scheduled MCP tools
    result = mcp.execute_tool('scheduled_task', {
        'timestamp': timer.schedule_status.last.isoformat()
    })

    print(f'Scheduled task result: {result}')
```

## Azure OpenAI Integration

Integrate with Azure OpenAI services:

```python
# azure_openai_integration.py
from openai import AzureOpenAI
import os


def get_azure_openai_client():
    """Get Azure OpenAI client."""
    return AzureOpenAI(
        api_key=os.environ['AZURE_OPENAI_KEY'],
        api_version="2024-02-15-preview",
        azure_endpoint=os.environ['AZURE_OPENAI_ENDPOINT']
    )


async def chat_completion(
    messages: list,
    deployment: str = 'gpt-4',
    temperature: float = 0.7
) -> dict:
    """Get chat completion from Azure OpenAI."""
    client = get_azure_openai_client()

    response = client.chat.completions.create(
        model=deployment,
        messages=messages,
        temperature=temperature
    )

    return {
        'content': response.choices[0].message.content,
        'usage': {
            'prompt_tokens': response.usage.prompt_tokens,
            'completion_tokens': response.usage.completion_tokens
        },
        'finish_reason': response.choices[0].finish_reason
    }


async def embedding(text: str, deployment: str = 'text-embedding-ada-002') -> dict:
    """Get embeddings from Azure OpenAI."""
    client = get_azure_openai_client()

    response = client.embeddings.create(
        input=text,
        model=deployment
    )

    return {
        'embedding': response.data[0].embedding,
        'tokens': response.usage.total_tokens
    }
```

## Managed Identity Authentication

Secure your functions with managed identity:

```python
# managed_identity.py
from azure.identity import ManagedIdentityCredential
from azure.keyvault.secrets import SecretClient


def get_secret(vault_url: str, secret_name: str) -> str:
    """Get secret from Key Vault using managed identity."""
    credential = ManagedIdentityCredential()
    client = SecretClient(vault_url=vault_url, credential=credential)

    secret = client.get_secret(secret_name)
    return secret.value


def get_storage_connection():
    """Get storage connection using managed identity."""
    credential = ManagedIdentityCredential()

    from azure.storage.blob import BlobServiceClient

    account_url = "https://yourstorageaccount.blob.core.windows.net"
    return BlobServiceClient(account_url, credential=credential)
```

## ARM Template Deployment

Deploy infrastructure as code:

```json
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "functionAppName": {
      "type": "string",
      "metadata": {
        "description": "Name of the Function App"
      }
    }
  },
  "resources": [
    {
      "type": "Microsoft.Web/sites",
      "apiVersion": "2022-03-01",
      "name": "[parameters('functionAppName')]",
      "location": "[resourceGroup().location]",
      "kind": "functionapp,linux",
      "identity": {
        "type": "SystemAssigned"
      },
      "properties": {
        "reserved": true,
        "siteConfig": {
          "linuxFxVersion": "Python|3.11",
          "appSettings": [
            {
              "name": "GANTZ_ENABLED",
              "value": "true"
            },
            {
              "name": "FUNCTIONS_WORKER_RUNTIME",
              "value": "python"
            }
          ]
        }
      }
    }
  ]
}
```

## Application Insights Monitoring

Track function performance:

```python
# monitoring.py
from opencensus.ext.azure import metrics_exporter
from opencensus.stats import aggregation, measure, stats, view
import time

# Set up exporter
exporter = metrics_exporter.new_metrics_exporter(
    connection_string='InstrumentationKey=your-key'
)

# Create measures
tool_latency = measure.MeasureFloat(
    'tool_latency',
    'MCP tool execution latency',
    'ms'
)

tool_count = measure.MeasureInt(
    'tool_count',
    'Number of tool executions',
    'count'
)

# Create views
latency_view = view.View(
    'mcp/tool_latency',
    'Tool execution latency',
    ['tool_name', 'status'],
    tool_latency,
    aggregation.DistributionAggregation([0, 100, 500, 1000, 5000])
)

count_view = view.View(
    'mcp/tool_count',
    'Tool execution count',
    ['tool_name', 'status'],
    tool_count,
    aggregation.CountAggregation()
)

# Register views
stats.stats.view_manager.register_view(latency_view)
stats.stats.view_manager.register_view(count_view)
stats.stats.view_manager.register_exporter(exporter)


def track_tool_execution(tool_name: str):
    """Decorator to track tool execution."""
    def decorator(func):
        async def wrapper(*args, **kwargs):
            start = time.time()
            status = 'success'

            try:
                result = await func(*args, **kwargs)
                return result
            except Exception as e:
                status = 'error'
                raise
            finally:
                duration = (time.time() - start) * 1000

                mmap = stats.stats.stats_recorder.new_measurement_map()
                tmap = mmap.tag_context

                tmap.insert('tool_name', tool_name)
                tmap.insert('status', status)

                mmap.measure_float_put(tool_latency, duration)
                mmap.measure_int_put(tool_count, 1)
                mmap.record()

        return wrapper
    return decorator
```

## Deploy with Gantz CLI

Deploy your Azure Functions:

```bash
# Install Gantz
npm install -g gantz

# Initialize Azure project
gantz init --template azure-functions

# Login to Azure
az login

# Deploy to Azure
gantz deploy --platform azure --resource-group my-rg

# Test function
gantz run invoke_function \
  --function-app my-func-app \
  --function-name MCPAgent \
  --data '{"action": "test"}'
```

Build enterprise AI agents on Azure at [gantz.run](https://gantz.run).

## Related Reading

- [AWS Lambda MCP Integration](/post/aws-lambda-mcp/) - Compare with AWS serverless
- [GCP Functions MCP Integration](/post/gcp-functions-mcp/) - Compare with Google Cloud
- [MCP Circuit Breakers](/post/mcp-circuit-breakers/) - Handle Azure failures gracefully

## Conclusion

Azure Functions provides enterprise-grade capabilities for MCP-powered AI agents. With durable functions for orchestration, Event Hubs for high-throughput processing, and Azure OpenAI integration, you can build sophisticated AI workflows that meet enterprise requirements.

Start deploying MCP tools to Azure with Gantz today.
