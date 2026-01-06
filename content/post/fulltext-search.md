+++
title = "Full-Text Search: The RAG Alternative Nobody Tries"
date = 2025-12-20
image = "images/agent-city-01.png"
draft = false
tags = ['rag', 'architecture', 'comparison']
+++


Everyone reaches for vector databases.

Embeddings. Chunking pipelines. Semantic search. The whole stack.

Meanwhile, full-text search sits there. Battle-tested for 30 years. Works out of the box.

And nobody tries it first.

## The RAG reflex

Developer needs search:

```
"I need to search documents"

Brain: Embeddings → Vector DB → RAG pipeline

Result: 2 weeks of setup, $200/month infrastructure
```

What if you just... searched?

```sql
SELECT * FROM documents
WHERE content ILIKE '%refund policy%'
```

Sometimes that's all you need.

## What is full-text search?

Full-text search indexes words, not vectors.

```
Document: "The quick brown fox jumps over the lazy dog"

Full-text index:
  "quick" → doc1
  "brown" → doc1
  "fox" → doc1
  "jumps" → doc1
  ...

Query: "quick fox"
Match: doc1 (contains both words)
```

No embeddings. No ML. Just word matching with smarts.

### The smarts

Full-text search isn't just LIKE queries. It handles:

**Stemming**: "running" matches "run", "runs", "ran"

**Ranking**: Documents with more matches rank higher

**Proximity**: "quick fox" ranks higher when words are close

**Stop words**: Ignores "the", "a", "is"

**Fuzzy matching**: "quik" can match "quick"

## When full-text beats RAG

### Exact terminology matters

```
User: "What's the MAX_CONNECTIONS setting?"

RAG returns: "Connection pooling improves performance..."
(Semantically similar, wrong answer)

Full-text returns: "MAX_CONNECTIONS=100 sets the connection limit"
(Exact match, right answer)
```

Technical docs, config references, API docs - exact terms matter.

### Keywords are specific

```
User: "Error code E_AUTH_FAILED"

RAG returns: "Authentication errors can occur when..."
(Related concept, not the error code)

Full-text returns: "E_AUTH_FAILED: Invalid credentials provided"
(Exact error code match)
```

Error codes, product IDs, specific terminology.

### Small corpus

```
Your data: 500 documents

RAG:
- Generate 500 embeddings ($0.10)
- Set up vector DB
- Build retrieval pipeline
- Debug relevance issues

Full-text:
- Add to PostgreSQL
- CREATE INDEX
- Done
```

For small corpora, full-text is dramatically simpler.

### Real-time updates

```
RAG:
- New doc → generate embedding → update index → hope cache invalidates

Full-text:
- INSERT INTO documents → instantly searchable
```

Full-text indexes update in real-time. Vector indexes often don't.

### Zero hallucination tolerance

```
User: "What's the exact wording of section 3.2?"

RAG might paraphrase or combine chunks.
Full-text returns exactly what's in section 3.2.
```

Legal, compliance, quotes - when exact text matters.

## Implementation

### PostgreSQL (built-in)

```sql
-- Add full-text search column
ALTER TABLE documents ADD COLUMN search_vector tsvector;

-- Populate it
UPDATE documents SET search_vector = to_tsvector('english', content);

-- Create index
CREATE INDEX idx_search ON documents USING GIN(search_vector);

-- Search
SELECT title, content
FROM documents
WHERE search_vector @@ to_tsquery('english', 'refund & policy')
ORDER BY ts_rank(search_vector, to_tsquery('english', 'refund & policy')) DESC
LIMIT 5;
```

That's it. Full-text search in 4 lines.

### With automatic updates

```sql
-- Auto-update search vector on insert/update
CREATE OR REPLACE FUNCTION update_search_vector()
RETURNS TRIGGER AS $$
BEGIN
  NEW.search_vector := to_tsvector('english', COALESCE(NEW.title, '') || ' ' || COALESCE(NEW.content, ''));
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER documents_search_update
BEFORE INSERT OR UPDATE ON documents
FOR EACH ROW EXECUTE FUNCTION update_search_vector();
```

Now every insert is automatically indexed.

### SQLite (for simpler setups)

```sql
-- Create FTS5 virtual table
CREATE VIRTUAL TABLE documents_fts USING fts5(title, content);

-- Insert documents
INSERT INTO documents_fts VALUES ('Refund Policy', 'Full refund within 30 days...');

-- Search
SELECT * FROM documents_fts WHERE documents_fts MATCH 'refund';

-- Ranked search
SELECT *, rank FROM documents_fts WHERE documents_fts MATCH 'refund policy' ORDER BY rank;
```

