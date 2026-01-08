+++
title = "AI Agent Collaboration Patterns with MCP: Multi-Agent Teamwork"
image = "images/collaboration-patterns.webp"
date = 2025-06-12
description = "Master AI agent collaboration patterns with MCP and Gantz. Learn peer-to-peer communication, shared workspaces, and cooperative problem-solving."
summary = "One agent can only do so much. Build teams of agents that collaborate - a researcher finds information, an analyst processes it, a writer produces output. Learn peer-to-peer messaging, shared workspaces where agents contribute to common artifacts, handoff protocols, and coordination patterns that prevent agents from stepping on each other's work."
draft = false
tags = ['collaboration', 'patterns', 'ai', 'mcp', 'multi-agent', 'gantz']
voice = false

[howto]
name = "How To Implement AI Agent Collaboration Patterns with MCP"
totalTime = 45
[[howto.steps]]
name = "Understand collaboration models"
text = "Learn agent teamwork fundamentals"
[[howto.steps]]
name = "Design communication channels"
text = "Build inter-agent messaging"
[[howto.steps]]
name = "Implement shared state"
text = "Create collaborative workspaces"
[[howto.steps]]
name = "Add coordination logic"
text = "Implement synchronization mechanisms"
[[howto.steps]]
name = "Deploy with Gantz"
text = "Deploy collaborative agents using Gantz CLI"
+++

AI agent collaboration patterns enable multiple agents to work together on complex tasks through communication, shared state, and coordinated action.

## Why Use Collaboration Patterns?

Agent collaboration enables:

- **Complex problem-solving**: Combine diverse perspectives
- **Knowledge sharing**: Agents learn from each other
- **Redundancy**: Multiple agents verify results
- **Creativity**: Emergent solutions from interaction
- **Scalability**: Tackle larger problems together

## Collaboration Architecture

```yaml
# gantz.yaml
name: collaboration-system
version: 1.0.0

tools:
  create_workspace:
    description: "Create collaborative workspace"
    parameters:
      name:
        type: string
        required: true
      agents:
        type: array
        required: true
    handler: collaboration.create_workspace

  send_message:
    description: "Send message to agent(s)"
    parameters:
      from_agent:
        type: string
        required: true
      to_agents:
        type: array
        required: true
      message:
        type: object
        required: true
    handler: collaboration.send_message

  share_artifact:
    description: "Share work artifact"
    parameters:
      workspace_id:
        type: string
        required: true
      artifact:
        type: object
        required: true
    handler: collaboration.share_artifact

  request_review:
    description: "Request peer review"
    parameters:
      artifact_id:
        type: string
        required: true
      reviewers:
        type: array
    handler: collaboration.request_review

  merge_contributions:
    description: "Merge agent contributions"
    parameters:
      workspace_id:
        type: string
        required: true
    handler: collaboration.merge_contributions

  collaborative_solve:
    description: "Solve problem collaboratively"
    parameters:
      problem:
        type: object
        required: true
      team:
        type: array
    handler: collaboration.collaborative_solve
```

## Handler Implementation

