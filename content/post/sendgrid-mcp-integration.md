+++
title = "SendGrid MCP Integration: Build AI-Powered Email Automation"
image = "images/sendgrid-mcp-integration.webp"
date = 2025-05-16
description = "Create intelligent email agents with SendGrid and MCP. Learn email automation, dynamic templates, and analytics integration with Gantz."
draft = false
tags = ['sendgrid', 'email', 'automation', 'mcp', 'marketing', 'gantz']
voice = false

[howto]
name = "How To Build Email Automation with SendGrid and MCP"
totalTime = 30
[[howto.steps]]
name = "Set up SendGrid account"
text = "Configure SendGrid API keys and sender verification"
[[howto.steps]]
name = "Define MCP tools"
text = "Create tool definitions for email operations"
[[howto.steps]]
name = "Implement handlers"
text = "Build handlers for sending, templates, and analytics"
[[howto.steps]]
name = "Add AI capabilities"
text = "Integrate AI-powered content generation and personalization"
[[howto.steps]]
name = "Deploy with Gantz"
text = "Deploy your email agents using Gantz CLI"
+++

SendGrid powers email for businesses worldwide, and with MCP integration, you can build intelligent email systems that personalize content, optimize delivery, and respond to engagement signals automatically.

## Why SendGrid MCP Integration?

AI-powered email automation enables:

- **Smart personalization**: AI-generated content per recipient
- **Optimal timing**: Send when users engage most
- **A/B testing**: AI-driven subject line optimization
- **Analytics**: Engagement analysis and insights
- **Automation**: Triggered email workflows

## SendGrid MCP Tool Definition

Configure SendGrid tools in Gantz:

```yaml
# gantz.yaml
name: sendgrid-mcp-tools
version: 1.0.0

tools:
  send_email:
    description: "Send email via SendGrid"
    parameters:
      to:
        type: string
        required: true
      subject:
        type: string
        required: true
      content:
        type: string
        required: true
      from_email:
        type: string
      template_id:
        type: string
      dynamic_data:
        type: object
    handler: sendgrid.send_email

  send_template:
    description: "Send email using dynamic template"
    parameters:
      to:
        type: string
        required: true
      template_id:
        type: string
        required: true
      dynamic_data:
        type: object
        required: true
    handler: sendgrid.send_template

  create_contact:
    description: "Add contact to marketing list"
    parameters:
      email:
        type: string
        required: true
      first_name:
        type: string
      last_name:
        type: string
      custom_fields:
        type: object
      list_ids:
        type: array
    handler: sendgrid.create_contact

  get_stats:
    description: "Get email statistics"
    parameters:
      start_date:
        type: string
        required: true
      end_date:
        type: string
      aggregated_by:
        type: string
        default: "day"
    handler: sendgrid.get_stats

  validate_email:
    description: "Validate email address"
    parameters:
      email:
        type: string
        required: true
    handler: sendgrid.validate_email

  get_bounces:
    description: "Get bounced email addresses"
    parameters:
      start_time:
        type: integer
      end_time:
        type: integer
    handler: sendgrid.get_bounces
```

## Handler Implementation

Build SendGrid operation handlers:

