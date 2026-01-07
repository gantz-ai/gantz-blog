+++
title = "Notion MCP Integration: AI-Powered Workspace Automation"
image = "/images/notion-mcp-integration.png"
date = 2025-06-03
description = "Build intelligent workspace agents with Notion and MCP. Learn database automation, content generation, and AI-driven knowledge management with Gantz."
draft = false
tags = ['notion', 'productivity', 'workspace', 'mcp', 'automation', 'gantz']
voice = false

[howto]
name = "How To Build AI Workspace with Notion and MCP"
totalTime = 30
[[howto.steps]]
name = "Set up Notion API"
text = "Configure Notion integration and API key"
[[howto.steps]]
name = "Define MCP tools"
text = "Create tool definitions for workspace operations"
[[howto.steps]]
name = "Implement handlers"
text = "Build handlers for pages, databases, and blocks"
[[howto.steps]]
name = "Add AI capabilities"
text = "Integrate AI-powered content and organization"
[[howto.steps]]
name = "Deploy with Gantz"
text = "Deploy your workspace automation using Gantz CLI"
+++

Notion is the all-in-one workspace for notes, docs, and databases. With MCP integration, you can build AI agents that automate content creation, organize knowledge, and manage complex workflows.

## Why Notion MCP Integration?

AI-powered workspace enables:

- **Content generation**: AI-written documents and summaries
- **Smart organization**: Automated page structuring
- **Database automation**: Intelligent data management
- **Knowledge synthesis**: AI-driven insights extraction
- **Workflow triggers**: Automated task management

## Notion MCP Tool Definition

Configure Notion tools in Gantz:

```yaml
# gantz.yaml
name: notion-mcp-tools
version: 1.0.0

tools:
  get_page:
    description: "Get page by ID"
    parameters:
      page_id:
        type: string
        required: true
    handler: notion.get_page

  create_page:
    description: "Create new page"
    parameters:
      parent_id:
        type: string
        required: true
      title:
        type: string
        required: true
      content:
        type: array
      properties:
        type: object
    handler: notion.create_page

  update_page:
    description: "Update page properties"
    parameters:
      page_id:
        type: string
        required: true
      properties:
        type: object
        required: true
    handler: notion.update_page

  query_database:
    description: "Query database"
    parameters:
      database_id:
        type: string
        required: true
      filter:
        type: object
      sorts:
        type: array
    handler: notion.query_database

  create_database_item:
    description: "Create database item"
    parameters:
      database_id:
        type: string
        required: true
      properties:
        type: object
        required: true
    handler: notion.create_database_item

  search:
    description: "Search workspace"
    parameters:
      query:
        type: string
        required: true
    handler: notion.search

  generate_content:
    description: "AI generate content"
    parameters:
      topic:
        type: string
        required: true
      type:
        type: string
        default: "document"
    handler: notion.generate_content
```

## Handler Implementation

Build Notion operation handlers:

```python
# handlers/notion.py
import httpx
import os

NOTION_API = "https://api.notion.com/v1"
NOTION_TOKEN = os.environ['NOTION_API_KEY']
NOTION_VERSION = "2022-06-28"


def get_headers():
    """Get authorization headers."""
    return {
        "Authorization": f"Bearer {NOTION_TOKEN}",
        "Content-Type": "application/json",
        "Notion-Version": NOTION_VERSION
    }


async def api_request(method: str, path: str,
                      data: dict = None, params: dict = None) -> dict:
    """Make Notion API request."""
    async with httpx.AsyncClient() as client:
        response = await client.request(
            method,
            f"{NOTION_API}{path}",
            json=data,
            params=params,
            headers=get_headers(),
            timeout=30.0
        )

        if response.status_code >= 400:
            return {'error': response.text}

        return response.json()


async def get_page(page_id: str) -> dict:
    """Get page by ID."""
    try:
        result = await api_request("GET", f"/pages/{page_id}")

        if 'error' in result:
            return result

        # Get page content
        blocks = await api_request("GET", f"/blocks/{page_id}/children")

        return {
            'id': result.get('id'),
            'title': extract_title(result),
            'properties': result.get('properties', {}),
            'created_time': result.get('created_time'),
            'last_edited_time': result.get('last_edited_time'),
            'content': blocks.get('results', [])
        }

    except Exception as e:
        return {'error': f'Failed to get page: {str(e)}'}


async def create_page(parent_id: str, title: str,
                     content: list = None, properties: dict = None) -> dict:
    """Create new page."""
    try:
        # Determine if parent is database or page
        parent_type = 'database_id' if '-' not in parent_id[:8] else 'page_id'

        page_data = {
            'parent': {parent_type: parent_id}
        }

        # Set title based on parent type
        if parent_type == 'database_id':
            page_data['properties'] = properties or {'title': {'title': [{'text': {'content': title}}]}}
        else:
            page_data['properties'] = {'title': {'title': [{'text': {'content': title}}]}}

        # Add content blocks
        if content:
            page_data['children'] = content

        result = await api_request("POST", "/pages", page_data)

        if 'error' in result:
            return result

        return {
            'id': result.get('id'),
            'created': True,
            'title': title,
            'url': result.get('url')
        }

    except Exception as e:
        return {'error': f'Failed to create page: {str(e)}'}


async def update_page(page_id: str, properties: dict) -> dict:
    """Update page properties."""
    try:
        result = await api_request(
            "PATCH",
            f"/pages/{page_id}",
            {'properties': properties}
        )

        if 'error' in result:
            return result

        return {
            'id': page_id,
            'updated': True
        }

    except Exception as e:
        return {'error': f'Failed to update page: {str(e)}'}


async def query_database(database_id: str, filter: dict = None,
                        sorts: list = None) -> dict:
    """Query database."""
    try:
        query_data = {}
        if filter:
            query_data['filter'] = filter
        if sorts:
            query_data['sorts'] = sorts

        result = await api_request(
            "POST",
            f"/databases/{database_id}/query",
            query_data
        )

        if 'error' in result:
            return result

        return {
            'database_id': database_id,
            'count': len(result.get('results', [])),
            'items': [{
                'id': item.get('id'),
                'properties': extract_properties(item.get('properties', {})),
                'created_time': item.get('created_time')
            } for item in result.get('results', [])]
        }

    except Exception as e:
        return {'error': f'Query failed: {str(e)}'}


async def create_database_item(database_id: str, properties: dict) -> dict:
    """Create database item."""
    try:
        result = await api_request(
            "POST",
            "/pages",
            {
                'parent': {'database_id': database_id},
                'properties': properties
            }
        )

        if 'error' in result:
            return result

        return {
            'id': result.get('id'),
            'created': True,
            'url': result.get('url')
        }

    except Exception as e:
        return {'error': f'Failed to create item: {str(e)}'}


async def search(query: str) -> dict:
    """Search workspace."""
    try:
        result = await api_request(
            "POST",
            "/search",
            {'query': query}
        )

        if 'error' in result:
            return result

        return {
            'query': query,
            'count': len(result.get('results', [])),
            'results': [{
                'id': r.get('id'),
                'type': r.get('object'),
                'title': extract_title(r),
                'url': r.get('url')
            } for r in result.get('results', [])]
        }

    except Exception as e:
        return {'error': f'Search failed: {str(e)}'}


async def append_blocks(page_id: str, blocks: list) -> dict:
    """Append blocks to page."""
    try:
        result = await api_request(
            "PATCH",
            f"/blocks/{page_id}/children",
            {'children': blocks}
        )

        if 'error' in result:
            return result

        return {
            'page_id': page_id,
            'blocks_added': len(blocks)
        }

    except Exception as e:
        return {'error': f'Failed to append blocks: {str(e)}'}


def extract_title(page: dict) -> str:
    """Extract title from page."""
    props = page.get('properties', {})
    title_prop = props.get('title') or props.get('Name') or {}

    if 'title' in title_prop:
        titles = title_prop.get('title', [])
        if titles:
            return titles[0].get('text', {}).get('content', '')

    return ''


def extract_properties(properties: dict) -> dict:
    """Extract property values."""
    extracted = {}
    for name, prop in properties.items():
        prop_type = prop.get('type')
        if prop_type == 'title':
            extracted[name] = ''.join(t.get('plain_text', '') for t in prop.get('title', []))
        elif prop_type == 'rich_text':
            extracted[name] = ''.join(t.get('plain_text', '') for t in prop.get('rich_text', []))
        elif prop_type == 'select':
            extracted[name] = prop.get('select', {}).get('name') if prop.get('select') else None
        elif prop_type == 'multi_select':
            extracted[name] = [s.get('name') for s in prop.get('multi_select', [])]
        elif prop_type == 'number':
            extracted[name] = prop.get('number')
        elif prop_type == 'checkbox':
            extracted[name] = prop.get('checkbox')
        elif prop_type == 'date':
            extracted[name] = prop.get('date', {}).get('start') if prop.get('date') else None
    return extracted
```

