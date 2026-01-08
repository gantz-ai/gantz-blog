+++
title = "SQLite MCP Tools: Embedded Database for AI Agents"
image = "images/sqlite-mcp-tools.webp"
date = 2025-12-21
description = "Build MCP tools for SQLite. Local database operations, in-memory caching, and portable data storage for AI applications."
summary = "SQLite runs everywhere - no server required. Build MCP tools for local database queries, in-memory caching that persists across agent calls, full-text search with FTS5, and natural language to SQL translation. Perfect for desktop apps, CLI tools, and anywhere you need persistent data without managing infrastructure."
draft = false
tags = ['mcp', 'sqlite', 'database', 'local']
voice = false

[howto]
name = "Build SQLite MCP Tools"
totalTime = 25
[[howto.steps]]
name = "Set up SQLite connection"
text = "Configure SQLite with connection management."
[[howto.steps]]
name = "Create query tools"
text = "Build SQL execution tools."
[[howto.steps]]
name = "Add schema tools"
text = "Schema introspection and management."
[[howto.steps]]
name = "Implement backup tools"
text = "Database backup and restore."
[[howto.steps]]
name = "Add AI query generation"
text = "Natural language to SQL."
+++


SQLite is everywhere. AI agents need local data.

Together, they enable portable intelligent applications.

## Why SQLite + MCP

SQLite provides:
- Zero configuration
- Serverless operation
- Single file storage
- Cross-platform

MCP tools enable:
- AI-driven queries
- Local data processing
- Portable applications
- Offline operation

## Step 1: SQLite connection

