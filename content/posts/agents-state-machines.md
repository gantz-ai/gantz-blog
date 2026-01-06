+++
title = 'Agents as State Machines'
date = 2026-01-03
draft = false
tags = ['agents', 'ai', 'mcp']
+++


Most people think of AI agents as magic black boxes.

They're not. They're state machines.

Once you see it, agent design becomes much clearer.

## What's a state machine?

A state machine is:
- A set of **states** (where you are)
- A set of **transitions** (how you move between states)
- **Events** that trigger transitions

```
┌─────────┐   button_press   ┌─────────┐
│   OFF   │ ───────────────→ │   ON    │
└─────────┘                  └─────────┘
     ↑                            │
     └────────────────────────────┘
            button_press
```

Simple. Predictable. Debuggable.

## Agents are state machines

Every agent has:
- **States**: What the agent is doing right now
- **Transitions**: How it moves between states
- **Events**: User input, tool results, errors

```
┌──────────┐   user_input   ┌──────────┐   needs_tool   ┌──────────┐
│  IDLE    │ ─────────────→ │ THINKING │ ────────────→  │ ACTING   │
└──────────┘                └──────────┘                └──────────┘
     ↑                           │                           │
     │                           │ has_answer                │ tool_result
     │                           ▼                           │
     │                      ┌──────────┐                     │
     └───────────────────── │ RESPOND  │ ←───────────────────┘
                            └──────────┘
```

The classic ReAct loop is just a state machine.

## The basic agent states

### IDLE

Waiting for input. No active task.

```python
class AgentState:
    IDLE = "idle"  # Waiting for user
```

### THINKING

Processing input. Deciding what to do.

```python
    THINKING = "thinking"  # LLM is reasoning
```

### ACTING

Executing a tool call.

```python
    ACTING = "acting"  # Tool is running
```

### OBSERVING

Processing tool results.

```python
    OBSERVING = "observing"  # Analyzing results
```

### RESPONDING

Generating final answer.

```python
    RESPONDING = "responding"  # Creating output
```

### ERROR

Something went wrong.

```python
    ERROR = "error"  # Handling failure
```

## Full state diagram

```
                              ┌─────────────────────────────────────┐
                              │                                     │
                              ▼                                     │
┌────────┐  user_input  ┌──────────┐                               │
│  IDLE  │ ───────────→ │ THINKING │ ←─────────────────────────────┤
└────────┘              └────┬─────┘                               │
     ↑                       │                                     │
     │                       ├─── needs_tool ───→ ┌─────────┐      │
     │                       │                    │ ACTING  │      │
     │                       │                    └────┬────┘      │
     │                       │                         │           │
     │                       │                    tool_result      │
     │                       │                         │           │
     │                       │                         ▼           │
     │                       │                    ┌──────────┐     │
     │                       │                    │OBSERVING │─────┘
     │                       │                    └──────────┘
     │                       │
     │                       └─── has_answer ───→ ┌───────────┐
     │                                            │ RESPONDING│
     │                                            └─────┬─────┘
     │                                                  │
     │                          done                    │
     └──────────────────────────────────────────────────┘


                    ┌─────────┐
    (any state) ───→│  ERROR  │───→ (recovery or IDLE)
                    └─────────┘
```

## Implementation

### Basic state machine

```python
from enum import Enum
from typing import Callable

class State(Enum):
    IDLE = "idle"
    THINKING = "thinking"
    ACTING = "acting"
    OBSERVING = "observing"
    RESPONDING = "responding"
    ERROR = "error"

class AgentStateMachine:
    def __init__(self):
        self.state = State.IDLE
        self.context = {}
        self.transitions = {
            State.IDLE: {
                "user_input": State.THINKING
            },
            State.THINKING: {
                "needs_tool": State.ACTING,
                "has_answer": State.RESPONDING,
                "error": State.ERROR
            },
            State.ACTING: {
                "tool_success": State.OBSERVING,
                "tool_failure": State.ERROR
            },
            State.OBSERVING: {
                "need_more": State.THINKING,
                "done": State.RESPONDING
            },
            State.RESPONDING: {
                "done": State.IDLE
            },
            State.ERROR: {
                "retry": State.THINKING,
                "abort": State.IDLE
            }
        }

    def transition(self, event: str):
        valid_transitions = self.transitions.get(self.state, {})

        if event not in valid_transitions:
            raise InvalidTransitionError(
                f"Cannot transition from {self.state} via {event}"
            )

        old_state = self.state
        self.state = valid_transitions[event]

        self.on_transition(old_state, event, self.state)

    def on_transition(self, old, event, new):
        print(f"{old.value} --[{event}]--> {new.value}")
```

