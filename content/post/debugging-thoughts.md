+++
title = "How to Read an Agent's Mind: Debugging Thought Processes"
date = 2025-12-25
image = "images/agent-jungle-green.png"
draft = false
tags = ['debugging', 'patterns', 'best-practices']
+++


Your agent did something stupid. Why?

You can't ask it. It already forgot.

Here's how to figure out what it was thinking.

## The problem

Agent debugging is hard because:

```
Input: "Update the config file"

Agent: *thinks something*
Agent: *calls wrong tool*
Agent: *makes things worse*

You: "Why did you do that?!"
Agent: "Do what?"
```

The reasoning is invisible. The decision already happened. The context is gone.

## Capture everything

### Step 1: Log the full context

Don't just log inputs and outputs. Log what the model saw.

```python
class DebugAgent:
    def __init__(self, llm, tools):
        self.llm = llm
        self.tools = tools
        self.thought_log = []

    def think(self, context):
        # Build the full prompt
        messages = self.build_messages(context)

        # LOG IT
        self.thought_log.append({
            "timestamp": time.time(),
            "type": "llm_input",
            "messages": messages,
            "available_tools": [t.name for t in self.tools]
        })

        # Get response
        response = self.llm.create(messages=messages, tools=self.tools)

        # LOG IT
        self.thought_log.append({
            "timestamp": time.time(),
            "type": "llm_output",
            "response": response,
            "tool_call": response.tool_call if hasattr(response, 'tool_call') else None,
            "content": response.content
        })

        return response
```

### Step 2: Log tool calls and results

```python
def execute_tool(self, tool_call):
    self.thought_log.append({
        "timestamp": time.time(),
        "type": "tool_call",
        "tool": tool_call.name,
        "params": tool_call.params
    })

    try:
        result = self.tools.call(tool_call.name, tool_call.params)

        self.thought_log.append({
            "timestamp": time.time(),
            "type": "tool_result",
            "tool": tool_call.name,
            "success": True,
            "result": result[:1000]  # Truncate for logging
        })

        return result

    except Exception as e:
        self.thought_log.append({
            "timestamp": time.time(),
            "type": "tool_error",
            "tool": tool_call.name,
            "error": str(e)
        })
        raise
```

### Step 3: Export for analysis

```python
def export_thoughts(self):
    return {
        "session_id": self.session_id,
        "thoughts": self.thought_log,
        "summary": {
            "total_llm_calls": len([t for t in self.thought_log if t["type"] == "llm_input"]),
            "total_tool_calls": len([t for t in self.thought_log if t["type"] == "tool_call"]),
            "errors": len([t for t in self.thought_log if t["type"] == "tool_error"])
        }
    }
```

## Reading the thought log

### Format for readability

```python
def print_thoughts(thought_log):
    for i, thought in enumerate(thought_log):
        timestamp = datetime.fromtimestamp(thought["timestamp"]).strftime("%H:%M:%S")

        if thought["type"] == "llm_input":
            print(f"\n[{timestamp}] 🧠 THINKING")
            print(f"  Context length: {len(str(thought['messages']))} chars")
            print(f"  Available tools: {thought['available_tools']}")
            print(f"  Last message: {thought['messages'][-1]['content'][:100]}...")

        elif thought["type"] == "llm_output":
            print(f"\n[{timestamp}] 💭 DECIDED")
            if thought["tool_call"]:
                print(f"  Action: Call {thought['tool_call']['name']}")
                print(f"  Params: {thought['tool_call']['params']}")
            else:
                print(f"  Response: {thought['content'][:100]}...")

        elif thought["type"] == "tool_call":
            print(f"\n[{timestamp}] 🔧 CALLING: {thought['tool']}")
            print(f"  Params: {thought['params']}")

        elif thought["type"] == "tool_result":
            print(f"\n[{timestamp}] ✅ RESULT")
            print(f"  {thought['result'][:200]}...")

        elif thought["type"] == "tool_error":
            print(f"\n[{timestamp}] ❌ ERROR")
            print(f"  {thought['error']}")
```

Output:

