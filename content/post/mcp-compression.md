+++
title = "MCP Compression: Reduce Bandwidth and Latency"
image = "images/mcp-compression.webp"
date = 2025-11-07
description = "Implement compression for MCP tools. Reduce payload sizes and improve response times with gzip, brotli, and streaming."
summary = "Master compression techniques for MCP tools including gzip, brotli, deflate, and zstd algorithms to shrink payload sizes by up to 95%. Learn how to implement HTTP compression middleware, streaming compression for large files, automatic response compression, and algorithm selection based on your performance priorities."
draft = false
tags = ['mcp', 'performance', 'compression']
voice = false

[howto]
name = "Implement MCP Compression"
totalTime = 20
[[howto.steps]]
name = "Choose compression algorithm"
text = "Select gzip, brotli, or zstd based on use case."
[[howto.steps]]
name = "Configure compression levels"
text = "Balance compression ratio vs CPU usage."
[[howto.steps]]
name = "Implement request compression"
text = "Compress outgoing request payloads."
[[howto.steps]]
name = "Handle response decompression"
text = "Decompress incoming responses automatically."
[[howto.steps]]
name = "Add streaming compression"
text = "Compress large payloads incrementally."
+++


Large payloads slow everything down.

1MB of JSON over the network takes time.

Compression shrinks data. Compression is fast.

## Why compression matters

Without compression:
```text
Tool result: 1MB JSON → Network transfer (500ms) → Parse
Total: 500ms+ latency
```

With compression:
```text
Tool result: 1MB JSON → Compress (50KB) → Transfer (25ms) → Decompress
Total: 50ms latency (10x faster)
```

## Step 1: Basic compression setup

