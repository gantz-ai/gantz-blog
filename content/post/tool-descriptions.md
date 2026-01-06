+++
title = "The Art of Tool Descriptions"
date = 2025-11-21
description = "Write tool descriptions that AI agents understand. Best practices for clear, actionable descriptions that improve tool selection accuracy."
image = "images/robot-billboard-09.webp"
draft = false
tags = ['tool-use', 'prompting', 'best-practices']
voice = false
+++


Your tool descriptions are prompts. Bad descriptions = bad tool use.

Most people get this wrong.

## Why descriptions matter

AI decides which tool to use based on descriptions. Not the tool name. Not the code. The description.

```yaml
# Bad
- name: process_data
  description: Processes data

# What the AI thinks:
# "Process... what data? How? When should I use this?"
```

```yaml
# Good
- name: process_data
  description: Clean and normalize CSV data. Removes duplicates, fixes date formats, trims whitespace. Use when user has messy CSV files.

# What the AI thinks:
# "Ah, this cleans CSVs. I'll use this when the user mentions messy data or CSV cleanup."
```

Same tool. Different descriptions. Completely different AI behavior.

## The anatomy of a good description

A good tool description has four parts:

```
┌─────────────────────────────────────────────────────┐
│                 TOOL DESCRIPTION                     │
├─────────────────────────────────────────────────────┤
│  1. WHAT it does        (core function)             │
│  2. HOW it works        (mechanism/method)          │
│  3. WHEN to use it      (trigger conditions)        │
│  4. WHAT it returns     (output format)             │
└─────────────────────────────────────────────────────┘
```

### 1. WHAT it does

Start with the core function. One sentence. Active voice.

```yaml
# Bad
description: This tool is used for searching

# Good
description: Search files by content using regex patterns
```

### 2. HOW it works

Brief explanation of the mechanism. Helps AI understand limitations.

```yaml
# Bad
description: Searches files

# Good
description: Searches files using ripgrep. Supports regex, glob patterns, and file type filters.
```

### 3. WHEN to use it

Explicit trigger conditions. When should AI reach for this tool?

```yaml
# Bad
description: Database query tool

# Good
description: Query the PostgreSQL database. Use when user asks about customers, orders, or sales data. Only for read operations.
```

### 4. WHAT it returns

Output format and structure. Helps AI parse and present results.

```yaml
# Bad
description: Gets user info

# Good
description: Gets user info. Returns JSON with fields: id, name, email, created_at. Returns null if user not found.
```

## Full examples

### Example 1: File search

```yaml
# Bad
- name: search
  description: Searches for things

# Good
- name: search_files
  description: |
    Search for files by name pattern.
    Uses glob matching (e.g., "*.js", "src/**/*.ts").
    Returns list of matching file paths, sorted by modification time.
    Use when user wants to find files but doesn't know exact location.
```

### Example 2: API call

```yaml
# Bad
- name: api
  description: Makes API calls

# Good
- name: call_api
  description: |
    Make HTTP requests to external APIs.
    Supports GET, POST, PUT, DELETE methods.
    Handles JSON request/response automatically.
    Returns: {status: number, body: object, headers: object}
    Use for fetching external data or integrating with third-party services.
    Rate limited to 10 requests/minute.
```

### Example 3: Database

```yaml
# Bad
- name: db
  description: Database operations

# Good
- name: query_database
  description: |
    Execute read-only SQL queries against the application database.
    Tables available: users, orders, products, inventory.
    Returns results as JSON array. Max 1000 rows.
    Use when user asks questions about business data.
    Cannot modify data - use update_database for writes.
```

### Example 4: File operations

```yaml
# Bad
- name: write
  description: Writes files

# Good
- name: write_file
  description: |
    Write content to a file. Creates file if it doesn't exist, overwrites if it does.
    Parameters: path (string), content (string)
    Returns: {success: boolean, bytes_written: number}
    Use when user wants to save, create, or update files.
    Warning: Overwrites existing files without confirmation.
```

## Common mistakes

### Mistake 1: Too vague

```yaml
# Bad - AI has no idea when to use this
- name: helper
  description: A helpful utility function
```

Vague descriptions make AI guess. Guessing leads to wrong tool choices.

### Mistake 2: Too technical

```yaml
# Bad - AI doesn't need implementation details
- name: search
  description: Implements Boyer-Moore string matching algorithm with O(n/m) average case complexity using bad character and good suffix heuristics
```

AI needs to know what it does, not how it's implemented internally.

### Mistake 3: Missing constraints

```yaml
# Bad - AI doesn't know the limits
- name: send_email
  description: Sends an email
```

```yaml
# Good - AI knows the boundaries
- name: send_email
  description: |
    Send an email via SMTP.
    Max 10 recipients. Max 5MB attachments.
    Returns confirmation with message ID.
    Requires user confirmation before sending.
```

### Mistake 4: No trigger hints

```yaml
# Bad - When should AI use this vs other tools?
- name: fetch_data
  description: Fetches data from the system
```

