+++
title = "AI Agent Evaluation: Measure Quality Systematically"
image = "images/agent-evaluation.webp"
date = 2025-11-09
description = "Evaluate AI agents systematically. Build evaluation frameworks, define metrics, create benchmarks, and continuously measure agent quality with MCP."
summary = "Measure agent quality systematically with evaluation frameworks. Define criteria (correctness, completeness, safety), create test datasets, implement LLM-as-judge scoring, build benchmarks, and set up continuous monitoring."
draft = false
tags = ['mcp', 'testing', 'evaluation']
voice = false

[howto]
name = "Evaluate AI Agents"
totalTime = 40
[[howto.steps]]
name = "Define evaluation criteria"
text = "Establish what quality means for your agent."
[[howto.steps]]
name = "Create evaluation datasets"
text = "Build representative test cases."
[[howto.steps]]
name = "Implement automated evaluation"
text = "Use LLMs to grade agent outputs."
[[howto.steps]]
name = "Build benchmarks"
text = "Create reproducible performance tests."
[[howto.steps]]
name = "Set up continuous evaluation"
text = "Monitor quality over time."
+++


How good is your agent?

"It works" isn't an answer.

Measure quality systematically.

## Why evaluate agents?

Evaluation answers critical questions:
- Is the agent improving or degrading?
- Which changes helped or hurt?
- Where does the agent struggle?
- Is it ready for production?
- How does it compare to alternatives?

Without evaluation, you're guessing.

## Evaluation dimensions

```text
┌─────────────────────────────────────────┐
│            Agent Quality                │
├─────────────────────────────────────────┤
│  Correctness  │  Does it give right answers?     │
│  Helpfulness  │  Does it solve the problem?      │
│  Safety       │  Does it avoid harmful outputs?  │
│  Efficiency   │  Does it use resources well?     │
│  Reliability  │  Does it work consistently?      │
│  Latency      │  How fast is it?                 │
└─────────────────────────────────────────┘
```

## Step 1: Define criteria

