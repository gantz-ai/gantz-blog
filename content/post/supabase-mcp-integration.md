+++
title = "Supabase MCP Integration: Backend as a Service for AI"
image = "images/supabase-mcp-integration.webp"
date = 2025-12-15
description = "Build MCP tools for Supabase. Database queries, authentication, storage, and real-time subscriptions for AI agents."
summary = "Supabase gives you Postgres, auth, storage, and realtime in one package - now give it to your AI agents. Build MCP tools for database queries with row-level security, user authentication flows, file uploads to storage buckets, and real-time subscriptions that let agents react to database changes as they happen."
draft = false
tags = ['mcp', 'supabase', 'baas', 'database']
voice = false

[howto]
name = "Integrate Supabase with MCP"
totalTime = 30
[[howto.steps]]
name = "Set up Supabase connection"
text = "Configure Supabase client with API keys."
[[howto.steps]]
name = "Create database tools"
text = "Build tools for PostgreSQL operations."
[[howto.steps]]
name = "Add auth tools"
text = "User authentication and management."
[[howto.steps]]
name = "Implement storage tools"
text = "File upload and management."
[[howto.steps]]
name = "Add real-time tools"
text = "Subscribe to database changes."
+++


Supabase is Firebase for PostgreSQL. MCP tools unlock its full power.

Together, they enable AI-powered backend operations.

## Why Supabase + MCP

Supabase provides:
- PostgreSQL database
- Authentication
- File storage
- Real-time subscriptions

MCP tools enable:
- AI-driven queries
- Automated user management
- Intelligent file handling
- Real-time AI responses

## Step 1: Supabase connection

