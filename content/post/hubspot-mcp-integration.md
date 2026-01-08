+++
title = "HubSpot MCP Integration: AI-Powered Marketing and Sales Automation"
image = "images/hubspot-mcp-integration.webp"
date = 2025-06-01
description = "Build intelligent marketing agents with HubSpot and MCP. Learn contact management, campaign automation, and AI-driven engagement with Gantz."
summary = "Connect AI agents to HubSpot for inbound marketing automation. Auto-segment audiences using ML, generate personalized email content, run automated A/B tests, trigger intelligent workflow based on lead behavior, and predict engagement rates. Includes handlers for contacts, deals, campaigns, and analytics."
draft = false
tags = ['hubspot', 'marketing', 'crm', 'mcp', 'automation', 'gantz']
voice = false

[howto]
name = "How To Build AI Marketing with HubSpot and MCP"
totalTime = 30
[[howto.steps]]
name = "Set up HubSpot API"
text = "Configure HubSpot API key and scopes"
[[howto.steps]]
name = "Define MCP tools"
text = "Create tool definitions for marketing operations"
[[howto.steps]]
name = "Implement handlers"
text = "Build handlers for contacts, deals, and campaigns"
[[howto.steps]]
name = "Add AI capabilities"
text = "Integrate AI-powered marketing automation"
[[howto.steps]]
name = "Deploy with Gantz"
text = "Deploy your marketing automation using Gantz CLI"
+++

HubSpot is the leading inbound marketing platform, and with MCP integration, you can build AI agents that automate marketing workflows, personalize engagement, and optimize campaign performance.

## Why HubSpot MCP Integration?

AI-powered marketing enables:

- **Smart segmentation**: ML-based audience targeting
- **Content personalization**: AI-driven messaging
- **Campaign optimization**: Automated A/B testing
- **Lead nurturing**: Intelligent workflow triggers
- **Predictive analytics**: Engagement forecasting

## HubSpot MCP Tool Definition

Configure HubSpot tools in Gantz:

```yaml
# gantz.yaml
name: hubspot-mcp-tools
version: 1.0.0

tools:
  get_contact:
    description: "Get contact by ID"
    parameters:
      contact_id:
        type: string
        required: true
    handler: hubspot.get_contact

  create_contact:
    description: "Create new contact"
    parameters:
      properties:
        type: object
        required: true
    handler: hubspot.create_contact

  update_contact:
    description: "Update contact properties"
    parameters:
      contact_id:
        type: string
        required: true
      properties:
        type: object
        required: true
    handler: hubspot.update_contact

  search_contacts:
    description: "Search contacts"
    parameters:
      query:
        type: string
      filters:
        type: array
    handler: hubspot.search_contacts

  get_deal:
    description: "Get deal by ID"
    parameters:
      deal_id:
        type: string
        required: true
    handler: hubspot.get_deal

  create_deal:
    description: "Create new deal"
    parameters:
      properties:
        type: object
        required: true
    handler: hubspot.create_deal

  get_campaigns:
    description: "Get marketing campaigns"
    handler: hubspot.get_campaigns

  personalize_content:
    description: "AI personalize content"
    parameters:
      contact_id:
        type: string
        required: true
      content_type:
        type: string
        required: true
    handler: hubspot.personalize_content
```

## Handler Implementation

Build HubSpot operation handlers:

```python
# handlers/hubspot.py
import httpx
import os

HUBSPOT_API = "https://api.hubapi.com"
ACCESS_TOKEN = os.environ['HUBSPOT_ACCESS_TOKEN']


def get_headers():
    """Get authorization headers."""
    return {
        "Authorization": f"Bearer {ACCESS_TOKEN}",
        "Content-Type": "application/json"
    }


async def api_request(method: str, path: str,
                      data: dict = None, params: dict = None) -> dict:
    """Make HubSpot API request."""
    async with httpx.AsyncClient() as client:
        response = await client.request(
            method,
            f"{HUBSPOT_API}{path}",
            json=data,
            params=params,
            headers=get_headers(),
            timeout=30.0
        )

        if response.status_code >= 400:
            return {'error': response.text}

        return response.json() if response.text else {'success': True}


async def get_contact(contact_id: str) -> dict:
    """Get contact by ID."""
    try:
        result = await api_request(
            "GET",
            f"/crm/v3/objects/contacts/{contact_id}",
            params={'properties': 'firstname,lastname,email,company,lifecyclestage,hs_lead_status'}
        )

        if 'error' in result:
            return result

        return {
            'id': result.get('id'),
            'properties': result.get('properties', {}),
            'created_at': result.get('createdAt'),
            'updated_at': result.get('updatedAt')
        }

    except Exception as e:
        return {'error': f'Failed to get contact: {str(e)}'}


async def create_contact(properties: dict) -> dict:
    """Create new contact."""
    try:
        result = await api_request(
            "POST",
            "/crm/v3/objects/contacts",
            {'properties': properties}
        )

        if 'error' in result:
            return result

        return {
            'id': result.get('id'),
            'created': True,
            'properties': result.get('properties', {})
        }

    except Exception as e:
        return {'error': f'Failed to create contact: {str(e)}'}


async def update_contact(contact_id: str, properties: dict) -> dict:
    """Update contact properties."""
    try:
        result = await api_request(
            "PATCH",
            f"/crm/v3/objects/contacts/{contact_id}",
            {'properties': properties}
        )

        if 'error' in result:
            return result

        return {
            'id': contact_id,
            'updated': True,
            'properties': result.get('properties', {})
        }

    except Exception as e:
        return {'error': f'Failed to update contact: {str(e)}'}


async def search_contacts(query: str = None, filters: list = None) -> dict:
    """Search contacts."""
    try:
        search_body = {
            'limit': 100
        }

        if query:
            search_body['query'] = query

        if filters:
            search_body['filterGroups'] = [{'filters': filters}]

        result = await api_request(
            "POST",
            "/crm/v3/objects/contacts/search",
            search_body
        )

        if 'error' in result:
            return result

        return {
            'total': result.get('total', 0),
            'contacts': [{
                'id': c.get('id'),
                'properties': c.get('properties', {})
            } for c in result.get('results', [])]
        }

    except Exception as e:
        return {'error': f'Search failed: {str(e)}'}


async def get_deal(deal_id: str) -> dict:
    """Get deal by ID."""
    try:
        result = await api_request(
            "GET",
            f"/crm/v3/objects/deals/{deal_id}",
            params={'properties': 'dealname,amount,dealstage,closedate,pipeline'}
        )

        if 'error' in result:
            return result

        return {
            'id': result.get('id'),
            'properties': result.get('properties', {})
        }

    except Exception as e:
        return {'error': f'Failed to get deal: {str(e)}'}


async def create_deal(properties: dict) -> dict:
    """Create new deal."""
    try:
        result = await api_request(
            "POST",
            "/crm/v3/objects/deals",
            {'properties': properties}
        )

        if 'error' in result:
            return result

        return {
            'id': result.get('id'),
            'created': True,
            'properties': result.get('properties', {})
        }

    except Exception as e:
        return {'error': f'Failed to create deal: {str(e)}'}


async def get_campaigns() -> dict:
    """Get marketing campaigns."""
    try:
        result = await api_request(
            "GET",
            "/marketing/v3/campaigns"
        )

        if 'error' in result:
            return result

        return {
            'count': len(result.get('results', [])),
            'campaigns': [{
                'id': c.get('id'),
                'name': c.get('name'),
                'status': c.get('status')
            } for c in result.get('results', [])]
        }

    except Exception as e:
        return {'error': f'Failed to get campaigns: {str(e)}'}


async def get_engagement_history(contact_id: str) -> dict:
    """Get contact engagement history."""
    try:
        # Get associated engagements
        result = await api_request(
            "GET",
            f"/crm/v3/objects/contacts/{contact_id}/associations/engagements"
        )

        if 'error' in result:
            return result

        engagements = []
        for assoc in result.get('results', [])[:20]:
            eng = await api_request(
                "GET",
                f"/crm/v3/objects/engagements/{assoc.get('id')}"
            )
            if 'error' not in eng:
                engagements.append(eng)

        return {
            'contact_id': contact_id,
            'engagements': engagements
        }

    except Exception as e:
        return {'error': f'Failed to get engagements: {str(e)}'}
```

## AI-Powered Marketing

Build intelligent marketing automation:

```python
# hubspot_ai.py
from gantz import MCPClient

mcp = MCPClient(config_path='gantz.yaml')


async def personalize_content(contact_id: str, content_type: str) -> dict:
    """AI personalize content for contact."""
    # Get contact data
    contact = mcp.execute_tool('get_contact', {'contact_id': contact_id})

    if 'error' in contact:
        return contact

    # Get engagement history
    history = await get_engagement_history(contact_id)

    # AI personalization
    result = mcp.execute_tool('ai_generate', {
        'type': 'personalized_content',
        'content_type': content_type,
        'contact': contact.get('properties'),
        'engagement_history': history.get('engagements', []),
        'personalize': ['subject', 'body', 'cta', 'tone']
    })

    return {
        'contact_id': contact_id,
        'content_type': content_type,
        'personalized_content': result.get('content'),
        'personalization_factors': result.get('factors', [])
    }


async def segment_audience(criteria: dict) -> dict:
    """AI-powered audience segmentation."""
    # Get all contacts matching base criteria
    contacts = mcp.execute_tool('search_contacts', {
        'filters': criteria.get('base_filters', [])
    })

    # AI segmentation
    result = mcp.execute_tool('ai_analyze', {
        'type': 'audience_segmentation',
        'contacts': contacts.get('contacts', []),
        'segment_by': criteria.get('segment_by', ['behavior', 'demographics', 'engagement'])
    })

    return {
        'total_contacts': len(contacts.get('contacts', [])),
        'segments': result.get('segments', []),
        'segment_profiles': result.get('profiles', {}),
        'targeting_recommendations': result.get('recommendations', [])
    }


async def optimize_campaign(campaign_id: str) -> dict:
    """AI campaign optimization."""
    # Get campaign data
    campaign_data = await get_campaign_analytics(campaign_id)

    # AI optimization
    result = mcp.execute_tool('ai_analyze', {
        'type': 'campaign_optimization',
        'campaign': campaign_data,
        'optimize': ['subject_lines', 'send_time', 'content', 'segments']
    })

    return {
        'campaign_id': campaign_id,
        'current_performance': campaign_data.get('metrics'),
        'optimizations': result.get('optimizations', []),
        'expected_improvement': result.get('expected_lift'),
        'a_b_test_suggestions': result.get('ab_tests', [])
    }


async def score_contact(contact_id: str) -> dict:
    """AI contact scoring."""
    contact = mcp.execute_tool('get_contact', {'contact_id': contact_id})
    history = await get_engagement_history(contact_id)

    # AI scoring
    result = mcp.execute_tool('ai_analyze', {
        'type': 'contact_scoring',
        'contact': contact.get('properties'),
        'engagement': history.get('engagements', []),
        'factors': ['fit', 'engagement', 'intent', 'recency']
    })

    # Update contact score
    mcp.execute_tool('update_contact', {
        'contact_id': contact_id,
        'properties': {
            'hs_lead_status': result.get('recommended_status'),
            'hubspot_score': result.get('score')
        }
    })

    return {
        'contact_id': contact_id,
        'score': result.get('score'),
        'grade': result.get('grade'),
        'factor_breakdown': result.get('factors', {}),
        'next_best_action': result.get('action')
    }


async def generate_nurture_sequence(segment: str) -> dict:
    """Generate AI nurture sequence."""
    # Get segment contacts
    contacts = mcp.execute_tool('search_contacts', {
        'filters': [{'propertyName': 'lifecyclestage', 'operator': 'EQ', 'value': segment}]
    })

    # AI sequence generation
    result = mcp.execute_tool('ai_generate', {
        'type': 'nurture_sequence',
        'segment': segment,
        'sample_contacts': contacts.get('contacts', [])[:10],
        'sequence_length': 5,
        'include': ['emails', 'delays', 'conditions', 'goals']
    })

    return {
        'segment': segment,
        'sequence': result.get('sequence'),
        'emails': result.get('emails', []),
        'expected_conversion': result.get('conversion_rate'),
        'workflow_config': result.get('workflow')
    }
```

## Email Intelligence

Smart email automation:

```python
# email_ai.py
from gantz import MCPClient

mcp = MCPClient()


async def generate_email(contact_id: str, purpose: str) -> dict:
    """Generate personalized email."""
    contact = mcp.execute_tool('get_contact', {'contact_id': contact_id})

    result = mcp.execute_tool('ai_generate', {
        'type': 'marketing_email',
        'contact': contact.get('properties'),
        'purpose': purpose,
        'variations': 3
    })

    return {
        'contact_id': contact_id,
        'variations': result.get('variations', []),
        'recommended': result.get('recommended'),
        'subject_lines': result.get('subjects', [])
    }


async def predict_best_send_time(contact_id: str) -> dict:
    """Predict optimal email send time."""
    history = await get_engagement_history(contact_id)

    result = mcp.execute_tool('ai_predict', {
        'type': 'send_time',
        'engagement_history': history.get('engagements', []),
        'timezone': 'UTC'
    })

    return {
        'contact_id': contact_id,
        'best_day': result.get('day'),
        'best_time': result.get('time'),
        'confidence': result.get('confidence'),
        'alternative_times': result.get('alternatives', [])
    }


async def analyze_email_performance(email_id: str) -> dict:
    """AI analysis of email performance."""
    # Get email metrics
    metrics = await get_email_metrics(email_id)

    result = mcp.execute_tool('ai_analyze', {
        'type': 'email_performance',
        'metrics': metrics,
        'analyze': ['subject', 'content', 'cta', 'timing']
    })

    return {
        'email_id': email_id,
        'performance_summary': result.get('summary'),
        'strengths': result.get('strengths', []),
        'improvements': result.get('improvements', []),
        'benchmarks': result.get('benchmarks')
    }
```

## Deploy with Gantz CLI

Deploy your marketing automation:

```bash
# Install Gantz
npm install -g gantz

# Initialize HubSpot project
gantz init --template hubspot-marketing

# Set environment variables
export HUBSPOT_ACCESS_TOKEN=your-access-token

# Deploy
gantz deploy --platform vercel

# Score contact
gantz run score_contact --contact-id 12345

# Personalize content
gantz run personalize_content \
  --contact-id 12345 \
  --content-type email

# Generate nurture sequence
gantz run generate_nurture_sequence --segment lead
```

Build intelligent marketing at [gantz.run](https://gantz.run).

## Related Reading

- [Salesforce MCP Integration](/post/salesforce-mcp-integration/) - CRM automation
- [Mailchimp MCP Integration](/post/mailchimp-mcp-integration/) - Email marketing
- [Intercom MCP Integration](/post/intercom-mcp-integration/) - Customer messaging

## Conclusion

HubSpot and MCP create powerful AI-driven marketing systems. With intelligent personalization, automated segmentation, and campaign optimization, you can transform marketing operations and drive engagement.

Start building HubSpot AI agents with Gantz today.