```python
# handlers/collaboration.py
import asyncio
from datetime import datetime
from typing import List, Dict, Any

# Shared state
WORKSPACES = {}
MESSAGE_QUEUES = {}
ARTIFACTS = {}


async def create_workspace(name: str, agents: list) -> dict:
    """Create collaborative workspace."""
    from gantz import MCPClient
    mcp = MCPClient()

    workspace_id = generate_workspace_id()

    workspace = {
        'id': workspace_id,
        'name': name,
        'agents': agents,
        'artifacts': [],
        'messages': [],
        'created_at': datetime.now().isoformat(),
        'status': 'active'
    }

    # Initialize message queues for agents
    for agent in agents:
        if agent not in MESSAGE_QUEUES:
            MESSAGE_QUEUES[agent] = asyncio.Queue()

    # Notify agents of workspace creation
    for agent in agents:
        await send_message('system', [agent], {
            'type': 'workspace_created',
            'workspace_id': workspace_id,
            'name': name,
            'team': agents
        })

    WORKSPACES[workspace_id] = workspace

    return {
        'workspace_id': workspace_id,
        'name': name,
        'agents': agents,
        'status': 'active'
    }


async def send_message(from_agent: str, to_agents: list, message: dict) -> dict:
    """Send message to agent(s)."""
    from gantz import MCPClient
    mcp = MCPClient()

    message_id = generate_message_id()

    full_message = {
        'id': message_id,
        'from': from_agent,
        'to': to_agents,
        'content': message,
        'sent_at': datetime.now().isoformat()
    }

    # Route to recipients
    delivered = []
    for agent in to_agents:
        if agent in MESSAGE_QUEUES:
            await MESSAGE_QUEUES[agent].put(full_message)
            delivered.append(agent)

    return {
        'message_id': message_id,
        'from': from_agent,
        'delivered_to': delivered,
        'sent_at': full_message['sent_at']
    }


async def share_artifact(workspace_id: str, artifact: dict) -> dict:
    """Share work artifact in workspace."""
    from gantz import MCPClient
    mcp = MCPClient()

    workspace = WORKSPACES.get(workspace_id)
    if not workspace:
        return {'error': 'Workspace not found'}

    artifact_id = generate_artifact_id()

    shared_artifact = {
        'id': artifact_id,
        'workspace_id': workspace_id,
        'content': artifact.get('content'),
        'type': artifact.get('type'),
        'author': artifact.get('author'),
        'shared_at': datetime.now().isoformat(),
        'version': 1,
        'reviews': [],
        'status': 'draft'
    }

    ARTIFACTS[artifact_id] = shared_artifact
    workspace['artifacts'].append(artifact_id)

    # Notify team
    for agent in workspace['agents']:
        if agent != artifact.get('author'):
            await send_message('system', [agent], {
                'type': 'artifact_shared',
                'artifact_id': artifact_id,
                'author': artifact.get('author'),
                'artifact_type': artifact.get('type')
            })

    return {
        'artifact_id': artifact_id,
        'shared': True,
        'workspace_id': workspace_id,
        'notified': len(workspace['agents']) - 1
    }


async def request_review(artifact_id: str, reviewers: list = None) -> dict:
    """Request peer review of artifact."""
    from gantz import MCPClient
    mcp = MCPClient()

    artifact = ARTIFACTS.get(artifact_id)
    if not artifact:
        return {'error': 'Artifact not found'}

    workspace = WORKSPACES.get(artifact['workspace_id'])

    # Select reviewers if not specified
    if not reviewers:
        available = [a for a in workspace['agents'] if a != artifact['author']]
        # AI reviewer selection
        selection = mcp.execute_tool('ai_select', {
            'type': 'reviewer_selection',
            'artifact': artifact,
            'candidates': available,
            'select': 2
        })
        reviewers = selection.get('selected', available[:2])

    # Request reviews
    review_requests = []
    for reviewer in reviewers:
        request = {
            'artifact_id': artifact_id,
            'reviewer': reviewer,
            'requested_at': datetime.now().isoformat(),
            'status': 'pending'
        }
        review_requests.append(request)

        await send_message(artifact['author'], [reviewer], {
            'type': 'review_request',
            'artifact_id': artifact_id,
            'artifact_type': artifact['type']
        })

    artifact['reviews'] = review_requests

    return {
        'artifact_id': artifact_id,
        'reviewers': reviewers,
        'status': 'pending_review'
    }


async def merge_contributions(workspace_id: str) -> dict:
    """Merge all agent contributions in workspace."""
    from gantz import MCPClient
    mcp = MCPClient()

    workspace = WORKSPACES.get(workspace_id)
    if not workspace:
        return {'error': 'Workspace not found'}

    # Get all artifacts
    artifacts = [ARTIFACTS[aid] for aid in workspace['artifacts']]

    # AI merge
    merge_result = mcp.execute_tool('ai_synthesize', {
        'type': 'contribution_merge',
        'artifacts': artifacts,
        'merge_strategy': 'intelligent',
        'resolve_conflicts': True
    })

    merged_artifact = {
        'id': generate_artifact_id(),
        'workspace_id': workspace_id,
        'type': 'merged',
        'content': merge_result.get('merged_content'),
        'contributors': list(set(a['author'] for a in artifacts)),
        'merged_at': datetime.now().isoformat(),
        'conflicts_resolved': merge_result.get('conflicts', []),
        'version': 1
    }

    ARTIFACTS[merged_artifact['id']] = merged_artifact

    return {
        'workspace_id': workspace_id,
        'merged_artifact_id': merged_artifact['id'],
        'contributions_merged': len(artifacts),
        'contributors': merged_artifact['contributors'],
        'conflicts_resolved': len(merge_result.get('conflicts', []))
    }


async def collaborative_solve(problem: dict, team: list = None) -> dict:
    """Solve problem collaboratively with agent team."""
    from gantz import MCPClient
    mcp = MCPClient()

    # Create workspace for problem
    workspace = await create_workspace(
        f"solve_{problem.get('id', 'unknown')}",
        team or ['analyst', 'researcher', 'critic', 'synthesizer']
    )

    workspace_id = workspace['workspace_id']
    agents = workspace['agents']

    # Phase 1: Individual analysis
    analyses = []
    for agent in agents:
        analysis = mcp.execute_tool('ai_analyze', {
            'type': 'problem_analysis',
            'problem': problem,
            'perspective': agent,
            'analyze': ['understanding', 'approach', 'challenges', 'solutions']
        })

        await share_artifact(workspace_id, {
            'type': 'analysis',
            'author': agent,
            'content': analysis
        })
        analyses.append(analysis)

    # Phase 2: Discussion and refinement
    discussion_rounds = 3
    for round_num in range(discussion_rounds):
        for agent in agents:
            # Agent reviews others' work
            other_analyses = [a for i, a in enumerate(analyses) if agents[i] != agent]

            feedback = mcp.execute_tool('ai_generate', {
                'type': 'collaborative_feedback',
                'own_analysis': analyses[agents.index(agent)],
                'others': other_analyses,
                'round': round_num,
                'generate': ['agreements', 'disagreements', 'suggestions', 'refinements']
            })

            await send_message(agent, [a for a in agents if a != agent], {
                'type': 'discussion',
                'round': round_num,
                'content': feedback
            })

    # Phase 3: Synthesis
    merged = await merge_contributions(workspace_id)

    # Final collaborative solution
    solution = mcp.execute_tool('ai_synthesize', {
        'type': 'collaborative_solution',
        'problem': problem,
        'merged_analysis': merged,
        'team_size': len(agents),
        'synthesize': ['solution', 'rationale', 'confidence', 'alternatives']
    })

    return {
        'problem_id': problem.get('id'),
        'workspace_id': workspace_id,
        'team': agents,
        'solution': solution.get('solution'),
        'rationale': solution.get('rationale'),
        'confidence': solution.get('confidence'),
        'alternatives': solution.get('alternatives', []),
        'discussion_rounds': discussion_rounds
    }
```

