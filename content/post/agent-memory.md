+++
title = "Agent Memory Patterns: Context That Persists"
image = "/images/agent-memory.png"
date = 2025-11-19
description = "Build AI agents with persistent memory. Store conversation history, learned facts, and user preferences across sessions using MCP tools."
draft = false
tags = ['mcp', 'architecture', 'memory']
voice = false

[howto]
name = "Build Agent Memory"
totalTime = 30
[[howto.steps]]
name = "Design memory architecture"
text = "Choose memory types for different use cases."
[[howto.steps]]
name = "Implement storage"
text = "Build MCP tools for memory persistence."
[[howto.steps]]
name = "Create retrieval system"
text = "Implement semantic search for relevant memories."
[[howto.steps]]
name = "Add memory management"
text = "Handle memory consolidation and forgetting."
[[howto.steps]]
name = "Integrate with agents"
text = "Use memory in agent prompts and decisions."
+++


Conversations end. But context shouldn't.

AI agents that remember. Across sessions. Across time.

Here's how to build persistent memory.

## The memory problem

Default AI behavior:
- Each conversation starts fresh
- No memory of past interactions
- Can't learn user preferences
- Context lost between sessions

With persistent memory:
- Remember past conversations
- Learn user preferences over time
- Build on previous work
- Personalized interactions

## Memory types

1. **Episodic**: What happened (conversation history)
2. **Semantic**: What we know (facts, knowledge)
3. **Procedural**: How to do things (learned patterns)
4. **Working**: Current context (active session)

## Step 1: Memory infrastructure

