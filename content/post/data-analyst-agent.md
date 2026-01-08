+++
title = "AI Data Analyst: Query Databases in Plain English"
image = "images/data-analyst-agent.webp"
date = 2025-11-08
description = "Build an AI data analyst agent that translates natural language to SQL queries. Chat with your database using plain English."
summary = "Non-technical stakeholders asking for data? Build an agent that translates 'show me last month's top customers' into the right SQL query. The agent inspects your schema, understands table relationships, generates safe parameterized queries, and can even visualize results. Turn your database into a conversational interface anyone can use."
draft = false
tags = ['mcp', 'tutorial', 'data-analysis']
voice = false

[howto]
name = "Build AI Data Analyst"
totalTime = 35
[[howto.steps]]
name = "Create database tools"
text = "Build MCP tools for database access and schema inspection."
[[howto.steps]]
name = "Implement query translator"
text = "Create the agent that converts English to SQL."
[[howto.steps]]
name = "Add safety guardrails"
text = "Implement query validation and read-only protections."
[[howto.steps]]
name = "Build visualization"
text = "Add tools for generating charts and reports."
[[howto.steps]]
name = "Create chat interface"
text = "Build an interactive data exploration interface."
+++


"How many users signed up last month?"

Type that. Get the answer. No SQL required.

That's what an AI data analyst does.

## Why AI for data analysis?

SQL is powerful. But:
- Not everyone knows SQL
- Complex queries take time to write
- Joining tables is error-prone
- Business users can't self-serve

AI data analysts:
- Understand natural language
- Know your schema
- Write correct SQL
- Explain results in plain English

## What you can ask

- "Show me top 10 customers by revenue"
- "Compare sales this quarter vs last quarter"
- "Which products are trending up?"
- "Find users who haven't logged in for 30 days"
- "What's our daily active user trend?"

## Step 1: Create database tools

