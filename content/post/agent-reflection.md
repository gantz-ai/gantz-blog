+++
title = "AI Agent Reflection: Build Self-Improving Agents"
image = "images/agent-reflection.webp"
date = 2025-11-11
description = "Implement reflection patterns for AI agents. Enable self-critique, error correction, and continuous improvement in agent behavior and outputs."
summary = "Most agents make the same mistakes repeatedly. Reflection patterns break the cycle: after each task, have the agent critique its own output, analyze what went wrong when errors occur, and store learned insights for future reference. Build agents that get better over time instead of repeating failures. Self-improvement without retraining."
draft = false
tags = ['mcp', 'agents', 'reflection']
voice = false

[howto]
name = "Implement Agent Reflection"
totalTime = 35
[[howto.steps]]
name = "Define reflection triggers"
text = "Determine when agents should reflect."
[[howto.steps]]
name = "Implement self-critique"
text = "Enable agents to evaluate their outputs."
[[howto.steps]]
name = "Add error analysis"
text = "Analyze failures to prevent recurrence."
[[howto.steps]]
name = "Build improvement loops"
text = "Use reflection to improve future behavior."
[[howto.steps]]
name = "Store learned insights"
text = "Persist learnings for long-term improvement."
+++


AI agents make mistakes.

Good agents recognize and correct them.

That's reflection.

## What is agent reflection?

Reflection is an agent examining its own:
- **Outputs** - Was the response good?
- **Reasoning** - Was the logic sound?
- **Actions** - Were the right tools used?
- **Failures** - What went wrong?

Reflection enables self-improvement.

## Reflection patterns

```
Output → Critique → Revision → Better Output
     ↑                              ↓
     └──────── Learn ←──────────────┘
```

## Step 1: Self-critique

