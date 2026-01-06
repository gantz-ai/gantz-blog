+++
title = 'Memory Patterns for AI Agents'
date = 2025-12-10
draft = false
tags = ['agents', 'ai', 'mcp']
+++


AI agents forget everything between conversations. That's a problem.

Here's how to give your agents memory.

## The memory problem

Without memory, every conversation starts fresh:

```
Monday:
User: "My name is Sarah, I work on the payments team"
AI: "Nice to meet you, Sarah!"

Tuesday:
User: "What's my name?"
AI: "I don't know your name. Could you tell me?"
```

Agents without memory can't:
- Remember user preferences
- Learn from past mistakes
- Build on previous work
- Maintain context across sessions

## Types of memory

Human memory has different systems. AI agents need them too.

```
┌─────────────────────────────────────────────────────┐
│                   Agent Memory                       │
├─────────────────┬─────────────────┬─────────────────┤
│   Short-term    │   Long-term     │    Episodic     │
│                 │                 │                 │
│  Current task   │  Facts & prefs  │  Past events    │
│  Working memory │  Learned info   │  Conversations  │
│  Conversation   │  User profile   │  What happened  │
└─────────────────┴─────────────────┴─────────────────┘
```

## Short-term memory

What the agent knows right now. The current conversation and task.

### Implementation: Conversation buffer

```python
class ShortTermMemory:
    def __init__(self, max_messages=50):
        self.messages = []
        self.max_messages = max_messages

    def add(self, role, content):
        self.messages.append({"role": role, "content": content})
        # Trim if too long
        if len(self.messages) > self.max_messages:
            self.messages = self.messages[-self.max_messages:]

    def get_context(self):
        return self.messages

    def clear(self):
        self.messages = []
```

### Implementation: Sliding window

Keep recent context, summarize old context.

```python
class SlidingWindowMemory:
    def __init__(self, window_size=20):
        self.messages = []
        self.window_size = window_size
        self.summary = ""

    def add(self, role, content):
        self.messages.append({"role": role, "content": content})

        if len(self.messages) > self.window_size * 2:
            # Summarize older messages
            old_messages = self.messages[:self.window_size]
            self.summary = self.summarize(old_messages)
            self.messages = self.messages[self.window_size:]

    def get_context(self):
        context = []
        if self.summary:
            context.append({
                "role": "system",
                "content": f"Previous conversation summary: {self.summary}"
            })
        context.extend(self.messages)
        return context

    def summarize(self, messages):
        response = llm.create(
            messages=[
                {"role": "system", "content": "Summarize this conversation concisely"},
                {"role": "user", "content": str(messages)}
            ]
        )
        return response.content
```

### Implementation: Token-aware buffer

Manage by tokens, not message count.

```python
class TokenAwareMemory:
    def __init__(self, max_tokens=4000):
        self.messages = []
        self.max_tokens = max_tokens

    def add(self, role, content):
        self.messages.append({"role": role, "content": content})
        self.trim_to_fit()

    def trim_to_fit(self):
        while self.count_tokens() > self.max_tokens:
            # Remove oldest non-system message
            for i, msg in enumerate(self.messages):
                if msg["role"] != "system":
                    self.messages.pop(i)
                    break

    def count_tokens(self):
        # Rough estimate: 4 chars per token
        total = sum(len(m["content"]) for m in self.messages)
        return total // 4
```

## Long-term memory

Persistent facts the agent should always know.

### Implementation: Key-value store

```python
class LongTermMemory:
    def __init__(self, db_path="memory.db"):
        self.db = sqlite3.connect(db_path)
        self.db.execute("""
            CREATE TABLE IF NOT EXISTS facts (
                key TEXT PRIMARY KEY,
                value TEXT,
                category TEXT,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        """)

    def remember(self, key, value, category="general"):
        self.db.execute(
            "INSERT OR REPLACE INTO facts (key, value, category) VALUES (?, ?, ?)",
            (key, value, category)
        )
        self.db.commit()

    def recall(self, key):
        result = self.db.execute(
            "SELECT value FROM facts WHERE key = ?", (key,)
        ).fetchone()
        return result[0] if result else None

    def recall_category(self, category):
        results = self.db.execute(
            "SELECT key, value FROM facts WHERE category = ?", (category,)
        ).fetchall()
        return dict(results)

    def forget(self, key):
        self.db.execute("DELETE FROM facts WHERE key = ?", (key,))
        self.db.commit()
```

