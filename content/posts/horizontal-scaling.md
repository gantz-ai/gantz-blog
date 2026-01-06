+++
title = 'Horizontal Scaling for Stateful Agents'
date = 2025-12-18
draft = false
tags = ['agents', 'ai', 'mcp']
+++


Your agent works great on one server.

Then you get traffic. You add a second server.

Now half your users get "I don't remember our conversation."

Welcome to stateful scaling.

## The problem

Agents are stateful. Each conversation builds on previous messages.

```python
# Single server - works fine
class Agent:
    def __init__(self):
        self.conversations = {}  # In memory

    def respond(self, session_id, message):
        if session_id not in self.conversations:
            self.conversations[session_id] = []

        self.conversations[session_id].append(message)
        return self.generate_response(self.conversations[session_id])
```

Add a second server:

```
Request 1 → Server A → conversation stored in A's memory
Request 2 → Server B → "What conversation?"
```

Load balancer doesn't know about your state. It just picks a server.

## Solution 1: Sticky sessions

Force users to the same server.

```nginx
# nginx.conf
upstream agents {
    ip_hash;  # Same IP → same server
    server agent1:8000;
    server agent2:8000;
}
```

Or with cookies:

```nginx
upstream agents {
    server agent1:8000;
    server agent2:8000;
    sticky cookie srv_id expires=1h;
}
```

### Pros
- Simple to implement
- No code changes needed
- Low latency (no external state lookup)

### Cons
- Server dies → all its sessions are lost
- Uneven load distribution
- Can't scale down without losing sessions
- Health checks become complicated

Sticky sessions work for small scale. They break at real scale.

## Solution 2: External state store

Move conversations out of memory.

```python
import redis
import json

class ScalableAgent:
    def __init__(self):
        self.redis = redis.Redis(host='redis', port=6379)
        self.ttl = 3600  # 1 hour expiry

    def get_conversation(self, session_id):
        data = self.redis.get(f"conv:{session_id}")
        if data:
            return json.loads(data)
        return []

    def save_conversation(self, session_id, messages):
        self.redis.setex(
            f"conv:{session_id}",
            self.ttl,
            json.dumps(messages)
        )

    def respond(self, session_id, message):
        conversation = self.get_conversation(session_id)
        conversation.append({"role": "user", "content": message})

        response = self.generate_response(conversation)

        conversation.append({"role": "assistant", "content": response})
        self.save_conversation(session_id, conversation)

        return response
```

Now any server can handle any request:

```
Request 1 → Server A → saves to Redis
Request 2 → Server B → loads from Redis → continues conversation
```

### Database options

| Store | Best for | Watch out |
|-------|----------|-----------|
| Redis | Fast access, short TTL | Memory limits, no persistence by default |
| PostgreSQL | Durability, complex queries | Slower, connection pooling needed |
| MongoDB | Flexible schema, large docs | Can get expensive |
| DynamoDB | AWS scale, pay-per-request | Costs at high volume |

### Redis implementation

```python
import redis
import json
from datetime import datetime

class ConversationStore:
    def __init__(self, redis_url="redis://localhost:6379"):
        self.redis = redis.from_url(redis_url)

    def save(self, session_id: str, messages: list, metadata: dict = None):
        data = {
            "messages": messages,
            "metadata": metadata or {},
            "updated_at": datetime.utcnow().isoformat()
        }
        self.redis.setex(
            f"conv:{session_id}",
            3600,  # 1 hour TTL
            json.dumps(data)
        )

    def load(self, session_id: str) -> dict:
        data = self.redis.get(f"conv:{session_id}")
        if not data:
            return {"messages": [], "metadata": {}}
        return json.loads(data)

    def delete(self, session_id: str):
        self.redis.delete(f"conv:{session_id}")

    def extend_ttl(self, session_id: str, seconds: int = 3600):
        self.redis.expire(f"conv:{session_id}", seconds)
```

### PostgreSQL implementation

```python
from sqlalchemy import create_engine, Column, String, JSON, DateTime
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
from datetime import datetime

Base = declarative_base()

class Conversation(Base):
    __tablename__ = 'conversations'

    session_id = Column(String, primary_key=True)
    messages = Column(JSON, default=[])
    metadata = Column(JSON, default={})
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

class ConversationStore:
    def __init__(self, database_url):
        self.engine = create_engine(database_url)
        Base.metadata.create_all(self.engine)
        self.Session = sessionmaker(bind=self.engine)

    def save(self, session_id: str, messages: list, metadata: dict = None):
        session = self.Session()
        try:
            conv = session.query(Conversation).filter_by(session_id=session_id).first()
            if conv:
                conv.messages = messages
                conv.metadata = metadata or conv.metadata
            else:
                conv = Conversation(
                    session_id=session_id,
                    messages=messages,
                    metadata=metadata or {}
                )
                session.add(conv)
            session.commit()
        finally:
            session.close()

    def load(self, session_id: str) -> dict:
        session = self.Session()
        try:
            conv = session.query(Conversation).filter_by(session_id=session_id).first()
            if not conv:
                return {"messages": [], "metadata": {}}
            return {"messages": conv.messages, "metadata": conv.metadata}
        finally:
            session.close()
```

