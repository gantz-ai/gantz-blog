+++
title = "Google Cloud Functions MCP Integration: Serverless AI Agents on GCP"
image = "images/gcp-functions-mcp.webp"
date = 2025-05-02
description = "Build and deploy MCP-powered AI agents on Google Cloud Functions. Learn event-driven architecture, Cloud Run integration, and GCP best practices with Gantz."
summary = "Deploy serverless MCP-powered AI agents on Google Cloud Functions with HTTP, Pub/Sub, and Cloud Storage triggers for event-driven architectures. This guide covers handler implementations for function invocation and deployment, Vertex AI integration with Gemini models, Cloud Run compatibility for Gen 2 functions, custom metrics with Cloud Monitoring, and Cloud Scheduler for periodic tasks."
draft = false
tags = ['gcp', 'cloud-functions', 'serverless', 'mcp', 'google-cloud', 'gantz']
voice = false

[howto]
name = "How To Deploy AI Agents on Google Cloud Functions with MCP"
totalTime = 35
[[howto.steps]]
name = "Set up Cloud Function"
text = "Configure Google Cloud Function with appropriate runtime and triggers"
[[howto.steps]]
name = "Define MCP tools"
text = "Create tool definitions for Cloud Functions operations"
[[howto.steps]]
name = "Implement handlers"
text = "Build Python handlers for serverless MCP execution"
[[howto.steps]]
name = "Configure triggers"
text = "Set up HTTP, Pub/Sub, or Cloud Storage triggers"
[[howto.steps]]
name = "Deploy with Gantz"
text = "Deploy and manage your serverless AI agents using Gantz CLI"
+++

Google Cloud Functions provides a serverless platform for deploying MCP-powered AI agents. This guide covers building event-driven AI workflows that integrate seamlessly with the GCP ecosystem.

## Why Google Cloud Functions for MCP?

GCP offers unique advantages for AI agent deployment:

- **Native Vertex AI integration**: Direct access to Google's AI services
- **Cloud Run compatibility**: Same code runs on both platforms
- **Pub/Sub triggers**: Robust event-driven architecture
- **BigQuery integration**: Process large datasets easily
- **Global load balancing**: Automatic traffic distribution

## Cloud Functions MCP Tool Definition

Configure GCP-based tools in Gantz:

```yaml
# gantz.yaml
name: gcp-functions-tools
version: 1.0.0

tools:
  invoke_function:
    description: "Invoke Google Cloud Function"
    parameters:
      project_id:
        type: string
        description: "GCP project ID"
        required: true
      region:
        type: string
        description: "Function region"
        default: "us-central1"
      function_name:
        type: string
        description: "Function name"
        required: true
      data:
        type: object
        description: "Request payload"
        required: true
    handler: gcp_functions.invoke

  list_functions:
    description: "List Cloud Functions in project"
    parameters:
      project_id:
        type: string
        required: true
      region:
        type: string
        default: "us-central1"
    handler: gcp_functions.list_functions

  get_function_logs:
    description: "Retrieve function logs from Cloud Logging"
    parameters:
      project_id:
        type: string
        required: true
      function_name:
        type: string
        required: true
      minutes:
        type: integer
        default: 30
    handler: gcp_functions.get_logs

  deploy_function:
    description: "Deploy new Cloud Function"
    parameters:
      project_id:
        type: string
        required: true
      function_name:
        type: string
        required: true
      source_dir:
        type: string
        description: "Path to source code"
        required: true
      runtime:
        type: string
        default: "python311"
      entry_point:
        type: string
        required: true
      trigger_type:
        type: string
        description: "http, pubsub, or storage"
        default: "http"
      memory:
        type: string
        default: "256MB"
    handler: gcp_functions.deploy

  publish_pubsub:
    description: "Publish message to Pub/Sub topic"
    parameters:
      project_id:
        type: string
        required: true
      topic:
        type: string
        required: true
      message:
        type: object
        required: true
    handler: gcp_functions.publish_pubsub
```

