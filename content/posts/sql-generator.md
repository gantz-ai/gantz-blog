+++
title = 'Build a SQL Query Generator from Natural Language'
date = 2025-11-23
draft = false
tags = ['agents', 'ai', 'mcp']
+++


"Show me customers who spent more than $1000 last month"

Wouldn't it be nice if your database understood that?

Let's build it.

## What we're building

A tool that converts plain English to SQL queries, runs them, and returns results.

```
User: "Find the top 5 products by revenue"

Agent:
1. Understands the request
2. Looks at your schema
3. Generates SQL: SELECT product_name, SUM(price * quantity) as revenue
                  FROM orders GROUP BY product_name
                  ORDER BY revenue DESC LIMIT 5
4. Runs query (with your approval)
5. Returns formatted results
```

No more googling SQL syntax. No more JOIN confusion.

## The architecture

```
┌─────────────────┐
│  Natural Lang   │
│    Question     │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│   AI Agent      │
│                 │
│  ┌───────────┐  │
│  │  Schema   │  │  ← Knows your tables
│  │  Context  │  │
│  └───────────┘  │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│   SQL Query     │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│   MCP Tools     │  ← Safe execution
│   (Gantz)       │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│   Database      │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│   Results       │
└─────────────────┘
```

## Step 1: Define the tools

Create MCP tools for database operations.

```yaml
# gantz.yaml
tools:
  - name: get_schema
    description: Get database schema (tables, columns, types)
    script:
      shell: |
        sqlite3 {{db_path}} ".schema"

  - name: get_tables
    description: List all tables in the database
    script:
      shell: |
        sqlite3 {{db_path}} ".tables"

  - name: describe_table
    description: Get columns and types for a specific table
    parameters:
      - name: table_name
        type: string
        required: true
    script:
      shell: |
        sqlite3 {{db_path}} "PRAGMA table_info({{table_name}});"

  - name: preview_table
    description: Show sample rows from a table
    parameters:
      - name: table_name
        type: string
        required: true
      - name: limit
        type: number
        default: 5
    script:
      shell: |
        sqlite3 -header -column {{db_path}} "SELECT * FROM {{table_name}} LIMIT {{limit}};"

  - name: run_query
    description: Execute a SELECT query (read-only)
    parameters:
      - name: query
        type: string
        required: true
    script:
      shell: |
        # Only allow SELECT queries
        if echo "{{query}}" | grep -iqE "^[[:space:]]*(INSERT|UPDATE|DELETE|DROP|CREATE|ALTER|TRUNCATE)"; then
          echo '{"error": "Only SELECT queries are allowed"}'
          exit 1
        fi
        sqlite3 -header -json {{db_path}} "{{query}}"

  - name: explain_query
    description: Show query execution plan
    parameters:
      - name: query
        type: string
        required: true
    script:
      shell: |
        sqlite3 {{db_path}} "EXPLAIN QUERY PLAN {{query}}"
```

Set your database path:

```bash
export db_path="./my_database.db"
gantz
```

