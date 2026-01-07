+++
title = "Elasticsearch MCP Integration: Search Tools for AI Agents"
image = "images/elasticsearch-mcp-integration.webp"
date = 2025-12-11
description = "Build MCP tools for Elasticsearch. Full-text search, aggregations, and AI-powered search experiences."
draft = false
tags = ['mcp', 'elasticsearch', 'search', 'analytics']
voice = false

[howto]
name = "Integrate Elasticsearch with MCP"
totalTime = 30
[[howto.steps]]
name = "Set up Elasticsearch connection"
text = "Configure Elasticsearch client."
[[howto.steps]]
name = "Create search tools"
text = "Build full-text search capabilities."
[[howto.steps]]
name = "Add aggregation tools"
text = "Analytics and faceted search."
[[howto.steps]]
name = "Implement vector search"
text = "Semantic search with embeddings."
[[howto.steps]]
name = "Add AI query enhancement"
text = "Natural language to Elasticsearch queries."
+++


Elasticsearch finds what you need. MCP tools make it intelligent.

Together, they enable AI-powered search experiences.

## Why Elasticsearch + MCP

Elasticsearch provides:
- Full-text search
- Real-time indexing
- Aggregations
- Vector search

MCP tools enable:
- AI-driven queries
- Natural language search
- Automated analysis
- Semantic understanding

## Step 1: Elasticsearch connection

