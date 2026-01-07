+++
title = "Mailchimp MCP Integration: AI-Powered Marketing Automation"
image = "images/mailchimp-mcp-integration.webp"
date = 2025-05-17
description = "Build intelligent marketing campaigns with Mailchimp and MCP. Learn audience management, campaign automation, and analytics with Gantz."
draft = false
tags = ['mailchimp', 'marketing', 'email', 'mcp', 'automation', 'gantz']
voice = false

[howto]
name = "How To Build Marketing Automation with Mailchimp and MCP"
totalTime = 30
[[howto.steps]]
name = "Set up Mailchimp account"
text = "Configure Mailchimp API keys and audience settings"
[[howto.steps]]
name = "Define MCP tools"
text = "Create tool definitions for marketing operations"
[[howto.steps]]
name = "Implement handlers"
text = "Build handlers for campaigns, audiences, and automation"
[[howto.steps]]
name = "Add AI capabilities"
text = "Integrate AI-powered content and audience segmentation"
[[howto.steps]]
name = "Deploy with Gantz"
text = "Deploy your marketing automation using Gantz CLI"
+++

Mailchimp is a leading marketing automation platform, and with MCP integration, you can build AI-powered marketing systems that create personalized campaigns, optimize audiences, and maximize engagement.

## Why Mailchimp MCP Integration?

AI-powered marketing automation enables:

- **Smart segmentation**: AI-driven audience targeting
- **Content optimization**: AI-generated copy and subject lines
- **Send time optimization**: ML-based delivery timing
- **Campaign analytics**: Intelligent performance insights
- **Automated journeys**: AI-orchestrated customer paths

## Mailchimp MCP Tool Definition

Configure Mailchimp tools in Gantz:

```yaml
# gantz.yaml
name: mailchimp-mcp-tools
version: 1.0.0

tools:
  create_campaign:
    description: "Create email campaign"
    parameters:
      list_id:
        type: string
        required: true
      subject:
        type: string
        required: true
      content:
        type: string
        required: true
      from_name:
        type: string
      segment_id:
        type: string
    handler: mailchimp.create_campaign

  send_campaign:
    description: "Send or schedule campaign"
    parameters:
      campaign_id:
        type: string
        required: true
      schedule_time:
        type: string
        description: "ISO datetime for scheduling"
    handler: mailchimp.send_campaign

  add_subscriber:
    description: "Add subscriber to audience"
    parameters:
      list_id:
        type: string
        required: true
      email:
        type: string
        required: true
      merge_fields:
        type: object
      tags:
        type: array
    handler: mailchimp.add_subscriber

  create_segment:
    description: "Create audience segment"
    parameters:
      list_id:
        type: string
        required: true
      name:
        type: string
        required: true
      conditions:
        type: array
        required: true
    handler: mailchimp.create_segment

  get_campaign_report:
    description: "Get campaign performance report"
    parameters:
      campaign_id:
        type: string
        required: true
    handler: mailchimp.get_campaign_report

  get_audience_stats:
    description: "Get audience statistics"
    parameters:
      list_id:
        type: string
        required: true
    handler: mailchimp.get_audience_stats

  create_automation:
    description: "Create marketing automation"
    parameters:
      list_id:
        type: string
        required: true
      trigger_type:
        type: string
        required: true
      emails:
        type: array
        required: true
    handler: mailchimp.create_automation
```

## Handler Implementation

Build Mailchimp operation handlers:

