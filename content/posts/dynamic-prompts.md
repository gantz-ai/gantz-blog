+++
title = 'Dynamic Prompts: Changing Instructions Mid-Conversation'
date = 2025-12-23
draft = false
tags = ['agents', 'ai', 'mcp']
+++


Your system prompt is set at the start. Then it never changes.

But your agent learns things during the conversation. The user prefers TypeScript. The codebase uses tabs. The tests are in Jest.

Why keep using the same generic instructions?

## Static vs dynamic prompts

### Static prompt

```python
SYSTEM_PROMPT = """
You are a coding assistant.
"""

# Same prompt for every turn, every user, every project
messages = [
    {"role": "system", "content": SYSTEM_PROMPT},
    *conversation_history
]
```

### Dynamic prompt

```python
def build_prompt(context):
    return f"""
You are a coding assistant.

Project: {context.get('project_type', 'unknown')}
Language: {context.get('language', 'not detected')}
Style: {context.get('style_preferences', 'none detected')}
User preferences: {context.get('user_prefs', 'none')}
Current mode: {context.get('mode', 'normal')}
"""

# Prompt evolves as you learn
messages = [
    {"role": "system", "content": build_prompt(learned_context)},
    *conversation_history
]
```

The prompt adapts. The agent gets smarter.

## Pattern 1: Learning from the codebase

First tool call reveals project details. Use them.

```python
class AdaptiveAgent:
    def __init__(self):
        self.context = {}

    def update_from_tool_result(self, tool_name, result):
        if tool_name == "read_file":
            # Detect language
            if "def " in result and "import " in result:
                self.context["language"] = "Python"
            elif "function " in result or "const " in result:
                self.context["language"] = "JavaScript"
            elif "func " in result and "package " in result:
                self.context["language"] = "Go"

            # Detect style
            if "\t" in result:
                self.context["indentation"] = "tabs"
            elif "    " in result:
                self.context["indentation"] = "4 spaces"
            elif "  " in result:
                self.context["indentation"] = "2 spaces"

        if tool_name == "run_command" and "package.json" in result:
            if "jest" in result.lower():
                self.context["test_framework"] = "Jest"
            elif "mocha" in result.lower():
                self.context["test_framework"] = "Mocha"
            elif "pytest" in result.lower():
                self.context["test_framework"] = "pytest"

    def build_prompt(self):
        base = "You are a coding assistant.\n\n"

        if self.context:
            base += "Project context:\n"
            for key, value in self.context.items():
                base += f"- {key}: {value}\n"
            base += "\nFollow these conventions in your code."

        return base
```

After reading a few files:

```python
# Prompt becomes:
"""
You are a coding assistant.

Project context:
- language: TypeScript
- indentation: 2 spaces
- test_framework: Jest
- style: single quotes, no semicolons

Follow these conventions in your code.
"""
```

Now every code suggestion matches the project style.

## Pattern 2: User preference detection

Users reveal preferences through corrections. Remember them.

```python
class PreferenceLearner:
    def __init__(self):
        self.preferences = {}

    def learn_from_feedback(self, user_message):
        message = user_message.lower()

        # Explicit preferences
        if "always use" in message:
            # "always use typescript" → preference
            self.extract_preference(message, "always use")

        if "don't use" in message or "never use" in message:
            self.extract_negative_preference(message)

        # Implicit preferences from corrections
        if "no, use" in message:
            # "no, use async/await instead"
            self.preferences["preferred_pattern"] = self.extract_after(message, "no, use")

        if "i prefer" in message:
            self.preferences["style"] = self.extract_after(message, "i prefer")

    def build_preference_prompt(self):
        if not self.preferences:
            return ""

        lines = ["User preferences (always follow these):"]
        for key, value in self.preferences.items():
            lines.append(f"- {value}")
        return "\n".join(lines)
```

Conversation:

```
User: "Write a function to fetch users"
Agent: *writes callback-based code*

User: "No, use async/await instead"
Agent: *rewrites with async/await*

# Agent learns: user prefers async/await
# Future prompt includes: "User prefers async/await over callbacks"
```

Now all future code uses async/await automatically.

## Pattern 3: Mode switching

Different tasks need different instructions.

