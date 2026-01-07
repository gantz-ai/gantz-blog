+++
title = "MCP Batching: Process Multiple Requests Efficiently"
image = "images/mcp-batching.webp"
date = 2025-11-05
description = "Implement request batching for MCP tools. Reduce API calls, optimize throughput, and handle bulk operations in AI agent systems."
draft = false
tags = ['mcp', 'performance', 'batching']
voice = false

[howto]
name = "Implement Request Batching"
totalTime = 25
[[howto.steps]]
name = "Identify batchable operations"
text = "Find operations that can be grouped together."
[[howto.steps]]
name = "Configure batch sizes"
text = "Set optimal batch sizes for your use case."
[[howto.steps]]
name = "Implement batch collection"
text = "Collect requests until batch is ready."
[[howto.steps]]
name = "Process batches"
text = "Execute batched operations efficiently."
[[howto.steps]]
name = "Handle partial failures"
text = "Manage failures within batches gracefully."
+++


One request at a time is slow.

100 requests means 100 round trips.

Batching combines requests. Batching is fast.

## Why batching matters

Without batching:
```
Request 1 → API call (100ms) → Response
Request 2 → API call (100ms) → Response
Request 3 → API call (100ms) → Response
...
100 requests = 10 seconds
```

With batching:
```
Collect 100 requests → Single API call (150ms) → All responses
100 requests = 150ms (66x faster)
```

## Step 1: Basic batch collector