## AI-Powered Content Generation

Build intelligent workspace automation:

```python
# notion_ai.py
from gantz import MCPClient

mcp = MCPClient(config_path='gantz.yaml')


async def generate_content(topic: str, type: str = "document") -> dict:
    """AI generate content."""
    # AI content generation
    result = mcp.execute_tool('ai_generate', {
        'type': f'notion_{type}',
        'topic': topic,
        'format': 'notion_blocks',
        'include': ['headings', 'paragraphs', 'lists', 'callouts']
    })

    return {
        'topic': topic,
        'type': type,
        'blocks': result.get('blocks', []),
        'outline': result.get('outline', []),
        'word_count': result.get('word_count')
    }


async def create_document(topic: str, parent_id: str) -> dict:
    """Create AI-generated document."""
    # Generate content
    content = await generate_content(topic, 'document')

    # Create page with content
    page = mcp.execute_tool('create_page', {
        'parent_id': parent_id,
        'title': topic,
        'content': content.get('blocks', [])
    })

    return {
        'page_id': page.get('id'),
        'url': page.get('url'),
        'topic': topic,
        'sections': content.get('outline', [])
    }


async def summarize_page(page_id: str) -> dict:
    """AI summarize page content."""
    page = mcp.execute_tool('get_page', {'page_id': page_id})

    if 'error' in page:
        return page

    # AI summarization
    result = mcp.execute_tool('ai_analyze', {
        'type': 'summarize',
        'content': page.get('content', []),
        'generate': ['summary', 'key_points', 'action_items']
    })

    return {
        'page_id': page_id,
        'title': page.get('title'),
        'summary': result.get('summary'),
        'key_points': result.get('key_points', []),
        'action_items': result.get('action_items', [])
    }


async def organize_workspace(parent_id: str) -> dict:
    """AI-organize workspace structure."""
    # Get all pages under parent
    pages = await get_child_pages(parent_id)

    # AI organization
    result = mcp.execute_tool('ai_analyze', {
        'type': 'workspace_organization',
        'pages': pages,
        'suggest': ['categories', 'hierarchy', 'tags']
    })

    return {
        'parent_id': parent_id,
        'pages_analyzed': len(pages),
        'suggested_structure': result.get('structure'),
        'categories': result.get('categories', []),
        'recommendations': result.get('recommendations', [])
    }


async def auto_tag_database(database_id: str) -> dict:
    """Auto-tag database items."""
    items = mcp.execute_tool('query_database', {'database_id': database_id})

    tagged = []
    for item in items.get('items', []):
        # AI tagging
        result = mcp.execute_tool('ai_classify', {
            'type': 'content_tagging',
            'content': item.get('properties'),
            'tag_categories': ['topic', 'priority', 'status']
        })

        # Update item with tags
        if result.get('tags'):
            mcp.execute_tool('update_page', {
                'page_id': item.get('id'),
                'properties': result.get('property_updates', {})
            })

        tagged.append({
            'id': item.get('id'),
            'tags': result.get('tags', [])
        })

    return {
        'database_id': database_id,
        'items_tagged': len(tagged),
        'results': tagged
    }
```

