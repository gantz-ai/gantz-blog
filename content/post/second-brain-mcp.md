+++
title = "Build a second brain with MCP"
date = 2025-11-27
image = "/images/agent-city-04.png"
draft = false
tags = ['mcp', 'tutorial', 'automation']
+++


I have notes everywhere. Markdown files, random text docs, bookmarks, highlights, ideas scattered across folders. Finding anything is a nightmare.

So I built a "second brain" — an AI that knows all my notes and can actually answer questions about them.

Not some cloud service. Everything stays local. Here's how.

## The idea

```
You → AI → MCP Server → Search your notes → Find connections → Answer
```

Instead of manually searching through folders, you just ask:

- "What did I write about pricing strategies?"
- "Find notes related to this project idea"
- "What books have I read about habits?"
- "Connect my notes on marketing and psychology"

## What you'll need

- [Gantz CLI](https://gantz.run)
- Your notes (markdown, txt, whatever)
- Python
- 30 minutes

## Step 1: Organize your notes

You don't need a perfect system. Just put your notes somewhere:

```
~/notes/
├── ideas/
├── projects/
├── books/
├── journal/
├── meetings/
├── learning/
└── random/
```

Works with any structure. The AI figures it out.

## Step 2: Build the tools

**search_notes.py:**

```python
#!/usr/bin/env python3
import os
import sys
from pathlib import Path
from datetime import datetime

NOTES_DIR = os.environ.get('NOTES_DIR', './notes')

def search(query, max_results=10):
    results = []
    query_lower = query.lower()
    query_words = query_lower.split()

    for path in Path(NOTES_DIR).rglob('*'):
        if not path.is_file():
            continue
        if path.suffix not in ['.md', '.txt', '.org']:
            continue

        try:
            content = path.read_text(encoding='utf-8')
            content_lower = content.lower()

            # Score based on word matches
            score = 0
            for word in query_words:
                score += content_lower.count(word)

            # Boost for title match
            if query_lower in path.stem.lower():
                score += 20

            # Boost for recent files
            mtime = path.stat().st_mtime
            days_old = (datetime.now().timestamp() - mtime) / 86400
            if days_old < 7:
                score += 5
            elif days_old < 30:
                score += 2

            if score > 0:
                # Extract relevant snippet
                lines = content.split('\n')
                snippet_lines = []
                for i, line in enumerate(lines):
                    if any(word in line.lower() for word in query_words):
                        start = max(0, i - 2)
                        end = min(len(lines), i + 3)
                        snippet_lines.extend(lines[start:end])
                        break

                snippet = '\n'.join(snippet_lines[:10]) if snippet_lines else lines[:5]

                results.append({
                    'path': str(path.relative_to(NOTES_DIR)),
                    'score': score,
                    'snippet': '\n'.join(snippet) if isinstance(snippet, list) else snippet,
                    'modified': datetime.fromtimestamp(mtime).strftime('%Y-%m-%d')
                })

        except:
            continue

    results.sort(key=lambda x: x['score'], reverse=True)
    return results[:max_results]

def main():
    if len(sys.argv) < 2:
        print("Usage: search_notes.py <query>")
        sys.exit(1)

    query = ' '.join(sys.argv[1:])
    results = search(query)

    if not results:
        print("No notes found.")
        return

    for r in results:
        print(f"## {r['path']}")
        print(f"Modified: {r['modified']} | Score: {r['score']}")
        print(f"\n{r['snippet']}\n")
        print("---\n")

if __name__ == '__main__':
    main()
```

**read_note.py:**

```python
#!/usr/bin/env python3
import os
import sys
from pathlib import Path

NOTES_DIR = os.environ.get('NOTES_DIR', './notes')

def main():
    if len(sys.argv) < 2:
        print("Usage: read_note.py <path>")
        sys.exit(1)

    note_path = sys.argv[1]
    full_path = Path(NOTES_DIR) / note_path

    if not full_path.exists():
        # Try fuzzy match
        for path in Path(NOTES_DIR).rglob('*'):
            if note_path.lower() in str(path).lower():
                full_path = path
                break

    if not full_path.exists():
        print(f"Note not found: {note_path}")
        sys.exit(1)

    content = full_path.read_text(encoding='utf-8')

    # Limit output
    lines = content.split('\n')
    if len(lines) > 200:
        print('\n'.join(lines[:200]))
        print(f"\n... truncated ({len(lines)} total lines)")
    else:
        print(content)

if __name__ == '__main__':
    main()
```

**list_notes.py:**

```python
#!/usr/bin/env python3
import os
from pathlib import Path
from datetime import datetime

NOTES_DIR = os.environ.get('NOTES_DIR', './notes')

def main():
    folder = sys.argv[1] if len(sys.argv) > 1 else None

    search_path = Path(NOTES_DIR) / folder if folder else Path(NOTES_DIR)

    notes = []
    for path in search_path.rglob('*'):
        if path.is_file() and path.suffix in ['.md', '.txt', '.org']:
            mtime = path.stat().st_mtime
            notes.append({
                'path': str(path.relative_to(NOTES_DIR)),
                'modified': datetime.fromtimestamp(mtime)
            })

    # Sort by modified date
    notes.sort(key=lambda x: x['modified'], reverse=True)

    print(f"## Notes in {folder or 'all folders'}\n")
    for n in notes[:50]:
        print(f"- {n['path']} ({n['modified'].strftime('%Y-%m-%d')})")

    print(f"\nTotal: {len(notes)} notes")

if __name__ == '__main__':
    import sys
    main()
```

**find_related.py:**

```python
#!/usr/bin/env python3
import os
import sys
from pathlib import Path
from collections import Counter

NOTES_DIR = os.environ.get('NOTES_DIR', './notes')

def get_keywords(text):
    """Extract simple keywords from text"""
    # Remove common words
    stopwords = {'the', 'a', 'an', 'is', 'are', 'was', 'were', 'be', 'been',
                 'being', 'have', 'has', 'had', 'do', 'does', 'did', 'will',
                 'would', 'could', 'should', 'may', 'might', 'must', 'shall',
                 'can', 'need', 'dare', 'ought', 'used', 'to', 'of', 'in',
                 'for', 'on', 'with', 'at', 'by', 'from', 'as', 'into', 'through',
                 'and', 'but', 'or', 'nor', 'so', 'yet', 'both', 'either',
                 'neither', 'not', 'only', 'own', 'same', 'than', 'too', 'very',
                 'just', 'that', 'this', 'these', 'those', 'i', 'you', 'he',
                 'she', 'it', 'we', 'they', 'what', 'which', 'who', 'whom'}

    words = text.lower().split()
    words = [w.strip('.,!?()[]{}":;') for w in words]
    words = [w for w in words if len(w) > 3 and w not in stopwords and w.isalpha()]
    return Counter(words)

def find_related(note_path, max_results=5):
    full_path = Path(NOTES_DIR) / note_path

    if not full_path.exists():
        return []

    source_content = full_path.read_text(encoding='utf-8')
    source_keywords = get_keywords(source_content)
    top_keywords = [w for w, c in source_keywords.most_common(20)]

    results = []
    for path in Path(NOTES_DIR).rglob('*'):
        if not path.is_file() or path == full_path:
            continue
        if path.suffix not in ['.md', '.txt', '.org']:
            continue

        try:
            content = path.read_text(encoding='utf-8')
            keywords = get_keywords(content)

            # Count shared keywords
            shared = sum(1 for k in top_keywords if k in keywords)

            if shared > 2:
                results.append({
                    'path': str(path.relative_to(NOTES_DIR)),
                    'shared': shared,
                    'common_words': [k for k in top_keywords if k in keywords][:5]
                })
        except:
            continue

    results.sort(key=lambda x: x['shared'], reverse=True)
    return results[:max_results]

def main():
    if len(sys.argv) < 2:
        print("Usage: find_related.py <note_path>")
        sys.exit(1)

    note_path = sys.argv[1]
    results = find_related(note_path)

    if not results:
        print("No related notes found.")
        return

    print(f"## Notes related to {note_path}\n")
    for r in results:
        print(f"- {r['path']}")
        print(f"  Common topics: {', '.join(r['common_words'])}")

if __name__ == '__main__':
    main()
```

**recent_notes.py:**

```python
#!/usr/bin/env python3
import os
from pathlib import Path
from datetime import datetime, timedelta

NOTES_DIR = os.environ.get('NOTES_DIR', './notes')

def main():
    days = int(sys.argv[1]) if len(sys.argv) > 1 else 7
    cutoff = datetime.now() - timedelta(days=days)

    notes = []
    for path in Path(NOTES_DIR).rglob('*'):
        if path.is_file() and path.suffix in ['.md', '.txt', '.org']:
            mtime = datetime.fromtimestamp(path.stat().st_mtime)
            if mtime > cutoff:
                notes.append({
                    'path': str(path.relative_to(NOTES_DIR)),
                    'modified': mtime
                })

    notes.sort(key=lambda x: x['modified'], reverse=True)

    print(f"## Notes from the last {days} days\n")
    for n in notes:
        print(f"- {n['path']} ({n['modified'].strftime('%Y-%m-%d %H:%M')})")

    print(f"\nTotal: {len(notes)} notes")

if __name__ == '__main__':
    import sys
    main()
```

## Step 3: MCP config

```yaml
name: second-brain
description: AI-powered second brain for your local notes

tools:
  - name: search_notes
    description: Search all notes for a topic or keyword
    parameters:
      - name: query
        type: string
        required: true
    script:
      command: python3
      args: ["./scripts/search_notes.py", "{{query}}"]
      working_dir: "${HOME}/brain"
    environment:
      NOTES_DIR: "${HOME}/notes"

  - name: read_note
    description: Read the full content of a specific note
    parameters:
      - name: path
        type: string
        required: true
        description: Path to the note file
    script:
      command: python3
      args: ["./scripts/read_note.py", "{{path}}"]
      working_dir: "${HOME}/brain"
    environment:
      NOTES_DIR: "${HOME}/notes"

  - name: list_notes
    description: List notes in a folder or all folders
    parameters:
      - name: folder
        type: string
        description: Folder to list (optional, lists all if empty)
    script:
      command: python3
      args: ["./scripts/list_notes.py", "{{folder}}"]
      working_dir: "${HOME}/brain"
    environment:
      NOTES_DIR: "${HOME}/notes"

  - name: find_related
    description: Find notes related to a specific note
    parameters:
      - name: note_path
        type: string
        required: true
    script:
      command: python3
      args: ["./scripts/find_related.py", "{{note_path}}"]
      working_dir: "${HOME}/brain"
    environment:
      NOTES_DIR: "${HOME}/notes"

  - name: recent_notes
    description: Show recently modified notes
    parameters:
      - name: days
        type: integer
        default: 7
    script:
      command: python3
      args: ["./scripts/recent_notes.py", "{{days}}"]
      working_dir: "${HOME}/brain"
    environment:
      NOTES_DIR: "${HOME}/notes"
```

## Step 4: Run it

```bash
gantz run --auth
```

## Step 5: Connect Claude

```python
import anthropic

client = anthropic.Anthropic(api_key="your-api-key")

response = client.beta.messages.create(
    model="claude-sonnet-4-5-20250929",
    max_tokens=2048,
    system="""You are a helpful assistant with access to my personal notes and knowledge base.
Help me find information, make connections between ideas, and recall things I've written.
When answering, cite which notes you found the information in.""",
    messages=[{"role": "user", "content": "What have I written about productivity systems?"}],
    mcp_servers=[{
        "type": "url",
        "url": "https://your-tunnel.gantz.run/sse",
        "name": "brain",
        "authorization_token": "your-token"
    }],
    tools=[{"type": "mcp_toolset", "mcp_server_name": "brain"}],
    betas=["mcp-client-2025-11-20"]
)

for block in response.content:
    if hasattr(block, "text"):
        print(block.text)
```

## What you can ask

**Recall:**
```
"What did I write about that startup idea?"
"Find my notes on habit formation"
"What books have I taken notes on?"
```

**Connect:**
```
"Find notes related to my marketing doc"
"What ideas connect to this project?"
"Show me everything about pricing"
```

**Summarize:**
```
"Summarize my notes on leadership"
"What are my main takeaways from the design sprint book?"
"Give me an overview of my project ideas"
```

**Discover:**
```
"What have I been working on this week?"
"Show me notes I haven't looked at in a while"
"What topics do I write about most?"
```

## The magic

The real power is connections. You might ask:

"I'm working on a SaaS pricing page. What have I written that might help?"

And AI finds:
- Your notes on pricing psychology (from a book)
- A competitor analysis you did
- Ideas from a podcast about value-based pricing
- A journal entry about your own purchasing decisions

Stuff you forgot you even wrote.

## Extend it

- **Add tags** — Extract #tags and search by them
- **Daily notes** — Auto-create today's note
- **Backlinks** — Find notes that link to each other
- **Capture** — Quick tool to add a new note
- **Templates** — Generate meeting notes, book reviews, etc.

## Why local?

Your notes are personal. Mine have journal entries, business ideas, random thoughts. I don't want them on someone's server.

With this setup:
- Notes stay on your machine
- AI accesses them through MCP
- No syncing to cloud services
- Full privacy

---

*What would you put in your second brain? I'm thinking of adding my browser bookmarks next.*
