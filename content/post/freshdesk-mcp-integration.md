+++
title = "Freshdesk MCP Integration: AI-Powered Help Desk Automation"
image = "/images/freshdesk-mcp-integration.png"
date = 2025-05-20
description = "Build intelligent help desk agents with Freshdesk and MCP. Learn ticket automation, canned responses, and analytics integration with Gantz."
draft = false
tags = ['freshdesk', 'helpdesk', 'support', 'mcp', 'automation', 'gantz']
voice = false

[howto]
name = "How To Build AI Help Desk with Freshdesk and MCP"
totalTime = 30
[[howto.steps]]
name = "Set up Freshdesk API"
text = "Configure Freshdesk API key and domain"
[[howto.steps]]
name = "Define MCP tools"
text = "Create tool definitions for help desk operations"
[[howto.steps]]
name = "Implement handlers"
text = "Build handlers for tickets, contacts, and solutions"
[[howto.steps]]
name = "Add AI capabilities"
text = "Integrate AI-powered ticket handling and responses"
[[howto.steps]]
name = "Deploy with Gantz"
text = "Deploy your help desk automation using Gantz CLI"
+++

Freshdesk provides intuitive help desk software, and with MCP integration, you can build AI-powered support systems that automate ticket handling, provide instant solutions, and delight customers.

## Why Freshdesk MCP Integration?

AI-powered help desk automation enables:

- **Auto-categorization**: AI-driven ticket classification
- **Instant solutions**: Automated response suggestions
- **Smart assignment**: ML-based agent routing
- **Solution articles**: AI-enhanced knowledge base
- **SLA management**: Predictive breach prevention

## Freshdesk MCP Tool Definition

Configure Freshdesk tools in Gantz:

```yaml
# gantz.yaml
name: freshdesk-mcp-tools
version: 1.0.0

tools:
  create_ticket:
    description: "Create support ticket"
    parameters:
      subject:
        type: string
        required: true
      description:
        type: string
        required: true
      email:
        type: string
        required: true
      priority:
        type: integer
        default: 1
      status:
        type: integer
        default: 2
      type:
        type: string
    handler: freshdesk.create_ticket

  update_ticket:
    description: "Update ticket"
    parameters:
      ticket_id:
        type: integer
        required: true
      status:
        type: integer
      priority:
        type: integer
      responder_id:
        type: integer
      tags:
        type: array
    handler: freshdesk.update_ticket

  reply_ticket:
    description: "Reply to ticket"
    parameters:
      ticket_id:
        type: integer
        required: true
      body:
        type: string
        required: true
      private:
        type: boolean
        default: false
    handler: freshdesk.reply_ticket

  get_ticket:
    description: "Get ticket details"
    parameters:
      ticket_id:
        type: integer
        required: true
    handler: freshdesk.get_ticket

  search_tickets:
    description: "Search tickets"
    parameters:
      query:
        type: string
        required: true
    handler: freshdesk.search_tickets

  search_solutions:
    description: "Search solution articles"
    parameters:
      query:
        type: string
        required: true
    handler: freshdesk.search_solutions

  get_contact:
    description: "Get contact details"
    parameters:
      contact_id:
        type: integer
        required: true
    handler: freshdesk.get_contact

  list_canned_responses:
    description: "List canned responses"
    parameters:
      folder_id:
        type: integer
    handler: freshdesk.list_canned_responses
```

## Handler Implementation

Build Freshdesk operation handlers:

```python
# handlers/freshdesk.py
import httpx
import base64
import os

FRESHDESK_DOMAIN = os.environ['FRESHDESK_DOMAIN']
FRESHDESK_API = f"https://{FRESHDESK_DOMAIN}.freshdesk.com/api/v2"


def get_headers():
    """Get authorization headers."""
    api_key = os.environ['FRESHDESK_API_KEY']
    auth = base64.b64encode(f"{api_key}:X".encode()).decode()
    return {
        "Authorization": f"Basic {auth}",
        "Content-Type": "application/json"
    }


async def api_request(method: str, path: str,
                      data: dict = None, params: dict = None) -> dict:
    """Make Freshdesk API request."""
    async with httpx.AsyncClient() as client:
        response = await client.request(
            method,
            f"{FRESHDESK_API}{path}",
            json=data,
            params=params,
            headers=get_headers(),
            timeout=30.0
        )

        if response.status_code >= 400:
            return {'error': response.text}

        return response.json() if response.text else {'success': True}


async def create_ticket(subject: str, description: str, email: str,
                        priority: int = 1, status: int = 2,
                        ticket_type: str = None) -> dict:
    """Create support ticket."""
    try:
        data = {
            "subject": subject,
            "description": description,
            "email": email,
            "priority": priority,
            "status": status
        }

        if ticket_type:
            data["type"] = ticket_type

        result = await api_request("POST", "/tickets", data)

        if "error" in result:
            return result

        return {
            'ticket_id': result.get('id'),
            'subject': subject,
            'status': status,
            'priority': priority,
            'created': True
        }

    except Exception as e:
        return {'error': f'Failed to create ticket: {str(e)}'}


async def update_ticket(ticket_id: int, status: int = None,
                        priority: int = None, responder_id: int = None,
                        tags: list = None) -> dict:
    """Update ticket."""
    try:
        data = {}
        if status is not None:
            data['status'] = status
        if priority is not None:
            data['priority'] = priority
        if responder_id is not None:
            data['responder_id'] = responder_id
        if tags is not None:
            data['tags'] = tags

        result = await api_request("PUT", f"/tickets/{ticket_id}", data)

        if "error" in result:
            return result

        return {
            'ticket_id': ticket_id,
            'updated': True,
            'changes': data
        }

    except Exception as e:
        return {'error': f'Failed to update ticket: {str(e)}'}


async def reply_ticket(ticket_id: int, body: str,
                       private: bool = False) -> dict:
    """Reply to ticket."""
    try:
        data = {
            "body": body,
            "private": private
        }

        result = await api_request(
            "POST",
            f"/tickets/{ticket_id}/reply",
            data
        )

        if "error" in result:
            return result

        return {
            'ticket_id': ticket_id,
            'reply_id': result.get('id'),
            'private': private,
            'sent': True
        }

    except Exception as e:
        return {'error': f'Failed to reply: {str(e)}'}


async def get_ticket(ticket_id: int) -> dict:
    """Get ticket details."""
    try:
        result = await api_request("GET", f"/tickets/{ticket_id}")

        if "error" in result:
            return result

        # Get conversations
        conversations = await api_request(
            "GET",
            f"/tickets/{ticket_id}/conversations"
        )

        return {
            'id': result.get('id'),
            'subject': result.get('subject'),
            'description': result.get('description'),
            'status': result.get('status'),
            'priority': result.get('priority'),
            'type': result.get('type'),
            'requester_id': result.get('requester_id'),
            'responder_id': result.get('responder_id'),
            'tags': result.get('tags', []),
            'created_at': result.get('created_at'),
            'updated_at': result.get('updated_at'),
            'conversations': conversations if isinstance(conversations, list) else []
        }

    except Exception as e:
        return {'error': f'Failed to get ticket: {str(e)}'}


async def search_tickets(query: str) -> dict:
    """Search tickets."""
    try:
        result = await api_request(
            "GET",
            "/search/tickets",
            params={"query": f'"{query}"'}
        )

        if "error" in result:
            return result

        tickets = result.get('results', [])

        return {
            'query': query,
            'count': len(tickets),
            'tickets': [{
                'id': t.get('id'),
                'subject': t.get('subject'),
                'status': t.get('status'),
                'priority': t.get('priority'),
                'created_at': t.get('created_at')
            } for t in tickets[:25]]
        }

    except Exception as e:
        return {'error': f'Search failed: {str(e)}'}


async def search_solutions(query: str) -> dict:
    """Search solution articles."""
    try:
        result = await api_request(
            "GET",
            "/search/solutions",
            params={"term": query}
        )

        if "error" in result:
            return result

        articles = result if isinstance(result, list) else []

        return {
            'query': query,
            'count': len(articles),
            'articles': [{
                'id': a.get('id'),
                'title': a.get('title'),
                'description': a.get('description', '')[:200],
                'folder_id': a.get('folder_id'),
                'category_id': a.get('category_id')
            } for a in articles[:5]]
        }

    except Exception as e:
        return {'error': f'Solution search failed: {str(e)}'}


async def get_contact(contact_id: int) -> dict:
    """Get contact details."""
    try:
        result = await api_request("GET", f"/contacts/{contact_id}")

        if "error" in result:
            return result

        return {
            'id': result.get('id'),
            'name': result.get('name'),
            'email': result.get('email'),
            'phone': result.get('phone'),
            'company_id': result.get('company_id'),
            'created_at': result.get('created_at')
        }

    except Exception as e:
        return {'error': f'Failed to get contact: {str(e)}'}


async def list_canned_responses(folder_id: int = None) -> dict:
    """List canned responses."""
    try:
        path = "/canned_responses"
        if folder_id:
            path = f"/canned_response_folders/{folder_id}/responses"

        result = await api_request("GET", path)

        if "error" in result:
            return result

        responses = result if isinstance(result, list) else []

        return {
            'count': len(responses),
            'responses': [{
                'id': r.get('id'),
                'title': r.get('title'),
                'content': r.get('content', '')[:200]
            } for r in responses]
        }

    except Exception as e:
        return {'error': f'Failed to list responses: {str(e)}'}
```