Using [Gantz](https://gantz.run):

```yaml
# gantz.yaml
name: agent-memory

tools:
  - name: store_memory
    description: Store a memory for later retrieval
    parameters:
      - name: user_id
        type: string
        required: true
      - name: memory_type
        type: string
        required: true
        description: "episodic, semantic, procedural"
      - name: content
        type: string
        required: true
      - name: metadata
        type: string
        description: JSON metadata for the memory
    script:
      command: python
      args: ["scripts/store_memory.py", "{{user_id}}", "{{memory_type}}", "{{metadata}}"]
      stdin: "{{content}}"

  - name: search_memories
    description: Search memories by semantic similarity
    parameters:
      - name: user_id
        type: string
        required: true
      - name: query
        type: string
        required: true
      - name: memory_type
        type: string
        description: Filter by type
      - name: limit
        type: integer
        default: 10
    script:
      command: python
      args: ["scripts/search_memories.py", "{{user_id}}", "{{query}}", "{{memory_type}}", "{{limit}}"]

  - name: get_recent_memories
    description: Get recent memories for a user
    parameters:
      - name: user_id
        type: string
        required: true
      - name: limit
        type: integer
        default: 20
      - name: memory_type
        type: string
    script:
      command: python
      args: ["scripts/recent_memories.py", "{{user_id}}", "{{limit}}", "{{memory_type}}"]

  - name: update_memory
    description: Update or reinforce a memory
    parameters:
      - name: memory_id
        type: string
        required: true
      - name: updates
        type: string
        required: true
    script:
      command: python
      args: ["scripts/update_memory.py", "{{memory_id}}", "{{updates}}"]

  - name: forget_memory
    description: Remove a specific memory
    parameters:
      - name: memory_id
        type: string
        required: true
    script:
      command: python
      args: ["scripts/forget_memory.py", "{{memory_id}}"]

  - name: get_user_profile
    description: Get aggregated user preferences and facts
    parameters:
      - name: user_id
        type: string
        required: true
    script:
      command: python
      args: ["scripts/get_profile.py", "{{user_id}}"]

  - name: update_user_profile
    description: Update user profile with learned information
    parameters:
      - name: user_id
        type: string
        required: true
      - name: updates
        type: string
        required: true
    script:
      command: python
      args: ["scripts/update_profile.py", "{{user_id}}", "{{updates}}"]
```

Memory storage script:

```python
# scripts/store_memory.py
import sys
import json
import uuid
from datetime import datetime
import chromadb
from sentence_transformers import SentenceTransformer

# Initialize embedding model
model = SentenceTransformer('all-MiniLM-L6-v2')

# Initialize ChromaDB
chroma = chromadb.PersistentClient(path="./memory_db")

def store_memory(user_id: str, memory_type: str, content: str, metadata: dict = None) -> dict:
    """Store a memory with semantic embedding."""

    # Get or create collection for user
    collection = chroma.get_or_create_collection(
        name=f"memories_{user_id}",
        metadata={"hnsw:space": "cosine"}
    )

    # Generate embedding
    embedding = model.encode(content).tolist()

    # Create memory record
    memory_id = str(uuid.uuid4())
    memory_metadata = {
        "type": memory_type,
        "timestamp": datetime.utcnow().isoformat(),
        "access_count": 0,
        **(metadata or {})
    }

    # Store in ChromaDB
    collection.add(
        ids=[memory_id],
        embeddings=[embedding],
        documents=[content],
        metadatas=[memory_metadata]
    )

    return {
        "id": memory_id,
        "type": memory_type,
        "stored_at": memory_metadata["timestamp"]
    }

if __name__ == "__main__":
    user_id = sys.argv[1]
    memory_type = sys.argv[2]
    metadata = json.loads(sys.argv[3]) if len(sys.argv) > 3 and sys.argv[3] else {}
    content = sys.stdin.read()

    result = store_memory(user_id, memory_type, content, metadata)
    print(json.dumps(result, indent=2))
```

Search memories script:

```python
# scripts/search_memories.py
import sys
import json
import chromadb
from sentence_transformers import SentenceTransformer

model = SentenceTransformer('all-MiniLM-L6-v2')
chroma = chromadb.PersistentClient(path="./memory_db")

def search_memories(user_id: str, query: str, memory_type: str = None, limit: int = 10) -> list:
    """Search memories by semantic similarity."""

    try:
        collection = chroma.get_collection(name=f"memories_{user_id}")
    except:
        return []

    # Generate query embedding
    query_embedding = model.encode(query).tolist()

    # Build filter
    where_filter = {"type": memory_type} if memory_type else None

    # Search
    results = collection.query(
        query_embeddings=[query_embedding],
        n_results=limit,
        where=where_filter
    )

    memories = []
    for i in range(len(results['ids'][0])):
        memories.append({
            "id": results['ids'][0][i],
            "content": results['documents'][0][i],
            "metadata": results['metadatas'][0][i],
            "relevance": 1 - results['distances'][0][i]  # Convert distance to similarity
        })

    return memories

if __name__ == "__main__":
    user_id = sys.argv[1]
    query = sys.argv[2]
    memory_type = sys.argv[3] if len(sys.argv) > 3 and sys.argv[3] != "None" else None
    limit = int(sys.argv[4]) if len(sys.argv) > 4 else 10

    results = search_memories(user_id, query, memory_type, limit)
    print(json.dumps(results, indent=2))
```

```bash
gantz run --auth
```

## Step 2: Memory-enabled agent

```python
import anthropic
from typing import Optional
import json

MCP_URL = "https://agent-memory.gantz.run/sse"
MCP_TOKEN = "gtz_abc123"

client = anthropic.Anthropic()

MEMORY_AGENT_PROMPT = """You are an AI assistant with persistent memory.

You can remember things across conversations:
- Use store_memory to save important information
- Use search_memories to recall relevant context
- Use get_user_profile for user preferences

Memory guidelines:
1. Store important facts learned about the user
2. Remember key decisions and preferences
3. Recall relevant context before responding
4. Update your understanding over time

What to remember:
- User preferences and settings
- Important decisions made
- Key facts about their projects/work
- Patterns in their requests
- Things they asked you to remember

What NOT to remember:
- Sensitive information (passwords, secrets)
- Temporary/ephemeral requests
- Trivial small talk"""

class MemoryAgent:
    """Agent with persistent memory capabilities."""

    def __init__(self, user_id: str):
        self.user_id = user_id
        self.session_memories = []

    def chat(self, message: str) -> str:
        """Chat with memory recall and storage."""

        # Build context from memory
        memory_context = self._get_memory_context(message)

        response = client.messages.create(
            model="claude-sonnet-4-20250514",
            max_tokens=4096,
            system=f"""{MEMORY_AGENT_PROMPT}

User ID: {self.user_id}

Relevant memories:
{memory_context}

Remember to:
1. Consider the memory context in your response
2. Store any new important information
3. Be consistent with past interactions""",
            messages=[{
                "role": "user",
                "content": message
            }],
            tools=[{"type": "mcp", "server_url": MCP_URL, "token": MCP_TOKEN}]
        )

        result = ""
        for content in response.content:
            if hasattr(content, 'text'):
                result += content.text

        # Store this interaction as episodic memory
        self._store_interaction(message, result)

        return result

    def _get_memory_context(self, query: str) -> str:
        """Retrieve relevant memories for context."""

        response = client.messages.create(
            model="claude-sonnet-4-20250514",
            max_tokens=2048,
            messages=[{
                "role": "user",
                "content": f"""For user {self.user_id}, retrieve relevant context:

Query: {query}

1. Use get_user_profile to get their preferences
2. Use search_memories with the query to find relevant past interactions
3. Summarize the relevant context

Output only the relevant context, nothing else."""
            }],
            tools=[{"type": "mcp", "server_url": MCP_URL, "token": MCP_TOKEN}]
        )

        for content in response.content:
            if hasattr(content, 'text'):
                return content.text

        return "No relevant memories found."

    def _store_interaction(self, user_message: str, agent_response: str):
        """Store the interaction in episodic memory."""

        # Only store meaningful interactions
        if len(user_message) < 10:
            return

        response = client.messages.create(
            model="claude-sonnet-4-20250514",
            max_tokens=512,
            messages=[{
                "role": "user",
                "content": f"""Analyze this interaction and decide what to remember:

User: {user_message}
Assistant: {agent_response[:500]}

If there's something worth remembering (preference, fact, decision), use store_memory.
Memory types: episodic (what happened), semantic (facts), procedural (how to do things)

If nothing important to remember, just say "Nothing to store"."""
            }],
            tools=[{"type": "mcp", "server_url": MCP_URL, "token": MCP_TOKEN}]
        )

    def remember(self, content: str, memory_type: str = "semantic") -> str:
        """Explicitly store a memory."""

        response = client.messages.create(
            model="claude-sonnet-4-20250514",
            max_tokens=256,
            messages=[{
                "role": "user",
                "content": f"""Store this memory for user {self.user_id}:

Content: {content}
Type: {memory_type}

Use store_memory tool."""
            }],
            tools=[{"type": "mcp", "server_url": MCP_URL, "token": MCP_TOKEN}]
        )

        for content in response.content:
            if hasattr(content, 'text'):
                return content.text

        return "Memory stored."

    def recall(self, query: str) -> str:
        """Explicitly recall memories."""

        response = client.messages.create(
            model="claude-sonnet-4-20250514",
            max_tokens=2048,
            messages=[{
                "role": "user",
                "content": f"""Recall memories for user {self.user_id} about: {query}

Use search_memories to find relevant memories.
Summarize what you found."""
            }],
            tools=[{"type": "mcp", "server_url": MCP_URL, "token": MCP_TOKEN}]
        )

        for content in response.content:
            if hasattr(content, 'text'):
                return content.text

        return "No memories found."
```

## Step 3: User profiles

```python
def build_user_profile(user_id: str) -> dict:
    """Build a comprehensive user profile from memories."""

    response = client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=2048,
        messages=[{
            "role": "user",
            "content": f"""Build a user profile for {user_id}:

1. Use get_recent_memories to get their interaction history
2. Use search_memories with relevant queries to find:
   - Their preferences
   - Their work/projects
   - Their communication style
   - Any explicit settings they've shared

3. Synthesize into a profile with:
   - preferences: {{key: value}}
   - interests: [list]
   - communication_style: description
   - known_facts: [list of facts]
   - active_projects: [list]

Output as JSON."""
        }],
        tools=[{"type": "mcp", "server_url": MCP_URL, "token": MCP_TOKEN}]
    )

    for content in response.content:
        if hasattr(content, 'text'):
            try:
                return json.loads(content.text)
            except:
                return {"raw": content.text}

    return {}

def update_profile_from_interaction(user_id: str, interaction: str):
    """Update user profile based on new interaction."""

    response = client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=512,
        messages=[{
            "role": "user",
            "content": f"""Analyze this interaction for user {user_id}:

{interaction}

1. Use get_user_profile to get current profile
2. Identify any new information learned:
   - New preferences
   - Updated facts
   - Changed settings
3. Use update_user_profile if there are updates

Only update if there's genuinely new information."""
        }],
        tools=[{"type": "mcp", "server_url": MCP_URL, "token": MCP_TOKEN}]
    )
```

## Step 4: Memory consolidation

```python
def consolidate_memories(user_id: str):
    """Consolidate and compress memories periodically."""

    response = client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=4096,
        messages=[{
            "role": "user",
            "content": f"""Consolidate memories for user {user_id}:

1. Use get_recent_memories with limit=100
2. Identify redundant or outdated memories
3. Group related episodic memories into summaries
4. For each group:
   - Create a consolidated semantic memory
   - Use store_memory to save it
   - Use forget_memory to remove the originals
5. Keep important specific memories intact

Goals:
- Reduce total memory count
- Preserve key information
- Remove redundancy
- Maintain useful recall

Report what was consolidated."""
        }],
        tools=[{"type": "mcp", "server_url": MCP_URL, "token": MCP_TOKEN}]
    )

    for content in response.content:
        if hasattr(content, 'text'):
            return content.text

    return ""

def decay_old_memories(user_id: str, days: int = 30):
    """Remove or archive old, unused memories."""

    response = client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=2048,
        messages=[{
            "role": "user",
            "content": f"""Review old memories for user {user_id}:

1. Get memories older than {days} days
2. Check access_count in metadata
3. For memories with low access and low importance:
   - Use forget_memory to remove
4. Keep memories that are:
   - Frequently accessed
   - Core user preferences
   - Important facts

Report what was removed."""
        }],
        tools=[{"type": "mcp", "server_url": MCP_URL, "token": MCP_TOKEN}]
    )

    for content in response.content:
        if hasattr(content, 'text'):
            return content.text

    return ""
```

## Step 5: Memory-aware workflows

```python
class MemoryAwareProject:
    """Track project progress across sessions."""

    def __init__(self, user_id: str, project_name: str):
        self.user_id = user_id
        self.project_name = project_name
        self.agent = MemoryAgent(user_id)

    def get_project_context(self) -> str:
        """Get full project context from memory."""

        return self.agent.recall(f"project {self.project_name}")

    def update_progress(self, update: str):
        """Store project progress update."""

        self.agent.remember(
            f"Project '{self.project_name}' update: {update}",
            memory_type="episodic"
        )

    def continue_work(self, request: str) -> str:
        """Continue work with full project context."""

        context = self.get_project_context()

        response = client.messages.create(
            model="claude-sonnet-4-20250514",
            max_tokens=4096,
            system=f"""{MEMORY_AGENT_PROMPT}

You are continuing work on project: {self.project_name}

Project context from memory:
{context}

Continue helping with the project, remembering past decisions and progress.""",
            messages=[{
                "role": "user",
                "content": request
            }],
            tools=[{"type": "mcp", "server_url": MCP_URL, "token": MCP_TOKEN}]
        )

        result = ""
        for content in response.content:
            if hasattr(content, 'text'):
                result += content.text

        # Store the work done
        self.update_progress(f"Worked on: {request[:100]}...")

        return result

# Usage
project = MemoryAwareProject("user123", "Website Redesign")

# Session 1
project.continue_work("Let's plan the homepage layout")

# Later session 2
project.continue_work("What was our decision on the homepage?")  # Agent remembers
```

## Summary

Agent memory patterns:

1. **Episodic memory** - Store what happened
2. **Semantic memory** - Store facts and knowledge
3. **User profiles** - Aggregate preferences
4. **Memory retrieval** - Semantic search for relevance
5. **Consolidation** - Compress and clean over time

Build tools with [Gantz](https://gantz.run), give agents persistent memory.

Conversations end. Understanding persists.

## Related reading

- [Multi-Agent Systems](/post/multi-agent-systems/) - Agent coordination
- [Agent Observability](/post/agent-observability/) - Debug agents
- [Event-Driven Agents](/post/event-driven-agents/) - Reactive systems

---

*How do you handle agent memory? Share your patterns.*
