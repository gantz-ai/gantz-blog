+++
title = "Building an AI Lead Scoring Agent with MCP: Automated Sales Qualification"
image = "images/lead-scoring-agent.webp"
date = 2025-06-18
description = "Build intelligent lead scoring agents with MCP and Gantz. Learn automated qualification, predictive scoring, and AI-driven sales prioritization."
summary = "Build an AI lead scoring agent that enriches lead data from external sources, scores prospects based on demographic fit, behavioral engagement, company fit, and intent signals, predicts conversion probability and deal size, and recommends optimal next actions. Includes handlers for batch scoring, buying signal analysis, and pipeline prioritization workflows."
draft = false
tags = ['lead-scoring', 'agent', 'ai', 'mcp', 'sales', 'gantz']
voice = false

[howto]
name = "How To Build an AI Lead Scoring Agent with MCP"
totalTime = 35
[[howto.steps]]
name = "Design agent architecture"
text = "Plan lead scoring agent capabilities"
[[howto.steps]]
name = "Integrate CRM data"
text = "Connect to CRM and marketing data"
[[howto.steps]]
name = "Build scoring models"
text = "Create predictive scoring functions"
[[howto.steps]]
name = "Add enrichment logic"
text = "Implement data enrichment and signals"
[[howto.steps]]
name = "Deploy with Gantz"
text = "Deploy your lead scoring agent using Gantz CLI"
+++

An AI lead scoring agent automates lead qualification, predictive scoring, and sales prioritization, helping sales teams focus on the highest-value prospects.

## Why Build a Lead Scoring Agent?

AI-powered lead scoring enables:

- **Predictive scoring**: ML-based conversion prediction
- **Real-time updates**: Dynamic score adjustments
- **Behavioral analysis**: Activity-based signals
- **Enrichment**: Automated data augmentation
- **Prioritization**: Focus on high-value leads

## Lead Scoring Agent Architecture

```yaml
# gantz.yaml
name: lead-scoring-agent
version: 1.0.0

tools:
  score_lead:
    description: "Score individual lead"
    parameters:
      lead_id:
        type: string
        required: true
    handler: scoring.score_lead

  batch_score:
    description: "Batch score multiple leads"
    parameters:
      segment:
        type: string
    handler: scoring.batch_score

  enrich_lead:
    description: "Enrich lead data"
    parameters:
      lead_id:
        type: string
        required: true
    handler: scoring.enrich_lead

  analyze_signals:
    description: "Analyze buying signals"
    parameters:
      lead_id:
        type: string
        required: true
    handler: scoring.analyze_signals

  predict_conversion:
    description: "Predict lead conversion"
    parameters:
      lead_id:
        type: string
        required: true
    handler: scoring.predict_conversion

  recommend_action:
    description: "Recommend next action"
    parameters:
      lead_id:
        type: string
        required: true
    handler: scoring.recommend_action
```

## Handler Implementation

