+++
title = "AI Content Writer: Blog Posts on Autopilot"
image = "images/content-writer-agent.webp"
date = 2025-11-11
description = "Build an AI content writer agent that researches topics, creates outlines, and writes SEO-optimized blog posts using MCP tools."
summary = "Stop context-switching between research tabs, outline docs, and your CMS. Build an agent that handles the entire content pipeline: researches topics across multiple sources, creates structured outlines, writes SEO-optimized drafts with proper keyword density, and publishes directly to WordPress, Ghost, or your custom CMS."
draft = false
tags = ['mcp', 'tutorial', 'content']
voice = false

[howto]
name = "Build Content Writer Agent"
totalTime = 30
[[howto.steps]]
name = "Create content tools"
text = "Build MCP tools for research, SEO analysis, and publishing."
[[howto.steps]]
name = "Implement research phase"
text = "Create prompts for topic research and outline generation."
[[howto.steps]]
name = "Build writing engine"
text = "Design the agent that writes and refines content."
[[howto.steps]]
name = "Add SEO optimization"
text = "Implement keyword research and optimization tools."
[[howto.steps]]
name = "Integrate publishing"
text = "Connect to CMS for automated publishing."
+++


Content at scale. Quality that doesn't scale down.

AI that researches, outlines, writes, and optimizes.

Here's how to build it.

## What content writers do

A content writing agent:
- Researches topics thoroughly
- Creates structured outlines
- Writes engaging content
- Optimizes for SEO
- Formats for publishing
- Maintains brand voice

## What you'll build

- Topic research and ideation
- Outline generation
- Long-form content writing
- SEO optimization
- Image suggestions
- Publishing automation

## Step 1: Create content tools

