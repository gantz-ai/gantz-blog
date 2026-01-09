+++
title = "Pinecone MCP Integration: Vector Search for AI Agents"
image = "images/pinecone-mcp-integration.webp"
date = 2025-12-13
description = "Build MCP tools for Pinecone vector database. Semantic search, RAG pipelines, and embedding management for AI applications."
summary = "Build MCP tools for Pinecone that give AI agents semantic search capabilities with embedding generation, similarity queries, and metadata filtering. This guide covers implementing full RAG pipelines with context retrieval and source citation, hybrid dense-sparse search, batch vector upserts with auto-embedding, and index management for production deployments."
draft = false
tags = ['mcp', 'pinecone', 'vectors', 'search']
voice = false

[howto]
name = "Integrate Pinecone with MCP"
totalTime = 30
[[howto.steps]]
name = "Set up Pinecone connection"
text = "Configure Pinecone client and index."
[[howto.steps]]
name = "Create embedding tools"
text = "Build tools for vector generation."
[[howto.steps]]
name = "Implement search tools"
text = "Semantic similarity search."
[[howto.steps]]
name = "Add upsert tools"
text = "Tools for adding and updating vectors."
[[howto.steps]]
name = "Build RAG pipeline"
text = "Retrieval-augmented generation."
+++


Pinecone stores vectors. AI agents need semantic understanding.

Together, they enable intelligent retrieval.

## Why Pinecone + MCP

Pinecone provides:
- Vector storage at scale
- Fast similarity search
- Metadata filtering
- Serverless operation

MCP tools enable:
- Semantic search
- RAG pipelines
- Knowledge retrieval
- Context augmentation

## Step 1: Pinecone connection