```python
# handlers/scoring.py
import os
from datetime import datetime, timedelta

CRM_API = os.environ.get('CRM_API_URL')
ENRICHMENT_API = os.environ.get('ENRICHMENT_API_KEY')


async def score_lead(lead_id: str) -> dict:
    """Score individual lead."""
    from gantz import MCPClient
    mcp = MCPClient()

    # Get lead data
    lead = await fetch_lead(lead_id)
    activities = await fetch_lead_activities(lead_id)
    company = await fetch_company_info(lead.get('company'))

    # AI scoring
    result = mcp.execute_tool('ai_analyze', {
        'type': 'lead_scoring',
        'lead': lead,
        'activities': activities,
        'company': company,
        'score_factors': [
            'demographic_fit',
            'behavioral_engagement',
            'company_fit',
            'intent_signals',
            'timing'
        ]
    })

    score_data = {
        'lead_id': lead_id,
        'score': result.get('score'),
        'grade': result.get('grade'),
        'factors': result.get('factor_breakdown', {}),
        'scored_at': datetime.now().isoformat()
    }

    # Update CRM
    await update_lead_score(lead_id, score_data)

    return {
        'lead_id': lead_id,
        'score': result.get('score'),
        'grade': result.get('grade'),
        'factor_breakdown': result.get('factor_breakdown', {}),
        'strengths': result.get('strengths', []),
        'weaknesses': result.get('weaknesses', []),
        'qualification_status': determine_qualification(result.get('score'))
    }


async def batch_score(segment: str = None) -> dict:
    """Batch score multiple leads."""
    from gantz import MCPClient
    mcp = MCPClient()

    # Get leads to score
    if segment:
        leads = await fetch_leads_by_segment(segment)
    else:
        leads = await fetch_unscored_leads()

    scored = []
    for lead in leads[:100]:  # Limit batch size
        result = await score_lead(lead['id'])
        scored.append(result)

    # AI batch analysis
    analysis = mcp.execute_tool('ai_analyze', {
        'type': 'batch_score_analysis',
        'scores': scored,
        'analyze': ['distribution', 'trends', 'anomalies']
    })

    return {
        'segment': segment,
        'leads_scored': len(scored),
        'score_distribution': analysis.get('distribution'),
        'hot_leads': [s for s in scored if s.get('grade') == 'A'],
        'warm_leads': [s for s in scored if s.get('grade') == 'B'],
        'cold_leads': [s for s in scored if s.get('grade') in ['C', 'D']],
        'insights': analysis.get('insights', [])
    }


async def enrich_lead(lead_id: str) -> dict:
    """Enrich lead data."""
    from gantz import MCPClient
    mcp = MCPClient()

    lead = await fetch_lead(lead_id)

    # Fetch enrichment data
    enrichment = await fetch_enrichment_data(lead.get('email'))

    # AI data merging
    result = mcp.execute_tool('ai_process', {
        'type': 'data_enrichment',
        'original': lead,
        'enrichment': enrichment,
        'merge_fields': [
            'company_size',
            'industry',
            'revenue',
            'technologies',
            'social_profiles',
            'decision_maker'
        ]
    })

    # Update lead
    await update_lead_data(lead_id, result.get('merged_data'))

    return {
        'lead_id': lead_id,
        'enriched': True,
        'fields_added': result.get('fields_added', []),
        'confidence_scores': result.get('confidence', {}),
        'new_insights': result.get('insights', [])
    }


async def analyze_signals(lead_id: str) -> dict:
    """Analyze buying signals."""
    from gantz import MCPClient
    mcp = MCPClient()

    # Get all lead activities
    activities = await fetch_lead_activities(lead_id)
    emails = await fetch_email_interactions(lead_id)
    website_visits = await fetch_website_activity(lead_id)
    content_engagement = await fetch_content_engagement(lead_id)

    # AI signal analysis
    result = mcp.execute_tool('ai_analyze', {
        'type': 'buying_signals',
        'activities': activities,
        'emails': emails,
        'website': website_visits,
        'content': content_engagement,
        'detect': [
            'purchase_intent',
            'urgency',
            'budget_signals',
            'decision_timeline',
            'competitor_research'
        ]
    })

    return {
        'lead_id': lead_id,
        'intent_score': result.get('intent_score'),
        'urgency': result.get('urgency'),
        'signals_detected': result.get('signals', []),
        'buying_stage': result.get('buying_stage'),
        'timeline_estimate': result.get('timeline'),
        'key_interests': result.get('interests', []),
        'engagement_trend': result.get('trend')
    }


async def predict_conversion(lead_id: str) -> dict:
    """Predict lead conversion."""
    from gantz import MCPClient
    mcp = MCPClient()

    lead = await fetch_lead(lead_id)
    score = await fetch_lead_score(lead_id)
    signals = await analyze_signals(lead_id)

    # AI prediction
    result = mcp.execute_tool('ai_predict', {
        'type': 'conversion_prediction',
        'lead': lead,
        'score': score,
        'signals': signals,
        'predict': ['probability', 'timeline', 'deal_size', 'risk_factors']
    })

    return {
        'lead_id': lead_id,
        'conversion_probability': result.get('probability'),
        'confidence': result.get('confidence'),
        'predicted_close_date': result.get('timeline'),
        'predicted_deal_size': result.get('deal_size'),
        'risk_factors': result.get('risks', []),
        'success_factors': result.get('success_factors', [])
    }


async def recommend_action(lead_id: str) -> dict:
    """Recommend next action for lead."""
    from gantz import MCPClient
    mcp = MCPClient()

    lead = await fetch_lead(lead_id)
    score = await fetch_lead_score(lead_id)
    signals = await analyze_signals(lead_id)
    history = await fetch_interaction_history(lead_id)

    # AI recommendation
    result = mcp.execute_tool('ai_generate', {
        'type': 'next_action',
        'lead': lead,
        'score': score,
        'signals': signals,
        'history': history,
        'recommend': ['action', 'channel', 'timing', 'message']
    })

    return {
        'lead_id': lead_id,
        'recommended_action': result.get('action'),
        'channel': result.get('channel'),
        'timing': result.get('timing'),
        'talking_points': result.get('talking_points', []),
        'message_template': result.get('message'),
        'expected_outcome': result.get('outcome')
    }


def determine_qualification(score: int) -> str:
    """Determine qualification status from score."""
    if score >= 80:
        return 'sales_qualified'
    elif score >= 60:
        return 'marketing_qualified'
    elif score >= 40:
        return 'nurture'
    return 'unqualified'
```

