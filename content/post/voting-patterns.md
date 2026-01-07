+++
title = "AI Agent Voting Patterns with MCP: Collective Decision Systems"
image = "images/voting-patterns.webp"
date = 2025-06-10
description = "Master AI agent voting patterns with MCP and Gantz. Learn ranked choice, weighted voting, and collective intelligence decision-making."
draft = false
tags = ['voting', 'patterns', 'ai', 'mcp', 'multi-agent', 'gantz']
voice = false

[howto]
name = "How To Implement AI Agent Voting Patterns with MCP"
totalTime = 35
[[howto.steps]]
name = "Understand voting systems"
text = "Learn collective decision fundamentals"
[[howto.steps]]
name = "Design ballot system"
text = "Build voting infrastructure"
[[howto.steps]]
name = "Implement voting methods"
text = "Create various voting algorithms"
[[howto.steps]]
name = "Add result aggregation"
text = "Aggregate and analyze results"
[[howto.steps]]
name = "Deploy with Gantz"
text = "Deploy voting system using Gantz CLI"
+++

AI agent voting patterns enable collective decision-making through various voting mechanisms, from simple majority to sophisticated ranked-choice systems.

## Why Use Voting Patterns?

Agent voting enables:

- **Democratic decisions**: Fair multi-agent input
- **Wisdom of crowds**: Aggregate diverse opinions
- **Weighted expertise**: Expert opinions count more
- **Transparent process**: Auditable decision trail
- **Conflict resolution**: Structured disagreement handling

## Voting Architecture

```yaml
# gantz.yaml
name: voting-system
version: 1.0.0

tools:
  create_ballot:
    description: "Create voting ballot"
    parameters:
      question:
        type: string
        required: true
      options:
        type: array
        required: true
      voting_method:
        type: string
        default: "simple_majority"
    handler: voting.create_ballot

  cast_vote:
    description: "Cast vote on ballot"
    parameters:
      ballot_id:
        type: string
        required: true
      agent_id:
        type: string
        required: true
      vote:
        type: object
        required: true
    handler: voting.cast_vote

  tally_votes:
    description: "Tally ballot votes"
    parameters:
      ballot_id:
        type: string
        required: true
    handler: voting.tally_votes

  weighted_vote:
    description: "Cast weighted vote"
    parameters:
      ballot_id:
        type: string
        required: true
      agent_id:
        type: string
        required: true
      vote:
        type: object
        required: true
      weight:
        type: number
    handler: voting.weighted_vote

  ranked_choice:
    description: "Cast ranked choice vote"
    parameters:
      ballot_id:
        type: string
        required: true
      agent_id:
        type: string
        required: true
      rankings:
        type: array
        required: true
    handler: voting.ranked_choice

  analyze_results:
    description: "Analyze voting results"
    parameters:
      ballot_id:
        type: string
        required: true
    handler: voting.analyze_results
```

## Handler Implementation