Using [Gantz](https://gantz.run):

```yaml
# gantz.yaml
name: elasticsearch-tools

env:
  ELASTICSEARCH_URL: ${ELASTICSEARCH_URL}
  ELASTICSEARCH_API_KEY: ${ELASTICSEARCH_API_KEY}

tools:
  - name: search
    description: Search documents
    parameters:
      - name: index
        type: string
        required: true
      - name: query
        type: string
        required: true
      - name: size
        type: integer
        default: 10
    script:
      command: python
      args: ["tools/search.py"]

  - name: semantic_search
    description: Semantic search with embeddings
    parameters:
      - name: index
        type: string
        required: true
      - name: query
        type: string
        required: true
    script:
      command: python
      args: ["tools/semantic_search.py"]
```

Elasticsearch client:

```python
# lib/elasticsearch_client.py
import os
from typing import Optional
from elasticsearch import Elasticsearch

class ElasticsearchClient:
    """Elasticsearch client wrapper."""

    _instance: Optional['ElasticsearchClient'] = None
    _client: Optional[Elasticsearch] = None

    def __new__(cls):
        if cls._instance is None:
            cls._instance = super().__new__(cls)
            cls._instance._initialize_client()
        return cls._instance

    def _initialize_client(self):
        """Initialize Elasticsearch client."""
        url = os.environ.get('ELASTICSEARCH_URL', 'http://localhost:9200')
        api_key = os.environ.get('ELASTICSEARCH_API_KEY')

        if api_key:
            self._client = Elasticsearch(
                url,
                api_key=api_key
            )
        else:
            self._client = Elasticsearch(url)

    @property
    def client(self) -> Elasticsearch:
        return self._client

    def ping(self) -> bool:
        """Check connection."""
        return self._client.ping()

# Global instance
es = ElasticsearchClient()
```

## Step 2: Search tools

Full-text search:

```python
# tools/search.py
import sys
import json
from lib.elasticsearch_client import es

class SearchTool:
    """Tool for Elasticsearch search."""

    def __init__(self):
        self.client = es.client

    def search(
        self,
        index: str,
        query: str,
        size: int = 10,
        from_: int = 0,
        fields: list = None,
        filters: dict = None
    ) -> dict:
        """Full-text search."""
        try:
            # Build query
            body = {
                'query': {
                    'bool': {
                        'must': [
                            {
                                'multi_match': {
                                    'query': query,
                                    'fields': fields or ['*'],
                                    'type': 'best_fields',
                                    'fuzziness': 'AUTO'
                                }
                            }
                        ]
                    }
                },
                'size': size,
                'from': from_,
                'highlight': {
                    'fields': {'*': {}},
                    'pre_tags': ['<mark>'],
                    'post_tags': ['</mark>']
                }
            }

            # Add filters
            if filters:
                filter_clauses = []
                for field, value in filters.items():
                    if isinstance(value, list):
                        filter_clauses.append({'terms': {field: value}})
                    else:
                        filter_clauses.append({'term': {field: value}})

                body['query']['bool']['filter'] = filter_clauses

            response = self.client.search(index=index, body=body)

            hits = []
            for hit in response['hits']['hits']:
                hits.append({
                    'id': hit['_id'],
                    'score': hit['_score'],
                    'source': hit['_source'],
                    'highlight': hit.get('highlight', {})
                })

            return {
                'success': True,
                'hits': hits,
                'total': response['hits']['total']['value'],
                'took_ms': response['took']
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def match_phrase(
        self,
        index: str,
        field: str,
        phrase: str,
        slop: int = 0
    ) -> dict:
        """Phrase search."""
        try:
            body = {
                'query': {
                    'match_phrase': {
                        field: {
                            'query': phrase,
                            'slop': slop
                        }
                    }
                }
            }

            response = self.client.search(index=index, body=body)

            return {
                'success': True,
                'hits': [hit['_source'] for hit in response['hits']['hits']],
                'total': response['hits']['total']['value']
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def autocomplete(
        self,
        index: str,
        field: str,
        prefix: str,
        size: int = 10
    ) -> dict:
        """Autocomplete suggestions."""
        try:
            body = {
                'query': {
                    'prefix': {
                        field: {
                            'value': prefix.lower()
                        }
                    }
                },
                'size': size,
                '_source': [field]
            }

            response = self.client.search(index=index, body=body)

            suggestions = list(set([
                hit['_source'].get(field)
                for hit in response['hits']['hits']
                if hit['_source'].get(field)
            ]))

            return {
                'success': True,
                'suggestions': suggestions
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}

if __name__ == '__main__':
    params = json.loads(sys.argv[1]) if len(sys.argv) > 1 else {}

    tool = SearchTool()
    result = tool.search(
        index=params.get('index', ''),
        query=params.get('query', ''),
        size=params.get('size', 10)
    )

    print(json.dumps(result))
```

## Step 3: Aggregation tools

Analytics and facets:

```python
# tools/aggregations.py
import json
from lib.elasticsearch_client import es

class AggregationTool:
    """Tool for Elasticsearch aggregations."""

    def __init__(self):
        self.client = es.client

    def terms_aggregation(
        self,
        index: str,
        field: str,
        size: int = 10,
        query: dict = None
    ) -> dict:
        """Get term counts."""
        try:
            body = {
                'size': 0,
                'aggs': {
                    'terms': {
                        'terms': {
                            'field': field,
                            'size': size
                        }
                    }
                }
            }

            if query:
                body['query'] = query

            response = self.client.search(index=index, body=body)
            buckets = response['aggregations']['terms']['buckets']

            return {
                'success': True,
                'buckets': [
                    {'key': b['key'], 'count': b['doc_count']}
                    for b in buckets
                ],
                'total': response['hits']['total']['value']
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def date_histogram(
        self,
        index: str,
        field: str,
        interval: str = 'day',
        query: dict = None
    ) -> dict:
        """Date histogram aggregation."""
        try:
            body = {
                'size': 0,
                'aggs': {
                    'over_time': {
                        'date_histogram': {
                            'field': field,
                            'calendar_interval': interval
                        }
                    }
                }
            }

            if query:
                body['query'] = query

            response = self.client.search(index=index, body=body)
            buckets = response['aggregations']['over_time']['buckets']

            return {
                'success': True,
                'buckets': [
                    {
                        'date': b['key_as_string'],
                        'count': b['doc_count']
                    }
                    for b in buckets
                ]
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def stats(
        self,
        index: str,
        field: str,
        query: dict = None
    ) -> dict:
        """Get field statistics."""
        try:
            body = {
                'size': 0,
                'aggs': {
                    'stats': {
                        'stats': {'field': field}
                    }
                }
            }

            if query:
                body['query'] = query

            response = self.client.search(index=index, body=body)
            stats = response['aggregations']['stats']

            return {
                'success': True,
                'stats': {
                    'count': stats['count'],
                    'min': stats['min'],
                    'max': stats['max'],
                    'avg': stats['avg'],
                    'sum': stats['sum']
                }
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def faceted_search(
        self,
        index: str,
        query: str,
        facets: list,
        size: int = 10
    ) -> dict:
        """Search with facets."""
        try:
            aggs = {}
            for facet in facets:
                aggs[facet] = {
                    'terms': {
                        'field': facet,
                        'size': 10
                    }
                }

            body = {
                'query': {
                    'multi_match': {
                        'query': query,
                        'fields': ['*']
                    }
                },
                'size': size,
                'aggs': aggs
            }

            response = self.client.search(index=index, body=body)

            facet_results = {}
            for facet in facets:
                facet_results[facet] = [
                    {'key': b['key'], 'count': b['doc_count']}
                    for b in response['aggregations'][facet]['buckets']
                ]

            return {
                'success': True,
                'hits': [hit['_source'] for hit in response['hits']['hits']],
                'total': response['hits']['total']['value'],
                'facets': facet_results
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}
```

## Step 4: Vector search

Semantic search with embeddings:

```python
# tools/semantic_search.py
import json
import anthropic
from lib.elasticsearch_client import es

class SemanticSearchTool:
    """Semantic search using vector embeddings."""

    def __init__(self):
        self.client = es.client
        self.anthropic = anthropic.Anthropic()

    def generate_embedding(self, text: str) -> list:
        """Generate embedding for text."""
        # Using a hypothetical embedding endpoint
        # In practice, use OpenAI, Cohere, or local model
        import hashlib
        # Placeholder - replace with actual embedding generation
        hash_bytes = hashlib.sha256(text.encode()).digest()
        return [float(b) / 255.0 for b in hash_bytes[:768]]

    def knn_search(
        self,
        index: str,
        query_vector: list,
        field: str = 'embedding',
        k: int = 10,
        num_candidates: int = 100,
        filter: dict = None
    ) -> dict:
        """K-nearest neighbors search."""
        try:
            body = {
                'knn': {
                    'field': field,
                    'query_vector': query_vector,
                    'k': k,
                    'num_candidates': num_candidates
                },
                '_source': {'excludes': [field]}
            }

            if filter:
                body['knn']['filter'] = filter

            response = self.client.search(index=index, body=body)

            hits = []
            for hit in response['hits']['hits']:
                hits.append({
                    'id': hit['_id'],
                    'score': hit['_score'],
                    'source': hit['_source']
                })

            return {
                'success': True,
                'hits': hits,
                'total': len(hits)
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def semantic_search(
        self,
        index: str,
        query: str,
        k: int = 10,
        field: str = 'embedding'
    ) -> dict:
        """Search using semantic similarity."""
        try:
            # Generate embedding for query
            query_vector = self.generate_embedding(query)

            # Perform KNN search
            return self.knn_search(
                index=index,
                query_vector=query_vector,
                field=field,
                k=k
            )
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def hybrid_search(
        self,
        index: str,
        query: str,
        k: int = 10,
        text_boost: float = 0.5,
        vector_boost: float = 0.5
    ) -> dict:
        """Hybrid text + vector search."""
        try:
            query_vector = self.generate_embedding(query)

            body = {
                'query': {
                    'bool': {
                        'should': [
                            {
                                'multi_match': {
                                    'query': query,
                                    'fields': ['title^2', 'content'],
                                    'boost': text_boost
                                }
                            }
                        ]
                    }
                },
                'knn': {
                    'field': 'embedding',
                    'query_vector': query_vector,
                    'k': k,
                    'num_candidates': 100,
                    'boost': vector_boost
                },
                'size': k,
                '_source': {'excludes': ['embedding']}
            }

            response = self.client.search(index=index, body=body)

            return {
                'success': True,
                'hits': [
                    {
                        'id': hit['_id'],
                        'score': hit['_score'],
                        'source': hit['_source']
                    }
                    for hit in response['hits']['hits']
                ]
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}

if __name__ == '__main__':
    params = json.loads(sys.argv[1]) if len(sys.argv) > 1 else {}

    tool = SemanticSearchTool()
    result = tool.semantic_search(
        index=params.get('index', ''),
        query=params.get('query', '')
    )

    print(json.dumps(result))
```

## Step 5: Natural language queries

AI-powered query generation:

```python
# tools/nl_search.py
import json
import anthropic
from lib.elasticsearch_client import es

class NaturalLanguageSearch:
    """Convert natural language to Elasticsearch queries."""

    def __init__(self):
        self.client = es.client
        self.anthropic = anthropic.Anthropic()

    def get_index_mapping(self, index: str) -> dict:
        """Get index mapping for context."""
        try:
            mapping = self.client.indices.get_mapping(index=index)
            return mapping[index]['mappings']
        except Exception:
            return {}

    def generate_query(self, index: str, question: str) -> dict:
        """Generate Elasticsearch query from question."""
        mapping = self.get_index_mapping(index)

        prompt = f"""Given this Elasticsearch index mapping:
{json.dumps(mapping, indent=2)}

Convert this question to an Elasticsearch query:
{question}

Return a valid Elasticsearch query DSL JSON object.
Return ONLY the JSON, no explanation."""

        try:
            response = self.anthropic.messages.create(
                model="claude-sonnet-4-20250514",
                max_tokens=1000,
                messages=[{"role": "user", "content": prompt}]
            )

            query_json = response.content[0].text.strip()

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

    def search(self, index: str, question: str) -> dict:
        """Search using natural language."""
        query_result = self.generate_query(index, question)

        if not query_result['success']:
            return query_result

        try:
            response = self.client.search(
                index=index,
                body=query_result['query']
            )

            return {
                'success': True,
                'question': question,
                'query': query_result['query'],
                'hits': [hit['_source'] for hit in response['hits']['hits']],
                'total': response['hits']['total']['value']
            }
        except Exception as e:
            return {
                'success': False,
                'question': question,
                'query': query_result['query'],
                'error': str(e)
            }
```

## Step 6: Index management

Index operations:

```python
# tools/index_management.py
import json
from lib.elasticsearch_client import es

class IndexManager:
    """Manage Elasticsearch indexes."""

    def __init__(self):
        self.client = es.client

    def list_indices(self) -> dict:
        """List all indices."""
        try:
            indices = self.client.cat.indices(format='json')

            return {
                'success': True,
                'indices': [
                    {
                        'name': idx['index'],
                        'docs': idx['docs.count'],
                        'size': idx['store.size'],
                        'health': idx['health']
                    }
                    for idx in indices
                ]
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def get_mapping(self, index: str) -> dict:
        """Get index mapping."""
        try:
            mapping = self.client.indices.get_mapping(index=index)

            return {
                'success': True,
                'mapping': mapping[index]['mappings']
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def get_stats(self, index: str) -> dict:
        """Get index statistics."""
        try:
            stats = self.client.indices.stats(index=index)
            index_stats = stats['indices'][index]

            return {
                'success': True,
                'stats': {
                    'docs': index_stats['primaries']['docs'],
                    'store': index_stats['primaries']['store'],
                    'indexing': index_stats['primaries']['indexing'],
                    'search': index_stats['primaries']['search']
                }
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}
```

## Summary

Elasticsearch + MCP integration:

1. **Connection management** - Client setup
2. **Full-text search** - Query capabilities
3. **Aggregations** - Analytics tools
4. **Vector search** - Semantic search
5. **Natural language** - AI-powered queries
6. **Index management** - Admin tools

Build tools with [Gantz](https://gantz.run), search intelligently.

Find anything, understand everything.

## Related reading

- [MongoDB MCP Integration](/post/mongodb-mcp-integration/) - Document search
- [Pinecone MCP Integration](/post/pinecone-mcp-integration/) - Vector database
- [MCP Caching](/post/mcp-caching/) - Cache search results

---

*How do you integrate search with AI agents? Share your approach.*