### With handlers

```python
class Agent(AgentStateMachine):
    def __init__(self, llm, tools):
        super().__init__()
        self.llm = llm
        self.tools = tools

        # State handlers
        self.handlers = {
            State.THINKING: self.handle_thinking,
            State.ACTING: self.handle_acting,
            State.OBSERVING: self.handle_observing,
            State.RESPONDING: self.handle_responding,
            State.ERROR: self.handle_error
        }

    def run(self, user_input):
        self.context["input"] = user_input
        self.transition("user_input")

        while self.state != State.IDLE:
            handler = self.handlers.get(self.state)
            if handler:
                event = handler()
                self.transition(event)

        return self.context.get("response")

    def handle_thinking(self):
        result = self.llm.think(self.context)

        if result.tool_call:
            self.context["pending_tool"] = result.tool_call
            return "needs_tool"
        else:
            self.context["answer"] = result.answer
            return "has_answer"

    def handle_acting(self):
        tool_call = self.context["pending_tool"]

        try:
            result = self.tools.execute(tool_call)
            self.context["tool_result"] = result
            return "tool_success"
        except Exception as e:
            self.context["error"] = str(e)
            return "tool_failure"

    def handle_observing(self):
        result = self.context["tool_result"]
        self.context["observations"].append(result)

        # Decide if we need more info
        if self.needs_more_info():
            return "need_more"
        else:
            return "done"

    def handle_responding(self):
        self.context["response"] = self.llm.respond(self.context)
        return "done"

    def handle_error(self):
        if self.context.get("retries", 0) < 3:
            self.context["retries"] = self.context.get("retries", 0) + 1
            return "retry"
        else:
            return "abort"
```

## Why this mental model helps

### 1. Clear debugging

Know exactly where the agent is.

```python
def debug_agent(agent):
    print(f"Current state: {agent.state}")
    print(f"Context: {agent.context}")
    print(f"Valid transitions: {agent.transitions[agent.state].keys()}")
```

```
Current state: ACTING
Context: {"pending_tool": {"name": "search", "params": {...}}}
Valid transitions: ["tool_success", "tool_failure"]
```

### 2. Predictable behavior

No mystery about what happens next.

```python
# You can predict all possible paths
def get_possible_paths(state_machine, depth=5):
    paths = []

    def explore(state, path, d):
        if d == 0:
            paths.append(path)
            return

        for event, next_state in state_machine.transitions.get(state, {}).items():
            explore(next_state, path + [(event, next_state)], d - 1)

    explore(state_machine.state, [], depth)
    return paths
```

### 3. Easy testing

Test each state independently.

```python
def test_thinking_to_acting():
    agent = Agent(mock_llm, mock_tools)
    agent.state = State.THINKING
    agent.context = {"input": "search for X"}

    mock_llm.think.return_value = ToolCall("search", {"q": "X"})

    event = agent.handle_thinking()

    assert event == "needs_tool"
    assert agent.context["pending_tool"].name == "search"

def test_thinking_to_responding():
    agent = Agent(mock_llm, mock_tools)
    agent.state = State.THINKING
    agent.context = {"input": "what is 2+2"}

    mock_llm.think.return_value = Answer("4")

    event = agent.handle_thinking()

    assert event == "has_answer"
    assert agent.context["answer"] == "4"
```

### 4. Explicit error handling

Errors are just another state.

```python
def handle_error(self):
    error = self.context.get("error")

    if isinstance(error, RateLimitError):
        time.sleep(60)
        return "retry"

    if isinstance(error, ToolNotFoundError):
        self.context["fallback"] = True
        return "retry"

    if isinstance(error, FatalError):
        self.context["response"] = f"I encountered an error: {error}"
        return "abort"

    # Unknown error
    return "abort"
```

### 5. State persistence

Save and resume agents.

```python
def save_state(agent):
    return {
        "state": agent.state.value,
        "context": agent.context,
        "history": agent.history
    }

def load_state(agent, saved):
    agent.state = State(saved["state"])
    agent.context = saved["context"]
    agent.history = saved["history"]
```

## Advanced patterns

### Sub-states

States within states.

```
┌─────────────────────────────────────────┐
│              ACTING                      │
│  ┌──────────┐  ┌──────────┐  ┌───────┐  │
│  │ PREPARE  │→ │ EXECUTE  │→ │ CLEAN │  │
│  └──────────┘  └──────────┘  └───────┘  │
└─────────────────────────────────────────┘
```