```python
# handlers/voting.py
from datetime import datetime
from typing import List, Dict, Any
from collections import defaultdict

# Voting state
BALLOTS = {}
VOTES = {}
AGENT_WEIGHTS = {}


async def create_ballot(question: str, options: list, voting_method: str = "simple_majority") -> dict:
    """Create voting ballot."""
    from gantz import MCPClient
    mcp = MCPClient()

    ballot_id = generate_ballot_id()

    ballot = {
        'id': ballot_id,
        'question': question,
        'options': options,
        'voting_method': voting_method,
        'status': 'open',
        'created_at': datetime.now().isoformat(),
        'closes_at': None
    }

    # AI ballot validation
    validation = mcp.execute_tool('ai_validate', {
        'type': 'ballot_validation',
        'question': question,
        'options': options,
        'validate': ['clarity', 'completeness', 'bias', 'mutual_exclusivity']
    })

    if validation.get('issues'):
        ballot['warnings'] = validation['issues']

    BALLOTS[ballot_id] = ballot
    VOTES[ballot_id] = []

    return {
        'ballot_id': ballot_id,
        'question': question,
        'options': options,
        'voting_method': voting_method,
        'status': 'open',
        'warnings': validation.get('issues', [])
    }


async def cast_vote(ballot_id: str, agent_id: str, vote: dict) -> dict:
    """Cast simple vote on ballot."""
    ballot = BALLOTS.get(ballot_id)
    if not ballot:
        return {'error': 'Ballot not found'}

    if ballot['status'] != 'open':
        return {'error': 'Ballot is closed'}

    # Validate vote
    if vote.get('choice') not in ballot['options']:
        return {'error': 'Invalid choice'}

    # Check for duplicate vote
    existing = [v for v in VOTES[ballot_id] if v['agent_id'] == agent_id]
    if existing:
        return {'error': 'Agent already voted'}

    vote_record = {
        'agent_id': agent_id,
        'choice': vote['choice'],
        'timestamp': datetime.now().isoformat(),
        'weight': 1.0
    }

    VOTES[ballot_id].append(vote_record)

    return {
        'ballot_id': ballot_id,
        'agent_id': agent_id,
        'vote_recorded': True,
        'choice': vote['choice']
    }


async def tally_votes(ballot_id: str) -> dict:
    """Tally votes and determine winner."""
    ballot = BALLOTS.get(ballot_id)
    if not ballot:
        return {'error': 'Ballot not found'}

    votes = VOTES.get(ballot_id, [])
    method = ballot['voting_method']

    if method == 'simple_majority':
        result = tally_simple_majority(votes, ballot['options'])
    elif method == 'weighted':
        result = tally_weighted(votes, ballot['options'])
    elif method == 'ranked_choice':
        result = tally_ranked_choice(votes, ballot['options'])
    elif method == 'approval':
        result = tally_approval(votes, ballot['options'])
    else:
        result = tally_simple_majority(votes, ballot['options'])

    # Close ballot
    BALLOTS[ballot_id]['status'] = 'closed'
    BALLOTS[ballot_id]['result'] = result

    return {
        'ballot_id': ballot_id,
        'question': ballot['question'],
        'voting_method': method,
        'total_votes': len(votes),
        **result
    }


async def weighted_vote(ballot_id: str, agent_id: str, vote: dict, weight: float = None) -> dict:
    """Cast weighted vote."""
    ballot = BALLOTS.get(ballot_id)
    if not ballot:
        return {'error': 'Ballot not found'}

    if ballot['voting_method'] != 'weighted':
        return {'error': 'Ballot does not support weighted voting'}

    # Get agent weight
    if weight is None:
        weight = AGENT_WEIGHTS.get(agent_id, 1.0)

    # Validate vote
    if vote.get('choice') not in ballot['options']:
        return {'error': 'Invalid choice'}

    vote_record = {
        'agent_id': agent_id,
        'choice': vote['choice'],
        'timestamp': datetime.now().isoformat(),
        'weight': weight
    }

    VOTES[ballot_id].append(vote_record)

    return {
        'ballot_id': ballot_id,
        'agent_id': agent_id,
        'vote_recorded': True,
        'choice': vote['choice'],
        'weight': weight
    }


async def ranked_choice(ballot_id: str, agent_id: str, rankings: list) -> dict:
    """Cast ranked choice vote."""
    ballot = BALLOTS.get(ballot_id)
    if not ballot:
        return {'error': 'Ballot not found'}

    # Validate rankings
    if set(rankings) != set(ballot['options']):
        return {'error': 'Rankings must include all options exactly once'}

    vote_record = {
        'agent_id': agent_id,
        'rankings': rankings,
        'timestamp': datetime.now().isoformat(),
        'weight': 1.0
    }

    VOTES[ballot_id].append(vote_record)

    return {
        'ballot_id': ballot_id,
        'agent_id': agent_id,
        'vote_recorded': True,
        'rankings': rankings
    }


async def analyze_results(ballot_id: str) -> dict:
    """Analyze voting results in detail."""
    from gantz import MCPClient
    mcp = MCPClient()

    ballot = BALLOTS.get(ballot_id)
    votes = VOTES.get(ballot_id, [])

    if not ballot:
        return {'error': 'Ballot not found'}

    # AI analysis
    analysis = mcp.execute_tool('ai_analyze', {
        'type': 'voting_analysis',
        'ballot': ballot,
        'votes': votes,
        'analyze': [
            'consensus_level',
            'polarization',
            'agent_alignment',
            'confidence',
            'alternative_outcomes'
        ]
    })

    return {
        'ballot_id': ballot_id,
        'question': ballot['question'],
        'winner': ballot.get('result', {}).get('winner'),
        'total_votes': len(votes),
        'consensus_level': analysis.get('consensus_level'),
        'polarization': analysis.get('polarization'),
        'agent_clusters': analysis.get('clusters', []),
        'confidence': analysis.get('confidence'),
        'alternative_outcomes': analysis.get('alternatives', []),
        'insights': analysis.get('insights', [])
    }


def tally_simple_majority(votes: list, options: list) -> dict:
    """Tally simple majority votes."""
    counts = defaultdict(int)
    for vote in votes:
        counts[vote['choice']] += 1

    total = len(votes)
    winner = max(counts, key=counts.get) if counts else None

    return {
        'winner': winner,
        'counts': dict(counts),
        'percentages': {k: v/total*100 for k, v in counts.items()} if total > 0 else {},
        'margin': (counts[winner] - sorted(counts.values())[-2]) if len(counts) > 1 else counts.get(winner, 0)
    }


def tally_weighted(votes: list, options: list) -> dict:
    """Tally weighted votes."""
    counts = defaultdict(float)
    for vote in votes:
        counts[vote['choice']] += vote.get('weight', 1.0)

    total_weight = sum(counts.values())
    winner = max(counts, key=counts.get) if counts else None

    return {
        'winner': winner,
        'weighted_counts': dict(counts),
        'percentages': {k: v/total_weight*100 for k, v in counts.items()} if total_weight > 0 else {},
        'total_weight': total_weight
    }


def tally_ranked_choice(votes: list, options: list) -> dict:
    """Tally ranked choice votes (instant runoff)."""
    active_votes = [{'rankings': v['rankings'][:], 'weight': 1.0} for v in votes]
    eliminated = set()
    rounds = []

    while True:
        # Count first-choice votes
        counts = defaultdict(float)
        for vote in active_votes:
            for choice in vote['rankings']:
                if choice not in eliminated:
                    counts[choice] += vote['weight']
                    break

        rounds.append(dict(counts))
        total = sum(counts.values())

        # Check for majority
        for option, count in counts.items():
            if count > total / 2:
                return {
                    'winner': option,
                    'rounds': rounds,
                    'eliminated': list(eliminated),
                    'final_count': count,
                    'final_percentage': count / total * 100
                }

        # Eliminate lowest
        if not counts:
            return {'winner': None, 'rounds': rounds}

        lowest = min(counts, key=counts.get)
        eliminated.add(lowest)

        # Update votes
        for vote in active_votes:
            vote['rankings'] = [r for r in vote['rankings'] if r not in eliminated]

        if len(set(options) - eliminated) <= 1:
            remaining = set(options) - eliminated
            winner = remaining.pop() if remaining else None
            return {
                'winner': winner,
                'rounds': rounds,
                'eliminated': list(eliminated)
            }


def tally_approval(votes: list, options: list) -> dict:
    """Tally approval votes (multiple choices allowed)."""
    counts = defaultdict(int)
    for vote in votes:
        for choice in vote.get('choices', []):
            counts[choice] += 1

    winner = max(counts, key=counts.get) if counts else None

    return {
        'winner': winner,
        'counts': dict(counts),
        'approval_rates': {k: v/len(votes)*100 for k, v in counts.items()} if votes else {}
    }
```

