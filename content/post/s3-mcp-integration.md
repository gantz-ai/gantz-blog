+++
title = "S3 MCP Integration: Cloud Storage for AI Agents"
image = "/images/s3-mcp-integration.png"
date = 2025-12-23
description = "Build MCP tools for Amazon S3. Object storage, file management, and cloud data operations for AI applications."
draft = false
tags = ['mcp', 's3', 'aws', 'storage']
voice = false

[howto]
name = "Integrate S3 with MCP"
totalTime = 25
[[howto.steps]]
name = "Set up S3 connection"
text = "Configure AWS credentials and client."
[[howto.steps]]
name = "Create object tools"
text = "Upload, download, and manage objects."
[[howto.steps]]
name = "Add bucket tools"
text = "Bucket management operations."
[[howto.steps]]
name = "Implement presigned URLs"
text = "Secure temporary access."
[[howto.steps]]
name = "Add batch operations"
text = "Bulk file processing."
+++


S3 stores unlimited data. AI agents need cloud access.

Together, they enable scalable intelligent storage.

## Why S3 + MCP

S3 provides:
- Unlimited storage
- High durability
- Global availability
- Cost effective

MCP tools enable:
- AI file processing
- Automated data management
- Intelligent organization
- Cloud-native workflows

## Step 1: S3 connection

