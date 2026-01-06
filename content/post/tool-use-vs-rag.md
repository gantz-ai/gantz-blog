+++
title = "Tool Use vs RAG: picking the right approach"
date = 2025-11-20
description = "When to use RAG vs Tool Use in AI applications. RAG retrieves knowledge, Tool Use executes actions. Decision framework with practical examples."
image = "images/warrior-rain-city-09.webp"
draft = false
tags = ['tool-use', 'rag', 'comparison']
+++


Two ways to make AI smarter: give it knowledge (RAG) or give it abilities (Tool Use).

I see people pick the wrong one all the time. Let's clear this up.

## What RAG does

RAG (Retrieval Augmented Generation) gives AI access to knowledge.

```
User: "What's our refund policy?"

System:
1. Search knowledge base for "refund policy"
2. Find relevant documents
3. Inject into AI context
4. AI answers based on retrieved content

AI: "According to our policy, refunds are available within 30 days..."
```

RAG is about **knowing things**. You have documents, and AI needs to reference them.

## What Tool Use does

Tool Use gives AI the ability to take actions.

```
User: "Process a refund for order #123"

System:
1. AI decides to call refund_order tool
2. Tool executes against real systems
3. Refund is actually processed
4. AI confirms completion

AI: "Done. I've processed a $49.99 refund for order #123."
```

Tool Use is about **doing things**. You have systems, and AI needs to interact with them.

## The core difference

| | RAG | Tool Use |
|---|---|---|
| Purpose | Answer questions | Take actions |
| Data flow | Documents → AI | AI → External systems |
| Output | Information | Effects |
| Example | "What is X?" | "Do X" |

**RAG** = AI reads stuff
**Tool Use** = AI does stuff

## When to use RAG

### You have static knowledge

Company policies, documentation, historical data, FAQs.

```
User: "What are the system requirements?"
→ RAG retrieves from docs
→ AI summarizes requirements
```

### Answers exist in documents

The information already exists somewhere. AI just needs to find and present it.

```
User: "What did we decide in last month's meeting?"
→ RAG retrieves meeting notes
→ AI extracts the decision
```

### No action needed

User wants information, not changes. Read-only.

```
User: "How do I configure the API?"
→ RAG retrieves setup guide
→ AI explains the steps
```

### Volume of context

You have more documents than fit in context. RAG retrieves only relevant parts.

```
User: "Find the section about authentication"
→ RAG searches 1000 pages
→ Returns the 2 relevant pages
→ AI answers from those
```

## When to use Tool Use

### Real-time data needed

Information changes constantly. Documents would be stale.

```
User: "What's my account balance?"
→ Tool calls banking API
→ Returns current balance
```

### Actions required

User wants something to happen, not just information.

```
User: "Send an email to the team"
→ Tool composes and sends email
→ Email actually goes out
```

### Computation needed

The answer requires calculation or processing.

```
User: "How much would 15% discount save on my cart?"
→ Tool fetches cart total
→ Tool calculates discount
→ Returns computed savings
```

### External systems

Data lives in databases, APIs, or services — not documents.

```
User: "Show me orders from last week"
→ Tool queries database
→ Returns live results
```

## Use both together

Often, you need both. This is where it gets powerful.

**Example: Customer support bot**

```
User: "I want to return this item. What's the process and can you start it?"

Step 1 - RAG:
→ Retrieves return policy
→ AI explains the 30-day window, conditions, etc.

Step 2 - Tool Use:
→ AI calls get_order tool to check purchase date
→ Confirms item is eligible

Step 3 - Tool Use:
→ AI calls initiate_return tool
→ Return process started

AI: "Your item qualifies for return (purchased 12 days ago).
I've initiated the return — you'll receive a shipping label via email."
```

RAG provided the policy knowledge. Tools took the action.

**Example: Research assistant**

```
User: "Find recent papers on transformer efficiency and summarize the key findings"

Step 1 - Tool Use:
→ AI calls search_arxiv tool
→ Finds 10 recent papers

Step 2 - RAG:
→ Papers loaded into context
→ AI reads and analyzes

Step 3 - Tool Use:
→ AI calls save_summary tool
→ Saves the analysis

AI: "I found 10 papers from the last month. Key findings:
1. Sparse attention reduces compute by 40%...
[Summary saved to your notes]"
```

