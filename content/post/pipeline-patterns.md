+++
title = "AI Agent Pipeline Patterns with MCP: Sequential Processing Systems"
image = "images/pipeline-patterns.webp"
date = 2025-06-06
description = "Master AI agent pipeline patterns with MCP and Gantz. Learn sequential processing, stage orchestration, and data transformation pipelines."
draft = false
tags = ['pipeline', 'patterns', 'ai', 'mcp', 'multi-agent', 'gantz']
voice = false

[howto]
name = "How To Implement AI Agent Pipeline Patterns with MCP"
totalTime = 40
[[howto.steps]]
name = "Understand pipeline concepts"
text = "Learn sequential processing fundamentals"
[[howto.steps]]
name = "Design pipeline stages"
text = "Define processing stages"
[[howto.steps]]
name = "Implement data flow"
text = "Build inter-stage communication"
[[howto.steps]]
name = "Add error handling"
text = "Create pipeline resilience"
[[howto.steps]]
name = "Deploy with Gantz"
text = "Deploy pipeline agents using Gantz CLI"
+++

AI agent pipeline patterns enable sequential multi-stage processing where each stage transforms data, enabling complex workflows through simple, composable stages.

## Why Use Pipeline Patterns?

Agent pipelines enable:

- **Sequential processing**: Ordered transformation stages
- **Composability**: Mix and match stages
- **Specialization**: Each stage does one thing well
- **Debugging**: Inspect intermediate results
- **Scalability**: Scale stages independently

## Pipeline Architecture

```yaml
# gantz.yaml
name: pipeline-system
version: 1.0.0

tools:
  create_pipeline:
    description: "Create processing pipeline"
    parameters:
      name:
        type: string
        required: true
      stages:
        type: array
        required: true
    handler: pipeline.create_pipeline

  execute_pipeline:
    description: "Execute pipeline with input"
    parameters:
      pipeline_id:
        type: string
        required: true
      input:
        type: object
        required: true
    handler: pipeline.execute_pipeline

  add_stage:
    description: "Add stage to pipeline"
    parameters:
      pipeline_id:
        type: string
        required: true
      stage:
        type: object
        required: true
      position:
        type: number
    handler: pipeline.add_stage

  branch_pipeline:
    description: "Create conditional branch"
    parameters:
      pipeline_id:
        type: string
        required: true
      condition:
        type: object
        required: true
      branches:
        type: object
    handler: pipeline.branch_pipeline

  merge_pipelines:
    description: "Merge pipeline outputs"
    parameters:
      pipelines:
        type: array
        required: true
      merge_strategy:
        type: string
    handler: pipeline.merge_pipelines

  monitor_pipeline:
    description: "Monitor pipeline execution"
    parameters:
      execution_id:
        type: string
        required: true
    handler: pipeline.monitor_pipeline
```

## Handler Implementation