```python
# handlers/mailchimp.py
import mailchimp_marketing as MailchimpMarketing
from mailchimp_marketing.api_client import ApiClientError
import os
import hashlib

client = MailchimpMarketing.Client()
client.set_config({
    "api_key": os.environ['MAILCHIMP_API_KEY'],
    "server": os.environ['MAILCHIMP_SERVER_PREFIX']
})


def get_subscriber_hash(email: str) -> str:
    """Get MD5 hash of email for Mailchimp API."""
    return hashlib.md5(email.lower().encode()).hexdigest()


async def create_campaign(list_id: str, subject: str, content: str,
                          from_name: str = None, segment_id: str = None) -> dict:
    """Create email campaign."""
    try:
        # Create campaign
        campaign_data = {
            "type": "regular",
            "recipients": {
                "list_id": list_id
            },
            "settings": {
                "subject_line": subject,
                "from_name": from_name or "Your Company",
                "reply_to": os.environ.get('MAILCHIMP_REPLY_TO', 'reply@example.com')
            }
        }

        if segment_id:
            campaign_data["recipients"]["segment_opts"] = {
                "saved_segment_id": int(segment_id)
            }

        campaign = client.campaigns.create(campaign_data)

        # Set content
        client.campaigns.set_content(campaign['id'], {
            "html": content
        })

        return {
            'campaign_id': campaign['id'],
            'web_id': campaign['web_id'],
            'status': campaign['status'],
            'subject': subject,
            'created': True
        }

    except ApiClientError as e:
        return {'error': f'Failed to create campaign: {e.text}'}


async def send_campaign(campaign_id: str, schedule_time: str = None) -> dict:
    """Send or schedule campaign."""
    try:
        if schedule_time:
            # Schedule campaign
            client.campaigns.schedule(campaign_id, {
                "schedule_time": schedule_time
            })
            return {
                'campaign_id': campaign_id,
                'scheduled': True,
                'schedule_time': schedule_time
            }
        else:
            # Send immediately
            client.campaigns.send(campaign_id)
            return {
                'campaign_id': campaign_id,
                'sent': True
            }

    except ApiClientError as e:
        return {'error': f'Failed to send campaign: {e.text}'}


async def add_subscriber(list_id: str, email: str,
                        merge_fields: dict = None, tags: list = None) -> dict:
    """Add subscriber to audience."""
    try:
        member_data = {
            "email_address": email,
            "status": "subscribed"
        }

        if merge_fields:
            member_data["merge_fields"] = merge_fields

        if tags:
            member_data["tags"] = tags

        member = client.lists.add_list_member(list_id, member_data)

        return {
            'id': member['id'],
            'email': email,
            'status': member['status'],
            'subscribed': True
        }

    except ApiClientError as e:
        if 'Member Exists' in str(e.text):
            # Update existing member
            subscriber_hash = get_subscriber_hash(email)
            member = client.lists.update_list_member(
                list_id,
                subscriber_hash,
                member_data
            )
            return {
                'id': member['id'],
                'email': email,
                'status': 'updated'
            }
        return {'error': f'Failed to add subscriber: {e.text}'}


async def create_segment(list_id: str, name: str, conditions: list) -> dict:
    """Create audience segment."""
    try:
        segment = client.lists.create_segment(list_id, {
            "name": name,
            "options": {
                "match": "all",
                "conditions": conditions
            }
        })

        return {
            'segment_id': segment['id'],
            'name': segment['name'],
            'member_count': segment['member_count'],
            'created': True
        }

    except ApiClientError as e:
        return {'error': f'Failed to create segment: {e.text}'}


async def get_campaign_report(campaign_id: str) -> dict:
    """Get campaign performance report."""
    try:
        report = client.reports.get_campaign_report(campaign_id)

        return {
            'campaign_id': campaign_id,
            'subject': report['subject_line'],
            'emails_sent': report['emails_sent'],
            'opens': {
                'total': report['opens']['opens_total'],
                'unique': report['opens']['unique_opens'],
                'rate': report['opens']['open_rate']
            },
            'clicks': {
                'total': report['clicks']['clicks_total'],
                'unique': report['clicks']['unique_clicks'],
                'rate': report['clicks']['click_rate']
            },
            'bounces': {
                'hard': report['bounces']['hard_bounces'],
                'soft': report['bounces']['soft_bounces']
            },
            'unsubscribes': report['unsubscribed']
        }

    except ApiClientError as e:
        return {'error': f'Failed to get report: {e.text}'}


async def get_audience_stats(list_id: str) -> dict:
    """Get audience statistics."""
    try:
        audience = client.lists.get_list(list_id)
        stats = audience['stats']

        return {
            'list_id': list_id,
            'name': audience['name'],
            'member_count': stats['member_count'],
            'unsubscribe_count': stats['unsubscribe_count'],
            'open_rate': stats['open_rate'],
            'click_rate': stats['click_rate'],
            'avg_sub_rate': stats['avg_sub_rate'],
            'avg_unsub_rate': stats['avg_unsub_rate'],
            'last_sub_date': stats.get('last_sub_date')
        }

    except ApiClientError as e:
        return {'error': f'Failed to get stats: {e.text}'}


async def create_automation(list_id: str, trigger_type: str,
                           emails: list) -> dict:
    """Create marketing automation."""
    try:
        # Note: Mailchimp's automation API is limited
        # This creates a customer journey workflow
        automation = client.automations.create({
            "recipients": {
                "list_id": list_id
            },
            "trigger_settings": {
                "workflow_type": trigger_type
            },
            "settings": {
                "title": f"Automation - {trigger_type}",
                "from_name": "Your Company",
                "reply_to": os.environ.get('MAILCHIMP_REPLY_TO')
            }
        })

        return {
            'automation_id': automation['id'],
            'trigger_type': trigger_type,
            'status': automation['status'],
            'created': True
        }

    except ApiClientError as e:
        return {'error': f'Failed to create automation: {e.text}'}
```

