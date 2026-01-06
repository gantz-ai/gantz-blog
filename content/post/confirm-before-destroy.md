+++
title = "The Confirm-Before-Destroy Pattern"
date = 2025-12-27
description = "Prevent AI agents from destructive actions with confirmation patterns. Implement safety checks for delete, drop, and irreversible operations."
image = "images/soldier-battlefield-fire.webp"
draft = false
tags = ['patterns', 'security', 'best-practices']
+++


My agent deleted 47 files.

I asked it to "clean up the test artifacts."

It cleaned up the tests too.

Now I add confirmation for anything destructive. Here's the pattern.

## The problem

Agents do what you ask. Sometimes too well.

```
User: "Remove the old API"

Agent: 🔧 run_command({"command": "rm -rf src/api/"})

"Done! I've removed the old API directory."

User: "...that was the only API"
```

The agent wasn't wrong. The request was ambiguous. But the damage is done.

## The pattern

Before destructive operations, show what will happen. Wait for confirmation.

```
User: "Remove the old API"

Agent: "I'll delete these files:
  - src/api/v1/users.py
  - src/api/v1/auth.py
  - src/api/v1/routes.py
  - src/api/v1/__init__.py

  4 files, 847 lines of code.

  Type 'yes' to confirm, or tell me to adjust."

User: "wait, keep auth.py"

Agent: "Got it. I'll delete:
  - src/api/v1/users.py
  - src/api/v1/routes.py
  - src/api/v1/__init__.py

  3 files, 612 lines of code.

  Type 'yes' to confirm."

User: "yes"

Agent: 🔧 rm src/api/v1/users.py
       🔧 rm src/api/v1/routes.py
       🔧 rm src/api/v1/__init__.py

"Done. Deleted 3 files. auth.py is preserved."
```

User stays in control. Mistakes get caught.

## What counts as destructive?

### Always confirm

```python
DESTRUCTIVE_OPERATIONS = [
    # File operations
    "delete", "remove", "rm",
    "overwrite",  # when replacing significant content
    "truncate",

    # Database
    "DROP", "DELETE", "TRUNCATE",
    "UPDATE...WHERE" # without specific ID

    # Git
    "push --force",
    "reset --hard",
    "branch -D",

    # System
    "kill", "pkill",
    "chmod", "chown",  # permission changes

    # Cloud/Infra
    "terraform destroy",
    "kubectl delete",
    "aws ... delete",
]
```

### Usually safe (no confirmation needed)

```python
SAFE_OPERATIONS = [
    # File operations
    "read", "cat", "head", "tail",
    "search", "grep", "find",
    "write",  # new files
    "edit",   # small changes to existing

    # Database
    "SELECT",
    "INSERT",  # usually reversible

    # Git
    "status", "diff", "log",
    "add", "commit",
    "push",  # normal push
    "checkout", "branch",

    # System
    "ls", "pwd", "echo",
    "npm install", "pip install",
]
```

### Context-dependent

```python
# These depend on what's being affected
CONTEXT_DEPENDENT = [
    "write_file",   # Overwriting important config? Confirm.
                    # Creating new file? Don't confirm.

    "run_command",  # rm -rf? Confirm.
                    # ls? Don't confirm.

    "git push",     # To main? Maybe confirm.
                    # To feature branch? Don't confirm.
]
```

## Implementation

### Option 1: Tool-level guards

```python
def execute_tool(name, args):
    # Check if this operation needs confirmation
    if needs_confirmation(name, args):
        return {
            "status": "confirmation_required",
            "message": build_confirmation_message(name, args),
            "pending_action": {"name": name, "args": args}
        }

    # Safe to execute
    return tools[name](**args)

def needs_confirmation(name, args):
    if name == "run_command":
        cmd = args["command"]
        dangerous = ["rm ", "rm -", "drop ", "delete ", "kill ", "> /dev/"]
        return any(d in cmd.lower() for d in dangerous)

    if name == "delete_file":
        return True  # Always confirm file deletion

    if name == "write_file":
        # Confirm if overwriting existing file
        return os.path.exists(args["path"])

    return False
```

### Option 2: Prompt-level guards

