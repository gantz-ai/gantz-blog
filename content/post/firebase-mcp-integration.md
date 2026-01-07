+++
title = "Firebase MCP Integration: Google Cloud for AI Agents"
image = "images/firebase-mcp-integration.webp"
date = 2025-12-17
description = "Build MCP tools for Firebase. Firestore, Authentication, Cloud Storage, and real-time database tools for AI applications."
draft = false
tags = ['mcp', 'firebase', 'google', 'baas']
voice = false

[howto]
name = "Integrate Firebase with MCP"
totalTime = 30
[[howto.steps]]
name = "Set up Firebase connection"
text = "Configure Firebase Admin SDK."
[[howto.steps]]
name = "Create Firestore tools"
text = "Build document database tools."
[[howto.steps]]
name = "Add auth tools"
text = "User authentication management."
[[howto.steps]]
name = "Implement storage tools"
text = "Cloud Storage file handling."
[[howto.steps]]
name = "Add real-time tools"
text = "Real-time Database operations."
+++


Firebase powers millions of apps. MCP tools add AI intelligence.

Together, they enable smart application backends.

## Why Firebase + MCP

Firebase provides:
- Firestore document database
- Authentication
- Cloud Storage
- Real-time Database

MCP tools enable:
- AI-driven queries
- Automated user management
- Intelligent file processing
- Real-time AI responses

## Step 1: Firebase connection

