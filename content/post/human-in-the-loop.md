+++
title = "Human-in-the-Loop: When AI Agents Should Stop and Ask"
date = 2025-12-17
image = "/images/agent-asian-street.png"
draft = false
tags = ['patterns', 'security', 'architecture']
+++


Autonomous agents are powerful. Autonomous agents with no guardrails are dangerous.

The best agents know when to stop and ask.

## The problem with full autonomy

```
User: "Clean up my inbox"

Fully autonomous agent:
1. Connects to email
2. Deletes 5,000 emails
3. "Done! Inbox cleaned."

User: "WHERE ARE MY EMAILS?!"
```

The agent did what it thought was right. It was wrong.

## When to ask

Not every action needs approval. But some definitely do.

### 1. Destructive actions

Anything that can't be undone.

```
ALWAYS ASK:
- Delete files/data
- Overwrite content
- Drop database tables
- Remove user accounts
- Unsubscribe from services

DON'T NEED TO ASK:
- Read files
- Search data
- List items
- Generate previews
```

### 2. High-cost operations

Money or resources at stake.

```
ALWAYS ASK:
- Purchases over $X
- API calls with costs
- Sending to large lists
- Deploying to production
- Creating paid resources

DON'T NEED TO ASK:
- Free tier operations
- Local computations
- Draft creation
- Staging deployments
```

### 3. External communication

Messages leaving your system.

```
ALWAYS ASK:
- Sending emails
- Posting to social media
- Messaging customers
- Publishing content
- Submitting forms

DON'T NEED TO ASK:
- Drafting messages
- Internal notifications
- Logging
```

### 4. Ambiguous requests

When the agent isn't sure what you mean.

```
User: "Send the report"

Agent should ask:
- Which report? (Q3 financials, weekly status, customer analysis)
- To whom? (team, client, executives)
- When? (now, scheduled, after review)
```

### 5. First-time actions

New patterns the agent hasn't done before.

```
First time connecting to a service → Ask
First time using a destructive tool → Ask
First time with high-value operation → Ask

After user approves pattern → Maybe don't ask next time
```

## Approval patterns

### Pattern 1: Pre-action confirmation

Ask before doing anything risky.

```
Agent: "I'm about to delete 150 old log files. Proceed?"
User: "Yes"
Agent: [deletes files]
Agent: "Done. 150 files deleted."
```

```python
def execute_with_confirmation(action, risk_level):
    if risk_level >= RISK_THRESHOLD:
        approved = ask_user(
            f"I'm about to: {action.description}\n"
            f"This will affect: {action.scope}\n"
            f"Proceed? (yes/no)"
        )
        if not approved:
            return {"status": "cancelled", "reason": "User declined"}

    return action.execute()
```

### Pattern 2: Plan review

Show the full plan, then execute.

```
Agent: "Here's my plan to reorganize your files:
1. Create folders: Projects, Archive, Personal
2. Move 45 work files to Projects
3. Move 120 old files to Archive
4. Move 12 personal files to Personal

Should I proceed?"

User: "Move personal files to a different location"
Agent: "Updated. Personal files will go to ~/Private instead. Proceed?"
User: "Yes"
```

```python
def execute_plan_with_review(task):
    # Create plan
    plan = planner.create(task)

    # Show plan to user
    approved = ask_user(
        f"Here's my plan:\n{format_plan(plan)}\n\n"
        f"Should I proceed, or would you like changes?"
    )

    if approved == "proceed":
        return executor.run(plan)
    elif approved == "modify":
        feedback = get_user_feedback()
        return execute_plan_with_review(task + f"\n\nUser feedback: {feedback}")
    else:
        return {"status": "cancelled"}
```

### Pattern 3: Periodic checkpoints

Check in during long-running tasks.

```
Agent: "Starting migration. I'll check in every 100 records."

[processes 100 records]
Agent: "Progress: 100/1000 complete. 3 errors encountered. Continue?"
User: "What were the errors?"
Agent: "Records 45, 67, 89 had invalid dates. I skipped them."
User: "Continue, but save errors to a file"

[processes 100 more]
Agent: "Progress: 200/1000 complete. 1 new error. Continuing..."
```