## Handler Implementation

Build handlers for Cloud Functions operations:

```python
# handlers/gcp_functions.py
import json
import base64
from datetime import datetime, timedelta
from google.cloud import functions_v2
from google.cloud import logging_v2
from google.cloud import pubsub_v1
from google.api_core import exceptions
import requests

# Reuse clients for performance
_functions_client = None
_logging_client = None
_publisher = None


def get_functions_client():
    """Get or create Functions client."""
    global _functions_client
    if _functions_client is None:
        _functions_client = functions_v2.FunctionServiceClient()
    return _functions_client


def get_logging_client():
    """Get or create Logging client."""
    global _logging_client
    if _logging_client is None:
        _logging_client = logging_v2.Client()
    return _logging_client


def get_publisher():
    """Get or create Pub/Sub publisher."""
    global _publisher
    if _publisher is None:
        _publisher = pubsub_v1.PublisherClient()
    return _publisher


async def invoke(project_id: str, function_name: str,
                 data: dict, region: str = 'us-central1') -> dict:
    """Invoke Cloud Function via HTTP."""
    client = get_functions_client()

    # Get function details
    name = f'projects/{project_id}/locations/{region}/functions/{function_name}'

    try:
        function = client.get_function(name=name)

        # Get function URL
        if function.service_config.uri:
            url = function.service_config.uri
        else:
            return {'error': 'Function does not have an HTTP endpoint'}

        # Invoke function
        response = requests.post(
            url,
            json=data,
            headers={'Content-Type': 'application/json'},
            timeout=60
        )

        return {
            'status_code': response.status_code,
            'response': response.json() if response.headers.get(
                'content-type', ''
            ).startswith('application/json') else response.text,
            'execution_id': response.headers.get('Function-Execution-Id')
        }

    except exceptions.NotFound:
        return {'error': f'Function {function_name} not found'}
    except requests.exceptions.Timeout:
        return {'error': 'Function invocation timed out'}
    except Exception as e:
        return {'error': f'Invocation failed: {str(e)}'}


async def list_functions(project_id: str,
                         region: str = 'us-central1') -> dict:
    """List Cloud Functions in project."""
    client = get_functions_client()
    parent = f'projects/{project_id}/locations/{region}'

    try:
        functions = []
        request = functions_v2.ListFunctionsRequest(parent=parent)

        for func in client.list_functions(request=request):
            functions.append({
                'name': func.name.split('/')[-1],
                'state': func.state.name,
                'runtime': func.build_config.runtime,
                'entry_point': func.build_config.entry_point,
                'memory': func.service_config.available_memory,
                'timeout': func.service_config.timeout_seconds,
                'url': func.service_config.uri,
                'update_time': func.update_time.isoformat() if func.update_time else None
            })

        return {
            'project': project_id,
            'region': region,
            'count': len(functions),
            'functions': functions
        }

    except Exception as e:
        return {'error': f'Failed to list functions: {str(e)}'}


async def get_logs(project_id: str, function_name: str,
                   minutes: int = 30) -> dict:
    """Retrieve function logs from Cloud Logging."""
    client = get_logging_client()

    # Build filter
    end_time = datetime.utcnow()
    start_time = end_time - timedelta(minutes=minutes)

    filter_str = f'''
        resource.type="cloud_function"
        resource.labels.function_name="{function_name}"
        timestamp >= "{start_time.isoformat()}Z"
        timestamp <= "{end_time.isoformat()}Z"
    '''

    try:
        entries = []

        for entry in client.list_entries(
            filter_=filter_str,
            order_by=logging_v2.DESCENDING,
            max_results=100,
            resource_names=[f'projects/{project_id}']
        ):
            entries.append({
                'timestamp': entry.timestamp.isoformat() if entry.timestamp else None,
                'severity': entry.severity,
                'message': entry.payload if isinstance(
                    entry.payload, str
                ) else json.dumps(entry.payload),
                'execution_id': entry.labels.get('execution_id')
            })

        return {
            'function': function_name,
            'project': project_id,
            'time_range': f'Last {minutes} minutes',
            'entries': entries
        }

    except Exception as e:
        return {'error': f'Failed to retrieve logs: {str(e)}'}


async def deploy(project_id: str, function_name: str,
                source_dir: str, entry_point: str,
                runtime: str = 'python311',
                trigger_type: str = 'http',
                memory: str = '256MB') -> dict:
    """Deploy Cloud Function."""
    client = get_functions_client()
    parent = f'projects/{project_id}/locations/us-central1'

    # Build function configuration
    function = functions_v2.Function(
        name=f'{parent}/functions/{function_name}',
        build_config=functions_v2.BuildConfig(
            runtime=runtime,
            entry_point=entry_point,
            source=functions_v2.Source(
                storage_source=functions_v2.StorageSource(
                    bucket=f'{project_id}-functions-source',
                    object_=f'{function_name}.zip'
                )
            )
        ),
        service_config=functions_v2.ServiceConfig(
            available_memory=memory,
            timeout_seconds=60,
            environment_variables={
                'GANTZ_ENABLED': 'true'
            }
        )
    )

    # Configure trigger
    if trigger_type == 'http':
        function.service_config.all_traffic_on_latest_revision = True

    try:
        operation = client.create_function(
            parent=parent,
            function=function,
            function_id=function_name
        )

        # Wait for deployment
        result = operation.result(timeout=300)

        return {
            'name': result.name.split('/')[-1],
            'state': result.state.name,
            'url': result.service_config.uri,
            'message': 'Function deployed successfully'
        }

    except exceptions.AlreadyExists:
        return {'error': f'Function {function_name} already exists'}
    except Exception as e:
        return {'error': f'Deployment failed: {str(e)}'}


async def publish_pubsub(project_id: str, topic: str,
                         message: dict) -> dict:
    """Publish message to Pub/Sub topic."""
    publisher = get_publisher()
    topic_path = publisher.topic_path(project_id, topic)

    try:
        # Encode message
        data = json.dumps(message).encode('utf-8')

        # Publish
        future = publisher.publish(topic_path, data)
        message_id = future.result(timeout=30)

        return {
            'message_id': message_id,
            'topic': topic,
            'status': 'published'
        }

    except exceptions.NotFound:
        return {'error': f'Topic {topic} not found'}
    except Exception as e:
        return {'error': f'Publish failed: {str(e)}'}
```