## Knowledge Management

AI-powered knowledge base:

```python
# knowledge_ai.py
from gantz import MCPClient

mcp = MCPClient()


async def answer_from_workspace(question: str) -> dict:
    """Answer question from workspace knowledge."""
    # Search relevant pages
    search_results = mcp.execute_tool('search', {'query': question})

    # Get content from top results
    contexts = []
    for result in search_results.get('results', [])[:5]:
        if result.get('type') == 'page':
            page = mcp.execute_tool('get_page', {'page_id': result.get('id')})
            contexts.append({
                'title': page.get('title'),
                'content': page.get('content')
            })

    # AI answer
    result = mcp.execute_tool('ai_answer', {
        'question': question,
        'contexts': contexts,
        'cite_sources': True
    })

    return {
        'question': question,
        'answer': result.get('answer'),
        'sources': result.get('sources', []),
        'confidence': result.get('confidence')
    }


async def generate_meeting_notes(transcript: str, database_id: str) -> dict:
    """Generate meeting notes from transcript."""
    # AI extraction
    result = mcp.execute_tool('ai_extract', {
        'type': 'meeting_notes',
        'transcript': transcript,
        'extract': ['summary', 'decisions', 'action_items', 'attendees']
    })

    # Create meeting note page
    page = mcp.execute_tool('create_database_item', {
        'database_id': database_id,
        'properties': {
            'Name': {'title': [{'text': {'content': result.get('title', 'Meeting Notes')}}]},
            'Date': {'date': {'start': result.get('date')}},
            'Summary': {'rich_text': [{'text': {'content': result.get('summary', '')}}]}
        }
    })

    # Add content blocks
    await append_meeting_content(page.get('id'), result)

    return {
        'page_id': page.get('id'),
        'summary': result.get('summary'),
        'action_items': result.get('action_items', []),
        'decisions': result.get('decisions', [])
    }


async def create_weekly_report(database_id: str) -> dict:
    """Generate weekly report from database."""
    # Get items from past week
    items = mcp.execute_tool('query_database', {
        'database_id': database_id,
        'filter': {
            'property': 'Date',
            'date': {'past_week': {}}
        }
    })

    # AI report generation
    result = mcp.execute_tool('ai_generate', {
        'type': 'weekly_report',
        'items': items.get('items', []),
        'include': ['highlights', 'metrics', 'blockers', 'next_week']
    })

    return {
        'items_analyzed': len(items.get('items', [])),
        'report': result.get('report'),
        'highlights': result.get('highlights', []),
        'metrics': result.get('metrics', {})
    }
```

## Deploy with Gantz CLI

Deploy your workspace automation:

```bash
# Install Gantz
npm install -g gantz

# Initialize Notion project
gantz init --template notion-workspace

# Set environment variables
export NOTION_API_KEY=your-api-key

# Deploy
gantz deploy --platform vercel

# Generate document
gantz run create_document \
  --topic "Q4 Product Roadmap" \
  --parent-id abc123

# Summarize page
gantz run summarize_page --page-id xyz789

# Answer from workspace
gantz run answer_from_workspace \
  --question "What are our Q3 OKRs?"
```

Build intelligent workspaces at [gantz.run](https://gantz.run).

## Related Reading

- [Airtable MCP Integration](/post/airtable-mcp-integration/) - Database automation
- [Asana MCP Integration](/post/asana-mcp-integration/) - Project management
- [Linear MCP Integration](/post/linear-mcp-integration/) - Issue tracking

## Conclusion

Notion and MCP create powerful AI-driven workspace automation. With intelligent content generation, knowledge management, and automated organization, you can transform how teams create and collaborate.

Start building Notion AI agents with Gantz today.