```python
def execute_with_checkpoints(items, checkpoint_interval=100):
    results = []
    errors = []

    for i, item in enumerate(items):
        try:
            results.append(process(item))
        except Exception as e:
            errors.append({"item": i, "error": str(e)})

        # Checkpoint
        if (i + 1) % checkpoint_interval == 0:
            status = f"Progress: {i+1}/{len(items)}. Errors: {len(errors)}"
            if not ask_user(f"{status}\nContinue?"):
                return {"partial": results, "errors": errors, "stopped_at": i}

    return {"results": results, "errors": errors}
```

### Pattern 4: Dry run first

Show what would happen without doing it.

```
Agent: "Dry run complete. Here's what would happen:
- 5 files would be renamed
- 2 files would be moved
- 1 file would be deleted (old_backup.zip)

Execute for real?"
```

```python
def execute_with_dry_run(action):
    # Dry run
    preview = action.dry_run()

    approved = ask_user(
        f"Dry run complete:\n{format_preview(preview)}\n\n"
        f"Execute for real?"
    )

    if approved:
        return action.execute()
    return {"status": "dry_run_only", "preview": preview}
```

### Pattern 5: Escalating autonomy

Start cautious, become more autonomous over time.

```
Week 1:
Agent asks before every email send

Week 2:
Agent asks before emails to external recipients only

Week 4:
Agent sends routine emails automatically, asks for unusual ones

Month 2:
Agent handles most communication, asks for sensitive topics only
```

```python
class EscalatingAutonomy:
    def __init__(self, user_id):
        self.user_id = user_id
        self.approval_history = load_history(user_id)

    def needs_approval(self, action):
        # Always ask for high-risk
        if action.risk_level == "high":
            return True

        # Check if user has approved similar actions before
        similar_approvals = self.find_similar(action)

        if len(similar_approvals) >= 3:
            # User has approved this type 3+ times
            return False
        elif len(similar_approvals) >= 1:
            # Ask but note the pattern
            return True
        else:
            # First time, definitely ask
            return True

    def record_approval(self, action, approved):
        self.approval_history.append({
            "action_type": action.type,
            "action_hash": hash(action),
            "approved": approved,
            "timestamp": now()
        })
```

## Implementation

### Risk classification

```python
class RiskClassifier:
    HIGH_RISK_ACTIONS = [
        "delete", "remove", "drop", "destroy",
        "send", "publish", "post", "deploy",
        "purchase", "pay", "subscribe",
        "grant", "revoke", "change_password"
    ]

    MEDIUM_RISK_ACTIONS = [
        "update", "modify", "edit", "move",
        "create", "add", "install"
    ]

    LOW_RISK_ACTIONS = [
        "read", "list", "search", "get",
        "preview", "draft", "analyze"
    ]

    def classify(self, action):
        action_verb = action.name.split("_")[0].lower()

        if action_verb in self.HIGH_RISK_ACTIONS:
            return "high"
        elif action_verb in self.MEDIUM_RISK_ACTIONS:
            return "medium"
        else:
            return "low"
```

### Confirmation prompts

```python
CONFIRMATION_TEMPLATES = {
    "delete": "I'm about to delete {count} {item_type}. This cannot be undone. Proceed?",
    "send": "Ready to send {message_type} to {recipient_count} recipients. Send now?",
    "deploy": "Deploying {version} to {environment}. This will affect {user_count} users. Proceed?",
    "purchase": "About to purchase {item} for {price}. Confirm payment?",
    "modify": "This will modify {count} {item_type}. Review changes first?",
}

def get_confirmation_prompt(action, context):
    template = CONFIRMATION_TEMPLATES.get(action.type, "Proceed with {action}?")
    return template.format(**context, action=action.description)
```

### MCP tools with confirmations