## AI-Powered Ticket Automation

Build intelligent ticket handling:

```python
# ticket_automation.py
from gantz import MCPClient

mcp = MCPClient(config_path='gantz.yaml')


class FreshdeskAI:
    """AI-powered Freshdesk automation."""

    # Status mapping
    STATUS = {
        'open': 2,
        'pending': 3,
        'resolved': 4,
        'closed': 5
    }

    # Priority mapping
    PRIORITY = {
        'low': 1,
        'medium': 2,
        'high': 3,
        'urgent': 4
    }

    async def process_ticket(self, ticket_id: int) -> dict:
        """Process ticket with AI."""
        # Get ticket details
        ticket = mcp.execute_tool('get_ticket', {'ticket_id': ticket_id})

        if 'error' in ticket:
            return ticket

        # Classify ticket
        classification = await self.classify(ticket)

        # Search for solutions
        solutions = mcp.execute_tool('search_solutions', {
            'query': ticket['subject']
        })

        # Generate response
        response = await self.generate_response(
            ticket, classification, solutions
        )

        # Determine priority
        priority = await self.assess_priority(ticket, classification)

        # Find best agent
        agent = await self.route_ticket(classification)

        # Update ticket
        mcp.execute_tool('update_ticket', {
            'ticket_id': ticket_id,
            'priority': self.PRIORITY.get(priority, 2),
            'responder_id': agent.get('id'),
            'tags': [classification['category']]
        })

        # Add internal note
        mcp.execute_tool('reply_ticket', {
            'ticket_id': ticket_id,
            'body': f"AI Analysis:\n- Category: {classification['category']}\n- Priority: {priority}\n- Confidence: {classification['confidence']:.0%}",
            'private': True
        })

        return {
            'ticket_id': ticket_id,
            'classification': classification,
            'priority': priority,
            'agent': agent,
            'suggested_response': response,
            'solutions': solutions.get('articles', [])
        }

    async def classify(self, ticket: dict) -> dict:
        """Classify ticket using AI."""
        result = mcp.execute_tool('ai_classify', {
            'text': f"{ticket['subject']}\n\n{ticket['description']}",
            'categories': [
                'technical_issue', 'billing_inquiry', 'feature_request',
                'bug_report', 'account_problem', 'how_to_question',
                'complaint', 'praise', 'general'
            ]
        })

        return {
            'category': result.get('category'),
            'confidence': result.get('confidence'),
            'sentiment': result.get('sentiment'),
            'keywords': result.get('keywords', [])
        }

    async def generate_response(self, ticket: dict, classification: dict,
                               solutions: dict) -> dict:
        """Generate suggested response."""
        # Get canned responses for category
        canned = mcp.execute_tool('list_canned_responses', {})

        # Get contact history
        contact = mcp.execute_tool('get_contact', {
            'contact_id': ticket['requester_id']
        })

        result = mcp.execute_tool('ai_generate', {
            'type': 'support_response',
            'ticket': {
                'subject': ticket['subject'],
                'description': ticket['description'],
                'category': classification['category']
            },
            'customer': contact,
            'solutions': solutions.get('articles', []),
            'canned_responses': canned.get('responses', []),
            'tone': 'helpful_friendly'
        })

        return {
            'suggested_reply': result.get('response'),
            'confidence': result.get('confidence'),
            'based_on_canned': result.get('canned_response_id'),
            'relevant_solutions': result.get('solutions', [])
        }

    async def assess_priority(self, ticket: dict,
                             classification: dict) -> str:
        """Assess ticket priority."""
        # Urgent triggers
        urgent_keywords = ['down', 'critical', 'urgent', 'asap', 'emergency']
        subject_lower = ticket['subject'].lower()

        if any(kw in subject_lower for kw in urgent_keywords):
            return 'urgent'

        if classification.get('sentiment') == 'very_negative':
            return 'high'

        # AI assessment
        result = mcp.execute_tool('ai_evaluate', {
            'type': 'priority',
            'ticket': ticket,
            'classification': classification
        })

        return result.get('priority', 'medium')

    async def route_ticket(self, classification: dict) -> dict:
        """Route ticket to best agent."""
        category = classification['category']

        # Category to group mapping
        group_mapping = {
            'technical_issue': 'technical_support',
            'billing_inquiry': 'billing_team',
            'bug_report': 'engineering',
            'feature_request': 'product_team'
        }

        group = group_mapping.get(category, 'general_support')

        # Find available agent in group
        result = mcp.execute_tool('find_available_agent', {
            'group': group,
            'skill': classification.get('keywords', [])
        })

        return {
            'id': result.get('agent_id'),
            'name': result.get('agent_name'),
            'group': group
        }


# Initialize
freshdesk_ai = FreshdeskAI()
```