```python
SYSTEM_PROMPT = """
You are a coding assistant with file and shell access.

CONFIRMATION REQUIRED for:
- Deleting files or directories
- Overwriting existing files with significant changes
- Running commands with rm, drop, delete, kill
- Git force push or hard reset
- Any operation affecting production

Before these operations:
1. List exactly what will be affected
2. Show file count, line count, or scope
3. Ask user to type 'yes' or adjust the plan
4. Only proceed after explicit confirmation

DO NOT ask confirmation for:
- Reading files
- Creating new files
- Normal git operations
- Running tests
- Installing dependencies
"""
```

### Option 3: Confirmation tool

Give the agent a dedicated confirmation tool:

```python
tools = [
    # ... other tools ...
    {
        "name": "request_confirmation",
        "description": """Request user confirmation before destructive action.

        Use this BEFORE delete, remove, drop, overwrite, or force operations.

        Include: what will happen, what will be affected, scope/count.""",
        "parameters": {
            "action": {"type": "string", "description": "What you're about to do"},
            "affected": {"type": "array", "description": "List of affected items"},
            "scope": {"type": "string", "description": "e.g., '5 files, 200 lines'"}
        }
    }
]
```

Agent usage:

```
Agent: 🔧 request_confirmation({
    "action": "Delete test fixture files",
    "affected": ["fixtures/user.json", "fixtures/order.json", "fixtures/product.json"],
    "scope": "3 files, 45 lines"
})

System: [Waiting for user confirmation]

User: "yes"

Agent: 🔧 delete_file({"path": "fixtures/user.json"})
       🔧 delete_file({"path": "fixtures/order.json"})
       🔧 delete_file({"path": "fixtures/product.json"})
```

## The confirmation message

Good confirmation messages include:

### 1. What will happen

```
Bad:  "Delete files?"
Good: "Delete 3 test fixture files from fixtures/"
```

### 2. Specific items affected

```
Bad:  "Some files will be removed"
Good: "Will delete:
       - fixtures/user.json
       - fixtures/order.json
       - fixtures/product.json"
```

### 3. Scope/impact

```
Bad:  "This will delete code"
Good: "3 files, 245 lines of code"
```

### 4. Reversibility

```
Good: "This can be recovered from git"
Good: "⚠️  This cannot be undone (files not in git)"
```

### Complete example

```
I'll delete outdated migration files:

  Files to delete:
  - migrations/001_add_users.sql
  - migrations/002_add_orders.sql
  - migrations/003_add_products.sql

  Scope: 3 files, 127 lines
  Recovery: ✓ Committed to git (can restore with git checkout)

Type 'yes' to proceed, or specify which to keep.
```

## Handling the response

```python
def handle_confirmation_response(response, pending_action):
    response = response.lower().strip()

    # Explicit yes
    if response in ["yes", "y", "confirm", "do it", "proceed"]:
        return execute_tool(pending_action["name"], pending_action["args"])

    # Explicit no
    if response in ["no", "n", "cancel", "stop", "abort"]:
        return {"status": "cancelled", "message": "Operation cancelled."}

    # Modification request - let the agent handle it
    return {
        "status": "modified",
        "message": response,
        "original_action": pending_action
    }
```

This lets users say:

- `"yes"` → proceed
- `"no"` → cancel
- `"keep auth.py"` → agent adjusts and re-confirms

## Edge cases

### Multiple destructive operations

```
User: "Clean up the repo - delete node_modules, dist, and coverage"

Agent: "I'll delete these directories:

  1. node_modules/ (1,247 packages, 892MB)
  2. dist/ (compiled output, 12MB)
  3. coverage/ (test reports, 3MB)

  Total: 3 directories, ~907MB

  All can be regenerated with 'npm install' and 'npm run build'.

  Type 'yes' to delete all, or specify which to keep."
```

Batch them into one confirmation, not three.

### Nested destructive operations