```python
class ActingSubStates(Enum):
    PREPARE = "prepare"
    EXECUTE = "execute"
    CLEANUP = "cleanup"

def handle_acting(self):
    substate = ActingSubStates.PREPARE

    while True:
        if substate == ActingSubStates.PREPARE:
            self.prepare_tool_call()
            substate = ActingSubStates.EXECUTE

        elif substate == ActingSubStates.EXECUTE:
            result = self.execute_tool()
            substate = ActingSubStates.CLEANUP

        elif substate == ActingSubStates.CLEANUP:
            self.cleanup()
            break

    return "tool_success" if result.success else "tool_failure"
```

### Parallel states

Multiple things happening at once.

```
┌─────────────────────────────────────────┐
│              ACTING                      │
│                                          │
│  ┌──────────┐      ┌──────────┐         │
│  │ TOOL_A   │      │ TOOL_B   │         │
│  │ running  │      │ running  │         │
│  └──────────┘      └──────────┘         │
│         │                │               │
│         └───────┬────────┘               │
│                 ▼                        │
│           ┌──────────┐                   │
│           │  MERGE   │                   │
│           └──────────┘                   │
└─────────────────────────────────────────┘
```

```python
async def handle_acting_parallel(self):
    tool_calls = self.context["pending_tools"]

    # Run tools in parallel
    results = await asyncio.gather(*[
        self.execute_tool(tc) for tc in tool_calls
    ])

    self.context["tool_results"] = results
    return "tools_complete"
```

### History tracking

Keep track of state transitions.

```python
class AgentWithHistory(AgentStateMachine):
    def __init__(self):
        super().__init__()
        self.history = []

    def transition(self, event):
        old_state = self.state
        super().transition(event)

        self.history.append({
            "timestamp": time.time(),
            "from": old_state.value,
            "event": event,
            "to": self.state.value,
            "context_snapshot": dict(self.context)
        })

    def replay(self):
        for entry in self.history:
            print(f"[{entry['timestamp']}] "
                  f"{entry['from']} --[{entry['event']}]--> {entry['to']}")
```

## MCP integration

State machine works naturally with MCP tools via [Gantz](https://gantz.run):

```python
class MCPAgent(AgentStateMachine):
    def __init__(self, mcp_client):
        super().__init__()
        self.mcp = mcp_client

    def handle_acting(self):
        tool_call = self.context["pending_tool"]

        try:
            # Call MCP tool
            result = self.mcp.call_tool(
                tool_call.name,
                tool_call.params
            )
            self.context["tool_result"] = result
            return "tool_success"

        except MCPError as e:
            self.context["error"] = e
            return "tool_failure"
```

```yaml
# gantz.yaml
tools:
  - name: search
    description: Search for information
    script:
      shell: grep -r "{{query}}" .

  - name: write
    description: Write to file
    script:
      shell: echo "{{content}}" > "{{path}}"
```

## Common state machine bugs

### Bug 1: Missing transitions

```python
# Bad: no error handling from ACTING
State.ACTING: {
    "tool_success": State.OBSERVING
    # Missing: "tool_failure": State.ERROR
}
```

Agent gets stuck when tool fails.

### Bug 2: No exit from ERROR

```python
# Bad: error state is a dead end
State.ERROR: {
    # Nothing here!
}
```

Agent never recovers.

### Bug 3: Infinite loops

```python
# Bad: THINKING always goes to ACTING
State.THINKING: {
    "needs_tool": State.ACTING
    # Missing: "has_answer": State.RESPONDING
}
```

Agent never responds.

## Validation

Validate your state machine at startup:

```python
def validate_state_machine(transitions):
    all_states = set(transitions.keys())
    all_targets = set()

    for state, events in transitions.items():
        for target in events.values():
            all_targets.add(target)

    # Check all target states exist
    missing = all_targets - all_states
    if missing:
        raise ValueError(f"Missing states: {missing}")

    # Check IDLE is reachable from all states
    for state in all_states:
        if not can_reach(transitions, state, State.IDLE):
            raise ValueError(f"State {state} cannot reach IDLE")

    # Check no dead ends (except IDLE)
    for state in all_states:
        if state != State.IDLE and not transitions.get(state):
            raise ValueError(f"Dead end state: {state}")
```

## Summary

Agents are state machines:

```
IDLE → THINKING → ACTING → OBSERVING → RESPONDING → IDLE
           ↑         │           │
           └─────────┴───────────┘
                  (loop)
```

Benefits:
- **Predictable**: Know exactly what can happen
- **Debuggable**: See where you are, how you got there
- **Testable**: Test each state independently
- **Recoverable**: Errors are just states

Stop treating agents as magic. Start treating them as state machines.

---

*Do you model your agents as state machines? What states do you use?*
