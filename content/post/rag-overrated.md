+++
title = "RAG Is Overrated for Most Use Cases"
date = 2025-12-01
image = "/images/agent-city-03.png"
draft = false
tags = ['agents', 'ai', 'mcp']
+++


Everyone's building RAG. Vector databases. Embeddings. Chunking strategies. Retrieval pipelines.

For most use cases, it's overkill.

## The RAG hype

Every AI tutorial:

```
Step 1: Set up a vector database
Step 2: Chunk your documents
Step 3: Generate embeddings
Step 4: Build retrieval pipeline
Step 5: Query and augment
Step 6: Finally do something useful
```

By step 3, you've spent a week and $200 on infrastructure.

## What RAG actually solves

RAG solves one problem: **your data doesn't fit in the context window**.

```
You have: 10,000 documents (50M tokens)
Context window: 128K tokens
Solution: Retrieve relevant chunks, fit in context
```

That's it. That's the problem RAG solves.

## When you don't need RAG

### Your data fits in context

```
Documents: 50 pages of company policies
Tokens: ~40,000

Context window: 128,000

Math: 40,000 < 128,000

Solution: Just put it all in the system prompt.
```

No embeddings. No vector database. No chunking. Just... include it.

```python
# "RAG" for small datasets
with open("all_policies.md") as f:
    policies = f.read()

response = llm.create(
    messages=[
        {"role": "system", "content": f"Company policies:\n{policies}"},
        {"role": "user", "content": user_question}
    ]
)
```

Done. Ship it.

### Your data is structured

RAG is for unstructured text. If your data is structured, use... structure.

```python
# Don't do this
"Embed product catalog into vectors, retrieve similar products"

# Do this
SELECT * FROM products WHERE category = 'electronics' AND price < 100

# Don't do this
"Embed user database, find similar users"

# Do this
SELECT * FROM users WHERE department = 'engineering'
```

SQL beats embeddings when your data has structure.

### You need exact matches

RAG is semantic search. It finds "similar" content.

```
Query: "What's the refund policy for order #12345?"

RAG returns: "Our refund policy allows returns within 30 days..."
(Similar content, wrong answer)

What you need: Exact lookup of order #12345
```

For exact lookups, use exact lookups.

```python
# Not RAG
def answer_order_question(order_id, question):
    order = db.get_order(order_id)  # Exact lookup
    return llm.answer(question, context=order)
```

### Real-time data

RAG indexes are snapshots. They go stale.

```
User: "What's my account balance?"
RAG: Returns balance from 3 days ago when index was built
User: "That's wrong!"
```

For real-time data, query real-time sources.

```python
# Not RAG
def get_balance(user_id):
    return api.get_current_balance(user_id)  # Live data
```

### Small, focused domains

You're building a FAQ bot for 50 questions.

```
RAG approach:
- Embed 50 questions
- Set up vector DB
- Build retrieval pipeline
- Handle edge cases
- 2 weeks of work

Simple approach:
- Put all 50 Q&As in system prompt
- Done
- 2 hours of work
```

Same result. 100x less effort.

## The RAG complexity tax

### Infrastructure

```
Without RAG:
- Your app
- LLM API

With RAG:
- Your app
- LLM API
- Vector database (Pinecone/Weaviate/Chroma)
- Embedding model
- Document processor
- Chunking pipeline
- Index update jobs
- Retrieval service
```

### Code

```python
# Without RAG
response = llm.create(messages=[
    {"role": "system", "content": context},
    {"role": "user", "content": question}
])

# With RAG
chunks = load_documents(path)
processed = chunk_documents(chunks, size=500, overlap=50)
embeddings = embed(processed, model="text-embedding-3-small")
index = vector_db.create_index(embeddings)

query_embedding = embed(question)
relevant = index.search(query_embedding, top_k=5)
context = "\n".join([r.text for r in relevant])

response = llm.create(messages=[
    {"role": "system", "content": f"Context:\n{context}"},
    {"role": "user", "content": question}
])
```

### Failure modes

RAG introduces new ways to fail:

```
- Chunking splits important info across chunks
- Embedding model misses semantic nuance
- Wrong chunks retrieved
- Relevant info not in top-k results
- Index out of date
- Embedding dimension mismatch
- Vector DB connection issues
```

## The alternatives

### Just use the context window

Modern context windows are huge:

| Model | Context | Pages of text |
|-------|---------|---------------|
| GPT-4o | 128K | ~250 pages |
| Claude 3.5 | 200K | ~400 pages |
| Gemini 1.5 | 1M | ~2000 pages |

If your data fits, stuff it in.

### Use tool calling

Let the AI fetch what it needs.