## Solution 3: Stateless with client-side state

Push state to the client.

```python
from fastapi import FastAPI, Request
import json
import base64

app = FastAPI()

@app.post("/chat")
async def chat(request: Request):
    body = await request.json()

    # State comes from client
    encoded_state = body.get("state", "")
    if encoded_state:
        conversation = json.loads(base64.b64decode(encoded_state))
    else:
        conversation = []

    # Add new message
    conversation.append({"role": "user", "content": body["message"]})

    # Generate response
    response = generate_response(conversation)
    conversation.append({"role": "assistant", "content": response})

    # Return state to client
    new_state = base64.b64encode(json.dumps(conversation).encode()).decode()

    return {
        "response": response,
        "state": new_state  # Client stores this
    }
```

Client sends state with each request:

```javascript
let conversationState = "";

async function sendMessage(message) {
    const response = await fetch("/chat", {
        method: "POST",
        body: JSON.stringify({
            message: message,
            state: conversationState  // Send current state
        })
    });

    const data = await response.json();
    conversationState = data.state;  // Save new state
    return data.response;
}
```

### Pros
- Truly stateless servers
- Infinite horizontal scale
- No database needed

### Cons
- State grows with conversation (bandwidth)
- Client can tamper with state
- Can't query conversations server-side
- State lost if client clears storage

### Securing client-side state

Sign and encrypt:

```python
from cryptography.fernet import Fernet
import hmac
import hashlib

SECRET_KEY = b"your-secret-key-here"
FERNET_KEY = Fernet.generate_key()
cipher = Fernet(FERNET_KEY)

def encode_state(conversation):
    data = json.dumps(conversation).encode()

    # Encrypt
    encrypted = cipher.encrypt(data)

    # Sign
    signature = hmac.new(SECRET_KEY, encrypted, hashlib.sha256).hexdigest()

    return f"{encrypted.decode()}:{signature}"

def decode_state(state):
    try:
        encrypted, signature = state.rsplit(":", 1)

        # Verify signature
        expected = hmac.new(SECRET_KEY, encrypted.encode(), hashlib.sha256).hexdigest()
        if not hmac.compare_digest(signature, expected):
            raise ValueError("Invalid signature")

        # Decrypt
        data = cipher.decrypt(encrypted.encode())
        return json.loads(data)
    except:
        return []  # Invalid state, start fresh
```

## Solution 4: Hybrid approach

Redis for hot state, database for persistence.

```python
class HybridStore:
    def __init__(self, redis_url, database_url):
        self.redis = redis.from_url(redis_url)
        self.db = PostgresStore(database_url)
        self.cache_ttl = 300  # 5 min cache

    def load(self, session_id: str):
        # Try cache first
        cached = self.redis.get(f"conv:{session_id}")
        if cached:
            return json.loads(cached)

        # Fall back to database
        data = self.db.load(session_id)
        if data["messages"]:
            # Warm the cache
            self.redis.setex(f"conv:{session_id}", self.cache_ttl, json.dumps(data))

        return data

    def save(self, session_id: str, messages: list, metadata: dict = None):
        data = {"messages": messages, "metadata": metadata or {}}

        # Write to cache (fast)
        self.redis.setex(f"conv:{session_id}", self.cache_ttl, json.dumps(data))

        # Write to database (durable) - can be async
        self.db.save(session_id, messages, metadata)
```

Best of both worlds:
- Fast reads from Redis
- Durable writes to database
- Survives Redis restart

## Handling concurrent requests

Same user sends two messages at once. Race condition.

```
Request 1: Load conversation [A, B]
Request 2: Load conversation [A, B]
Request 1: Append C, save [A, B, C]
Request 2: Append D, save [A, B, D]  # Lost C!
```

### Solution: Optimistic locking

```python
class VersionedStore:
    def load(self, session_id: str):
        data = self.redis.get(f"conv:{session_id}")
        if not data:
            return {"messages": [], "version": 0}

        parsed = json.loads(data)
        return parsed

    def save(self, session_id: str, messages: list, expected_version: int):
        key = f"conv:{session_id}"

        # Lua script for atomic check-and-set
        script = """
        local current = redis.call('GET', KEYS[1])
        local current_version = 0
        if current then
            current_version = cjson.decode(current).version
        end

        if current_version ~= tonumber(ARGV[1]) then
            return 0  -- Version mismatch
        end

        redis.call('SETEX', KEYS[1], 3600, ARGV[2])
        return 1
        """

        new_data = json.dumps({
            "messages": messages,
            "version": expected_version + 1
        })

        result = self.redis.eval(script, 1, key, expected_version, new_data)

        if result == 0:
            raise ConcurrencyError("Conversation was modified")

        return True
```

