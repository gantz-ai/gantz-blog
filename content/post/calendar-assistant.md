+++
title = "AI Calendar Assistant: Schedule Meetings Automatically"
image = "images/calendar-assistant.webp"
date = 2025-11-14
description = "Build an AI calendar assistant that schedules meetings, finds optimal times, manages conflicts, and handles rescheduling using MCP tools."
summary = "Scheduling meetings shouldn't require 5 back-and-forth emails. Build an AI calendar assistant that checks everyone's availability, finds optimal meeting times considering time zones and preferences, resolves conflicts automatically, and handles rescheduling through natural language. 'Find 30 minutes with the design team next week' - done in seconds."
draft = false
tags = ['mcp', 'tutorial', 'calendar']
voice = false

[howto]
name = "Build Calendar Assistant"
totalTime = 30
[[howto.steps]]
name = "Create calendar tools"
text = "Build MCP tools for calendar API access and time management."
[[howto.steps]]
name = "Implement scheduling logic"
text = "Create prompts for finding optimal meeting times."
[[howto.steps]]
name = "Build conflict resolution"
text = "Handle double-bookings and priority conflicts."
[[howto.steps]]
name = "Add natural language"
text = "Parse natural language scheduling requests."
[[howto.steps]]
name = "Create notification system"
text = "Send reminders and updates to participants."
+++


"Find a time that works for everyone."

The most dreaded phrase in corporate communication.

AI can finally solve this.

## The scheduling nightmare

Manual scheduling involves:
- Checking multiple calendars
- Sending "when works for you?" emails
- Playing timezone Tetris
- Rescheduling when someone cancels
- Forgetting to send reminders

AI scheduling:
- Checks all calendars instantly
- Finds optimal times automatically
- Handles timezones correctly
- Reschedules automatically
- Sends appropriate reminders

## What you'll build

- Calendar integration
- Smart time slot finding
- Multi-participant scheduling
- Conflict detection and resolution
- Natural language requests
- Automated rescheduling

## Step 1: Create calendar tools

