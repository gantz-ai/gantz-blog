+++
title = "Redis MCP Tools: Caching and State for AI Agents"
image = "/images/redis-mcp-tools.png"
date = 2025-12-09
description = "Build MCP tools for Redis operations. Caching, session management, pub/sub, and real-time state for AI agent systems."
draft = false
tags = ['mcp', 'redis', 'caching', 'state']
voice = false

[howto]
name = "Build Redis MCP Tools"
totalTime = 25
[[howto.steps]]
name = "Set up Redis connection"
text = "Configure Redis client with connection pooling."
[[howto.steps]]
name = "Create cache tools"
text = "Build tools for key-value operations."
[[howto.steps]]
name = "Add data structure tools"
text = "Tools for lists, sets, and hashes."
[[howto.steps]]
name = "Implement pub/sub"
text = "Real-time messaging tools."
[[howto.steps]]
name = "Add session management"
text = "Agent state and session tools."
+++


Redis is fast. AI agents need speed.

Together, they enable real-time intelligent systems.

## Why Redis + MCP

Redis provides:
- In-memory speed
- Data structures
- Pub/sub messaging
- TTL expiration

MCP tools enable:
- Agent state management
- Result caching
- Real-time communication
- Session handling

## Step 1: Redis connection

Using [Gantz](https://gantz.run):

```yaml
# gantz.yaml
name: redis-tools

env:
  REDIS_URL: ${REDIS_URL}

tools:
  - name: cache_get
    description: Get cached value
    parameters:
      - name: key
        type: string
        required: true
    script:
      command: python
      args: ["tools/cache.py", "get"]

  - name: cache_set
    description: Set cached value with TTL
    parameters:
      - name: key
        type: string
        required: true
      - name: value
        type: string
        required: true
      - name: ttl
        type: integer
        default: 3600
    script:
      command: python
      args: ["tools/cache.py", "set"]
```

Redis client setup:

```python
# lib/redis_client.py
import os
from typing import Optional, Any, Union
import redis
from redis import ConnectionPool

class RedisClient:
    """Redis client wrapper with connection pooling."""

    _instance: Optional['RedisClient'] = None
    _pool: Optional[ConnectionPool] = None

    def __new__(cls):
        if cls._instance is None:
            cls._instance = super().__new__(cls)
            cls._instance._initialize_pool()
        return cls._instance

    def _initialize_pool(self):
        """Initialize connection pool."""
        redis_url = os.environ.get('REDIS_URL', 'redis://localhost:6379/0')

        self._pool = ConnectionPool.from_url(
            redis_url,
            max_connections=10,
            decode_responses=True
        )

        self._client = redis.Redis(connection_pool=self._pool)

    @property
    def client(self) -> redis.Redis:
        return self._client

    def ping(self) -> bool:
        """Check connection."""
        try:
            return self._client.ping()
        except redis.ConnectionError:
            return False

# Global instance
redis_client = RedisClient()
```

## Step 2: Cache tools

Key-value operations:

```python
# tools/cache.py
import sys
import json
from typing import Optional, Any
from lib.redis_client import redis_client

class CacheTool:
    """Tool for cache operations."""

    def __init__(self, prefix: str = 'mcp'):
        self.prefix = prefix
        self.client = redis_client.client

    def _key(self, key: str) -> str:
        """Add prefix to key."""
        return f'{self.prefix}:{key}'

    def get(self, key: str) -> dict:
        """Get cached value."""
        try:
            full_key = self._key(key)
            value = self.client.get(full_key)

            if value is None:
                return {
                    'success': True,
                    'value': None,
                    'found': False
                }

            # Try to parse as JSON
            try:
                parsed = json.loads(value)
                return {
                    'success': True,
                    'value': parsed,
                    'found': True
                }
            except json.JSONDecodeError:
                return {
                    'success': True,
                    'value': value,
                    'found': True
                }
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def set(
        self,
        key: str,
        value: Any,
        ttl: int = 3600
    ) -> dict:
        """Set cached value with TTL."""
        try:
            full_key = self._key(key)

            # Serialize value
            if isinstance(value, (dict, list)):
                value = json.dumps(value)

            self.client.setex(full_key, ttl, value)

            return {
                'success': True,
                'key': key,
                'ttl': ttl
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def delete(self, key: str) -> dict:
        """Delete cached value."""
        try:
            full_key = self._key(key)
            deleted = self.client.delete(full_key)

            return {
                'success': True,
                'deleted': deleted > 0
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def exists(self, key: str) -> dict:
        """Check if key exists."""
        try:
            full_key = self._key(key)
            exists = self.client.exists(full_key)

            return {
                'success': True,
                'exists': exists > 0
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def ttl(self, key: str) -> dict:
        """Get remaining TTL."""
        try:
            full_key = self._key(key)
            ttl = self.client.ttl(full_key)

            return {
                'success': True,
                'ttl': ttl if ttl > 0 else None
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def keys(self, pattern: str = '*') -> dict:
        """List keys matching pattern."""
        try:
            full_pattern = self._key(pattern)
            keys = self.client.keys(full_pattern)

            # Remove prefix from keys
            prefix_len = len(self.prefix) + 1
            clean_keys = [k[prefix_len:] for k in keys]

            return {
                'success': True,
                'keys': clean_keys,
                'count': len(clean_keys)
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}

if __name__ == '__main__':
    operation = sys.argv[1] if len(sys.argv) > 1 else 'get'
    params = json.loads(sys.argv[2]) if len(sys.argv) > 2 else {}

    tool = CacheTool()

    if operation == 'get':
        result = tool.get(params.get('key', ''))
    elif operation == 'set':
        result = tool.set(
            params.get('key', ''),
            params.get('value', ''),
            params.get('ttl', 3600)
        )
    elif operation == 'delete':
        result = tool.delete(params.get('key', ''))
    else:
        result = {'success': False, 'error': f'Unknown operation: {operation}'}

    print(json.dumps(result))
```

## Step 3: Data structure tools

Lists, sets, and hashes:

```python
# tools/structures.py
import json
from lib.redis_client import redis_client

class ListTool:
    """Tool for Redis list operations."""

    def __init__(self, prefix: str = 'mcp:list'):
        self.prefix = prefix
        self.client = redis_client.client

    def _key(self, key: str) -> str:
        return f'{self.prefix}:{key}'

    def push(self, key: str, values: list, left: bool = True) -> dict:
        """Push values to list."""
        try:
            full_key = self._key(key)
            serialized = [json.dumps(v) if isinstance(v, (dict, list)) else str(v) for v in values]

            if left:
                length = self.client.lpush(full_key, *serialized)
            else:
                length = self.client.rpush(full_key, *serialized)

            return {'success': True, 'length': length}
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def pop(self, key: str, left: bool = True) -> dict:
        """Pop value from list."""
        try:
            full_key = self._key(key)

            if left:
                value = self.client.lpop(full_key)
            else:
                value = self.client.rpop(full_key)

            if value:
                try:
                    value = json.loads(value)
                except json.JSONDecodeError:
                    pass

            return {'success': True, 'value': value}
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def range(self, key: str, start: int = 0, end: int = -1) -> dict:
        """Get list range."""
        try:
            full_key = self._key(key)
            values = self.client.lrange(full_key, start, end)

            # Try to parse JSON values
            parsed = []
            for v in values:
                try:
                    parsed.append(json.loads(v))
                except json.JSONDecodeError:
                    parsed.append(v)

            return {
                'success': True,
                'values': parsed,
                'count': len(parsed)
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}

class HashTool:
    """Tool for Redis hash operations."""

    def __init__(self, prefix: str = 'mcp:hash'):
        self.prefix = prefix
        self.client = redis_client.client

    def _key(self, key: str) -> str:
        return f'{self.prefix}:{key}'

    def set(self, key: str, mapping: dict) -> dict:
        """Set hash fields."""
        try:
            full_key = self._key(key)

            # Serialize complex values
            serialized = {}
            for k, v in mapping.items():
                if isinstance(v, (dict, list)):
                    serialized[k] = json.dumps(v)
                else:
                    serialized[k] = str(v)

            self.client.hset(full_key, mapping=serialized)

            return {'success': True, 'fields': len(mapping)}
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def get(self, key: str, field: str = None) -> dict:
        """Get hash field or all fields."""
        try:
            full_key = self._key(key)

            if field:
                value = self.client.hget(full_key, field)
                if value:
                    try:
                        value = json.loads(value)
                    except json.JSONDecodeError:
                        pass
                return {'success': True, 'value': value}
            else:
                data = self.client.hgetall(full_key)
                # Parse values
                parsed = {}
                for k, v in data.items():
                    try:
                        parsed[k] = json.loads(v)
                    except json.JSONDecodeError:
                        parsed[k] = v

                return {'success': True, 'data': parsed}
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def delete(self, key: str, fields: list) -> dict:
        """Delete hash fields."""
        try:
            full_key = self._key(key)
            deleted = self.client.hdel(full_key, *fields)

            return {'success': True, 'deleted': deleted}
        except Exception as e:
            return {'success': False, 'error': str(e)}

class SetTool:
    """Tool for Redis set operations."""

    def __init__(self, prefix: str = 'mcp:set'):
        self.prefix = prefix
        self.client = redis_client.client

    def _key(self, key: str) -> str:
        return f'{self.prefix}:{key}'

    def add(self, key: str, members: list) -> dict:
        """Add members to set."""
        try:
            full_key = self._key(key)
            added = self.client.sadd(full_key, *members)

            return {'success': True, 'added': added}
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def members(self, key: str) -> dict:
        """Get all set members."""
        try:
            full_key = self._key(key)
            members = self.client.smembers(full_key)

            return {
                'success': True,
                'members': list(members),
                'count': len(members)
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def is_member(self, key: str, member: str) -> dict:
        """Check if member exists in set."""
        try:
            full_key = self._key(key)
            exists = self.client.sismember(full_key, member)

            return {'success': True, 'is_member': exists}
        except Exception as e:
            return {'success': False, 'error': str(e)}
```

## Step 4: Session management

Agent state and sessions:

```python
# tools/session.py
import json
import uuid
from datetime import datetime
from lib.redis_client import redis_client

class SessionManager:
    """Manage agent sessions in Redis."""

    def __init__(self, prefix: str = 'mcp:session'):
        self.prefix = prefix
        self.client = redis_client.client
        self.default_ttl = 3600  # 1 hour

    def _key(self, session_id: str) -> str:
        return f'{self.prefix}:{session_id}'

    def create(
        self,
        data: dict = None,
        ttl: int = None
    ) -> dict:
        """Create new session."""
        try:
            session_id = str(uuid.uuid4())
            key = self._key(session_id)

            session_data = {
                'id': session_id,
                'created_at': datetime.utcnow().isoformat(),
                'data': data or {}
            }

            self.client.setex(
                key,
                ttl or self.default_ttl,
                json.dumps(session_data)
            )

            return {
                'success': True,
                'session_id': session_id,
                'ttl': ttl or self.default_ttl
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def get(self, session_id: str) -> dict:
        """Get session data."""
        try:
            key = self._key(session_id)
            data = self.client.get(key)

            if data is None:
                return {
                    'success': True,
                    'session': None,
                    'found': False
                }

            session = json.loads(data)

            return {
                'success': True,
                'session': session,
                'found': True
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def update(
        self,
        session_id: str,
        data: dict,
        merge: bool = True
    ) -> dict:
        """Update session data."""
        try:
            key = self._key(session_id)

            # Get existing session
            existing = self.client.get(key)
            if existing is None:
                return {
                    'success': False,
                    'error': 'Session not found'
                }

            session = json.loads(existing)

            if merge:
                session['data'].update(data)
            else:
                session['data'] = data

            session['updated_at'] = datetime.utcnow().isoformat()

            # Get remaining TTL
            ttl = self.client.ttl(key)
            if ttl < 0:
                ttl = self.default_ttl

            self.client.setex(key, ttl, json.dumps(session))

            return {'success': True, 'session_id': session_id}
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def delete(self, session_id: str) -> dict:
        """Delete session."""
        try:
            key = self._key(session_id)
            deleted = self.client.delete(key)

            return {
                'success': True,
                'deleted': deleted > 0
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def extend(self, session_id: str, ttl: int = None) -> dict:
        """Extend session TTL."""
        try:
            key = self._key(session_id)

            if not self.client.exists(key):
                return {
                    'success': False,
                    'error': 'Session not found'
                }

            self.client.expire(key, ttl or self.default_ttl)

            return {
                'success': True,
                'session_id': session_id,
                'ttl': ttl or self.default_ttl
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}
```

## Step 5: Pub/Sub tools

Real-time messaging:

```python
# tools/pubsub.py
import json
import threading
from typing import Callable, Optional
from lib.redis_client import redis_client

class PubSubTool:
    """Tool for Redis pub/sub messaging."""

    def __init__(self, prefix: str = 'mcp:channel'):
        self.prefix = prefix
        self.client = redis_client.client
        self._subscriptions = {}

    def _channel(self, channel: str) -> str:
        return f'{self.prefix}:{channel}'

    def publish(self, channel: str, message: dict) -> dict:
        """Publish message to channel."""
        try:
            full_channel = self._channel(channel)
            payload = json.dumps(message)
            subscribers = self.client.publish(full_channel, payload)

            return {
                'success': True,
                'channel': channel,
                'subscribers': subscribers
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def subscribe(
        self,
        channel: str,
        callback: Callable[[dict], None]
    ) -> dict:
        """Subscribe to channel."""
        try:
            full_channel = self._channel(channel)

            pubsub = self.client.pubsub()
            pubsub.subscribe(full_channel)

            def listener():
                for message in pubsub.listen():
                    if message['type'] == 'message':
                        try:
                            data = json.loads(message['data'])
                            callback(data)
                        except json.JSONDecodeError:
                            callback({'raw': message['data']})

            thread = threading.Thread(target=listener, daemon=True)
            thread.start()

            self._subscriptions[channel] = {
                'pubsub': pubsub,
                'thread': thread
            }

            return {
                'success': True,
                'channel': channel,
                'subscribed': True
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def unsubscribe(self, channel: str) -> dict:
        """Unsubscribe from channel."""
        try:
            if channel in self._subscriptions:
                sub = self._subscriptions[channel]
                sub['pubsub'].unsubscribe()
                del self._subscriptions[channel]

            return {
                'success': True,
                'channel': channel,
                'unsubscribed': True
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}
```

## Step 6: Rate limiting

API rate limiting:

```python
# tools/rate_limit.py
import time
from lib.redis_client import redis_client

class RateLimiter:
    """Redis-based rate limiter."""

    def __init__(self, prefix: str = 'mcp:rate'):
        self.prefix = prefix
        self.client = redis_client.client

    def _key(self, identifier: str, window: str) -> str:
        return f'{self.prefix}:{identifier}:{window}'

    def check(
        self,
        identifier: str,
        limit: int,
        window_seconds: int
    ) -> dict:
        """Check if request is allowed."""
        try:
            now = int(time.time())
            window = now // window_seconds
            key = self._key(identifier, str(window))

            pipe = self.client.pipeline()
            pipe.incr(key)
            pipe.expire(key, window_seconds)
            results = pipe.execute()

            current = results[0]

            return {
                'success': True,
                'allowed': current <= limit,
                'current': current,
                'limit': limit,
                'remaining': max(0, limit - current),
                'reset_at': (window + 1) * window_seconds
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def sliding_window(
        self,
        identifier: str,
        limit: int,
        window_seconds: int
    ) -> dict:
        """Sliding window rate limit."""
        try:
            now = time.time()
            key = f'{self.prefix}:{identifier}:sliding'

            pipe = self.client.pipeline()

            # Remove old entries
            pipe.zremrangebyscore(key, 0, now - window_seconds)

            # Count current entries
            pipe.zcard(key)

            # Add current request
            pipe.zadd(key, {str(now): now})
            pipe.expire(key, window_seconds)

            results = pipe.execute()
            current = results[1]

            return {
                'success': True,
                'allowed': current < limit,
                'current': current,
                'limit': limit,
                'remaining': max(0, limit - current - 1)
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}
```

## Summary

Redis + MCP integration:

1. **Connection pooling** - Efficient connections
2. **Cache tools** - Key-value operations
3. **Data structures** - Lists, sets, hashes
4. **Sessions** - Agent state management
5. **Pub/Sub** - Real-time messaging
6. **Rate limiting** - Request throttling

Build tools with [Gantz](https://gantz.run), speed up your agents.

Fast state, fast agents.

## Related reading

- [MCP Caching](/post/mcp-caching/) - Cache strategies
- [MCP Connection Pooling](/post/mcp-connection-pooling/) - Pool connections
- [Agent State Management](/post/agent-state-management/) - State patterns

---

*How do you use Redis with AI agents? Share your patterns.*
