+++
title = "PostgreSQL MCP Integration: Database Tools for AI Agents"
image = "images/postgresql-mcp-integration.webp"
date = 2025-12-05
description = "Build MCP tools for PostgreSQL operations. Query execution, schema introspection, and AI-powered database interactions."
draft = false
tags = ['mcp', 'postgresql', 'database', 'sql']
voice = false

[howto]
name = "Integrate PostgreSQL with MCP"
totalTime = 30
[[howto.steps]]
name = "Set up database connection"
text = "Configure PostgreSQL connection pooling."
[[howto.steps]]
name = "Create query tools"
text = "Build tools for SQL execution."
[[howto.steps]]
name = "Add schema introspection"
text = "Tools to explore database structure."
[[howto.steps]]
name = "Implement safe operations"
text = "Add read-only and parameterized queries."
[[howto.steps]]
name = "Add AI-powered queries"
text = "Natural language to SQL generation."
+++


PostgreSQL stores your data. MCP tools unlock it for AI.

Together, they enable intelligent database interactions.

## Why PostgreSQL + MCP

PostgreSQL provides:
- Reliable data storage
- Complex queries
- Full-text search
- JSON support

MCP tools enable:
- AI-driven queries
- Natural language access
- Automated analysis
- Schema understanding

## Step 1: Database connection