Or run with [Gantz](https://gantz.run) remotely for Claude Desktop integration.

## Step 2: Create the system prompt

Give the AI context about SQL generation.

```python
SYSTEM_PROMPT = """You are a SQL query generator. You help users query databases using natural language.

Your workflow:
1. First, understand the database schema using get_schema or describe_table
2. Understand what the user wants
3. Generate the appropriate SQL query
4. Show the query to the user before running
5. Run the query and format results nicely

Rules:
- Only generate SELECT queries (read-only)
- Always check the schema before writing queries
- Use proper JOINs when data spans multiple tables
- Include column aliases for clarity
- Add comments explaining complex queries
- If the request is ambiguous, ask for clarification

When showing results:
- Format as a readable table
- Summarize large result sets
- Explain what the data shows
"""
```

## Step 3: Example queries

Let's see it in action with a sample e-commerce database.

**Schema:**
```sql
CREATE TABLE customers (
    id INTEGER PRIMARY KEY,
    name TEXT,
    email TEXT,
    created_at DATETIME
);

CREATE TABLE products (
    id INTEGER PRIMARY KEY,
    name TEXT,
    category TEXT,
    price DECIMAL
);

CREATE TABLE orders (
    id INTEGER PRIMARY KEY,
    customer_id INTEGER,
    product_id INTEGER,
    quantity INTEGER,
    order_date DATETIME,
    FOREIGN KEY (customer_id) REFERENCES customers(id),
    FOREIGN KEY (product_id) REFERENCES products(id)
);
```

### Example 1: Simple query

```
User: "How many customers do we have?"

Agent:
[calls get_schema to understand database]

I'll query the customers table:

SELECT COUNT(*) as customer_count FROM customers;

[calls run_query]

Result: You have 1,247 customers.
```

### Example 2: Aggregation

```
User: "What's the total revenue by category?"

Agent:
[calls describe_table for orders and products]

This requires joining orders with products:

SELECT
    p.category,
    SUM(p.price * o.quantity) as total_revenue
FROM orders o
JOIN products p ON o.product_id = p.id
GROUP BY p.category
ORDER BY total_revenue DESC;

[calls run_query]

Results:
┌─────────────┬───────────────┐
│ category    │ total_revenue │
├─────────────┼───────────────┤
│ Electronics │ $45,230.00    │
│ Clothing    │ $32,100.00    │
│ Books       │ $12,450.00    │
│ Home        │ $8,920.00     │
└─────────────┴───────────────┘
```

### Example 3: Complex analysis

```
User: "Show me customers who ordered more than 3 times but haven't ordered in the last 30 days"

Agent:
[calls get_schema]

This needs a subquery and date calculation:

SELECT
    c.name,
    c.email,
    COUNT(o.id) as total_orders,
    MAX(o.order_date) as last_order
FROM customers c
JOIN orders o ON c.id = o.customer_id
GROUP BY c.id
HAVING
    COUNT(o.id) > 3
    AND MAX(o.order_date) < DATE('now', '-30 days')
ORDER BY last_order ASC;

This finds loyal customers (>3 orders) who may be churning (no orders in 30 days).

[calls run_query]

Found 23 customers matching this criteria:
┌─────────────┬─────────────────────┬──────────────┬─────────────┐
│ name        │ email               │ total_orders │ last_order  │
├─────────────┼─────────────────────┼──────────────┼─────────────┤
│ John Smith  │ john@example.com    │ 7            │ 2024-10-15  │
│ Sarah Jones │ sarah@example.com   │ 5            │ 2024-10-20  │
│ ...         │ ...                 │ ...          │ ...         │
└─────────────┴─────────────────────┴──────────────┴─────────────┘

These might be good candidates for a re-engagement campaign.
```

## Step 4: Safety features

### Read-only enforcement

```yaml
- name: run_query
  script:
    shell: |
      # Reject non-SELECT queries
      query_upper=$(echo "{{query}}" | tr '[:lower:]' '[:upper:]')

      if [[ ! "$query_upper" =~ ^[[:space:]]*SELECT ]]; then
        echo '{"error": "Only SELECT queries allowed"}'
        exit 1
      fi

      # Block dangerous keywords even in SELECT
      if [[ "$query_upper" =~ (DROP|DELETE|INSERT|UPDATE|ALTER|TRUNCATE|EXEC|EXECUTE) ]]; then
        echo '{"error": "Query contains forbidden keywords"}'
        exit 1
      fi

      sqlite3 -header -json {{db_path}} "{{query}}"
```

### Query preview

Always show query before execution:

```python
def generate_and_run(question, tools):
    # Generate query
    query = generate_sql(question, schema)

    # Show to user
    print(f"Generated query:\n{query}\n")

    # Confirm
    if input("Run this query? (y/n): ").lower() != 'y':
        return "Query cancelled"

    # Execute
    return tools.run_query(query)
```

### Result limits

```yaml
- name: run_query
  parameters:
    - name: query
      type: string
      required: true
    - name: max_rows
      type: number
      default: 100
  script:
    shell: |
      # Add LIMIT if not present
      query="{{query}}"
      if ! echo "$query" | grep -qi "LIMIT"; then
        query="$query LIMIT {{max_rows}}"
      fi
      sqlite3 -header -json {{db_path}} "$query"
```

## Step 5: PostgreSQL version

Same concept, different database:

```yaml
# gantz-postgres.yaml
env:
  - PGHOST
  - PGPORT
  - PGUSER
  - PGPASSWORD
  - PGDATABASE

tools:
  - name: get_schema
    description: Get database schema
    script:
      shell: |
        psql -c "\dt" && psql -c "\d+"

  - name: describe_table
    description: Describe a table
    parameters:
      - name: table_name
        type: string
        required: true
    script:
      shell: |
        psql -c "\d {{table_name}}"

  - name: run_query
    description: Run a SELECT query
    parameters:
      - name: query
        type: string
        required: true
    script:
      shell: |
        # Read-only check
        if echo "{{query}}" | grep -iqE "^[[:space:]]*(INSERT|UPDATE|DELETE|DROP|CREATE|ALTER)"; then
          echo "Error: Only SELECT queries allowed"
          exit 1
        fi
        psql -c "{{query}}"

  - name: get_table_stats
    description: Get row counts and size for tables
    script:
      shell: |
        psql -c "SELECT relname, n_live_tup FROM pg_stat_user_tables ORDER BY n_live_tup DESC;"
```

## Step 6: Smart schema context

For large databases, don't load entire schema. Find relevant tables.

```yaml
- name: find_relevant_tables
  description: Find tables that might be relevant to a question
  parameters:
    - name: keywords
      type: string
      required: true
  script:
    shell: |
      # Search table and column names
      sqlite3 {{db_path}} "
        SELECT DISTINCT m.name as table_name
        FROM sqlite_master m
        JOIN pragma_table_info(m.name) p
        WHERE m.type='table'
          AND (m.name LIKE '%{{keywords}}%'
               OR p.name LIKE '%{{keywords}}%')
      "

- name: get_table_relationships
  description: Find foreign key relationships
  parameters:
    - name: table_name
      type: string
      required: true
  script:
    shell: |
      sqlite3 {{db_path}} "PRAGMA foreign_key_list({{table_name}});"
```

## Step 7: Query explanation

Help users understand the generated SQL:

```python
EXPLANATION_PROMPT = """Explain this SQL query in simple terms:

Query: {query}

Explain:
1. What tables are being used
2. What the query is doing step by step
3. What the results will show

Use simple language, avoid jargon."""
```

```
User: "What does this query do?"

Agent: This query:

1. Looks at the 'orders' and 'products' tables
2. Joins them by matching product IDs
3. Groups all orders by product category
4. Adds up (price × quantity) for each category
5. Sorts from highest to lowest revenue
6. Returns the category name and total revenue

In plain English: "Show me how much money each product category made,
with the best sellers at the top."
```

## Step 8: Common patterns library

Pre-built queries for common questions:

```python
QUERY_PATTERNS = {
    "top_n": """
        SELECT {column}, COUNT(*) as count
        FROM {table}
        GROUP BY {column}
        ORDER BY count DESC
        LIMIT {n}
    """,

    "time_series": """
        SELECT
            DATE({date_column}) as date,
            COUNT(*) as count
        FROM {table}
        WHERE {date_column} >= DATE('now', '-{days} days')
        GROUP BY DATE({date_column})
        ORDER BY date
    """,

    "growth": """
        SELECT
            strftime('%Y-%m', {date_column}) as month,
            COUNT(*) as count,
            COUNT(*) - LAG(COUNT(*)) OVER (ORDER BY strftime('%Y-%m', {date_column})) as growth
        FROM {table}
        GROUP BY month
    """,

    "cohort": """
        SELECT
            strftime('%Y-%m', c.created_at) as cohort,
            COUNT(DISTINCT c.id) as customers,
            COUNT(DISTINCT o.id) as orders
        FROM customers c
        LEFT JOIN orders o ON c.id = o.customer_id
        GROUP BY cohort
    """
}
```

## Full example session

```
User: "I want to analyze customer behavior"

Agent: I'll help you analyze customer behavior. Let me first understand your database.

[calls get_tables]
Tables: customers, orders, products, categories

[calls describe_table for each]

Your database has customer, order, and product data. Here are some analyses I can run:

1. Customer lifetime value (total spent per customer)
2. Purchase frequency (orders per customer)
3. Popular products by customer segment
4. Churn risk (customers who stopped ordering)
5. Cohort analysis (retention over time)

Which would you like to explore?

User: "Show me customer lifetime value"

Agent: I'll calculate total spending per customer:

SELECT
    c.id,
    c.name,
    c.email,
    COUNT(o.id) as total_orders,
    SUM(p.price * o.quantity) as lifetime_value,
    MIN(o.order_date) as first_order,
    MAX(o.order_date) as last_order
FROM customers c
JOIN orders o ON c.id = o.customer_id
JOIN products p ON o.product_id = p.id
GROUP BY c.id
ORDER BY lifetime_value DESC
LIMIT 20;

Run this query? (y/n)

User: "y"

[calls run_query]

Top 20 customers by lifetime value:
┌────┬───────────────┬─────────────────────┬────────┬────────────────┬─────────────┬─────────────┐
│ id │ name          │ email               │ orders │ lifetime_value │ first_order │ last_order  │
├────┼───────────────┼─────────────────────┼────────┼────────────────┼─────────────┼─────────────┤
│ 42 │ Alice Chen    │ alice@company.com   │ 23     │ $4,520.00      │ 2023-01-15  │ 2024-11-20  │
│ 17 │ Bob Williams  │ bob@email.com       │ 18     │ $3,890.00      │ 2023-03-22  │ 2024-11-18  │
│ 89 │ Carol Davis   │ carol@example.com   │ 15     │ $3,210.00      │ 2023-06-01  │ 2024-11-15  │
└────┴───────────────┴─────────────────────┴────────┴────────────────┴─────────────┴─────────────┘

Your top customer (Alice Chen) has spent $4,520 across 23 orders since January 2023.

Want me to dig deeper into any of these customers, or run a different analysis?
```

## Summary

Build a SQL generator with:

1. **Schema tools**: Let AI understand your database
2. **Safe query execution**: Read-only, with limits
3. **Query preview**: Always show before running
4. **Smart context**: Find relevant tables for large DBs
5. **Result formatting**: Make output human-readable

Run your tools with [Gantz](https://gantz.run) to connect AI agents to your database safely.

No more SQL syntax struggles. Just ask in plain English.

---

*What database queries do you wish you could ask in plain English?*