```python
class ModalAgent:
    MODES = {
        "normal": """
            You are a coding assistant.
            Help with whatever the user needs.
        """,
        "debugging": """
            You are in DEBUGGING MODE.
            Focus on finding the root cause.
            - Check logs first
            - Reproduce the issue
            - Form hypotheses and test them
            - Don't suggest fixes until you understand the bug
        """,
        "refactoring": """
            You are in REFACTORING MODE.
            - Make minimal changes
            - Preserve behavior exactly
            - Run tests after each change
            - Commit frequently
        """,
        "planning": """
            You are in PLANNING MODE.
            - Don't write code yet
            - Outline the approach
            - Identify files to change
            - List potential issues
            - Get user approval before implementing
        """,
        "careful": """
            You are in CAREFUL MODE.
            - Confirm before any file changes
            - Show diffs before applying
            - Make one change at a time
            - Extra verification on destructive operations
        """
    }

    def __init__(self):
        self.mode = "normal"

    def detect_mode(self, user_message):
        message = user_message.lower()

        if any(w in message for w in ["bug", "error", "failing", "broken", "doesn't work"]):
            return "debugging"
        if any(w in message for w in ["refactor", "clean up", "reorganize"]):
            return "refactoring"
        if any(w in message for w in ["plan", "design", "how should", "approach"]):
            return "planning"
        if any(w in message for w in ["careful", "be safe", "double check"]):
            return "careful"

        return "normal"

    def set_mode(self, mode):
        self.mode = mode

    def build_prompt(self):
        return self.MODES[self.mode]
```

Usage:

```
User: "There's a bug in the login flow"
# Mode switches to "debugging"

User: "Clean up the utils folder"
# Mode switches to "refactoring"

User: "Let's plan the new feature first"
# Mode switches to "planning"
```

Each mode has specialized instructions.

## Pattern 4: Progressive disclosure

Start simple. Add complexity as needed.

```python
class ProgressiveAgent:
    def __init__(self):
        self.turn_count = 0
        self.complexity_level = "basic"
        self.features_used = set()

    def update_complexity(self, tool_calls):
        # Track what features are being used
        for call in tool_calls:
            self.features_used.add(call.name)

        # Upgrade complexity based on usage
        if len(self.features_used) > 3:
            self.complexity_level = "intermediate"
        if "run_command" in self.features_used and "write_file" in self.features_used:
            self.complexity_level = "advanced"

    def build_prompt(self):
        if self.complexity_level == "basic":
            return """
            You are a coding assistant.
            Start simple. Read files to understand before making changes.
            """

        if self.complexity_level == "intermediate":
            return """
            You are a coding assistant.
            You can chain multiple tools to complete tasks.
            Read → Understand → Modify → Verify.
            """

        if self.complexity_level == "advanced":
            return """
            You are a coding assistant.
            Use parallel tool calls when efficient.
            Chain complex operations.
            Run tests after changes.
            Commit logical units of work.
            """
```

New users get simple instructions. Power users get advanced features.

## Pattern 5: Context injection

Inject relevant context based on what's happening.

```python
class ContextInjector:
    def __init__(self):
        self.active_file = None
        self.recent_errors = []
        self.current_task = None

    def update_context(self, tool_name, tool_args, result):
        if tool_name == "read_file":
            self.active_file = tool_args.get("path")

        if tool_name == "run_command" and "error" in result.lower():
            self.recent_errors.append(result[:500])
            self.recent_errors = self.recent_errors[-3:]  # Keep last 3

    def set_task(self, task):
        self.current_task = task

    def build_prompt(self):
        parts = ["You are a coding assistant."]

        if self.active_file:
            parts.append(f"\nCurrently working on: {self.active_file}")

        if self.recent_errors:
            parts.append("\nRecent errors to be aware of:")
            for err in self.recent_errors:
                parts.append(f"- {err[:200]}")

        if self.current_task:
            parts.append(f"\nCurrent task: {self.current_task}")

        return "\n".join(parts)
```

The prompt now includes:

```
You are a coding assistant.

Currently working on: src/auth/login.ts
Recent errors to be aware of:
- TypeError: Cannot read property 'id' of undefined at line 47
Current task: Fix authentication bug
```

Agent stays focused on what matters.

## Pattern 6: Guardrails based on state

Add restrictions when entering dangerous territory.

```python
class AdaptiveGuardrails:
    def __init__(self):
        self.in_production = False
        self.touched_sensitive_files = False
        self.made_destructive_changes = False

    def update_state(self, tool_name, tool_args, result):
        path = tool_args.get("path", "")
        command = tool_args.get("command", "")

        # Detect production context
        if "prod" in path.lower() or "production" in command.lower():
            self.in_production = True

        # Detect sensitive files
        sensitive = [".env", "secrets", "credentials", "password", "key"]
        if any(s in path.lower() for s in sensitive):
            self.touched_sensitive_files = True

        # Detect destructive changes
        if "rm " in command or "delete" in command or "drop" in command.lower():
            self.made_destructive_changes = True

    def build_prompt(self):
        base = "You are a coding assistant.\n"

        if self.in_production:
            base += """
⚠️ PRODUCTION ENVIRONMENT DETECTED
- Double-check all commands before running
- Confirm with user before any changes
- Prefer read-only operations
- No force pushes or hard resets
"""

        if self.touched_sensitive_files:
            base += """
🔒 SENSITIVE FILES IN SCOPE
- Never output secrets or credentials
- Don't commit .env files
- Mask sensitive values in responses
"""

        if self.made_destructive_changes:
            base += """
🗑️ DESTRUCTIVE OPERATIONS ACTIVE
- Confirm each deletion with user
- Suggest backups before proceeding
- Show what will be affected
"""

        return base
```

