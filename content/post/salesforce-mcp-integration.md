+++
title = "Salesforce MCP Integration: AI-Powered CRM Automation"
image = "/images/salesforce-mcp-integration.png"
date = 2025-05-31
description = "Build intelligent CRM agents with Salesforce and MCP. Learn lead management, opportunity tracking, and AI-driven sales automation with Gantz."
draft = false
tags = ['salesforce', 'crm', 'sales', 'mcp', 'automation', 'gantz']
voice = false

[howto]
name = "How To Build AI CRM with Salesforce and MCP"
totalTime = 35
[[howto.steps]]
name = "Set up Salesforce API"
text = "Configure Salesforce connected app and OAuth"
[[howto.steps]]
name = "Define MCP tools"
text = "Create tool definitions for CRM operations"
[[howto.steps]]
name = "Implement handlers"
text = "Build handlers for leads, opportunities, and accounts"
[[howto.steps]]
name = "Add AI capabilities"
text = "Integrate AI-powered sales insights and automation"
[[howto.steps]]
name = "Deploy with Gantz"
text = "Deploy your CRM automation using Gantz CLI"
+++

Salesforce is the world's leading CRM platform, and with MCP integration, you can build AI agents that automate lead management, optimize sales processes, and provide intelligent customer insights.

## Why Salesforce MCP Integration?

AI-powered CRM enables:

- **Lead scoring**: ML-based qualification
- **Opportunity insights**: AI-driven win predictions
- **Auto-enrichment**: Intelligent data completion
- **Sales coaching**: AI-generated recommendations
- **Pipeline forecasting**: Predictive analytics

## Salesforce MCP Tool Definition

Configure Salesforce tools in Gantz:

```yaml
# gantz.yaml
name: salesforce-mcp-tools
version: 1.0.0

tools:
  query:
    description: "Execute SOQL query"
    parameters:
      soql:
        type: string
        required: true
    handler: salesforce.query

  create_record:
    description: "Create Salesforce record"
    parameters:
      object_type:
        type: string
        required: true
      data:
        type: object
        required: true
    handler: salesforce.create_record

  update_record:
    description: "Update Salesforce record"
    parameters:
      object_type:
        type: string
        required: true
      record_id:
        type: string
        required: true
      data:
        type: object
        required: true
    handler: salesforce.update_record

  get_record:
    description: "Get record by ID"
    parameters:
      object_type:
        type: string
        required: true
      record_id:
        type: string
        required: true
    handler: salesforce.get_record

  search:
    description: "Search across objects"
    parameters:
      query:
        type: string
        required: true
    handler: salesforce.search

  score_lead:
    description: "AI lead scoring"
    parameters:
      lead_id:
        type: string
        required: true
    handler: salesforce.score_lead

  predict_opportunity:
    description: "Predict opportunity outcome"
    parameters:
      opportunity_id:
        type: string
        required: true
    handler: salesforce.predict_opportunity
```

## Handler Implementation

Build Salesforce operation handlers:

```python
# handlers/salesforce.py
from simple_salesforce import Salesforce
import os

SF_USERNAME = os.environ['SALESFORCE_USERNAME']
SF_PASSWORD = os.environ['SALESFORCE_PASSWORD']
SF_TOKEN = os.environ['SALESFORCE_SECURITY_TOKEN']
SF_DOMAIN = os.environ.get('SALESFORCE_DOMAIN', 'login')


def get_sf_client():
    """Get Salesforce client."""
    return Salesforce(
        username=SF_USERNAME,
        password=SF_PASSWORD,
        security_token=SF_TOKEN,
        domain=SF_DOMAIN
    )


async def query(soql: str) -> dict:
    """Execute SOQL query."""
    try:
        sf = get_sf_client()
        result = sf.query_all(soql)

        return {
            'total_size': result.get('totalSize', 0),
            'records': result.get('records', []),
            'done': result.get('done', True)
        }

    except Exception as e:
        return {'error': f'Query failed: {str(e)}'}


async def create_record(object_type: str, data: dict) -> dict:
    """Create Salesforce record."""
    try:
        sf = get_sf_client()
        sf_object = getattr(sf, object_type)
        result = sf_object.create(data)

        return {
            'id': result.get('id'),
            'success': result.get('success'),
            'object_type': object_type
        }

    except Exception as e:
        return {'error': f'Create failed: {str(e)}'}


async def update_record(object_type: str, record_id: str, data: dict) -> dict:
    """Update Salesforce record."""
    try:
        sf = get_sf_client()
        sf_object = getattr(sf, object_type)
        sf_object.update(record_id, data)

        return {
            'id': record_id,
            'updated': True,
            'object_type': object_type
        }

    except Exception as e:
        return {'error': f'Update failed: {str(e)}'}


async def get_record(object_type: str, record_id: str) -> dict:
    """Get record by ID."""
    try:
        sf = get_sf_client()
        sf_object = getattr(sf, object_type)
        result = sf_object.get(record_id)

        return {
            'id': record_id,
            'object_type': object_type,
            'record': result
        }

    except Exception as e:
        return {'error': f'Get failed: {str(e)}'}


async def search(query: str) -> dict:
    """Search across objects."""
    try:
        sf = get_sf_client()
        result = sf.search(f"FIND {{{query}}} IN ALL FIELDS RETURNING Lead, Contact, Account, Opportunity")

        return {
            'query': query,
            'results': result.get('searchRecords', [])
        }

    except Exception as e:
        return {'error': f'Search failed: {str(e)}'}


async def get_lead(lead_id: str) -> dict:
    """Get lead with related data."""
    try:
        sf = get_sf_client()

        lead = sf.Lead.get(lead_id)

        # Get activities
        activities = sf.query(
            f"SELECT Id, Subject, Status, ActivityDate FROM Task WHERE WhoId = '{lead_id}' ORDER BY ActivityDate DESC LIMIT 10"
        )

        return {
            'id': lead_id,
            'lead': lead,
            'activities': activities.get('records', [])
        }

    except Exception as e:
        return {'error': f'Get lead failed: {str(e)}'}


async def get_opportunity(opportunity_id: str) -> dict:
    """Get opportunity with related data."""
    try:
        sf = get_sf_client()

        opp = sf.Opportunity.get(opportunity_id)

        # Get line items
        line_items = sf.query(
            f"SELECT Id, Name, Quantity, UnitPrice FROM OpportunityLineItem WHERE OpportunityId = '{opportunity_id}'"
        )

        # Get activities
        activities = sf.query(
            f"SELECT Id, Subject, Status FROM Task WHERE WhatId = '{opportunity_id}' ORDER BY ActivityDate DESC LIMIT 10"
        )

        return {
            'id': opportunity_id,
            'opportunity': opp,
            'line_items': line_items.get('records', []),
            'activities': activities.get('records', [])
        }

    except Exception as e:
        return {'error': f'Get opportunity failed: {str(e)}'}
```

## AI-Powered Sales Intelligence

Build intelligent CRM automation:

```python
# salesforce_ai.py
from gantz import MCPClient

mcp = MCPClient(config_path='gantz.yaml')


async def score_lead(lead_id: str) -> dict:
    """AI lead scoring."""
    # Get lead data
    lead = await get_lead(lead_id)

    if 'error' in lead:
        return lead

    # AI scoring
    result = mcp.execute_tool('ai_analyze', {
        'type': 'lead_scoring',
        'lead': lead.get('lead'),
        'activities': lead.get('activities'),
        'factors': ['engagement', 'fit', 'intent', 'timing']
    })

    # Update lead score
    mcp.execute_tool('update_record', {
        'object_type': 'Lead',
        'record_id': lead_id,
        'data': {
            'Lead_Score__c': result.get('score'),
            'Score_Reason__c': result.get('primary_reason')
        }
    })

    return {
        'lead_id': lead_id,
        'score': result.get('score'),
        'grade': result.get('grade'),
        'factors': result.get('factor_breakdown', {}),
        'recommendations': result.get('recommendations', [])
    }


async def predict_opportunity(opportunity_id: str) -> dict:
    """Predict opportunity outcome."""
    opp = await get_opportunity(opportunity_id)

    if 'error' in opp:
        return opp

    # AI prediction
    result = mcp.execute_tool('ai_predict', {
        'type': 'opportunity_outcome',
        'opportunity': opp.get('opportunity'),
        'activities': opp.get('activities'),
        'predict': ['win_probability', 'expected_close', 'risk_factors']
    })

    return {
        'opportunity_id': opportunity_id,
        'win_probability': result.get('probability'),
        'expected_close_date': result.get('close_date'),
        'confidence': result.get('confidence'),
        'risk_factors': result.get('risks', []),
        'recommended_actions': result.get('actions', [])
    }


async def enrich_lead(lead_id: str) -> dict:
    """AI-powered lead enrichment."""
    lead = mcp.execute_tool('get_record', {
        'object_type': 'Lead',
        'record_id': lead_id
    })

    # AI enrichment
    result = mcp.execute_tool('ai_enrich', {
        'type': 'lead',
        'data': lead.get('record'),
        'sources': ['company_data', 'social', 'news']
    })

    # Update lead with enriched data
    if result.get('enriched_fields'):
        mcp.execute_tool('update_record', {
            'object_type': 'Lead',
            'record_id': lead_id,
            'data': result.get('enriched_fields')
        })

    return {
        'lead_id': lead_id,
        'enriched': True,
        'fields_updated': list(result.get('enriched_fields', {}).keys()),
        'company_insights': result.get('company_insights'),
        'social_profiles': result.get('social', [])
    }


async def generate_sales_email(opportunity_id: str, context: str) -> dict:
    """Generate personalized sales email."""
    opp = await get_opportunity(opportunity_id)

    result = mcp.execute_tool('ai_generate', {
        'type': 'sales_email',
        'opportunity': opp.get('opportunity'),
        'context': context,
        'tone': 'professional',
        'include': ['value_props', 'next_steps', 'urgency']
    })

    return {
        'opportunity_id': opportunity_id,
        'subject': result.get('subject'),
        'body': result.get('body'),
        'follow_up_date': result.get('follow_up')
    }


async def analyze_pipeline(owner_id: str = None) -> dict:
    """AI pipeline analysis."""
    # Get opportunities
    soql = "SELECT Id, Name, Amount, StageName, CloseDate, Probability FROM Opportunity WHERE IsClosed = false"
    if owner_id:
        soql += f" AND OwnerId = '{owner_id}'"

    opps = mcp.execute_tool('query', {'soql': soql})

    # AI analysis
    result = mcp.execute_tool('ai_analyze', {
        'type': 'pipeline_analysis',
        'opportunities': opps.get('records', []),
        'analyze': ['health', 'risks', 'forecast', 'recommendations']
    })

    return {
        'total_pipeline': sum(o.get('Amount', 0) for o in opps.get('records', [])),
        'opportunity_count': len(opps.get('records', [])),
        'health_score': result.get('health_score'),
        'at_risk': result.get('at_risk_deals', []),
        'forecast': result.get('forecast'),
        'recommendations': result.get('recommendations', [])
    }
```

