+++
title = "MCP Pagination: Handle Large Result Sets"
image = "/images/mcp-pagination.png"
date = 2025-11-09
description = "Implement pagination for MCP tools and AI agents. Cursor-based, offset-based, and keyset pagination patterns for large datasets."
draft = false
tags = ['mcp', 'performance', 'pagination']
voice = false

[howto]
name = "Implement MCP Pagination"
totalTime = 25
[[howto.steps]]
name = "Choose pagination strategy"
text = "Select cursor, offset, or keyset pagination."
[[howto.steps]]
name = "Implement page fetching"
text = "Build paginated query logic."
[[howto.steps]]
name = "Handle page navigation"
text = "Support next, previous, and random access."
[[howto.steps]]
name = "Add pagination metadata"
text = "Include total counts and page info."
[[howto.steps]]
name = "Optimize for large datasets"
text = "Use efficient pagination for scale."
+++


Fetching 10,000 records at once crashes systems.

Memory exhaustion. Timeout errors. User frustration.

Pagination breaks data into manageable chunks.

## Why pagination matters

Without pagination:
```
Query all records → Load 10,000 items → Memory spike →
Timeout or crash → User sees nothing
```

With pagination:
```
Query page 1 (100 items) → Return fast →
User requests page 2 → Return fast → ...
Smooth experience
```

## Step 1: Basic pagination setup