Build confirmation into your tools with [Gantz](https://gantz.run):

```yaml
# tools.yaml
tools:
  - name: delete_files
    description: Delete files (requires confirmation)
    parameters:
      - name: pattern
        type: string
        required: true
      - name: confirmed
        type: boolean
        default: false
    script:
      shell: |
        if [ "{{confirmed}}" != "true" ]; then
          # Return preview instead of executing
          echo '{"status": "needs_confirmation", "files": ['
          find . -name "{{pattern}}" -type f | head -20 | while read f; do
            echo "\"$f\","
          done
          echo '], "count": '$(find . -name "{{pattern}}" -type f | wc -l)'}'
          exit 0
        fi

        # Actually delete
        find . -name "{{pattern}}" -type f -delete
        echo '{"status": "deleted"}'

  - name: send_email
    description: Send email (shows draft first)
    parameters:
      - name: to
        type: string
        required: true
      - name: subject
        type: string
        required: true
      - name: body
        type: string
        required: true
      - name: confirmed
        type: boolean
        default: false
    script:
      shell: |
        if [ "{{confirmed}}" != "true" ]; then
          echo '{"status": "draft", "preview": {"to": "{{to}}", "subject": "{{subject}}", "body": "{{body}}"}}'
          exit 0
        fi

        # Actually send
        python send_email.py --to "{{to}}" --subject "{{subject}}" --body "{{body}}"
```

### Agent integration

```python
class HumanInTheLoopAgent:
    def __init__(self, llm, tools, ask_fn):
        self.llm = llm
        self.tools = tools
        self.ask_fn = ask_fn  # Function to ask user
        self.classifier = RiskClassifier()

    def execute(self, task):
        while not done:
            action = self.llm.decide_action(task, context)

            risk = self.classifier.classify(action)

            if risk == "high":
                # Always confirm high risk
                if not self.confirm_action(action):
                    context.append("User declined action. Try alternative.")
                    continue

            elif risk == "medium":
                # Dry run first
                preview = self.tools.dry_run(action)
                if not self.confirm_preview(action, preview):
                    context.append("User declined after preview. Try alternative.")
                    continue

            # Execute
            result = self.tools.execute(action)
            context.append(result)

    def confirm_action(self, action):
        prompt = get_confirmation_prompt(action.type, action.context)
        return self.ask_fn(prompt)

    def confirm_preview(self, action, preview):
        prompt = f"Preview of {action.description}:\n{preview}\n\nProceed?"
        return self.ask_fn(prompt)
```

## UX for confirmations

### Good confirmation dialogs

```
✓ Clear action description
✓ Scope/impact stated
✓ Reversibility mentioned
✓ Simple yes/no/modify options

Example:
┌─────────────────────────────────────────────┐
│ Delete 47 files from /logs                  │
├─────────────────────────────────────────────┤
│ This will permanently delete:               │
│ • 47 log files                              │
│ • 2.3 GB of data                            │
│                                             │
│ This action cannot be undone.               │
│                                             │
│ [Cancel]  [View Files]  [Delete]            │
└─────────────────────────────────────────────┘
```

### Bad confirmation dialogs

```
✗ Vague description
✗ No scope information
✗ Technical jargon
✗ Too many options

Bad example:
┌─────────────────────────────────────────────┐
│ Execute rm -rf operation?                   │
│                                             │
│ [Yes] [No] [Maybe] [Help] [Settings] [...]  │
└─────────────────────────────────────────────┘
```

### Reducing confirmation fatigue

Too many confirmations = users click "yes" without reading.

```python
def smart_confirmation(action, user_history):
    # Skip confirmation for actions user always approves
    if user_history.always_approves(action.type):
        return True

    # Batch similar confirmations
    if pending_similar := get_pending_similar(action):
        return batch_confirm([action, *pending_similar])

    # Use progressive disclosure
    if action.risk == "medium":
        # Quick confirmation with "show details" option
        return quick_confirm(action)
    else:
        # Full confirmation for high risk
        return full_confirm(action)
```

## Balancing autonomy and safety

```
Too cautious:                    Too autonomous:
"Delete file?"                   [deletes everything]
"Delete another file?"           [no questions asked]
"Delete another file?"
[user stops using agent]

Sweet spot:
"I'll delete 47 log files older than 30 days. Proceed?"
[one confirmation, clear scope]
```

### The autonomy dial

```
Full manual ◄─────────────────────────► Full auto
     │                                       │
     │  ┌─────────────────────────────────┐  │
     │  │ • Low risk: auto                │  │
     │  │ • Medium risk: dry run + confirm│  │
     │  │ • High risk: always confirm     │  │
     │  │ • Destructive: confirm + verify │  │
     │  └─────────────────────────────────┘  │
     │                                       │
   Safe but slow                    Fast but risky
```

## Summary

Good agents ask before acting when:
- Actions are destructive
- Money is involved
- Messages go external
- Requests are ambiguous
- It's a first-time action

Approval patterns:
- Pre-action confirmation
- Plan review
- Periodic checkpoints
- Dry run first
- Escalating autonomy

Build confirmation into your tools from the start. It's easier than explaining why the agent deleted production.

The goal isn't to eliminate human oversight. It's to put it in the right places.

---

*How do you handle human-in-the-loop in your agents? Where do you draw the line on autonomy?*