## Collaboration Patterns

```python
# patterns/collaboration.py
from gantz import MCPClient

mcp = MCPClient(config_path='gantz.yaml')


class BrainstormingSession:
    """Collaborative brainstorming pattern."""

    def __init__(self, participants: list):
        self.participants = participants
        self.ideas = []

    async def run(self, topic: str) -> dict:
        """Run brainstorming session."""
        # Create workspace
        workspace = await mcp.execute_tool('create_workspace', {
            'name': f'brainstorm_{topic}',
            'agents': self.participants
        })

        # Idea generation phase
        for participant in self.participants:
            ideas = await mcp.execute_tool('ai_generate', {
                'type': 'brainstorm_ideas',
                'topic': topic,
                'perspective': participant,
                'count': 5
            })

            for idea in ideas.get('ideas', []):
                await mcp.execute_tool('share_artifact', {
                    'workspace_id': workspace['workspace_id'],
                    'artifact': {
                        'type': 'idea',
                        'author': participant,
                        'content': idea
                    }
                })
                self.ideas.append(idea)

        # Evaluation phase
        evaluations = await self.evaluate_ideas()

        return {
            'topic': topic,
            'total_ideas': len(self.ideas),
            'top_ideas': evaluations[:5],
            'participants': self.participants
        }


class PeerReviewCircle:
    """Peer review collaboration pattern."""

    def __init__(self, reviewers: list):
        self.reviewers = reviewers

    async def review(self, artifact: dict) -> dict:
        """Conduct peer review circle."""
        reviews = []

        for reviewer in self.reviewers:
            review = await mcp.execute_tool('ai_analyze', {
                'type': 'peer_review',
                'artifact': artifact,
                'reviewer_perspective': reviewer,
                'analyze': ['strengths', 'weaknesses', 'suggestions', 'score']
            })
            reviews.append({
                'reviewer': reviewer,
                **review
            })

        # Synthesize reviews
        synthesis = await mcp.execute_tool('ai_synthesize', {
            'type': 'review_synthesis',
            'reviews': reviews,
            'synthesize': ['consensus', 'key_points', 'final_score', 'recommendations']
        })

        return {
            'artifact_id': artifact.get('id'),
            'reviews': reviews,
            'consensus': synthesis.get('consensus'),
            'final_score': synthesis.get('final_score'),
            'recommendations': synthesis.get('recommendations', [])
        }


class DebateProtocol:
    """Structured debate collaboration pattern."""

    def __init__(self, proposition_agent: str, opposition_agent: str, judge: str):
        self.prop = proposition_agent
        self.opp = opposition_agent
        self.judge = judge

    async def debate(self, topic: str) -> dict:
        """Conduct structured debate."""
        rounds = []

        # Opening statements
        prop_opening = await self.get_argument(self.prop, topic, 'opening', 'for')
        opp_opening = await self.get_argument(self.opp, topic, 'opening', 'against')

        rounds.append({
            'round': 'opening',
            'proposition': prop_opening,
            'opposition': opp_opening
        })

        # Rebuttals
        for i in range(2):
            prop_rebuttal = await self.get_rebuttal(self.prop, opp_opening, 'for')
            opp_rebuttal = await self.get_rebuttal(self.opp, prop_opening, 'against')

            rounds.append({
                'round': f'rebuttal_{i+1}',
                'proposition': prop_rebuttal,
                'opposition': opp_rebuttal
            })

        # Closing statements
        prop_closing = await self.get_argument(self.prop, topic, 'closing', 'for')
        opp_closing = await self.get_argument(self.opp, topic, 'closing', 'against')

        rounds.append({
            'round': 'closing',
            'proposition': prop_closing,
            'opposition': opp_closing
        })

        # Judge decision
        verdict = await mcp.execute_tool('ai_analyze', {
            'type': 'debate_judgment',
            'topic': topic,
            'rounds': rounds,
            'judge': self.judge,
            'analyze': ['winner', 'reasoning', 'key_points', 'score']
        })

        return {
            'topic': topic,
            'rounds': rounds,
            'verdict': verdict
        }
```

## Deploy with Gantz CLI

```bash
# Install Gantz
npm install -g gantz

# Initialize collaboration system
gantz init --template collaboration-system

# Deploy
gantz deploy --platform kubernetes

# Create workspace
gantz run create_workspace --name "project_alpha" --agents '["analyst", "developer", "reviewer"]'

# Collaborative solve
gantz run collaborative_solve --problem '{"description": "..."}' --team '["agent1", "agent2", "agent3"]'

# Merge contributions
gantz run merge_contributions --workspace-id ws_123
```

Build collaborative AI systems at [gantz.run](https://gantz.run).

## Related Reading

- [Consensus Patterns](/post/consensus-patterns/) - Agreement building
- [Voting Patterns](/post/voting-patterns/) - Collective decisions
- [Swarm Patterns](/post/swarm-patterns/) - Emergent behavior

## Conclusion

Collaboration patterns enable powerful multi-agent teamwork. With shared workspaces, peer review, and structured discussions, agents can tackle problems beyond individual capabilities.

Start building collaborative agent systems with Gantz today.