```python
# handlers/sendgrid.py
import sendgrid
from sendgrid.helpers.mail import Mail, Email, To, Content, DynamicTemplateData
import os

sg = sendgrid.SendGridAPIClient(api_key=os.environ['SENDGRID_API_KEY'])
DEFAULT_FROM = os.environ.get('SENDGRID_FROM_EMAIL', 'noreply@example.com')


async def send_email(to: str, subject: str, content: str,
                     from_email: str = None, template_id: str = None,
                     dynamic_data: dict = None) -> dict:
    """Send email via SendGrid."""
    try:
        message = Mail(
            from_email=from_email or DEFAULT_FROM,
            to_emails=to,
            subject=subject
        )

        if template_id:
            message.template_id = template_id
            if dynamic_data:
                message.dynamic_template_data = dynamic_data
        else:
            message.add_content(Content("text/html", content))

        response = sg.send(message)

        return {
            'status_code': response.status_code,
            'to': to,
            'subject': subject,
            'sent': response.status_code == 202
        }

    except Exception as e:
        return {'error': f'Failed to send email: {str(e)}'}


async def send_template(to: str, template_id: str,
                        dynamic_data: dict) -> dict:
    """Send email using dynamic template."""
    try:
        message = Mail(
            from_email=DEFAULT_FROM,
            to_emails=to
        )
        message.template_id = template_id
        message.dynamic_template_data = dynamic_data

        response = sg.send(message)

        return {
            'status_code': response.status_code,
            'to': to,
            'template_id': template_id,
            'sent': response.status_code == 202
        }

    except Exception as e:
        return {'error': f'Failed to send template: {str(e)}'}


async def create_contact(email: str, first_name: str = None,
                        last_name: str = None, custom_fields: dict = None,
                        list_ids: list = None) -> dict:
    """Add contact to SendGrid."""
    try:
        data = {
            "contacts": [{
                "email": email,
                "first_name": first_name,
                "last_name": last_name,
                "custom_fields": custom_fields or {}
            }]
        }

        if list_ids:
            data["list_ids"] = list_ids

        response = sg.client.marketing.contacts.put(
            request_body=data
        )

        return {
            'email': email,
            'status_code': response.status_code,
            'created': response.status_code == 202
        }

    except Exception as e:
        return {'error': f'Failed to create contact: {str(e)}'}


async def get_stats(start_date: str, end_date: str = None,
                    aggregated_by: str = "day") -> dict:
    """Get email statistics."""
    try:
        params = {
            "start_date": start_date,
            "aggregated_by": aggregated_by
        }

        if end_date:
            params["end_date"] = end_date

        response = sg.client.stats.get(query_params=params)
        stats = response.to_dict

        return {
            'period': f"{start_date} to {end_date or 'now'}",
            'aggregated_by': aggregated_by,
            'stats': stats
        }

    except Exception as e:
        return {'error': f'Failed to get stats: {str(e)}'}


async def validate_email(email: str) -> dict:
    """Validate email address."""
    try:
        response = sg.client.validations.email.post(
            request_body={"email": email}
        )

        result = response.to_dict

        return {
            'email': email,
            'valid': result.get('result', {}).get('verdict') == 'Valid',
            'score': result.get('result', {}).get('score'),
            'checks': result.get('result', {}).get('checks', {})
        }

    except Exception as e:
        return {'error': f'Validation failed: {str(e)}'}


async def get_bounces(start_time: int = None, end_time: int = None) -> dict:
    """Get bounced email addresses."""
    try:
        params = {}
        if start_time:
            params["start_time"] = start_time
        if end_time:
            params["end_time"] = end_time

        response = sg.client.suppression.bounces.get(query_params=params)
        bounces = response.to_dict

        return {
            'count': len(bounces),
            'bounces': [{
                'email': b.get('email'),
                'reason': b.get('reason'),
                'created': b.get('created')
            } for b in bounces]
        }

    except Exception as e:
        return {'error': f'Failed to get bounces: {str(e)}'}
```

## AI-Powered Email Generation

Generate personalized email content:

```python
# email_generator.py
from gantz import MCPClient

mcp = MCPClient()


async def generate_welcome_email(user: dict) -> dict:
    """Generate personalized welcome email."""
    result = mcp.execute_tool('ai_generate', {
        'type': 'email',
        'template': 'welcome',
        'context': {
            'name': user.get('first_name', 'there'),
            'company': user.get('company'),
            'interests': user.get('interests', []),
            'signup_source': user.get('signup_source')
        },
        'tone': 'friendly_professional',
        'length': 'medium'
    })

    return {
        'subject': result.get('subject'),
        'content': result.get('content'),
        'personalization_score': result.get('personalization_score')
    }


async def generate_follow_up(user: dict, interaction_history: list) -> dict:
    """Generate follow-up email based on user activity."""
    # Analyze user behavior
    analysis = mcp.execute_tool('analyze_user_engagement', {
        'user_id': user.get('id'),
        'interactions': interaction_history
    })

    # Generate appropriate follow-up
    result = mcp.execute_tool('ai_generate', {
        'type': 'email',
        'template': 'follow_up',
        'context': {
            'name': user.get('first_name'),
            'last_interaction': analysis.get('last_interaction'),
            'interests': analysis.get('inferred_interests'),
            'engagement_level': analysis.get('engagement_level')
        },
        'goal': analysis.get('recommended_action'),
        'tone': 'helpful'
    })

    return result


async def optimize_subject_line(subject: str, audience: str) -> dict:
    """Optimize subject line with AI."""
    result = mcp.execute_tool('ai_optimize', {
        'type': 'subject_line',
        'original': subject,
        'audience': audience,
        'goals': ['open_rate', 'engagement'],
        'variations': 5
    })

    return {
        'original': subject,
        'optimized': result.get('best_variant'),
        'alternatives': result.get('variants'),
        'predicted_improvement': result.get('predicted_improvement')
    }
```

## Email Automation Workflows

Build automated email sequences:

```python
# workflows.py
from gantz import MCPClient
from datetime import datetime, timedelta
import asyncio

mcp = MCPClient()


class EmailWorkflow:
    """AI-powered email workflow automation."""

    def __init__(self, workflow_id: str):
        self.workflow_id = workflow_id
        self.steps = []

    def add_step(self, delay_hours: int, template: str, conditions: dict = None):
        """Add step to workflow."""
        self.steps.append({
            'delay_hours': delay_hours,
            'template': template,
            'conditions': conditions or {}
        })
        return self

    async def execute(self, user: dict):
        """Execute workflow for user."""
        for i, step in enumerate(self.steps):
            # Wait for delay
            if step['delay_hours'] > 0:
                await asyncio.sleep(step['delay_hours'] * 3600)

            # Check conditions
            if not await self.check_conditions(user, step['conditions']):
                continue

            # Generate and send email
            email = await self.generate_step_email(user, step)

            mcp.execute_tool('send_email', {
                'to': user['email'],
                'subject': email['subject'],
                'content': email['content']
            })

            # Log step
            await self.log_step(user, i, email)

    async def check_conditions(self, user: dict, conditions: dict) -> bool:
        """Check if step conditions are met."""
        if not conditions:
            return True

        # Check engagement condition
        if 'min_engagement' in conditions:
            engagement = await self.get_user_engagement(user['id'])
            if engagement < conditions['min_engagement']:
                return False

        # Check if user opened previous email
        if conditions.get('opened_previous'):
            if not await self.check_previous_opened(user['id']):
                return False

        return True

    async def generate_step_email(self, user: dict, step: dict) -> dict:
        """Generate email for workflow step."""
        result = mcp.execute_tool('ai_generate', {
            'type': 'email',
            'template': step['template'],
            'context': {
                'name': user.get('first_name'),
                'workflow': self.workflow_id,
                'step': step
            }
        })
        return result


# Example workflows
def create_onboarding_workflow() -> EmailWorkflow:
    """Create onboarding email sequence."""
    return (
        EmailWorkflow('onboarding')
        .add_step(0, 'welcome')
        .add_step(24, 'getting_started', {'opened_previous': True})
        .add_step(72, 'feature_highlight')
        .add_step(168, 'success_story')
        .add_step(336, 'check_in', {'min_engagement': 0.3})
    )


def create_re_engagement_workflow() -> EmailWorkflow:
    """Create re-engagement workflow for inactive users."""
    return (
        EmailWorkflow('re_engagement')
        .add_step(0, 'miss_you')
        .add_step(72, 'special_offer', {'opened_previous': False})
        .add_step(168, 'last_chance')
    )
```

## Webhook Handler for Events

Process SendGrid events:

```python
# webhooks.py
from fastapi import FastAPI, Request
from gantz import MCPClient

app = FastAPI()
mcp = MCPClient()


@app.post("/sendgrid/events")
async def handle_sendgrid_events(request: Request):
    """Handle SendGrid webhook events."""
    events = await request.json()

    for event in events:
        event_type = event.get('event')
        email = event.get('email')

        if event_type == 'open':
            await handle_open(email, event)

        elif event_type == 'click':
            await handle_click(email, event)

        elif event_type == 'bounce':
            await handle_bounce(email, event)

        elif event_type == 'unsubscribe':
            await handle_unsubscribe(email, event)

        elif event_type == 'spam_report':
            await handle_spam_report(email, event)

    return {"processed": len(events)}


async def handle_open(email: str, event: dict):
    """Handle email open event."""
    # Update engagement score
    mcp.execute_tool('update_engagement', {
        'email': email,
        'event': 'open',
        'timestamp': event.get('timestamp')
    })

    # Trigger follow-up if applicable
    user = await get_user_by_email(email)
    if user and should_follow_up(user, event):
        mcp.execute_tool('queue_follow_up', {
            'user_id': user['id'],
            'trigger': 'email_open',
            'delay_hours': 24
        })


async def handle_click(email: str, event: dict):
    """Handle link click event."""
    url = event.get('url')

    # Track interest
    mcp.execute_tool('track_interest', {
        'email': email,
        'url': url,
        'category': categorize_url(url)
    })

    # Update lead score
    mcp.execute_tool('update_lead_score', {
        'email': email,
        'action': 'click',
        'value': get_click_value(url)
    })


async def handle_bounce(email: str, event: dict):
    """Handle bounce event."""
    bounce_type = event.get('type')

    mcp.execute_tool('handle_bounce', {
        'email': email,
        'type': bounce_type,
        'reason': event.get('reason')
    })

    # Remove from active lists if hard bounce
    if bounce_type == 'hard':
        mcp.execute_tool('suppress_email', {'email': email})


async def handle_unsubscribe(email: str, event: dict):
    """Handle unsubscribe event."""
    mcp.execute_tool('process_unsubscribe', {
        'email': email,
        'timestamp': event.get('timestamp')
    })

    # Trigger win-back later
    mcp.execute_tool('schedule_winback', {
        'email': email,
        'delay_days': 90
    })
```

## Deploy with Gantz CLI

Deploy your email automation:

```bash
# Install Gantz
npm install -g gantz

# Initialize SendGrid project
gantz init --template sendgrid-automation

# Set environment variables
export SENDGRID_API_KEY=your-api-key
export SENDGRID_FROM_EMAIL=noreply@yourdomain.com

# Deploy
gantz deploy --platform railway

# Test email send
gantz run send_email \
  --to test@example.com \
  --subject "Test Email" \
  --content "<h1>Hello!</h1><p>This is a test.</p>"
```

Build intelligent email automation at [gantz.run](https://gantz.run).

## Related Reading

- [Mailchimp MCP Integration](/post/mailchimp-mcp-integration/) - Marketing automation
- [Twilio MCP Integration](/post/twilio-mcp-integration/) - Multi-channel messaging
- [MCP Batching](/post/mcp-batching/) - Efficient bulk operations

## Conclusion

SendGrid and MCP create powerful email automation systems. With AI-generated content, personalization, and engagement tracking, you can build email experiences that drive results and scale effortlessly.

Start building email AI agents with Gantz today.