```
User: "Set up the project from scratch"

# This might involve:
# 1. Delete existing files (destructive)
# 2. Clone fresh repo (safe)
# 3. Install dependencies (safe)
# 4. Overwrite config (destructive)

Agent: "To set up from scratch, I need to:

  1. ⚠️  Delete current project files
     - src/, tests/, config/ (47 files)

  2. Clone fresh from git@github.com:...

  3. Install dependencies

  4. ⚠️  Create config (will overwrite if exists)
     - .env, config.json

  Confirm the destructive steps (1 and 4)?"
```

Group and confirm destructive steps together.

### The "I know what I'm doing" user

Some users hate confirmations:

```python
# Support a "force" mode in system prompt
SYSTEM_PROMPT = """
...

If user says "just do it", "no confirmation", or "I trust you",
skip confirmations for this session. Still show what you did after.
"""
```

```
User: "Delete all .log files, no confirmation needed"

Agent: 🔧 run_command({"command": "find . -name '*.log' -delete"})

"Done. Deleted 23 log files."
```

Trust the user, but log what happened.

## What NOT to confirm

Don't be annoying:

```
# Don't do this
Agent: "I'm about to read config.json. Confirm?"
Agent: "I'll run 'npm test'. Proceed?"
Agent: "Creating new file utils.py. Is that okay?"
```

Only confirm operations that:
1. **Cannot be easily undone** (delete, truncate, overwrite)
2. **Affect production** (deploy, push to main)
3. **Are broad in scope** (delete *.log, update all users)

Reading, creating, and small edits don't need confirmation.

## Implementation with Gantz

Using [Gantz](https://gantz.run), you can build confirmation into your tools:

```yaml
# gantz.yaml
tools:
  - name: delete
    description: |
      Delete a file or directory.
      IMPORTANT: Before using, call 'confirm' with details.
    parameters:
      - name: path
        type: string
        required: true
    script:
      shell: rm -rf "{{path}}"

  - name: confirm
    description: Request user confirmation. Returns 'confirmed' or 'cancelled'.
    parameters:
      - name: action
        type: string
        description: What will happen
        required: true
      - name: details
        type: string
        description: Specific items/scope
        required: true
    script:
      shell: |
        echo "⚠️  Confirmation required:"
        echo ""
        echo "Action: {{action}}"
        echo "Details: {{details}}"
        echo ""
        read -p "Type 'yes' to proceed: " response
        if [ "$response" = "yes" ]; then
          echo "confirmed"
        else
          echo "cancelled"
        fi
```

The agent learns to call `confirm` before `delete`.

## The pattern in one diagram

```
         User Request
              │
              ▼
    ┌─────────────────┐
    │ Is this         │
    │ destructive?    │
    └────────┬────────┘
             │
      ┌──────┴──────┐
      │             │
     No            Yes
      │             │
      ▼             ▼
  ┌───────┐   ┌────────────┐
  │Execute│   │Show impact │
  │ tool  │   │Ask confirm │
  └───────┘   └─────┬──────┘
                    │
         ┌──────────┼──────────┐
         │          │          │
        Yes      Modify        No
         │          │          │
         ▼          ▼          ▼
    ┌───────┐  ┌────────┐  ┌────────┐
    │Execute│  │Adjust  │  │Cancel  │
    │ tool  │  │& retry │  │        │
    └───────┘  └────────┘  └────────┘
```

## Summary

The Confirm-Before-Destroy pattern:

| Step | What to do |
|------|------------|
| **Detect** | Identify destructive operations (delete, drop, overwrite, force) |
| **Show** | List exactly what will be affected |
| **Scope** | Include counts, sizes, reversibility |
| **Wait** | Require explicit "yes" or adjustment |
| **Execute** | Only after confirmation |

**Always confirm:**
- File/directory deletion
- Database drops/mass updates
- Git force operations
- Production deployments

**Never confirm:**
- Reading files
- Creating new files
- Small edits
- Running tests

Give users control. Catch mistakes before they happen.

## Related reading

- [When to Use Human-in-the-Loop](/post/human-in-the-loop/) - Adding human oversight
- [Defending Against Prompt Injection](/post/prompt-injection/) - Security considerations
- [Error Recovery Patterns for AI Agents](/post/error-recovery/) - Handling failures gracefully

---

*What's the worst thing your agent deleted without asking?*
