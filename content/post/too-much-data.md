+++
title = "How to Handle Tools That Return Too Much Data"
date = 2025-11-22
description = "Manage AI agent tools that return massive outputs. Strategies for truncation, pagination, summarization, and streaming large tool results."
summary = "Your agent calls a tool and gets 50,000 lines back - now what? That won't fit in context. Learn strategies for handling massive tool outputs: smart truncation that keeps relevant parts, pagination for iterative exploration, summarization for high-level views, and streaming for progressive processing. Keep agents responsive regardless of data size."
image = "images/warrior-rain-city-08.webp"
draft = false
tags = ['tool-use', 'patterns', 'best-practices']
voice = false
+++


Your agent calls a tool. The tool returns 50,000 lines.

Now what?

## The problem

```python
# Agent calls search tool
result = tools.search("error")

# Tool returns... everything
len(result)  # 847,293 characters

# Agent tries to process it
llm.create(messages=[
    {"role": "user", "content": "Find the error"},
    {"role": "assistant", "content": None, "tool_calls": [...]},
    {"role": "tool", "content": result}  # 💥 Context overflow
])
```

The context window explodes. Or the model gets confused. Or you burn through tokens.

## Why this happens

### 1. Unbounded queries

```python
# "Get all users"
SELECT * FROM users;  # Returns 100,000 rows

# "Search logs"
grep "error" /var/log/*.log  # Returns 50MB of logs

# "List files"
find . -type f  # Returns 200,000 files
```

### 2. Verbose output formats

```python
# Tool returns full objects
{
    "users": [
        {"id": 1, "name": "...", "email": "...", "created_at": "...",
         "updated_at": "...", "last_login": "...", "preferences": {...},
         "metadata": {...}, "permissions": [...], ...},
        # × 1000 users
    ]
}
```

### 3. Unexpected data growth

```python
# Worked fine with 100 records
# Production has 100,000 records
```

## Strategy 1: Limit at the source

Don't let tools return unlimited data.

### Hard limits

```yaml
# gantz.yaml
tools:
  - name: query_database
    description: Query database. Returns max 100 rows.
    parameters:
      - name: sql
        type: string
        required: true
    script:
      shell: |
        # Force LIMIT if not present
        query="{{sql}}"
        if ! echo "$query" | grep -qi "LIMIT"; then
          query="$query LIMIT 100"
        fi
        sqlite3 -json db.sqlite "$query"
```

### Pagination built-in

```yaml
  - name: search_files
    description: Search files. Returns max 50 matches per page.
    parameters:
      - name: query
        type: string
        required: true
      - name: page
        type: number
        default: 1
    script:
      shell: |
        rg --json "{{query}}" . | head -n $(({{page}} * 50)) | tail -n 50
```

### Count first

```yaml
  - name: list_items
    description: List items. If more than 100, returns count only. Use filters to narrow.
    parameters:
      - name: filter
        type: string
    script:
      shell: |
        count=$(find . -name "{{filter}}" | wc -l)
        if [ $count -gt 100 ]; then
          echo "{\"count\": $count, \"message\": \"Too many results. Add more specific filters.\"}"
        else
          find . -name "{{filter}}" -print
        fi
```

## Strategy 2: Truncate intelligently

When you can't limit at source, truncate the response.

### Simple truncation

```python
def truncate_result(result, max_chars=10000):
    if len(result) <= max_chars:
        return result

    return result[:max_chars] + f"\n\n... [Truncated. Total: {len(result)} chars]"
```

### Head + tail

Show beginning and end:

```python
def head_tail(result, head=3000, tail=1000):
    if len(result) <= head + tail:
        return result

    return (
        result[:head] +
        f"\n\n... [{len(result) - head - tail} chars omitted] ...\n\n" +
        result[-tail:]
    )
```

### Smart truncation (keep structure)

```python
def truncate_json(data, max_items=50):
    if isinstance(data, list):
        if len(data) > max_items:
            return {
                "items": data[:max_items],
                "truncated": True,
                "total_count": len(data),
                "showing": max_items
            }
        return data

    if isinstance(data, dict):
        return {k: truncate_json(v, max_items) for k, v in data.items()}

    return data
```