## Voting Method Implementations

```python
# methods/voting.py
from gantz import MCPClient

mcp = MCPClient(config_path='gantz.yaml')


class QuadraticVoting:
    """Quadratic voting - cost increases quadratically."""

    def __init__(self, agents: list, credits_per_agent: int = 100):
        self.agents = agents
        self.credits = {a: credits_per_agent for a in agents}

    async def vote(self, ballot_id: str, agent_id: str, votes: dict) -> dict:
        """Cast quadratic votes (votes cost credits^2)."""
        # Calculate cost
        total_cost = sum(v**2 for v in votes.values())

        if total_cost > self.credits[agent_id]:
            return {'error': 'Insufficient credits'}

        self.credits[agent_id] -= total_cost

        # Record votes
        for option, strength in votes.items():
            await mcp.execute_tool('weighted_vote', {
                'ballot_id': ballot_id,
                'agent_id': agent_id,
                'vote': {'choice': option},
                'weight': strength
            })

        return {
            'votes_cast': votes,
            'credits_spent': total_cost,
            'credits_remaining': self.credits[agent_id]
        }


class LiquidDemocracy:
    """Liquid democracy - delegate votes to other agents."""

    def __init__(self, agents: list):
        self.agents = agents
        self.delegations = {}

    def delegate(self, from_agent: str, to_agent: str) -> dict:
        """Delegate voting power to another agent."""
        self.delegations[from_agent] = to_agent
        return {
            'delegated': True,
            'from': from_agent,
            'to': to_agent
        }

    def get_voting_power(self, agent_id: str) -> int:
        """Calculate total voting power including delegations."""
        power = 1  # Own vote
        for delegator, delegate in self.delegations.items():
            if delegate == agent_id:
                power += self.get_voting_power(delegator)
        return power

    async def vote(self, ballot_id: str, agent_id: str, choice: str) -> dict:
        """Cast vote with delegated power."""
        power = self.get_voting_power(agent_id)

        return await mcp.execute_tool('weighted_vote', {
            'ballot_id': ballot_id,
            'agent_id': agent_id,
            'vote': {'choice': choice},
            'weight': power
        })


class CondorcetVoting:
    """Condorcet method - pairwise comparisons."""

    async def tally(self, ballot_id: str) -> dict:
        """Find Condorcet winner through pairwise comparison."""
        ballot = BALLOTS.get(ballot_id)
        votes = VOTES.get(ballot_id, [])
        options = ballot['options']

        # Build pairwise preference matrix
        pairwise = defaultdict(lambda: defaultdict(int))

        for vote in votes:
            rankings = vote['rankings']
            for i, opt_a in enumerate(rankings):
                for opt_b in rankings[i+1:]:
                    pairwise[opt_a][opt_b] += 1

        # Find Condorcet winner (beats all others in pairwise)
        for candidate in options:
            is_condorcet = True
            for opponent in options:
                if candidate != opponent:
                    if pairwise[candidate][opponent] <= pairwise[opponent][candidate]:
                        is_condorcet = False
                        break
            if is_condorcet:
                return {
                    'winner': candidate,
                    'method': 'condorcet',
                    'pairwise_matrix': dict(pairwise)
                }

        return {
            'winner': None,
            'method': 'condorcet',
            'note': 'No Condorcet winner exists (cycle detected)',
            'pairwise_matrix': dict(pairwise)
        }
```

## Deploy with Gantz CLI

```bash
# Install Gantz
npm install -g gantz

# Initialize voting system
gantz init --template voting-system

# Deploy
gantz deploy --platform kubernetes

# Create ballot
gantz run create_ballot --question "Best approach?" --options '["A", "B", "C"]' --voting-method ranked_choice

# Cast vote
gantz run cast_vote --ballot-id ballot_123 --agent-id agent1 --vote '{"choice": "A"}'

# Tally votes
gantz run tally_votes --ballot-id ballot_123

# Analyze results
gantz run analyze_results --ballot-id ballot_123
```

Build collective decision systems at [gantz.run](https://gantz.run).

## Related Reading

- [Consensus Patterns](/post/consensus-patterns/) - Agreement building
- [Collaboration Patterns](/post/collaboration-patterns/) - Agent teamwork
- [Swarm Patterns](/post/swarm-patterns/) - Collective intelligence

## Conclusion

Voting patterns enable fair, transparent collective decision-making. With various methods from simple majority to ranked choice and quadratic voting, you can implement the right mechanism for your multi-agent system.

Start building voting systems with Gantz today.