```yaml
# Good - Clear trigger conditions
- name: fetch_user_data
  description: |
    Fetch current user's profile and preferences.
    Use when user asks about their account, settings, or profile info.
    For other users' data, use lookup_user instead.
```

### Mistake 5: Ambiguous overlap

```yaml
# Bad - Which one should AI pick?
- name: search_docs
  description: Searches documentation

- name: find_docs
  description: Finds documentation
```

```yaml
# Good - Clear differentiation
- name: search_docs
  description: |
    Full-text search across all documentation.
    Use for keyword queries like "how to configure X".

- name: find_docs
  description: |
    Find documentation by exact path or ID.
    Use when you know the specific doc you need.
```

## Description templates

### For read operations

```yaml
description: |
  [What it retrieves] from [source].
  Returns [format/structure].
  Use when user asks about [trigger topics].
  [Any limitations or constraints].
```

### For write operations

```yaml
description: |
  [What it creates/modifies] in [destination].
  Parameters: [key params explained].
  Returns [confirmation format].
  Use when user wants to [action verbs].
  Warning: [any destructive behaviors].
```

### For search operations

```yaml
description: |
  Search [what] by [criteria].
  Supports [search features: regex, fuzzy, etc].
  Returns [result format], max [limit] results.
  Use when user is looking for [use cases].
```

### For external integrations

```yaml
description: |
  [Action] via [service/API].
  Requires [authentication/setup].
  Rate limited to [limit].
  Returns [response format].
  Use for [integration scenarios].
```

## Parameter descriptions matter too

Don't just describe the tool. Describe the parameters.

```yaml
# Bad
parameters:
  - name: query
    type: string

# Good
parameters:
  - name: query
    type: string
    description: |
      Search query. Supports:
      - Simple text: "hello world"
      - Regex: "/hello.*world/i"
      - Glob: "*.js"
      Default: matches all files.
```

## Context-aware descriptions

Tailor descriptions to your use case.

### For a coding assistant

```yaml
- name: run_tests
  description: |
    Run the test suite for the current project.
    Use after making code changes to verify nothing broke.
    Returns test results with pass/fail counts and error details.
```

### For a customer support agent

```yaml
- name: lookup_order
  description: |
    Look up customer order by order ID or email.
    Use when customer asks about their order status, shipping, or returns.
    Returns order details including items, status, and tracking info.
```

### For a data analyst

```yaml
- name: run_query
  description: |
    Execute SQL query against the analytics database.
    Use for answering questions about metrics, trends, or business performance.
    Returns results as JSON. Include LIMIT clause for large result sets.
```

## Testing your descriptions

### Test 1: The "which tool" test

Give AI a task and see if it picks the right tool.

```
Task: "Find all JavaScript files in the src folder"

If AI picks wrong tool → Description needs work
If AI picks right tool → Description is clear
```

### Test 2: The "parameter" test

Does AI provide correct parameters?

```
Task: "Search for files containing 'TODO'"

Good: AI uses search_files with query="TODO"
Bad: AI uses search_files with query="files with TODO"
```

### Test 3: The "boundary" test

Does AI know when NOT to use the tool?

```
Task: "Delete all log files"

If tool is read-only and AI still tries to use it →
Description doesn't communicate constraints
```

## Tool description checklist

Before shipping a tool, check:

- [ ] **Clear verb**: Does it start with an action word?
- [ ] **Scope defined**: Is it clear what this tool can/can't do?
- [ ] **Triggers stated**: When should AI use this?
- [ ] **Output described**: What format does it return?
- [ ] **Constraints listed**: What are the limits?
- [ ] **Differentiated**: How is it different from similar tools?
- [ ] **Parameters explained**: Are param purposes clear?

## Try it yourself

Define your tools with good descriptions using [Gantz](https://gantz.run):

```yaml
# gantz.yaml
tools:
  - name: search_codebase
    description: |
      Search code files by content pattern.
      Uses ripgrep for fast regex matching.
      Returns matching lines with file paths and line numbers.
      Use when user wants to find code, functions, or patterns.
    parameters:
      - name: pattern
        type: string
        description: Regex pattern to search for
        required: true
    script:
      shell: rg --json "{{pattern}}" .
```

Run `gantz` and watch AI pick the right tools.

## Summary

Tool descriptions are prompts. Treat them like prompts.

**Good descriptions include:**
- What the tool does
- How it works (briefly)
- When to use it
- What it returns
- Constraints and limits

**Avoid:**
- Vague descriptions
- Implementation details
- Missing constraints
- Ambiguous overlap with other tools

Write descriptions for AI, not for documentation. AI needs to decide in milliseconds whether to use your tool.

Make that decision easy.

## Related reading

- [Why Your 50-Tool Agent is Worse Than a 5-Tool One](/post/50-tools/) - When to consolidate tools
- [Atomic vs Compound Tools](/post/atomic-compound-tools/) - Tool design patterns
- [The Meta-Prompting Pattern](/post/meta-prompting/) - Let AI write descriptions

---

*What's the worst tool description you've seen? The best?*