Using [Gantz](https://gantz.run):

```yaml
# gantz.yaml
name: content-writer

tools:
  - name: search_web
    description: Search the web for research
    parameters:
      - name: query
        type: string
        required: true
      - name: num_results
        type: integer
        default: 10
    script:
      shell: |
        curl -s "https://api.search.brave.com/res/v1/web/search?q={{query}}&count={{num_results}}" \
          -H "X-Subscription-Token: $BRAVE_API_KEY"

  - name: get_page_content
    description: Get content from a web page
    parameters:
      - name: url
        type: string
        required: true
    script:
      shell: |
        curl -s "{{url}}" | python -c "
        import sys
        from bs4 import BeautifulSoup
        soup = BeautifulSoup(sys.stdin.read(), 'html.parser')
        for script in soup(['script', 'style', 'nav', 'footer']):
            script.decompose()
        text = soup.get_text(separator=' ', strip=True)
        print(text[:10000])
        "

  - name: keyword_research
    description: Get keyword data and related terms
    parameters:
      - name: keyword
        type: string
        required: true
    script:
      command: python
      args: ["scripts/keyword_research.py", "{{keyword}}"]

  - name: analyze_serp
    description: Analyze top-ranking content for a keyword
    parameters:
      - name: keyword
        type: string
        required: true
    script:
      command: python
      args: ["scripts/analyze_serp.py", "{{keyword}}"]

  - name: check_readability
    description: Analyze content readability
    parameters:
      - name: content
        type: string
        required: true
    script:
      command: python
      args: ["scripts/readability.py"]
      stdin: "{{content}}"

  - name: check_plagiarism
    description: Check content for potential plagiarism
    parameters:
      - name: content
        type: string
        required: true
    script:
      command: python
      args: ["scripts/plagiarism_check.py"]
      stdin: "{{content}}"

  - name: save_draft
    description: Save content draft
    parameters:
      - name: title
        type: string
        required: true
      - name: content
        type: string
        required: true
      - name: format
        type: string
        default: "markdown"
    script:
      shell: |
        filename=$(echo "{{title}}" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd '[:alnum:]-')
        echo "{{content}}" > "drafts/${filename}.{{format}}"
        echo "Saved to drafts/${filename}.{{format}}"

  - name: publish_to_cms
    description: Publish content to the CMS
    parameters:
      - name: title
        type: string
        required: true
      - name: content
        type: string
        required: true
      - name: category
        type: string
      - name: tags
        type: string
      - name: status
        type: string
        default: "draft"
    script:
      shell: |
        curl -s -X POST "$CMS_URL/posts" \
          -H "Authorization: Bearer $CMS_TOKEN" \
          -H "Content-Type: application/json" \
          -d '{
            "title": "{{title}}",
            "content": "{{content}}",
            "category": "{{category}}",
            "tags": "{{tags}}",
            "status": "{{status}}"
          }'

  - name: get_brand_guidelines
    description: Get brand voice and style guidelines
    script:
      shell: cat config/brand_guidelines.md

  - name: get_content_calendar
    description: Get upcoming content topics from calendar
    parameters:
      - name: days
        type: integer
        default: 30
    script:
      shell: |
        curl -s "$CMS_URL/calendar?days={{days}}" \
          -H "Authorization: Bearer $CMS_TOKEN"
```

Keyword research script:

```python
# scripts/keyword_research.py
import sys
import json
import requests
import os

def get_keyword_data(keyword: str) -> dict:
    """Get keyword volume and related terms."""

    # Using DataForSEO or similar API
    # This is a simplified example
    response = requests.post(
        "https://api.dataforseo.com/v3/keywords_data/google/search_volume/live",
        auth=(os.environ["DATAFORSEO_LOGIN"], os.environ["DATAFORSEO_PASSWORD"]),
        json=[{
            "keywords": [keyword],
            "language_code": "en",
            "location_code": 2840  # US
        }]
    )

    data = response.json()

    # Get related keywords
    related_response = requests.post(
        "https://api.dataforseo.com/v3/keywords_data/google/keywords_for_keywords/live",
        auth=(os.environ["DATAFORSEO_LOGIN"], os.environ["DATAFORSEO_PASSWORD"]),
        json=[{
            "keywords": [keyword],
            "language_code": "en",
            "location_code": 2840
        }]
    )

    related_data = related_response.json()

    return {
        "keyword": keyword,
        "volume": data.get("tasks", [{}])[0].get("result", [{}])[0].get("search_volume", 0),
        "competition": data.get("tasks", [{}])[0].get("result", [{}])[0].get("competition", ""),
        "related": [
            {"keyword": r["keyword"], "volume": r.get("search_volume", 0)}
            for r in related_data.get("tasks", [{}])[0].get("result", [])[:20]
        ]
    }

if __name__ == "__main__":
    keyword = sys.argv[1]
    result = get_keyword_data(keyword)
    print(json.dumps(result, indent=2))
```

```bash
gantz run --auth
```

## Step 2: The content writer agent

```python
import anthropic
from typing import List, Optional

MCP_URL = "https://content-writer.gantz.run/sse"
MCP_TOKEN = "gtz_abc123"

client = anthropic.Anthropic()

WRITER_SYSTEM_PROMPT = """You are an expert content writer.

Your writing is:
- Engaging and readable
- Well-researched and accurate
- SEO-optimized but natural
- Structured with clear headings
- Actionable and valuable to readers

Process for each piece:
1. Research thoroughly before writing
2. Create a detailed outline
3. Write in a conversational tone
4. Include examples and data
5. Optimize for target keywords
6. Add calls-to-action

Writing style:
- Short paragraphs (2-3 sentences)
- Active voice
- Specific, not vague
- Show, don't tell
- Use bullet points for lists
- Include relevant statistics

SEO guidelines:
- Keyword in title, H1, first paragraph
- Related keywords throughout naturally
- Internal and external links
- Meta description under 160 chars
- Image alt text
- Readable URL slug"""

def research_topic(topic: str) -> str:
    """Research a topic before writing."""

    response = client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=4096,
        system=WRITER_SYSTEM_PROMPT,
        messages=[{
            "role": "user",
            "content": f"""Research the topic: {topic}

1. Use keyword_research to find:
   - Search volume
   - Competition level
   - Related keywords to include

2. Use search_web to find:
   - Recent articles on this topic
   - Statistics and data
   - Expert opinions
   - Common questions people ask

3. Use analyze_serp to understand:
   - What top-ranking content covers
   - Average word count
   - Content gaps we can fill

4. Summarize research findings:
   - Key points to cover
   - Data/stats to include
   - Unique angle we can take
   - Target keywords (primary + secondary)"""
        }],
        tools=[{"type": "mcp", "server_url": MCP_URL, "token": MCP_TOKEN}]
    )

    for content in response.content:
        if hasattr(content, 'text'):
            return content.text

    return ""

def create_outline(topic: str, research: str) -> str:
    """Create a detailed outline for content."""

    response = client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=2048,
        system=WRITER_SYSTEM_PROMPT,
        messages=[{
            "role": "user",
            "content": f"""Create an outline for: {topic}

Research findings:
{research}

Create a detailed outline including:

1. **Title options** (3 variations, include primary keyword)

2. **Meta description** (under 160 chars, include keyword)

3. **Introduction**
   - Hook
   - Problem/opportunity
   - What reader will learn

4. **Main sections** (H2 headings)
   - For each section:
     - Key points (H3 if needed)
     - Examples/data to include
     - Internal link opportunities

5. **Conclusion**
   - Summary
   - Call-to-action

6. **SEO checklist**
   - Primary keyword placement
   - Secondary keywords to include
   - Suggested images

Target word count: 1500-2000 words"""
        }]
    )

    for content in response.content:
        if hasattr(content, 'text'):
            return content.text

    return ""

def write_content(topic: str, outline: str) -> str:
    """Write the full content from outline."""

    response = client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=8192,
        system=WRITER_SYSTEM_PROMPT,
        messages=[{
            "role": "user",
            "content": f"""Write the full article for: {topic}

Follow this outline:
{outline}

Guidelines:
1. Use get_brand_guidelines to match our voice
2. Write engaging, valuable content
3. Include all planned sections
4. Add relevant examples
5. Incorporate keywords naturally
6. Use formatting (headers, bullets, bold)

Format as Markdown with:
- Title as H1
- Sections as H2
- Subsections as H3
- Code blocks where relevant
- Bullet/numbered lists
- Bold for emphasis

After writing, use check_readability to verify the content is accessible."""
        }],
        tools=[{"type": "mcp", "server_url": MCP_URL, "token": MCP_TOKEN}]
    )

    for content in response.content:
        if hasattr(content, 'text'):
            return content.text

    return ""
```

## Step 3: Content optimization

```python
def optimize_content(content: str, target_keyword: str) -> str:
    """Optimize content for SEO."""

    response = client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=8192,
        system="""You optimize content for SEO while maintaining readability.

        Focus on:
        - Keyword placement (title, H1, intro, headings)
        - Keyword density (1-2%, not stuffed)
        - Related keywords (LSI terms)
        - Readability (short sentences, simple words)
        - Structure (proper heading hierarchy)
        - Engagement (questions, calls-to-action)""",
        messages=[{
            "role": "user",
            "content": f"""Optimize this content for: {target_keyword}

Content:
{content}

Steps:
1. Check current keyword usage
2. Identify missing SEO elements
3. Improve without over-optimizing
4. Verify readability with check_readability
5. Output the optimized content

Preserve the original voice and quality."""
        }],
        tools=[{"type": "mcp", "server_url": MCP_URL, "token": MCP_TOKEN}]
    )

    for content in response.content:
        if hasattr(content, 'text'):
            return content.text

    return ""

def generate_meta(content: str, keyword: str) -> dict:
    """Generate meta title and description."""

    response = client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=512,
        messages=[{
            "role": "user",
            "content": f"""Generate SEO meta tags for this content.
            Target keyword: {keyword}

            Content:
            {content[:2000]}

            Generate:
            1. Meta title (under 60 chars, keyword near start)
            2. Meta description (under 160 chars, keyword included, compelling)
            3. URL slug (lowercase, hyphens, keyword)
            4. 5 relevant tags

            Output as JSON."""
        }]
    )

    for c in response.content:
        if hasattr(c, 'text'):
            import json
            return json.loads(c.text)

    return {}

def suggest_images(content: str) -> str:
    """Suggest images for the content."""

    response = client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=1024,
        messages=[{
            "role": "user",
            "content": f"""Suggest images for this content:

{content[:3000]}

For each suggested image:
1. Placement (after which section)
2. Description of what it should show
3. Alt text (include keyword if natural)
4. Whether to use stock photo, custom graphic, or screenshot

Suggest 3-5 images total."""
        }]
    )

    for c in response.content:
        if hasattr(c, 'text'):
            return c.text

    return ""
```

## Step 4: Content pipeline

```python
def full_content_pipeline(topic: str, auto_publish: bool = False) -> dict:
    """Run the full content creation pipeline."""

    print(f"Starting content pipeline for: {topic}")

    # Step 1: Research
    print("📚 Researching topic...")
    research = research_topic(topic)

    # Step 2: Outline
    print("📝 Creating outline...")
    outline = create_outline(topic, research)

    # Step 3: Write
    print("✍️ Writing content...")
    content = write_content(topic, outline)

    # Step 4: Optimize
    print("🔍 Optimizing for SEO...")
    keyword = extract_primary_keyword(research)
    optimized = optimize_content(content, keyword)

    # Step 5: Generate meta
    print("🏷️ Generating meta tags...")
    meta = generate_meta(optimized, keyword)

    # Step 6: Image suggestions
    print("🖼️ Suggesting images...")
    images = suggest_images(optimized)

    # Step 7: Quality checks
    print("✅ Running quality checks...")
    checks = run_quality_checks(optimized)

    result = {
        "topic": topic,
        "keyword": keyword,
        "content": optimized,
        "meta": meta,
        "images": images,
        "checks": checks
    }

    # Step 8: Save or publish
    if auto_publish and checks["passed"]:
        print("🚀 Publishing...")
        publish_content(result)
    else:
        print("💾 Saving draft...")
        save_draft_content(result)

    return result

def extract_primary_keyword(research: str) -> str:
    """Extract the primary target keyword from research."""
    # Simple extraction - in production, parse the research output
    response = client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=100,
        messages=[{
            "role": "user",
            "content": f"Extract the single primary target keyword from this research:\n{research[:1000]}\n\nOutput only the keyword."
        }]
    )

    for c in response.content:
        if hasattr(c, 'text'):
            return c.text.strip()

    return ""

def run_quality_checks(content: str) -> dict:
    """Run quality checks on content."""

    response = client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=2048,
        messages=[{
            "role": "user",
            "content": f"""Run quality checks on this content:

{content}

Check:
1. Grammar and spelling errors
2. Readability score (target: 8th grade)
3. Keyword stuffing (flag if >3%)
4. Factual claims (note any that need verification)
5. Broken structure (missing sections, orphan headings)
6. Length (target: 1500-2000 words)

Output JSON with:
- passed: boolean
- issues: list of issues found
- suggestions: list of improvements"""
        }],
        tools=[{"type": "mcp", "server_url": MCP_URL, "token": MCP_TOKEN}]
    )

    for c in response.content:
        if hasattr(c, 'text'):
            import json
            try:
                return json.loads(c.text)
            except:
                return {"passed": True, "issues": [], "suggestions": []}

    return {"passed": True, "issues": [], "suggestions": []}

def save_draft_content(result: dict):
    """Save content as draft."""
    # Implementation using save_draft tool
    pass

def publish_content(result: dict):
    """Publish content to CMS."""
    # Implementation using publish_to_cms tool
    pass
```

## Step 5: CLI and batch processing

```python
#!/usr/bin/env python3
"""Content Writer CLI."""

import argparse
import json

def main():
    parser = argparse.ArgumentParser(description="AI Content Writer")
    subparsers = parser.add_subparsers(dest="command", help="Commands")

    # Research
    research_parser = subparsers.add_parser("research", help="Research a topic")
    research_parser.add_argument("topic", help="Topic to research")

    # Outline
    outline_parser = subparsers.add_parser("outline", help="Create outline")
    outline_parser.add_argument("topic", help="Topic")

    # Write
    write_parser = subparsers.add_parser("write", help="Write content")
    write_parser.add_argument("topic", help="Topic")
    write_parser.add_argument("--output", "-o", help="Output file")

    # Pipeline
    pipeline_parser = subparsers.add_parser("pipeline", help="Full pipeline")
    pipeline_parser.add_argument("topic", help="Topic")
    pipeline_parser.add_argument("--publish", action="store_true", help="Auto-publish")

    # Batch
    batch_parser = subparsers.add_parser("batch", help="Batch process topics")
    batch_parser.add_argument("file", help="File with topics (one per line)")
    batch_parser.add_argument("--output-dir", "-o", default="output")

    # Calendar
    calendar_parser = subparsers.add_parser("calendar", help="Process content calendar")
    calendar_parser.add_argument("--days", "-d", type=int, default=7)

    args = parser.parse_args()

    if args.command == "research":
        result = research_topic(args.topic)
        print(result)

    elif args.command == "outline":
        research = research_topic(args.topic)
        result = create_outline(args.topic, research)
        print(result)

    elif args.command == "write":
        research = research_topic(args.topic)
        outline = create_outline(args.topic, research)
        content = write_content(args.topic, outline)

        if args.output:
            with open(args.output, "w") as f:
                f.write(content)
            print(f"Saved to {args.output}")
        else:
            print(content)

    elif args.command == "pipeline":
        result = full_content_pipeline(args.topic, args.publish)
        print(json.dumps(result, indent=2))

    elif args.command == "batch":
        import os
        os.makedirs(args.output_dir, exist_ok=True)

        with open(args.file) as f:
            topics = [line.strip() for line in f if line.strip()]

        for i, topic in enumerate(topics, 1):
            print(f"\n[{i}/{len(topics)}] Processing: {topic}")
            result = full_content_pipeline(topic)

            filename = topic.lower().replace(" ", "-")[:50]
            with open(f"{args.output_dir}/{filename}.json", "w") as f:
                json.dump(result, f, indent=2)

    elif args.command == "calendar":
        # Get topics from content calendar and process
        response = client.messages.create(
            model="claude-sonnet-4-20250514",
            max_tokens=1024,
            messages=[{
                "role": "user",
                "content": f"Use get_content_calendar with days={args.days} and list the upcoming topics."
            }],
            tools=[{"type": "mcp", "server_url": MCP_URL, "token": MCP_TOKEN}]
        )

        for c in response.content:
            if hasattr(c, 'text'):
                print(c.text)

    else:
        parser.print_help()

if __name__ == "__main__":
    main()
```

Usage:

```bash
# Research a topic
./writer.py research "best practices for API design"

# Create an outline
./writer.py outline "REST API authentication methods"

# Write full content
./writer.py write "microservices vs monolith" --output article.md

# Full pipeline with auto-publish
./writer.py pipeline "kubernetes security best practices" --publish

# Batch process multiple topics
./writer.py batch topics.txt --output-dir articles/

# Process content calendar
./writer.py calendar --days 7
```

## Summary

Building an AI content writer:

1. **Research tools** for topic analysis and keyword data
2. **Outline generation** for structured content
3. **Writing engine** with brand voice consistency
4. **SEO optimization** for search visibility
5. **Publishing integration** for workflow automation

Build tools with [Gantz](https://gantz.run), scale content creation.

Quality content at scale. Finally possible.

## Related reading

- [Research Assistant AI](/post/research-assistant/) - Research automation
- [Auto-Generate Documentation](/post/documentation-agents/) - Doc generation
- [Build a Translation Agent](/post/translation-agent/) - Multi-language content

---

*How do you scale content creation? Share your approach.*