### Implementation: User profile

```python
class UserProfile:
    def __init__(self, user_id, db):
        self.user_id = user_id
        self.db = db

    def update(self, field, value):
        self.db.remember(f"user:{self.user_id}:{field}", value, "profile")

    def get(self, field):
        return self.db.recall(f"user:{self.user_id}:{field}")

    def get_all(self):
        return self.db.recall_category("profile")

    def to_context(self):
        profile = self.get_all()
        if not profile:
            return ""
        lines = [f"- {k.split(':')[-1]}: {v}" for k, v in profile.items()]
        return "User profile:\n" + "\n".join(lines)
```

Usage:

```python
profile = UserProfile("sarah_123", long_term_memory)
profile.update("name", "Sarah")
profile.update("team", "payments")
profile.update("timezone", "PST")
profile.update("preference_verbosity", "concise")

# Later, inject into context
context = profile.to_context()
# "User profile:
#  - name: Sarah
#  - team: payments
#  - timezone: PST
#  - preference_verbosity: concise"
```

### Implementation: Vector store

For semantic search over memories.

```python
class VectorMemory:
    def __init__(self):
        self.embeddings = []
        self.documents = []

    def store(self, text, metadata=None):
        embedding = get_embedding(text)
        self.embeddings.append(embedding)
        self.documents.append({"text": text, "metadata": metadata})

    def search(self, query, top_k=5):
        query_embedding = get_embedding(query)
        scores = [
            cosine_similarity(query_embedding, emb)
            for emb in self.embeddings
        ]
        # Get top-k indices
        top_indices = sorted(
            range(len(scores)),
            key=lambda i: scores[i],
            reverse=True
        )[:top_k]
        return [self.documents[i] for i in top_indices]

    def to_context(self, query):
        relevant = self.search(query)
        return "\n".join([doc["text"] for doc in relevant])
```

## Episodic memory

What happened in the past. Specific events and conversations.

### Implementation: Conversation log

```python
class EpisodicMemory:
    def __init__(self, db_path="episodes.db"):
        self.db = sqlite3.connect(db_path)
        self.db.execute("""
            CREATE TABLE IF NOT EXISTS episodes (
                id INTEGER PRIMARY KEY,
                timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                session_id TEXT,
                summary TEXT,
                outcome TEXT,
                full_conversation TEXT
            )
        """)

    def save_episode(self, session_id, conversation, summary, outcome):
        self.db.execute(
            """INSERT INTO episodes
               (session_id, summary, outcome, full_conversation)
               VALUES (?, ?, ?, ?)""",
            (session_id, summary, outcome, json.dumps(conversation))
        )
        self.db.commit()

    def recall_similar(self, query, limit=5):
        # Simple keyword match (use vector search for better results)
        results = self.db.execute(
            """SELECT summary, outcome FROM episodes
               WHERE summary LIKE ?
               ORDER BY timestamp DESC LIMIT ?""",
            (f"%{query}%", limit)
        ).fetchall()
        return results

    def recall_recent(self, limit=10):
        results = self.db.execute(
            """SELECT summary, outcome FROM episodes
               ORDER BY timestamp DESC LIMIT ?""",
            (limit,)
        ).fetchall()
        return results
```

### Implementation: Event timeline

```python
class EventTimeline:
    def __init__(self):
        self.events = []

    def record(self, event_type, description, metadata=None):
        self.events.append({
            "timestamp": datetime.now(),
            "type": event_type,
            "description": description,
            "metadata": metadata or {}
        })

    def get_recent(self, n=10):
        return self.events[-n:]

    def get_by_type(self, event_type):
        return [e for e in self.events if e["type"] == event_type]

    def to_context(self, n=5):
        recent = self.get_recent(n)
        lines = [
            f"- [{e['timestamp']}] {e['type']}: {e['description']}"
            for e in recent
        ]
        return "Recent events:\n" + "\n".join(lines)
```

## MCP tools for memory

Give your agent tools to manage its own memory.