Usage:

```python
def respond(self, session_id, message):
    max_retries = 3

    for attempt in range(max_retries):
        try:
            data = self.store.load(session_id)
            conversation = data["messages"]
            version = data["version"]

            conversation.append({"role": "user", "content": message})
            response = self.generate_response(conversation)
            conversation.append({"role": "assistant", "content": response})

            self.store.save(session_id, conversation, version)
            return response

        except ConcurrencyError:
            if attempt == max_retries - 1:
                raise
            continue  # Retry with fresh state
```

### Solution: Request queuing

Process one request per session at a time.

```python
class QueuedAgent:
    def __init__(self):
        self.locks = {}  # Per-session locks

    async def respond(self, session_id, message):
        # Get or create lock for this session
        if session_id not in self.locks:
            self.locks[session_id] = asyncio.Lock()

        async with self.locks[session_id]:
            # Only one request per session at a time
            return await self._respond(session_id, message)
```

For distributed locks:

```python
import redis

class DistributedLock:
    def __init__(self, redis_client, lock_name, ttl=30):
        self.redis = redis_client
        self.lock_name = lock_name
        self.ttl = ttl

    def acquire(self):
        return self.redis.set(
            f"lock:{self.lock_name}",
            "1",
            nx=True,  # Only if not exists
            ex=self.ttl
        )

    def release(self):
        self.redis.delete(f"lock:{self.lock_name}")

# Usage
lock = DistributedLock(redis, f"session:{session_id}")
if lock.acquire():
    try:
        response = process_message(session_id, message)
    finally:
        lock.release()
else:
    return {"error": "Request in progress, please wait"}
```

## Load balancing strategies

### Round robin (default)
```
Request 1 → Server A
Request 2 → Server B
Request 3 → Server A
```
Works with external state store.

### Least connections
```nginx
upstream agents {
    least_conn;
    server agent1:8000;
    server agent2:8000;
}
```
Better for long-running agent requests.

### Weighted (for heterogeneous servers)
```nginx
upstream agents {
    server agent1:8000 weight=3;  # 3x capacity
    server agent2:8000 weight=1;
}
```

## Health checks

Don't just check if server responds. Check if it can actually process.

```python
from fastapi import FastAPI
from datetime import datetime

app = FastAPI()
last_successful_response = datetime.utcnow()

@app.get("/health")
async def health():
    # Check Redis connection
    try:
        redis.ping()
    except:
        return {"status": "unhealthy", "reason": "redis"}, 503

    # Check if we've processed recently (not stuck)
    seconds_since_success = (datetime.utcnow() - last_successful_response).seconds
    if seconds_since_success > 300:  # 5 min
        return {"status": "unhealthy", "reason": "no recent success"}, 503

    return {"status": "healthy"}

@app.post("/chat")
async def chat(message: str):
    global last_successful_response
    response = process(message)
    last_successful_response = datetime.utcnow()
    return response
```

## Architecture diagram

```
                         ┌─────────────────┐
                         │  Load Balancer  │
                         │  (Round Robin)  │
                         └────────┬────────┘
                                  │
              ┌───────────────────┼───────────────────┐
              │                   │                   │
              ▼                   ▼                   ▼
       ┌──────────┐        ┌──────────┐        ┌──────────┐
       │ Agent 1  │        │ Agent 2  │        │ Agent 3  │
       │ (stateless)       │ (stateless)       │ (stateless)
       └─────┬────┘        └─────┬────┘        └─────┬────┘
             │                   │                   │
             └───────────────────┼───────────────────┘
                                 │
                    ┌────────────┴────────────┐
                    │                         │
                    ▼                         ▼
             ┌──────────┐              ┌──────────┐
             │  Redis   │              │ Postgres │
             │ (cache)  │              │ (durable)│
             └──────────┘              └──────────┘
```

## Scaling with Gantz

With [Gantz](https://gantz.run), you can run stateless tool servers and manage state separately:

```yaml
# docker-compose.yml
services:
  gantz:
    image: gantz/gantz
    deploy:
      replicas: 3  # Scale horizontally
    environment:
      - REDIS_URL=redis://redis:6379

  redis:
    image: redis:alpine

  postgres:
    image: postgres:15
    volumes:
      - pgdata:/var/lib/postgresql/data
```

Tools are stateless. Conversations live in Redis/Postgres.

## Summary

| Approach | Complexity | Durability | Scale |
|----------|------------|------------|-------|
| Sticky sessions | Low | Poor | Limited |
| Redis | Medium | Medium | High |
| PostgreSQL | Medium | High | High |
| Client-side | Low | None* | Unlimited |
| Hybrid | High | High | High |

For most cases: **Redis for conversations, PostgreSQL for long-term storage.**

Start simple. Add complexity when you need it.

---

*How do you scale your stateful agents?*