```python
# handlers/pipeline.py
import asyncio
from datetime import datetime
from typing import List, Dict, Any, Callable

# Pipeline state
PIPELINES = {}
EXECUTIONS = {}
STAGE_HANDLERS = {}


async def create_pipeline(name: str, stages: list) -> dict:
    """Create processing pipeline."""
    from gantz import MCPClient
    mcp = MCPClient()

    pipeline_id = generate_pipeline_id()

    # Validate stages
    validation = mcp.execute_tool('ai_validate', {
        'type': 'pipeline_validation',
        'stages': stages,
        'validate': ['connectivity', 'type_compatibility', 'completeness']
    })

    # Build pipeline
    pipeline_stages = []
    for i, stage in enumerate(stages):
        pipeline_stages.append({
            'id': f"{pipeline_id}_stage_{i}",
            'name': stage.get('name'),
            'handler': stage.get('handler'),
            'config': stage.get('config', {}),
            'input_type': stage.get('input_type'),
            'output_type': stage.get('output_type'),
            'retry_policy': stage.get('retry', {'max_attempts': 3}),
            'timeout': stage.get('timeout', 30)
        })

    pipeline = {
        'id': pipeline_id,
        'name': name,
        'stages': pipeline_stages,
        'created_at': datetime.now().isoformat(),
        'status': 'ready',
        'executions': 0
    }

    PIPELINES[pipeline_id] = pipeline

    return {
        'pipeline_id': pipeline_id,
        'name': name,
        'stages_count': len(pipeline_stages),
        'validation': validation,
        'status': 'ready'
    }


async def execute_pipeline(pipeline_id: str, input: dict) -> dict:
    """Execute pipeline with input."""
    from gantz import MCPClient
    mcp = MCPClient()

    pipeline = PIPELINES.get(pipeline_id)
    if not pipeline:
        return {'error': 'Pipeline not found'}

    execution_id = generate_execution_id()

    execution = {
        'id': execution_id,
        'pipeline_id': pipeline_id,
        'input': input,
        'started_at': datetime.now().isoformat(),
        'status': 'running',
        'current_stage': 0,
        'stage_results': [],
        'errors': []
    }

    EXECUTIONS[execution_id] = execution

    # Execute stages sequentially
    current_data = input

    for i, stage in enumerate(pipeline['stages']):
        execution['current_stage'] = i

        try:
            # Execute stage
            stage_start = datetime.now()

            result = await execute_stage(stage, current_data, mcp)

            stage_end = datetime.now()

            stage_result = {
                'stage_id': stage['id'],
                'stage_name': stage['name'],
                'input': current_data,
                'output': result,
                'duration_ms': (stage_end - stage_start).total_seconds() * 1000,
                'status': 'completed'
            }

            execution['stage_results'].append(stage_result)
            current_data = result

        except Exception as e:
            # Handle stage failure
            error = {
                'stage_id': stage['id'],
                'stage_name': stage['name'],
                'error': str(e),
                'occurred_at': datetime.now().isoformat()
            }

            execution['errors'].append(error)

            # Retry logic
            if stage['retry_policy']['max_attempts'] > 1:
                for attempt in range(1, stage['retry_policy']['max_attempts']):
                    try:
                        result = await execute_stage(stage, current_data, mcp)
                        execution['stage_results'].append({
                            'stage_id': stage['id'],
                            'output': result,
                            'status': 'completed',
                            'retry_attempt': attempt
                        })
                        current_data = result
                        break
                    except:
                        continue
            else:
                execution['status'] = 'failed'
                break

    # Mark completion
    if execution['status'] != 'failed':
        execution['status'] = 'completed'

    execution['completed_at'] = datetime.now().isoformat()
    execution['output'] = current_data

    # Update pipeline stats
    PIPELINES[pipeline_id]['executions'] += 1

    return {
        'execution_id': execution_id,
        'pipeline_id': pipeline_id,
        'status': execution['status'],
        'stages_completed': len(execution['stage_results']),
        'total_stages': len(pipeline['stages']),
        'output': current_data,
        'errors': execution['errors']
    }


async def add_stage(pipeline_id: str, stage: dict, position: int = None) -> dict:
    """Add stage to pipeline."""
    pipeline = PIPELINES.get(pipeline_id)
    if not pipeline:
        return {'error': 'Pipeline not found'}

    new_stage = {
        'id': f"{pipeline_id}_stage_{len(pipeline['stages'])}",
        'name': stage.get('name'),
        'handler': stage.get('handler'),
        'config': stage.get('config', {}),
        'input_type': stage.get('input_type'),
        'output_type': stage.get('output_type'),
        'retry_policy': stage.get('retry', {'max_attempts': 3}),
        'timeout': stage.get('timeout', 30)
    }

    if position is not None:
        pipeline['stages'].insert(position, new_stage)
    else:
        pipeline['stages'].append(new_stage)

    return {
        'pipeline_id': pipeline_id,
        'stage_id': new_stage['id'],
        'position': position if position else len(pipeline['stages']) - 1,
        'added': True
    }


async def branch_pipeline(pipeline_id: str, condition: dict, branches: dict) -> dict:
    """Create conditional branch in pipeline."""
    from gantz import MCPClient
    mcp = MCPClient()

    pipeline = PIPELINES.get(pipeline_id)
    if not pipeline:
        return {'error': 'Pipeline not found'}

    branch_stage = {
        'id': f"{pipeline_id}_branch_{generate_branch_id()}",
        'name': 'conditional_branch',
        'type': 'branch',
        'condition': condition,
        'branches': branches,
        'handler': 'pipeline.execute_branch'
    }

    # Add branch stage
    pipeline['stages'].append(branch_stage)

    return {
        'pipeline_id': pipeline_id,
        'branch_id': branch_stage['id'],
        'condition': condition,
        'branch_count': len(branches)
    }


async def merge_pipelines(pipelines: list, merge_strategy: str = 'concat') -> dict:
    """Merge multiple pipeline outputs."""
    from gantz import MCPClient
    mcp = MCPClient()

    merged_id = generate_pipeline_id()

    # Collect all stages
    all_stages = []
    for pid in pipelines:
        pipeline = PIPELINES.get(pid)
        if pipeline:
            all_stages.extend(pipeline['stages'])

    # Add merge stage
    merge_stage = {
        'id': f"{merged_id}_merge",
        'name': 'merge',
        'type': 'merge',
        'strategy': merge_strategy,
        'source_pipelines': pipelines,
        'handler': 'pipeline.merge_outputs'
    }

    merged_pipeline = {
        'id': merged_id,
        'name': f"merged_{len(pipelines)}_pipelines",
        'stages': all_stages + [merge_stage],
        'source_pipelines': pipelines,
        'created_at': datetime.now().isoformat(),
        'status': 'ready'
    }

    PIPELINES[merged_id] = merged_pipeline

    return {
        'merged_pipeline_id': merged_id,
        'source_pipelines': pipelines,
        'total_stages': len(merged_pipeline['stages']),
        'merge_strategy': merge_strategy
    }


async def monitor_pipeline(execution_id: str) -> dict:
    """Monitor pipeline execution."""
    from gantz import MCPClient
    mcp = MCPClient()

    execution = EXECUTIONS.get(execution_id)
    if not execution:
        return {'error': 'Execution not found'}

    pipeline = PIPELINES.get(execution['pipeline_id'])

    # Calculate metrics
    completed_stages = len(execution['stage_results'])
    total_stages = len(pipeline['stages'])

    stage_times = [
        r.get('duration_ms', 0)
        for r in execution['stage_results']
    ]

    # AI analysis
    analysis = mcp.execute_tool('ai_analyze', {
        'type': 'pipeline_monitoring',
        'execution': execution,
        'pipeline': pipeline,
        'analyze': ['bottlenecks', 'anomalies', 'predictions']
    })

    return {
        'execution_id': execution_id,
        'pipeline_id': execution['pipeline_id'],
        'status': execution['status'],
        'progress': completed_stages / total_stages * 100,
        'current_stage': execution['current_stage'],
        'completed_stages': completed_stages,
        'total_stages': total_stages,
        'total_duration_ms': sum(stage_times),
        'avg_stage_duration_ms': sum(stage_times) / len(stage_times) if stage_times else 0,
        'errors': execution['errors'],
        'analysis': analysis
    }


async def execute_stage(stage: dict, data: dict, mcp) -> dict:
    """Execute single pipeline stage."""
    handler_name = stage['handler']

    # AI stage execution
    result = mcp.execute_tool('ai_process', {
        'type': 'pipeline_stage',
        'stage': stage['name'],
        'handler': handler_name,
        'config': stage['config'],
        'input': data
    })

    return result


# Stage handler implementations
async def transform_stage(data: dict, config: dict) -> dict:
    """Transform data according to config."""
    transformations = config.get('transformations', [])

    for transform in transformations:
        if transform['type'] == 'map':
            data = {transform['to']: data.get(transform['from'])}
        elif transform['type'] == 'filter':
            data = {k: v for k, v in data.items() if eval(transform['condition'])}
        elif transform['type'] == 'aggregate':
            # Aggregation logic
            pass

    return data


async def enrich_stage(data: dict, config: dict) -> dict:
    """Enrich data with additional information."""
    from gantz import MCPClient
    mcp = MCPClient()

    enrichment = mcp.execute_tool('ai_enrich', {
        'data': data,
        'enrich_with': config.get('sources', [])
    })

    return {**data, **enrichment}


async def validate_stage(data: dict, config: dict) -> dict:
    """Validate data against schema."""
    schema = config.get('schema')

    # Validation logic
    is_valid = validate_against_schema(data, schema)

    if not is_valid:
        raise ValueError(f"Data validation failed")

    return data
```