SQLite FTS5 is surprisingly powerful. Zero infrastructure.

### Python wrapper

```python
import psycopg2

class FullTextSearch:
    def __init__(self, connection_string):
        self.conn = psycopg2.connect(connection_string)

    def search(self, query: str, limit: int = 5) -> list:
        """Search documents using full-text search"""
        # Convert natural query to tsquery
        # "refund policy" → "refund & policy"
        terms = query.split()
        tsquery = " & ".join(terms)

        with self.conn.cursor() as cur:
            cur.execute("""
                SELECT title, content,
                       ts_rank(search_vector, to_tsquery('english', %s)) as rank
                FROM documents
                WHERE search_vector @@ to_tsquery('english', %s)
                ORDER BY rank DESC
                LIMIT %s
            """, (tsquery, tsquery, limit))

            return [
                {"title": row[0], "content": row[1], "score": row[2]}
                for row in cur.fetchall()
            ]

    def add_document(self, title: str, content: str):
        """Add document (auto-indexed via trigger)"""
        with self.conn.cursor() as cur:
            cur.execute(
                "INSERT INTO documents (title, content) VALUES (%s, %s)",
                (title, content)
            )
        self.conn.commit()
```

### Integration with agent

```python
class AgentWithSearch:
    def __init__(self, llm, search: FullTextSearch):
        self.llm = llm
        self.search = search
        self.tools = [
            {
                "type": "function",
                "function": {
                    "name": "search_docs",
                    "description": "Search documentation for specific terms or phrases",
                    "parameters": {
                        "type": "object",
                        "properties": {
                            "query": {"type": "string", "description": "Search terms"}
                        },
                        "required": ["query"]
                    }
                }
            }
        ]

    def execute_tool(self, name: str, args: dict) -> str:
        if name == "search_docs":
            results = self.search.search(args["query"])

            if not results:
                return "No documents found matching your query."

            output = f"Found {len(results)} results:\n\n"
            for i, r in enumerate(results, 1):
                output += f"{i}. {r['title']}\n{r['content'][:500]}...\n\n"

            return output

        return "Unknown tool"
```

## Advanced full-text features

### Phrase search

```sql
-- Exact phrase
SELECT * FROM documents
WHERE search_vector @@ phraseto_tsquery('english', 'refund policy');

-- Words near each other
SELECT * FROM documents
WHERE search_vector @@ to_tsquery('english', 'refund <2> policy');  -- within 2 words
```

### Fuzzy matching

```sql
-- PostgreSQL pg_trgm extension
CREATE EXTENSION pg_trgm;

SELECT * FROM documents
WHERE content % 'refnd polcy'  -- Typo-tolerant
ORDER BY similarity(content, 'refnd polcy') DESC;
```

### Highlighting

```sql
SELECT title,
       ts_headline('english', content,
                   to_tsquery('english', 'refund & policy'),
                   'StartSel=<b>, StopSel=</b>') as highlighted
FROM documents
WHERE search_vector @@ to_tsquery('english', 'refund & policy');
```

Returns: "...request a <b>refund</b> according to our <b>policy</b>..."

### Boosting fields

```sql
-- Title matches worth more than content matches
SELECT *,
       ts_rank(setweight(to_tsvector(title), 'A') ||
               setweight(to_tsvector(content), 'B'),
               to_tsquery('refund')) as rank
FROM documents
ORDER BY rank DESC;
```

## Full-text vs RAG comparison

