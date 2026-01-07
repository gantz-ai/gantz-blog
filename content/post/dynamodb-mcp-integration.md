+++
title = "DynamoDB MCP Integration: AWS NoSQL for AI Agents"
image = "images/dynamodb-mcp-integration.webp"
date = 2025-12-19
description = "Build MCP tools for Amazon DynamoDB. Key-value operations, queries, and serverless database patterns for AI applications."
draft = false
tags = ['mcp', 'dynamodb', 'aws', 'nosql']
voice = false

[howto]
name = "Integrate DynamoDB with MCP"
totalTime = 30
[[howto.steps]]
name = "Set up DynamoDB connection"
text = "Configure AWS SDK and credentials."
[[howto.steps]]
name = "Create item tools"
text = "Build CRUD operations for items."
[[howto.steps]]
name = "Add query tools"
text = "Efficient querying with indexes."
[[howto.steps]]
name = "Implement batch operations"
text = "Batch reads and writes."
[[howto.steps]]
name = "Add scan tools"
text = "Full table scans when needed."
+++


DynamoDB scales infinitely. AI agents need fast data.

Together, they enable serverless intelligent systems.

## Why DynamoDB + MCP

DynamoDB provides:
- Serverless scaling
- Single-digit millisecond latency
- Global tables
- Streams and triggers

MCP tools enable:
- AI-driven data access
- Automated queries
- Intelligent caching
- Real-time processing

## Step 1: DynamoDB connection