Using [Gantz](https://gantz.run):

```yaml
# gantz.yaml
name: s3-tools

env:
  AWS_REGION: ${AWS_REGION}
  AWS_ACCESS_KEY_ID: ${AWS_ACCESS_KEY_ID}
  AWS_SECRET_ACCESS_KEY: ${AWS_SECRET_ACCESS_KEY}
  S3_BUCKET: ${S3_BUCKET}

tools:
  - name: upload_file
    description: Upload file to S3
    parameters:
      - name: key
        type: string
        required: true
      - name: content
        type: string
        required: true
    script:
      command: python
      args: ["tools/s3.py", "upload"]

  - name: download_file
    description: Download file from S3
    parameters:
      - name: key
        type: string
        required: true
    script:
      command: python
      args: ["tools/s3.py", "download"]

  - name: list_objects
    description: List objects in bucket
    parameters:
      - name: prefix
        type: string
        required: false
    script:
      command: python
      args: ["tools/s3.py", "list"]
```

S3 client:

```python
# lib/s3_client.py
import os
from typing import Optional
import boto3
from botocore.config import Config

class S3Client:
    """S3 client wrapper."""

    _instance: Optional['S3Client'] = None

    def __new__(cls):
        if cls._instance is None:
            cls._instance = super().__new__(cls)
            cls._instance._initialize()
        return cls._instance

    def _initialize(self):
        """Initialize S3 client."""
        region = os.environ.get('AWS_REGION', 'us-east-1')

        config = Config(
            retries={'max_attempts': 3, 'mode': 'adaptive'},
            connect_timeout=5,
            read_timeout=60
        )

        self._client = boto3.client('s3', region_name=region, config=config)
        self._resource = boto3.resource('s3', region_name=region)
        self._default_bucket = os.environ.get('S3_BUCKET')

    @property
    def client(self):
        """Get low-level client."""
        return self._client

    @property
    def resource(self):
        """Get high-level resource."""
        return self._resource

    def bucket(self, name: str = None):
        """Get bucket resource."""
        return self._resource.Bucket(name or self._default_bucket)

    @property
    def default_bucket(self) -> str:
        return self._default_bucket

# Global instance
s3 = S3Client()
```

## Step 2: Object tools

Upload and download:

```python
# tools/s3.py
import sys
import json
import base64
from lib.s3_client import s3

class ObjectTool:
    """Tool for S3 object operations."""

    def __init__(self, bucket: str = None):
        self.bucket_name = bucket or s3.default_bucket
        self.bucket = s3.bucket(self.bucket_name)
        self.client = s3.client

    def upload(
        self,
        key: str,
        content: bytes | str,
        content_type: str = None,
        metadata: dict = None
    ) -> dict:
        """Upload object to S3."""
        try:
            # Handle base64 encoded content
            if isinstance(content, str):
                try:
                    content = base64.b64decode(content)
                except Exception:
                    content = content.encode('utf-8')

            extra_args = {}
            if content_type:
                extra_args['ContentType'] = content_type
            if metadata:
                extra_args['Metadata'] = metadata

            self.bucket.put_object(
                Key=key,
                Body=content,
                **extra_args
            )

            return {
                'success': True,
                'bucket': self.bucket_name,
                'key': key,
                'size': len(content)
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def download(self, key: str) -> dict:
        """Download object from S3."""
        try:
            response = self.client.get_object(
                Bucket=self.bucket_name,
                Key=key
            )

            content = response['Body'].read()

            return {
                'success': True,
                'key': key,
                'content': base64.b64encode(content).decode('utf-8'),
                'size': len(content),
                'content_type': response.get('ContentType'),
                'metadata': response.get('Metadata', {})
            }
        except self.client.exceptions.NoSuchKey:
            return {
                'success': False,
                'error': f'Object not found: {key}'
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def delete(self, key: str) -> dict:
        """Delete object from S3."""
        try:
            self.client.delete_object(
                Bucket=self.bucket_name,
                Key=key
            )

            return {
                'success': True,
                'deleted': key
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def copy(
        self,
        source_key: str,
        dest_key: str,
        dest_bucket: str = None
    ) -> dict:
        """Copy object within or between buckets."""
        try:
            dest_bucket = dest_bucket or self.bucket_name

            self.client.copy_object(
                CopySource={'Bucket': self.bucket_name, 'Key': source_key},
                Bucket=dest_bucket,
                Key=dest_key
            )

            return {
                'success': True,
                'source': f'{self.bucket_name}/{source_key}',
                'destination': f'{dest_bucket}/{dest_key}'
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def move(
        self,
        source_key: str,
        dest_key: str,
        dest_bucket: str = None
    ) -> dict:
        """Move object (copy + delete)."""
        copy_result = self.copy(source_key, dest_key, dest_bucket)

        if not copy_result['success']:
            return copy_result

        delete_result = self.delete(source_key)

        return {
            'success': delete_result['success'],
            'moved': source_key,
            'to': dest_key
        }

    def exists(self, key: str) -> dict:
        """Check if object exists."""
        try:
            self.client.head_object(
                Bucket=self.bucket_name,
                Key=key
            )
            return {'success': True, 'exists': True}
        except self.client.exceptions.ClientError as e:
            if e.response['Error']['Code'] == '404':
                return {'success': True, 'exists': False}
            return {'success': False, 'error': str(e)}

    def get_metadata(self, key: str) -> dict:
        """Get object metadata."""
        try:
            response = self.client.head_object(
                Bucket=self.bucket_name,
                Key=key
            )

            return {
                'success': True,
                'key': key,
                'size': response['ContentLength'],
                'content_type': response.get('ContentType'),
                'last_modified': response['LastModified'].isoformat(),
                'etag': response['ETag'],
                'metadata': response.get('Metadata', {})
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}

if __name__ == '__main__':
    operation = sys.argv[1] if len(sys.argv) > 1 else 'list'
    params = json.loads(sys.argv[2]) if len(sys.argv) > 2 else {}

    tool = ObjectTool(params.get('bucket'))

    if operation == 'upload':
        result = tool.upload(
            params.get('key', ''),
            params.get('content', '')
        )
    elif operation == 'download':
        result = tool.download(params.get('key', ''))
    elif operation == 'delete':
        result = tool.delete(params.get('key', ''))
    else:
        result = {'success': False, 'error': f'Unknown operation: {operation}'}

    print(json.dumps(result))
```

## Step 3: Listing tools

Browse bucket contents:

```python
# tools/list.py
import json
from lib.s3_client import s3

class ListTool:
    """Tool for listing S3 objects."""

    def __init__(self, bucket: str = None):
        self.bucket_name = bucket or s3.default_bucket
        self.client = s3.client

    def list_objects(
        self,
        prefix: str = '',
        max_keys: int = 1000,
        delimiter: str = None
    ) -> dict:
        """List objects with prefix."""
        try:
            kwargs = {
                'Bucket': self.bucket_name,
                'Prefix': prefix,
                'MaxKeys': max_keys
            }

            if delimiter:
                kwargs['Delimiter'] = delimiter

            response = self.client.list_objects_v2(**kwargs)

            objects = []
            for obj in response.get('Contents', []):
                objects.append({
                    'key': obj['Key'],
                    'size': obj['Size'],
                    'last_modified': obj['LastModified'].isoformat(),
                    'etag': obj['ETag']
                })

            # Common prefixes (folders)
            prefixes = [
                p['Prefix'] for p in response.get('CommonPrefixes', [])
            ]

            return {
                'success': True,
                'objects': objects,
                'prefixes': prefixes,
                'count': len(objects),
                'truncated': response.get('IsTruncated', False)
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def list_all(
        self,
        prefix: str = '',
        delimiter: str = None
    ) -> dict:
        """List all objects (handles pagination)."""
        try:
            paginator = self.client.get_paginator('list_objects_v2')

            kwargs = {
                'Bucket': self.bucket_name,
                'Prefix': prefix
            }

            if delimiter:
                kwargs['Delimiter'] = delimiter

            objects = []
            prefixes = []

            for page in paginator.paginate(**kwargs):
                for obj in page.get('Contents', []):
                    objects.append({
                        'key': obj['Key'],
                        'size': obj['Size'],
                        'last_modified': obj['LastModified'].isoformat()
                    })

                for p in page.get('CommonPrefixes', []):
                    prefixes.append(p['Prefix'])

            return {
                'success': True,
                'objects': objects,
                'prefixes': prefixes,
                'count': len(objects)
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def get_size(self, prefix: str = '') -> dict:
        """Calculate total size of objects."""
        try:
            result = self.list_all(prefix)

            if not result['success']:
                return result

            total_size = sum(obj['size'] for obj in result['objects'])

            return {
                'success': True,
                'prefix': prefix,
                'total_size': total_size,
                'object_count': result['count']
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def search(
        self,
        pattern: str,
        prefix: str = ''
    ) -> dict:
        """Search objects by pattern."""
        import fnmatch

        try:
            result = self.list_all(prefix)

            if not result['success']:
                return result

            matches = [
                obj for obj in result['objects']
                if fnmatch.fnmatch(obj['key'], pattern)
            ]

            return {
                'success': True,
                'pattern': pattern,
                'matches': matches,
                'count': len(matches)
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}
```

## Step 4: Presigned URLs

Secure temporary access:

```python
# tools/presigned.py
import json
from lib.s3_client import s3

class PresignedURLTool:
    """Tool for S3 presigned URLs."""

    def __init__(self, bucket: str = None):
        self.bucket_name = bucket or s3.default_bucket
        self.client = s3.client

    def get_download_url(
        self,
        key: str,
        expires_in: int = 3600
    ) -> dict:
        """Generate presigned download URL."""
        try:
            url = self.client.generate_presigned_url(
                'get_object',
                Params={
                    'Bucket': self.bucket_name,
                    'Key': key
                },
                ExpiresIn=expires_in
            )

            return {
                'success': True,
                'url': url,
                'key': key,
                'expires_in': expires_in
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def get_upload_url(
        self,
        key: str,
        content_type: str = None,
        expires_in: int = 3600
    ) -> dict:
        """Generate presigned upload URL."""
        try:
            params = {
                'Bucket': self.bucket_name,
                'Key': key
            }

            if content_type:
                params['ContentType'] = content_type

            url = self.client.generate_presigned_url(
                'put_object',
                Params=params,
                ExpiresIn=expires_in
            )

            return {
                'success': True,
                'url': url,
                'key': key,
                'method': 'PUT',
                'expires_in': expires_in,
                'content_type': content_type
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def get_multipart_upload_urls(
        self,
        key: str,
        parts: int,
        expires_in: int = 3600
    ) -> dict:
        """Generate presigned URLs for multipart upload."""
        try:
            # Initiate multipart upload
            response = self.client.create_multipart_upload(
                Bucket=self.bucket_name,
                Key=key
            )

            upload_id = response['UploadId']

            # Generate URLs for each part
            part_urls = []
            for part_number in range(1, parts + 1):
                url = self.client.generate_presigned_url(
                    'upload_part',
                    Params={
                        'Bucket': self.bucket_name,
                        'Key': key,
                        'UploadId': upload_id,
                        'PartNumber': part_number
                    },
                    ExpiresIn=expires_in
                )

                part_urls.append({
                    'part_number': part_number,
                    'url': url
                })

            return {
                'success': True,
                'upload_id': upload_id,
                'key': key,
                'parts': part_urls,
                'expires_in': expires_in
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}
```

## Step 5: Batch operations

Bulk file processing:

```python
# tools/batch.py
import json
from concurrent.futures import ThreadPoolExecutor, as_completed
from lib.s3_client import s3

class BatchTool:
    """Tool for S3 batch operations."""

    def __init__(self, bucket: str = None, max_workers: int = 10):
        self.bucket_name = bucket or s3.default_bucket
        self.client = s3.client
        self.max_workers = max_workers

    def batch_delete(self, keys: list) -> dict:
        """Delete multiple objects."""
        try:
            # S3 allows max 1000 objects per delete request
            deleted = []
            errors = []

            for i in range(0, len(keys), 1000):
                batch = keys[i:i + 1000]

                response = self.client.delete_objects(
                    Bucket=self.bucket_name,
                    Delete={
                        'Objects': [{'Key': key} for key in batch],
                        'Quiet': False
                    }
                )

                deleted.extend([
                    d['Key'] for d in response.get('Deleted', [])
                ])

                errors.extend([
                    {'key': e['Key'], 'error': e['Message']}
                    for e in response.get('Errors', [])
                ])

            return {
                'success': len(errors) == 0,
                'deleted': len(deleted),
                'errors': errors
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def batch_copy(
        self,
        operations: list  # [{'source': key, 'dest': key}, ...]
    ) -> dict:
        """Copy multiple objects."""
        results = {'success': 0, 'failed': 0, 'errors': []}

        def copy_one(op):
            try:
                self.client.copy_object(
                    CopySource={'Bucket': self.bucket_name, 'Key': op['source']},
                    Bucket=self.bucket_name,
                    Key=op['dest']
                )
                return {'success': True, 'source': op['source']}
            except Exception as e:
                return {
                    'success': False,
                    'source': op['source'],
                    'error': str(e)
                }

        with ThreadPoolExecutor(max_workers=self.max_workers) as executor:
            futures = [executor.submit(copy_one, op) for op in operations]

            for future in as_completed(futures):
                result = future.result()
                if result['success']:
                    results['success'] += 1
                else:
                    results['failed'] += 1
                    results['errors'].append(result)

        return {
            'success': results['failed'] == 0,
            'copied': results['success'],
            'failed': results['failed'],
            'errors': results['errors']
        }

    def sync_prefix(
        self,
        source_prefix: str,
        dest_prefix: str
    ) -> dict:
        """Sync objects from one prefix to another."""
        try:
            # List source objects
            list_tool = ListTool(self.bucket_name)
            source_result = list_tool.list_all(source_prefix)

            if not source_result['success']:
                return source_result

            # Build copy operations
            operations = []
            for obj in source_result['objects']:
                source_key = obj['key']
                dest_key = source_key.replace(source_prefix, dest_prefix, 1)

                operations.append({
                    'source': source_key,
                    'dest': dest_key
                })

            # Execute batch copy
            return self.batch_copy(operations)
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def delete_prefix(self, prefix: str) -> dict:
        """Delete all objects with prefix."""
        try:
            list_tool = ListTool(self.bucket_name)
            result = list_tool.list_all(prefix)

            if not result['success']:
                return result

            keys = [obj['key'] for obj in result['objects']]

            if not keys:
                return {
                    'success': True,
                    'deleted': 0,
                    'message': 'No objects found'
                }

            return self.batch_delete(keys)
        except Exception as e:
            return {'success': False, 'error': str(e)}
```

## Summary

S3 + MCP integration:

1. **Object tools** - Upload, download, manage
2. **Listing tools** - Browse and search
3. **Presigned URLs** - Secure access
4. **Batch operations** - Bulk processing
5. **Sync tools** - Prefix management

Build tools with [Gantz](https://gantz.run), scale with S3.

Unlimited storage, intelligent access.

## Related reading

- [Firebase MCP Integration](/post/firebase-mcp-integration/) - Alternative storage
- [MCP Streaming Patterns](/post/mcp-streaming-patterns/) - Large files
- [Agent File Patterns](/post/agent-file-patterns/) - File handling

---

*How do you use S3 with AI agents? Share your patterns.*