Using [Gantz](https://gantz.run):

```yaml
# gantz.yaml
name: data-analyst

tools:
  - name: get_schema
    description: Get database schema including tables and columns
    script:
      shell: |
        psql "$DATABASE_URL" -c "\dt" --csv && \
        psql "$DATABASE_URL" -c "
          SELECT table_name, column_name, data_type, is_nullable
          FROM information_schema.columns
          WHERE table_schema = 'public'
          ORDER BY table_name, ordinal_position
        " --csv

  - name: get_table_info
    description: Get detailed information about a specific table
    parameters:
      - name: table_name
        type: string
        required: true
    script:
      shell: |
        psql "$DATABASE_URL" -c "\d {{table_name}}" && \
        psql "$DATABASE_URL" -c "SELECT COUNT(*) as row_count FROM {{table_name}}"

  - name: run_query
    description: Execute a read-only SQL query
    parameters:
      - name: query
        type: string
        required: true
        description: SQL SELECT query to execute
    script:
      shell: |
        # Only allow SELECT queries for safety
        query="{{query}}"
        if echo "$query" | grep -iqE "^\s*(insert|update|delete|drop|alter|create|truncate)"; then
          echo "Error: Only SELECT queries are allowed"
          exit 1
        fi
        psql "$DATABASE_URL" -c "$query" --csv

  - name: sample_data
    description: Get sample rows from a table
    parameters:
      - name: table_name
        type: string
        required: true
      - name: limit
        type: integer
        default: 5
    script:
      shell: |
        psql "$DATABASE_URL" -c "SELECT * FROM {{table_name}} LIMIT {{limit}}" --csv

  - name: get_relationships
    description: Get foreign key relationships between tables
    script:
      shell: |
        psql "$DATABASE_URL" -c "
          SELECT
            tc.table_name,
            kcu.column_name,
            ccu.table_name AS foreign_table_name,
            ccu.column_name AS foreign_column_name
          FROM information_schema.table_constraints AS tc
          JOIN information_schema.key_column_usage AS kcu
            ON tc.constraint_name = kcu.constraint_name
          JOIN information_schema.constraint_column_usage AS ccu
            ON ccu.constraint_name = tc.constraint_name
          WHERE tc.constraint_type = 'FOREIGN KEY'
        " --csv

  - name: explain_query
    description: Get query execution plan
    parameters:
      - name: query
        type: string
        required: true
    script:
      shell: |
        psql "$DATABASE_URL" -c "EXPLAIN ANALYZE {{query}}"
```

```bash
export DATABASE_URL="postgresql://user:pass@localhost/mydb"
gantz run --auth
```

## Step 2: The data analyst agent

```python
import anthropic
import json

MCP_URL = "https://data-analyst.gantz.run/sse"
MCP_TOKEN = "gtz_abc123"

client = anthropic.Anthropic()

DATA_ANALYST_PROMPT = """You are a data analyst assistant.

Your job is to help users explore and understand their data using SQL queries.

Guidelines:
1. **Understand the schema first**: Always check table structures before writing queries
2. **Write efficient SQL**: Use appropriate JOINs, indexes, and LIMIT clauses
3. **Explain your results**: Don't just return data, interpret it
4. **Be conservative**: When unsure, ask for clarification
5. **Handle errors gracefully**: If a query fails, explain why and try again

Query best practices:
- Always include a LIMIT for exploratory queries (default 100)
- Use appropriate date/time functions for temporal queries
- Consider NULL values in calculations
- Use table aliases for readability
- Format large numbers for readability

When presenting results:
- Summarize key findings
- Point out interesting patterns
- Suggest follow-up questions
- Warn about data quality issues if any"""

def ask_analyst(question: str, context: str = "") -> str:
    """Ask the data analyst a question in natural language."""

    messages = [{
        "role": "user",
        "content": f"""Question: {question}

{f'Additional context: {context}' if context else ''}

Steps:
1. Use get_schema to understand the database structure
2. If needed, use sample_data to see example values
3. Write and execute the appropriate SQL query
4. Analyze and explain the results
5. Suggest related questions the user might want to explore"""
    }]

    response = client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=4096,
        system=DATA_ANALYST_PROMPT,
        messages=messages,
        tools=[{"type": "mcp", "server_url": MCP_URL, "token": MCP_TOKEN}]
    )

    # Extract the response
    result = ""
    for content in response.content:
        if hasattr(content, 'text'):
            result += content.text

    return result

def explore_table(table_name: str) -> str:
    """Get a comprehensive overview of a table."""

    response = client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=2048,
        system=DATA_ANALYST_PROMPT,
        messages=[{
            "role": "user",
            "content": f"""Give me a complete overview of the {table_name} table:

1. Use get_table_info to see structure and row count
2. Use sample_data to see example records
3. Use get_relationships to see how it connects to other tables
4. Summarize:
   - What this table represents
   - Key columns and their meaning
   - Data quality observations
   - Common query patterns for this table"""
        }],
        tools=[{"type": "mcp", "server_url": MCP_URL, "token": MCP_TOKEN}]
    )

    for content in response.content:
        if hasattr(content, 'text'):
            return content.text

    return ""
```

## Step 3: Common analysis patterns

```python
def revenue_analysis(time_period: str = "last 30 days") -> str:
    """Analyze revenue metrics."""

    return ask_analyst(f"""
    Analyze revenue for {time_period}:
    - Total revenue
    - Revenue by product/category
    - Top customers by revenue
    - Revenue trend over time
    - Compare to previous period
    """)

def user_engagement(metric: str = "activity") -> str:
    """Analyze user engagement."""

    return ask_analyst(f"""
    Analyze user {metric}:
    - Daily/weekly/monthly active users
    - User retention rates
    - Most active user segments
    - Activity trends
    - Churn indicators
    """)

def cohort_analysis(cohort_type: str = "signup month") -> str:
    """Perform cohort analysis."""

    return ask_analyst(f"""
    Perform cohort analysis by {cohort_type}:
    - Define cohorts by {cohort_type}
    - Track retention over time
    - Compare behavior across cohorts
    - Identify best/worst performing cohorts
    - Explain methodology
    """)

def funnel_analysis(funnel_stages: list) -> str:
    """Analyze conversion funnel."""

    stages = " -> ".join(funnel_stages)
    return ask_analyst(f"""
    Analyze the conversion funnel: {stages}
    - Conversion rate at each stage
    - Drop-off points
    - Time between stages
    - Segment analysis (by user type, source, etc.)
    """)
```

## Step 4: Safe query execution

Add guardrails for safety:

```python
import re

DANGEROUS_PATTERNS = [
    r'\b(DROP|DELETE|TRUNCATE|UPDATE|INSERT|ALTER|CREATE)\b',
    r';\s*(DROP|DELETE)',
    r'--',  # SQL comments
    r'/\*',  # Block comments
]

READ_ONLY_WRAPPER = """
BEGIN READ ONLY;
{query}
COMMIT;
"""

def validate_query(query: str) -> tuple[bool, str]:
    """Validate that a query is safe to execute."""

    query_upper = query.upper()

    # Check for dangerous patterns
    for pattern in DANGEROUS_PATTERNS:
        if re.search(pattern, query_upper, re.IGNORECASE):
            return False, f"Query contains forbidden pattern: {pattern}"

    # Must start with SELECT, WITH, or EXPLAIN
    if not re.match(r'^\s*(SELECT|WITH|EXPLAIN)\b', query_upper):
        return False, "Query must start with SELECT, WITH, or EXPLAIN"

    # Check for multiple statements
    if query.count(';') > 1:
        return False, "Multiple statements not allowed"

    return True, "Query is valid"

def safe_query(query: str) -> str:
    """Execute a query with safety checks."""

    is_valid, message = validate_query(query)

    if not is_valid:
        return f"Error: {message}"

    # Use the agent to run the query
    return ask_analyst(f"Run this exact query and show me the results: {query}")
```

## Step 5: Result visualization

```python
def generate_chart(data_query: str, chart_type: str = "bar") -> str:
    """Generate a chart description from query results."""

    response = client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=2048,
        system="""You generate chart specifications from data.

        Output a JSON specification for the chart with:
        - type: bar, line, pie, scatter
        - data: array of data points
        - labels: axis labels
        - title: chart title

        Also provide the raw data in a table format.""",
        messages=[{
            "role": "user",
            "content": f"""
            Run this query: {data_query}

            Then generate a {chart_type} chart specification for the results.

            Output:
            1. Raw data table
            2. Chart JSON specification
            3. Insights from the visualization
            """
        }],
        tools=[{"type": "mcp", "server_url": MCP_URL, "token": MCP_TOKEN}]
    )

    for content in response.content:
        if hasattr(content, 'text'):
            return content.text

    return ""

def export_report(questions: list, format: str = "markdown") -> str:
    """Generate a report answering multiple questions."""

    questions_text = "\n".join(f"- {q}" for q in questions)

    response = client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=8192,
        system=f"""You are generating a data report in {format} format.

        Structure:
        1. Executive Summary
        2. Key Metrics
        3. Detailed Findings (one section per question)
        4. Recommendations
        5. Methodology

        Include data tables where relevant.
        Be concise but thorough.""",
        messages=[{
            "role": "user",
            "content": f"""Generate a report answering these questions:

{questions_text}

For each question:
1. Run the necessary queries
2. Analyze the results
3. Include key data points
4. Provide insights"""
        }],
        tools=[{"type": "mcp", "server_url": MCP_URL, "token": MCP_TOKEN}]
    )

    for content in response.content:
        if hasattr(content, 'text'):
            return content.text

    return ""
```

## Step 6: Interactive chat interface

```python
#!/usr/bin/env python3
"""Interactive Data Analyst Chat."""

import readline  # For better input handling

def chat():
    """Interactive chat with the data analyst."""

    print("📊 Data Analyst Ready")
    print("Ask questions in plain English. Type 'quit' to exit.")
    print("Commands: /schema, /tables, /explore <table>, /report")
    print()

    # First, get schema overview
    print("Loading database schema...")
    schema_response = ask_analyst("Give me a brief overview of the database schema - what tables exist and what they're for")
    print(schema_response)
    print()

    while True:
        try:
            user_input = input("You: ").strip()
        except EOFError:
            break

        if not user_input:
            continue

        if user_input.lower() in ['quit', 'exit', 'q']:
            print("Goodbye!")
            break

        # Handle commands
        if user_input.startswith('/'):
            handle_command(user_input)
            continue

        # Regular question
        print("\nAnalyzing...\n")
        response = ask_analyst(user_input)
        print(f"Analyst: {response}\n")

def handle_command(command: str):
    """Handle special commands."""

    parts = command.split(maxsplit=1)
    cmd = parts[0].lower()
    args = parts[1] if len(parts) > 1 else ""

    if cmd == '/schema':
        response = ask_analyst("Show me the complete database schema")
        print(response)

    elif cmd == '/tables':
        response = ask_analyst("List all tables with their row counts")
        print(response)

    elif cmd == '/explore':
        if args:
            response = explore_table(args)
            print(response)
        else:
            print("Usage: /explore <table_name>")

    elif cmd == '/report':
        questions = [
            "What are the key metrics for today?",
            "How does this compare to last week?",
            "What trends should we be aware of?"
        ]
        response = export_report(questions)
        print(response)

    elif cmd == '/help':
        print("""
Commands:
  /schema     - Show database schema
  /tables     - List all tables
  /explore    - Deep dive into a table
  /report     - Generate quick report
  /help       - Show this help
  quit        - Exit
        """)

    else:
        print(f"Unknown command: {cmd}")

if __name__ == "__main__":
    chat()
```

## Step 7: Slack/Web integration

Make it accessible to everyone:

```python
from flask import Flask, request, jsonify

app = Flask(__name__)

@app.route("/analyze", methods=["POST"])
def analyze():
    """API endpoint for data analysis."""

    data = request.json
    question = data.get("question", "")

    if not question:
        return jsonify({"error": "No question provided"}), 400

    try:
        response = ask_analyst(question)
        return jsonify({
            "question": question,
            "answer": response
        })
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route("/webhook/slack", methods=["POST"])
def slack_webhook():
    """Handle Slack messages."""

    data = request.json

    # Handle URL verification
    if data.get("type") == "url_verification":
        return jsonify({"challenge": data["challenge"]})

    # Handle message
    event = data.get("event", {})
    if event.get("type") == "app_mention":
        text = event.get("text", "")
        channel = event.get("channel")

        # Remove bot mention
        question = re.sub(r'<@\w+>', '', text).strip()

        # Analyze
        response = ask_analyst(question)

        # Send response to Slack
        send_slack_message(channel, response)

    return jsonify({"status": "ok"})

def send_slack_message(channel: str, message: str):
    """Send a message to Slack."""
    import requests
    import os

    requests.post(
        "https://slack.com/api/chat.postMessage",
        headers={"Authorization": f"Bearer {os.environ['SLACK_TOKEN']}"},
        json={
            "channel": channel,
            "text": message,
            "mrkdwn": True
        }
    )

if __name__ == "__main__":
    app.run(port=5000)
```

## Example interactions

### Simple question
```
You: How many users do we have?

Analyst: Let me check that for you.

I ran: SELECT COUNT(*) as total_users FROM users

Result: 45,238 total users

Breaking it down:
- Active users (logged in last 30 days): 12,456
- New users this month: 1,234
- Users with at least one order: 8,901
```

### Complex analysis
```
You: Compare user signups this month vs last month by source

Analyst: I'll analyze signup trends by acquisition source.

Query executed:
SELECT
  source,
  COUNT(CASE WHEN created_at >= DATE_TRUNC('month', NOW()) THEN 1 END) as this_month,
  COUNT(CASE WHEN created_at >= DATE_TRUNC('month', NOW()) - INTERVAL '1 month'
              AND created_at < DATE_TRUNC('month', NOW()) THEN 1 END) as last_month
FROM users
GROUP BY source
ORDER BY this_month DESC

Results:
| Source    | This Month | Last Month | Change |
|-----------|------------|------------|--------|
| Organic   | 523        | 412        | +27%   |
| Google    | 345        | 298        | +16%   |
| Referral  | 201        | 156        | +29%   |
| Social    | 165        | 189        | -13%   |

Key insights:
- Overall signups up 18% month-over-month
- Referral program showing strong growth
- Social acquisition declining - may need investigation
- Organic is your strongest channel

Want me to dig deeper into any of these sources?
```

## Summary

Building an AI data analyst:

1. **Create database tools** with MCP for schema and queries
2. **Implement safety guardrails** - read-only, query validation
3. **Design good prompts** that understand data context
4. **Add visualization** for charts and reports
5. **Build accessible interfaces** - chat, Slack, API

Create tools with [Gantz](https://gantz.run), let anyone query your data.

SQL is for engineers. Plain English is for everyone.

## Related reading

- [Build a Customer Support Bot](/post/support-bot-mcp/) - Chat interfaces
- [PDF to Structured Data](/post/document-processing/) - Data extraction
- [Smart Notifications](/post/smart-notifications/) - Alert systems

---

*How do you democratize data access? Share your approach.*
