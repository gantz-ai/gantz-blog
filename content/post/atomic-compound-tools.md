+++
title = "Atomic vs Compound Tools: Design Trade-offs"
date = 2025-12-31
image = "images/logo-metal-armor.png"
draft = false
tags = ['tool-use', 'architecture', 'patterns']
+++


Should your tool do one thing or many things?

This is the most important design decision when building AI agent tools.

## The spectrum

```
Atomic                                              Compound
  │                                                      │
  ▼                                                      ▼
read_file              ─────────────────────>      manage_project
write_file                                         (reads, writes, runs,
list_files                                          builds, deploys)
delete_file
```

**Atomic**: One tool, one action
**Compound**: One tool, many actions

Most tools fall somewhere in between.

## Atomic tools

### What they look like

```yaml
tools:
  - name: read_file
    description: Read contents of a file
    parameters:
      - name: path
        type: string
        required: true

  - name: write_file
    description: Write content to a file
    parameters:
      - name: path
        type: string
        required: true
      - name: content
        type: string
        required: true

  - name: delete_file
    description: Delete a file
    parameters:
      - name: path
        type: string
        required: true

  - name: list_files
    description: List files in a directory
    parameters:
      - name: path
        type: string
        required: true
```

Four tools. Four actions. Crystal clear.

### Advantages

**1. Clear responsibility**

AI knows exactly what each tool does. No ambiguity.

```
User: "Read the config file"
AI: Uses read_file ← obvious choice
```

**2. Easy to debug**

When something fails, you know exactly what failed.

```
Error in: delete_file
Action: delete
Path: /important/file.txt
← Easy to trace
```

**3. Composable**

Combine atomic tools for complex workflows.

```
read_file → transform → write_file → validate → deploy
```

**4. Testable**

Each tool has one behavior to test.

```python
def test_read_file():
    result = read_file("/test.txt")
    assert result.content == "expected"
    # One test, one behavior
```

**5. Principle of least privilege**

Grant minimal permissions per tool.

```yaml
- name: read_file    # read-only permission
- name: write_file   # write permission
- name: delete_file  # delete permission (dangerous!)
```

### Disadvantages

**1. More tool calls**

Simple tasks require multiple calls.

```
Task: "Copy file A to B"

Atomic approach:
1. read_file(A)
2. write_file(B, content)
← Two tool calls

Compound approach:
1. copy_file(A, B)
← One tool call
```

**2. More tokens**

Each tool call costs tokens.

```
Atomic: 4 tool calls × 100 tokens = 400 tokens
Compound: 1 tool call × 150 tokens = 150 tokens
```

**3. AI coordination overhead**

AI must orchestrate multiple tools correctly.

```
AI needs to:
1. Read first
2. Remember content
3. Write to new location
4. Verify it worked

More steps = more chances for mistakes
```

**4. Tool sprawl**

Too many atomic tools overwhelm the AI.

```yaml
tools:
  - read_file
  - write_file
  - append_file
  - prepend_file
  - delete_file
  - move_file
  - copy_file
  - rename_file
  - create_directory
  - delete_directory
  - list_directory
  - get_file_info
  - set_permissions
  - ...
  # AI: "Which one do I use again?"
```

## Compound tools

### What they look like

```yaml
tools:
  - name: file_manager
    description: Manage files and directories
    parameters:
      - name: action
        type: string
        enum: [read, write, delete, copy, move, list]
        required: true
      - name: path
        type: string
        required: true
      - name: content
        type: string
      - name: destination
        type: string
```

One tool. Multiple actions.

### Advantages

**1. Fewer tool calls**

Complex operations in single call.

```
Task: "Copy file A to B"

Compound:
file_manager(action="copy", path="A", destination="B")
← One call
```

**2. Lower token cost**

Less overhead per operation.

**3. Simpler tool list**

AI has fewer tools to choose from.

```yaml
tools:
  - file_manager     # All file ops
  - database        # All DB ops
  - http_client     # All HTTP ops
  # Clean, organized
```

**4. Bundled operations**

Related actions stay together.

```yaml
- name: git
  parameters:
    - name: command
      enum: [status, add, commit, push, pull, branch, checkout]
```

### Disadvantages

**1. Ambiguous selection**

AI might not know which action to pick.

```
User: "Save this to a file"
AI: file_manager(action=???)  # write? create? append?
```

**2. Complex parameters**

Different actions need different parameters.

```yaml
- name: file_manager
  parameters:
    - name: action
      type: string
    - name: path          # Required for all
    - name: content       # Only for write
    - name: destination   # Only for copy/move
    - name: recursive     # Only for delete/list
    - name: filter        # Only for list
    # Confusing: which params for which action?
```

**3. Harder to debug**

Failures are less specific.

```
Error in: file_manager
Action: ??? (need to check params)
```

**4. All-or-nothing permissions**

Can't grant read without granting write.

```yaml
- name: file_manager  # Grants ALL file operations
  # Can't restrict to read-only
```

**5. Harder to test**

Multiple behaviors per tool.

```python
def test_file_manager():
    # Test read
    # Test write
    # Test delete
    # Test copy
    # Test move
    # Test list
    # One tool, many tests
```

## The trade-off matrix

| Factor | Atomic | Compound |
|--------|--------|----------|
| Clarity | ✓ Better | Worse |
| Token cost | Higher | ✓ Lower |
| Tool calls | More | ✓ Fewer |
| Debugging | ✓ Easier | Harder |
| Testing | ✓ Easier | Harder |
| Permissions | ✓ Granular | Coarse |
| AI cognitive load | More | ✓ Less |
| Flexibility | ✓ More | Less |

## When to use each

### Use atomic tools when:

- **Actions have different risk levels**

```yaml
# Keep dangerous operations separate
- name: read_database    # Safe
- name: write_database   # Dangerous
- name: drop_table       # Very dangerous
```

- **Actions need different permissions**

```yaml
# Separate permission boundaries
- name: view_user    # Public
- name: edit_user    # Admin only
- name: delete_user  # Superadmin only
```

- **Actions are truly independent**

```yaml
# Unrelated actions = separate tools
- name: send_email
- name: query_database
- name: generate_report
```

- **Debugging matters**

```yaml
# Production system: atomic for observability
- name: create_order
- name: process_payment
- name: send_confirmation
```

### Use compound tools when:

- **Actions are conceptually related**

```yaml
# Git is one concept with many actions
- name: git
  parameters:
    - name: command
      enum: [status, add, commit, push, pull]
```

- **Reducing tool calls matters**

```yaml
# High-latency environment
- name: crud
  parameters:
    - name: action
      enum: [create, read, update, delete]
```

- **AI is overwhelmed by tool count**

```yaml
# Consolidate to reduce cognitive load
- name: project_manager  # vs 20 separate tools
```

- **Operations are frequently chained**

```yaml
# Always read-modify-write together
- name: transform_file
  parameters:
    - name: path
    - name: transformation
```

## Hybrid approach

The best designs often mix both.

### Strategy 1: Group by domain

```yaml
# Atomic within domain, compound across domains
tools:
  - name: files
    description: File operations (read, write, list, delete)
    parameters:
      - name: action
        enum: [read, write, list, delete]

  - name: database
    description: Database operations (query, insert, update)
    parameters:
      - name: action
        enum: [query, insert, update]
```

### Strategy 2: Separate by risk

```yaml
# Compound for safe, atomic for dangerous
tools:
  - name: read_files
    description: Read any file or list directory
    parameters:
      - name: action
        enum: [read, list, search]

  - name: write_file     # Separate: risky
  - name: delete_file    # Separate: very risky
```

### Strategy 3: Convenience wrappers

```yaml
# Atomic base + compound convenience
tools:
  # Atomic (low-level)
  - name: read_file
  - name: write_file
  - name: run_command

  # Compound (high-level convenience)
  - name: deploy
    description: Build, test, and deploy (runs read, write, command internally)
```

## Real-world examples

### Example 1: File system (Hybrid)

```yaml
tools:
  # Compound for reading (safe)
  - name: explore_files
    description: Read, list, and search files
    parameters:
      - name: action
        enum: [read, list, search, info]
      - name: path
        type: string

  # Atomic for writing (risky)
  - name: write_file
    description: Write content to file
    parameters:
      - name: path
      - name: content

  # Atomic for deleting (very risky)
  - name: delete_file
    description: Delete a file (irreversible)
    parameters:
      - name: path
```

### Example 2: HTTP client (Compound)

```yaml
tools:
  - name: http
    description: Make HTTP requests
    parameters:
      - name: method
        enum: [GET, POST, PUT, DELETE]
      - name: url
        type: string
      - name: headers
        type: object
      - name: body
        type: string
```

All HTTP methods are similar risk level. Compound makes sense.

### Example 3: Database (Hybrid)

```yaml
tools:
  # Compound for reading
  - name: query
    description: Read data from database
    parameters:
      - name: sql
        type: string
      - name: limit
        type: number
        default: 100

  # Atomic for modifications
  - name: insert
  - name: update
  - name: delete
```

## Decision flowchart

```
                    Start
                      │
                      ▼
        ┌─────────────────────────┐
        │ Are actions same risk?   │
        └────────────┬────────────┘
                     │
           ┌─────────┴─────────┐
           ▼                   ▼
          Yes                  No
           │                   │
           ▼                   ▼
    ┌──────────────┐    Use atomic tools
    │ Conceptually │    (separate by risk)
    │   related?   │
    └──────┬───────┘
           │
     ┌─────┴─────┐
     ▼           ▼
    Yes          No
     │           │
     ▼           ▼
  Compound    Atomic
```

## Building with Gantz

Define your tools with [Gantz](https://gantz.run):

```yaml
# gantz.yaml - Hybrid approach
tools:
  # Compound: safe read operations
  - name: explore
    description: Explore files and directories (read-only)
    parameters:
      - name: action
        type: string
        enum: [read, list, search, tree]
      - name: path
        type: string
        required: true
      - name: pattern
        type: string
    script:
      shell: |
        case "{{action}}" in
          read)   cat "{{path}}" ;;
          list)   ls -la "{{path}}" ;;
          search) grep -r "{{pattern}}" "{{path}}" ;;
          tree)   find "{{path}}" -type f ;;
        esac

  # Atomic: risky write operation
  - name: write_file
    description: Write content to file (creates or overwrites)
    parameters:
      - name: path
        type: string
        required: true
      - name: content
        type: string
        required: true
    script:
      shell: echo "{{content}}" > "{{path}}"

  # Atomic: dangerous delete operation
  - name: delete_file
    description: Permanently delete a file
    parameters:
      - name: path
        type: string
        required: true
    script:
      shell: rm "{{path}}"
```

## Summary

**Atomic tools:**
- One action per tool
- Clear, testable, debuggable
- More tool calls, higher token cost
- Best for: risky operations, different permission levels

**Compound tools:**
- Multiple actions per tool
- Fewer calls, lower tokens
- Harder to debug and test
- Best for: related operations, same risk level

**Hybrid approach:**
- Compound for safe reads
- Atomic for risky writes
- Best of both worlds

Design your tools around risk, not convenience.

---

*How do you design your tools? Atomic, compound, or hybrid?*