## Cloud Function Entry Point

Create the function that runs on GCP:

```python
# main.py - Cloud Function entry point
import functions_framework
import json
from gantz import MCPClient

# Initialize MCP client at module level for reuse
mcp_client = MCPClient(config_path='gantz.yaml')


@functions_framework.http
def mcp_agent(request):
    """HTTP Cloud Function for MCP tool execution."""
    # Parse request
    request_json = request.get_json(silent=True)

    if not request_json:
        return json.dumps({'error': 'No JSON payload provided'}), 400

    tool_name = request_json.get('tool')
    parameters = request_json.get('parameters', {})

    if not tool_name:
        return json.dumps({'error': 'Tool name required'}), 400

    try:
        # Execute MCP tool
        result = mcp_client.execute_tool(tool_name, parameters)

        return json.dumps(result), 200, {'Content-Type': 'application/json'}

    except Exception as e:
        return json.dumps({'error': str(e)}), 500


@functions_framework.cloud_event
def pubsub_agent(cloud_event):
    """Pub/Sub triggered Cloud Function."""
    import base64

    # Decode Pub/Sub message
    message_data = base64.b64decode(cloud_event.data['message']['data'])
    message = json.loads(message_data)

    tool_name = message.get('tool')
    parameters = message.get('parameters', {})

    if tool_name:
        result = mcp_client.execute_tool(tool_name, parameters)
        print(f'Tool {tool_name} executed: {result}')

    return 'OK'


@functions_framework.cloud_event
def storage_agent(cloud_event):
    """Cloud Storage triggered function."""
    data = cloud_event.data

    bucket = data['bucket']
    name = data['name']

    # Process uploaded file with MCP tool
    result = mcp_client.execute_tool('analyze_file', {
        'bucket': bucket,
        'file_path': name,
        'content_type': data.get('contentType')
    })

    print(f'File analysis complete: {result}')
    return 'OK'
```

