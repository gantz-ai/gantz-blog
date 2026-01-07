+++
title = "MongoDB MCP Integration: NoSQL Tools for AI Agents"
image = "images/mongodb-mcp-integration.webp"
date = 2025-12-07
description = "Build MCP tools for MongoDB operations. Document queries, aggregation pipelines, and AI-powered NoSQL interactions."
draft = false
tags = ['mcp', 'mongodb', 'nosql', 'database']
voice = false

[howto]
name = "Integrate MongoDB with MCP"
totalTime = 30
[[howto.steps]]
name = "Set up MongoDB connection"
text = "Configure MongoDB client and connection pooling."
[[howto.steps]]
name = "Create CRUD tools"
text = "Build tools for document operations."
[[howto.steps]]
name = "Add aggregation tools"
text = "Tools for complex data pipelines."
[[howto.steps]]
name = "Implement search"
text = "Full-text and vector search tools."
[[howto.steps]]
name = "Add AI query generation"
text = "Natural language to MongoDB queries."
+++


MongoDB stores flexible documents. MCP tools make them accessible.

Together, they enable intelligent document operations.

## Why MongoDB + MCP

MongoDB provides:
- Flexible schemas
- Document model
- Aggregation pipelines
- Atlas Search

MCP tools enable:
- AI-driven queries
- Natural language access
- Automated aggregations
- Schema understanding

## Step 1: MongoDB connection