Using [Gantz](https://gantz.run):

```yaml
# gantz.yaml
name: postgresql-tools

env:
  DATABASE_URL: ${DATABASE_URL}

tools:
  - name: query_database
    description: Execute a read-only SQL query
    parameters:
      - name: query
        type: string
        required: true
      - name: params
        type: array
        required: false
    script:
      command: python
      args: ["tools/query.py"]

  - name: describe_table
    description: Get table schema and sample data
    parameters:
      - name: table_name
        type: string
        required: true
    script:
      command: python
      args: ["tools/describe.py"]

  - name: natural_language_query
    description: Convert natural language to SQL
    parameters:
      - name: question
        type: string
        required: true
    script:
      command: python
      args: ["tools/nl_query.py"]
```

Connection pool setup:

```python
# lib/database.py
import os
from contextlib import contextmanager
from typing import List, Dict, Any, Optional
import psycopg2
from psycopg2 import pool, sql
from psycopg2.extras import RealDictCursor

class DatabasePool:
    """PostgreSQL connection pool."""

    _instance: Optional['DatabasePool'] = None
    _pool: Optional[pool.ThreadedConnectionPool] = None

    def __new__(cls):
        if cls._instance is None:
            cls._instance = super().__new__(cls)
            cls._instance._initialize_pool()
        return cls._instance

    def _initialize_pool(self):
        """Initialize connection pool."""
        database_url = os.environ.get('DATABASE_URL')

        self._pool = pool.ThreadedConnectionPool(
            minconn=2,
            maxconn=10,
            dsn=database_url
        )

    @contextmanager
    def connection(self):
        """Get connection from pool."""
        conn = self._pool.getconn()
        try:
            yield conn
        finally:
            self._pool.putconn(conn)

    @contextmanager
    def cursor(self, dict_cursor: bool = True):
        """Get cursor from pool."""
        with self.connection() as conn:
            cursor_factory = RealDictCursor if dict_cursor else None
            with conn.cursor(cursor_factory=cursor_factory) as cur:
                yield cur

    def execute(
        self,
        query: str,
        params: tuple = None,
        fetch: bool = True
    ) -> List[Dict[str, Any]]:
        """Execute query and return results."""
        with self.cursor() as cur:
            cur.execute(query, params)

            if fetch and cur.description:
                return [dict(row) for row in cur.fetchall()]
            return []

    def execute_many(
        self,
        query: str,
        params_list: List[tuple]
    ) -> int:
        """Execute query with multiple parameter sets."""
        with self.connection() as conn:
            with conn.cursor() as cur:
                cur.executemany(query, params_list)
                conn.commit()
                return cur.rowcount

# Global instance
db = DatabasePool()
```

## Step 2: Query tools

Safe query execution:

```python
# tools/query.py
import sys
import json
from lib.database import db

class QueryTool:
    """Tool for executing read-only queries."""

    # Allowed operations for read-only mode
    READ_ONLY_PREFIXES = ('SELECT', 'WITH', 'EXPLAIN')

    def __init__(self, read_only: bool = True):
        self.read_only = read_only

    def execute(self, query: str, params: list = None) -> dict:
        """Execute SQL query."""
        # Validate query
        normalized = query.strip().upper()

        if self.read_only:
            if not any(normalized.startswith(p) for p in self.READ_ONLY_PREFIXES):
                return {
                    'success': False,
                    'error': 'Only SELECT queries allowed in read-only mode'
                }

        try:
            results = db.execute(query, tuple(params) if params else None)

            return {
                'success': True,
                'data': results,
                'row_count': len(results)
            }
        except Exception as e:
            return {
                'success': False,
                'error': str(e)
            }

    def explain(self, query: str) -> dict:
        """Get query execution plan."""
        try:
            explain_query = f"EXPLAIN (FORMAT JSON, ANALYZE) {query}"
            results = db.execute(explain_query)

            return {
                'success': True,
                'plan': results[0]['QUERY PLAN'] if results else None
            }
        except Exception as e:
            return {
                'success': False,
                'error': str(e)
            }

if __name__ == '__main__':
    params = json.loads(sys.argv[1]) if len(sys.argv) > 1 else {}

    tool = QueryTool(read_only=True)
    result = tool.execute(
        params.get('query', ''),
        params.get('params', [])
    )

    print(json.dumps(result))
```

## Step 3: Schema introspection

Explore database structure:

```python
# tools/describe.py
import sys
import json
from lib.database import db

class SchemaIntrospector:
    """Introspect PostgreSQL schema."""

    def list_tables(self) -> dict:
        """List all tables in database."""
        query = """
            SELECT
                table_name,
                table_type
            FROM information_schema.tables
            WHERE table_schema = 'public'
            ORDER BY table_name
        """

        results = db.execute(query)
        return {'success': True, 'tables': results}

    def describe_table(self, table_name: str) -> dict:
        """Get table structure and statistics."""
        # Validate table name
        if not table_name.isidentifier():
            return {'success': False, 'error': 'Invalid table name'}

        # Get columns
        columns_query = """
            SELECT
                column_name,
                data_type,
                is_nullable,
                column_default,
                character_maximum_length
            FROM information_schema.columns
            WHERE table_schema = 'public'
            AND table_name = %s
            ORDER BY ordinal_position
        """

        columns = db.execute(columns_query, (table_name,))

        # Get indexes
        indexes_query = """
            SELECT
                indexname,
                indexdef
            FROM pg_indexes
            WHERE schemaname = 'public'
            AND tablename = %s
        """

        indexes = db.execute(indexes_query, (table_name,))

        # Get row count
        count_query = f'SELECT COUNT(*) as count FROM "{table_name}"'
        count_result = db.execute(count_query)
        row_count = count_result[0]['count'] if count_result else 0

        # Get sample data
        sample_query = f'SELECT * FROM "{table_name}" LIMIT 5'
        sample = db.execute(sample_query)

        return {
            'success': True,
            'table': table_name,
            'columns': columns,
            'indexes': indexes,
            'row_count': row_count,
            'sample_data': sample
        }

    def get_relationships(self, table_name: str) -> dict:
        """Get foreign key relationships."""
        query = """
            SELECT
                tc.constraint_name,
                kcu.column_name,
                ccu.table_name AS foreign_table_name,
                ccu.column_name AS foreign_column_name
            FROM information_schema.table_constraints AS tc
            JOIN information_schema.key_column_usage AS kcu
                ON tc.constraint_name = kcu.constraint_name
            JOIN information_schema.constraint_column_usage AS ccu
                ON ccu.constraint_name = tc.constraint_name
            WHERE tc.constraint_type = 'FOREIGN KEY'
            AND tc.table_name = %s
        """

        results = db.execute(query, (table_name,))
        return {'success': True, 'relationships': results}

    def get_schema_summary(self) -> dict:
        """Get complete schema summary."""
        tables = self.list_tables()

        if not tables['success']:
            return tables

        summary = []
        for table in tables['tables']:
            table_name = table['table_name']
            desc = self.describe_table(table_name)

            if desc['success']:
                summary.append({
                    'table': table_name,
                    'columns': len(desc['columns']),
                    'rows': desc['row_count'],
                    'column_names': [c['column_name'] for c in desc['columns']]
                })

        return {'success': True, 'schema': summary}

if __name__ == '__main__':
    params = json.loads(sys.argv[1]) if len(sys.argv) > 1 else {}

    introspector = SchemaIntrospector()
    result = introspector.describe_table(params.get('table_name', ''))

    print(json.dumps(result))
```

## Step 4: Natural language queries

AI-powered SQL generation:

```python
# tools/nl_query.py
import sys
import json
import anthropic
from lib.database import db

class NaturalLanguageQuery:
    """Convert natural language to SQL."""

    def __init__(self):
        self.client = anthropic.Anthropic()
        self.introspector = SchemaIntrospector()

    def get_schema_context(self) -> str:
        """Get schema for context."""
        summary = self.introspector.get_schema_summary()

        if not summary['success']:
            return ""

        context_parts = []
        for table in summary['schema']:
            cols = ", ".join(table['column_names'])
            context_parts.append(f"Table {table['table']}: {cols}")

        return "\n".join(context_parts)

    def generate_sql(self, question: str) -> dict:
        """Generate SQL from natural language."""
        schema_context = self.get_schema_context()

        prompt = f"""Given this PostgreSQL database schema:

{schema_context}

Convert this question to a SQL query:
{question}

Rules:
- Return ONLY the SQL query, no explanation
- Use SELECT queries only (read-only)
- Use proper PostgreSQL syntax
- Include appropriate JOINs if needed
- Limit results to 100 rows unless specified

SQL Query:"""

        try:
            response = self.client.messages.create(
                model="claude-sonnet-4-20250514",
                max_tokens=500,
                messages=[{"role": "user", "content": prompt}]
            )

            sql_query = response.content[0].text.strip()

            # Remove markdown code blocks if present
            if sql_query.startswith("```"):
                sql_query = sql_query.split("```")[1]
                if sql_query.startswith("sql"):
                    sql_query = sql_query[3:]
                sql_query = sql_query.strip()

            return {
                'success': True,
                'sql': sql_query,
                'question': question
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def query(self, question: str, execute: bool = True) -> dict:
        """Convert question to SQL and optionally execute."""
        # Generate SQL
        sql_result = self.generate_sql(question)

        if not sql_result['success']:
            return sql_result

        if not execute:
            return sql_result

        # Execute the generated SQL
        query_tool = QueryTool(read_only=True)
        exec_result = query_tool.execute(sql_result['sql'])

        return {
            'success': exec_result['success'],
            'question': question,
            'sql': sql_result['sql'],
            'data': exec_result.get('data', []),
            'row_count': exec_result.get('row_count', 0),
            'error': exec_result.get('error')
        }

if __name__ == '__main__':
    params = json.loads(sys.argv[1]) if len(sys.argv) > 1 else {}

    tool = NaturalLanguageQuery()
    result = tool.query(
        params.get('question', ''),
        execute=params.get('execute', True)
    )

    print(json.dumps(result))
```

## Step 5: Data analysis tools

AI-powered analysis:

```python
# tools/analyze.py
import json
import anthropic
from lib.database import db

class DataAnalyzer:
    """AI-powered data analysis."""

    def __init__(self):
        self.client = anthropic.Anthropic()

    def analyze_table(self, table_name: str) -> dict:
        """Analyze table data and provide insights."""
        # Get table info
        introspector = SchemaIntrospector()
        table_info = introspector.describe_table(table_name)

        if not table_info['success']:
            return table_info

        # Get statistics
        stats = self._get_statistics(table_name, table_info['columns'])

        # Generate insights
        insights = self._generate_insights(table_name, table_info, stats)

        return {
            'success': True,
            'table': table_name,
            'statistics': stats,
            'insights': insights
        }

    def _get_statistics(self, table_name: str, columns: list) -> dict:
        """Get statistical summary of table."""
        stats = {}

        for col in columns:
            col_name = col['column_name']
            col_type = col['data_type']

            if col_type in ('integer', 'bigint', 'numeric', 'real', 'double precision'):
                query = f"""
                    SELECT
                        MIN("{col_name}") as min,
                        MAX("{col_name}") as max,
                        AVG("{col_name}")::numeric(10,2) as avg,
                        COUNT(DISTINCT "{col_name}") as distinct_count
                    FROM "{table_name}"
                """
                result = db.execute(query)
                stats[col_name] = result[0] if result else {}

            elif col_type in ('character varying', 'text'):
                query = f"""
                    SELECT
                        COUNT(DISTINCT "{col_name}") as distinct_count,
                        MIN(LENGTH("{col_name}")) as min_length,
                        MAX(LENGTH("{col_name}")) as max_length
                    FROM "{table_name}"
                """
                result = db.execute(query)
                stats[col_name] = result[0] if result else {}

        return stats

    def _generate_insights(self, table_name: str, table_info: dict, stats: dict) -> str:
        """Generate AI insights from data."""
        prompt = f"""Analyze this database table and provide insights:

Table: {table_name}
Columns: {json.dumps(table_info['columns'], indent=2)}
Row Count: {table_info['row_count']}
Statistics: {json.dumps(stats, indent=2)}
Sample Data: {json.dumps(table_info['sample_data'][:3], indent=2)}

Provide:
1. Data quality observations
2. Potential issues or anomalies
3. Suggested indexes or optimizations
4. Interesting patterns in the sample data

Keep the analysis concise and actionable."""

        response = self.client.messages.create(
            model="claude-sonnet-4-20250514",
            max_tokens=1000,
            messages=[{"role": "user", "content": prompt}]
        )

        return response.content[0].text
```

## Step 6: Migration tools

Schema management:

```python
# tools/migrations.py
from lib.database import db
from datetime import datetime

class MigrationTool:
    """Database migration helper."""

    def get_migration_status(self) -> dict:
        """Get applied migrations."""
        # Check if migrations table exists
        check_query = """
            SELECT EXISTS (
                SELECT FROM information_schema.tables
                WHERE table_schema = 'public'
                AND table_name = 'schema_migrations'
            )
        """

        result = db.execute(check_query)

        if not result[0]['exists']:
            return {
                'success': True,
                'migrations': [],
                'message': 'No migrations table found'
            }

        query = """
            SELECT version, applied_at
            FROM schema_migrations
            ORDER BY applied_at DESC
        """

        migrations = db.execute(query)

        return {
            'success': True,
            'migrations': migrations
        }

    def suggest_indexes(self, table_name: str) -> dict:
        """Suggest indexes based on query patterns."""
        # Get table statistics
        query = """
            SELECT
                schemaname,
                relname,
                seq_scan,
                seq_tup_read,
                idx_scan,
                idx_tup_fetch
            FROM pg_stat_user_tables
            WHERE relname = %s
        """

        stats = db.execute(query, (table_name,))

        if not stats:
            return {'success': False, 'error': 'Table not found'}

        table_stats = stats[0]
        seq_scans = table_stats['seq_scan'] or 0
        idx_scans = table_stats['idx_scan'] or 0

        suggestions = []

        if seq_scans > idx_scans * 10:
            suggestions.append(
                f"High sequential scans ({seq_scans}). Consider adding indexes."
            )

        # Get unused indexes
        unused_query = """
            SELECT indexrelname, idx_scan
            FROM pg_stat_user_indexes
            WHERE relname = %s
            AND idx_scan = 0
        """

        unused = db.execute(unused_query, (table_name,))

        if unused:
            suggestions.append(
                f"Found {len(unused)} unused indexes that could be removed."
            )

        return {
            'success': True,
            'table': table_name,
            'stats': table_stats,
            'suggestions': suggestions,
            'unused_indexes': unused
        }
```

## Summary

PostgreSQL + MCP integration:

1. **Connection pooling** - Efficient database access
2. **Query tools** - Safe SQL execution
3. **Schema introspection** - Explore structure
4. **Natural language** - AI-powered queries
5. **Data analysis** - Automated insights
6. **Migration tools** - Schema management

Build tools with [Gantz](https://gantz.run), unlock your database.

Data meets intelligence.

## Related reading

- [MongoDB MCP Integration](/post/mongodb-mcp-integration/) - NoSQL tools
- [MCP Connection Pooling](/post/mcp-connection-pooling/) - Pool connections
- [Agent Database Patterns](/post/agent-database-patterns/) - Best practices

---

*How do you integrate databases with AI agents? Share your approach.*