## Cloud Functions Gen 2 with Cloud Run

Deploy with Cloud Run for more flexibility:

```yaml
# cloudbuild.yaml
steps:
  # Build container image
  - name: 'gcr.io/cloud-builders/docker'
    args:
      - 'build'
      - '-t'
      - 'gcr.io/$PROJECT_ID/mcp-agent:$COMMIT_SHA'
      - '.'

  # Push to Container Registry
  - name: 'gcr.io/cloud-builders/docker'
    args:
      - 'push'
      - 'gcr.io/$PROJECT_ID/mcp-agent:$COMMIT_SHA'

  # Deploy to Cloud Run
  - name: 'gcr.io/google.com/cloudsdktool/cloud-sdk'
    args:
      - 'gcloud'
      - 'run'
      - 'deploy'
      - 'mcp-agent'
      - '--image=gcr.io/$PROJECT_ID/mcp-agent:$COMMIT_SHA'
      - '--region=us-central1'
      - '--memory=1Gi'
      - '--timeout=300'
      - '--concurrency=80'
      - '--min-instances=1'
      - '--allow-unauthenticated'

images:
  - 'gcr.io/$PROJECT_ID/mcp-agent:$COMMIT_SHA'
```

Dockerfile for the agent:

```dockerfile
# Dockerfile
FROM python:3.11-slim

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application
COPY . .

# Run with gunicorn
CMD exec gunicorn --bind :$PORT --workers 1 --threads 8 --timeout 0 main:app
```

## Vertex AI Integration

Integrate with Google's AI services:

```python
# vertex_integration.py
from google.cloud import aiplatform
from vertexai.generative_models import GenerativeModel
import vertexai


def init_vertex(project_id: str, location: str = 'us-central1'):
    """Initialize Vertex AI."""
    vertexai.init(project=project_id, location=location)


async def generate_with_gemini(prompt: str, model: str = 'gemini-pro') -> dict:
    """Generate content using Gemini."""
    model = GenerativeModel(model)

    response = model.generate_content(prompt)

    return {
        'text': response.text,
        'usage': {
            'prompt_tokens': response.usage_metadata.prompt_token_count,
            'candidates_tokens': response.usage_metadata.candidates_token_count
        }
    }


async def predict_with_endpoint(
    project_id: str,
    endpoint_id: str,
    instances: list,
    location: str = 'us-central1'
) -> dict:
    """Get predictions from Vertex AI endpoint."""
    aiplatform.init(project=project_id, location=location)

    endpoint = aiplatform.Endpoint(endpoint_id)

    prediction = endpoint.predict(instances=instances)

    return {
        'predictions': prediction.predictions,
        'deployed_model_id': prediction.deployed_model_id
    }
```

## Event-Driven Architecture

Set up comprehensive event triggers:

```python
# event_triggers.py
import json
from google.cloud import pubsub_v1
from google.cloud import scheduler_v1
from google.protobuf import duration_pb2


def create_pubsub_trigger(
    project_id: str,
    topic_name: str,
    subscription_name: str,
    push_endpoint: str
) -> dict:
    """Create Pub/Sub subscription with push delivery."""
    publisher = pubsub_v1.PublisherClient()
    subscriber = pubsub_v1.SubscriberClient()

    # Create topic
    topic_path = publisher.topic_path(project_id, topic_name)
    try:
        publisher.create_topic(name=topic_path)
    except Exception:
        pass  # Topic exists

    # Create push subscription
    subscription_path = subscriber.subscription_path(
        project_id, subscription_name
    )

    push_config = pubsub_v1.types.PushConfig(
        push_endpoint=push_endpoint
    )

    subscription = subscriber.create_subscription(
        name=subscription_path,
        topic=topic_path,
        push_config=push_config,
        ack_deadline_seconds=60
    )

    return {
        'subscription': subscription.name,
        'topic': topic_path,
        'endpoint': push_endpoint
    }


def create_scheduler_job(
    project_id: str,
    location: str,
    job_name: str,
    schedule: str,  # Cron format
    target_url: str,
    payload: dict
) -> dict:
    """Create Cloud Scheduler job for periodic execution."""
    client = scheduler_v1.CloudSchedulerClient()
    parent = f'projects/{project_id}/locations/{location}'

    job = scheduler_v1.Job(
        name=f'{parent}/jobs/{job_name}',
        schedule=schedule,
        time_zone='UTC',
        http_target=scheduler_v1.HttpTarget(
            uri=target_url,
            http_method=scheduler_v1.HttpMethod.POST,
            body=json.dumps(payload).encode(),
            headers={'Content-Type': 'application/json'}
        )
    )

    created_job = client.create_job(parent=parent, job=job)

    return {
        'job_name': created_job.name,
        'schedule': created_job.schedule,
        'state': created_job.state.name
    }
```

## Monitoring with Cloud Monitoring

Track function performance:

```python
# monitoring.py
from google.cloud import monitoring_v3
import time


def write_custom_metric(
    project_id: str,
    metric_type: str,
    value: float,
    labels: dict = None
):
    """Write custom metric to Cloud Monitoring."""
    client = monitoring_v3.MetricServiceClient()
    project_name = f'projects/{project_id}'

    series = monitoring_v3.TimeSeries()
    series.metric.type = f'custom.googleapis.com/{metric_type}'
    series.resource.type = 'global'

    if labels:
        for key, val in labels.items():
            series.metric.labels[key] = val

    now = time.time()
    seconds = int(now)
    nanos = int((now - seconds) * 10 ** 9)

    interval = monitoring_v3.TimeInterval(
        end_time={'seconds': seconds, 'nanos': nanos}
    )

    point = monitoring_v3.Point(
        interval=interval,
        value={'double_value': value}
    )
    series.points = [point]

    client.create_time_series(name=project_name, time_series=[series])


# Usage in MCP handlers
def mcp_with_metrics(func):
    """Decorator to track MCP tool metrics."""
    async def wrapper(*args, **kwargs):
        start = time.time()
        try:
            result = await func(*args, **kwargs)
            write_custom_metric(
                'your-project',
                'mcp/tool_execution_time',
                time.time() - start,
                {'tool': func.__name__, 'status': 'success'}
            )
            return result
        except Exception as e:
            write_custom_metric(
                'your-project',
                'mcp/tool_execution_time',
                time.time() - start,
                {'tool': func.__name__, 'status': 'error'}
            )
            raise
    return wrapper
```

## Deploy with Gantz CLI

Deploy your GCP Cloud Functions:

```bash
# Install Gantz
npm install -g gantz

# Initialize GCP project
gantz init --template gcp-functions

# Configure GCP credentials
export GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json

# Deploy function
gantz deploy --platform gcp --region us-central1

# Test function
gantz run invoke_function \
  --project-id my-project \
  --function-name mcp-agent \
  --data '{"action": "test"}'
```

Build serverless AI agents on GCP at [gantz.run](https://gantz.run).

## Related Reading

- [AWS Lambda MCP Integration](/post/aws-lambda-mcp/) - Compare with AWS serverless
- [MCP Connection Pooling](/post/mcp-connection-pooling/) - Optimize GCP connections
- [MCP Streaming Patterns](/post/mcp-streaming-patterns/) - Stream data from Cloud Functions

## Conclusion

Google Cloud Functions provides a robust platform for serverless MCP tools. With Vertex AI integration, Pub/Sub triggers, and Cloud Run compatibility, you can build sophisticated AI agents that leverage the full GCP ecosystem.

Start deploying MCP tools to GCP with Gantz today.