Using [Gantz](https://gantz.run):

```yaml
# gantz.yaml
name: mongodb-tools

env:
  MONGODB_URI: ${MONGODB_URI}

tools:
  - name: find_documents
    description: Query documents from a collection
    parameters:
      - name: collection
        type: string
        required: true
      - name: query
        type: object
        required: false
      - name: limit
        type: integer
        default: 10
    script:
      command: python
      args: ["tools/find.py"]

  - name: aggregate
    description: Run aggregation pipeline
    parameters:
      - name: collection
        type: string
        required: true
      - name: pipeline
        type: array
        required: true
    script:
      command: python
      args: ["tools/aggregate.py"]
```

MongoDB client setup:

```python
# lib/mongodb.py
import os
from typing import Optional
from pymongo import MongoClient
from pymongo.database import Database
from pymongo.collection import Collection

class MongoDBClient:
    """MongoDB client wrapper."""

    _instance: Optional['MongoDBClient'] = None
    _client: Optional[MongoClient] = None

    def __new__(cls):
        if cls._instance is None:
            cls._instance = super().__new__(cls)
            cls._instance._initialize_client()
        return cls._instance

    def _initialize_client(self):
        """Initialize MongoDB client."""
        uri = os.environ.get('MONGODB_URI', 'mongodb://localhost:27017')
        self._client = MongoClient(uri)

    @property
    def client(self) -> MongoClient:
        return self._client

    def database(self, name: str = None) -> Database:
        """Get database."""
        if name:
            return self._client[name]
        # Get default from URI
        return self._client.get_default_database()

    def collection(self, name: str, db: str = None) -> Collection:
        """Get collection."""
        database = self.database(db)
        return database[name]

    def list_databases(self) -> list:
        """List all databases."""
        return self._client.list_database_names()

    def list_collections(self, db: str = None) -> list:
        """List collections in database."""
        database = self.database(db)
        return database.list_collection_names()

# Global instance
mongo = MongoDBClient()
```

## Step 2: CRUD tools

Document operations:

```python
# tools/find.py
import sys
import json
from bson import ObjectId
from bson.json_util import dumps, loads
from lib.mongodb import mongo

class FindTool:
    """Tool for finding documents."""

    def __init__(self, collection: str, db: str = None):
        self.collection = mongo.collection(collection, db)

    def find(
        self,
        query: dict = None,
        projection: dict = None,
        sort: list = None,
        limit: int = 10,
        skip: int = 0
    ) -> dict:
        """Find documents matching query."""
        try:
            cursor = self.collection.find(
                query or {},
                projection
            )

            if sort:
                cursor = cursor.sort(sort)

            cursor = cursor.skip(skip).limit(limit)

            documents = list(cursor)

            return {
                'success': True,
                'data': json.loads(dumps(documents)),
                'count': len(documents)
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def find_one(self, query: dict) -> dict:
        """Find single document."""
        try:
            document = self.collection.find_one(query)

            if document:
                return {
                    'success': True,
                    'data': json.loads(dumps(document))
                }
            return {
                'success': True,
                'data': None,
                'message': 'Document not found'
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def count(self, query: dict = None) -> dict:
        """Count matching documents."""
        try:
            count = self.collection.count_documents(query or {})
            return {'success': True, 'count': count}
        except Exception as e:
            return {'success': False, 'error': str(e)}

class InsertTool:
    """Tool for inserting documents."""

    def __init__(self, collection: str, db: str = None):
        self.collection = mongo.collection(collection, db)

    def insert_one(self, document: dict) -> dict:
        """Insert single document."""
        try:
            result = self.collection.insert_one(document)
            return {
                'success': True,
                'inserted_id': str(result.inserted_id)
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def insert_many(self, documents: list) -> dict:
        """Insert multiple documents."""
        try:
            result = self.collection.insert_many(documents)
            return {
                'success': True,
                'inserted_ids': [str(id) for id in result.inserted_ids],
                'count': len(result.inserted_ids)
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}

class UpdateTool:
    """Tool for updating documents."""

    def __init__(self, collection: str, db: str = None):
        self.collection = mongo.collection(collection, db)

    def update_one(self, query: dict, update: dict, upsert: bool = False) -> dict:
        """Update single document."""
        try:
            result = self.collection.update_one(query, update, upsert=upsert)
            return {
                'success': True,
                'matched_count': result.matched_count,
                'modified_count': result.modified_count,
                'upserted_id': str(result.upserted_id) if result.upserted_id else None
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def update_many(self, query: dict, update: dict) -> dict:
        """Update multiple documents."""
        try:
            result = self.collection.update_many(query, update)
            return {
                'success': True,
                'matched_count': result.matched_count,
                'modified_count': result.modified_count
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}

if __name__ == '__main__':
    params = json.loads(sys.argv[1]) if len(sys.argv) > 1 else {}

    tool = FindTool(params.get('collection', ''))
    result = tool.find(
        query=params.get('query', {}),
        limit=params.get('limit', 10)
    )

    print(json.dumps(result))
```

## Step 3: Aggregation tools

Complex data pipelines:

```python
# tools/aggregate.py
import sys
import json
from bson.json_util import dumps
from lib.mongodb import mongo

class AggregationTool:
    """Tool for aggregation pipelines."""

    def __init__(self, collection: str, db: str = None):
        self.collection = mongo.collection(collection, db)

    def aggregate(self, pipeline: list) -> dict:
        """Run aggregation pipeline."""
        try:
            cursor = self.collection.aggregate(pipeline)
            results = list(cursor)

            return {
                'success': True,
                'data': json.loads(dumps(results)),
                'count': len(results)
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def group_by(
        self,
        group_field: str,
        aggregations: dict = None
    ) -> dict:
        """Simple group by operation."""
        pipeline = [
            {
                '$group': {
                    '_id': f'${group_field}',
                    'count': {'$sum': 1},
                    **(aggregations or {})
                }
            },
            {'$sort': {'count': -1}}
        ]

        return self.aggregate(pipeline)

    def time_series(
        self,
        date_field: str,
        granularity: str = 'day',
        metric_field: str = None,
        metric_op: str = 'sum'
    ) -> dict:
        """Time series aggregation."""
        date_format = {
            'hour': '%Y-%m-%d %H:00',
            'day': '%Y-%m-%d',
            'week': '%Y-W%V',
            'month': '%Y-%m'
        }.get(granularity, '%Y-%m-%d')

        group_stage = {
            '_id': {
                '$dateToString': {
                    'format': date_format,
                    'date': f'${date_field}'
                }
            },
            'count': {'$sum': 1}
        }

        if metric_field:
            op = f'${metric_op}'
            group_stage['value'] = {op: f'${metric_field}'}

        pipeline = [
            {'$group': group_stage},
            {'$sort': {'_id': 1}}
        ]

        return self.aggregate(pipeline)

    def top_values(
        self,
        field: str,
        limit: int = 10,
        with_count: bool = True
    ) -> dict:
        """Get top values for a field."""
        pipeline = [
            {'$group': {'_id': f'${field}', 'count': {'$sum': 1}}},
            {'$sort': {'count': -1}},
            {'$limit': limit}
        ]

        return self.aggregate(pipeline)

if __name__ == '__main__':
    params = json.loads(sys.argv[1]) if len(sys.argv) > 1 else {}

    tool = AggregationTool(params.get('collection', ''))
    result = tool.aggregate(params.get('pipeline', []))

    print(json.dumps(result))
```

## Step 4: Schema introspection

Explore document structure:

```python
# tools/schema.py
import json
from lib.mongodb import mongo

class SchemaIntrospector:
    """Introspect MongoDB schema."""

    def __init__(self, collection: str, db: str = None):
        self.collection = mongo.collection(collection, db)

    def infer_schema(self, sample_size: int = 100) -> dict:
        """Infer schema from sample documents."""
        try:
            sample = list(self.collection.aggregate([
                {'$sample': {'size': sample_size}}
            ]))

            if not sample:
                return {
                    'success': True,
                    'schema': {},
                    'message': 'Collection is empty'
                }

            schema = self._analyze_documents(sample)

            return {
                'success': True,
                'schema': schema,
                'sample_size': len(sample)
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def _analyze_documents(self, documents: list) -> dict:
        """Analyze documents to infer schema."""
        field_stats = {}

        for doc in documents:
            self._analyze_object(doc, '', field_stats)

        schema = {}
        total = len(documents)

        for field, stats in field_stats.items():
            schema[field] = {
                'types': list(stats['types']),
                'count': stats['count'],
                'presence': round(stats['count'] / total * 100, 1),
                'sample_values': list(stats['samples'])[:3]
            }

        return schema

    def _analyze_object(self, obj: dict, prefix: str, stats: dict):
        """Recursively analyze object fields."""
        for key, value in obj.items():
            field_path = f'{prefix}.{key}' if prefix else key

            if field_path not in stats:
                stats[field_path] = {
                    'types': set(),
                    'count': 0,
                    'samples': set()
                }

            stats[field_path]['types'].add(type(value).__name__)
            stats[field_path]['count'] += 1

            if value is not None and not isinstance(value, (dict, list)):
                sample = str(value)[:50]
                if len(stats[field_path]['samples']) < 5:
                    stats[field_path]['samples'].add(sample)

            if isinstance(value, dict):
                self._analyze_object(value, field_path, stats)
            elif isinstance(value, list) and value and isinstance(value[0], dict):
                self._analyze_object(value[0], f'{field_path}[]', stats)

    def get_indexes(self) -> dict:
        """Get collection indexes."""
        try:
            indexes = list(self.collection.list_indexes())
            return {
                'success': True,
                'indexes': [
                    {
                        'name': idx['name'],
                        'keys': list(idx['key'].keys()),
                        'unique': idx.get('unique', False)
                    }
                    for idx in indexes
                ]
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def get_stats(self) -> dict:
        """Get collection statistics."""
        try:
            stats = self.collection.database.command('collStats', self.collection.name)

            return {
                'success': True,
                'stats': {
                    'document_count': stats.get('count', 0),
                    'size_bytes': stats.get('size', 0),
                    'avg_doc_size': stats.get('avgObjSize', 0),
                    'index_count': stats.get('nindexes', 0),
                    'index_size': stats.get('totalIndexSize', 0)
                }
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}
```

## Step 5: Natural language queries

AI-powered query generation:

```python
# tools/nl_query.py
import json
import anthropic
from lib.mongodb import mongo

class NaturalLanguageQuery:
    """Convert natural language to MongoDB queries."""

    def __init__(self, collection: str, db: str = None):
        self.collection_name = collection
        self.collection = mongo.collection(collection, db)
        self.client = anthropic.Anthropic()
        self.introspector = SchemaIntrospector(collection, db)

    def generate_query(self, question: str) -> dict:
        """Generate MongoDB query from question."""
        schema = self.introspector.infer_schema(50)
        schema_context = json.dumps(schema.get('schema', {}), indent=2)

        prompt = f"""Given this MongoDB collection schema:

Collection: {self.collection_name}
Schema: {schema_context}

Convert this question to a MongoDB query:
{question}

Return a JSON object with either:
1. For find queries: {{"operation": "find", "query": {{}}, "projection": {{}}, "sort": {{}}, "limit": 10}}
2. For aggregation: {{"operation": "aggregate", "pipeline": []}}

Return ONLY the JSON, no explanation."""

        try:
            response = self.client.messages.create(
                model="claude-sonnet-4-20250514",
                max_tokens=1000,
                messages=[{"role": "user", "content": prompt}]
            )

            query_json = response.content[0].text.strip()

            # Parse JSON
            if query_json.startswith("```"):
                query_json = query_json.split("```")[1]
                if query_json.startswith("json"):
                    query_json = query_json[4:]
                query_json = query_json.strip()

            query = json.loads(query_json)

            return {
                'success': True,
                'query': query,
                'question': question
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def query(self, question: str, execute: bool = True) -> dict:
        """Generate and optionally execute query."""
        result = self.generate_query(question)

        if not result['success'] or not execute:
            return result

        query = result['query']

        try:
            if query.get('operation') == 'aggregate':
                tool = AggregationTool(self.collection_name)
                exec_result = tool.aggregate(query['pipeline'])
            else:
                tool = FindTool(self.collection_name)
                exec_result = tool.find(
                    query=query.get('query', {}),
                    projection=query.get('projection'),
                    sort=query.get('sort'),
                    limit=query.get('limit', 10)
                )

            return {
                'success': exec_result['success'],
                'question': question,
                'query': query,
                'data': exec_result.get('data', []),
                'count': exec_result.get('count', 0)
            }
        except Exception as e:
            return {
                'success': False,
                'question': question,
                'query': query,
                'error': str(e)
            }
```

## Step 6: Vector search

Atlas Vector Search:

```python
# tools/vector_search.py
import json
from lib.mongodb import mongo

class VectorSearchTool:
    """MongoDB Atlas Vector Search."""

    def __init__(self, collection: str, db: str = None):
        self.collection = mongo.collection(collection, db)

    def search(
        self,
        query_vector: list,
        index_name: str = 'vector_index',
        path: str = 'embedding',
        num_candidates: int = 100,
        limit: int = 10,
        filter: dict = None
    ) -> dict:
        """Perform vector similarity search."""
        pipeline = [
            {
                '$vectorSearch': {
                    'index': index_name,
                    'path': path,
                    'queryVector': query_vector,
                    'numCandidates': num_candidates,
                    'limit': limit
                }
            },
            {
                '$project': {
                    '_id': 1,
                    'score': {'$meta': 'vectorSearchScore'}
                }
            }
        ]

        if filter:
            pipeline[0]['$vectorSearch']['filter'] = filter

        try:
            results = list(self.collection.aggregate(pipeline))
            return {
                'success': True,
                'data': json.loads(dumps(results)),
                'count': len(results)
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def semantic_search(
        self,
        query: str,
        embedding_func,
        **kwargs
    ) -> dict:
        """Search using text query."""
        # Generate embedding from query
        embedding = embedding_func(query)

        return self.search(
            query_vector=embedding,
            **kwargs
        )
```

## Summary

MongoDB + MCP integration:

1. **Connection management** - Client pooling
2. **CRUD tools** - Document operations
3. **Aggregation** - Complex pipelines
4. **Schema introspection** - Structure analysis
5. **Natural language** - AI-powered queries
6. **Vector search** - Semantic search

Build tools with [Gantz](https://gantz.run), unlock your documents.

Flexible data, intelligent access.

## Related reading

- [PostgreSQL MCP Integration](/post/postgresql-mcp-integration/) - SQL tools
- [Elasticsearch MCP Integration](/post/elasticsearch-mcp-integration/) - Search tools
- [MCP Caching](/post/mcp-caching/) - Cache results

---

*How do you integrate MongoDB with AI agents? Share your patterns.*