## Natural Language CRM

Query CRM with natural language:

```python
# natural_crm.py
from gantz import MCPClient

mcp = MCPClient()


async def natural_query(question: str) -> dict:
    """Query Salesforce with natural language."""
    # Parse to SOQL
    parsed = mcp.execute_tool('ai_parse', {
        'type': 'soql',
        'question': question,
        'objects': ['Lead', 'Contact', 'Account', 'Opportunity', 'Task']
    })

    soql = parsed.get('query')

    # Execute query
    result = mcp.execute_tool('query', {'soql': soql})

    # Generate response
    response = mcp.execute_tool('ai_generate', {
        'type': 'query_response',
        'question': question,
        'data': result.get('records', [])
    })

    return {
        'question': question,
        'soql': soql,
        'answer': response.get('answer'),
        'data': result.get('records', [])
    }


async def sales_assistant(question: str, context: dict = None) -> dict:
    """AI sales assistant."""
    result = mcp.execute_tool('ai_assistant', {
        'type': 'sales',
        'question': question,
        'context': context,
        'capabilities': ['query', 'create', 'update', 'analyze']
    })

    return {
        'question': question,
        'answer': result.get('answer'),
        'actions_taken': result.get('actions', []),
        'suggestions': result.get('suggestions', [])
    }
```

## Deploy with Gantz CLI

Deploy your CRM automation:

```bash
# Install Gantz
npm install -g gantz

# Initialize Salesforce project
gantz init --template salesforce-crm

# Set environment variables
export SALESFORCE_USERNAME=your-username
export SALESFORCE_PASSWORD=your-password
export SALESFORCE_SECURITY_TOKEN=your-token

# Deploy
gantz deploy --platform heroku

# Score leads
gantz run score_lead --lead-id 00Q000000000001

# Predict opportunity
gantz run predict_opportunity --opportunity-id 006000000000001

# Natural language query
gantz run natural_query \
  --question "Show me all opportunities closing this month over $50k"
```

Build intelligent CRM at [gantz.run](https://gantz.run).

## Related Reading

- [HubSpot MCP Integration](/post/hubspot-mcp-integration/) - Marketing automation
- [Pipedrive MCP Integration](/post/pipedrive-mcp-integration/) - Sales pipeline
- [Linear MCP Integration](/post/linear-mcp-integration/) - Issue tracking

## Conclusion

Salesforce and MCP create powerful AI-driven CRM systems. With intelligent lead scoring, opportunity prediction, and natural language queries, you can transform sales operations and close more deals.

Start building Salesforce AI agents with Gantz today.