## Webhook Handler

Process Freshdesk webhooks:

```python
# webhooks.py
from fastapi import FastAPI, Request
from ticket_automation import freshdesk_ai

app = FastAPI()


@app.post("/freshdesk/webhook")
async def handle_webhook(request: Request):
    """Handle Freshdesk webhook events."""
    data = await request.json()

    # Get ticket ID from webhook payload
    ticket_data = data.get('freshdesk_webhook', {})
    ticket_id = ticket_data.get('ticket_id')

    if not ticket_id:
        return {"error": "No ticket_id in webhook"}

    # Check event type
    event = ticket_data.get('triggered_event')

    if event == 'ticket_created':
        result = await freshdesk_ai.process_ticket(int(ticket_id))
        return result

    elif event == 'ticket_updated':
        # Handle updates if needed
        pass

    return {"status": "ok"}


@app.post("/freshdesk/automation/new-ticket")
async def handle_automation_trigger(request: Request):
    """Handle automation rule trigger."""
    data = await request.json()
    ticket_id = data.get('ticket_id')

    if ticket_id:
        result = await freshdesk_ai.process_ticket(int(ticket_id))
        return result

    return {"error": "No ticket_id provided"}
```

## Auto-Reply with Freddy AI

Enhance Freshdesk's Freddy AI:

```python
# freddy_enhancement.py
from gantz import MCPClient

mcp = MCPClient()


async def enhance_freddy_response(query: str, context: dict) -> dict:
    """Enhance Freddy AI with custom logic."""
    # Search solutions
    solutions = mcp.execute_tool('search_solutions', {'query': query})

    # Generate enhanced response
    result = mcp.execute_tool('ai_generate', {
        'type': 'chatbot_response',
        'query': query,
        'solutions': solutions.get('articles', []),
        'context': context,
        'style': 'conversational'
    })

    return {
        'response': result.get('response'),
        'articles': solutions.get('articles', [])[:3],
        'confidence': result.get('confidence'),
        'should_handoff': result.get('confidence', 0) < 0.6
    }
```

## SLA Prediction

Predict and prevent SLA breaches:

```python
# sla_prediction.py
from gantz import MCPClient

mcp = MCPClient()


async def predict_sla_risk(ticket_id: int) -> dict:
    """Predict SLA breach risk."""
    ticket = mcp.execute_tool('get_ticket', {'ticket_id': ticket_id})

    result = mcp.execute_tool('ai_predict', {
        'type': 'sla_breach',
        'ticket': ticket,
        'factors': ['complexity', 'backlog', 'agent_workload']
    })

    if result.get('breach_probability', 0) > 0.7:
        # Escalate or reassign
        mcp.execute_tool('update_ticket', {
            'ticket_id': ticket_id,
            'priority': 4,  # Urgent
            'tags': ['sla_risk']
        })

    return {
        'ticket_id': ticket_id,
        'breach_probability': result.get('breach_probability'),
        'estimated_resolution': result.get('estimated_time'),
        'action_taken': 'escalated' if result.get('breach_probability', 0) > 0.7 else 'none'
    }
```

## Deploy with Gantz CLI

Deploy your help desk automation:

```bash
# Install Gantz
npm install -g gantz

# Initialize Freshdesk project
gantz init --template freshdesk-helpdesk

# Set environment variables
export FRESHDESK_DOMAIN=yourcompany
export FRESHDESK_API_KEY=your-api-key

# Deploy
gantz deploy --platform railway

# Test ticket creation
gantz run create_ticket \
  --subject "Test ticket" \
  --description "Testing AI automation" \
  --email test@example.com
```

Build intelligent help desk systems at [gantz.run](https://gantz.run).

## Related Reading

- [Zendesk MCP Integration](/post/zendesk-mcp-integration/) - Compare with Zendesk
- [Intercom MCP Integration](/post/intercom-mcp-integration/) - Customer messaging
- [MCP Circuit Breakers](/post/mcp-circuit-breakers/) - Handle API limits

## Conclusion

Freshdesk and MCP create powerful help desk automation. With AI-driven classification, smart routing, and automated responses, you can transform support operations and improve customer satisfaction.

Start building Freshdesk AI agents with Gantz today.