### Line-based truncation

```python
def truncate_lines(result, max_lines=100):
    lines = result.split('\n')
    if len(lines) <= max_lines:
        return result

    return '\n'.join(lines[:max_lines]) + f"\n\n... [{len(lines) - max_lines} more lines]"
```

## Strategy 3: Summarize

Let AI summarize large results.

### Summarize before returning

```python
def summarize_if_large(result, max_chars=5000):
    if len(result) <= max_chars:
        return result

    # Use a fast/cheap model to summarize
    summary = fast_llm.create(
        messages=[{
            "role": "user",
            "content": f"Summarize this data concisely:\n\n{result[:20000]}"
        }]
    ).content

    return {
        "summary": summary,
        "full_size": len(result),
        "note": "Result was summarized due to size"
    }
```

### Extract relevant parts

```python
def extract_relevant(result, query, max_chars=5000):
    if len(result) <= max_chars:
        return result

    # Use LLM to find relevant portions
    extraction = llm.create(
        messages=[{
            "role": "user",
            "content": f"""Given this query: "{query}"

Extract only the relevant parts from this data:

{result[:30000]}

Return only what's needed to answer the query."""
        }]
    ).content

    return {
        "relevant_extract": extraction,
        "full_size": len(result),
        "note": "Extracted relevant portions only"
    }
```

## Strategy 4: Stream and filter

Process large results without loading everything.

### Streaming tools

```yaml
# gantz.yaml
tools:
  - name: search_large_file
    description: Search large file, streams results
    parameters:
      - name: file
        type: string
      - name: pattern
        type: string
      - name: max_matches
        type: number
        default: 20
    script:
      shell: |
        grep -n "{{pattern}}" "{{file}}" | head -{{max_matches}}
```

### Progressive loading

```python
def search_with_progressive_load(query, max_results=20):
    results = []

    for match in stream_search(query):  # Generator
        results.append(match)

        if len(results) >= max_results:
            return {
                "results": results,
                "has_more": True,
                "message": f"Showing first {max_results}. Refine search for more specific results."
            }

    return {"results": results, "has_more": False}
```

## Strategy 5: Return references, not content

Don't return data. Return pointers to data.

### File references

```python
# Bad: Return file contents
def read_logs():
    return open("/var/log/app.log").read()  # 50MB

# Good: Return file info + snippet
def read_logs():
    path = "/var/log/app.log"
    size = os.path.getsize(path)

    # Read just the tail
    with open(path) as f:
        f.seek(max(0, size - 5000))
        tail = f.read()

    return {
        "path": path,
        "size_bytes": size,
        "size_human": f"{size / 1024 / 1024:.1f}MB",
        "last_lines": tail,
        "note": "Use read_file_range to read specific sections"
    }
```

### Database references

```python
# Bad: Return all matching records
def search_users(query):
    return db.query(f"SELECT * FROM users WHERE name LIKE '%{query}%'")  # 10,000 records

# Good: Return IDs and count
def search_users(query):
    results = db.query(f"SELECT id, name FROM users WHERE name LIKE '%{query}%' LIMIT 100")
    total = db.query(f"SELECT COUNT(*) FROM users WHERE name LIKE '%{query}%'")[0][0]

    return {
        "matches": results,  # Just id and name
        "showing": len(results),
        "total": total,
        "note": "Use get_user(id) for full details"
    }
```

## Strategy 6: Give agent tools to navigate

Let the agent request more data as needed.

### Pagination tools

```yaml
tools:
  - name: search
    description: Search. Returns first 20 results. Use get_page for more.
    parameters:
      - name: query
        type: string

  - name: get_page
    description: Get specific page of previous search results
    parameters:
      - name: page
        type: number

  - name: get_item
    description: Get full details of one item by ID
    parameters:
      - name: id
        type: string
```

### Drill-down tools

```yaml
tools:
  - name: list_directories
    description: List top-level directories with item counts

  - name: list_directory
    description: List contents of specific directory
    parameters:
      - name: path
        type: string

  - name: read_file
    description: Read specific file
    parameters:
      - name: path
        type: string
```

### Range tools