Using [Gantz](https://gantz.run):

```yaml
# gantz.yaml
name: compressed-tools

compression:
  enabled: true
  algorithm: gzip
  level: 6
  min_size: 1024  # Only compress >1KB

  content_types:
    - application/json
    - text/plain
    - text/csv

tools:
  - name: fetch_large_data
    description: Fetch and compress large datasets
    compression: true
    parameters:
      - name: query
        type: string
        required: true
    script:
      command: python
      args: ["scripts/fetch_data.py", "{{query}}"]
```

Compression implementation:

```python
import gzip
import zlib
import brotli
import zstandard as zstd
from typing import Union, Optional
from enum import Enum
from dataclasses import dataclass
import io

class CompressionAlgorithm(Enum):
    GZIP = "gzip"
    DEFLATE = "deflate"
    BROTLI = "br"
    ZSTD = "zstd"

@dataclass
class CompressionConfig:
    """Compression configuration."""
    algorithm: CompressionAlgorithm = CompressionAlgorithm.GZIP
    level: int = 6
    min_size: int = 1024  # bytes

class Compressor:
    """Multi-algorithm compressor."""

    def __init__(self, config: CompressionConfig = None):
        self.config = config or CompressionConfig()

    def compress(self, data: bytes) -> tuple[bytes, str]:
        """Compress data, return compressed bytes and encoding."""
        if len(data) < self.config.min_size:
            return data, ""

        algorithm = self.config.algorithm
        level = self.config.level

        if algorithm == CompressionAlgorithm.GZIP:
            compressed = gzip.compress(data, compresslevel=level)
        elif algorithm == CompressionAlgorithm.DEFLATE:
            compressed = zlib.compress(data, level=level)
        elif algorithm == CompressionAlgorithm.BROTLI:
            compressed = brotli.compress(data, quality=level)
        elif algorithm == CompressionAlgorithm.ZSTD:
            cctx = zstd.ZstdCompressor(level=level)
            compressed = cctx.compress(data)
        else:
            return data, ""

        # Only use if smaller
        if len(compressed) < len(data):
            return compressed, algorithm.value

        return data, ""

    def decompress(self, data: bytes, encoding: str) -> bytes:
        """Decompress data based on encoding."""
        if not encoding:
            return data

        if encoding == "gzip":
            return gzip.decompress(data)
        elif encoding == "deflate":
            return zlib.decompress(data)
        elif encoding == "br":
            return brotli.decompress(data)
        elif encoding == "zstd":
            dctx = zstd.ZstdDecompressor()
            return dctx.decompress(data)

        return data

    def compress_json(self, obj: dict) -> tuple[bytes, str]:
        """Compress JSON object."""
        import json
        data = json.dumps(obj).encode('utf-8')
        return self.compress(data)

    def decompress_json(self, data: bytes, encoding: str) -> dict:
        """Decompress to JSON object."""
        import json
        decompressed = self.decompress(data, encoding)
        return json.loads(decompressed.decode('utf-8'))

# Usage
compressor = Compressor(CompressionConfig(
    algorithm=CompressionAlgorithm.GZIP,
    level=6
))

# Compress
data = b"large data" * 10000
compressed, encoding = compressor.compress(data)
print(f"Compressed: {len(data)} -> {len(compressed)} ({encoding})")

# Decompress
original = compressor.decompress(compressed, encoding)
```

## Step 2: HTTP compression middleware

Add compression to HTTP requests:

```python
import httpx
from typing import Optional, Any

class CompressedHTTPClient:
    """HTTP client with automatic compression."""

    def __init__(
        self,
        base_url: str = None,
        compress_requests: bool = True,
        accept_encoding: str = "gzip, deflate, br"
    ):
        self.compressor = Compressor()
        self.compress_requests = compress_requests

        self.client = httpx.Client(
            base_url=base_url,
            headers={"Accept-Encoding": accept_encoding}
        )

    def post(
        self,
        url: str,
        json: dict = None,
        **kwargs
    ) -> httpx.Response:
        """POST with compression."""
        if json and self.compress_requests:
            compressed, encoding = self.compressor.compress_json(json)

            if encoding:
                kwargs['content'] = compressed
                kwargs['headers'] = kwargs.get('headers', {})
                kwargs['headers']['Content-Encoding'] = encoding
                kwargs['headers']['Content-Type'] = 'application/json'
            else:
                kwargs['json'] = json
        else:
            kwargs['json'] = json

        response = self.client.post(url, **kwargs)
        return self._decompress_response(response)

    def get(self, url: str, **kwargs) -> httpx.Response:
        """GET with decompression."""
        response = self.client.get(url, **kwargs)
        return self._decompress_response(response)

    def _decompress_response(self, response: httpx.Response) -> httpx.Response:
        """Decompress response if needed."""
        # httpx handles this automatically with Accept-Encoding
        return response

class AsyncCompressedHTTPClient:
    """Async HTTP client with compression."""

    def __init__(self, base_url: str = None):
        self.compressor = Compressor()
        self.client = httpx.AsyncClient(
            base_url=base_url,
            headers={"Accept-Encoding": "gzip, deflate, br"}
        )

    async def post(self, url: str, json: dict = None, **kwargs) -> httpx.Response:
        if json:
            compressed, encoding = self.compressor.compress_json(json)
            if encoding:
                kwargs['content'] = compressed
                kwargs['headers'] = kwargs.get('headers', {})
                kwargs['headers']['Content-Encoding'] = encoding
                kwargs['headers']['Content-Type'] = 'application/json'
            else:
                kwargs['json'] = json

        return await self.client.post(url, **kwargs)

    async def close(self):
        await self.client.aclose()

# Usage
client = CompressedHTTPClient(base_url="https://api.example.com")
response = client.post("/data", json={"large": "payload" * 1000})
```

## Step 3: Streaming compression

Compress large data streams:

```python
import gzip
import io
from typing import Iterator, Generator

class StreamingCompressor:
    """Compress data streams."""

    def __init__(self, level: int = 6):
        self.level = level

    def compress_stream(
        self,
        data_stream: Iterator[bytes],
        chunk_size: int = 65536
    ) -> Generator[bytes, None, None]:
        """Compress stream incrementally."""
        buffer = io.BytesIO()

        with gzip.GzipFile(
            fileobj=buffer,
            mode='wb',
            compresslevel=self.level
        ) as gz:
            for chunk in data_stream:
                gz.write(chunk)

                # Flush and yield compressed data
                if buffer.tell() >= chunk_size:
                    gz.flush()
                    yield buffer.getvalue()
                    buffer.seek(0)
                    buffer.truncate()

        # Yield remaining data
        if buffer.tell() > 0:
            yield buffer.getvalue()

    def decompress_stream(
        self,
        compressed_stream: Iterator[bytes]
    ) -> Generator[bytes, None, None]:
        """Decompress stream incrementally."""
        decompressor = zlib.decompressobj(16 + zlib.MAX_WBITS)

        for chunk in compressed_stream:
            decompressed = decompressor.decompress(chunk)
            if decompressed:
                yield decompressed

        # Flush remaining
        remaining = decompressor.flush()
        if remaining:
            yield remaining

class StreamingFileCompressor:
    """Compress files with streaming."""

    def __init__(self, chunk_size: int = 1024 * 1024):  # 1MB chunks
        self.chunk_size = chunk_size
        self.compressor = StreamingCompressor()

    def compress_file(
        self,
        input_path: str,
        output_path: str
    ) -> dict:
        """Compress file with streaming."""
        input_size = 0
        output_size = 0

        def read_chunks():
            nonlocal input_size
            with open(input_path, 'rb') as f:
                while chunk := f.read(self.chunk_size):
                    input_size += len(chunk)
                    yield chunk

        with open(output_path, 'wb') as out:
            for compressed_chunk in self.compressor.compress_stream(read_chunks()):
                out.write(compressed_chunk)
                output_size += len(compressed_chunk)

        return {
            "input_size": input_size,
            "output_size": output_size,
            "ratio": output_size / input_size if input_size > 0 else 0
        }

# Usage with MCP tool
def compress_file_tool(input_path: str, output_path: str) -> dict:
    """MCP tool for file compression."""
    compressor = StreamingFileCompressor()
    result = compressor.compress_file(input_path, output_path)
    return {
        "success": True,
        "compression_ratio": f"{result['ratio']:.2%}",
        "saved_bytes": result['input_size'] - result['output_size']
    }
```

## Step 4: Response compression for tools

Compress MCP tool responses:

```python
import json
from typing import Any, Callable
from functools import wraps

class ToolResponseCompressor:
    """Compress tool responses automatically."""

    def __init__(
        self,
        min_size: int = 1024,
        algorithm: str = "gzip"
    ):
        self.min_size = min_size
        self.compressor = Compressor(CompressionConfig(
            algorithm=CompressionAlgorithm(algorithm),
            min_size=min_size
        ))

    def compress_response(self, response: dict) -> dict:
        """Compress response if large enough."""
        json_str = json.dumps(response)
        size = len(json_str.encode('utf-8'))

        if size < self.min_size:
            return response

        compressed, encoding = self.compressor.compress(json_str.encode('utf-8'))

        if encoding:
            import base64
            return {
                "_compressed": True,
                "_encoding": encoding,
                "_original_size": size,
                "_compressed_size": len(compressed),
                "data": base64.b64encode(compressed).decode('ascii')
            }

        return response

    def decompress_response(self, response: dict) -> dict:
        """Decompress response if compressed."""
        if not response.get("_compressed"):
            return response

        import base64
        compressed = base64.b64decode(response["data"])
        encoding = response["_encoding"]

        decompressed = self.compressor.decompress(compressed, encoding)
        return json.loads(decompressed.decode('utf-8'))

def compressed_tool(min_size: int = 1024):
    """Decorator for automatic response compression."""
    compressor = ToolResponseCompressor(min_size=min_size)

    def decorator(func: Callable) -> Callable:
        @wraps(func)
        def wrapper(*args, **kwargs) -> dict:
            response = func(*args, **kwargs)
            return compressor.compress_response(response)
        return wrapper
    return decorator

# Usage
@compressed_tool(min_size=512)
def fetch_large_dataset(query: str) -> dict:
    """Fetch large dataset with automatic compression."""
    data = database.query(query)
    return {"results": data, "count": len(data)}
```

## Step 5: Compression selection

Choose optimal compression:

```python
from dataclasses import dataclass
from typing import Dict, List
import time

@dataclass
class CompressionBenchmark:
    """Benchmark result for compression."""
    algorithm: str
    compressed_size: int
    compression_time: float
    decompression_time: float
    ratio: float

class CompressionSelector:
    """Select optimal compression algorithm."""

    def __init__(self):
        self.algorithms = [
            CompressionAlgorithm.GZIP,
            CompressionAlgorithm.DEFLATE,
            CompressionAlgorithm.BROTLI,
            CompressionAlgorithm.ZSTD
        ]

    def benchmark(
        self,
        data: bytes,
        level: int = 6
    ) -> List[CompressionBenchmark]:
        """Benchmark all algorithms."""
        results = []

        for algo in self.algorithms:
            try:
                compressor = Compressor(CompressionConfig(
                    algorithm=algo,
                    level=level,
                    min_size=0
                ))

                # Compression
                start = time.time()
                compressed, _ = compressor.compress(data)
                compress_time = time.time() - start

                # Decompression
                start = time.time()
                compressor.decompress(compressed, algo.value)
                decompress_time = time.time() - start

                results.append(CompressionBenchmark(
                    algorithm=algo.value,
                    compressed_size=len(compressed),
                    compression_time=compress_time,
                    decompression_time=decompress_time,
                    ratio=len(compressed) / len(data)
                ))
            except Exception:
                continue

        return results

    def select_best(
        self,
        data: bytes,
        priority: str = "ratio"  # ratio, speed, balanced
    ) -> CompressionAlgorithm:
        """Select best algorithm based on priority."""
        benchmarks = self.benchmark(data)

        if not benchmarks:
            return CompressionAlgorithm.GZIP

        if priority == "ratio":
            best = min(benchmarks, key=lambda b: b.ratio)
        elif priority == "speed":
            best = min(benchmarks, key=lambda b: b.compression_time)
        else:  # balanced
            best = min(
                benchmarks,
                key=lambda b: b.ratio * 0.5 + b.compression_time * 0.5
            )

        return CompressionAlgorithm(best.algorithm)

# Usage
selector = CompressionSelector()
best_algo = selector.select_best(large_data, priority="balanced")
print(f"Best algorithm: {best_algo.value}")
```

## Step 6: Compression monitoring

Track compression metrics:

```python
from prometheus_client import Counter, Histogram, Gauge
from dataclasses import dataclass

compression_ratio_histogram = Histogram(
    'compression_ratio',
    'Compression ratios',
    ['algorithm'],
    buckets=[0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0]
)

bytes_saved_counter = Counter(
    'compression_bytes_saved_total',
    'Total bytes saved by compression',
    ['algorithm']
)

compression_time_histogram = Histogram(
    'compression_duration_seconds',
    'Compression duration',
    ['algorithm', 'operation']
)

class MonitoredCompressor:
    """Compressor with monitoring."""

    def __init__(self, config: CompressionConfig = None):
        self.compressor = Compressor(config)
        self.config = config or CompressionConfig()

    def compress(self, data: bytes) -> tuple[bytes, str]:
        """Compress with monitoring."""
        import time

        start = time.time()
        compressed, encoding = self.compressor.compress(data)
        duration = time.time() - start

        if encoding:
            algo = encoding
            ratio = len(compressed) / len(data)
            saved = len(data) - len(compressed)

            compression_ratio_histogram.labels(algorithm=algo).observe(ratio)
            bytes_saved_counter.labels(algorithm=algo).inc(saved)
            compression_time_histogram.labels(
                algorithm=algo,
                operation="compress"
            ).observe(duration)

        return compressed, encoding

    def decompress(self, data: bytes, encoding: str) -> bytes:
        """Decompress with monitoring."""
        import time

        start = time.time()
        decompressed = self.compressor.decompress(data, encoding)
        duration = time.time() - start

        if encoding:
            compression_time_histogram.labels(
                algorithm=encoding,
                operation="decompress"
            ).observe(duration)

        return decompressed
```

## Summary

MCP compression patterns:

1. **Algorithm selection** - Gzip, brotli, zstd
2. **HTTP compression** - Request and response
3. **Streaming compression** - Large data handling
4. **Tool response compression** - Automatic compression
5. **Optimal selection** - Choose by priority
6. **Monitoring** - Track compression metrics

Build tools with [Gantz](https://gantz.run), compress for speed.

Smaller is faster.

## Related reading

- [MCP Streaming Patterns](/post/mcp-streaming-patterns/) - Stream large data
- [MCP Performance](/post/mcp-performance/) - Optimize throughput
- [MCP Batching](/post/mcp-batching/) - Batch before compression

---

*What compression algorithms do you use? Share your experience.*