Guardrails activate automatically when needed.

## Pattern 7: Learning the codebase structure

Build a mental map, inject it into prompts.

```python
class CodebaseMapper:
    def __init__(self):
        self.structure = {}
        self.key_files = []
        self.patterns = []

    def learn_structure(self, tool_results):
        # From ls or find commands
        if "src/" in tool_results:
            self.structure["source"] = "src/"
        if "tests/" in tool_results or "__tests__" in tool_results:
            self.structure["tests"] = self.detect_test_dir(tool_results)
        if "package.json" in tool_results:
            self.structure["type"] = "Node.js"
        if "requirements.txt" in tool_results:
            self.structure["type"] = "Python"

    def add_key_file(self, path, purpose):
        self.key_files.append({"path": path, "purpose": purpose})

    def build_prompt(self):
        if not self.structure:
            return "You are a coding assistant."

        prompt = "You are a coding assistant.\n\nProject structure:\n"

        for key, value in self.structure.items():
            prompt += f"- {key}: {value}\n"

        if self.key_files:
            prompt += "\nKey files:\n"
            for f in self.key_files[:5]:  # Top 5
                prompt += f"- {f['path']}: {f['purpose']}\n"

        return prompt
```

Result:

```
You are a coding assistant.

Project structure:
- type: Node.js/TypeScript
- source: src/
- tests: __tests__/
- config: config/

Key files:
- src/index.ts: Main entry point
- src/api/routes.ts: API route definitions
- src/db/connection.ts: Database setup
```

Agent understands the project layout.

## Implementation with Gantz

With [Gantz](https://gantz.run), you can build dynamic context into your setup:

```yaml
# gantz.yaml
system: |
  You are a coding assistant.

  {{#if detected_language}}
  Language: {{detected_language}}
  {{/if}}

  {{#if user_preferences}}
  User preferences:
  {{#each user_preferences}}
  - {{this}}
  {{/each}}
  {{/if}}

  {{#if mode}}
  Current mode: {{mode}}
  {{/if}}

tools:
  - name: read
    description: Read a file
    parameters:
      - name: path
        type: string
        required: true
    script:
      shell: cat "{{path}}"
    # Hook to update context after reading
    on_result: detect_project_context

  - name: set_mode
    description: Switch agent mode (debugging, refactoring, planning)
    parameters:
      - name: mode
        type: string
        required: true
    script:
      shell: echo "Mode set to {{mode}}"
```

Context updates flow into the prompt automatically.

## When to update the prompt

| Trigger | What to update |
|---------|----------------|
| First file read | Language, style, indentation |
| Package file read | Framework, dependencies, test runner |
| User correction | Add preference |
| Error encountered | Add to recent errors |
| Task stated | Set current focus |
| Sensitive file touched | Add guardrails |
| Mode keyword detected | Switch mode |

## What NOT to put in dynamic prompts

Keep it focused:

```python
# ❌ Too much noise
prompt = f"""
You are a coding assistant.
Files read this session: {all_200_files_read}
All tool calls: {entire_tool_history}
Complete git log: {full_git_log}
"""

# ✅ Focused context
prompt = f"""
You are a coding assistant.
Project: TypeScript/React
Style: 2 spaces, single quotes
Current file: src/components/Header.tsx
Recent error: Props type mismatch on line 23
"""
```

More context isn't always better. Relevant context is.

## Summary

Dynamic prompts let your agent learn and adapt:

| Pattern | What changes |
|---------|--------------|
| Codebase learning | Language, style, frameworks |
| Preference detection | User's preferred patterns |
| Mode switching | Debugging vs refactoring vs planning |
| Progressive disclosure | Basic → Advanced instructions |
| Context injection | Current file, recent errors, task |
| Adaptive guardrails | Safety rules when needed |
| Structure mapping | Project layout knowledge |

Start static. Add dynamics where they help.

Your prompt should grow smarter, just like your agent.

---

*What context do you inject into your agent's prompts?*