Using [Gantz](https://gantz.run):

```yaml
# gantz.yaml
name: batched-tools

batching:
  default:
    max_size: 100
    max_wait_ms: 50

  embeddings:
    max_size: 1000
    max_wait_ms: 100

tools:
  - name: batch_embed
    description: Batch embed multiple texts
    batching: embeddings
    parameters:
      - name: texts
        type: array
        required: true
    script:
      command: python
      args: ["scripts/batch_embed.py"]
```

Batch collector implementation:

```python
import asyncio
import threading
import time
from typing import TypeVar, Generic, Callable, List, Any
from dataclasses import dataclass
from collections import deque

T = TypeVar('T')
R = TypeVar('R')

@dataclass
class BatchConfig:
    """Batch configuration."""
    max_size: int = 100
    max_wait_ms: int = 50
    min_size: int = 1

@dataclass
class BatchItem(Generic[T]):
    """Item in batch queue."""
    data: T
    future: asyncio.Future
    timestamp: float

class BatchCollector(Generic[T, R]):
    """Collect items into batches."""

    def __init__(
        self,
        processor: Callable[[List[T]], List[R]],
        config: BatchConfig = None
    ):
        self.processor = processor
        self.config = config or BatchConfig()

        self._queue: deque[BatchItem[T]] = deque()
        self._lock = threading.Lock()
        self._batch_event = asyncio.Event()
        self._running = False

    async def start(self):
        """Start batch processing loop."""
        self._running = True
        asyncio.create_task(self._process_loop())

    async def stop(self):
        """Stop batch processing."""
        self._running = False
        self._batch_event.set()

    async def submit(self, item: T) -> R:
        """Submit item for batching."""
        loop = asyncio.get_event_loop()
        future = loop.create_future()

        batch_item = BatchItem(
            data=item,
            future=future,
            timestamp=time.time()
        )

        with self._lock:
            self._queue.append(batch_item)

            # Trigger if batch is full
            if len(self._queue) >= self.config.max_size:
                self._batch_event.set()

        return await future

    async def _process_loop(self):
        """Main processing loop."""
        while self._running:
            # Wait for batch or timeout
            try:
                await asyncio.wait_for(
                    self._batch_event.wait(),
                    timeout=self.config.max_wait_ms / 1000
                )
            except asyncio.TimeoutError:
                pass

            self._batch_event.clear()

            # Process pending items
            await self._process_batch()

    async def _process_batch(self):
        """Process current batch."""
        with self._lock:
            if not self._queue:
                return

            # Get batch
            batch_items = []
            while self._queue and len(batch_items) < self.config.max_size:
                batch_items.append(self._queue.popleft())

        if not batch_items:
            return

        # Extract data
        data = [item.data for item in batch_items]

        try:
            # Process batch
            results = await asyncio.to_thread(self.processor, data)

            # Distribute results
            for item, result in zip(batch_items, results):
                if not item.future.done():
                    item.future.set_result(result)

        except Exception as e:
            # Fail all items in batch
            for item in batch_items:
                if not item.future.done():
                    item.future.set_exception(e)

# Usage
def batch_process_embeddings(texts: List[str]) -> List[List[float]]:
    """Process embeddings in batch."""
    # Call embedding API with all texts
    return embedding_api.embed_batch(texts)

collector = BatchCollector(
    processor=batch_process_embeddings,
    config=BatchConfig(max_size=100, max_wait_ms=50)
)

await collector.start()

# Submit items - they get batched automatically
embedding = await collector.submit("Hello world")
```

## Step 2: Synchronous batching

For synchronous code:

```python
import threading
import time
from queue import Queue, Empty
from typing import List, Callable, Any, Dict
from dataclasses import dataclass
from concurrent.futures import Future, ThreadPoolExecutor

class SyncBatchCollector:
    """Synchronous batch collector."""

    def __init__(
        self,
        processor: Callable[[List[Any]], List[Any]],
        max_size: int = 100,
        max_wait_seconds: float = 0.05
    ):
        self.processor = processor
        self.max_size = max_size
        self.max_wait = max_wait_seconds

        self._queue = Queue()
        self._executor = ThreadPoolExecutor(max_workers=1)
        self._running = True
        self._process_thread = threading.Thread(
            target=self._process_loop,
            daemon=True
        )
        self._process_thread.start()

    def submit(self, item: Any) -> Any:
        """Submit item and wait for result."""
        future = Future()
        self._queue.put((item, future))
        return future.result()

    def submit_async(self, item: Any) -> Future:
        """Submit item and return future."""
        future = Future()
        self._queue.put((item, future))
        return future

    def _process_loop(self):
        """Processing loop."""
        while self._running:
            batch = []
            futures = []
            deadline = time.time() + self.max_wait

            # Collect batch
            while len(batch) < self.max_size:
                timeout = max(0, deadline - time.time())
                try:
                    item, future = self._queue.get(timeout=timeout)
                    batch.append(item)
                    futures.append(future)
                except Empty:
                    break

            if not batch:
                continue

            # Process batch
            try:
                results = self.processor(batch)
                for future, result in zip(futures, results):
                    future.set_result(result)
            except Exception as e:
                for future in futures:
                    future.set_exception(e)

    def stop(self):
        """Stop collector."""
        self._running = False
        self._process_thread.join(timeout=1)

# Usage
def process_batch(items: List[str]) -> List[dict]:
    """Process items in batch."""
    return api.batch_process(items)

collector = SyncBatchCollector(process_batch, max_size=50)

# These get batched together
result1 = collector.submit("item1")
result2 = collector.submit("item2")
```

## Step 3: Database batch operations

Batch database operations:

```python
from typing import List, Tuple, Any
import psycopg2
from psycopg2.extras import execute_batch, execute_values

class DatabaseBatcher:
    """Batch database operations."""

    def __init__(self, connection_pool, batch_size: int = 1000):
        self.pool = connection_pool
        self.batch_size = batch_size

    def batch_insert(
        self,
        table: str,
        columns: List[str],
        values: List[Tuple]
    ) -> int:
        """Insert rows in batches."""
        if not values:
            return 0

        total_inserted = 0
        column_str = ", ".join(columns)

        with self.pool.acquire() as conn:
            with conn.cursor() as cur:
                # Process in batches
                for i in range(0, len(values), self.batch_size):
                    batch = values[i:i + self.batch_size]

                    query = f"""
                        INSERT INTO {table} ({column_str})
                        VALUES %s
                    """

                    execute_values(cur, query, batch)
                    total_inserted += len(batch)

                conn.commit()

        return total_inserted

    def batch_update(
        self,
        table: str,
        updates: List[dict],
        key_column: str
    ) -> int:
        """Update rows in batches."""
        if not updates:
            return 0

        total_updated = 0

        with self.pool.acquire() as conn:
            with conn.cursor() as cur:
                for i in range(0, len(updates), self.batch_size):
                    batch = updates[i:i + self.batch_size]

                    # Build batch update
                    for update in batch:
                        key_value = update.pop(key_column)
                        set_clause = ", ".join(
                            f"{k} = %s" for k in update.keys()
                        )

                        cur.execute(
                            f"UPDATE {table} SET {set_clause} WHERE {key_column} = %s",
                            list(update.values()) + [key_value]
                        )
                        total_updated += 1

                conn.commit()

        return total_updated

    def batch_delete(
        self,
        table: str,
        ids: List[Any],
        id_column: str = "id"
    ) -> int:
        """Delete rows in batches."""
        if not ids:
            return 0

        total_deleted = 0

        with self.pool.acquire() as conn:
            with conn.cursor() as cur:
                for i in range(0, len(ids), self.batch_size):
                    batch = ids[i:i + self.batch_size]
                    placeholders = ",".join(["%s"] * len(batch))

                    cur.execute(
                        f"DELETE FROM {table} WHERE {id_column} IN ({placeholders})",
                        batch
                    )
                    total_deleted += cur.rowcount

                conn.commit()

        return total_deleted

# Usage with MCP tool
db_batcher = DatabaseBatcher(pool, batch_size=500)

def bulk_insert_tool(table: str, records: List[dict]) -> dict:
    """MCP tool for bulk inserts."""
    if not records:
        return {"inserted": 0}

    columns = list(records[0].keys())
    values = [tuple(r[c] for c in columns) for r in records]

    inserted = db_batcher.batch_insert(table, columns, values)
    return {"inserted": inserted}
```

## Step 4: API request batching

Batch external API calls:

```python
import httpx
from typing import List, Dict, Any
import asyncio

class APIBatcher:
    """Batch API requests."""

    def __init__(
        self,
        base_url: str,
        batch_endpoint: str,
        max_batch_size: int = 100
    ):
        self.base_url = base_url
        self.batch_endpoint = batch_endpoint
        self.max_batch_size = max_batch_size
        self.client = httpx.AsyncClient(base_url=base_url)

    async def batch_request(
        self,
        requests: List[Dict[str, Any]]
    ) -> List[Dict[str, Any]]:
        """Send batched requests."""
        all_results = []

        # Split into batches
        for i in range(0, len(requests), self.max_batch_size):
            batch = requests[i:i + self.max_batch_size]

            response = await self.client.post(
                self.batch_endpoint,
                json={"requests": batch}
            )
            response.raise_for_status()

            results = response.json()["responses"]
            all_results.extend(results)

        return all_results

    async def close(self):
        await self.client.aclose()

class EmbeddingBatcher:
    """Batch embedding requests."""

    def __init__(self, api_key: str, max_batch: int = 100):
        self.api_key = api_key
        self.max_batch = max_batch
        self.client = httpx.AsyncClient()

    async def embed_batch(self, texts: List[str]) -> List[List[float]]:
        """Embed texts in batches."""
        all_embeddings = []

        for i in range(0, len(texts), self.max_batch):
            batch = texts[i:i + self.max_batch]

            response = await self.client.post(
                "https://api.openai.com/v1/embeddings",
                headers={"Authorization": f"Bearer {self.api_key}"},
                json={
                    "input": batch,
                    "model": "text-embedding-3-small"
                }
            )
            response.raise_for_status()

            data = response.json()
            embeddings = [d["embedding"] for d in data["data"]]
            all_embeddings.extend(embeddings)

        return all_embeddings

# MCP tool using batched embeddings
embedding_batcher = EmbeddingBatcher(api_key="...")

async def embed_documents_tool(documents: List[str]) -> dict:
    """Embed multiple documents efficiently."""
    embeddings = await embedding_batcher.embed_batch(documents)
    return {
        "count": len(embeddings),
        "embeddings": embeddings
    }
```

## Step 5: Handling partial failures

Handle failures within batches:

```python
from dataclasses import dataclass
from typing import List, Any, Optional, Generic, TypeVar
from enum import Enum

T = TypeVar('T')
R = TypeVar('R')

class BatchItemStatus(Enum):
    SUCCESS = "success"
    FAILED = "failed"
    SKIPPED = "skipped"

@dataclass
class BatchResult(Generic[R]):
    """Result for single item in batch."""
    status: BatchItemStatus
    result: Optional[R] = None
    error: Optional[str] = None
    index: int = 0

class ResilientBatcher(Generic[T, R]):
    """Batcher with partial failure handling."""

    def __init__(
        self,
        processor: Callable[[T], R],
        batch_processor: Callable[[List[T]], List[R]] = None
    ):
        self.processor = processor
        self.batch_processor = batch_processor

    def process_batch(
        self,
        items: List[T],
        fail_fast: bool = False
    ) -> List[BatchResult[R]]:
        """Process batch with failure handling."""
        results = []

        # Try batch processing first
        if self.batch_processor:
            try:
                batch_results = self.batch_processor(items)
                return [
                    BatchResult(
                        status=BatchItemStatus.SUCCESS,
                        result=r,
                        index=i
                    )
                    for i, r in enumerate(batch_results)
                ]
            except Exception:
                # Fall back to individual processing
                pass

        # Process individually
        for i, item in enumerate(items):
            try:
                result = self.processor(item)
                results.append(BatchResult(
                    status=BatchItemStatus.SUCCESS,
                    result=result,
                    index=i
                ))
            except Exception as e:
                results.append(BatchResult(
                    status=BatchItemStatus.FAILED,
                    error=str(e),
                    index=i
                ))

                if fail_fast:
                    # Mark remaining as skipped
                    for j in range(i + 1, len(items)):
                        results.append(BatchResult(
                            status=BatchItemStatus.SKIPPED,
                            index=j
                        ))
                    break

        return results

    def get_successful(self, results: List[BatchResult[R]]) -> List[R]:
        """Get successful results."""
        return [
            r.result for r in results
            if r.status == BatchItemStatus.SUCCESS
        ]

    def get_failed_indices(self, results: List[BatchResult[R]]) -> List[int]:
        """Get indices of failed items."""
        return [
            r.index for r in results
            if r.status == BatchItemStatus.FAILED
        ]

# Usage
def process_single(item: dict) -> dict:
    return api.process(item)

def process_batch(items: List[dict]) -> List[dict]:
    return api.batch_process(items)

batcher = ResilientBatcher(process_single, process_batch)

results = batcher.process_batch(items)
successful = batcher.get_successful(results)
failed_indices = batcher.get_failed_indices(results)

if failed_indices:
    print(f"Failed items: {failed_indices}")
```

## Step 6: Batch monitoring

Monitor batch performance:

```python
from prometheus_client import Counter, Histogram, Gauge
from dataclasses import dataclass
import time

batch_size_histogram = Histogram(
    'batch_size',
    'Batch sizes',
    ['operation'],
    buckets=[1, 5, 10, 25, 50, 100, 250, 500, 1000]
)

batch_duration_histogram = Histogram(
    'batch_duration_seconds',
    'Batch processing duration',
    ['operation']
)

batch_items_counter = Counter(
    'batch_items_total',
    'Total items processed',
    ['operation', 'status']
)

@dataclass
class BatchMetrics:
    """Batch operation metrics."""
    total_batches: int = 0
    total_items: int = 0
    failed_items: int = 0
    total_duration: float = 0.0

    @property
    def avg_batch_size(self) -> float:
        if self.total_batches == 0:
            return 0
        return self.total_items / self.total_batches

    @property
    def success_rate(self) -> float:
        if self.total_items == 0:
            return 1.0
        return (self.total_items - self.failed_items) / self.total_items

class MonitoredBatcher:
    """Batcher with monitoring."""

    def __init__(self, name: str, processor: Callable):
        self.name = name
        self.processor = processor
        self.metrics = BatchMetrics()

    def process(self, items: List[Any]) -> List[Any]:
        """Process batch with monitoring."""
        start = time.time()

        # Record batch size
        batch_size_histogram.labels(operation=self.name).observe(len(items))

        try:
            results = self.processor(items)

            # Record success
            batch_items_counter.labels(
                operation=self.name,
                status="success"
            ).inc(len(items))

            self.metrics.total_items += len(items)

            return results

        except Exception as e:
            # Record failure
            batch_items_counter.labels(
                operation=self.name,
                status="failed"
            ).inc(len(items))

            self.metrics.failed_items += len(items)
            raise

        finally:
            duration = time.time() - start
            batch_duration_histogram.labels(
                operation=self.name
            ).observe(duration)

            self.metrics.total_batches += 1
            self.metrics.total_duration += duration

    def get_stats(self) -> dict:
        """Get batch statistics."""
        return {
            "total_batches": self.metrics.total_batches,
            "total_items": self.metrics.total_items,
            "avg_batch_size": self.metrics.avg_batch_size,
            "success_rate": self.metrics.success_rate,
            "avg_duration": (
                self.metrics.total_duration / self.metrics.total_batches
                if self.metrics.total_batches > 0 else 0
            )
        }
```

## Summary

MCP batching patterns:

1. **Batch collection** - Gather requests before processing
2. **Sync/async batching** - Both patterns supported
3. **Database batching** - Bulk inserts and updates
4. **API batching** - Reduce external calls
5. **Partial failures** - Handle failures gracefully
6. **Monitoring** - Track batch performance

Build tools with [Gantz](https://gantz.run), batch for efficiency.

One call beats many.

## Related reading

- [MCP Connection Pooling](/post/mcp-connection-pooling/) - Pool connections
- [MCP Performance](/post/mcp-performance/) - Optimize throughput
- [MCP Caching](/post/mcp-caching/) - Cache batch results

---

*How do you batch operations? Share your strategies.*