Using [Gantz](https://gantz.run):

```yaml
# gantz.yaml
name: sqlite-tools

env:
  SQLITE_DB_PATH: ${SQLITE_DB_PATH:-./data.db}

tools:
  - name: execute_query
    description: Execute SQL query
    parameters:
      - name: query
        type: string
        required: true
      - name: params
        type: array
        required: false
    script:
      command: python
      args: ["tools/sqlite.py", "query"]

  - name: describe_database
    description: Get database schema
    script:
      command: python
      args: ["tools/sqlite.py", "describe"]
```

SQLite connection manager:

```python
# lib/sqlite_client.py
import os
import sqlite3
from typing import Optional, List, Dict, Any
from contextlib import contextmanager

class SQLiteClient:
    """SQLite connection manager."""

    _instance: Optional['SQLiteClient'] = None

    def __new__(cls, db_path: str = None):
        if cls._instance is None:
            cls._instance = super().__new__(cls)
            cls._instance._initialize(db_path)
        return cls._instance

    def _initialize(self, db_path: str = None):
        """Initialize SQLite connection."""
        self.db_path = db_path or os.environ.get('SQLITE_DB_PATH', './data.db')

    @contextmanager
    def connection(self):
        """Get database connection."""
        conn = sqlite3.connect(self.db_path)
        conn.row_factory = sqlite3.Row
        try:
            yield conn
        finally:
            conn.close()

    @contextmanager
    def cursor(self):
        """Get database cursor."""
        with self.connection() as conn:
            cursor = conn.cursor()
            try:
                yield cursor
                conn.commit()
            except Exception:
                conn.rollback()
                raise

    def execute(
        self,
        query: str,
        params: tuple = None,
        fetch: bool = True
    ) -> List[Dict[str, Any]]:
        """Execute query and return results."""
        with self.cursor() as cur:
            cur.execute(query, params or ())

            if fetch and cur.description:
                columns = [col[0] for col in cur.description]
                return [dict(zip(columns, row)) for row in cur.fetchall()]
            return []

    def execute_many(
        self,
        query: str,
        params_list: List[tuple]
    ) -> int:
        """Execute query with multiple parameter sets."""
        with self.cursor() as cur:
            cur.executemany(query, params_list)
            return cur.rowcount

    def execute_script(self, script: str):
        """Execute SQL script."""
        with self.connection() as conn:
            conn.executescript(script)

# Global instance
db = SQLiteClient()
```

## Step 2: Query tools

SQL execution:

```python
# tools/sqlite.py
import sys
import json
from lib.sqlite_client import db

class QueryTool:
    """Tool for SQLite query execution."""

    def __init__(self, read_only: bool = False):
        self.read_only = read_only

    def execute(
        self,
        query: str,
        params: list = None
    ) -> dict:
        """Execute SQL query."""
        # Validate for read-only mode
        if self.read_only:
            normalized = query.strip().upper()
            if not normalized.startswith(('SELECT', 'WITH', 'EXPLAIN', 'PRAGMA')):
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
            return {'success': False, 'error': str(e)}

    def insert(
        self,
        table: str,
        data: dict
    ) -> dict:
        """Insert row into table."""
        if self.read_only:
            return {'success': False, 'error': 'Read-only mode'}

        try:
            columns = ', '.join(data.keys())
            placeholders = ', '.join(['?' for _ in data])
            query = f'INSERT INTO {table} ({columns}) VALUES ({placeholders})'

            with db.cursor() as cur:
                cur.execute(query, tuple(data.values()))
                return {
                    'success': True,
                    'id': cur.lastrowid
                }
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def update(
        self,
        table: str,
        data: dict,
        where: dict
    ) -> dict:
        """Update rows in table."""
        if self.read_only:
            return {'success': False, 'error': 'Read-only mode'}

        try:
            set_clause = ', '.join([f'{k} = ?' for k in data.keys()])
            where_clause = ' AND '.join([f'{k} = ?' for k in where.keys()])
            query = f'UPDATE {table} SET {set_clause} WHERE {where_clause}'

            params = list(data.values()) + list(where.values())

            with db.cursor() as cur:
                cur.execute(query, params)
                return {
                    'success': True,
                    'affected': cur.rowcount
                }
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def delete(
        self,
        table: str,
        where: dict
    ) -> dict:
        """Delete rows from table."""
        if self.read_only:
            return {'success': False, 'error': 'Read-only mode'}

        try:
            where_clause = ' AND '.join([f'{k} = ?' for k in where.keys()])
            query = f'DELETE FROM {table} WHERE {where_clause}'

            with db.cursor() as cur:
                cur.execute(query, tuple(where.values()))
                return {
                    'success': True,
                    'deleted': cur.rowcount
                }
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def batch_insert(
        self,
        table: str,
        rows: list
    ) -> dict:
        """Insert multiple rows."""
        if self.read_only:
            return {'success': False, 'error': 'Read-only mode'}

        if not rows:
            return {'success': True, 'inserted': 0}

        try:
            columns = ', '.join(rows[0].keys())
            placeholders = ', '.join(['?' for _ in rows[0]])
            query = f'INSERT INTO {table} ({columns}) VALUES ({placeholders})'

            params_list = [tuple(row.values()) for row in rows]
            count = db.execute_many(query, params_list)

            return {
                'success': True,
                'inserted': count
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}

if __name__ == '__main__':
    operation = sys.argv[1] if len(sys.argv) > 1 else 'query'
    params = json.loads(sys.argv[2]) if len(sys.argv) > 2 else {}

    tool = QueryTool(read_only=False)

    if operation == 'query':
        result = tool.execute(
            params.get('query', ''),
            params.get('params', [])
        )
    elif operation == 'insert':
        result = tool.insert(
            params.get('table', ''),
            params.get('data', {})
        )
    else:
        result = {'success': False, 'error': f'Unknown operation: {operation}'}

    print(json.dumps(result))
```

## Step 3: Schema tools

Database introspection:

```python
# tools/schema.py
import json
from lib.sqlite_client import db

class SchemaTool:
    """Tool for SQLite schema introspection."""

    def list_tables(self) -> dict:
        """List all tables."""
        try:
            query = """
                SELECT name, type
                FROM sqlite_master
                WHERE type IN ('table', 'view')
                AND name NOT LIKE 'sqlite_%'
                ORDER BY name
            """

            tables = db.execute(query)

            return {
                'success': True,
                'tables': tables
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def describe_table(self, table_name: str) -> dict:
        """Get table structure."""
        try:
            # Validate table name
            if not table_name.replace('_', '').isalnum():
                return {'success': False, 'error': 'Invalid table name'}

            # Get columns
            columns = db.execute(f'PRAGMA table_info({table_name})')

            # Get indexes
            indexes = db.execute(f'PRAGMA index_list({table_name})')

            # Get foreign keys
            foreign_keys = db.execute(f'PRAGMA foreign_key_list({table_name})')

            # Get row count
            count_result = db.execute(f'SELECT COUNT(*) as count FROM {table_name}')
            row_count = count_result[0]['count'] if count_result else 0

            # Get sample data
            sample = db.execute(f'SELECT * FROM {table_name} LIMIT 5')

            return {
                'success': True,
                'table': table_name,
                'columns': [
                    {
                        'name': col['name'],
                        'type': col['type'],
                        'nullable': not col['notnull'],
                        'default': col['dflt_value'],
                        'primary_key': bool(col['pk'])
                    }
                    for col in columns
                ],
                'indexes': indexes,
                'foreign_keys': foreign_keys,
                'row_count': row_count,
                'sample': sample
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def get_schema_sql(self, table_name: str = None) -> dict:
        """Get CREATE statements."""
        try:
            if table_name:
                query = """
                    SELECT sql FROM sqlite_master
                    WHERE name = ? AND sql IS NOT NULL
                """
                results = db.execute(query, (table_name,))
            else:
                query = """
                    SELECT name, sql FROM sqlite_master
                    WHERE sql IS NOT NULL
                    ORDER BY type, name
                """
                results = db.execute(query)

            return {
                'success': True,
                'schema': results
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def create_table(
        self,
        name: str,
        columns: list,
        if_not_exists: bool = True
    ) -> dict:
        """Create new table."""
        try:
            col_defs = []
            for col in columns:
                col_def = f"{col['name']} {col['type']}"

                if col.get('primary_key'):
                    col_def += ' PRIMARY KEY'
                if col.get('autoincrement'):
                    col_def += ' AUTOINCREMENT'
                if col.get('not_null'):
                    col_def += ' NOT NULL'
                if col.get('unique'):
                    col_def += ' UNIQUE'
                if 'default' in col:
                    col_def += f" DEFAULT {col['default']}"

                col_defs.append(col_def)

            exists = 'IF NOT EXISTS ' if if_not_exists else ''
            query = f"CREATE TABLE {exists}{name} ({', '.join(col_defs)})"

            db.execute(query, fetch=False)

            return {
                'success': True,
                'table': name
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def add_column(
        self,
        table: str,
        column: dict
    ) -> dict:
        """Add column to existing table."""
        try:
            col_def = f"{column['name']} {column['type']}"

            if column.get('not_null') and 'default' in column:
                col_def += f" NOT NULL DEFAULT {column['default']}"

            query = f"ALTER TABLE {table} ADD COLUMN {col_def}"
            db.execute(query, fetch=False)

            return {
                'success': True,
                'table': table,
                'column': column['name']
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}
```

## Step 4: Backup tools

Database backup and restore:

```python
# tools/backup.py
import os
import shutil
import sqlite3
from datetime import datetime
from lib.sqlite_client import db

class BackupTool:
    """Tool for SQLite backup operations."""

    def __init__(self, backup_dir: str = './backups'):
        self.backup_dir = backup_dir
        os.makedirs(backup_dir, exist_ok=True)

    def backup(self, name: str = None) -> dict:
        """Create database backup."""
        try:
            if not name:
                timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
                name = f'backup_{timestamp}.db'

            backup_path = os.path.join(self.backup_dir, name)

            # Use SQLite backup API
            with db.connection() as source:
                backup_conn = sqlite3.connect(backup_path)
                source.backup(backup_conn)
                backup_conn.close()

            size = os.path.getsize(backup_path)

            return {
                'success': True,
                'path': backup_path,
                'size': size
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def restore(self, backup_path: str) -> dict:
        """Restore database from backup."""
        try:
            if not os.path.exists(backup_path):
                return {
                    'success': False,
                    'error': 'Backup file not found'
                }

            # Verify backup is valid SQLite
            try:
                conn = sqlite3.connect(backup_path)
                conn.execute('SELECT 1')
                conn.close()
            except Exception:
                return {
                    'success': False,
                    'error': 'Invalid SQLite backup file'
                }

            # Replace current database
            shutil.copy2(backup_path, db.db_path)

            return {
                'success': True,
                'restored_from': backup_path
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def list_backups(self) -> dict:
        """List available backups."""
        try:
            backups = []

            for filename in os.listdir(self.backup_dir):
                if filename.endswith('.db'):
                    path = os.path.join(self.backup_dir, filename)
                    stat = os.stat(path)

                    backups.append({
                        'name': filename,
                        'path': path,
                        'size': stat.st_size,
                        'created': datetime.fromtimestamp(stat.st_mtime).isoformat()
                    })

            backups.sort(key=lambda x: x['created'], reverse=True)

            return {
                'success': True,
                'backups': backups
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def export_sql(self, output_path: str = None) -> dict:
        """Export database as SQL script."""
        try:
            if not output_path:
                timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
                output_path = os.path.join(self.backup_dir, f'export_{timestamp}.sql')

            with db.connection() as conn:
                with open(output_path, 'w') as f:
                    for line in conn.iterdump():
                        f.write(f'{line}\n')

            size = os.path.getsize(output_path)

            return {
                'success': True,
                'path': output_path,
                'size': size
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def import_sql(self, sql_path: str) -> dict:
        """Import SQL script."""
        try:
            with open(sql_path, 'r') as f:
                script = f.read()

            db.execute_script(script)

            return {
                'success': True,
                'imported_from': sql_path
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}
```

## Step 5: Natural language queries

AI-powered SQL:

```python
# tools/nl_query.py
import json
import anthropic
from lib.sqlite_client import db

class NaturalLanguageQuery:
    """Convert natural language to SQLite queries."""

    def __init__(self):
        self.client = anthropic.Anthropic()
        self.schema_tool = SchemaTool()

    def get_schema_context(self) -> str:
        """Get schema for AI context."""
        tables_result = self.schema_tool.list_tables()

        if not tables_result['success']:
            return ""

        context_parts = []
        for table in tables_result['tables']:
            table_name = table['name']
            desc = self.schema_tool.describe_table(table_name)

            if desc['success']:
                cols = [f"{c['name']} ({c['type']})" for c in desc['columns']]
                context_parts.append(f"Table {table_name}: {', '.join(cols)}")

        return "\n".join(context_parts)

    def generate_sql(self, question: str) -> dict:
        """Generate SQL from natural language."""
        schema = self.get_schema_context()

        prompt = f"""Given this SQLite database schema:

{schema}

Convert this question to a SQL query:
{question}

Rules:
- Return ONLY the SQL query, no explanation
- Use standard SQLite syntax
- Use SELECT for read operations only
- Limit results to 100 rows unless specified

SQL Query:"""

        try:
            response = self.client.messages.create(
                model="claude-sonnet-4-20250514",
                max_tokens=500,
                messages=[{"role": "user", "content": prompt}]
            )

            sql = response.content[0].text.strip()

            # Clean up response
            if sql.startswith("```"):
                sql = sql.split("```")[1]
                if sql.startswith("sql"):
                    sql = sql[3:]
                sql = sql.strip()

            return {
                'success': True,
                'sql': sql,
                'question': question
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def query(self, question: str, execute: bool = True) -> dict:
        """Generate and execute natural language query."""
        result = self.generate_sql(question)

        if not result['success'] or not execute:
            return result

        query_tool = QueryTool(read_only=True)
        exec_result = query_tool.execute(result['sql'])

        return {
            'success': exec_result['success'],
            'question': question,
            'sql': result['sql'],
            'data': exec_result.get('data', []),
            'row_count': exec_result.get('row_count', 0),
            'error': exec_result.get('error')
        }
```

## Summary

SQLite + MCP integration:

1. **Connection management** - Safe database access
2. **Query tools** - CRUD operations
3. **Schema tools** - Introspection
4. **Backup tools** - Data safety
5. **Natural language** - AI-powered queries

Build tools with [Gantz](https://gantz.run), go portable with SQLite.

Local data, anywhere.

## Related reading

- [PostgreSQL MCP Integration](/post/postgresql-mcp-integration/) - Server database
- [MCP Caching](/post/mcp-caching/) - Cache strategies
- [Agent Data Patterns](/post/agent-data-patterns/) - Data access

---

*How do you use SQLite with AI agents? Share your approach.*