## AI-Powered Campaign Creation

Generate intelligent campaigns:

```python
# campaign_ai.py
from gantz import MCPClient

mcp = MCPClient()


async def create_ai_campaign(audience_id: str, goal: str,
                            product_info: dict = None) -> dict:
    """Create AI-powered marketing campaign."""
    # Get audience insights
    audience_stats = mcp.execute_tool('get_audience_stats', {
        'list_id': audience_id
    })

    # Analyze audience for personalization
    analysis = mcp.execute_tool('analyze_audience', {
        'audience_id': audience_id,
        'metrics': ['engagement', 'demographics', 'behavior']
    })

    # Generate campaign content
    content_result = mcp.execute_tool('ai_generate', {
        'type': 'email_campaign',
        'goal': goal,
        'audience_insights': analysis,
        'product': product_info,
        'elements': ['subject_lines', 'preview_text', 'body', 'cta']
    })

    # Generate multiple subject line variations for A/B test
    subjects = mcp.execute_tool('ai_generate_variations', {
        'type': 'subject_line',
        'base': content_result.get('subject'),
        'count': 3,
        'optimize_for': 'open_rate'
    })

    # Create campaign with best content
    campaign = mcp.execute_tool('create_campaign', {
        'list_id': audience_id,
        'subject': subjects['variations'][0],
        'content': content_result.get('body'),
        'from_name': 'Your Company'
    })

    return {
        'campaign_id': campaign.get('campaign_id'),
        'subject_variations': subjects['variations'],
        'content_preview': content_result.get('body')[:200] + '...',
        'predicted_performance': content_result.get('predictions')
    }


async def optimize_send_time(list_id: str) -> dict:
    """Find optimal send time using AI."""
    # Get historical engagement data
    engagement_data = mcp.execute_tool('get_engagement_history', {
        'list_id': list_id,
        'days': 90
    })

    # Analyze with AI
    result = mcp.execute_tool('ai_analyze', {
        'type': 'send_time_optimization',
        'data': engagement_data,
        'consider': ['timezone_distribution', 'day_of_week', 'time_of_day']
    })

    return {
        'recommended_time': result.get('optimal_time'),
        'recommended_day': result.get('optimal_day'),
        'confidence': result.get('confidence'),
        'timezone_breakdown': result.get('by_timezone')
    }


async def create_smart_segment(list_id: str, description: str) -> dict:
    """Create segment from natural language description."""
    # Parse description with AI
    result = mcp.execute_tool('ai_parse', {
        'type': 'segment_conditions',
        'description': description,
        'available_fields': get_available_fields(list_id)
    })

    conditions = result.get('conditions', [])

    # Create segment
    segment = mcp.execute_tool('create_segment', {
        'list_id': list_id,
        'name': result.get('suggested_name', description[:50]),
        'conditions': conditions
    })

    return {
        'segment_id': segment.get('segment_id'),
        'name': segment.get('name'),
        'conditions_parsed': conditions,
        'estimated_size': segment.get('member_count')
    }


def get_available_fields(list_id: str) -> list:
    """Get available merge fields for segmentation."""
    return [
        'email', 'FNAME', 'LNAME', 'tags',
        'email_client', 'signup_source',
        'last_engagement', 'total_opens', 'total_clicks'
    ]
```

## Marketing Automation Workflows

Build AI-driven customer journeys:

```python
# automation.py
from gantz import MCPClient
from datetime import datetime, timedelta

mcp = MCPClient()


class MarketingJourney:
    """AI-powered marketing automation journey."""

    def __init__(self, name: str, list_id: str):
        self.name = name
        self.list_id = list_id
        self.steps = []

    def add_email(self, template: str, delay_days: int = 0,
                  conditions: dict = None):
        """Add email step to journey."""
        self.steps.append({
            'type': 'email',
            'template': template,
            'delay_days': delay_days,
            'conditions': conditions
        })
        return self

    def add_wait(self, days: int):
        """Add wait step."""
        self.steps.append({
            'type': 'wait',
            'days': days
        })
        return self

    def add_branch(self, condition: str, yes_path: list, no_path: list):
        """Add conditional branch."""
        self.steps.append({
            'type': 'branch',
            'condition': condition,
            'yes': yes_path,
            'no': no_path
        })
        return self

    async def execute_for_user(self, user: dict):
        """Execute journey for a user."""
        for step in self.steps:
            if step['type'] == 'email':
                await self.send_journey_email(user, step)

            elif step['type'] == 'wait':
                # In production, use job scheduler
                pass

            elif step['type'] == 'branch':
                if await self.evaluate_condition(user, step['condition']):
                    for s in step['yes']:
                        await self.execute_step(user, s)
                else:
                    for s in step['no']:
                        await self.execute_step(user, s)

    async def send_journey_email(self, user: dict, step: dict):
        """Send journey email with AI personalization."""
        # Check conditions
        if step.get('conditions'):
            if not await self.check_conditions(user, step['conditions']):
                return

        # Generate personalized content
        content = mcp.execute_tool('ai_generate', {
            'type': 'email',
            'template': step['template'],
            'user': user,
            'journey': self.name
        })

        # Send via Mailchimp
        mcp.execute_tool('send_transactional', {
            'to': user['email'],
            'subject': content['subject'],
            'content': content['body']
        })

    async def evaluate_condition(self, user: dict, condition: str) -> bool:
        """Evaluate branch condition with AI."""
        result = mcp.execute_tool('ai_evaluate', {
            'condition': condition,
            'user_data': user,
            'engagement_history': await self.get_user_engagement(user['email'])
        })
        return result.get('result', False)


# Pre-built journeys
def welcome_journey(list_id: str) -> MarketingJourney:
    """Create welcome email journey."""
    return (
        MarketingJourney('welcome', list_id)
        .add_email('welcome_email', delay_days=0)
        .add_wait(2)
        .add_email('getting_started', delay_days=0,
                   conditions={'opened_previous': True})
        .add_wait(3)
        .add_branch(
            'user.engagement_score > 0.5',
            yes_path=[{'type': 'email', 'template': 'power_user_tips'}],
            no_path=[{'type': 'email', 'template': 're_engagement'}]
        )
        .add_wait(7)
        .add_email('feedback_request')
    )


def abandoned_cart_journey(list_id: str) -> MarketingJourney:
    """Create abandoned cart recovery journey."""
    return (
        MarketingJourney('abandoned_cart', list_id)
        .add_email('cart_reminder_1', delay_days=0)
        .add_wait(1)
        .add_branch(
            'cart.completed == false',
            yes_path=[
                {'type': 'email', 'template': 'cart_reminder_2_discount'},
                {'type': 'wait', 'days': 2},
                {'type': 'email', 'template': 'cart_final_reminder'}
            ],
            no_path=[]
        )
    )
```

## Webhook Handler

Process Mailchimp webhooks:

```python
# webhooks.py
from fastapi import FastAPI, Request
from gantz import MCPClient

app = FastAPI()
mcp = MCPClient()


@app.post("/mailchimp/webhook")
async def handle_mailchimp_webhook(request: Request):
    """Handle Mailchimp webhook events."""
    data = await request.form()
    event_type = data.get('type')

    if event_type == 'subscribe':
        await handle_subscribe(data)
    elif event_type == 'unsubscribe':
        await handle_unsubscribe(data)
    elif event_type == 'campaign':
        await handle_campaign_event(data)

    return {"status": "ok"}


async def handle_subscribe(data: dict):
    """Handle new subscriber."""
    email = data.get('data[email]')

    # Start welcome journey
    mcp.execute_tool('start_journey', {
        'journey': 'welcome',
        'email': email
    })


async def handle_unsubscribe(data: dict):
    """Handle unsubscribe event."""
    email = data.get('data[email]')

    # Log for analysis
    mcp.execute_tool('log_unsubscribe', {
        'email': email,
        'reason': data.get('data[reason]'),
        'timestamp': datetime.now().isoformat()
    })
```

## Deploy with Gantz CLI

Deploy your marketing automation:

```bash
# Install Gantz
npm install -g gantz

# Initialize Mailchimp project
gantz init --template mailchimp-automation

# Set environment variables
export MAILCHIMP_API_KEY=your-api-key
export MAILCHIMP_SERVER_PREFIX=us1

# Deploy
gantz deploy --platform railway

# Test campaign creation
gantz run create_campaign \
  --list-id abc123 \
  --subject "Welcome!" \
  --content "<h1>Hello!</h1>"
```

Build intelligent marketing at [gantz.run](https://gantz.run).

## Related Reading

- [SendGrid MCP Integration](/post/sendgrid-mcp-integration/) - Transactional email
- [Intercom MCP Integration](/post/intercom-mcp-integration/) - Customer messaging
- [MCP Batching](/post/mcp-batching/) - Efficient bulk operations

## Conclusion

Mailchimp and MCP create powerful marketing automation systems. With AI-driven content generation, smart segmentation, and optimized delivery, you can build marketing campaigns that drive engagement and conversions.

Start building marketing AI agents with Gantz today.