Using [Gantz](https://gantz.run):

```yaml
# gantz.yaml
name: reflective-agent

tools:
  - name: critique_output
    description: Critique an agent output
    parameters:
      - name: output
        type: string
        required: true
      - name: task
        type: string
        required: true
    script:
      command: python
      args: ["scripts/critique.py", "{{output}}", "{{task}}"]

  - name: revise_output
    description: Revise output based on critique
    parameters:
      - name: output
        type: string
        required: true
      - name: critique
        type: string
        required: true
    script:
      command: python
      args: ["scripts/revise.py", "{{output}}", "{{critique}}"]
```

Self-critique implementation:

```python
import anthropic
from typing import Dict, Any, List, Optional
from dataclasses import dataclass

@dataclass
class Critique:
    """Structured critique of agent output."""
    score: float  # 0-1
    strengths: List[str]
    weaknesses: List[str]
    suggestions: List[str]
    should_revise: bool

@dataclass
class ReflectionResult:
    """Result of reflection process."""
    original_output: str
    critique: Critique
    revised_output: Optional[str]
    iterations: int

class SelfCritique:
    """Enable agents to critique their own outputs."""

    def __init__(self):
        self.client = anthropic.Anthropic()

    def critique(
        self,
        output: str,
        task: str,
        criteria: List[str] = None
    ) -> Critique:
        """Critique an output against criteria."""

        default_criteria = [
            "accuracy", "completeness", "clarity",
            "relevance", "helpfulness"
        ]
        criteria = criteria or default_criteria

        prompt = f"""Critique this output for a given task.

Task: {task}

Output: {output}

Criteria to evaluate: {criteria}

Provide a structured critique:
1. Score (0-1, where 1 is perfect)
2. Strengths (what was done well)
3. Weaknesses (what needs improvement)
4. Suggestions (specific improvements)
5. Should revise (true/false)

Output as JSON:
{{
    "score": 0.8,
    "strengths": ["..."],
    "weaknesses": ["..."],
    "suggestions": ["..."],
    "should_revise": true
}}"""

        response = self.client.messages.create(
            model="claude-sonnet-4-20250514",
            max_tokens=1024,
            messages=[{"role": "user", "content": prompt}]
        )

        import json
        result = json.loads(response.content[0].text)

        return Critique(
            score=result["score"],
            strengths=result["strengths"],
            weaknesses=result["weaknesses"],
            suggestions=result["suggestions"],
            should_revise=result["should_revise"]
        )

    def revise(
        self,
        output: str,
        critique: Critique,
        task: str
    ) -> str:
        """Revise output based on critique."""

        prompt = f"""Revise this output based on the critique.

Original Task: {task}

Original Output: {output}

Critique:
- Score: {critique.score}
- Strengths: {critique.strengths}
- Weaknesses: {critique.weaknesses}
- Suggestions: {critique.suggestions}

Create an improved version that addresses the weaknesses and incorporates the suggestions while maintaining the strengths.

Provide only the revised output, no explanations."""

        response = self.client.messages.create(
            model="claude-sonnet-4-20250514",
            max_tokens=4096,
            messages=[{"role": "user", "content": prompt}]
        )

        return response.content[0].text

    def reflect_and_improve(
        self,
        output: str,
        task: str,
        max_iterations: int = 3,
        quality_threshold: float = 0.85
    ) -> ReflectionResult:
        """Iterate critique and revision until quality threshold met."""

        current_output = output
        iterations = 0

        while iterations < max_iterations:
            critique = self.critique(current_output, task)
            iterations += 1

            if critique.score >= quality_threshold or not critique.should_revise:
                return ReflectionResult(
                    original_output=output,
                    critique=critique,
                    revised_output=current_output if current_output != output else None,
                    iterations=iterations
                )

            current_output = self.revise(current_output, critique, task)

        # Final critique
        final_critique = self.critique(current_output, task)

        return ReflectionResult(
            original_output=output,
            critique=final_critique,
            revised_output=current_output,
            iterations=iterations
        )

# Usage
critic = SelfCritique()

output = "Python is a programming language."
task = "Explain Python to a beginner developer"

result = critic.reflect_and_improve(output, task)

print(f"Original: {result.original_output}")
print(f"Score: {result.critique.score}")
print(f"Iterations: {result.iterations}")
if result.revised_output:
    print(f"Revised: {result.revised_output}")
```

## Step 2: Error analysis

Analyze failures to learn from them:

```python
from typing import List, Dict, Any
from dataclasses import dataclass
from enum import Enum

class ErrorType(Enum):
    TOOL_FAILURE = "tool_failure"
    REASONING_ERROR = "reasoning_error"
    KNOWLEDGE_GAP = "knowledge_gap"
    INSTRUCTION_VIOLATION = "instruction_violation"
    HALLUCINATION = "hallucination"

@dataclass
class ErrorAnalysis:
    """Analysis of an agent error."""
    error_type: ErrorType
    description: str
    root_cause: str
    prevention_strategy: str
    severity: float  # 0-1

class ErrorAnalyzer:
    """Analyze agent errors for learning."""

    def __init__(self):
        self.client = anthropic.Anthropic()
        self.error_history: List[ErrorAnalysis] = []

    def analyze(
        self,
        task: str,
        agent_actions: List[Dict[str, Any]],
        error_message: str,
        expected_outcome: str = None
    ) -> ErrorAnalysis:
        """Analyze an error occurrence."""

        prompt = f"""Analyze this agent error.

Task: {task}

Agent Actions:
{json.dumps(agent_actions, indent=2)}

Error: {error_message}

Expected Outcome: {expected_outcome or "Not specified"}

Analyze:
1. Error Type: One of [tool_failure, reasoning_error, knowledge_gap, instruction_violation, hallucination]
2. Description: What happened
3. Root Cause: Why it happened
4. Prevention Strategy: How to prevent it
5. Severity: 0-1 scale

Output as JSON."""

        response = self.client.messages.create(
            model="claude-sonnet-4-20250514",
            max_tokens=1024,
            messages=[{"role": "user", "content": prompt}]
        )

        result = json.loads(response.content[0].text)

        analysis = ErrorAnalysis(
            error_type=ErrorType(result["error_type"]),
            description=result["description"],
            root_cause=result["root_cause"],
            prevention_strategy=result["prevention_strategy"],
            severity=result["severity"]
        )

        self.error_history.append(analysis)

        return analysis

    def get_patterns(self) -> Dict[str, Any]:
        """Identify patterns in error history."""

        if not self.error_history:
            return {"patterns": [], "recommendations": []}

        # Count error types
        type_counts = {}
        for error in self.error_history:
            type_name = error.error_type.value
            type_counts[type_name] = type_counts.get(type_name, 0) + 1

        # Find most common
        sorted_types = sorted(type_counts.items(), key=lambda x: x[1], reverse=True)

        # Generate recommendations
        recommendations = []
        for error_type, count in sorted_types[:3]:
            if count >= 2:
                relevant_errors = [e for e in self.error_history if e.error_type.value == error_type]
                strategies = list(set(e.prevention_strategy for e in relevant_errors))
                recommendations.append({
                    "error_type": error_type,
                    "frequency": count,
                    "strategies": strategies
                })

        return {
            "patterns": sorted_types,
            "recommendations": recommendations
        }

    def suggest_improvements(self) -> List[str]:
        """Suggest improvements based on error history."""

        patterns = self.get_patterns()

        if not patterns["recommendations"]:
            return ["No significant error patterns detected"]

        suggestions = []
        for rec in patterns["recommendations"]:
            suggestions.append(
                f"Reduce {rec['error_type']} errors by: {'; '.join(rec['strategies'][:2])}"
            )

        return suggestions
```

## Step 3: Reasoning reflection

Reflect on reasoning process:

```python
@dataclass
class ReasoningStep:
    """A step in the agent's reasoning."""
    step_number: int
    thought: str
    action: Optional[str]
    observation: Optional[str]

@dataclass
class ReasoningReflection:
    """Reflection on reasoning process."""
    steps_analyzed: int
    logical_errors: List[str]
    missed_considerations: List[str]
    improvements: List[str]
    overall_quality: float

class ReasoningReflector:
    """Reflect on agent reasoning processes."""

    def __init__(self):
        self.client = anthropic.Anthropic()

    def extract_reasoning(self, agent_trace: str) -> List[ReasoningStep]:
        """Extract reasoning steps from agent trace."""

        prompt = f"""Extract the reasoning steps from this agent trace.

Trace:
{agent_trace}

For each step, identify:
- Step number
- Thought (the reasoning)
- Action (if any was taken)
- Observation (result of action)

Output as JSON array of steps."""

        response = self.client.messages.create(
            model="claude-sonnet-4-20250514",
            max_tokens=2048,
            messages=[{"role": "user", "content": prompt}]
        )

        steps_data = json.loads(response.content[0].text)

        return [
            ReasoningStep(
                step_number=s["step_number"],
                thought=s["thought"],
                action=s.get("action"),
                observation=s.get("observation")
            )
            for s in steps_data
        ]

    def reflect_on_reasoning(
        self,
        task: str,
        steps: List[ReasoningStep],
        outcome: str
    ) -> ReasoningReflection:
        """Reflect on reasoning quality."""

        steps_text = "\n".join([
            f"Step {s.step_number}: {s.thought}"
            f"{f' -> Action: {s.action}' if s.action else ''}"
            f"{f' -> Observation: {s.observation}' if s.observation else ''}"
            for s in steps
        ])

        prompt = f"""Reflect on this agent's reasoning process.

Task: {task}

Reasoning Steps:
{steps_text}

Outcome: {outcome}

Analyze:
1. Logical errors in the reasoning
2. Considerations that were missed
3. How the reasoning could be improved
4. Overall quality score (0-1)

Output as JSON."""

        response = self.client.messages.create(
            model="claude-sonnet-4-20250514",
            max_tokens=1024,
            messages=[{"role": "user", "content": prompt}]
        )

        result = json.loads(response.content[0].text)

        return ReasoningReflection(
            steps_analyzed=len(steps),
            logical_errors=result.get("logical_errors", []),
            missed_considerations=result.get("missed_considerations", []),
            improvements=result.get("improvements", []),
            overall_quality=result.get("overall_quality", 0.5)
        )

    def generate_improved_reasoning(
        self,
        task: str,
        original_steps: List[ReasoningStep],
        reflection: ReasoningReflection
    ) -> str:
        """Generate improved reasoning based on reflection."""

        prompt = f"""Based on this reflection, generate improved reasoning for the task.

Task: {task}

Original reasoning had these issues:
- Logical errors: {reflection.logical_errors}
- Missed considerations: {reflection.missed_considerations}

Suggested improvements: {reflection.improvements}

Generate a better step-by-step reasoning process."""

        response = self.client.messages.create(
            model="claude-sonnet-4-20250514",
            max_tokens=2048,
            messages=[{"role": "user", "content": prompt}]
        )

        return response.content[0].text
```

## Step 4: Learning from reflection

Store and apply learnings:

```python
import json
from datetime import datetime

@dataclass
class Learning:
    """A learning from reflection."""
    id: str
    category: str
    insight: str
    context: str
    created_at: float
    applications: int = 0

class LearningStore:
    """Store and retrieve learnings from reflection."""

    def __init__(self, storage_path: str = "learnings.json"):
        self.storage_path = storage_path
        self.learnings: Dict[str, Learning] = {}
        self._load()

    def _load(self):
        """Load learnings from storage."""
        try:
            with open(self.storage_path, "r") as f:
                data = json.load(f)
                self.learnings = {
                    k: Learning(**v) for k, v in data.items()
                }
        except FileNotFoundError:
            self.learnings = {}

    def _save(self):
        """Save learnings to storage."""
        with open(self.storage_path, "w") as f:
            json.dump(
                {k: v.__dict__ for k, v in self.learnings.items()},
                f,
                indent=2
            )

    def add(self, category: str, insight: str, context: str) -> Learning:
        """Add a new learning."""
        import uuid

        learning = Learning(
            id=str(uuid.uuid4()),
            category=category,
            insight=insight,
            context=context,
            created_at=time.time()
        )

        self.learnings[learning.id] = learning
        self._save()

        return learning

    def get_relevant(self, task: str, limit: int = 5) -> List[Learning]:
        """Get learnings relevant to a task."""

        # Simple keyword matching (could use embeddings)
        task_words = set(task.lower().split())

        scored = []
        for learning in self.learnings.values():
            context_words = set(learning.context.lower().split())
            insight_words = set(learning.insight.lower().split())

            overlap = len(task_words & (context_words | insight_words))
            if overlap > 0:
                scored.append((learning, overlap))

        scored.sort(key=lambda x: x[1], reverse=True)

        return [l for l, _ in scored[:limit]]

    def apply(self, learning_id: str):
        """Mark a learning as applied."""
        if learning_id in self.learnings:
            self.learnings[learning_id].applications += 1
            self._save()

class ReflectiveLearner:
    """Agent that learns from reflection."""

    def __init__(self):
        self.client = anthropic.Anthropic()
        self.critic = SelfCritique()
        self.error_analyzer = ErrorAnalyzer()
        self.learning_store = LearningStore()

    def run_with_reflection(
        self,
        task: str,
        mcp_url: str = None,
        mcp_token: str = None
    ) -> Dict[str, Any]:
        """Run task with reflection and learning."""

        # Get relevant learnings
        learnings = self.learning_store.get_relevant(task)

        # Build context with learnings
        learning_context = ""
        if learnings:
            learning_context = "\n\nRelevant learnings from past experience:\n"
            for l in learnings:
                learning_context += f"- {l.insight}\n"

        # Initial execution
        messages = [{"role": "user", "content": task + learning_context}]

        response = self.client.messages.create(
            model="claude-sonnet-4-20250514",
            max_tokens=4096,
            messages=messages
        )

        initial_output = response.content[0].text

        # Reflect on output
        reflection = self.critic.reflect_and_improve(initial_output, task)

        # Store new learnings
        if reflection.critique.weaknesses:
            for weakness in reflection.critique.weaknesses:
                self.learning_store.add(
                    category="weakness",
                    insight=f"Avoid: {weakness}",
                    context=task
                )

        if reflection.critique.suggestions:
            for suggestion in reflection.critique.suggestions:
                self.learning_store.add(
                    category="improvement",
                    insight=suggestion,
                    context=task
                )

        # Mark applied learnings
        for learning in learnings:
            self.learning_store.apply(learning.id)

        return {
            "task": task,
            "initial_output": initial_output,
            "final_output": reflection.revised_output or initial_output,
            "reflection": {
                "score": reflection.critique.score,
                "iterations": reflection.iterations,
                "improvements": reflection.critique.suggestions
            },
            "learnings_applied": len(learnings),
            "learnings_created": len(reflection.critique.weaknesses) + len(reflection.critique.suggestions)
        }

# Usage
learner = ReflectiveLearner()

result = learner.run_with_reflection(
    "Write a function to parse CSV files in Python"
)

print(f"Initial score: {result['reflection']['score']}")
print(f"Learnings applied: {result['learnings_applied']}")
print(f"New learnings: {result['learnings_created']}")
```

## Step 5: Continuous improvement

Build agents that improve over time:

```python
class ContinuouslyImprovingAgent:
    """Agent that continuously improves through reflection."""

    def __init__(self):
        self.learner = ReflectiveLearner()
        self.metrics: List[Dict[str, Any]] = []

    def run(self, task: str) -> str:
        """Run task and record metrics."""

        start = time.time()
        result = self.learner.run_with_reflection(task)
        duration = time.time() - start

        # Record metrics
        self.metrics.append({
            "timestamp": time.time(),
            "task": task[:50],
            "score": result["reflection"]["score"],
            "iterations": result["reflection"]["iterations"],
            "duration": duration
        })

        return result["final_output"]

    def get_improvement_trend(self) -> Dict[str, Any]:
        """Analyze improvement over time."""

        if len(self.metrics) < 5:
            return {"trend": "insufficient_data"}

        # Calculate moving average of scores
        recent = self.metrics[-10:]
        older = self.metrics[:-10] if len(self.metrics) > 10 else self.metrics[:5]

        recent_avg = sum(m["score"] for m in recent) / len(recent)
        older_avg = sum(m["score"] for m in older) / len(older)

        improvement = recent_avg - older_avg

        return {
            "recent_avg_score": recent_avg,
            "older_avg_score": older_avg,
            "improvement": improvement,
            "trend": "improving" if improvement > 0.05 else "stable" if improvement > -0.05 else "declining"
        }
```

## Summary

Agent reflection patterns:

1. **Self-critique** - Evaluate own outputs
2. **Error analysis** - Learn from failures
3. **Reasoning reflection** - Examine thought process
4. **Learning storage** - Persist insights
5. **Continuous improvement** - Track progress

Build tools with [Gantz](https://gantz.run), reflect and improve.

Good agents learn. Great agents reflect.

## Related reading

- [Human in the Loop](/post/human-in-the-loop/) - Human feedback
- [Agent Evaluation](/post/agent-evaluation/) - Measure quality
- [Prompt Chaining](/post/prompt-chaining/) - Chain reflections

---

*How do you implement agent reflection? Share your patterns.*