## Lead Scoring Orchestration

```python
# scoring_agent.py
from gantz import MCPClient

mcp = MCPClient(config_path='gantz.yaml')


async def process_new_leads() -> dict:
    """Process and score new leads."""
    # Get new leads from last 24 hours
    new_leads = await fetch_new_leads(hours=24)

    processed = []
    for lead in new_leads:
        # Enrich lead data
        enriched = mcp.execute_tool('enrich_lead', {'lead_id': lead['id']})

        # Score lead
        scored = mcp.execute_tool('score_lead', {'lead_id': lead['id']})

        # Recommend action
        action = mcp.execute_tool('recommend_action', {'lead_id': lead['id']})

        processed.append({
            'lead_id': lead['id'],
            'score': scored.get('score'),
            'grade': scored.get('grade'),
            'recommended_action': action.get('recommended_action')
        })

    # Route hot leads to sales
    hot_leads = [p for p in processed if p.get('grade') == 'A']
    await route_to_sales(hot_leads)

    return {
        'processed': len(processed),
        'hot_leads': len(hot_leads),
        'leads': processed
    }


async def daily_score_review() -> dict:
    """Daily review and re-score of active leads."""
    # Get active leads with recent activity
    active_leads = await fetch_active_leads()

    updated_scores = []
    score_changes = []

    for lead in active_leads:
        old_score = await fetch_lead_score(lead['id'])
        new_score = mcp.execute_tool('score_lead', {'lead_id': lead['id']})

        if old_score and abs(new_score.get('score', 0) - old_score.get('score', 0)) > 10:
            score_changes.append({
                'lead_id': lead['id'],
                'old_score': old_score.get('score'),
                'new_score': new_score.get('score'),
                'change': new_score.get('score', 0) - old_score.get('score', 0)
            })

        updated_scores.append(new_score)

    # AI summary
    result = mcp.execute_tool('ai_generate', {
        'type': 'daily_scoring_summary',
        'scores': updated_scores,
        'changes': score_changes,
        'generate': ['summary', 'notable_changes', 'recommendations']
    })

    return {
        'date': datetime.now().isoformat(),
        'leads_reviewed': len(active_leads),
        'significant_changes': len(score_changes),
        'summary': result.get('summary'),
        'notable_changes': result.get('notable', []),
        'recommendations': result.get('recommendations', [])
    }


async def prioritize_pipeline() -> dict:
    """Prioritize sales pipeline by score and signals."""
    # Score all pipeline leads
    pipeline = await fetch_pipeline_leads()

    prioritized = []
    for lead in pipeline:
        score = await fetch_lead_score(lead['id'])
        prediction = mcp.execute_tool('predict_conversion', {'lead_id': lead['id']})

        prioritized.append({
            'lead_id': lead['id'],
            'name': lead.get('name'),
            'score': score.get('score'),
            'conversion_probability': prediction.get('conversion_probability'),
            'predicted_value': prediction.get('predicted_deal_size')
        })

    # Sort by expected value
    prioritized.sort(
        key=lambda x: (x.get('conversion_probability', 0) * x.get('predicted_value', 0)),
        reverse=True
    )

    return {
        'pipeline_count': len(prioritized),
        'prioritized_leads': prioritized[:20],
        'total_predicted_value': sum(p.get('predicted_value', 0) for p in prioritized)
    }
```

## Deploy with Gantz CLI

```bash
# Install Gantz
npm install -g gantz

# Initialize lead scoring agent
gantz init --template lead-scoring-agent

# Set API keys
export CRM_API_URL=your-crm-url
export ENRICHMENT_API_KEY=your-key

# Deploy
gantz deploy --platform railway

# Score individual lead
gantz run score_lead --lead-id lead123

# Process new leads
gantz run process_new_leads

# Daily review
gantz run daily_score_review

# Prioritize pipeline
gantz run prioritize_pipeline
```

Build intelligent lead scoring at [gantz.run](https://gantz.run).

## Related Reading

- [Churn Prevention Agent](/post/churn-prevention-agent/) - Retention scoring
- [Salesforce MCP Integration](/post/salesforce-mcp-integration/) - CRM integration
- [HubSpot MCP Integration](/post/hubspot-mcp-integration/) - Marketing automation

## Conclusion

An AI lead scoring agent transforms sales prioritization from gut feeling to data-driven decisions. With predictive scoring, buying signals, and intelligent recommendations, sales teams can focus on high-value opportunities.

Start building your lead scoring agent with Gantz today.
