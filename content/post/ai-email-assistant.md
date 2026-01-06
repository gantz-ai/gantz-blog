+++
title = "Let AI agents read and respond to your emails"
date = 2026-01-02
image = "images/cafe-interior.webp"
draft = false
tags = ['tutorial', 'automation', 'mcp']
+++


I wanted an AI assistant that could actually do stuff with my email. Not just summarize — actually read, draft, and send responses.

Turns out it's not that hard. Here's how I set it up.

## The idea

Your AI agent (Claude, GPT, Gemini, whatever) connects to an MCP server that has email tools. It can:

- Check your inbox
- Read specific emails
- Search for emails
- Draft responses
- Send emails

All through natural conversation.

```
You → AI Agent → MCP Server (your machine) → Email API → Gmail/Outlook
```

## What you'll need

- Gmail or any email with API access
- [Gantz CLI](https://gantz.run)
- Python (for the email scripts)
- 30 minutes

## Step 1: Set up Gmail API

1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Create a project
3. Enable Gmail API
4. Create OAuth credentials (Desktop app)
5. Download `credentials.json`

Install the client:

```bash
pip install google-auth-oauthlib google-api-python-client
```

Run this once to authenticate:

```python
from google_auth_oauthlib.flow import InstalledAppFlow
from google.auth.transport.requests import Request
import pickle
import os

SCOPES = ['https://www.googleapis.com/auth/gmail.modify']

def get_credentials():
    creds = None
    if os.path.exists('token.pickle'):
        with open('token.pickle', 'rb') as token:
            creds = pickle.load(token)

    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            creds.refresh(Request())
        else:
            flow = InstalledAppFlow.from_client_secrets_file('credentials.json', SCOPES)
            creds = flow.run_local_server(port=0)

        with open('token.pickle', 'wb') as token:
            pickle.dump(creds, token)

    return creds

if __name__ == '__main__':
    get_credentials()
    print("Authentication successful!")
```

## Step 2: Create email scripts

Create a folder with these scripts:

**list_emails.py:**

```python
#!/usr/bin/env python3
import sys
from googleapiclient.discovery import build
from google.oauth2.credentials import Credentials
import pickle

def main():
    count = int(sys.argv[1]) if len(sys.argv) > 1 else 10

    with open('token.pickle', 'rb') as token:
        creds = pickle.load(token)

    service = build('gmail', 'v1', credentials=creds)
    results = service.users().messages().list(userId='me', maxResults=count, labelIds=['INBOX']).execute()
    messages = results.get('messages', [])

    for msg in messages:
        message = service.users().messages().get(userId='me', id=msg['id'], format='metadata',
            metadataHeaders=['From', 'Subject', 'Date']).execute()
        headers = {h['name']: h['value'] for h in message['payload']['headers']}
        snippet = message.get('snippet', '')[:100]
        print(f"ID: {msg['id']}")
        print(f"From: {headers.get('From', 'Unknown')}")
        print(f"Subject: {headers.get('Subject', 'No subject')}")
        print(f"Date: {headers.get('Date', '')}")
        print(f"Preview: {snippet}...")
        print("---")

if __name__ == '__main__':
    main()
```

**read_email.py:**

```python
#!/usr/bin/env python3
import sys
import base64
from googleapiclient.discovery import build
import pickle

def main():
    if len(sys.argv) < 2:
        print("Usage: read_email.py <email_id>")
        sys.exit(1)

    email_id = sys.argv[1]

    with open('token.pickle', 'rb') as token:
        creds = pickle.load(token)

    service = build('gmail', 'v1', credentials=creds)
    message = service.users().messages().get(userId='me', id=email_id, format='full').execute()

    headers = {h['name']: h['value'] for h in message['payload']['headers']}
    print(f"From: {headers.get('From', 'Unknown')}")
    print(f"To: {headers.get('To', 'Unknown')}")
    print(f"Subject: {headers.get('Subject', 'No subject')}")
    print(f"Date: {headers.get('Date', '')}")
    print("\n--- Body ---\n")

    # Get body
    if 'parts' in message['payload']:
        for part in message['payload']['parts']:
            if part['mimeType'] == 'text/plain':
                body = base64.urlsafe_b64decode(part['body']['data']).decode('utf-8')
                print(body)
                break
    elif 'body' in message['payload'] and 'data' in message['payload']['body']:
        body = base64.urlsafe_b64decode(message['payload']['body']['data']).decode('utf-8')
        print(body)

if __name__ == '__main__':
    main()
```

**search_emails.py:**

```python
#!/usr/bin/env python3
import sys
from googleapiclient.discovery import build
import pickle

def main():
    if len(sys.argv) < 2:
        print("Usage: search_emails.py <query>")
        sys.exit(1)

    query = ' '.join(sys.argv[1:])

    with open('token.pickle', 'rb') as token:
        creds = pickle.load(token)

    service = build('gmail', 'v1', credentials=creds)
    results = service.users().messages().list(userId='me', q=query, maxResults=10).execute()
    messages = results.get('messages', [])

    if not messages:
        print("No emails found.")
        return

    for msg in messages:
        message = service.users().messages().get(userId='me', id=msg['id'], format='metadata',
            metadataHeaders=['From', 'Subject', 'Date']).execute()
        headers = {h['name']: h['value'] for h in message['payload']['headers']}
        print(f"ID: {msg['id']}")
        print(f"From: {headers.get('From', 'Unknown')}")
        print(f"Subject: {headers.get('Subject', 'No subject')}")
        print("---")

if __name__ == '__main__':
    main()
```

**send_email.py:**

```python
#!/usr/bin/env python3
import sys
import base64
from email.mime.text import MIMEText
from googleapiclient.discovery import build
import pickle

def main():
    if len(sys.argv) < 4:
        print("Usage: send_email.py <to> <subject> <body>")
        sys.exit(1)

    to = sys.argv[1]
    subject = sys.argv[2]
    body = sys.argv[3]

    with open('token.pickle', 'rb') as token:
        creds = pickle.load(token)

    service = build('gmail', 'v1', credentials=creds)

    message = MIMEText(body)
    message['to'] = to
    message['subject'] = subject
    raw = base64.urlsafe_b64encode(message.as_bytes()).decode()

    result = service.users().messages().send(userId='me', body={'raw': raw}).execute()
    print(f"Email sent! Message ID: {result['id']}")

if __name__ == '__main__':
    main()
```

**draft_reply.py:**

```python
#!/usr/bin/env python3
import sys
import base64
from email.mime.text import MIMEText
from googleapiclient.discovery import build
import pickle

def main():
    if len(sys.argv) < 3:
        print("Usage: draft_reply.py <email_id> <reply_body>")
        sys.exit(1)

    email_id = sys.argv[1]
    reply_body = sys.argv[2]

    with open('token.pickle', 'rb') as token:
        creds = pickle.load(token)

    service = build('gmail', 'v1', credentials=creds)

    # Get original email
    original = service.users().messages().get(userId='me', id=email_id, format='metadata',
        metadataHeaders=['From', 'Subject', 'Message-ID']).execute()
    headers = {h['name']: h['value'] for h in original['payload']['headers']}

    # Create reply
    message = MIMEText(reply_body)
    message['to'] = headers.get('From', '')
    message['subject'] = 'Re: ' + headers.get('Subject', '')
    message['In-Reply-To'] = headers.get('Message-ID', '')
    message['References'] = headers.get('Message-ID', '')
    raw = base64.urlsafe_b64encode(message.as_bytes()).decode()

    # Create draft
    draft = service.users().drafts().create(userId='me', body={
        'message': {'raw': raw, 'threadId': original['threadId']}
    }).execute()

    print(f"Draft created! Draft ID: {draft['id']}")
    print(f"Reply to: {headers.get('From', '')}")
    print(f"Subject: Re: {headers.get('Subject', '')}")

if __name__ == '__main__':
    main()
```

## Step 3: Create your MCP config

```yaml
name: email-assistant
description: AI email assistant tools

tools:
  - name: list_emails
    description: List recent emails from inbox
    parameters:
      - name: count
        type: integer
        description: Number of emails to show (default 10)
        default: 10
    script:
      command: python3
      args: ["./scripts/list_emails.py", "{{count}}"]
      working_dir: "${HOME}/email-tools"

  - name: read_email
    description: Read the full content of an email by ID
    parameters:
      - name: email_id
        type: string
        required: true
        description: The email ID to read
    script:
      command: python3
      args: ["./scripts/read_email.py", "{{email_id}}"]
      working_dir: "${HOME}/email-tools"

  - name: search_emails
    description: Search emails by query (from:, subject:, has:attachment, etc.)
    parameters:
      - name: query
        type: string
        required: true
        description: Gmail search query
    script:
      command: python3
      args: ["./scripts/search_emails.py", "{{query}}"]
      working_dir: "${HOME}/email-tools"

  - name: send_email
    description: Send a new email
    parameters:
      - name: to
        type: string
        required: true
        description: Recipient email address
      - name: subject
        type: string
        required: true
      - name: body
        type: string
        required: true
    script:
      command: python3
      args: ["./scripts/send_email.py", "{{to}}", "{{subject}}", "{{body}}"]
      working_dir: "${HOME}/email-tools"

  - name: draft_reply
    description: Create a draft reply to an email (doesn't send, just saves as draft)
    parameters:
      - name: email_id
        type: string
        required: true
        description: The email ID to reply to
      - name: body
        type: string
        required: true
        description: The reply content
    script:
      command: python3
      args: ["./scripts/draft_reply.py", "{{email_id}}", "{{body}}"]
      working_dir: "${HOME}/email-tools"
```

## Step 4: Run it

```bash
gantz run --auth
```

You'll get a tunnel URL and auth token:

```
Tunnel URL: https://cool-penguin.gantz.run
Auth Token: gtz_abc123...
```

## Step 5: Connect Claude (or any AI agent)

Here's a Python example using Claude:

```python
import anthropic

client = anthropic.Anthropic(api_key="your-api-key")

response = client.beta.messages.create(
    model="claude-sonnet-4-5-20250929",
    max_tokens=2048,
    system="You are an email assistant. Use the available tools to help manage emails. Always show relevant details when listing or reading emails.",
    messages=[{"role": "user", "content": "Show me my last 5 emails"}],
    mcp_servers=[{
        "type": "url",
        "url": "https://cool-penguin.gantz.run/sse",
        "name": "email",
        "authorization_token": "gtz_abc123..."
    }],
    tools=[{"type": "mcp_toolset", "mcp_server_name": "email"}],
    betas=["mcp-client-2025-11-20"]
)

for block in response.content:
    if hasattr(block, "text"):
        print(block.text)
```

Works the same with GPT, Gemini, or any MCP-compatible agent.

## What you can ask

```
"Show me my last 5 emails"

"Any emails from my boss this week?"
→ search_emails with "from:boss@company.com newer_than:7d"

"Read the email from Sarah about the project"
→ Searches, finds it, reads full content

"Draft a reply saying I'll have it done by Friday"
→ Creates a draft, doesn't send

"Send a quick email to john@example.com asking about lunch"
→ Composes and sends
```

## Safety first

Some tips:

1. **Use drafts first** — Have AI create drafts instead of sending directly
2. **Review before send** — Add a confirmation step for sending
3. **Limit scope** — Maybe read-only tools first
4. **Use `--auth`** — Always protect your tunnel

You can also create a "safe mode" config with only read tools:

```yaml
tools:
  - name: list_emails
    # ...
  - name: read_email
    # ...
  - name: search_emails
    # ...
  # No send tools!
```

## Works with any AI

This isn't Claude-specific. Any AI agent that supports MCP can use these tools:

- Claude (Anthropic)
- GPT (OpenAI) — with MCP support
- Gemini (Google)
- Local models via LangChain/LlamaIndex
- Your own agents

The MCP server doesn't care who's calling it.

## Ideas to extend

- **Summarize daily** — "Give me a summary of today's important emails"
- **Auto-categorize** — "Label all newsletters as low priority"
- **Follow-ups** — "Remind me to follow up on unanswered emails"
- **Templates** — Add common response templates
- **Calendar integration** — "Schedule a meeting based on this email"

## Why local?

Your emails stay on your machine. The AI connects to your local MCP server, which talks to Gmail. No emails sent to third-party services (beyond Google, obviously).

And you control what tools are available. Don't want AI sending emails? Don't include the send tool.

---

_What email tasks would you automate? I'm thinking auto-unsubscribe next._