Using [Gantz](https://gantz.run):

```yaml
# gantz.yaml
name: supabase-tools

env:
  SUPABASE_URL: ${SUPABASE_URL}
  SUPABASE_KEY: ${SUPABASE_KEY}
  SUPABASE_SERVICE_KEY: ${SUPABASE_SERVICE_KEY}

tools:
  - name: query_table
    description: Query Supabase table
    parameters:
      - name: table
        type: string
        required: true
      - name: filters
        type: object
        required: false
    script:
      command: python
      args: ["tools/query.py"]

  - name: insert_record
    description: Insert record into table
    parameters:
      - name: table
        type: string
        required: true
      - name: data
        type: object
        required: true
    script:
      command: python
      args: ["tools/insert.py"]
```

Supabase client:

```python
# lib/supabase_client.py
import os
from typing import Optional
from supabase import create_client, Client

class SupabaseClient:
    """Supabase client wrapper."""

    _instance: Optional['SupabaseClient'] = None
    _client: Optional[Client] = None
    _admin_client: Optional[Client] = None

    def __new__(cls):
        if cls._instance is None:
            cls._instance = super().__new__(cls)
            cls._instance._initialize()
        return cls._instance

    def _initialize(self):
        """Initialize Supabase clients."""
        url = os.environ.get('SUPABASE_URL')
        key = os.environ.get('SUPABASE_KEY')
        service_key = os.environ.get('SUPABASE_SERVICE_KEY')

        self._client = create_client(url, key)

        if service_key:
            self._admin_client = create_client(url, service_key)

    @property
    def client(self) -> Client:
        """Get public client."""
        return self._client

    @property
    def admin(self) -> Client:
        """Get admin client with service key."""
        return self._admin_client or self._client

# Global instance
supabase = SupabaseClient()
```

## Step 2: Database tools

Query and modify data:

```python
# tools/database.py
import sys
import json
from lib.supabase_client import supabase

class DatabaseTool:
    """Tool for Supabase database operations."""

    def __init__(self):
        self.client = supabase.client

    def select(
        self,
        table: str,
        columns: str = '*',
        filters: dict = None,
        order_by: str = None,
        limit: int = 100,
        offset: int = 0
    ) -> dict:
        """Select records from table."""
        try:
            query = self.client.table(table).select(columns)

            # Apply filters
            if filters:
                for field, condition in filters.items():
                    if isinstance(condition, dict):
                        op = condition.get('op', 'eq')
                        value = condition.get('value')

                        if op == 'eq':
                            query = query.eq(field, value)
                        elif op == 'neq':
                            query = query.neq(field, value)
                        elif op == 'gt':
                            query = query.gt(field, value)
                        elif op == 'gte':
                            query = query.gte(field, value)
                        elif op == 'lt':
                            query = query.lt(field, value)
                        elif op == 'lte':
                            query = query.lte(field, value)
                        elif op == 'like':
                            query = query.like(field, value)
                        elif op == 'ilike':
                            query = query.ilike(field, value)
                        elif op == 'in':
                            query = query.in_(field, value)
                    else:
                        query = query.eq(field, condition)

            # Order and pagination
            if order_by:
                desc = order_by.startswith('-')
                field = order_by.lstrip('-')
                query = query.order(field, desc=desc)

            query = query.range(offset, offset + limit - 1)

            response = query.execute()

            return {
                'success': True,
                'data': response.data,
                'count': len(response.data)
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def insert(
        self,
        table: str,
        data: dict | list,
        upsert: bool = False
    ) -> dict:
        """Insert record(s) into table."""
        try:
            query = self.client.table(table)

            if upsert:
                response = query.upsert(data).execute()
            else:
                response = query.insert(data).execute()

            return {
                'success': True,
                'data': response.data,
                'count': len(response.data) if isinstance(response.data, list) else 1
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def update(
        self,
        table: str,
        data: dict,
        filters: dict
    ) -> dict:
        """Update records in table."""
        try:
            query = self.client.table(table).update(data)

            for field, value in filters.items():
                query = query.eq(field, value)

            response = query.execute()

            return {
                'success': True,
                'data': response.data,
                'count': len(response.data)
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def delete(
        self,
        table: str,
        filters: dict
    ) -> dict:
        """Delete records from table."""
        try:
            query = self.client.table(table).delete()

            for field, value in filters.items():
                query = query.eq(field, value)

            response = query.execute()

            return {
                'success': True,
                'deleted': len(response.data)
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def rpc(
        self,
        function_name: str,
        params: dict = None
    ) -> dict:
        """Call PostgreSQL function."""
        try:
            response = self.client.rpc(function_name, params or {}).execute()

            return {
                'success': True,
                'data': response.data
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}

if __name__ == '__main__':
    params = json.loads(sys.argv[1]) if len(sys.argv) > 1 else {}

    tool = DatabaseTool()
    result = tool.select(
        table=params.get('table', ''),
        filters=params.get('filters', {})
    )

    print(json.dumps(result))
```

## Step 3: Authentication tools

User management:

```python
# tools/auth.py
import json
from lib.supabase_client import supabase

class AuthTool:
    """Tool for Supabase authentication."""

    def __init__(self):
        self.client = supabase.client
        self.admin = supabase.admin

    def sign_up(
        self,
        email: str,
        password: str,
        metadata: dict = None
    ) -> dict:
        """Sign up new user."""
        try:
            response = self.client.auth.sign_up({
                'email': email,
                'password': password,
                'options': {
                    'data': metadata or {}
                }
            })

            if response.user:
                return {
                    'success': True,
                    'user': {
                        'id': response.user.id,
                        'email': response.user.email
                    }
                }
            return {'success': False, 'error': 'Sign up failed'}
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def sign_in(
        self,
        email: str,
        password: str
    ) -> dict:
        """Sign in user."""
        try:
            response = self.client.auth.sign_in_with_password({
                'email': email,
                'password': password
            })

            if response.user:
                return {
                    'success': True,
                    'user': {
                        'id': response.user.id,
                        'email': response.user.email
                    },
                    'session': {
                        'access_token': response.session.access_token,
                        'expires_at': response.session.expires_at
                    }
                }
            return {'success': False, 'error': 'Sign in failed'}
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def get_user(self, user_id: str = None) -> dict:
        """Get user details."""
        try:
            if user_id:
                # Admin: get specific user
                response = self.admin.auth.admin.get_user_by_id(user_id)
            else:
                # Get current user
                response = self.client.auth.get_user()

            if response.user:
                return {
                    'success': True,
                    'user': {
                        'id': response.user.id,
                        'email': response.user.email,
                        'created_at': response.user.created_at,
                        'metadata': response.user.user_metadata
                    }
                }
            return {'success': False, 'error': 'User not found'}
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def list_users(
        self,
        page: int = 1,
        per_page: int = 50
    ) -> dict:
        """List all users (admin only)."""
        try:
            response = self.admin.auth.admin.list_users(
                page=page,
                per_page=per_page
            )

            return {
                'success': True,
                'users': [
                    {
                        'id': u.id,
                        'email': u.email,
                        'created_at': u.created_at
                    }
                    for u in response
                ],
                'count': len(response)
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def update_user(
        self,
        user_id: str,
        updates: dict
    ) -> dict:
        """Update user (admin only)."""
        try:
            response = self.admin.auth.admin.update_user_by_id(
                user_id,
                updates
            )

            return {
                'success': True,
                'user': {
                    'id': response.user.id,
                    'email': response.user.email
                }
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}
```

## Step 4: Storage tools

File management:

```python
# tools/storage.py
import json
import base64
from lib.supabase_client import supabase

class StorageTool:
    """Tool for Supabase storage."""

    def __init__(self, bucket: str = 'default'):
        self.client = supabase.client
        self.bucket = bucket

    def upload(
        self,
        path: str,
        file_content: bytes | str,
        content_type: str = 'application/octet-stream'
    ) -> dict:
        """Upload file to storage."""
        try:
            # Handle base64 encoded content
            if isinstance(file_content, str):
                file_content = base64.b64decode(file_content)

            response = self.client.storage.from_(self.bucket).upload(
                path,
                file_content,
                {'content-type': content_type}
            )

            return {
                'success': True,
                'path': path,
                'bucket': self.bucket
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def download(self, path: str) -> dict:
        """Download file from storage."""
        try:
            response = self.client.storage.from_(self.bucket).download(path)

            return {
                'success': True,
                'content': base64.b64encode(response).decode('utf-8'),
                'path': path
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def get_public_url(self, path: str) -> dict:
        """Get public URL for file."""
        try:
            url = self.client.storage.from_(self.bucket).get_public_url(path)

            return {
                'success': True,
                'url': url,
                'path': path
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def create_signed_url(
        self,
        path: str,
        expires_in: int = 3600
    ) -> dict:
        """Create signed URL for private file."""
        try:
            response = self.client.storage.from_(self.bucket).create_signed_url(
                path,
                expires_in
            )

            return {
                'success': True,
                'signed_url': response['signedURL'],
                'expires_in': expires_in
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def list_files(
        self,
        path: str = '',
        limit: int = 100
    ) -> dict:
        """List files in path."""
        try:
            response = self.client.storage.from_(self.bucket).list(
                path,
                {'limit': limit}
            )

            return {
                'success': True,
                'files': [
                    {
                        'name': f['name'],
                        'size': f.get('metadata', {}).get('size'),
                        'created_at': f.get('created_at')
                    }
                    for f in response
                ]
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def delete(self, paths: list) -> dict:
        """Delete files."""
        try:
            self.client.storage.from_(self.bucket).remove(paths)

            return {
                'success': True,
                'deleted': paths
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}
```

## Step 5: Real-time tools

Subscribe to changes:

```python
# tools/realtime.py
import json
import asyncio
from lib.supabase_client import supabase

class RealtimeTool:
    """Tool for Supabase real-time subscriptions."""

    def __init__(self):
        self.client = supabase.client
        self.subscriptions = {}

    def subscribe_table(
        self,
        table: str,
        event: str = '*',
        callback = None
    ) -> dict:
        """Subscribe to table changes."""
        try:
            channel = self.client.channel(f'{table}_changes')

            def handle_change(payload):
                if callback:
                    callback(payload)
                else:
                    print(json.dumps(payload))

            channel.on_postgres_changes(
                event=event,
                schema='public',
                table=table,
                callback=handle_change
            ).subscribe()

            self.subscriptions[table] = channel

            return {
                'success': True,
                'subscribed': table,
                'event': event
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def unsubscribe(self, table: str) -> dict:
        """Unsubscribe from table."""
        try:
            if table in self.subscriptions:
                self.subscriptions[table].unsubscribe()
                del self.subscriptions[table]

            return {
                'success': True,
                'unsubscribed': table
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def broadcast(
        self,
        channel: str,
        event: str,
        payload: dict
    ) -> dict:
        """Broadcast message to channel."""
        try:
            self.client.channel(channel).send_broadcast(
                event,
                payload
            )

            return {
                'success': True,
                'channel': channel,
                'event': event
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}
```

## Step 6: AI-powered queries

Natural language to Supabase:

```python
# tools/nl_query.py
import json
import anthropic
from lib.supabase_client import supabase

class NaturalLanguageQuery:
    """Convert natural language to Supabase queries."""

    def __init__(self):
        self.client = supabase.client
        self.anthropic = anthropic.Anthropic()

    def get_schema(self) -> str:
        """Get database schema for context."""
        # Query information_schema
        response = self.client.rpc('get_table_info', {}).execute()
        return json.dumps(response.data, indent=2)

    def generate_query(self, question: str) -> dict:
        """Generate Supabase query from question."""
        schema = self.get_schema()

        prompt = f"""Given this Supabase/PostgreSQL schema:
{schema}

Convert this question to a Supabase Python query:
{question}

Return a JSON object with:
- table: the table name
- operation: 'select', 'insert', 'update', or 'delete'
- columns: columns to select (for select)
- filters: filter conditions
- data: data to insert/update

Return ONLY the JSON."""

        try:
            response = self.anthropic.messages.create(
                model="claude-sonnet-4-20250514",
                max_tokens=500,
                messages=[{"role": "user", "content": prompt}]
            )

            query = json.loads(response.content[0].text.strip())

            return {
                'success': True,
                'query': query,
                'question': question
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def query(self, question: str) -> dict:
        """Execute natural language query."""
        result = self.generate_query(question)

        if not result['success']:
            return result

        query = result['query']
        db = DatabaseTool()

        if query['operation'] == 'select':
            return db.select(
                table=query['table'],
                columns=query.get('columns', '*'),
                filters=query.get('filters')
            )
        elif query['operation'] == 'insert':
            return db.insert(
                table=query['table'],
                data=query['data']
            )

        return {'success': False, 'error': 'Unsupported operation'}
```

## Summary

Supabase + MCP integration:

1. **Database tools** - CRUD operations
2. **Authentication** - User management
3. **Storage** - File handling
4. **Real-time** - Subscriptions
5. **Natural language** - AI-powered queries

Build tools with [Gantz](https://gantz.run), power your backend.

Backend meets intelligence.

## Related reading

- [Firebase MCP Integration](/post/firebase-mcp-integration/) - Alternative BaaS
- [PostgreSQL MCP Integration](/post/postgresql-mcp-integration/) - Direct SQL
- [Agent Auth Patterns](/post/agent-auth-patterns/) - Authentication

---

*How do you integrate Supabase with AI agents? Share your patterns.*
