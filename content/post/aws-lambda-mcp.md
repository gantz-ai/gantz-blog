+++
title = "AWS Lambda MCP Integration: Build Serverless AI Agents"
image = "images/aws-lambda-mcp.webp"
date = 2025-05-01
description = "Deploy MCP-powered AI agents on AWS Lambda. Learn serverless architecture, cold start optimization, and event-driven AI workflows with Gantz."
summary = "Serverless AI agents that scale to zero and handle millions of requests. Deploy MCP agents on AWS Lambda with API Gateway for HTTP triggers or SQS for async processing. Learn cold start optimization techniques, connection pooling for database tools, and provisioned concurrency for latency-sensitive use cases. Pay only for compute you actually use."
draft = false
tags = ['aws', 'lambda', 'serverless', 'mcp', 'cloud', 'gantz']
voice = false

[howto]
name = "How To Build Serverless AI Agents with AWS Lambda and MCP"
totalTime = 35
[[howto.steps]]
name = "Configure Lambda function"
text = "Set up AWS Lambda with proper runtime, memory, and timeout settings for MCP operations"
[[howto.steps]]
name = "Define MCP tools for Lambda"
text = "Create tool definitions optimized for serverless execution patterns"
[[howto.steps]]
name = "Handle cold starts"
text = "Implement connection reuse and initialization optimization strategies"
[[howto.steps]]
name = "Set up event triggers"
text = "Configure API Gateway, SQS, or EventBridge triggers for AI agent invocation"
[[howto.steps]]
name = "Deploy with Gantz"
text = "Package and deploy your serverless MCP tools using Gantz CLI"
+++

AWS Lambda provides the perfect serverless foundation for deploying MCP-powered AI agents. This guide covers building scalable, cost-effective AI workflows that respond to events without managing infrastructure.

## Why AWS Lambda for MCP?

Serverless architecture offers unique advantages for AI agents:

- **Pay-per-execution**: Only pay when your agent processes requests
- **Auto-scaling**: Handle traffic spikes without configuration
- **Event-driven**: Trigger agents from any AWS service
- **Global deployment**: Deploy to multiple regions instantly
- **Managed runtime**: No server maintenance required

## Lambda MCP Tool Definition

Configure your Lambda-based MCP tools in Gantz:

```yaml
# gantz.yaml
name: lambda-mcp-tools
version: 1.0.0

tools:
  invoke_lambda:
    description: "Invoke AWS Lambda function with payload"
    parameters:
      function_name:
        type: string
        description: "Lambda function name or ARN"
        required: true
      payload:
        type: object
        description: "JSON payload to send to function"
        required: true
      invocation_type:
        type: string
        description: "Sync (RequestResponse) or async (Event)"
        default: "RequestResponse"
    handler: aws_lambda.invoke

  list_functions:
    description: "List available Lambda functions"
    parameters:
      prefix:
        type: string
        description: "Function name prefix filter"
      max_items:
        type: integer
        description: "Maximum functions to return"
        default: 50
    handler: aws_lambda.list_functions

  get_function_logs:
    description: "Retrieve CloudWatch logs for Lambda function"
    parameters:
      function_name:
        type: string
        required: true
      minutes:
        type: integer
        description: "Minutes of logs to retrieve"
        default: 15
    handler: aws_lambda.get_logs

  create_function:
    description: "Create new Lambda function"
    parameters:
      function_name:
        type: string
        required: true
      runtime:
        type: string
        description: "Runtime environment"
        default: "python3.11"
      handler:
        type: string
        required: true
      code_path:
        type: string
        description: "Path to deployment package"
        required: true
      memory:
        type: integer
        description: "Memory in MB"
        default: 256
      timeout:
        type: integer
        description: "Timeout in seconds"
        default: 30
    handler: aws_lambda.create_function
```

## Lambda Handler Implementation

Create optimized Lambda handlers for MCP operations:

```python
# handlers/aws_lambda.py
import boto3
import json
import base64
from datetime import datetime, timedelta
from botocore.config import Config
from functools import lru_cache

# Connection reuse for warm starts
@lru_cache(maxsize=1)
def get_lambda_client(region='us-east-1'):
    """Reuse Lambda client across invocations."""
    config = Config(
        retries={'max_attempts': 3, 'mode': 'adaptive'},
        connect_timeout=5,
        read_timeout=60
    )
    return boto3.client('lambda', region_name=region, config=config)

@lru_cache(maxsize=1)
def get_logs_client(region='us-east-1'):
    """Reuse CloudWatch Logs client."""
    return boto3.client('logs', region_name=region)


async def invoke(function_name: str, payload: dict,
                 invocation_type: str = 'RequestResponse') -> dict:
    """Invoke Lambda function with payload."""
    client = get_lambda_client()

    try:
        response = client.invoke(
            FunctionName=function_name,
            InvocationType=invocation_type,
            Payload=json.dumps(payload)
        )

        if invocation_type == 'RequestResponse':
            # Synchronous invocation
            response_payload = json.loads(
                response['Payload'].read().decode('utf-8')
            )

            return {
                'status_code': response['StatusCode'],
                'function_error': response.get('FunctionError'),
                'executed_version': response.get('ExecutedVersion'),
                'response': response_payload
            }
        else:
            # Async invocation
            return {
                'status_code': response['StatusCode'],
                'message': f'Function {function_name} invoked asynchronously'
            }

    except client.exceptions.ResourceNotFoundException:
        return {'error': f'Function {function_name} not found'}
    except client.exceptions.InvalidRequestContentException as e:
        return {'error': f'Invalid payload: {str(e)}'}
    except Exception as e:
        return {'error': f'Invocation failed: {str(e)}'}


async def list_functions(prefix: str = None, max_items: int = 50) -> dict:
    """List Lambda functions with optional filtering."""
    client = get_lambda_client()
    functions = []

    paginator = client.get_paginator('list_functions')
    page_iterator = paginator.paginate(
        PaginationConfig={'MaxItems': max_items}
    )

    for page in page_iterator:
        for func in page['Functions']:
            if prefix and not func['FunctionName'].startswith(prefix):
                continue

            functions.append({
                'name': func['FunctionName'],
                'runtime': func.get('Runtime', 'N/A'),
                'memory': func['MemorySize'],
                'timeout': func['Timeout'],
                'last_modified': func['LastModified'],
                'code_size': func['CodeSize'],
                'handler': func.get('Handler', 'N/A')
            })

    return {
        'count': len(functions),
        'functions': functions
    }


async def get_logs(function_name: str, minutes: int = 15) -> dict:
    """Retrieve recent CloudWatch logs for function."""
    logs_client = get_logs_client()
    log_group = f'/aws/lambda/{function_name}'

    try:
        # Calculate time range
        end_time = int(datetime.now().timestamp() * 1000)
        start_time = int(
            (datetime.now() - timedelta(minutes=minutes)).timestamp() * 1000
        )

        # Get log streams
        streams_response = logs_client.describe_log_streams(
            logGroupName=log_group,
            orderBy='LastEventTime',
            descending=True,
            limit=5
        )

        log_entries = []

        for stream in streams_response.get('logStreams', []):
            events_response = logs_client.get_log_events(
                logGroupName=log_group,
                logStreamName=stream['logStreamName'],
                startTime=start_time,
                endTime=end_time,
                limit=100
            )

            for event in events_response.get('events', []):
                log_entries.append({
                    'timestamp': datetime.fromtimestamp(
                        event['timestamp'] / 1000
                    ).isoformat(),
                    'message': event['message'].strip(),
                    'stream': stream['logStreamName']
                })

        # Sort by timestamp
        log_entries.sort(key=lambda x: x['timestamp'], reverse=True)

        return {
            'function': function_name,
            'log_group': log_group,
            'entries': log_entries[:100],
            'time_range': f'Last {minutes} minutes'
        }

    except logs_client.exceptions.ResourceNotFoundException:
        return {'error': f'Log group {log_group} not found'}


async def create_function(function_name: str, runtime: str,
                         handler: str, code_path: str,
                         memory: int = 256, timeout: int = 30) -> dict:
    """Create new Lambda function."""
    client = get_lambda_client()

    try:
        # Read deployment package
        with open(code_path, 'rb') as f:
            zip_content = f.read()

        response = client.create_function(
            FunctionName=function_name,
            Runtime=runtime,
            Role=get_execution_role(),  # You'll need to implement this
            Handler=handler,
            Code={'ZipFile': zip_content},
            MemorySize=memory,
            Timeout=timeout,
            Environment={
                'Variables': {
                    'GANTZ_ENABLED': 'true'
                }
            },
            Tags={
                'CreatedBy': 'gantz-mcp',
                'Purpose': 'ai-agent'
            }
        )

        return {
            'function_name': response['FunctionName'],
            'function_arn': response['FunctionArn'],
            'runtime': response['Runtime'],
            'state': response['State'],
            'message': 'Function created successfully'
        }

    except client.exceptions.ResourceConflictException:
        return {'error': f'Function {function_name} already exists'}
    except Exception as e:
        return {'error': f'Creation failed: {str(e)}'}
```