Using [Gantz](https://gantz.run):

```yaml
# gantz.yaml
name: paginated-tools

pagination:
  default_page_size: 50
  max_page_size: 200

tools:
  - name: list_records
    description: List records with pagination
    pagination:
      enabled: true
      default_size: 50
    parameters:
      - name: filter
        type: string
        required: false
      - name: page
        type: integer
        required: false
      - name: page_size
        type: integer
        required: false
    script:
      command: python
      args: ["scripts/list_records.py"]
```

Pagination implementation:

```python
from dataclasses import dataclass
from typing import TypeVar, Generic, List, Optional, Any
from abc import ABC, abstractmethod

T = TypeVar('T')

@dataclass
class PageInfo:
    """Pagination metadata."""
    page: int
    page_size: int
    total_items: int
    total_pages: int
    has_next: bool
    has_previous: bool

@dataclass
class PaginatedResult(Generic[T]):
    """Paginated result container."""
    items: List[T]
    page_info: PageInfo

    def to_dict(self) -> dict:
        return {
            "items": self.items,
            "page": self.page_info.page,
            "page_size": self.page_info.page_size,
            "total_items": self.page_info.total_items,
            "total_pages": self.page_info.total_pages,
            "has_next": self.page_info.has_next,
            "has_previous": self.page_info.has_previous
        }

class Paginator(ABC, Generic[T]):
    """Base paginator class."""

    def __init__(
        self,
        default_page_size: int = 50,
        max_page_size: int = 200
    ):
        self.default_page_size = default_page_size
        self.max_page_size = max_page_size

    def validate_params(self, page: int, page_size: int) -> tuple[int, int]:
        """Validate and normalize pagination parameters."""
        page = max(1, page)
        page_size = min(max(1, page_size), self.max_page_size)
        return page, page_size

    @abstractmethod
    def paginate(
        self,
        page: int = 1,
        page_size: int = None
    ) -> PaginatedResult[T]:
        """Get paginated results."""
        pass

class OffsetPaginator(Paginator[T]):
    """Offset-based pagination."""

    def __init__(
        self,
        query_func,
        count_func,
        **kwargs
    ):
        super().__init__(**kwargs)
        self.query_func = query_func
        self.count_func = count_func

    def paginate(
        self,
        page: int = 1,
        page_size: int = None
    ) -> PaginatedResult[T]:
        """Get page using offset."""
        page_size = page_size or self.default_page_size
        page, page_size = self.validate_params(page, page_size)

        offset = (page - 1) * page_size
        total_items = self.count_func()
        total_pages = (total_items + page_size - 1) // page_size

        items = self.query_func(offset=offset, limit=page_size)

        return PaginatedResult(
            items=items,
            page_info=PageInfo(
                page=page,
                page_size=page_size,
                total_items=total_items,
                total_pages=total_pages,
                has_next=page < total_pages,
                has_previous=page > 1
            )
        )

# Usage
def query_records(offset: int, limit: int) -> List[dict]:
    return db.execute(
        "SELECT * FROM records LIMIT %s OFFSET %s",
        (limit, offset)
    )

def count_records() -> int:
    return db.execute("SELECT COUNT(*) FROM records")[0][0]

paginator = OffsetPaginator(
    query_func=query_records,
    count_func=count_records,
    default_page_size=50
)

result = paginator.paginate(page=2, page_size=25)
```

## Step 2: Cursor-based pagination

More efficient for large datasets:

```python
from typing import Optional, Tuple
import base64
import json

@dataclass
class CursorPageInfo:
    """Cursor pagination metadata."""
    cursor: Optional[str]
    has_next: bool
    has_previous: bool
    page_size: int

@dataclass
class CursorPaginatedResult(Generic[T]):
    """Cursor-paginated result."""
    items: List[T]
    next_cursor: Optional[str]
    previous_cursor: Optional[str]
    page_info: CursorPageInfo

    def to_dict(self) -> dict:
        return {
            "items": self.items,
            "next_cursor": self.next_cursor,
            "previous_cursor": self.previous_cursor,
            "has_next": self.page_info.has_next,
            "has_previous": self.page_info.has_previous
        }

class CursorPaginator(Paginator[T]):
    """Cursor-based pagination."""

    def __init__(
        self,
        query_func,
        cursor_field: str = "id",
        **kwargs
    ):
        super().__init__(**kwargs)
        self.query_func = query_func
        self.cursor_field = cursor_field

    def encode_cursor(self, value: Any) -> str:
        """Encode cursor value."""
        data = json.dumps({"v": value, "f": self.cursor_field})
        return base64.urlsafe_b64encode(data.encode()).decode()

    def decode_cursor(self, cursor: str) -> Tuple[str, Any]:
        """Decode cursor to field and value."""
        try:
            data = json.loads(base64.urlsafe_b64decode(cursor))
            return data["f"], data["v"]
        except Exception:
            raise ValueError("Invalid cursor")

    def paginate(
        self,
        cursor: str = None,
        page_size: int = None,
        direction: str = "forward"
    ) -> CursorPaginatedResult[T]:
        """Get page using cursor."""
        page_size = page_size or self.default_page_size
        _, page_size = self.validate_params(1, page_size)

        # Decode cursor if provided
        cursor_value = None
        if cursor:
            _, cursor_value = self.decode_cursor(cursor)

        # Query with cursor
        # Fetch one extra to check if there's more
        items = self.query_func(
            cursor_field=self.cursor_field,
            cursor_value=cursor_value,
            limit=page_size + 1,
            direction=direction
        )

        has_more = len(items) > page_size
        if has_more:
            items = items[:page_size]

        # Build cursors
        next_cursor = None
        previous_cursor = None

        if items:
            if has_more:
                next_cursor = self.encode_cursor(
                    items[-1][self.cursor_field]
                )
            if cursor_value:
                previous_cursor = self.encode_cursor(
                    items[0][self.cursor_field]
                )

        return CursorPaginatedResult(
            items=items,
            next_cursor=next_cursor,
            previous_cursor=previous_cursor,
            page_info=CursorPageInfo(
                cursor=cursor,
                has_next=has_more,
                has_previous=cursor_value is not None,
                page_size=page_size
            )
        )

# Usage
def query_with_cursor(
    cursor_field: str,
    cursor_value: Any,
    limit: int,
    direction: str
) -> List[dict]:
    if cursor_value and direction == "forward":
        return db.execute(
            f"SELECT * FROM records WHERE {cursor_field} > %s ORDER BY {cursor_field} LIMIT %s",
            (cursor_value, limit)
        )
    elif cursor_value and direction == "backward":
        return db.execute(
            f"SELECT * FROM records WHERE {cursor_field} < %s ORDER BY {cursor_field} DESC LIMIT %s",
            (cursor_value, limit)
        )
    else:
        return db.execute(
            f"SELECT * FROM records ORDER BY {cursor_field} LIMIT %s",
            (limit,)
        )

paginator = CursorPaginator(
    query_func=query_with_cursor,
    cursor_field="id"
)

# First page
result = paginator.paginate(page_size=50)

# Next page
if result.next_cursor:
    next_result = paginator.paginate(cursor=result.next_cursor)
```

## Step 3: Keyset pagination

Efficient for sorted large datasets:

```python
from typing import List, Tuple, Dict, Any

@dataclass
class KeysetCursor:
    """Multi-column keyset cursor."""
    columns: List[str]
    values: List[Any]

    def encode(self) -> str:
        data = {"c": self.columns, "v": self.values}
        return base64.urlsafe_b64encode(json.dumps(data).encode()).decode()

    @classmethod
    def decode(cls, cursor: str) -> 'KeysetCursor':
        data = json.loads(base64.urlsafe_b64decode(cursor))
        return cls(columns=data["c"], values=data["v"])

class KeysetPaginator(Paginator[T]):
    """Keyset pagination for sorted queries."""

    def __init__(
        self,
        query_func,
        sort_columns: List[Tuple[str, str]],  # [(column, direction), ...]
        **kwargs
    ):
        super().__init__(**kwargs)
        self.query_func = query_func
        self.sort_columns = sort_columns

    def build_keyset_condition(
        self,
        cursor: KeysetCursor
    ) -> Tuple[str, List[Any]]:
        """Build WHERE clause for keyset."""
        conditions = []
        params = []

        # Build compound condition
        for i, (col, direction) in enumerate(self.sort_columns):
            if i >= len(cursor.values):
                break

            # Previous columns equal, this column compared
            eq_conditions = []
            for j in range(i):
                eq_conditions.append(f"{self.sort_columns[j][0]} = %s")
                params.append(cursor.values[j])

            op = ">" if direction == "ASC" else "<"
            eq_conditions.append(f"{col} {op} %s")
            params.append(cursor.values[i])

            conditions.append(f"({' AND '.join(eq_conditions)})")

        return " OR ".join(conditions), params

    def paginate(
        self,
        cursor: str = None,
        page_size: int = None
    ) -> CursorPaginatedResult[T]:
        """Paginate using keyset."""
        page_size = page_size or self.default_page_size
        _, page_size = self.validate_params(1, page_size)

        keyset_cursor = None
        if cursor:
            keyset_cursor = KeysetCursor.decode(cursor)

        items = self.query_func(
            keyset_cursor=keyset_cursor,
            sort_columns=self.sort_columns,
            limit=page_size + 1
        )

        has_more = len(items) > page_size
        if has_more:
            items = items[:page_size]

        # Build next cursor
        next_cursor = None
        if items and has_more:
            last_item = items[-1]
            cursor_values = [
                last_item[col] for col, _ in self.sort_columns
            ]
            next_cursor = KeysetCursor(
                columns=[col for col, _ in self.sort_columns],
                values=cursor_values
            ).encode()

        return CursorPaginatedResult(
            items=items,
            next_cursor=next_cursor,
            previous_cursor=None,  # Keyset typically forward-only
            page_info=CursorPageInfo(
                cursor=cursor,
                has_next=has_more,
                has_previous=cursor is not None,
                page_size=page_size
            )
        )

# Usage
paginator = KeysetPaginator(
    query_func=query_with_keyset,
    sort_columns=[("created_at", "DESC"), ("id", "DESC")]
)
```

## Step 4: MCP tool with pagination

Build paginated MCP tools:

```python
from typing import Optional

class PaginatedTool:
    """MCP tool with pagination support."""

    def __init__(
        self,
        name: str,
        paginator: Paginator,
        description: str = ""
    ):
        self.name = name
        self.paginator = paginator
        self.description = description

    def get_schema(self) -> dict:
        """Get tool schema with pagination params."""
        return {
            "name": self.name,
            "description": self.description,
            "parameters": {
                "type": "object",
                "properties": {
                    "page": {
                        "type": "integer",
                        "description": "Page number (1-indexed)",
                        "default": 1
                    },
                    "page_size": {
                        "type": "integer",
                        "description": "Items per page",
                        "default": self.paginator.default_page_size,
                        "maximum": self.paginator.max_page_size
                    },
                    "cursor": {
                        "type": "string",
                        "description": "Cursor for cursor-based pagination"
                    }
                }
            }
        }

    def execute(
        self,
        page: int = 1,
        page_size: int = None,
        cursor: str = None,
        **kwargs
    ) -> dict:
        """Execute paginated query."""
        if cursor and isinstance(self.paginator, CursorPaginator):
            result = self.paginator.paginate(
                cursor=cursor,
                page_size=page_size
            )
        else:
            result = self.paginator.paginate(
                page=page,
                page_size=page_size
            )

        return result.to_dict()

# Usage
list_users_tool = PaginatedTool(
    name="list_users",
    paginator=OffsetPaginator(
        query_func=query_users,
        count_func=count_users
    ),
    description="List users with pagination"
)

# Execute
result = list_users_tool.execute(page=2, page_size=25)
```

## Step 5: Auto-pagination iterator

Iterate through all pages:

```python
from typing import Iterator, AsyncIterator

class PaginationIterator(Iterator[T]):
    """Iterate through all pages."""

    def __init__(
        self,
        paginator: Paginator,
        page_size: int = None
    ):
        self.paginator = paginator
        self.page_size = page_size
        self.current_page = 0
        self.current_items = []
        self.item_index = 0
        self.exhausted = False

    def __iter__(self):
        return self

    def __next__(self) -> T:
        # Get next item from current page
        if self.item_index < len(self.current_items):
            item = self.current_items[self.item_index]
            self.item_index += 1
            return item

        # Fetch next page
        if self.exhausted:
            raise StopIteration

        self.current_page += 1
        result = self.paginator.paginate(
            page=self.current_page,
            page_size=self.page_size
        )

        self.current_items = result.items
        self.item_index = 0
        self.exhausted = not result.page_info.has_next

        if not self.current_items:
            raise StopIteration

        return self.__next__()

class AsyncPaginationIterator(AsyncIterator[T]):
    """Async pagination iterator."""

    def __init__(
        self,
        fetch_page,
        page_size: int = 50
    ):
        self.fetch_page = fetch_page
        self.page_size = page_size
        self.cursor = None
        self.current_items = []
        self.item_index = 0
        self.exhausted = False

    def __aiter__(self):
        return self

    async def __anext__(self) -> T:
        if self.item_index < len(self.current_items):
            item = self.current_items[self.item_index]
            self.item_index += 1
            return item

        if self.exhausted:
            raise StopAsyncIteration

        result = await self.fetch_page(
            cursor=self.cursor,
            page_size=self.page_size
        )

        self.current_items = result.items
        self.cursor = result.next_cursor
        self.item_index = 0
        self.exhausted = not result.page_info.has_next

        if not self.current_items:
            raise StopAsyncIteration

        return await self.__anext__()

# Usage
def process_all_records():
    """Process all records page by page."""
    iterator = PaginationIterator(paginator, page_size=100)

    for record in iterator:
        process_record(record)

async def process_all_async():
    """Process all records asynchronously."""
    async for record in AsyncPaginationIterator(fetch_page):
        await process_record(record)
```

## Step 6: Pagination caching

Cache paginated results:

```python
import hashlib
from typing import Optional
from functools import lru_cache

class CachedPaginator:
    """Paginator with caching."""

    def __init__(
        self,
        paginator: Paginator,
        cache,
        ttl: int = 300
    ):
        self.paginator = paginator
        self.cache = cache
        self.ttl = ttl

    def _cache_key(
        self,
        page: int,
        page_size: int,
        **filters
    ) -> str:
        """Generate cache key."""
        key_data = f"pagination:{page}:{page_size}:{hash(frozenset(filters.items()))}"
        return hashlib.md5(key_data.encode()).hexdigest()

    def paginate(
        self,
        page: int = 1,
        page_size: int = None,
        use_cache: bool = True,
        **filters
    ) -> PaginatedResult:
        """Paginate with caching."""
        cache_key = self._cache_key(page, page_size or 50, **filters)

        # Check cache
        if use_cache:
            cached = self.cache.get(cache_key)
            if cached:
                return cached

        # Fetch from source
        result = self.paginator.paginate(page=page, page_size=page_size)

        # Cache result
        self.cache.set(cache_key, result, ttl=self.ttl)

        return result

    def invalidate(self, **filters):
        """Invalidate cached pages."""
        # Invalidate all pages for these filters
        pattern = f"pagination:*:{hash(frozenset(filters.items()))}"
        self.cache.delete_pattern(pattern)
```

## Summary

MCP pagination patterns:

1. **Offset pagination** - Simple, random access
2. **Cursor pagination** - Efficient, consistent
3. **Keyset pagination** - Fast for sorted data
4. **Tool integration** - Paginated MCP tools
5. **Auto-iteration** - Process all pages
6. **Caching** - Cache paginated results

Build tools with [Gantz](https://gantz.run), paginate for scale.

Pages beat payloads.

## Related reading

- [MCP Batching](/post/mcp-batching/) - Batch paginated requests
- [MCP Caching](/post/mcp-caching/) - Cache pages
- [MCP Performance](/post/mcp-performance/) - Optimize queries

---

*What pagination strategy do you prefer? Share your approach.*
