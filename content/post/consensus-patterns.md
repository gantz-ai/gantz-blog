+++
title = "AI Agent Consensus Patterns with MCP: Distributed Agreement"
image = "images/consensus-patterns.webp"
date = 2025-06-11
description = "Master AI agent consensus patterns with MCP and Gantz. Learn distributed agreement, conflict resolution, and collective decision-making."
summary = "When multiple agents need to agree on something, how do you reach consensus? Build proposal mechanisms where agents suggest actions, voting systems that weigh expertise and confidence, conflict resolution for when agents disagree, and quorum rules for when you need majority approval. Distributed decision-making that produces consistent outcomes."
draft = false
tags = ['consensus', 'patterns', 'ai', 'mcp', 'multi-agent', 'gantz']
voice = false

[howto]
name = "How To Implement AI Agent Consensus Patterns with MCP"
totalTime = 40
[[howto.steps]]
name = "Understand consensus models"
text = "Learn distributed agreement fundamentals"
[[howto.steps]]
name = "Design proposal mechanism"
text = "Build consensus proposal system"
[[howto.steps]]
name = "Implement voting logic"
text = "Create agent voting mechanisms"
[[howto.steps]]
name = "Add conflict resolution"
text = "Handle disagreements gracefully"
[[howto.steps]]
name = "Deploy with Gantz"
text = "Deploy consensus system using Gantz CLI"
+++

AI agent consensus patterns enable multiple agents to reach agreement on decisions, data, or actions through structured negotiation and voting.

## Why Use Consensus Patterns?

Agent consensus enables:

- **Reliable decisions**: Multi-agent verification
- **Fault tolerance**: Survive individual failures
- **Trust**: Distributed validation
- **Quality**: Aggregate diverse perspectives
- **Coordination**: Aligned multi-agent action

## Consensus Architecture

```yaml
# gantz.yaml
name: consensus-system
version: 1.0.0

tools:
  propose:
    description: "Submit consensus proposal"
    parameters:
      proposal:
        type: object
        required: true
      quorum:
        type: number
        default: 0.66
    handler: consensus.propose

  vote:
    description: "Vote on proposal"
    parameters:
      proposal_id:
        type: string
        required: true
      agent_id:
        type: string
        required: true
      vote:
        type: string
        required: true
    handler: consensus.vote

  check_consensus:
    description: "Check consensus status"
    parameters:
      proposal_id:
        type: string
        required: true
    handler: consensus.check_consensus

  resolve_conflict:
    description: "Resolve voting conflict"
    parameters:
      proposal_id:
        type: string
        required: true
    handler: consensus.resolve_conflict

  execute_decision:
    description: "Execute consensus decision"
    parameters:
      proposal_id:
        type: string
        required: true
    handler: consensus.execute_decision

  consensus_history:
    description: "Get consensus history"
    parameters:
      filter:
        type: object
    handler: consensus.consensus_history
```

## Handler Implementation