Tools did the searching and saving. RAG handled the reading.

## Decision framework

Ask yourself:

### 1. Does the answer exist in documents?

**Yes** → RAG
**No** → Tool Use

### 2. Does the user want information or action?

**Information** → Probably RAG
**Action** → Tool Use

### 3. Is the data static or dynamic?

**Static** (rarely changes) → RAG
**Dynamic** (changes frequently) → Tool Use

### 4. Is reading enough, or does something need to happen?

**Reading** → RAG
**Something happens** → Tool Use

## Quick reference

| User wants... | Use |
|--------------|-----|
| "What is our policy on X?" | RAG |
| "Update my policy to X" | Tool Use |
| "Explain how Y works" | RAG |
| "Make Y do Z" | Tool Use |
| "Find information about X" | RAG (or Tool for live data) |
| "Create/Send/Delete X" | Tool Use |
| "What did document say about X?" | RAG |
| "What is the current X?" | Tool Use |

## Common mistakes

### Mistake 1: RAG for live data

```
User: "What's the stock price of Apple?"

Wrong: RAG over old financial documents
Right: Tool that calls stock API
```

RAG can't give you real-time data. It only knows what's in your documents.

### Mistake 2: Tool Use for static knowledge

```
User: "What are your business hours?"

Wrong: Tool that queries a database
Right: RAG over FAQ document
```

Don't over-engineer. If it's in a document, use RAG.

### Mistake 3: Only using one

Most real applications need both.

- Support bot: RAG for policies + Tools for actions
- Research assistant: Tools for search + RAG for reading
- Business assistant: RAG for docs + Tools for data

### Mistake 4: RAG for tiny context

If your entire knowledge base fits in context, you might not need RAG.

```
# If you only have 10 pages of docs
# Just include them in the system prompt
# No retrieval needed
```

RAG adds complexity. Only use it when you have too much to fit in context.

## Implementation

### RAG stack

```
Documents → Chunking → Embeddings → Vector DB → Retrieval → AI
```

Tools: Pinecone, Weaviate, Chroma, pgvector

### Tool Use stack

```
AI → MCP/Function Calling → Tool Server → External Systems
```

Tools: [Gantz](https://gantz.run), LangChain, custom MCP servers

### Both together

```
┌─────────────────────────────────────┐
│              AI Agent               │
├─────────────────────────────────────┤
│                                     │
│   ┌─────────────┐ ┌─────────────┐   │
│   │    RAG      │ │  Tool Use   │   │
│   │             │ │             │   │
│   │  Knowledge  │ │   Actions   │   │
│   │  retrieval  │ │  execution  │   │
│   └──────┬──────┘ └──────┬──────┘   │
│          │               │          │
└──────────┼───────────────┼──────────┘
           │               │
           ▼               ▼
    ┌────────────┐  ┌────────────┐
    │ Vector DB  │  │ MCP Server │
    │ (Docs)     │  │ (Tools)    │
    └────────────┘  └────────────┘
```

## Summary

**Use RAG when:**
- Information exists in documents
- User wants to know things
- Data is static
- Reading is enough

**Use Tool Use when:**
- Data is live/real-time
- User wants actions taken
- External systems involved
- Something needs to happen

**Use both when:**
- Complex workflows
- Knowledge + action needed
- Real-world applications

Don't overthink it. Start with what the user needs:

- Need to know? → RAG
- Need to do? → Tools
- Need both? → Use both

## Related reading

- [RAG Is Overrated for Most Use Cases](/post/rag-overrated/) - When simpler solutions work
- [Full-Text Search: The RAG Alternative Nobody Tries](/post/fulltext-search/) - Alternative retrieval methods
- [Build a Local RAG Pipeline with MCP](/post/local-rag-mcp/) - Practical RAG implementation

---

*How do you decide between RAG and tools in your projects?*