Using [Gantz](https://gantz.run):

```yaml
# gantz.yaml
name: firebase-tools

env:
  GOOGLE_APPLICATION_CREDENTIALS: ${GOOGLE_APPLICATION_CREDENTIALS}
  FIREBASE_PROJECT_ID: ${FIREBASE_PROJECT_ID}

tools:
  - name: firestore_query
    description: Query Firestore collection
    parameters:
      - name: collection
        type: string
        required: true
      - name: filters
        type: array
        required: false
    script:
      command: python
      args: ["tools/firestore.py", "query"]

  - name: firestore_add
    description: Add document to Firestore
    parameters:
      - name: collection
        type: string
        required: true
      - name: data
        type: object
        required: true
    script:
      command: python
      args: ["tools/firestore.py", "add"]
```

Firebase client:

```python
# lib/firebase_client.py
import os
from typing import Optional
import firebase_admin
from firebase_admin import credentials, firestore, auth, storage

class FirebaseClient:
    """Firebase Admin SDK wrapper."""

    _instance: Optional['FirebaseClient'] = None
    _app: Optional[firebase_admin.App] = None

    def __new__(cls):
        if cls._instance is None:
            cls._instance = super().__new__(cls)
            cls._instance._initialize()
        return cls._instance

    def _initialize(self):
        """Initialize Firebase Admin SDK."""
        cred_path = os.environ.get('GOOGLE_APPLICATION_CREDENTIALS')
        project_id = os.environ.get('FIREBASE_PROJECT_ID')

        if cred_path:
            cred = credentials.Certificate(cred_path)
        else:
            cred = credentials.ApplicationDefault()

        self._app = firebase_admin.initialize_app(cred, {
            'projectId': project_id,
            'storageBucket': f'{project_id}.appspot.com'
        })

    @property
    def firestore(self):
        """Get Firestore client."""
        return firestore.client()

    @property
    def auth(self):
        """Get Auth client."""
        return auth

    @property
    def storage(self):
        """Get Storage bucket."""
        return storage.bucket()

# Global instance
firebase = FirebaseClient()
```

## Step 2: Firestore tools

Document database operations:

```python
# tools/firestore.py
import sys
import json
from datetime import datetime
from google.cloud.firestore_v1 import FieldFilter
from lib.firebase_client import firebase

class FirestoreTool:
    """Tool for Firestore operations."""

    def __init__(self):
        self.db = firebase.firestore

    def query(
        self,
        collection: str,
        filters: list = None,
        order_by: str = None,
        limit: int = 100
    ) -> dict:
        """Query documents from collection."""
        try:
            ref = self.db.collection(collection)

            # Apply filters
            if filters:
                for f in filters:
                    field = f.get('field')
                    op = f.get('op', '==')
                    value = f.get('value')

                    ref = ref.where(filter=FieldFilter(field, op, value))

            # Order and limit
            if order_by:
                desc = order_by.startswith('-')
                field = order_by.lstrip('-')
                direction = firestore.Query.DESCENDING if desc else firestore.Query.ASCENDING
                ref = ref.order_by(field, direction=direction)

            ref = ref.limit(limit)

            docs = ref.stream()

            results = []
            for doc in docs:
                data = doc.to_dict()
                data['_id'] = doc.id
                results.append(data)

            return {
                'success': True,
                'data': results,
                'count': len(results)
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def get(self, collection: str, doc_id: str) -> dict:
        """Get single document."""
        try:
            doc = self.db.collection(collection).document(doc_id).get()

            if doc.exists:
                data = doc.to_dict()
                data['_id'] = doc.id
                return {'success': True, 'data': data}

            return {
                'success': True,
                'data': None,
                'message': 'Document not found'
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def add(
        self,
        collection: str,
        data: dict,
        doc_id: str = None
    ) -> dict:
        """Add document to collection."""
        try:
            # Add timestamp
            data['created_at'] = datetime.utcnow()

            if doc_id:
                self.db.collection(collection).document(doc_id).set(data)
                return {
                    'success': True,
                    'id': doc_id
                }
            else:
                doc_ref = self.db.collection(collection).add(data)
                return {
                    'success': True,
                    'id': doc_ref[1].id
                }
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def update(
        self,
        collection: str,
        doc_id: str,
        data: dict
    ) -> dict:
        """Update document."""
        try:
            data['updated_at'] = datetime.utcnow()

            self.db.collection(collection).document(doc_id).update(data)

            return {
                'success': True,
                'id': doc_id
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def delete(self, collection: str, doc_id: str) -> dict:
        """Delete document."""
        try:
            self.db.collection(collection).document(doc_id).delete()

            return {
                'success': True,
                'deleted': doc_id
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def batch_add(
        self,
        collection: str,
        documents: list
    ) -> dict:
        """Batch add documents."""
        try:
            batch = self.db.batch()
            doc_ids = []

            for doc_data in documents:
                doc_ref = self.db.collection(collection).document()
                doc_data['created_at'] = datetime.utcnow()
                batch.set(doc_ref, doc_data)
                doc_ids.append(doc_ref.id)

            batch.commit()

            return {
                'success': True,
                'ids': doc_ids,
                'count': len(doc_ids)
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def aggregate(
        self,
        collection: str,
        aggregations: list
    ) -> dict:
        """Run aggregation query."""
        try:
            ref = self.db.collection(collection)

            results = {}
            for agg in aggregations:
                agg_type = agg.get('type')
                field = agg.get('field')
                alias = agg.get('alias', field)

                if agg_type == 'count':
                    query = ref.count()
                    results[alias] = query.get()[0][0].value
                elif agg_type == 'sum':
                    query = ref.sum(field)
                    results[alias] = query.get()[0][0].value
                elif agg_type == 'average':
                    query = ref.average(field)
                    results[alias] = query.get()[0][0].value

            return {
                'success': True,
                'aggregations': results
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}

if __name__ == '__main__':
    operation = sys.argv[1] if len(sys.argv) > 1 else 'query'
    params = json.loads(sys.argv[2]) if len(sys.argv) > 2 else {}

    tool = FirestoreTool()

    if operation == 'query':
        result = tool.query(
            collection=params.get('collection', ''),
            filters=params.get('filters', [])
        )
    elif operation == 'add':
        result = tool.add(
            collection=params.get('collection', ''),
            data=params.get('data', {})
        )
    else:
        result = {'success': False, 'error': f'Unknown operation: {operation}'}

    print(json.dumps(result, default=str))
```

## Step 3: Authentication tools

User management:

```python
# tools/auth.py
import json
from lib.firebase_client import firebase

class AuthTool:
    """Tool for Firebase Authentication."""

    def __init__(self):
        self.auth = firebase.auth

    def create_user(
        self,
        email: str,
        password: str,
        display_name: str = None,
        phone_number: str = None
    ) -> dict:
        """Create new user."""
        try:
            user = self.auth.create_user(
                email=email,
                password=password,
                display_name=display_name,
                phone_number=phone_number
            )

            return {
                'success': True,
                'user': {
                    'uid': user.uid,
                    'email': user.email,
                    'display_name': user.display_name
                }
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def get_user(self, uid: str = None, email: str = None) -> dict:
        """Get user by UID or email."""
        try:
            if uid:
                user = self.auth.get_user(uid)
            elif email:
                user = self.auth.get_user_by_email(email)
            else:
                return {'success': False, 'error': 'uid or email required'}

            return {
                'success': True,
                'user': {
                    'uid': user.uid,
                    'email': user.email,
                    'display_name': user.display_name,
                    'disabled': user.disabled,
                    'email_verified': user.email_verified,
                    'created_at': user.user_metadata.creation_timestamp
                }
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def list_users(self, max_results: int = 100) -> dict:
        """List all users."""
        try:
            users = []
            page = self.auth.list_users(max_results=max_results)

            for user in page.iterate_all():
                users.append({
                    'uid': user.uid,
                    'email': user.email,
                    'display_name': user.display_name
                })

            return {
                'success': True,
                'users': users,
                'count': len(users)
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def update_user(
        self,
        uid: str,
        updates: dict
    ) -> dict:
        """Update user."""
        try:
            user = self.auth.update_user(uid, **updates)

            return {
                'success': True,
                'user': {
                    'uid': user.uid,
                    'email': user.email
                }
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def delete_user(self, uid: str) -> dict:
        """Delete user."""
        try:
            self.auth.delete_user(uid)
            return {'success': True, 'deleted': uid}
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def create_custom_token(
        self,
        uid: str,
        claims: dict = None
    ) -> dict:
        """Create custom authentication token."""
        try:
            token = self.auth.create_custom_token(uid, claims)

            return {
                'success': True,
                'token': token.decode('utf-8')
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def set_custom_claims(
        self,
        uid: str,
        claims: dict
    ) -> dict:
        """Set custom claims for user."""
        try:
            self.auth.set_custom_user_claims(uid, claims)

            return {
                'success': True,
                'uid': uid,
                'claims': claims
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}
```

## Step 4: Cloud Storage tools

File operations:

```python
# tools/storage.py
import json
import base64
from datetime import timedelta
from lib.firebase_client import firebase

class StorageTool:
    """Tool for Firebase Cloud Storage."""

    def __init__(self):
        self.bucket = firebase.storage

    def upload(
        self,
        path: str,
        content: bytes | str,
        content_type: str = 'application/octet-stream'
    ) -> dict:
        """Upload file to storage."""
        try:
            # Handle base64 content
            if isinstance(content, str):
                content = base64.b64decode(content)

            blob = self.bucket.blob(path)
            blob.upload_from_string(content, content_type=content_type)

            return {
                'success': True,
                'path': path,
                'size': len(content)
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def download(self, path: str) -> dict:
        """Download file from storage."""
        try:
            blob = self.bucket.blob(path)
            content = blob.download_as_bytes()

            return {
                'success': True,
                'content': base64.b64encode(content).decode('utf-8'),
                'path': path,
                'size': len(content)
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def get_url(
        self,
        path: str,
        expiration: int = 3600
    ) -> dict:
        """Get signed URL for file."""
        try:
            blob = self.bucket.blob(path)
            url = blob.generate_signed_url(
                expiration=timedelta(seconds=expiration),
                method='GET'
            )

            return {
                'success': True,
                'url': url,
                'expires_in': expiration
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def list_files(
        self,
        prefix: str = '',
        max_results: int = 100
    ) -> dict:
        """List files in storage."""
        try:
            blobs = self.bucket.list_blobs(
                prefix=prefix,
                max_results=max_results
            )

            files = []
            for blob in blobs:
                files.append({
                    'name': blob.name,
                    'size': blob.size,
                    'content_type': blob.content_type,
                    'updated': blob.updated.isoformat() if blob.updated else None
                })

            return {
                'success': True,
                'files': files,
                'count': len(files)
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def delete(self, path: str) -> dict:
        """Delete file from storage."""
        try:
            blob = self.bucket.blob(path)
            blob.delete()

            return {
                'success': True,
                'deleted': path
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def copy(self, source: str, destination: str) -> dict:
        """Copy file to new location."""
        try:
            source_blob = self.bucket.blob(source)
            self.bucket.copy_blob(source_blob, self.bucket, destination)

            return {
                'success': True,
                'source': source,
                'destination': destination
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}
```

## Step 5: Real-time Database

Real-time data operations:

```python
# tools/realtime_db.py
import json
from firebase_admin import db as rtdb

class RealtimeDatabaseTool:
    """Tool for Firebase Realtime Database."""

    def __init__(self, database_url: str = None):
        self.db = rtdb

    def get(self, path: str) -> dict:
        """Get data at path."""
        try:
            ref = self.db.reference(path)
            data = ref.get()

            return {
                'success': True,
                'data': data,
                'path': path
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def set(self, path: str, data: dict) -> dict:
        """Set data at path."""
        try:
            ref = self.db.reference(path)
            ref.set(data)

            return {
                'success': True,
                'path': path
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def push(self, path: str, data: dict) -> dict:
        """Push new child to path."""
        try:
            ref = self.db.reference(path)
            new_ref = ref.push(data)

            return {
                'success': True,
                'key': new_ref.key,
                'path': f'{path}/{new_ref.key}'
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def update(self, path: str, data: dict) -> dict:
        """Update data at path."""
        try:
            ref = self.db.reference(path)
            ref.update(data)

            return {
                'success': True,
                'path': path
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def delete(self, path: str) -> dict:
        """Delete data at path."""
        try:
            ref = self.db.reference(path)
            ref.delete()

            return {
                'success': True,
                'deleted': path
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def query(
        self,
        path: str,
        order_by: str = None,
        equal_to = None,
        limit_first: int = None,
        limit_last: int = None
    ) -> dict:
        """Query data with filters."""
        try:
            ref = self.db.reference(path)

            if order_by:
                ref = ref.order_by_child(order_by)

            if equal_to is not None:
                ref = ref.equal_to(equal_to)

            if limit_first:
                ref = ref.limit_to_first(limit_first)
            elif limit_last:
                ref = ref.limit_to_last(limit_last)

            data = ref.get()

            return {
                'success': True,
                'data': data
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}
```

## Summary

Firebase + MCP integration:

1. **Firestore** - Document database
2. **Authentication** - User management
3. **Cloud Storage** - File handling
4. **Realtime Database** - Real-time data

Build tools with [Gantz](https://gantz.run), power your Firebase.

Google Cloud meets AI.

## Related reading

- [Supabase MCP Integration](/post/supabase-mcp-integration/) - Alternative BaaS
- [MCP Caching](/post/mcp-caching/) - Cache Firebase data
- [Agent Auth Patterns](/post/agent-auth-patterns/) - Authentication

---

*How do you integrate Firebase with AI agents? Share your approach.*