```python
# handlers/consensus.py
import asyncio
from datetime import datetime, timedelta
from typing import List, Dict, Any

# Consensus state
PROPOSALS = {}
VOTES = {}
AGENT_POOL = []


async def propose(proposal: dict, quorum: float = 0.66) -> dict:
    """Submit consensus proposal."""
    from gantz import MCPClient
    mcp = MCPClient()

    proposal_id = generate_proposal_id()

    # AI proposal analysis
    analysis = mcp.execute_tool('ai_analyze', {
        'type': 'proposal_analysis',
        'proposal': proposal,
        'analyze': ['clarity', 'implications', 'risks', 'alternatives']
    })

    proposal_record = {
        'id': proposal_id,
        'content': proposal,
        'proposer': proposal.get('proposer'),
        'quorum': quorum,
        'threshold': quorum * len(AGENT_POOL),
        'status': 'pending',
        'created_at': datetime.now().isoformat(),
        'expires_at': (datetime.now() + timedelta(hours=24)).isoformat(),
        'analysis': analysis
    }

    PROPOSALS[proposal_id] = proposal_record
    VOTES[proposal_id] = {'for': [], 'against': [], 'abstain': []}

    # Notify all agents
    for agent in AGENT_POOL:
        await notify_agent(agent, {
            'type': 'new_proposal',
            'proposal_id': proposal_id,
            'summary': analysis.get('summary'),
            'deadline': proposal_record['expires_at']
        })

    return {
        'proposal_id': proposal_id,
        'status': 'pending',
        'quorum_required': quorum,
        'agents_to_vote': len(AGENT_POOL),
        'expires_at': proposal_record['expires_at']
    }


async def vote(proposal_id: str, agent_id: str, vote: str) -> dict:
    """Cast vote on proposal."""
    from gantz import MCPClient
    mcp = MCPClient()

    proposal = PROPOSALS.get(proposal_id)
    if not proposal:
        return {'error': 'Proposal not found'}

    if proposal['status'] != 'pending':
        return {'error': f'Proposal is {proposal["status"]}'}

    # Validate vote
    if vote not in ['for', 'against', 'abstain']:
        return {'error': 'Invalid vote option'}

    # Check if already voted
    all_votes = VOTES[proposal_id]
    for vote_type in ['for', 'against', 'abstain']:
        if agent_id in [v['agent_id'] for v in all_votes[vote_type]]:
            return {'error': 'Agent already voted'}

    # Record vote with reasoning
    vote_record = {
        'agent_id': agent_id,
        'vote': vote,
        'timestamp': datetime.now().isoformat()
    }

    # AI reasoning generation
    reasoning = mcp.execute_tool('ai_generate', {
        'type': 'vote_reasoning',
        'proposal': proposal['content'],
        'vote': vote,
        'agent': agent_id
    })
    vote_record['reasoning'] = reasoning.get('reasoning')

    VOTES[proposal_id][vote].append(vote_record)

    # Check if consensus reached
    result = await check_consensus(proposal_id)

    return {
        'proposal_id': proposal_id,
        'agent_id': agent_id,
        'vote': vote,
        'recorded': True,
        'current_status': result
    }


async def check_consensus(proposal_id: str) -> dict:
    """Check consensus status."""
    proposal = PROPOSALS.get(proposal_id)
    if not proposal:
        return {'error': 'Proposal not found'}

    votes = VOTES[proposal_id]

    total_votes = len(votes['for']) + len(votes['against']) + len(votes['abstain'])
    participating_votes = len(votes['for']) + len(votes['against'])

    # Calculate percentages
    for_percent = len(votes['for']) / len(AGENT_POOL) if AGENT_POOL else 0
    against_percent = len(votes['against']) / len(AGENT_POOL) if AGENT_POOL else 0

    quorum = proposal['quorum']

    # Determine status
    if for_percent >= quorum:
        status = 'approved'
        PROPOSALS[proposal_id]['status'] = 'approved'
    elif against_percent > (1 - quorum):
        status = 'rejected'
        PROPOSALS[proposal_id]['status'] = 'rejected'
    elif datetime.now() > datetime.fromisoformat(proposal['expires_at']):
        status = 'expired'
        PROPOSALS[proposal_id]['status'] = 'expired'
    else:
        status = 'pending'

    return {
        'proposal_id': proposal_id,
        'status': status,
        'votes_for': len(votes['for']),
        'votes_against': len(votes['against']),
        'votes_abstain': len(votes['abstain']),
        'total_agents': len(AGENT_POOL),
        'quorum_required': quorum,
        'for_percentage': for_percent,
        'against_percentage': against_percent,
        'consensus_reached': status in ['approved', 'rejected']
    }


async def resolve_conflict(proposal_id: str) -> dict:
    """Resolve voting conflict through mediation."""
    from gantz import MCPClient
    mcp = MCPClient()

    proposal = PROPOSALS.get(proposal_id)
    votes = VOTES.get(proposal_id)

    if not proposal or not votes:
        return {'error': 'Proposal not found'}

    # Gather all reasoning
    all_reasoning = {
        'for': [v['reasoning'] for v in votes['for']],
        'against': [v['reasoning'] for v in votes['against']]
    }

    # AI conflict resolution
    resolution = mcp.execute_tool('ai_mediate', {
        'type': 'consensus_conflict',
        'proposal': proposal['content'],
        'for_arguments': all_reasoning['for'],
        'against_arguments': all_reasoning['against'],
        'mediate': ['common_ground', 'compromise', 'modified_proposal', 'recommendation']
    })

    if resolution.get('modified_proposal'):
        # Create new proposal with modifications
        new_proposal = await propose(
            resolution['modified_proposal'],
            proposal['quorum']
        )

        return {
            'original_proposal': proposal_id,
            'resolution_type': 'modified_proposal',
            'new_proposal_id': new_proposal['proposal_id'],
            'modifications': resolution.get('modifications', []),
            'common_ground': resolution.get('common_ground')
        }
    else:
        return {
            'proposal_id': proposal_id,
            'resolution_type': 'recommendation',
            'recommendation': resolution.get('recommendation'),
            'common_ground': resolution.get('common_ground'),
            'compromise_options': resolution.get('compromises', [])
        }


async def execute_decision(proposal_id: str) -> dict:
    """Execute approved consensus decision."""
    from gantz import MCPClient
    mcp = MCPClient()

    proposal = PROPOSALS.get(proposal_id)
    if not proposal:
        return {'error': 'Proposal not found'}

    if proposal['status'] != 'approved':
        return {'error': 'Proposal not approved'}

    # Execute based on proposal type
    execution_type = proposal['content'].get('type')

    result = mcp.execute_tool('ai_execute', {
        'type': f'consensus_{execution_type}',
        'proposal': proposal['content'],
        'approval_details': {
            'votes_for': len(VOTES[proposal_id]['for']),
            'approved_at': datetime.now().isoformat()
        }
    })

    # Update proposal status
    PROPOSALS[proposal_id]['status'] = 'executed'
    PROPOSALS[proposal_id]['executed_at'] = datetime.now().isoformat()
    PROPOSALS[proposal_id]['execution_result'] = result

    # Notify all agents
    for agent in AGENT_POOL:
        await notify_agent(agent, {
            'type': 'decision_executed',
            'proposal_id': proposal_id,
            'result': result.get('summary')
        })

    return {
        'proposal_id': proposal_id,
        'executed': True,
        'result': result,
        'executed_at': PROPOSALS[proposal_id]['executed_at']
    }


async def consensus_history(filter: dict = None) -> dict:
    """Get consensus history."""
    from gantz import MCPClient
    mcp = MCPClient()

    # Filter proposals
    filtered = []
    for pid, proposal in PROPOSALS.items():
        if filter:
            if filter.get('status') and proposal['status'] != filter['status']:
                continue
            if filter.get('proposer') and proposal['proposer'] != filter['proposer']:
                continue
        filtered.append({
            'proposal_id': pid,
            **proposal,
            'votes': {
                'for': len(VOTES.get(pid, {}).get('for', [])),
                'against': len(VOTES.get(pid, {}).get('against', [])),
                'abstain': len(VOTES.get(pid, {}).get('abstain', []))
            }
        })

    # AI analysis
    analysis = mcp.execute_tool('ai_analyze', {
        'type': 'consensus_patterns',
        'history': filtered,
        'analyze': ['trends', 'agent_alignment', 'common_disagreements', 'efficiency']
    })

    return {
        'total_proposals': len(filtered),
        'approved': len([p for p in filtered if p['status'] == 'approved']),
        'rejected': len([p for p in filtered if p['status'] == 'rejected']),
        'pending': len([p for p in filtered if p['status'] == 'pending']),
        'proposals': filtered,
        'analysis': analysis
    }
```