## Pipeline Templates

```python
# templates/pipelines.py
from gantz import MCPClient

mcp = MCPClient(config_path='gantz.yaml')


class ETLPipeline:
    """Extract-Transform-Load pipeline."""

    async def create(self, source: str, destination: str, transforms: list) -> dict:
        stages = [
            {
                'name': 'extract',
                'handler': 'etl.extract',
                'config': {'source': source}
            },
            *[{
                'name': f'transform_{i}',
                'handler': 'etl.transform',
                'config': t
            } for i, t in enumerate(transforms)],
            {
                'name': 'load',
                'handler': 'etl.load',
                'config': {'destination': destination}
            }
        ]

        return await mcp.execute_tool('create_pipeline', {
            'name': f'etl_{source}_to_{destination}',
            'stages': stages
        })


class DataProcessingPipeline:
    """Generic data processing pipeline."""

    async def create(self, processors: list) -> dict:
        stages = [
            {
                'name': 'ingest',
                'handler': 'data.ingest',
                'config': {}
            },
            {
                'name': 'validate',
                'handler': 'data.validate',
                'config': {}
            },
            *[{
                'name': p['name'],
                'handler': p['handler'],
                'config': p.get('config', {})
            } for p in processors],
            {
                'name': 'output',
                'handler': 'data.output',
                'config': {}
            }
        ]

        return await mcp.execute_tool('create_pipeline', {
            'name': 'data_processing',
            'stages': stages
        })


class MLPipeline:
    """Machine learning pipeline."""

    async def create(self, model_type: str, features: list) -> dict:
        stages = [
            {
                'name': 'data_loading',
                'handler': 'ml.load_data',
                'config': {}
            },
            {
                'name': 'feature_engineering',
                'handler': 'ml.engineer_features',
                'config': {'features': features}
            },
            {
                'name': 'train_test_split',
                'handler': 'ml.split_data',
                'config': {'test_size': 0.2}
            },
            {
                'name': 'model_training',
                'handler': 'ml.train',
                'config': {'model_type': model_type}
            },
            {
                'name': 'evaluation',
                'handler': 'ml.evaluate',
                'config': {}
            },
            {
                'name': 'model_export',
                'handler': 'ml.export',
                'config': {}
            }
        ]

        return await mcp.execute_tool('create_pipeline', {
            'name': f'ml_{model_type}',
            'stages': stages
        })
```

## Deploy with Gantz CLI

```bash
# Install Gantz
npm install -g gantz

# Initialize pipeline system
gantz init --template pipeline-system

# Deploy
gantz deploy --platform kubernetes

# Create pipeline
gantz run create_pipeline --name "data_process" --stages '[{"name": "extract", "handler": "etl.extract"}, ...]'

# Execute pipeline
gantz run execute_pipeline --pipeline-id pipe_123 --input '{"data": [...]}'

# Monitor execution
gantz run monitor_pipeline --execution-id exec_456

# Add stage
gantz run add_stage --pipeline-id pipe_123 --stage '{"name": "validate", "handler": "data.validate"}'
```

Build sequential processing systems at [gantz.run](https://gantz.run).

## Related Reading

- [Workflow Patterns](/post/workflow-patterns/) - Complex workflows
- [Orchestration Patterns](/post/orchestration-patterns/) - Multi-agent coordination
- [Delegation Patterns](/post/delegation-patterns/) - Task assignment

## Conclusion

Pipeline patterns enable powerful sequential data processing. With composable stages, error handling, and monitoring, you can build robust data transformation workflows that scale.

Start building pipeline systems with Gantz today.