Using [Gantz](https://gantz.run):

```yaml
# gantz.yaml
name: evaluation-tools

tools:
  - name: evaluate_response
    description: Evaluate an agent response
    parameters:
      - name: task
        type: string
        required: true
      - name: response
        type: string
        required: true
      - name: criteria
        type: array
        required: true
    script:
      command: python
      args: ["scripts/evaluate.py"]

  - name: run_benchmark
    description: Run evaluation benchmark
    parameters:
      - name: benchmark_name
        type: string
        required: true
      - name: agent_config
        type: object
        required: true
    script:
      command: python
      args: ["scripts/benchmark.py"]
```

Criteria definition:

```python
from typing import List, Dict, Any, Optional
from dataclasses import dataclass
from enum import Enum

class EvaluationDimension(Enum):
    CORRECTNESS = "correctness"
    HELPFULNESS = "helpfulness"
    SAFETY = "safety"
    COHERENCE = "coherence"
    RELEVANCE = "relevance"
    COMPLETENESS = "completeness"

@dataclass
class EvaluationCriterion:
    """A single evaluation criterion."""
    dimension: EvaluationDimension
    name: str
    description: str
    weight: float = 1.0
    scoring_guide: str = ""

@dataclass
class EvaluationSpec:
    """Specification for evaluation."""
    name: str
    criteria: List[EvaluationCriterion]
    passing_threshold: float = 0.7

    def get_criteria_names(self) -> List[str]:
        return [c.name for c in self.criteria]

    def get_total_weight(self) -> float:
        return sum(c.weight for c in self.criteria)

# Standard evaluation specs
GENERAL_EVALUATION = EvaluationSpec(
    name="general",
    criteria=[
        EvaluationCriterion(
            dimension=EvaluationDimension.CORRECTNESS,
            name="factual_accuracy",
            description="Response contains accurate information",
            weight=2.0,
            scoring_guide="1=Many errors, 3=Minor errors, 5=Fully accurate"
        ),
        EvaluationCriterion(
            dimension=EvaluationDimension.HELPFULNESS,
            name="task_completion",
            description="Response addresses the user's request",
            weight=2.0,
            scoring_guide="1=Doesn't address, 3=Partially, 5=Fully addresses"
        ),
        EvaluationCriterion(
            dimension=EvaluationDimension.COHERENCE,
            name="clarity",
            description="Response is clear and well-organized",
            weight=1.0,
            scoring_guide="1=Confusing, 3=Acceptable, 5=Crystal clear"
        ),
        EvaluationCriterion(
            dimension=EvaluationDimension.SAFETY,
            name="safety",
            description="Response avoids harmful content",
            weight=3.0,
            scoring_guide="1=Harmful, 3=Some concerns, 5=Completely safe"
        ),
    ],
    passing_threshold=0.75
)

CODE_EVALUATION = EvaluationSpec(
    name="code",
    criteria=[
        EvaluationCriterion(
            dimension=EvaluationDimension.CORRECTNESS,
            name="code_correctness",
            description="Code runs without errors",
            weight=3.0
        ),
        EvaluationCriterion(
            dimension=EvaluationDimension.CORRECTNESS,
            name="output_correctness",
            description="Code produces expected output",
            weight=3.0
        ),
        EvaluationCriterion(
            dimension=EvaluationDimension.COMPLETENESS,
            name="requirements_met",
            description="All requirements are addressed",
            weight=2.0
        ),
        EvaluationCriterion(
            dimension=EvaluationDimension.COHERENCE,
            name="code_quality",
            description="Code is clean and readable",
            weight=1.0
        ),
    ]
)
```

## Step 2: Evaluation datasets

Create test cases:

```python
from typing import List, Optional
from dataclasses import dataclass
import json

@dataclass
class EvaluationCase:
    """A single evaluation test case."""
    id: str
    task: str
    expected_output: Optional[str] = None
    expected_patterns: Optional[List[str]] = None
    forbidden_patterns: Optional[List[str]] = None
    metadata: Optional[Dict[str, Any]] = None

@dataclass
class EvaluationDataset:
    """Collection of evaluation cases."""
    name: str
    description: str
    cases: List[EvaluationCase]
    eval_spec: EvaluationSpec

    def __len__(self):
        return len(self.cases)

    def save(self, path: str):
        """Save dataset to file."""
        data = {
            "name": self.name,
            "description": self.description,
            "eval_spec": self.eval_spec.name,
            "cases": [
                {
                    "id": c.id,
                    "task": c.task,
                    "expected_output": c.expected_output,
                    "expected_patterns": c.expected_patterns,
                    "forbidden_patterns": c.forbidden_patterns,
                    "metadata": c.metadata
                }
                for c in self.cases
            ]
        }
        with open(path, "w") as f:
            json.dump(data, f, indent=2)

    @classmethod
    def load(cls, path: str, eval_spec: EvaluationSpec) -> 'EvaluationDataset':
        """Load dataset from file."""
        with open(path) as f:
            data = json.load(f)

        cases = [
            EvaluationCase(**case)
            for case in data["cases"]
        ]

        return cls(
            name=data["name"],
            description=data["description"],
            cases=cases,
            eval_spec=eval_spec
        )

# Create evaluation datasets
QA_DATASET = EvaluationDataset(
    name="qa_evaluation",
    description="Question answering evaluation",
    eval_spec=GENERAL_EVALUATION,
    cases=[
        EvaluationCase(
            id="qa_001",
            task="What is the capital of France?",
            expected_output="Paris",
            expected_patterns=["Paris", "capital"],
            forbidden_patterns=["London", "Berlin"]
        ),
        EvaluationCase(
            id="qa_002",
            task="Explain photosynthesis in one sentence.",
            expected_patterns=["plant", "sunlight", "energy", "carbon dioxide"],
            forbidden_patterns=[]
        ),
        EvaluationCase(
            id="qa_003",
            task="What is 15% of 200?",
            expected_output="30",
            expected_patterns=["30"]
        ),
    ]
)

CODING_DATASET = EvaluationDataset(
    name="coding_evaluation",
    description="Code generation evaluation",
    eval_spec=CODE_EVALUATION,
    cases=[
        EvaluationCase(
            id="code_001",
            task="Write a Python function to check if a number is prime",
            expected_patterns=["def ", "return ", "for ", "True", "False"],
            metadata={"test_inputs": [2, 3, 4, 17, 100], "expected_outputs": [True, True, False, True, False]}
        ),
        EvaluationCase(
            id="code_002",
            task="Write a function to reverse a string",
            expected_patterns=["def ", "return"],
            metadata={"test_inputs": ["hello", ""], "expected_outputs": ["olleh", ""]}
        ),
    ]
)
```

## Step 3: Automated evaluation

Use LLMs to evaluate:

```python
import anthropic
from typing import Dict, Any, List
from dataclasses import dataclass

@dataclass
class EvaluationResult:
    """Result of evaluating one case."""
    case_id: str
    scores: Dict[str, float]
    overall_score: float
    passed: bool
    feedback: str
    raw_evaluation: str

class LLMEvaluator:
    """Use LLM to evaluate agent outputs."""

    def __init__(self, model: str = "claude-sonnet-4-20250514"):
        self.client = anthropic.Anthropic()
        self.model = model

    def evaluate(
        self,
        case: EvaluationCase,
        response: str,
        spec: EvaluationSpec
    ) -> EvaluationResult:
        """Evaluate a single response."""

        # Build evaluation prompt
        criteria_text = "\n".join([
            f"- {c.name}: {c.description} (weight: {c.weight})\n  Scoring: {c.scoring_guide}"
            for c in spec.criteria
        ])

        prompt = f"""Evaluate this AI response against the given criteria.

TASK: {case.task}

RESPONSE: {response}

EXPECTED (if any): {case.expected_output or 'Not specified'}

CRITERIA:
{criteria_text}

For each criterion, provide a score from 1-5 and brief justification.
Then calculate the weighted average score.

Output as JSON:
{{
    "scores": {{
        "criterion_name": {{"score": X, "justification": "..."}}
    }},
    "overall_score": X.XX,
    "passed": true/false,
    "feedback": "summary of evaluation"
}}"""

        eval_response = self.client.messages.create(
            model=self.model,
            max_tokens=1024,
            messages=[{"role": "user", "content": prompt}]
        )

        raw = eval_response.content[0].text

        try:
            result = json.loads(raw)
        except:
            # Try to extract JSON
            import re
            match = re.search(r'\{[\s\S]*\}', raw)
            if match:
                result = json.loads(match.group())
            else:
                result = {
                    "scores": {},
                    "overall_score": 0,
                    "passed": False,
                    "feedback": "Failed to parse evaluation"
                }

        # Calculate weighted score
        total_weight = spec.get_total_weight()
        weighted_sum = 0

        for criterion in spec.criteria:
            if criterion.name in result["scores"]:
                score = result["scores"][criterion.name]["score"]
                weighted_sum += score * criterion.weight

        overall = weighted_sum / total_weight / 5  # Normalize to 0-1

        return EvaluationResult(
            case_id=case.id,
            scores={k: v["score"] for k, v in result["scores"].items()},
            overall_score=overall,
            passed=overall >= spec.passing_threshold,
            feedback=result.get("feedback", ""),
            raw_evaluation=raw
        )

    def evaluate_batch(
        self,
        dataset: EvaluationDataset,
        responses: Dict[str, str]
    ) -> List[EvaluationResult]:
        """Evaluate multiple responses."""

        results = []

        for case in dataset.cases:
            if case.id in responses:
                result = self.evaluate(case, responses[case.id], dataset.eval_spec)
                results.append(result)

        return results

# Pattern-based evaluation (faster, for simple checks)
class PatternEvaluator:
    """Fast pattern-based evaluation."""

    def evaluate(self, case: EvaluationCase, response: str) -> Dict[str, Any]:
        """Check patterns in response."""

        results = {
            "expected_found": [],
            "expected_missing": [],
            "forbidden_found": [],
            "pattern_score": 0
        }

        # Check expected patterns
        if case.expected_patterns:
            for pattern in case.expected_patterns:
                if pattern.lower() in response.lower():
                    results["expected_found"].append(pattern)
                else:
                    results["expected_missing"].append(pattern)

        # Check forbidden patterns
        if case.forbidden_patterns:
            for pattern in case.forbidden_patterns:
                if pattern.lower() in response.lower():
                    results["forbidden_found"].append(pattern)

        # Calculate score
        expected_score = len(results["expected_found"]) / len(case.expected_patterns) if case.expected_patterns else 1
        forbidden_penalty = len(results["forbidden_found"]) * 0.2
        results["pattern_score"] = max(0, expected_score - forbidden_penalty)

        return results

# Code execution evaluator
class CodeEvaluator:
    """Evaluate code by execution."""

    def evaluate(self, case: EvaluationCase, code: str) -> Dict[str, Any]:
        """Execute code and check results."""

        results = {
            "syntax_valid": False,
            "runs_without_error": False,
            "outputs_correct": False,
            "test_results": []
        }

        # Check syntax
        try:
            compile(code, '<string>', 'exec')
            results["syntax_valid"] = True
        except SyntaxError as e:
            results["error"] = str(e)
            return results

        # Execute
        try:
            local_vars = {}
            exec(code, {}, local_vars)
            results["runs_without_error"] = True

            # Run tests if provided
            if case.metadata and "test_inputs" in case.metadata:
                func_name = None
                for name, obj in local_vars.items():
                    if callable(obj):
                        func_name = name
                        break

                if func_name:
                    func = local_vars[func_name]
                    inputs = case.metadata["test_inputs"]
                    expected = case.metadata["expected_outputs"]

                    for inp, exp in zip(inputs, expected):
                        try:
                            actual = func(inp)
                            passed = actual == exp
                            results["test_results"].append({
                                "input": inp,
                                "expected": exp,
                                "actual": actual,
                                "passed": passed
                            })
                        except Exception as e:
                            results["test_results"].append({
                                "input": inp,
                                "error": str(e),
                                "passed": False
                            })

                    results["outputs_correct"] = all(
                        r["passed"] for r in results["test_results"]
                    )

        except Exception as e:
            results["error"] = str(e)

        return results
```

## Step 4: Benchmarking

Create reproducible benchmarks:

```python
import time
from typing import List, Dict, Any, Callable
from dataclasses import dataclass

@dataclass
class BenchmarkConfig:
    """Configuration for a benchmark run."""
    name: str
    dataset: EvaluationDataset
    agent_func: Callable[[str], str]
    num_runs: int = 1
    timeout_seconds: float = 60

@dataclass
class BenchmarkResult:
    """Results from a benchmark run."""
    config_name: str
    timestamp: float
    num_cases: int
    num_passed: int
    pass_rate: float
    avg_score: float
    avg_latency_ms: float
    total_tokens: int
    per_case_results: List[EvaluationResult]
    errors: List[Dict[str, Any]]

class Benchmark:
    """Run evaluation benchmarks."""

    def __init__(self):
        self.evaluator = LLMEvaluator()
        self.results_history: List[BenchmarkResult] = []

    def run(self, config: BenchmarkConfig) -> BenchmarkResult:
        """Run a complete benchmark."""

        responses = {}
        latencies = []
        errors = []
        total_tokens = 0

        # Generate responses
        for case in config.dataset.cases:
            start = time.time()

            try:
                response = config.agent_func(case.task)
                responses[case.id] = response
                latencies.append((time.time() - start) * 1000)
            except Exception as e:
                errors.append({
                    "case_id": case.id,
                    "error": str(e)
                })

        # Evaluate responses
        eval_results = self.evaluator.evaluate_batch(
            config.dataset,
            responses
        )

        # Calculate metrics
        num_passed = sum(1 for r in eval_results if r.passed)
        pass_rate = num_passed / len(config.dataset) if len(config.dataset) > 0 else 0
        avg_score = sum(r.overall_score for r in eval_results) / len(eval_results) if eval_results else 0
        avg_latency = sum(latencies) / len(latencies) if latencies else 0

        result = BenchmarkResult(
            config_name=config.name,
            timestamp=time.time(),
            num_cases=len(config.dataset),
            num_passed=num_passed,
            pass_rate=pass_rate,
            avg_score=avg_score,
            avg_latency_ms=avg_latency,
            total_tokens=total_tokens,
            per_case_results=eval_results,
            errors=errors
        )

        self.results_history.append(result)

        return result

    def compare(self, results: List[BenchmarkResult]) -> Dict[str, Any]:
        """Compare multiple benchmark results."""

        comparison = {
            "results": [],
            "best_by_score": None,
            "best_by_latency": None
        }

        for r in results:
            comparison["results"].append({
                "name": r.config_name,
                "pass_rate": r.pass_rate,
                "avg_score": r.avg_score,
                "avg_latency_ms": r.avg_latency_ms
            })

        # Find best
        if results:
            comparison["best_by_score"] = max(results, key=lambda r: r.avg_score).config_name
            comparison["best_by_latency"] = min(results, key=lambda r: r.avg_latency_ms).config_name

        return comparison

# Usage
def run_agent(task: str) -> str:
    client = anthropic.Anthropic()
    response = client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=1024,
        messages=[{"role": "user", "content": task}]
    )
    return response.content[0].text

benchmark = Benchmark()

result = benchmark.run(BenchmarkConfig(
    name="qa_benchmark_v1",
    dataset=QA_DATASET,
    agent_func=run_agent
))

print(f"Pass rate: {result.pass_rate:.1%}")
print(f"Average score: {result.avg_score:.2f}")
print(f"Average latency: {result.avg_latency_ms:.0f}ms")
```

## Step 5: Continuous evaluation

Monitor quality over time:

```python
from prometheus_client import Gauge, Histogram, Counter
import schedule
import threading

# Metrics
eval_score_gauge = Gauge(
    'agent_evaluation_score',
    'Latest evaluation score',
    ['benchmark', 'dimension']
)

eval_pass_rate_gauge = Gauge(
    'agent_pass_rate',
    'Evaluation pass rate',
    ['benchmark']
)

eval_latency_histogram = Histogram(
    'agent_evaluation_latency_ms',
    'Evaluation latency',
    buckets=[100, 500, 1000, 2000, 5000, 10000]
)

class ContinuousEvaluator:
    """Run evaluations continuously."""

    def __init__(self, benchmark: Benchmark):
        self.benchmark = benchmark
        self.configs: Dict[str, BenchmarkConfig] = {}
        self.running = False

    def register_benchmark(self, config: BenchmarkConfig):
        """Register a benchmark to run."""
        self.configs[config.name] = config

    def run_all(self):
        """Run all registered benchmarks."""

        for name, config in self.configs.items():
            result = self.benchmark.run(config)

            # Update metrics
            eval_pass_rate_gauge.labels(benchmark=name).set(result.pass_rate)

            for case_result in result.per_case_results:
                for dim, score in case_result.scores.items():
                    eval_score_gauge.labels(benchmark=name, dimension=dim).set(score)

            eval_latency_histogram.observe(result.avg_latency_ms)

            # Log results
            print(f"Benchmark {name}: {result.pass_rate:.1%} pass rate, {result.avg_score:.2f} avg score")

    def start_scheduled(self, interval_hours: int = 1):
        """Start scheduled evaluation."""

        schedule.every(interval_hours).hours.do(self.run_all)

        self.running = True

        def run_scheduler():
            while self.running:
                schedule.run_pending()
                time.sleep(60)

        thread = threading.Thread(target=run_scheduler, daemon=True)
        thread.start()

    def stop(self):
        """Stop scheduled evaluation."""
        self.running = False

class EvaluationDashboard:
    """Dashboard for evaluation results."""

    def __init__(self, benchmark: Benchmark):
        self.benchmark = benchmark

    def get_trend(self, benchmark_name: str, days: int = 7) -> Dict[str, Any]:
        """Get evaluation trend over time."""

        cutoff = time.time() - (days * 86400)

        relevant = [
            r for r in self.benchmark.results_history
            if r.config_name == benchmark_name and r.timestamp > cutoff
        ]

        if not relevant:
            return {"trend": "no_data"}

        scores = [r.avg_score for r in relevant]
        pass_rates = [r.pass_rate for r in relevant]

        return {
            "benchmark": benchmark_name,
            "num_runs": len(relevant),
            "avg_score": sum(scores) / len(scores),
            "score_trend": scores[-1] - scores[0] if len(scores) > 1 else 0,
            "avg_pass_rate": sum(pass_rates) / len(pass_rates),
            "pass_rate_trend": pass_rates[-1] - pass_rates[0] if len(pass_rates) > 1 else 0,
            "latest_timestamp": relevant[-1].timestamp
        }

    def get_failure_analysis(self, benchmark_name: str) -> Dict[str, Any]:
        """Analyze common failure patterns."""

        relevant = [
            r for r in self.benchmark.results_history
            if r.config_name == benchmark_name
        ]

        failed_cases = {}
        for result in relevant:
            for case_result in result.per_case_results:
                if not case_result.passed:
                    case_id = case_result.case_id
                    if case_id not in failed_cases:
                        failed_cases[case_id] = {
                            "failures": 0,
                            "scores": [],
                            "feedback": []
                        }
                    failed_cases[case_id]["failures"] += 1
                    failed_cases[case_id]["scores"].append(case_result.overall_score)
                    failed_cases[case_id]["feedback"].append(case_result.feedback)

        # Sort by failure count
        sorted_failures = sorted(
            failed_cases.items(),
            key=lambda x: x[1]["failures"],
            reverse=True
        )

        return {
            "total_failure_types": len(failed_cases),
            "top_failures": [
                {
                    "case_id": case_id,
                    "failure_count": data["failures"],
                    "avg_score": sum(data["scores"]) / len(data["scores"]),
                    "sample_feedback": data["feedback"][-1] if data["feedback"] else None
                }
                for case_id, data in sorted_failures[:10]
            ]
        }

# Usage
continuous = ContinuousEvaluator(benchmark)
continuous.register_benchmark(BenchmarkConfig(
    name="hourly_qa_check",
    dataset=QA_DATASET,
    agent_func=run_agent
))

continuous.start_scheduled(interval_hours=1)

# Dashboard
dashboard = EvaluationDashboard(benchmark)
trend = dashboard.get_trend("hourly_qa_check", days=7)
failures = dashboard.get_failure_analysis("hourly_qa_check")
```

## Summary

AI agent evaluation:

1. **Define criteria** - What quality means
2. **Create datasets** - Representative test cases
3. **Automate evaluation** - LLM and pattern-based
4. **Build benchmarks** - Reproducible tests
5. **Monitor continuously** - Track over time

Build tools with [Gantz](https://gantz.run), measure quality.

What gets measured gets improved.

## Related reading

- [Agent Testing](/post/agent-testing/) - Test strategies
- [Agent Observability](/post/agent-observability/) - Monitor agents
- [Agent Reflection](/post/agent-reflection/) - Self-improvement

---

*How do you evaluate your AI agents? Share your metrics.*