## Cold Start Optimization

Minimize cold start impact for responsive AI agents:

```python
# optimized_handler.py
import json
import os

# Initialize outside handler for connection reuse
_initialized = False
_mcp_client = None
_db_connection = None

def initialize():
    """One-time initialization for warm starts."""
    global _initialized, _mcp_client, _db_connection

    if _initialized:
        return

    # Import heavy dependencies here
    from gantz import MCPClient
    import psycopg2

    # Initialize MCP client
    _mcp_client = MCPClient(
        config_path=os.environ.get('GANTZ_CONFIG', 'gantz.yaml')
    )

    # Initialize database connection
    _db_connection = psycopg2.connect(
        os.environ['DATABASE_URL'],
        connect_timeout=5
    )

    _initialized = True


def handler(event, context):
    """Lambda handler with optimized initialization."""
    # Initialize on cold start
    initialize()

    # Check remaining time for long operations
    remaining_time = context.get_remaining_time_in_millis()

    if remaining_time < 5000:  # Less than 5 seconds
        return {
            'statusCode': 503,
            'body': json.dumps({'error': 'Insufficient time remaining'})
        }

    try:
        # Process MCP request
        tool_name = event.get('tool')
        parameters = event.get('parameters', {})

        result = _mcp_client.execute_tool(
            tool_name,
            parameters,
            timeout=remaining_time - 1000  # Leave 1s buffer
        )

        return {
            'statusCode': 200,
            'body': json.dumps(result)
        }

    except Exception as e:
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }
```

## Provisioned Concurrency for AI Agents

Eliminate cold starts for critical AI workflows:

```yaml
# serverless.yml
service: gantz-mcp-agent

provider:
  name: aws
  runtime: python3.11
  region: us-east-1
  memorySize: 1024  # More memory = more CPU
  timeout: 60

functions:
  ai-agent:
    handler: handler.main
    provisionedConcurrency: 5  # Keep 5 instances warm
    events:
      - http:
          path: /agent
          method: post
      - sqs:
          arn: !GetAtt AgentQueue.Arn
          batchSize: 1
    environment:
      GANTZ_CONFIG: config/gantz.yaml
      LOG_LEVEL: INFO

  async-processor:
    handler: async_handler.process
    timeout: 900  # 15 minutes for long tasks
    reservedConcurrency: 10
    events:
      - sqs:
          arn: !GetAtt AsyncQueue.Arn
          batchSize: 5

resources:
  Resources:
    AgentQueue:
      Type: AWS::SQS::Queue
      Properties:
        QueueName: gantz-agent-queue
        VisibilityTimeout: 120

    AsyncQueue:
      Type: AWS::SQS::Queue
      Properties:
        QueueName: gantz-async-queue
        VisibilityTimeout: 1800
```

## Event-Driven AI Workflows

Configure triggers for automated AI agent execution:

```python
# event_handlers.py
import json
from gantz import MCPClient

mcp = MCPClient()


def api_gateway_handler(event, context):
    """Handle API Gateway requests."""
    body = json.loads(event.get('body', '{}'))

    tool = body.get('tool')
    params = body.get('parameters', {})

    result = mcp.execute_tool(tool, params)

    return {
        'statusCode': 200,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*'
        },
        'body': json.dumps(result)
    }


def sqs_handler(event, context):
    """Process SQS messages with MCP tools."""
    results = []

    for record in event['Records']:
        message = json.loads(record['body'])

        result = mcp.execute_tool(
            message['tool'],
            message['parameters']
        )

        results.append({
            'message_id': record['messageId'],
            'result': result
        })

    return {'processed': len(results), 'results': results}


def eventbridge_handler(event, context):
    """Handle EventBridge scheduled events."""
    detail = event.get('detail', {})

    # Scheduled AI agent tasks
    if event['detail-type'] == 'Scheduled Agent Task':
        result = mcp.execute_tool(
            detail['tool'],
            detail['parameters']
        )

        # Store result for retrieval
        store_result(event['id'], result)

        return result

    return {'status': 'unhandled_event_type'}


def s3_handler(event, context):
    """Process S3 events with AI analysis."""
    results = []

    for record in event['Records']:
        bucket = record['s3']['bucket']['name']
        key = record['s3']['object']['key']

        # Analyze uploaded file
        result = mcp.execute_tool('analyze_file', {
            'bucket': bucket,
            'key': key
        })

        results.append({
            'file': f's3://{bucket}/{key}',
            'analysis': result
        })

    return results
```

## Lambda Layers for MCP Dependencies

Share dependencies across functions:

```bash
# Create Lambda layer with Gantz and dependencies
mkdir -p layer/python
pip install gantz boto3 -t layer/python

cd layer
zip -r gantz-layer.zip python

aws lambda publish-layer-version \
  --layer-name gantz-mcp-layer \
  --description "Gantz MCP dependencies" \
  --zip-file fileb://gantz-layer.zip \
  --compatible-runtimes python3.11 python3.12
```

Reference the layer in your function:

```yaml
# serverless.yml
functions:
  ai-agent:
    handler: handler.main
    layers:
      - arn:aws:lambda:us-east-1:123456789:layer:gantz-mcp-layer:1
```

## Monitoring and Observability

Track Lambda MCP performance:

```python
# monitoring.py
import json
import time
from functools import wraps
import boto3

cloudwatch = boto3.client('cloudwatch')


def metrics_decorator(func):
    """Track MCP tool execution metrics."""
    @wraps(func)
    def wrapper(*args, **kwargs):
        start_time = time.time()

        try:
            result = func(*args, **kwargs)
            success = True
        except Exception as e:
            success = False
            raise
        finally:
            duration = (time.time() - start_time) * 1000

            # Publish custom metrics
            cloudwatch.put_metric_data(
                Namespace='Gantz/MCP',
                MetricData=[
                    {
                        'MetricName': 'ToolExecutionTime',
                        'Value': duration,
                        'Unit': 'Milliseconds',
                        'Dimensions': [
                            {'Name': 'ToolName', 'Value': func.__name__}
                        ]
                    },
                    {
                        'MetricName': 'ToolExecutions',
                        'Value': 1,
                        'Unit': 'Count',
                        'Dimensions': [
                            {'Name': 'ToolName', 'Value': func.__name__},
                            {'Name': 'Success', 'Value': str(success)}
                        ]
                    }
                ]
            )

        return result
    return wrapper


# Apply to handlers
@metrics_decorator
async def invoke(function_name: str, payload: dict, **kwargs):
    # Implementation here
    pass
```

## Deploy with Gantz CLI

Deploy your Lambda MCP tools:

```bash
# Install Gantz CLI
npm install -g gantz

# Initialize project
gantz init --template aws-lambda

# Deploy to AWS
gantz deploy --platform aws-lambda --region us-east-1

# Test invocation
gantz run invoke_lambda \
  --function-name my-ai-agent \
  --payload '{"action": "analyze", "data": "test"}'
```

Run your serverless AI agents at [gantz.run](https://gantz.run).

## Related Reading

- [MCP Timeout Configuration](/post/mcp-timeout-configuration/) - Set appropriate timeouts for Lambda
- [MCP Circuit Breakers](/post/mcp-circuit-breakers/) - Handle Lambda failures gracefully
- [MCP Retry Strategies](/post/mcp-retry-strategies/) - Implement retry logic for transient errors

## Conclusion

AWS Lambda and MCP create a powerful combination for serverless AI agents. With proper cold start optimization, event triggers, and monitoring, you can build responsive, cost-effective AI workflows that scale automatically.

Start building serverless MCP tools with Gantz today.