```yaml
# memory-tools.yaml
tools:
  - name: remember
    description: Store a fact for later recall
    parameters:
      - name: key
        type: string
        description: What to remember (e.g., "user_preference_theme")
        required: true
      - name: value
        type: string
        description: The value to remember
        required: true
    script:
      shell: |
        echo "{{value}}" | python memory_store.py set "{{key}}"

  - name: recall
    description: Retrieve a stored fact
    parameters:
      - name: key
        type: string
        required: true
    script:
      shell: python memory_store.py get "{{key}}"

  - name: search_memory
    description: Search memories by keyword
    parameters:
      - name: query
        type: string
        required: true
    script:
      shell: python memory_store.py search "{{query}}"

  - name: list_memories
    description: List all stored memories
    script:
      shell: python memory_store.py list

  - name: forget
    description: Remove a stored memory
    parameters:
      - name: key
        type: string
        required: true
    script:
      shell: python memory_store.py delete "{{key}}"
```

Run with [Gantz](https://gantz.run):

```bash
gantz --config memory-tools.yaml
```

Now the agent can manage its own memory:

```
User: "Remember that I prefer dark mode"
AI: [calls remember tool: key="preference_theme", value="dark"]
    "Got it, I'll remember you prefer dark mode."

[Later session]
User: "What theme do I like?"
AI: [calls recall tool: key="preference_theme"]
    "You prefer dark mode."
```

## Combining memory types

Real agents need all three working together.

```python
class AgentMemory:
    def __init__(self, user_id):
        self.short_term = SlidingWindowMemory(window_size=20)
        self.long_term = LongTermMemory()
        self.episodic = EpisodicMemory()
        self.user_id = user_id

    def build_context(self, current_query):
        context = []

        # 1. User profile from long-term memory
        profile = UserProfile(self.user_id, self.long_term)
        if profile_context := profile.to_context():
            context.append({
                "role": "system",
                "content": profile_context
            })

        # 2. Relevant past episodes
        similar_episodes = self.episodic.recall_similar(current_query)
        if similar_episodes:
            episode_text = "\n".join([
                f"- {ep[0]} (outcome: {ep[1]})"
                for ep in similar_episodes
            ])
            context.append({
                "role": "system",
                "content": f"Relevant past conversations:\n{episode_text}"
            })

        # 3. Current conversation from short-term
        context.extend(self.short_term.get_context())

        return context

    def process_message(self, role, content):
        self.short_term.add(role, content)

        # Extract facts for long-term storage
        if role == "user":
            self.extract_facts(content)

    def extract_facts(self, message):
        # Use LLM to extract memorable facts
        response = llm.create(
            messages=[{
                "role": "user",
                "content": f"""Extract any facts worth remembering from this message.
                Return JSON: {{"facts": [{{"key": "...", "value": "..."}}]}}
                Message: {message}"""
            }]
        )
        facts = parse_json(response.content).get("facts", [])
        for fact in facts:
            self.long_term.remember(fact["key"], fact["value"])

    def end_session(self, outcome="completed"):
        # Summarize and store as episode
        conversation = self.short_term.get_context()
        summary = self.summarize_conversation(conversation)
        self.episodic.save_episode(
            session_id=str(uuid4()),
            conversation=conversation,
            summary=summary,
            outcome=outcome
        )
        self.short_term.clear()
```

## Memory architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        AI Agent                              │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│   Current Message                                            │
│        │                                                     │
│        ▼                                                     │
│   ┌─────────────────────────────────────────────────────┐   │
│   │              Context Builder                         │   │
│   │                                                      │   │
│   │   ┌─────────┐  ┌─────────┐  ┌─────────┐            │   │
│   │   │ Profile │  │Episodes │  │ Current │            │   │
│   │   │  Facts  │  │ Search  │  │  Conv   │            │   │
│   │   └────┬────┘  └────┬────┘  └────┬────┘            │   │
│   │        │            │            │                  │   │
│   │        └────────────┼────────────┘                  │   │
│   │                     ▼                               │   │
│   │              [Combined Context]                     │   │
│   └─────────────────────┬───────────────────────────────┘   │
│                         │                                    │
│                         ▼                                    │
│                      LLM Call                                │
│                         │                                    │
│                         ▼                                    │
│                     Response                                 │
│                                                              │
└─────────────────────────────────────────────────────────────┘
         │                              │
         ▼                              ▼
┌─────────────────┐           ┌─────────────────┐
│  Long-term DB   │           │   Episode DB    │
│  (SQLite/Redis) │           │  (SQLite/Mongo) │
└─────────────────┘           └─────────────────┘
```

## Practical patterns

### Pattern 1: Auto-extract user preferences

```python
EXTRACTION_PROMPT = """Analyze this message for user preferences or facts.
Extract anything we should remember about the user.

Message: {message}

Return JSON:
{{
  "preferences": [
    {{"category": "...", "preference": "...", "value": "..."}}
  ],
  "facts": [
    {{"type": "...", "fact": "..."}}
  ]
}}"""

def auto_extract(message, memory):
    response = llm.create(
        messages=[{"role": "user", "content": EXTRACTION_PROMPT.format(message=message)}]
    )
    data = parse_json(response.content)

    for pref in data.get("preferences", []):
        memory.long_term.remember(
            f"pref:{pref['category']}",
            pref['value'],
            category="preferences"
        )

    for fact in data.get("facts", []):
        memory.long_term.remember(
            f"fact:{fact['type']}",
            fact['fact'],
            category="facts"
        )
```

### Pattern 2: Summarize on session end

```python
def end_session(memory):
    conversation = memory.short_term.get_context()

    # Generate summary
    summary = llm.create(
        messages=[
            {"role": "system", "content": "Summarize this conversation in 2-3 sentences"},
            {"role": "user", "content": str(conversation)}
        ]
    ).content

    # Determine outcome
    outcome = llm.create(
        messages=[
            {"role": "system", "content": "What was the outcome? (completed/abandoned/ongoing)"},
            {"role": "user", "content": str(conversation)}
        ]
    ).content

    # Store episode
    memory.episodic.save_episode(
        session_id=current_session_id,
        conversation=conversation,
        summary=summary,
        outcome=outcome
    )

    memory.short_term.clear()
```

### Pattern 3: Proactive memory recall

```python
def get_relevant_context(query, memory):
    # Search episodic memory
    past_episodes = memory.episodic.recall_similar(query, limit=3)

    # Search long-term facts
    relevant_facts = memory.long_term.search(query)

    # Build context
    context = []

    if past_episodes:
        context.append(
            "You've discussed similar topics before:\n" +
            "\n".join([f"- {ep.summary}" for ep in past_episodes])
        )

    if relevant_facts:
        context.append(
            "Relevant things you know:\n" +
            "\n".join([f"- {f.key}: {f.value}" for f in relevant_facts])
        )

    return "\n\n".join(context)
```

### Pattern 4: Memory decay

Old memories fade if not accessed.

```python
class DecayingMemory:
    def __init__(self, decay_days=30):
        self.decay_days = decay_days

    def recall(self, key):
        result = self.db.execute(
            """SELECT value, accessed_at FROM facts WHERE key = ?""",
            (key,)
        ).fetchone()

        if result:
            # Update access time
            self.db.execute(
                "UPDATE facts SET accessed_at = ? WHERE key = ?",
                (datetime.now(), key)
            )
            return result[0]
        return None

    def cleanup(self):
        # Remove memories not accessed in decay_days
        cutoff = datetime.now() - timedelta(days=self.decay_days)
        self.db.execute(
            "DELETE FROM facts WHERE accessed_at < ?",
            (cutoff,)
        )
```

## When to use each type

| Memory Type | Use For | Persistence | Example |
|------------|---------|-------------|---------|
| Short-term | Current task | Session | "You asked about X earlier" |
| Long-term | Facts & prefs | Forever | "User prefers dark mode" |
| Episodic | Past events | Long-term | "Last week you deployed v2" |

## Summary

Memory makes agents useful across sessions.

**Short-term**: Current conversation
- Sliding window
- Token-aware buffer
- Summarization

**Long-term**: Persistent facts
- Key-value store
- User profiles
- Vector search

**Episodic**: Past events
- Conversation logs
- Event timeline
- Outcome tracking

Start with short-term (conversation buffer). Add long-term when you need persistence. Add episodic when past context matters.

Give agents memory tools so they can manage their own storage. Run them with [Gantz](https://gantz.run) for easy MCP integration.

---

*How do you handle memory in your agents? What patterns have worked for you?*