```yaml
# With Gantz
tools:
  - name: search_docs
    description: Search documentation
    parameters:
      - name: query
        type: string
    script:
      shell: grep -r "{{query}}" ./docs/ | head -20

  - name: get_doc
    description: Get specific document
    parameters:
      - name: name
        type: string
    script:
      shell: cat "./docs/{{name}}.md"
```

AI decides what to fetch. No embeddings required.

### Use simple search

```python
# Full-text search (PostgreSQL)
SELECT content FROM documents
WHERE to_tsvector(content) @@ to_tsquery('refund policy')
LIMIT 5;

# Simple grep
grep -r "refund" ./policies/
```

Full-text search handles most "find relevant content" cases.

### Use structured queries

```python
# Instead of "embed product catalog"
def find_products(user_query):
    # Let LLM generate SQL
    sql = llm.create(
        messages=[{
            "role": "user",
            "content": f"Generate SQL to find products for: {user_query}"
        }]
    ).content

    return db.execute(sql)
```

## When RAG actually makes sense

RAG is the right choice when:

### Large unstructured corpus

```
- 100,000+ documents
- Can't fit in context
- Need semantic search
- Updates are infrequent
```

### Semantic similarity matters

```
Query: "How do I handle angry customers?"
Should find: "Dealing with upset clients", "De-escalation techniques"
(Different words, same meaning)
```

### You've already tried simpler approaches

```
1. ✓ Tried: stuffing in context (didn't fit)
2. ✓ Tried: simple search (missed semantic matches)
3. ✓ Tried: tool-based retrieval (too slow)
4. → RAG: Makes sense now
```

## The decision flowchart

```
                    Start
                      │
                      ▼
          ┌──────────────────────┐
          │ Data fits in context? │
          └──────────┬───────────┘
                     │
           ┌─────────┴─────────┐
          Yes                  No
           │                   │
           ▼                   ▼
    ┌────────────┐   ┌─────────────────────┐
    │ Stuff it   │   │ Data is structured? │
    │ in context │   └──────────┬──────────┘
    └────────────┘              │
                      ┌─────────┴─────────┐
                     Yes                  No
                      │                   │
                      ▼                   ▼
               ┌────────────┐   ┌─────────────────────┐
               │ Use SQL /  │   │ Need semantic match?│
               │ queries    │   └──────────┬──────────┘
               └────────────┘              │
                                 ┌─────────┴─────────┐
                                No                  Yes
                                 │                   │
                                 ▼                   ▼
                          ┌────────────┐      ┌────────────┐
                          │ Full-text  │      │ RAG        │
                          │ search     │      │ (finally)  │
                          └────────────┘      └────────────┘
```

## Simple beats complex

### FAQ Bot

**Over-engineered:**
```
Pinecone + LangChain + Custom embeddings + Chunking pipeline
Development: 2 weeks
Cost: $100/month
```

**Simple:**
```python
FAQ = """
Q: How do I reset my password?
A: Go to Settings > Security > Reset Password

Q: What's your refund policy?
A: Full refund within 30 days...
"""

response = llm.create(
    messages=[
        {"role": "system", "content": f"Answer based on FAQ:\n{FAQ}"},
        {"role": "user", "content": user_question}
    ]
)
```
```
Development: 1 hour
Cost: $0/month (just LLM calls)
```

### Documentation search

**Over-engineered:**
```
Embed all docs → Vector DB → Retrieval pipeline → Re-ranking
```

**Simple with [Gantz](https://gantz.run):**
```yaml
tools:
  - name: search
    description: Search documentation for a topic
    parameters:
      - name: query
        type: string
    script:
      shell: rg -i "{{query}}" ./docs/ -l | head -5

  - name: read
    description: Read a documentation file
    parameters:
      - name: file
        type: string
    script:
      shell: cat "{{file}}"
```

Let the AI search and read. No embeddings.

### Customer support

**Over-engineered:**
```
Embed support history + product docs + user data
Build multi-index RAG system
```

**Simple:**
```python
def answer_support(user_id, question):
    # Fetch relevant data directly
    user = db.get_user(user_id)
    recent_orders = db.get_orders(user_id, limit=5)
    relevant_policy = search_policies(question)  # grep

    context = f"""
User: {user}
Recent orders: {recent_orders}
Relevant policy: {relevant_policy}
"""

    return llm.answer(question, context=context)
```

## Summary

RAG is a tool for a specific problem: semantic search over large unstructured data that doesn't fit in context.

**Before building RAG, try:**

1. Stuffing data in context (if it fits)
2. SQL queries (if data is structured)
3. Full-text search (if exact/keyword match works)
4. Tool-based retrieval (let AI fetch what it needs)

**Only use RAG when:**

- Data is too large for context
- Data is unstructured
- Semantic similarity is required
- Simpler approaches failed

Don't build RAG because it's trendy. Build it because you actually need it.

Most of you don't.

---

*Have you built RAG when you didn't need it? What simpler solution worked instead?*