## Consensus Algorithms

```python
# algorithms/consensus.py
from gantz import MCPClient

mcp = MCPClient(config_path='gantz.yaml')


class MajorityConsensus:
    """Simple majority consensus algorithm."""

    def __init__(self, agents: list, threshold: float = 0.5):
        self.agents = agents
        self.threshold = threshold

    async def reach_consensus(self, proposal: dict) -> dict:
        """Reach consensus through majority vote."""
        result = await mcp.execute_tool('propose', {
            'proposal': proposal,
            'quorum': self.threshold
        })

        # Collect votes
        for agent in self.agents:
            vote_decision = await self.get_agent_decision(agent, proposal)
            await mcp.execute_tool('vote', {
                'proposal_id': result['proposal_id'],
                'agent_id': agent,
                'vote': vote_decision
            })

        return await mcp.execute_tool('check_consensus', {
            'proposal_id': result['proposal_id']
        })


class ByzantineFaultTolerant:
    """Byzantine fault tolerant consensus."""

    def __init__(self, agents: list, max_faulty: int = 1):
        self.agents = agents
        self.max_faulty = max_faulty
        # Requires n >= 3f + 1 agents
        self.threshold = (2 * len(agents) + 1) / (3 * len(agents))

    async def reach_consensus(self, proposal: dict) -> dict:
        """Reach BFT consensus."""
        # Pre-prepare phase
        prepared = await self.pre_prepare(proposal)

        # Prepare phase
        prepare_votes = await self.prepare_phase(prepared)

        # Commit phase
        if self.count_votes(prepare_votes) >= self.threshold * len(self.agents):
            commit_votes = await self.commit_phase(prepared)

            if self.count_votes(commit_votes) >= self.threshold * len(self.agents):
                return {
                    'consensus': True,
                    'proposal': proposal,
                    'prepare_votes': prepare_votes,
                    'commit_votes': commit_votes
                }

        return {'consensus': False, 'reason': 'Failed to reach BFT consensus'}


class RaftConsensus:
    """Raft-style leader-based consensus."""

    def __init__(self, agents: list):
        self.agents = agents
        self.leader = None
        self.term = 0

    async def elect_leader(self) -> str:
        """Elect leader through voting."""
        self.term += 1

        votes = {}
        for agent in self.agents:
            # Each agent votes for a leader
            vote = await self.request_vote(agent)
            votes[vote] = votes.get(vote, 0) + 1

        # Agent with most votes becomes leader
        self.leader = max(votes, key=votes.get)
        return self.leader

    async def replicate_decision(self, decision: dict) -> dict:
        """Replicate decision through leader."""
        if not self.leader:
            await self.elect_leader()

        # Leader proposes
        result = await mcp.execute_tool('propose', {
            'proposal': {
                **decision,
                'proposer': self.leader,
                'term': self.term
            },
            'quorum': 0.5
        })

        # Followers accept
        accepted = 0
        for agent in self.agents:
            if agent != self.leader:
                ack = await self.append_entry(agent, decision)
                if ack:
                    accepted += 1

        return {
            'leader': self.leader,
            'term': self.term,
            'accepted_by': accepted,
            'total_followers': len(self.agents) - 1
        }
```

## Deploy with Gantz CLI

```bash
# Install Gantz
npm install -g gantz

# Initialize consensus system
gantz init --template consensus-system

# Deploy
gantz deploy --platform kubernetes

# Submit proposal
gantz run propose --proposal '{"type": "policy_change", "content": {...}}' --quorum 0.66

# Cast vote
gantz run vote --proposal-id prop_123 --agent-id agent1 --vote for

# Check status
gantz run check_consensus --proposal-id prop_123

# Resolve conflict
gantz run resolve_conflict --proposal-id prop_123
```

Build distributed consensus systems at [gantz.run](https://gantz.run).

## Related Reading

- [Voting Patterns](/post/voting-patterns/) - Voting mechanisms
- [Collaboration Patterns](/post/collaboration-patterns/) - Agent teamwork
- [Hierarchy Patterns](/post/hierarchy-patterns/) - Decision hierarchies

## Conclusion

Consensus patterns enable reliable multi-agent decision-making. With proper voting, quorum requirements, and conflict resolution, you can build systems that reach agreement even with diverse perspectives.

Start building consensus-driven systems with Gantz today.