```yaml
tools:
  - name: read_file_range
    description: Read lines from file
    parameters:
      - name: path
        type: string
      - name: start_line
        type: number
      - name: num_lines
        type: number
        default: 50
```

## Strategy 7: Format for efficiency

Same data, fewer tokens.

### Compact JSON

```python
# Verbose (wasteful)
{
    "user_id": 1,
    "user_name": "Alice",
    "user_email": "alice@example.com"
}

# Compact
{"id":1,"name":"Alice","email":"alice@example.com"}
```

### Tables instead of objects

```python
# Objects (verbose)
[
    {"id": 1, "name": "Alice", "age": 30},
    {"id": 2, "name": "Bob", "age": 25},
    {"id": 3, "name": "Carol", "age": 35}
]

# Table (compact)
"""
id | name  | age
1  | Alice | 30
2  | Bob   | 25
3  | Carol | 35
"""
```

### Just the essentials

```python
def slim_user(user):
    # Full object: 20 fields
    # Return only what's usually needed
    return {
        "id": user["id"],
        "name": user["name"],
        "email": user["email"]
    }
```

## MCP implementation with Gantz

Build data-safe tools with [Gantz](https://gantz.run):

```yaml
# gantz.yaml
tools:
  - name: query
    description: |
      Query database. Max 100 rows returned.
      For large results, add filters or use query_count first.
    parameters:
      - name: sql
        type: string
        required: true
    script:
      shell: |
        # Inject limit
        query=$(echo "{{sql}}" | sed 's/;$//')
        if ! echo "$query" | grep -qi "LIMIT"; then
          query="$query LIMIT 100"
        fi

        result=$(sqlite3 -json db.sqlite "$query")
        count=$(echo "$result" | jq length)

        if [ "$count" -eq 100 ]; then
          echo "{\"rows\": $result, \"warning\": \"Returned max 100 rows. Results may be truncated. Add filters or LIMIT.\"}"
        else
          echo "$result"
        fi

  - name: query_count
    description: Count rows matching a query. Use before large queries.
    parameters:
      - name: table
        type: string
      - name: where
        type: string
    script:
      shell: |
        sqlite3 db.sqlite "SELECT COUNT(*) FROM {{table}} WHERE {{where}}"

  - name: search_logs
    description: Search logs. Returns max 50 matches with context.
    parameters:
      - name: pattern
        type: string
        required: true
      - name: file
        type: string
        default: "/var/log/app.log"
    script:
      shell: |
        matches=$(grep -c "{{pattern}}" "{{file}}" 2>/dev/null || echo 0)
        if [ "$matches" -gt 50 ]; then
          echo "{\"total_matches\": $matches, \"showing\": 50, \"note\": \"Refine pattern for fewer results\"}"
          grep -n "{{pattern}}" "{{file}}" | head -50
        else
          grep -n "{{pattern}}" "{{file}}"
        fi
```

## The decision tree

```text
Tool returns data
        │
        ▼
Is it < 5KB?  ──Yes──→  Return as-is
        │
        No
        │
        ▼
Can you limit at source?  ──Yes──→  Add LIMIT/pagination
        │
        No
        │
        ▼
Is structure important?  ──Yes──→  Truncate smartly (keep structure)
        │
        No
        │
        ▼
Is it searchable?  ──Yes──→  Return count + let agent drill down
        │
        No
        │
        ▼
Summarize or extract relevant parts
```

## Summary

When tools return too much data:

1. **Limit at source**: LIMIT clauses, pagination, max results
2. **Truncate smartly**: Head/tail, preserve structure
3. **Summarize**: Use fast LLM to compress
4. **Return references**: Pointers, not content
5. **Give navigation tools**: Pagination, drill-down, ranges
6. **Format efficiently**: Compact JSON, tables

Don't let a single tool call blow up your context window.

## Related reading

- [Context Window Budgeting](/post/context-budgeting/) - Managing token limits
- [Sliding Window vs Summarization](/post/sliding-vs-summarization/) - Context management strategies
- [The 80/20 Rule for AI Agents](/post/80-20-rule/) - Focus on what matters

---

*What's the largest tool result you've had to handle?*