Using [Gantz](https://gantz.run):

```yaml
# gantz.yaml
name: calendar-assistant

tools:
  - name: get_calendar_events
    description: Get events from a calendar within a date range
    parameters:
      - name: calendar_id
        type: string
        default: "primary"
      - name: start_date
        type: string
        required: true
        description: Start date (ISO format)
      - name: end_date
        type: string
        required: true
        description: End date (ISO format)
    script:
      command: python
      args: ["scripts/get_events.py", "{{calendar_id}}", "{{start_date}}", "{{end_date}}"]

  - name: create_event
    description: Create a calendar event
    parameters:
      - name: title
        type: string
        required: true
      - name: start_time
        type: string
        required: true
      - name: end_time
        type: string
        required: true
      - name: attendees
        type: string
        description: Comma-separated email addresses
      - name: description
        type: string
      - name: location
        type: string
      - name: calendar_id
        type: string
        default: "primary"
    script:
      command: python
      args: ["scripts/create_event.py", "{{calendar_id}}", "{{title}}", "{{start_time}}", "{{end_time}}", "{{attendees}}", "{{description}}", "{{location}}"]

  - name: update_event
    description: Update an existing event
    parameters:
      - name: event_id
        type: string
        required: true
      - name: updates
        type: string
        required: true
        description: JSON object with fields to update
    script:
      command: python
      args: ["scripts/update_event.py", "{{event_id}}", "{{updates}}"]

  - name: delete_event
    description: Delete a calendar event
    parameters:
      - name: event_id
        type: string
        required: true
      - name: notify
        type: boolean
        default: true
    script:
      command: python
      args: ["scripts/delete_event.py", "{{event_id}}", "{{notify}}"]

  - name: find_free_slots
    description: Find available time slots for multiple participants
    parameters:
      - name: participants
        type: string
        required: true
        description: Comma-separated email addresses
      - name: duration_minutes
        type: integer
        required: true
      - name: start_date
        type: string
        required: true
      - name: end_date
        type: string
        required: true
      - name: working_hours_start
        type: string
        default: "09:00"
      - name: working_hours_end
        type: string
        default: "17:00"
    script:
      command: python
      args: ["scripts/find_free_slots.py", "{{participants}}", "{{duration_minutes}}", "{{start_date}}", "{{end_date}}", "{{working_hours_start}}", "{{working_hours_end}}"]

  - name: get_user_preferences
    description: Get user scheduling preferences
    parameters:
      - name: user_email
        type: string
        required: true
    script:
      shell: cat "preferences/{{user_email}}.json" 2>/dev/null || echo '{"working_hours": {"start": "09:00", "end": "17:00"}, "timezone": "UTC"}'

  - name: send_invite
    description: Send a calendar invite to participants
    parameters:
      - name: event_id
        type: string
        required: true
      - name: message
        type: string
    script:
      command: python
      args: ["scripts/send_invite.py", "{{event_id}}", "{{message}}"]

  - name: send_reminder
    description: Send a reminder for an upcoming event
    parameters:
      - name: event_id
        type: string
        required: true
      - name: recipients
        type: string
        description: Comma-separated emails
    script:
      command: python
      args: ["scripts/send_reminder.py", "{{event_id}}", "{{recipients}}"]

  - name: get_timezone
    description: Get timezone for a location or user
    parameters:
      - name: query
        type: string
        required: true
        description: User email or location name
    script:
      command: python
      args: ["scripts/get_timezone.py", "{{query}}"]
```

Find free slots script:

```python
# scripts/find_free_slots.py
import sys
import json
from datetime import datetime, timedelta
from google.oauth2.credentials import Credentials
from googleapiclient.discovery import build

def find_free_slots(participants: list, duration_minutes: int,
                    start_date: str, end_date: str,
                    working_start: str = "09:00",
                    working_end: str = "17:00") -> list:
    """Find available time slots for all participants."""

    creds = Credentials.from_authorized_user_file('credentials.json')
    service = build('calendar', 'v3', credentials=creds)

    # Get free/busy for all participants
    body = {
        "timeMin": start_date,
        "timeMax": end_date,
        "items": [{"id": p} for p in participants]
    }

    response = service.freebusy().query(body=body).execute()

    # Collect all busy times
    busy_times = []
    for calendar in response.get('calendars', {}).values():
        for busy in calendar.get('busy', []):
            busy_times.append({
                'start': datetime.fromisoformat(busy['start'].replace('Z', '+00:00')),
                'end': datetime.fromisoformat(busy['end'].replace('Z', '+00:00'))
            })

    # Sort busy times
    busy_times.sort(key=lambda x: x['start'])

    # Find free slots within working hours
    free_slots = []
    current = datetime.fromisoformat(start_date.replace('Z', '+00:00'))
    end = datetime.fromisoformat(end_date.replace('Z', '+00:00'))

    while current < end:
        # Check if within working hours
        work_start = current.replace(
            hour=int(working_start.split(':')[0]),
            minute=int(working_start.split(':')[1])
        )
        work_end = current.replace(
            hour=int(working_end.split(':')[0]),
            minute=int(working_end.split(':')[1])
        )

        if work_start <= current < work_end:
            # Check if this slot conflicts with any busy time
            slot_end = current + timedelta(minutes=duration_minutes)

            is_free = True
            for busy in busy_times:
                if not (slot_end <= busy['start'] or current >= busy['end']):
                    is_free = False
                    break

            if is_free and slot_end <= work_end:
                free_slots.append({
                    'start': current.isoformat(),
                    'end': slot_end.isoformat()
                })

        # Move to next slot (30 min intervals)
        current += timedelta(minutes=30)

        # Skip to next day if past working hours
        if current.hour >= int(working_end.split(':')[0]):
            current = current.replace(
                hour=int(working_start.split(':')[0]),
                minute=0
            ) + timedelta(days=1)

    return free_slots[:20]  # Return top 20 options

if __name__ == "__main__":
    participants = sys.argv[1].split(',')
    duration = int(sys.argv[2])
    start_date = sys.argv[3]
    end_date = sys.argv[4]
    working_start = sys.argv[5] if len(sys.argv) > 5 else "09:00"
    working_end = sys.argv[6] if len(sys.argv) > 6 else "17:00"

    slots = find_free_slots(participants, duration, start_date, end_date,
                           working_start, working_end)
    print(json.dumps(slots, indent=2))
```

```bash
gantz run --auth
```

## Step 2: The calendar assistant agent

```python
import anthropic
from typing import List, Optional, Dict
from datetime import datetime, timedelta
import json

MCP_URL = "https://calendar-assistant.gantz.run/sse"
MCP_TOKEN = "gtz_abc123"

client = anthropic.Anthropic()

CALENDAR_SYSTEM_PROMPT = """You are an intelligent calendar assistant.

Your capabilities:
- Find available meeting times for multiple people
- Schedule meetings with appropriate details
- Handle timezone conversions automatically
- Resolve scheduling conflicts
- Send invites and reminders
- Reschedule when needed

Guidelines:
1. **Respect preferences**: Consider working hours and timezone preferences
2. **Be efficient**: Suggest the best times, not all possible times
3. **Handle conflicts**: Propose alternatives when there are conflicts
4. **Clear communication**: Always confirm details before creating events
5. **Smart defaults**: Use sensible defaults for meeting duration, buffer time

When scheduling:
- Default meeting duration: 30 minutes
- Buffer between meetings: 15 minutes
- Prefer morning slots for complex topics
- Avoid scheduling over lunch (12-1pm) unless necessary
- Consider travel time for in-person meetings

Current date/time context matters - always use it."""

def schedule_meeting(request: str) -> str:
    """Schedule a meeting based on natural language request."""

    current_time = datetime.now().isoformat()

    response = client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=2048,
        system=CALENDAR_SYSTEM_PROMPT,
        messages=[{
            "role": "user",
            "content": f"""Current time: {current_time}

Schedule this meeting: {request}

Steps:
1. Parse the request to identify:
   - Participants (emails if provided, or ask)
   - Duration
   - Topic/title
   - Date range for scheduling
   - Any constraints

2. Get user preferences for each participant
3. Use find_free_slots to find available times
4. Present the best 3-5 options with pros/cons
5. Once a time is selected, use create_event
6. Send invites using send_invite

Be conversational and helpful."""
        }],
        tools=[{"type": "mcp", "server_url": MCP_URL, "token": MCP_TOKEN}]
    )

    for content in response.content:
        if hasattr(content, 'text'):
            return content.text

    return ""

def find_time_for_meeting(participants: List[str], duration: int,
                          within_days: int = 7) -> str:
    """Find available times for a meeting."""

    current_time = datetime.now()
    start_date = current_time.isoformat()
    end_date = (current_time + timedelta(days=within_days)).isoformat()

    response = client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=2048,
        system=CALENDAR_SYSTEM_PROMPT,
        messages=[{
            "role": "user",
            "content": f"""Find available times for a {duration} minute meeting.

Participants: {', '.join(participants)}
Search range: {start_date} to {end_date}

1. Get timezone preferences for each participant
2. Use find_free_slots with appropriate working hours
3. Rank slots by:
   - Number of participants in their optimal hours
   - Proximity to preferred times
   - Day of week preferences
4. Return top 5 options with clear timezone info"""
        }],
        tools=[{"type": "mcp", "server_url": MCP_URL, "token": MCP_TOKEN}]
    )

    for content in response.content:
        if hasattr(content, 'text'):
            return content.text

    return ""

def reschedule_meeting(event_id: str, reason: str) -> str:
    """Reschedule an existing meeting."""

    response = client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=2048,
        system=CALENDAR_SYSTEM_PROMPT,
        messages=[{
            "role": "user",
            "content": f"""Reschedule meeting {event_id}.

Reason: {reason}

Steps:
1. Get current event details
2. Find new available slots for all participants
3. Suggest alternatives
4. Update the event when new time is confirmed
5. Notify all participants of the change

Be apologetic and helpful about the reschedule."""
        }],
        tools=[{"type": "mcp", "server_url": MCP_URL, "token": MCP_TOKEN}]
    )

    for content in response.content:
        if hasattr(content, 'text'):
            return content.text

    return ""
```

## Step 3: Conflict resolution

```python
def check_conflicts(user: str, proposed_time: str, duration: int) -> Dict:
    """Check for conflicts with a proposed meeting time."""

    response = client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=1024,
        system=CALENDAR_SYSTEM_PROMPT,
        messages=[{
            "role": "user",
            "content": f"""Check for conflicts:
User: {user}
Proposed time: {proposed_time}
Duration: {duration} minutes

1. Get events around this time
2. Check for:
   - Direct conflicts (overlapping meetings)
   - Travel time issues (if location-based meetings)
   - Insufficient buffer time
   - Too many meetings that day
3. Return conflict details and suggestions"""
        }],
        tools=[{"type": "mcp", "server_url": MCP_URL, "token": MCP_TOKEN}]
    )

    for content in response.content:
        if hasattr(content, 'text'):
            try:
                return json.loads(content.text)
            except:
                return {"raw": content.text}

    return {}

def resolve_conflict(event_id: str, conflicting_event_id: str) -> str:
    """Resolve a scheduling conflict between two events."""

    response = client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=2048,
        system=CALENDAR_SYSTEM_PROMPT + """

        Conflict resolution priorities:
        1. External meetings > Internal meetings
        2. More participants > Fewer participants
        3. Earlier scheduled > Later scheduled
        4. Recurring meetings are harder to move
        5. Consider importance hints in titles/descriptions""",
        messages=[{
            "role": "user",
            "content": f"""Resolve conflict between events:
Event 1: {event_id}
Event 2: {conflicting_event_id}

1. Get details of both events
2. Analyze which should take priority
3. Suggest options:
   - Move one event
   - Shorten one event
   - Propose alternative times for the lower-priority event
4. Present options with reasoning"""
        }],
        tools=[{"type": "mcp", "server_url": MCP_URL, "token": MCP_TOKEN}]
    )

    for content in response.content:
        if hasattr(content, 'text'):
            return content.text

    return ""

def optimize_day(user: str, date: str) -> str:
    """Optimize a day's calendar to reduce fragmentation."""

    response = client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=2048,
        system=CALENDAR_SYSTEM_PROMPT,
        messages=[{
            "role": "user",
            "content": f"""Optimize calendar for {user} on {date}.

1. Get all events for the day
2. Identify:
   - Fragmented time (small gaps between meetings)
   - Back-to-back meetings without breaks
   - Suboptimal meeting distribution
3. Suggest optimizations:
   - Consolidate meetings
   - Add buffer time
   - Move flexible meetings
4. Show before/after comparison

Only suggest moving meetings that can be moved (internal, flexible)."""
        }],
        tools=[{"type": "mcp", "server_url": MCP_URL, "token": MCP_TOKEN}]
    )

    for content in response.content:
        if hasattr(content, 'text'):
            return content.text

    return ""
```

## Step 4: Natural language processing

```python
def parse_scheduling_request(request: str) -> Dict:
    """Parse a natural language scheduling request."""

    response = client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=1024,
        messages=[{
            "role": "user",
            "content": f"""Parse this scheduling request:

"{request}"

Extract:
- meeting_type: one-on-one, team, external, etc.
- participants: list of names/emails (or "unspecified")
- duration: in minutes (infer if not stated, default 30)
- date_constraints: specific date, range, or flexible
- time_constraints: morning/afternoon/specific time
- location: virtual, physical, or unspecified
- topic: what the meeting is about
- urgency: high, normal, low
- recurring: one-time or recurring pattern

Output as JSON."""
        }]
    )

    for content in response.content:
        if hasattr(content, 'text'):
            try:
                return json.loads(content.text)
            except:
                return {"raw": content.text}

    return {}

def handle_request(request: str) -> str:
    """Handle any calendar-related request in natural language."""

    response = client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=2048,
        system=CALENDAR_SYSTEM_PROMPT + f"""

        Current time: {datetime.now().isoformat()}

        Handle any calendar request:
        - "Schedule a meeting with..." → Find time and create event
        - "When am I free..." → Check availability
        - "Cancel my..." → Find and delete event
        - "Move my..." → Reschedule
        - "What's on my calendar..." → List events
        - "Find time for..." → Find available slots""",
        messages=[{
            "role": "user",
            "content": request
        }],
        tools=[{"type": "mcp", "server_url": MCP_URL, "token": MCP_TOKEN}]
    )

    for content in response.content:
        if hasattr(content, 'text'):
            return content.text

    return ""
```

## Step 5: CLI and integration

```python
#!/usr/bin/env python3
"""Calendar Assistant CLI."""

import argparse

def main():
    parser = argparse.ArgumentParser(description="AI Calendar Assistant")
    subparsers = parser.add_subparsers(dest="command", help="Commands")

    # Schedule
    schedule_parser = subparsers.add_parser("schedule", help="Schedule meeting")
    schedule_parser.add_argument("request", nargs="+", help="Natural language request")

    # Find time
    find_parser = subparsers.add_parser("find", help="Find available time")
    find_parser.add_argument("--with", "-w", dest="participants", required=True,
                            help="Participants (comma-separated)")
    find_parser.add_argument("--duration", "-d", type=int, default=30)
    find_parser.add_argument("--within", "-n", type=int, default=7,
                            help="Days to search")

    # Check conflicts
    conflict_parser = subparsers.add_parser("conflicts", help="Check conflicts")
    conflict_parser.add_argument("--user", "-u", required=True)
    conflict_parser.add_argument("--time", "-t", required=True)
    conflict_parser.add_argument("--duration", "-d", type=int, default=30)

    # Optimize
    optimize_parser = subparsers.add_parser("optimize", help="Optimize calendar")
    optimize_parser.add_argument("--user", "-u", required=True)
    optimize_parser.add_argument("--date", "-d", required=True)

    # Ask (natural language)
    ask_parser = subparsers.add_parser("ask", help="Natural language request")
    ask_parser.add_argument("question", nargs="+")

    args = parser.parse_args()

    if args.command == "schedule":
        request = " ".join(args.request)
        result = schedule_meeting(request)
        print(result)

    elif args.command == "find":
        participants = args.participants.split(",")
        result = find_time_for_meeting(participants, args.duration, args.within)
        print(result)

    elif args.command == "conflicts":
        result = check_conflicts(args.user, args.time, args.duration)
        print(json.dumps(result, indent=2))

    elif args.command == "optimize":
        result = optimize_day(args.user, args.date)
        print(result)

    elif args.command == "ask":
        question = " ".join(args.question)
        result = handle_request(question)
        print(result)

    else:
        parser.print_help()

if __name__ == "__main__":
    main()
```

Usage:

```bash
# Schedule with natural language
./calendar.py schedule "30 minute sync with Alice next week"

# Find time for meeting
./calendar.py find --with alice@co.com,bob@co.com --duration 60 --within 14

# Check for conflicts
./calendar.py conflicts --user me@co.com --time "2024-01-15T10:00:00" --duration 60

# Optimize a day's schedule
./calendar.py optimize --user me@co.com --date 2024-01-15

# Natural language queries
./calendar.py ask "What's on my calendar tomorrow?"
./calendar.py ask "Cancel all my meetings on Friday"
./calendar.py ask "When can I meet with the engineering team this week?"
```

## Summary

Building a calendar assistant:

1. **Calendar integration** - Google/Outlook API access
2. **Smart scheduling** - Find optimal times for everyone
3. **Conflict resolution** - Handle and resolve conflicts
4. **Natural language** - Understand scheduling requests
5. **Automation** - Reminders and rescheduling

Build tools with [Gantz](https://gantz.run), end scheduling nightmares.

Calendar management that actually works.

## Related reading

- [Smart Notifications](/post/smart-notifications/) - Alert systems
- [Build a Support Bot](/post/support-bot-mcp/) - Conversational AI
- [AI Data Analyst](/post/data-analyst-agent/) - Data queries

---

*How do you handle scheduling? Share your approach.*