```
[14:32:01] 🧠 THINKING
  Context length: 2847 chars
  Available tools: ['read_file', 'write_file', 'search']
  Last message: Update the config file to use port 8080...

[14:32:02] 💭 DECIDED
  Action: Call search
  Params: {'query': 'config'}

[14:32:02] 🔧 CALLING: search
  Params: {'query': 'config'}

[14:32:03] ✅ RESULT
  config.yaml, config.json, config.toml...

[14:32:03] 🧠 THINKING
  Context length: 3421 chars
  Available tools: ['read_file', 'write_file', 'search']
  Last message: [tool result: config.yaml, config.json...]

[14:32:04] 💭 DECIDED
  Action: Call read_file
  Params: {'path': 'config.yaml'}
```

Now you can see exactly what happened.

## Common patterns to look for

### Pattern 1: Wrong tool selection

```
🧠 THINKING
  Available tools: ['read_file', 'write_file', 'search', 'query_database']
  Last message: "Find customers who ordered last week"

💭 DECIDED
  Action: Call search           ← WRONG! Should be query_database
  Params: {'query': 'customers'}
```

**Why it happened**: Tool descriptions are ambiguous.

**Fix**: Improve tool descriptions.

```yaml
# Before
- name: search
  description: Search for things

# After
- name: search
  description: Search files by content. Use for finding code, configs, or text files. NOT for database queries.
```

### Pattern 2: Missing context

```
🧠 THINKING
  Context length: 847 chars      ← Suspiciously short
  Last message: "Update the config"

💭 DECIDED
  Action: Call write_file
  Params: {'path': 'config.yaml', 'content': '???'}  ← Doesn't know what to write
```

**Why it happened**: Previous context was lost or truncated.

**Fix**: Check context window management.

### Pattern 3: Hallucinated parameters

```
🧠 THINKING
  Available tools: ['send_email']
  Last message: "Email John about the meeting"

💭 DECIDED
  Action: Call send_email
  Params: {'to': 'john@company.com'}    ← Where did this email come from?
```

**Why it happened**: Model guessed the email instead of looking it up.

**Fix**: Add validation, require explicit data sources.

```python
def validate_tool_call(tool_call, context):
    if tool_call.name == "send_email":
        email = tool_call.params.get("to")
        # Check if email was actually in context
        if email not in str(context):
            raise ValueError(f"Email {email} not found in context. Look it up first.")
```

### Pattern 4: Infinite loop setup

```
[14:32:01] 💭 DECIDED: Call search {'query': 'config'}
[14:32:02] ✅ RESULT: No results
[14:32:03] 💭 DECIDED: Call search {'query': 'config'}    ← Same thing
[14:32:04] ✅ RESULT: No results
[14:32:05] 💭 DECIDED: Call search {'query': 'config'}    ← Loop detected
```

**Why it happened**: Agent doesn't remember failures.

**Fix**: Inject failure memory.

### Pattern 5: Context overflow

```
🧠 THINKING
  Context length: 127843 chars   ← Way too big
  [context truncated]

💭 DECIDED
  Action: Something random       ← Lost the original instruction
```

**Why it happened**: Too much context, important info got cut.

**Fix**: Smarter context management.

## Ask the agent to explain

Add a "think out loud" instruction:

```python
SYSTEM_PROMPT = """
Before taking any action, briefly explain your reasoning:
1. What is the user asking for?
2. What information do I have?
3. What information do I need?
4. Which tool should I use and why?

Then proceed with the action.
"""
```

Now you get:

```
💭 RESPONSE:
"The user wants to update the config file to use port 8080.

1. User is asking for: config file modification
2. I have: the new port number (8080)
3. I need: the current config file contents
4. I should: use read_file first to see the current config

Let me read the config file first."

ACTION: read_file {'path': 'config.yaml'}
```

Much easier to debug.

## Replay and step through

Build a replay system:

```python
class AgentReplayer:
    def __init__(self, thought_log):
        self.thoughts = thought_log
        self.position = 0

    def step(self):
        if self.position >= len(self.thoughts):
            print("End of session")
            return

        thought = self.thoughts[self.position]
        self.print_thought(thought)
        self.position += 1

    def back(self):
        if self.position > 0:
            self.position -= 1
            thought = self.thoughts[self.position]
            self.print_thought(thought)

    def jump_to_error(self):
        for i, thought in enumerate(self.thoughts):
            if thought["type"] == "tool_error":
                self.position = i
                self.print_thought(thought)
                return
        print("No errors found")

    def show_context_at(self, position):
        # Find the nearest llm_input before this position
        for i in range(position, -1, -1):
            if self.thoughts[i]["type"] == "llm_input":
                print("Context at this point:")
                for msg in self.thoughts[i]["messages"]:
                    print(f"  [{msg['role']}]: {msg['content'][:200]}...")
                return
```

Usage:

```python
replayer = AgentReplayer(agent.export_thoughts())

replayer.jump_to_error()
# Shows: ❌ ERROR in search tool

replayer.back()
# Shows: 🔧 CALLING: search with params...

replayer.back()
# Shows: 💭 DECIDED to call search

replayer.show_context_at(replayer.position)
# Shows: What the agent saw when it made this decision
```

## Visual debugging

Create a simple web UI:

```python
from flask import Flask, render_template_string

app = Flask(__name__)

TEMPLATE = """
<html>
<head><style>
  .thought { margin: 10px; padding: 10px; border-radius: 5px; }
  .llm_input { background: #e3f2fd; }
  .llm_output { background: #f3e5f5; }
  .tool_call { background: #fff3e0; }
  .tool_result { background: #e8f5e9; }
  .tool_error { background: #ffebee; }
</style></head>
<body>
  <h1>Agent Thought Log</h1>
  {% for thought in thoughts %}
  <div class="thought {{ thought.type }}">
    <strong>{{ thought.timestamp }}</strong> - {{ thought.type }}<br>
    <pre>{{ thought | tojson(indent=2) }}</pre>
  </div>
  {% endfor %}
</body>
</html>
"""

@app.route("/debug/<session_id>")
def debug_session(session_id):
    thoughts = load_thoughts(session_id)
    return render_template_string(TEMPLATE, thoughts=thoughts)
```

## MCP tool for debugging

Add debug tools to your [Gantz](https://gantz.run) setup:

```yaml
# gantz.yaml
tools:
  - name: explain_decision
    description: Explain why you're about to do something (for debugging)
    parameters:
      - name: action
        type: string
        required: true
      - name: reasoning
        type: string
        required: true
    script:
      shell: |
        echo "[DEBUG] Action: {{action}}"
        echo "[DEBUG] Reasoning: {{reasoning}}"
        echo "{{reasoning}}" >> /tmp/agent_reasoning.log

  - name: dump_context
    description: Dump current context for debugging
    script:
      shell: |
        echo "Context dump at $(date)"
        # This tool just logs, helps you see what agent thinks context is
```

## Checklist for debugging

When your agent misbehaves:

1. **Check the input**
   - [ ] What did the user actually ask?
   - [ ] Was the request ambiguous?

2. **Check the context**
   - [ ] How big was the context?
   - [ ] Was important info included?
   - [ ] Was anything truncated?

3. **Check tool selection**
   - [ ] What tools were available?
   - [ ] Which tool did it pick?
   - [ ] Were tool descriptions clear?

4. **Check parameters**
   - [ ] Were parameters valid?
   - [ ] Did it hallucinate any values?
   - [ ] Did it use context or guess?

5. **Check results**
   - [ ] What did the tool return?
   - [ ] Did the agent understand the result?
   - [ ] Did it handle errors?

6. **Check the loop**
   - [ ] How many iterations?
   - [ ] Was it making progress?
   - [ ] Did it repeat actions?

## Summary

To debug agent thoughts:

1. **Log everything**: Input, output, tool calls, results
2. **Format for humans**: Make logs readable
3. **Look for patterns**: Wrong tools, missing context, hallucinations, loops
4. **Ask for explanations**: Make the agent think out loud
5. **Build replay tools**: Step through decisions
6. **Visualize**: Web UI for complex sessions

You can't fix what you can't see. Make the thinking visible.

---

*What's the weirdest thing you've caught an agent thinking?*