| Aspect | Full-Text Search | RAG |
|--------|-----------------|-----|
| Setup time | Minutes | Days |
| Infrastructure | Your existing DB | Vector DB + embedding service |
| Cost | Free (built into DB) | $$ (embeddings + vector DB) |
| Exact matches | ✓ Excellent | ✗ Struggles |
| Semantic matches | ✗ Limited | ✓ Excellent |
| Real-time updates | ✓ Instant | ✗ Requires re-indexing |
| Debugging | Easy (it's just SQL) | Hard (why did it return that?) |
| Latency | <10ms | 100-500ms |

## Hybrid: Best of both

Use both. Full-text for precision, vectors for recall.

```python
class HybridSearch:
    def __init__(self, fulltext_db, vector_db):
        self.fulltext = fulltext_db
        self.vector = vector_db

    def search(self, query: str, limit: int = 5) -> list:
        # Get candidates from both
        fulltext_results = self.fulltext.search(query, limit=limit*2)
        vector_results = self.vector.search(query, limit=limit*2)

        # Combine and dedupe
        seen = set()
        combined = []

        for r in fulltext_results:
            if r["id"] not in seen:
                r["source"] = "fulltext"
                combined.append(r)
                seen.add(r["id"])

        for r in vector_results:
            if r["id"] not in seen:
                r["source"] = "vector"
                combined.append(r)
                seen.add(r["id"])

        # Rerank combined results
        return self.rerank(combined, query)[:limit]

    def rerank(self, results: list, query: str) -> list:
        # Simple: boost exact matches
        for r in results:
            if query.lower() in r["content"].lower():
                r["score"] *= 1.5  # Boost exact matches

        return sorted(results, key=lambda x: x["score"], reverse=True)
```

### Reciprocal Rank Fusion

A better way to combine:

```python
def reciprocal_rank_fusion(result_lists: list, k: int = 60) -> list:
    """Combine multiple ranked lists using RRF"""
    scores = {}

    for results in result_lists:
        for rank, doc in enumerate(results):
            doc_id = doc["id"]
            if doc_id not in scores:
                scores[doc_id] = {"doc": doc, "score": 0}
            scores[doc_id]["score"] += 1 / (k + rank + 1)

    combined = sorted(scores.values(), key=lambda x: x["score"], reverse=True)
    return [item["doc"] for item in combined]

# Usage
fulltext_results = fulltext.search(query)
vector_results = vector.search(query)
combined = reciprocal_rank_fusion([fulltext_results, vector_results])
```

## Decision flowchart

```
                     Start
                       │
                       ▼
            ┌─────────────────────┐
            │ Exact terms matter? │
            │ (codes, IDs, names) │
            └──────────┬──────────┘
                       │
              ┌────────┴────────┐
             Yes                No
              │                 │
              ▼                 ▼
        ┌──────────┐  ┌─────────────────────┐
        │Full-text │  │Need semantic match? │
        │ search   │  │("angry" → "upset")  │
        └──────────┘  └──────────┬──────────┘
                                 │
                        ┌────────┴────────┐
                       No                Yes
                        │                 │
                        ▼                 ▼
                  ┌──────────┐     ┌──────────────┐
                  │Full-text │     │Corpus > 10K? │
                  │ search   │     └──────┬───────┘
                  └──────────┘            │
                                 ┌────────┴────────┐
                                No                Yes
                                 │                 │
                                 ▼                 ▼
                          ┌───────────┐     ┌──────────┐
                          │ Stuff in  │     │   RAG    │
                          │ context   │     │          │
                          └───────────┘     └──────────┘
```

## Implementation with Gantz

Using [Gantz](https://gantz.run) with full-text search:

```yaml
# gantz.yaml
tools:
  - name: search
    description: Search documentation. Use specific keywords for best results.
    parameters:
      - name: query
        type: string
        required: true
    script:
      shell: |
        psql -d mydb -c "
          SELECT title, left(content, 500)
          FROM documents
          WHERE search_vector @@ plainto_tsquery('english', '{{query}}')
          ORDER BY ts_rank(search_vector, plainto_tsquery('english', '{{query}}')) DESC
          LIMIT 5
        "

  - name: search_exact
    description: Search for exact phrase in documentation
    parameters:
      - name: phrase
        type: string
        required: true
    script:
      shell: |
        psql -d mydb -c "
          SELECT title, left(content, 500)
          FROM documents
          WHERE content ILIKE '%{{phrase}}%'
          LIMIT 5
        "
```

No vector database. Just PostgreSQL.

## Quick start

### 1. Add full-text to existing table

```sql
-- Add column
ALTER TABLE documents ADD COLUMN search_vector tsvector;

-- Index existing content
UPDATE documents SET search_vector = to_tsvector('english', title || ' ' || content);

-- Create index
CREATE INDEX idx_fts ON documents USING GIN(search_vector);
```

### 2. Search

```sql
SELECT * FROM documents
WHERE search_vector @@ plainto_tsquery('english', 'your search query')
ORDER BY ts_rank(search_vector, plainto_tsquery('english', 'your search query')) DESC
LIMIT 10;
```

### 3. Done

No embeddings. No vector DB. No chunking pipeline. Just search.

## Summary

Before you build RAG:

1. **Try full-text search first**
   - Built into PostgreSQL, SQLite, MySQL
   - Zero additional infrastructure
   - Works in minutes, not days

2. **Use full-text when:**
   - Exact terms matter
   - Small-medium corpus
   - Real-time updates needed
   - You need to debug results

3. **Use RAG when:**
   - Semantic similarity matters
   - Synonyms and concepts > keywords
   - Corpus is huge
   - Full-text tried and failed

4. **Consider hybrid:**
   - Full-text for precision
   - Vectors for recall
   - RRF to combine

Stop overengineering. Try the simple thing first.

---

*Have you tried full-text search before reaching for vectors? What was your experience?*