Using [Gantz](https://gantz.run):

```yaml
# gantz.yaml
name: pinecone-tools

env:
  PINECONE_API_KEY: ${PINECONE_API_KEY}
  PINECONE_INDEX: ${PINECONE_INDEX}

tools:
  - name: semantic_search
    description: Search for similar content
    parameters:
      - name: query
        type: string
        required: true
      - name: top_k
        type: integer
        default: 5
    script:
      command: python
      args: ["tools/search.py"]

  - name: upsert_vectors
    description: Add or update vectors
    parameters:
      - name: documents
        type: array
        required: true
    script:
      command: python
      args: ["tools/upsert.py"]
```

Pinecone client:

```python
# lib/pinecone_client.py
import os
from typing import Optional
from pinecone import Pinecone

class PineconeClient:
    """Pinecone client wrapper."""

    _instance: Optional['PineconeClient'] = None

    def __new__(cls):
        if cls._instance is None:
            cls._instance = super().__new__(cls)
            cls._instance._initialize()
        return cls._instance

    def _initialize(self):
        """Initialize Pinecone client."""
        api_key = os.environ.get('PINECONE_API_KEY')
        self._client = Pinecone(api_key=api_key)
        self._index_name = os.environ.get('PINECONE_INDEX', 'default')

    @property
    def client(self) -> Pinecone:
        return self._client

    def index(self, name: str = None):
        """Get index."""
        index_name = name or self._index_name
        return self._client.Index(index_name)

    def list_indexes(self) -> list:
        """List all indexes."""
        return [idx.name for idx in self._client.list_indexes()]

# Global instance
pc = PineconeClient()
```

## Step 2: Embedding tools

Generate embeddings:

```python
# lib/embeddings.py
import os
from typing import List
import anthropic
import httpx

class EmbeddingGenerator:
    """Generate embeddings for text."""

    def __init__(self, model: str = 'text-embedding-3-small'):
        self.model = model
        self.api_key = os.environ.get('OPENAI_API_KEY')

    def generate(self, texts: List[str]) -> List[List[float]]:
        """Generate embeddings for multiple texts."""
        if isinstance(texts, str):
            texts = [texts]

        response = httpx.post(
            'https://api.openai.com/v1/embeddings',
            headers={
                'Authorization': f'Bearer {self.api_key}',
                'Content-Type': 'application/json'
            },
            json={
                'input': texts,
                'model': self.model
            }
        )

        response.raise_for_status()
        data = response.json()

        return [item['embedding'] for item in data['data']]

    def generate_single(self, text: str) -> List[float]:
        """Generate embedding for single text."""
        return self.generate([text])[0]

# Singleton
embedder = EmbeddingGenerator()
```

## Step 3: Search tools

Vector similarity search:

```python
# tools/search.py
import sys
import json
from lib.pinecone_client import pc
from lib.embeddings import embedder

class SearchTool:
    """Tool for Pinecone vector search."""

    def __init__(self, index_name: str = None):
        self.index = pc.index(index_name)

    def search(
        self,
        query: str,
        top_k: int = 5,
        filter: dict = None,
        include_metadata: bool = True
    ) -> dict:
        """Search for similar vectors."""
        try:
            # Generate query embedding
            query_vector = embedder.generate_single(query)

            # Search
            results = self.index.query(
                vector=query_vector,
                top_k=top_k,
                filter=filter,
                include_metadata=include_metadata
            )

            matches = []
            for match in results.matches:
                matches.append({
                    'id': match.id,
                    'score': match.score,
                    'metadata': match.metadata if include_metadata else None
                })

            return {
                'success': True,
                'matches': matches,
                'query': query
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def search_by_id(
        self,
        id: str,
        top_k: int = 5,
        filter: dict = None
    ) -> dict:
        """Search for similar vectors by ID."""
        try:
            # Fetch the vector
            fetch_result = self.index.fetch([id])

            if id not in fetch_result.vectors:
                return {
                    'success': False,
                    'error': f'Vector not found: {id}'
                }

            vector = fetch_result.vectors[id].values

            # Search
            results = self.index.query(
                vector=vector,
                top_k=top_k + 1,  # Exclude self
                filter=filter,
                include_metadata=True
            )

            matches = [
                {
                    'id': m.id,
                    'score': m.score,
                    'metadata': m.metadata
                }
                for m in results.matches
                if m.id != id
            ][:top_k]

            return {
                'success': True,
                'matches': matches,
                'source_id': id
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def hybrid_search(
        self,
        query: str,
        sparse_query: dict,
        top_k: int = 5,
        alpha: float = 0.5
    ) -> dict:
        """Hybrid dense + sparse search."""
        try:
            query_vector = embedder.generate_single(query)

            results = self.index.query(
                vector=query_vector,
                sparse_vector=sparse_query,
                top_k=top_k,
                include_metadata=True
            )

            return {
                'success': True,
                'matches': [
                    {
                        'id': m.id,
                        'score': m.score,
                        'metadata': m.metadata
                    }
                    for m in results.matches
                ]
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}

if __name__ == '__main__':
    params = json.loads(sys.argv[1]) if len(sys.argv) > 1 else {}

    tool = SearchTool()
    result = tool.search(
        query=params.get('query', ''),
        top_k=params.get('top_k', 5),
        filter=params.get('filter')
    )

    print(json.dumps(result))
```

## Step 4: Upsert tools

Add and update vectors:

```python
# tools/upsert.py
import sys
import json
import uuid
from typing import List, Dict, Any
from lib.pinecone_client import pc
from lib.embeddings import embedder

class UpsertTool:
    """Tool for upserting vectors to Pinecone."""

    def __init__(self, index_name: str = None):
        self.index = pc.index(index_name)

    def upsert(
        self,
        documents: List[Dict[str, Any]],
        namespace: str = ''
    ) -> dict:
        """Upsert documents with auto-generated embeddings."""
        try:
            vectors = []

            for doc in documents:
                # Get or generate ID
                doc_id = doc.get('id', str(uuid.uuid4()))

                # Get text for embedding
                text = doc.get('text', '')
                if not text:
                    continue

                # Generate embedding
                embedding = embedder.generate_single(text)

                # Prepare metadata
                metadata = doc.get('metadata', {})
                metadata['text'] = text[:1000]  # Store truncated text

                vectors.append({
                    'id': doc_id,
                    'values': embedding,
                    'metadata': metadata
                })

            # Batch upsert
            batch_size = 100
            upserted = 0

            for i in range(0, len(vectors), batch_size):
                batch = vectors[i:i + batch_size]
                self.index.upsert(
                    vectors=batch,
                    namespace=namespace
                )
                upserted += len(batch)

            return {
                'success': True,
                'upserted': upserted
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def upsert_vectors(
        self,
        vectors: List[Dict[str, Any]],
        namespace: str = ''
    ) -> dict:
        """Upsert pre-computed vectors."""
        try:
            batch_size = 100
            upserted = 0

            for i in range(0, len(vectors), batch_size):
                batch = vectors[i:i + batch_size]
                self.index.upsert(
                    vectors=batch,
                    namespace=namespace
                )
                upserted += len(batch)

            return {
                'success': True,
                'upserted': upserted
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def delete(
        self,
        ids: List[str] = None,
        filter: dict = None,
        namespace: str = ''
    ) -> dict:
        """Delete vectors."""
        try:
            if ids:
                self.index.delete(ids=ids, namespace=namespace)
            elif filter:
                self.index.delete(filter=filter, namespace=namespace)
            else:
                return {
                    'success': False,
                    'error': 'Must provide ids or filter'
                }

            return {'success': True}
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def update_metadata(
        self,
        id: str,
        metadata: dict,
        namespace: str = ''
    ) -> dict:
        """Update vector metadata."""
        try:
            self.index.update(
                id=id,
                set_metadata=metadata,
                namespace=namespace
            )

            return {'success': True, 'id': id}
        except Exception as e:
            return {'success': False, 'error': str(e)}

if __name__ == '__main__':
    params = json.loads(sys.argv[1]) if len(sys.argv) > 1 else {}

    tool = UpsertTool()
    result = tool.upsert(
        documents=params.get('documents', [])
    )

    print(json.dumps(result))
```

## Step 5: RAG pipeline

Retrieval-augmented generation:

```python
# tools/rag.py
import json
import anthropic
from lib.pinecone_client import pc
from lib.embeddings import embedder

class RAGTool:
    """Retrieval-Augmented Generation pipeline."""

    def __init__(self, index_name: str = None):
        self.index = pc.index(index_name)
        self.anthropic = anthropic.Anthropic()

    def retrieve(
        self,
        query: str,
        top_k: int = 5,
        filter: dict = None
    ) -> List[dict]:
        """Retrieve relevant context."""
        query_vector = embedder.generate_single(query)

        results = self.index.query(
            vector=query_vector,
            top_k=top_k,
            filter=filter,
            include_metadata=True
        )

        return [
            {
                'id': m.id,
                'text': m.metadata.get('text', ''),
                'score': m.score,
                'metadata': m.metadata
            }
            for m in results.matches
        ]

    def generate(
        self,
        query: str,
        context: List[dict],
        system_prompt: str = None
    ) -> str:
        """Generate response with context."""
        # Build context string
        context_text = "\n\n".join([
            f"[Source {i+1}] (relevance: {c['score']:.2f})\n{c['text']}"
            for i, c in enumerate(context)
        ])

        # Default system prompt
        if not system_prompt:
            system_prompt = """You are a helpful assistant. Answer questions based on the provided context.
If the context doesn't contain relevant information, say so.
Always cite your sources using [Source N] notation."""

        messages = [
            {
                "role": "user",
                "content": f"""Context:
{context_text}

Question: {query}

Please answer based on the context provided."""
            }
        ]

        response = self.anthropic.messages.create(
            model="claude-sonnet-4-20250514",
            max_tokens=1000,
            system=system_prompt,
            messages=messages
        )

        return response.content[0].text

    def query(
        self,
        question: str,
        top_k: int = 5,
        filter: dict = None,
        include_sources: bool = True
    ) -> dict:
        """Full RAG pipeline: retrieve and generate."""
        try:
            # Retrieve context
            context = self.retrieve(question, top_k, filter)

            if not context:
                return {
                    'success': True,
                    'answer': "I couldn't find relevant information to answer your question.",
                    'sources': []
                }

            # Generate response
            answer = self.generate(question, context)

            result = {
                'success': True,
                'answer': answer,
                'question': question
            }

            if include_sources:
                result['sources'] = [
                    {
                        'id': c['id'],
                        'text': c['text'][:200] + '...' if len(c['text']) > 200 else c['text'],
                        'score': c['score']
                    }
                    for c in context
                ]

            return result
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def chat(
        self,
        messages: List[dict],
        top_k: int = 5
    ) -> dict:
        """RAG-enhanced chat."""
        try:
            # Get latest user message
            latest_query = messages[-1]['content']

            # Retrieve context
            context = self.retrieve(latest_query, top_k)

            # Build context-enhanced messages
            context_text = "\n\n".join([
                f"[Source {i+1}]\n{c['text']}"
                for i, c in enumerate(context)
            ])

            enhanced_messages = messages.copy()
            enhanced_messages[-1] = {
                'role': 'user',
                'content': f"""Relevant context:
{context_text}

User question: {latest_query}"""
            }

            response = self.anthropic.messages.create(
                model="claude-sonnet-4-20250514",
                max_tokens=1000,
                messages=enhanced_messages
            )

            return {
                'success': True,
                'response': response.content[0].text,
                'context_used': len(context)
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}
```

## Step 6: Index management

Manage Pinecone indexes:

```python
# tools/index_management.py
import json
from lib.pinecone_client import pc

class IndexManager:
    """Manage Pinecone indexes."""

    def __init__(self):
        self.client = pc.client

    def list_indexes(self) -> dict:
        """List all indexes."""
        try:
            indexes = self.client.list_indexes()

            return {
                'success': True,
                'indexes': [
                    {
                        'name': idx.name,
                        'dimension': idx.dimension,
                        'metric': idx.metric,
                        'host': idx.host
                    }
                    for idx in indexes
                ]
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def describe_index(self, name: str) -> dict:
        """Get index details."""
        try:
            index = self.client.Index(name)
            stats = index.describe_index_stats()

            return {
                'success': True,
                'stats': {
                    'total_vector_count': stats.total_vector_count,
                    'dimension': stats.dimension,
                    'namespaces': {
                        ns: {'vector_count': data.vector_count}
                        for ns, data in stats.namespaces.items()
                    }
                }
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def create_index(
        self,
        name: str,
        dimension: int,
        metric: str = 'cosine'
    ) -> dict:
        """Create new index."""
        try:
            from pinecone import ServerlessSpec

            self.client.create_index(
                name=name,
                dimension=dimension,
                metric=metric,
                spec=ServerlessSpec(
                    cloud='aws',
                    region='us-east-1'
                )
            )

            return {'success': True, 'name': name}
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def delete_index(self, name: str) -> dict:
        """Delete index."""
        try:
            self.client.delete_index(name)
            return {'success': True, 'deleted': name}
        except Exception as e:
            return {'success': False, 'error': str(e)}
```

## Summary

Pinecone + MCP integration:

1. **Connection setup** - Client configuration
2. **Embedding generation** - Vector creation
3. **Semantic search** - Similarity queries
4. **Upsert operations** - Vector management
5. **RAG pipeline** - Retrieval + generation
6. **Index management** - Admin tools

Build tools with [Gantz](https://gantz.run), enable semantic AI.

Vectors unlock understanding.

## Related reading

- [Elasticsearch MCP Integration](/post/elasticsearch-mcp-integration/) - Text search
- [MCP Caching](/post/mcp-caching/) - Cache embeddings

---

*How do you use vector search with AI agents? Share your patterns.*
