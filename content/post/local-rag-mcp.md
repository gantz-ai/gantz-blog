+++
title = "Build a local RAG with MCP"
date = 2025-12-16
draft = false
tags = ['agents', 'ai', 'mcp']
+++


RAG (Retrieval Augmented Generation) is usually a whole production — vector databases, embeddings APIs, chunking strategies, the works.

But what if you just want Claude to search your local docs and answer questions? No cloud services, no complex setup.

Here's how I built a local RAG in about 30 minutes using MCP.

## The idea

```
You → Claude → MCP Server → Search local files → Return relevant chunks → Claude answers
```

Your documents stay on your machine. Claude searches them through MCP tools, finds relevant content, and uses it to answer.

## What you'll need

- [Gantz CLI](https://gantz.run)
- Python with a few libraries
- Some documents to search (markdown, txt, pdf, whatever)
- 30 minutes

## The simple approach (no vectors)

Let's start dead simple — grep-style search. Works surprisingly well for smaller document sets.

**search_docs.py:**

```python
#!/usr/bin/env python3
import os
import sys
import re
from pathlib import Path

DOCS_DIR = os.environ.get('DOCS_DIR', './docs')

def search(query, max_results=5):
    results = []
    query_lower = query.lower()

    for path in Path(DOCS_DIR).rglob('*'):
        if path.is_file() and path.suffix in ['.md', '.txt', '.py', '.js', '.ts']:
            try:
                content = path.read_text(encoding='utf-8')
                if query_lower in content.lower():
                    # Find the matching section
                    lines = content.split('\n')
                    for i, line in enumerate(lines):
                        if query_lower in line.lower():
                            # Get surrounding context (5 lines before/after)
                            start = max(0, i - 5)
                            end = min(len(lines), i + 6)
                            snippet = '\n'.join(lines[start:end])
                            results.append({
                                'file': str(path.relative_to(DOCS_DIR)),
                                'line': i + 1,
                                'snippet': snippet
                            })
                            if len(results) >= max_results:
                                return results
            except:
                continue

    return results

def main():
    if len(sys.argv) < 2:
        print("Usage: search_docs.py <query>")
        sys.exit(1)

    query = ' '.join(sys.argv[1:])
    results = search(query)

    if not results:
        print("No results found.")
        return

    for r in results:
        print(f"## {r['file']} (line {r['line']})")
        print(r['snippet'])
        print("\n---\n")

if __name__ == '__main__':
    main()
```

**list_docs.py:**

```python
#!/usr/bin/env python3
import os
from pathlib import Path

DOCS_DIR = os.environ.get('DOCS_DIR', './docs')

def main():
    for path in sorted(Path(DOCS_DIR).rglob('*')):
        if path.is_file() and path.suffix in ['.md', '.txt', '.py', '.js', '.ts', '.json']:
            rel_path = path.relative_to(DOCS_DIR)
            size = path.stat().st_size
            print(f"{rel_path} ({size} bytes)")

if __name__ == '__main__':
    main()
```

**read_doc.py:**

```python
#!/usr/bin/env python3
import os
import sys
from pathlib import Path

DOCS_DIR = os.environ.get('DOCS_DIR', './docs')

def main():
    if len(sys.argv) < 2:
        print("Usage: read_doc.py <filename>")
        sys.exit(1)

    filename = sys.argv[1]
    path = Path(DOCS_DIR) / filename

    if not path.exists():
        print(f"File not found: {filename}")
        sys.exit(1)

    # Optional: limit lines
    max_lines = int(sys.argv[2]) if len(sys.argv) > 2 else 200

    content = path.read_text(encoding='utf-8')
    lines = content.split('\n')[:max_lines]
    print('\n'.join(lines))

    if len(content.split('\n')) > max_lines:
        print(f"\n... truncated ({len(content.split(chr(10)))} total lines)")

if __name__ == '__main__':
    main()
```

## MCP config

```yaml
name: local-rag
description: Search and read local documents

tools:
  - name: search_docs
    description: Search documents for a query. Returns matching snippets with file names and line numbers.
    parameters:
      - name: query
        type: string
        required: true
        description: The search query
    script:
      command: python3
      args: ["./scripts/search_docs.py", "{{query}}"]
      working_dir: "${HOME}/rag-tools"
    environment:
      DOCS_DIR: "${HOME}/Documents/notes"

  - name: list_docs
    description: List all available documents
    parameters: []
    script:
      command: python3
      args: ["./scripts/list_docs.py"]
      working_dir: "${HOME}/rag-tools"
    environment:
      DOCS_DIR: "${HOME}/Documents/notes"

  - name: read_doc
    description: Read a specific document by filename
    parameters:
      - name: filename
        type: string
        required: true
        description: The filename to read (from list_docs output)
      - name: max_lines
        type: integer
        default: 200
        description: Maximum lines to return
    script:
      command: python3
      args: ["./scripts/read_doc.py", "{{filename}}", "{{max_lines}}"]
      working_dir: "${HOME}/rag-tools"
    environment:
      DOCS_DIR: "${HOME}/Documents/notes"
```

## Run it

```bash
gantz run --auth
```

## Connect Claude

```python
import anthropic

client = anthropic.Anthropic(api_key="your-api-key")

response = client.beta.messages.create(
    model="claude-sonnet-4-5-20250929",
    max_tokens=2048,
    system="""You are a helpful assistant with access to a local document library.
When answering questions:
1. First search for relevant documents
2. Read specific files if needed for more context
3. Cite your sources with filenames
4. If you can't find relevant info, say so""",
    messages=[{"role": "user", "content": "How do I configure the database connection?"}],
    mcp_servers=[{
        "type": "url",
        "url": "https://your-tunnel.gantz.run/sse",
        "name": "docs",
        "authorization_token": "your-token"
    }],
    tools=[{"type": "mcp_toolset", "mcp_server_name": "docs"}],
    betas=["mcp-client-2025-11-20"]
)

for block in response.content:
    if hasattr(block, "text"):
        print(block.text)
```

## Level up: Vector search

For larger document sets, add vector search. Here's a simple local setup using sentence-transformers:

```bash
pip install sentence-transformers faiss-cpu
```

**index_docs.py** (run once to build index):

```python
#!/usr/bin/env python3
import os
import pickle
from pathlib import Path
from sentence_transformers import SentenceTransformer
import faiss
import numpy as np

DOCS_DIR = os.environ.get('DOCS_DIR', './docs')
INDEX_DIR = os.environ.get('INDEX_DIR', './index')

def chunk_text(text, chunk_size=500, overlap=50):
    """Split text into overlapping chunks"""
    words = text.split()
    chunks = []
    for i in range(0, len(words), chunk_size - overlap):
        chunk = ' '.join(words[i:i + chunk_size])
        if chunk:
            chunks.append(chunk)
    return chunks

def main():
    model = SentenceTransformer('all-MiniLM-L6-v2')

    documents = []
    chunks = []

    for path in Path(DOCS_DIR).rglob('*'):
        if path.is_file() and path.suffix in ['.md', '.txt']:
            try:
                content = path.read_text(encoding='utf-8')
                file_chunks = chunk_text(content)
                for i, chunk in enumerate(file_chunks):
                    chunks.append(chunk)
                    documents.append({
                        'file': str(path.relative_to(DOCS_DIR)),
                        'chunk_index': i,
                        'content': chunk
                    })
            except:
                continue

    print(f"Indexing {len(chunks)} chunks from {len(set(d['file'] for d in documents))} files...")

    embeddings = model.encode(chunks, show_progress_bar=True)
    embeddings = np.array(embeddings).astype('float32')

    # Build FAISS index
    dimension = embeddings.shape[1]
    index = faiss.IndexFlatL2(dimension)
    index.add(embeddings)

    # Save
    os.makedirs(INDEX_DIR, exist_ok=True)
    faiss.write_index(index, f"{INDEX_DIR}/docs.index")
    with open(f"{INDEX_DIR}/documents.pkl", 'wb') as f:
        pickle.dump(documents, f)

    print(f"Index saved to {INDEX_DIR}")

if __name__ == '__main__':
    main()
```

**vector_search.py:**

```python
#!/usr/bin/env python3
import os
import sys
import pickle
from sentence_transformers import SentenceTransformer
import faiss
import numpy as np

INDEX_DIR = os.environ.get('INDEX_DIR', './index')

def main():
    if len(sys.argv) < 2:
        print("Usage: vector_search.py <query> [num_results]")
        sys.exit(1)

    query = ' '.join(sys.argv[1:-1]) if len(sys.argv) > 2 else sys.argv[1]
    k = int(sys.argv[-1]) if len(sys.argv) > 2 and sys.argv[-1].isdigit() else 5

    # Load index
    index = faiss.read_index(f"{INDEX_DIR}/docs.index")
    with open(f"{INDEX_DIR}/documents.pkl", 'rb') as f:
        documents = pickle.load(f)

    # Search
    model = SentenceTransformer('all-MiniLM-L6-v2')
    query_embedding = model.encode([query]).astype('float32')

    distances, indices = index.search(query_embedding, k)

    for i, idx in enumerate(indices[0]):
        if idx < len(documents):
            doc = documents[idx]
            score = 1 / (1 + distances[0][i])  # Convert distance to similarity
            print(f"## {doc['file']} (score: {score:.3f})")
            print(doc['content'][:500])
            print("\n---\n")

if __name__ == '__main__':
    main()
```

Add to your gantz.yaml:

```yaml
  - name: vector_search
    description: Semantic search using embeddings. Better for conceptual queries.
    parameters:
      - name: query
        type: string
        required: true
      - name: num_results
        type: integer
        default: 5
    script:
      command: python3
      args: ["./scripts/vector_search.py", "{{query}}", "{{num_results}}"]
      working_dir: "${HOME}/rag-tools"
    environment:
      INDEX_DIR: "${HOME}/rag-tools/index"
```

## When to use what

**Simple text search:**
- Small document sets (< 1000 files)
- Exact keyword matches
- Code search
- Fast, no setup

**Vector search:**
- Large document sets
- Conceptual/semantic queries ("how do I..." vs exact terms)
- Finding similar content
- Requires indexing step

## What you can ask

```
"How do I set up authentication?"
→ Searches docs, finds auth-related sections, answers with citations

"What's the API rate limit?"
→ Finds relevant docs, extracts the specific info

"Summarize the deployment guide"
→ Reads the doc and summarizes

"What files mention database migrations?"
→ Lists all matching files

"Compare the two approaches mentioned in the architecture doc"
→ Reads doc, analyzes, compares
```

## Ideas to extend

- **PDF support** — Add PyPDF2 or pdfplumber
- **Web scraping** — Index your favorite docs sites
- **Code search** — Index your codebase
- **Chat history** — Remember previous questions
- **Auto-reindex** — Watch for file changes

## Why local?

Your documents never leave your machine. No uploading to Pinecone, no OpenAI embeddings API. Everything runs locally.

Good for:
- Private/sensitive docs
- Offline access
- No API costs
- Full control

---

*What would you index? I'm using this for my personal notes and it's already saving me tons of time.*