Using [Gantz](https://gantz.run):

```yaml
# gantz.yaml
name: dynamodb-tools

env:
  AWS_REGION: ${AWS_REGION}
  AWS_ACCESS_KEY_ID: ${AWS_ACCESS_KEY_ID}
  AWS_SECRET_ACCESS_KEY: ${AWS_SECRET_ACCESS_KEY}

tools:
  - name: get_item
    description: Get item from DynamoDB table
    parameters:
      - name: table
        type: string
        required: true
      - name: key
        type: object
        required: true
    script:
      command: python
      args: ["tools/dynamodb.py", "get"]

  - name: query_table
    description: Query DynamoDB table
    parameters:
      - name: table
        type: string
        required: true
      - name: key_condition
        type: object
        required: true
    script:
      command: python
      args: ["tools/dynamodb.py", "query"]
```

DynamoDB client:

```python
# lib/dynamodb_client.py
import os
from typing import Optional
import boto3
from boto3.dynamodb.conditions import Key, Attr

class DynamoDBClient:
    """DynamoDB client wrapper."""

    _instance: Optional['DynamoDBClient'] = None

    def __new__(cls):
        if cls._instance is None:
            cls._instance = super().__new__(cls)
            cls._instance._initialize()
        return cls._instance

    def _initialize(self):
        """Initialize DynamoDB client."""
        region = os.environ.get('AWS_REGION', 'us-east-1')

        self._client = boto3.client('dynamodb', region_name=region)
        self._resource = boto3.resource('dynamodb', region_name=region)

    @property
    def client(self):
        """Get low-level client."""
        return self._client

    @property
    def resource(self):
        """Get high-level resource."""
        return self._resource

    def table(self, name: str):
        """Get table resource."""
        return self._resource.Table(name)

# Global instance
dynamodb = DynamoDBClient()
```

## Step 2: Item operations

CRUD for DynamoDB items:

```python
# tools/dynamodb.py
import sys
import json
from decimal import Decimal
from boto3.dynamodb.conditions import Key, Attr
from lib.dynamodb_client import dynamodb

class DecimalEncoder(json.JSONEncoder):
    """Handle Decimal types in JSON."""
    def default(self, obj):
        if isinstance(obj, Decimal):
            return float(obj)
        return super().default(obj)

class ItemTool:
    """Tool for DynamoDB item operations."""

    def __init__(self, table_name: str):
        self.table = dynamodb.table(table_name)

    def get(self, key: dict) -> dict:
        """Get single item."""
        try:
            response = self.table.get_item(Key=key)

            item = response.get('Item')
            if item:
                return {
                    'success': True,
                    'item': item
                }
            return {
                'success': True,
                'item': None,
                'message': 'Item not found'
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def put(
        self,
        item: dict,
        condition: str = None
    ) -> dict:
        """Put item into table."""
        try:
            # Convert floats to Decimals
            item = self._convert_floats(item)

            kwargs = {'Item': item}
            if condition:
                kwargs['ConditionExpression'] = condition

            self.table.put_item(**kwargs)

            return {
                'success': True,
                'item': item
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def update(
        self,
        key: dict,
        updates: dict,
        condition: str = None
    ) -> dict:
        """Update item attributes."""
        try:
            # Build update expression
            update_parts = []
            expression_values = {}
            expression_names = {}

            for i, (attr, value) in enumerate(updates.items()):
                placeholder_name = f'#attr{i}'
                placeholder_value = f':val{i}'

                update_parts.append(f'{placeholder_name} = {placeholder_value}')
                expression_names[placeholder_name] = attr
                expression_values[placeholder_value] = self._convert_value(value)

            update_expression = 'SET ' + ', '.join(update_parts)

            kwargs = {
                'Key': key,
                'UpdateExpression': update_expression,
                'ExpressionAttributeNames': expression_names,
                'ExpressionAttributeValues': expression_values,
                'ReturnValues': 'ALL_NEW'
            }

            if condition:
                kwargs['ConditionExpression'] = condition

            response = self.table.update_item(**kwargs)

            return {
                'success': True,
                'item': response.get('Attributes')
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def delete(
        self,
        key: dict,
        condition: str = None
    ) -> dict:
        """Delete item from table."""
        try:
            kwargs = {
                'Key': key,
                'ReturnValues': 'ALL_OLD'
            }

            if condition:
                kwargs['ConditionExpression'] = condition

            response = self.table.delete_item(**kwargs)

            return {
                'success': True,
                'deleted': response.get('Attributes')
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def _convert_floats(self, obj):
        """Convert floats to Decimals recursively."""
        if isinstance(obj, float):
            return Decimal(str(obj))
        elif isinstance(obj, dict):
            return {k: self._convert_floats(v) for k, v in obj.items()}
        elif isinstance(obj, list):
            return [self._convert_floats(v) for v in obj]
        return obj

    def _convert_value(self, value):
        """Convert single value."""
        if isinstance(value, float):
            return Decimal(str(value))
        return value

if __name__ == '__main__':
    operation = sys.argv[1] if len(sys.argv) > 1 else 'get'
    params = json.loads(sys.argv[2]) if len(sys.argv) > 2 else {}

    table = params.get('table', '')
    tool = ItemTool(table)

    if operation == 'get':
        result = tool.get(params.get('key', {}))
    elif operation == 'put':
        result = tool.put(params.get('item', {}))
    elif operation == 'delete':
        result = tool.delete(params.get('key', {}))
    else:
        result = {'success': False, 'error': f'Unknown operation: {operation}'}

    print(json.dumps(result, cls=DecimalEncoder))
```

## Step 3: Query tools

Efficient querying:

```python
# tools/query.py
import json
from boto3.dynamodb.conditions import Key, Attr
from lib.dynamodb_client import dynamodb

class QueryTool:
    """Tool for DynamoDB queries."""

    def __init__(self, table_name: str):
        self.table = dynamodb.table(table_name)

    def query(
        self,
        partition_key: str,
        partition_value,
        sort_key: str = None,
        sort_condition: dict = None,
        filters: dict = None,
        index_name: str = None,
        limit: int = None,
        scan_forward: bool = True
    ) -> dict:
        """Query table or index."""
        try:
            # Build key condition
            key_condition = Key(partition_key).eq(partition_value)

            if sort_key and sort_condition:
                op = sort_condition.get('op', 'eq')
                value = sort_condition.get('value')

                if op == 'eq':
                    key_condition &= Key(sort_key).eq(value)
                elif op == 'lt':
                    key_condition &= Key(sort_key).lt(value)
                elif op == 'lte':
                    key_condition &= Key(sort_key).lte(value)
                elif op == 'gt':
                    key_condition &= Key(sort_key).gt(value)
                elif op == 'gte':
                    key_condition &= Key(sort_key).gte(value)
                elif op == 'between':
                    key_condition &= Key(sort_key).between(value[0], value[1])
                elif op == 'begins_with':
                    key_condition &= Key(sort_key).begins_with(value)

            kwargs = {
                'KeyConditionExpression': key_condition,
                'ScanIndexForward': scan_forward
            }

            if index_name:
                kwargs['IndexName'] = index_name

            if limit:
                kwargs['Limit'] = limit

            # Build filter expression
            if filters:
                filter_expr = self._build_filter(filters)
                if filter_expr:
                    kwargs['FilterExpression'] = filter_expr

            response = self.table.query(**kwargs)

            return {
                'success': True,
                'items': response.get('Items', []),
                'count': response.get('Count', 0),
                'scanned_count': response.get('ScannedCount', 0)
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def query_all(
        self,
        partition_key: str,
        partition_value,
        **kwargs
    ) -> dict:
        """Query with pagination to get all results."""
        try:
            all_items = []
            last_key = None

            while True:
                result = self.query(
                    partition_key=partition_key,
                    partition_value=partition_value,
                    **kwargs
                )

                if not result['success']:
                    return result

                all_items.extend(result['items'])

                # Check for more pages
                if 'LastEvaluatedKey' not in result:
                    break

                kwargs['ExclusiveStartKey'] = result['LastEvaluatedKey']

            return {
                'success': True,
                'items': all_items,
                'count': len(all_items)
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def _build_filter(self, filters: dict):
        """Build filter expression from dict."""
        expressions = []

        for attr, condition in filters.items():
            if isinstance(condition, dict):
                op = condition.get('op', 'eq')
                value = condition.get('value')

                if op == 'eq':
                    expressions.append(Attr(attr).eq(value))
                elif op == 'ne':
                    expressions.append(Attr(attr).ne(value))
                elif op == 'lt':
                    expressions.append(Attr(attr).lt(value))
                elif op == 'lte':
                    expressions.append(Attr(attr).lte(value))
                elif op == 'gt':
                    expressions.append(Attr(attr).gt(value))
                elif op == 'gte':
                    expressions.append(Attr(attr).gte(value))
                elif op == 'contains':
                    expressions.append(Attr(attr).contains(value))
                elif op == 'exists':
                    expressions.append(Attr(attr).exists())
                elif op == 'not_exists':
                    expressions.append(Attr(attr).not_exists())
            else:
                expressions.append(Attr(attr).eq(condition))

        if not expressions:
            return None

        result = expressions[0]
        for expr in expressions[1:]:
            result &= expr

        return result
```

## Step 4: Batch operations

Batch reads and writes:

```python
# tools/batch.py
import json
from lib.dynamodb_client import dynamodb

class BatchTool:
    """Tool for DynamoDB batch operations."""

    def __init__(self):
        self.resource = dynamodb.resource

    def batch_get(
        self,
        requests: dict  # {table_name: [keys]}
    ) -> dict:
        """Batch get items from multiple tables."""
        try:
            # Format request
            request_items = {}
            for table, keys in requests.items():
                request_items[table] = {
                    'Keys': keys
                }

            response = self.resource.batch_get_item(
                RequestItems=request_items
            )

            return {
                'success': True,
                'items': response.get('Responses', {}),
                'unprocessed': response.get('UnprocessedKeys', {})
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def batch_write(
        self,
        requests: dict  # {table_name: [{'put': item} | {'delete': key}]}
    ) -> dict:
        """Batch write items to multiple tables."""
        try:
            # Format request
            request_items = {}

            for table, operations in requests.items():
                request_items[table] = []

                for op in operations:
                    if 'put' in op:
                        request_items[table].append({
                            'PutRequest': {'Item': op['put']}
                        })
                    elif 'delete' in op:
                        request_items[table].append({
                            'DeleteRequest': {'Key': op['delete']}
                        })

            response = self.resource.batch_write_item(
                RequestItems=request_items
            )

            return {
                'success': True,
                'unprocessed': response.get('UnprocessedItems', {})
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def batch_put(
        self,
        table_name: str,
        items: list
    ) -> dict:
        """Batch put items to single table."""
        try:
            table = dynamodb.table(table_name)

            with table.batch_writer() as batch:
                for item in items:
                    batch.put_item(Item=item)

            return {
                'success': True,
                'count': len(items)
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def batch_delete(
        self,
        table_name: str,
        keys: list
    ) -> dict:
        """Batch delete items from single table."""
        try:
            table = dynamodb.table(table_name)

            with table.batch_writer() as batch:
                for key in keys:
                    batch.delete_item(Key=key)

            return {
                'success': True,
                'count': len(keys)
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}
```

## Step 5: Scan operations

Full table scans:

```python
# tools/scan.py
import json
from boto3.dynamodb.conditions import Attr
from lib.dynamodb_client import dynamodb

class ScanTool:
    """Tool for DynamoDB scan operations."""

    def __init__(self, table_name: str):
        self.table = dynamodb.table(table_name)

    def scan(
        self,
        filters: dict = None,
        projection: list = None,
        limit: int = None,
        start_key: dict = None
    ) -> dict:
        """Scan table with optional filters."""
        try:
            kwargs = {}

            if filters:
                filter_expr = self._build_filter(filters)
                if filter_expr:
                    kwargs['FilterExpression'] = filter_expr

            if projection:
                kwargs['ProjectionExpression'] = ', '.join(projection)

            if limit:
                kwargs['Limit'] = limit

            if start_key:
                kwargs['ExclusiveStartKey'] = start_key

            response = self.table.scan(**kwargs)

            result = {
                'success': True,
                'items': response.get('Items', []),
                'count': response.get('Count', 0),
                'scanned_count': response.get('ScannedCount', 0)
            }

            if 'LastEvaluatedKey' in response:
                result['last_key'] = response['LastEvaluatedKey']

            return result
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def scan_all(
        self,
        filters: dict = None,
        projection: list = None
    ) -> dict:
        """Scan entire table with pagination."""
        try:
            all_items = []
            last_key = None

            while True:
                result = self.scan(
                    filters=filters,
                    projection=projection,
                    start_key=last_key
                )

                if not result['success']:
                    return result

                all_items.extend(result['items'])

                if 'last_key' not in result:
                    break

                last_key = result['last_key']

            return {
                'success': True,
                'items': all_items,
                'count': len(all_items)
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def parallel_scan(
        self,
        total_segments: int = 4,
        filters: dict = None
    ) -> dict:
        """Parallel scan for large tables."""
        import concurrent.futures

        try:
            all_items = []

            def scan_segment(segment):
                items = []
                last_key = None

                while True:
                    kwargs = {
                        'Segment': segment,
                        'TotalSegments': total_segments
                    }

                    if filters:
                        kwargs['FilterExpression'] = self._build_filter(filters)

                    if last_key:
                        kwargs['ExclusiveStartKey'] = last_key

                    response = self.table.scan(**kwargs)
                    items.extend(response.get('Items', []))

                    if 'LastEvaluatedKey' not in response:
                        break

                    last_key = response['LastEvaluatedKey']

                return items

            with concurrent.futures.ThreadPoolExecutor(max_workers=total_segments) as executor:
                futures = [
                    executor.submit(scan_segment, i)
                    for i in range(total_segments)
                ]

                for future in concurrent.futures.as_completed(futures):
                    all_items.extend(future.result())

            return {
                'success': True,
                'items': all_items,
                'count': len(all_items)
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def _build_filter(self, filters: dict):
        """Build filter expression."""
        expressions = []

        for attr, condition in filters.items():
            if isinstance(condition, dict):
                op = condition.get('op', 'eq')
                value = condition.get('value')

                if op == 'eq':
                    expressions.append(Attr(attr).eq(value))
                elif op == 'contains':
                    expressions.append(Attr(attr).contains(value))
            else:
                expressions.append(Attr(attr).eq(condition))

        if not expressions:
            return None

        result = expressions[0]
        for expr in expressions[1:]:
            result &= expr

        return result
```

## Summary

DynamoDB + MCP integration:

1. **Item operations** - CRUD for items
2. **Query tools** - Efficient key queries
3. **Batch operations** - Bulk reads/writes
4. **Scan tools** - Full table scans
5. **Parallel scan** - Large table handling

Build tools with [Gantz](https://gantz.run), scale with DynamoDB.

Serverless data at scale.

## Related reading

- [MongoDB MCP Integration](/post/mongodb-mcp-integration/) - Document database
- [AWS Lambda MCP](/post/aws-lambda-mcp/) - Serverless compute
- [MCP Caching](/post/mcp-caching/) - Cache DynamoDB data

---

*How do you use DynamoDB with AI agents? Share your patterns.*
