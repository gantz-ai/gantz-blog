+++
title = "Research Assistant AI: Automate Literature Reviews"
image = "images/research-assistant.webp"
date = 2025-11-10
description = "Build an AI research assistant that searches papers, summarizes findings, and compiles literature reviews automatically using MCP tools."
summary = "Literature reviews take weeks manually. Build an AI assistant that searches academic databases, filters relevant papers, extracts key findings and methodologies, identifies research gaps, and compiles everything into coherent reviews with proper citations. Includes PDF parsing tools and prompts for accurate summarization."
draft = false
tags = ['mcp', 'tutorial', 'research']
voice = false

[howto]
name = "Build Research Assistant"
totalTime = 35
[[howto.steps]]
name = "Create research tools"
text = "Build MCP tools for paper search, PDF parsing, and citation management."
[[howto.steps]]
name = "Implement paper discovery"
text = "Search academic databases and filter relevant papers."
[[howto.steps]]
name = "Build summarization"
text = "Create prompts for extracting key findings from papers."
[[howto.steps]]
name = "Generate reviews"
text = "Compile findings into coherent literature reviews."
[[howto.steps]]
name = "Add citation management"
text = "Track sources and generate properly formatted citations."
+++


Literature reviews take weeks.

Reading papers. Taking notes. Synthesizing findings.

An AI assistant can do the heavy lifting.

## What research assistants do

- Search academic databases
- Filter relevant papers
- Extract key findings
- Summarize methodologies
- Identify research gaps
- Compile literature reviews
- Generate citations

## The value proposition

**Without AI:**
- Search papers manually
- Skim abstracts one by one
- Read full papers (hours each)
- Take notes in scattered documents
- Write synthesis from scratch

**With AI:**
- Automated paper discovery
- Batch abstract analysis
- Key finding extraction
- Organized note compilation
- Structured review generation

Same quality, fraction of the time.

## Step 1: Create research tools

Using [Gantz](https://gantz.run):

```yaml
# gantz.yaml
name: research-assistant

tools:
  - name: search_papers
    description: Search academic papers on a topic
    parameters:
      - name: query
        type: string
        required: true
        description: Search query
      - name: source
        type: string
        default: "semantic_scholar"
        description: "semantic_scholar, arxiv, pubmed"
      - name: limit
        type: integer
        default: 20
      - name: year_from
        type: integer
        description: Filter papers from this year
    script:
      command: python
      args: ["scripts/search_papers.py", "{{query}}", "{{source}}", "{{limit}}", "{{year_from}}"]

  - name: get_paper_details
    description: Get full details of a specific paper
    parameters:
      - name: paper_id
        type: string
        required: true
        description: Paper ID (DOI, arXiv ID, etc.)
    script:
      command: python
      args: ["scripts/get_paper.py", "{{paper_id}}"]

  - name: download_pdf
    description: Download paper PDF if available
    parameters:
      - name: paper_id
        type: string
        required: true
      - name: output_path
        type: string
        default: "papers/"
    script:
      command: python
      args: ["scripts/download_pdf.py", "{{paper_id}}", "{{output_path}}"]

  - name: extract_pdf_text
    description: Extract text content from a PDF
    parameters:
      - name: pdf_path
        type: string
        required: true
    script:
      command: python
      args: ["scripts/extract_pdf.py", "{{pdf_path}}"]

  - name: get_citations
    description: Get papers that cite a given paper
    parameters:
      - name: paper_id
        type: string
        required: true
      - name: limit
        type: integer
        default: 10
    script:
      command: python
      args: ["scripts/get_citations.py", "{{paper_id}}", "{{limit}}"]

  - name: get_references
    description: Get papers referenced by a given paper
    parameters:
      - name: paper_id
        type: string
        required: true
    script:
      command: python
      args: ["scripts/get_references.py", "{{paper_id}}"]

  - name: save_note
    description: Save research note to database
    parameters:
      - name: paper_id
        type: string
        required: true
      - name: note_type
        type: string
        required: true
        description: "summary, finding, method, limitation, quote"
      - name: content
        type: string
        required: true
    script:
      command: python
      args: ["scripts/save_note.py", "{{paper_id}}", "{{note_type}}", "{{content}}"]

  - name: get_notes
    description: Get all notes for a paper or topic
    parameters:
      - name: paper_id
        type: string
      - name: topic
        type: string
    script:
      command: python
      args: ["scripts/get_notes.py", "{{paper_id}}", "{{topic}}"]

  - name: format_citation
    description: Format a citation in a specific style
    parameters:
      - name: paper_id
        type: string
        required: true
      - name: style
        type: string
        default: "apa"
        description: "apa, mla, chicago, harvard"
    script:
      command: python
      args: ["scripts/format_citation.py", "{{paper_id}}", "{{style}}"]
```

Paper search script:

```python
# scripts/search_papers.py
import sys
import json
import requests

def search_semantic_scholar(query: str, limit: int = 20, year_from: int = None) -> list:
    """Search Semantic Scholar API."""

    url = "https://api.semanticscholar.org/graph/v1/paper/search"
    params = {
        "query": query,
        "limit": limit,
        "fields": "paperId,title,abstract,year,authors,citationCount,url,openAccessPdf"
    }

    if year_from:
        params["year"] = f"{year_from}-"

    response = requests.get(url, params=params)
    data = response.json()

    return [{
        "id": p["paperId"],
        "title": p["title"],
        "abstract": p.get("abstract", ""),
        "year": p.get("year"),
        "authors": [a["name"] for a in p.get("authors", [])],
        "citations": p.get("citationCount", 0),
        "url": p.get("url"),
        "pdf_url": p.get("openAccessPdf", {}).get("url") if p.get("openAccessPdf") else None
    } for p in data.get("data", [])]

def search_arxiv(query: str, limit: int = 20) -> list:
    """Search arXiv API."""
    import urllib.parse

    base_url = "http://export.arxiv.org/api/query"
    params = {
        "search_query": f"all:{query}",
        "max_results": limit,
        "sortBy": "relevance"
    }

    response = requests.get(base_url, params=params)

    # Parse XML response
    import xml.etree.ElementTree as ET
    root = ET.fromstring(response.text)

    papers = []
    for entry in root.findall("{http://www.w3.org/2005/Atom}entry"):
        papers.append({
            "id": entry.find("{http://www.w3.org/2005/Atom}id").text.split("/")[-1],
            "title": entry.find("{http://www.w3.org/2005/Atom}title").text.strip(),
            "abstract": entry.find("{http://www.w3.org/2005/Atom}summary").text.strip(),
            "authors": [a.find("{http://www.w3.org/2005/Atom}name").text
                       for a in entry.findall("{http://www.w3.org/2005/Atom}author")],
            "url": entry.find("{http://www.w3.org/2005/Atom}id").text,
            "pdf_url": entry.find("{http://www.w3.org/2005/Atom}id").text.replace("abs", "pdf")
        })

    return papers

if __name__ == "__main__":
    query = sys.argv[1]
    source = sys.argv[2] if len(sys.argv) > 2 else "semantic_scholar"
    limit = int(sys.argv[3]) if len(sys.argv) > 3 else 20
    year_from = int(sys.argv[4]) if len(sys.argv) > 4 and sys.argv[4] else None

    if source == "semantic_scholar":
        results = search_semantic_scholar(query, limit, year_from)
    elif source == "arxiv":
        results = search_arxiv(query, limit)
    else:
        results = []

    print(json.dumps(results, indent=2))
```

```bash
gantz run --auth
```

## Step 2: The research agent

```python
import anthropic
from typing import List, Optional
import json

MCP_URL = "https://research-assistant.gantz.run/sse"
MCP_TOKEN = "gtz_abc123"

client = anthropic.Anthropic()

RESEARCH_SYSTEM_PROMPT = """You are a research assistant helping with academic literature reviews.

Your responsibilities:
1. **Paper discovery**: Find relevant papers based on research questions
2. **Critical reading**: Extract key findings, methods, and limitations
3. **Synthesis**: Identify patterns and connections across papers
4. **Gap analysis**: Note what's missing in the literature
5. **Writing support**: Help structure and write reviews

Guidelines:
- Be thorough but efficient
- Cite sources properly
- Distinguish between findings and interpretations
- Note methodological strengths and weaknesses
- Identify consensus and disagreements in the field
- Suggest follow-up papers based on citations

Output format:
- Use clear headings and bullet points
- Include paper titles and authors when referencing
- Provide page numbers for specific quotes
- Note confidence levels for your interpretations"""

def search_literature(topic: str, num_papers: int = 20, year_from: int = None) -> str:
    """Search for papers on a topic."""

    response = client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=4096,
        system=RESEARCH_SYSTEM_PROMPT,
        messages=[{
            "role": "user",
            "content": f"""Find relevant papers on: {topic}

1. Use search_papers to find {num_papers} papers{f' from {year_from} onwards' if year_from else ''}
2. Review the abstracts
3. Filter to the most relevant papers
4. For each relevant paper, note:
   - Why it's relevant
   - Key contribution (from abstract)
   - Citation count (indicator of influence)
5. Suggest additional search terms if needed"""
        }],
        tools=[{"type": "mcp", "server_url": MCP_URL, "token": MCP_TOKEN}]
    )

    for content in response.content:
        if hasattr(content, 'text'):
            return content.text

    return ""

def analyze_paper(paper_id: str) -> str:
    """Deep analysis of a specific paper."""

    response = client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=4096,
        system=RESEARCH_SYSTEM_PROMPT,
        messages=[{
            "role": "user",
            "content": f"""Analyze paper {paper_id} in detail.

1. Use get_paper_details for metadata
2. Use download_pdf and extract_pdf_text to get full content
3. Analyze and extract:

**Summary**
- Main research question
- Key argument/thesis
- Main findings

**Methodology**
- Research design
- Data sources
- Analysis methods
- Sample size/scope

**Key Findings**
- Primary results
- Supporting evidence
- Statistical significance if applicable

**Limitations**
- Acknowledged by authors
- Potential issues you identify

**Relevance**
- How this connects to other work
- Implications for the field

4. Use save_note to store key findings for later compilation"""
        }],
        tools=[{"type": "mcp", "server_url": MCP_URL, "token": MCP_TOKEN}]
    )

    for content in response.content:
        if hasattr(content, 'text'):
            return content.text

    return ""

def compare_papers(paper_ids: List[str]) -> str:
    """Compare multiple papers on similar topics."""

    papers_list = ", ".join(paper_ids)

    response = client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=4096,
        system=RESEARCH_SYSTEM_PROMPT,
        messages=[{
            "role": "user",
            "content": f"""Compare these papers: {papers_list}

For each paper, use get_paper_details to get information.

Then compare:

**Research Questions**
- How do the questions differ?
- What's the common thread?

**Methodological Approaches**
- Different methods used
- Strengths of each approach

**Findings**
- Where do they agree?
- Where do they disagree?
- How might differences be explained?

**Evolution of Thinking**
- How has understanding evolved across these papers?
- What newer papers add to older ones

Create a comparison table and narrative summary."""
        }],
        tools=[{"type": "mcp", "server_url": MCP_URL, "token": MCP_TOKEN}]
    )

    for content in response.content:
        if hasattr(content, 'text'):
            return content.text

    return ""
```

## Step 3: Literature review generator

```python
def generate_literature_review(topic: str, aspects: List[str] = None) -> str:
    """Generate a full literature review."""

    aspects_text = ", ".join(aspects) if aspects else "all relevant aspects"

    response = client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=8192,
        system=RESEARCH_SYSTEM_PROMPT,
        messages=[{
            "role": "user",
            "content": f"""Generate a literature review on: {topic}

Focus on: {aspects_text}

Steps:
1. Use search_papers to find relevant papers (try multiple queries)
2. For the most important papers, use get_paper_details
3. Use get_notes to retrieve any existing notes
4. Use get_citations and get_references for seminal papers to find more

Structure the review:
1. **Introduction**
   - Context and importance
   - Scope of the review
   - Key questions addressed

2. **Background**
   - Historical development
   - Key concepts and definitions
   - Theoretical frameworks

3. **Thematic Analysis** (organize by themes, not chronologically)
   - Theme 1: [findings, debates, evidence]
   - Theme 2: [findings, debates, evidence]
   - etc.

4. **Methodological Review**
   - Common approaches
   - Emerging methods
   - Methodological challenges

5. **Discussion**
   - Synthesis of findings
   - Patterns and trends
   - Contradictions and debates

6. **Gaps and Future Directions**
   - What's missing?
   - Promising areas for research
   - Methodological improvements needed

7. **Conclusion**
   - Key takeaways
   - Implications for practice/theory

8. **References**
   - Use format_citation for all cited works

Use save_note throughout to store key findings."""
        }],
        tools=[{"type": "mcp", "server_url": MCP_URL, "token": MCP_TOKEN}]
    )

    for content in response.content:
        if hasattr(content, 'text'):
            return content.text

    return ""

def identify_research_gaps(topic: str) -> str:
    """Identify gaps in the current research."""

    response = client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=2048,
        system=RESEARCH_SYSTEM_PROMPT,
        messages=[{
            "role": "user",
            "content": f"""Identify research gaps in: {topic}

1. Search for papers in this area
2. Analyze what's been studied
3. Identify:
   - Understudied populations or contexts
   - Methodological limitations across studies
   - Unanswered questions
   - Conflicting findings needing resolution
   - Emerging areas not yet well-covered

For each gap:
- Describe the gap
- Explain why it matters
- Suggest how it could be addressed
- Rate importance (high/medium/low)"""
        }],
        tools=[{"type": "mcp", "server_url": MCP_URL, "token": MCP_TOKEN}]
    )

    for content in response.content:
        if hasattr(content, 'text'):
            return content.text

    return ""
```

## Step 4: Citation network analysis

```python
def analyze_citation_network(seed_paper_id: str, depth: int = 2) -> str:
    """Analyze the citation network around a paper."""

    response = client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=4096,
        system=RESEARCH_SYSTEM_PROMPT,
        messages=[{
            "role": "user",
            "content": f"""Analyze the citation network around paper {seed_paper_id}.

1. Get details of the seed paper
2. Use get_citations to find papers citing it
3. Use get_references to find papers it cites
4. For highly-cited references/citations, repeat to depth {depth}

Identify:
- **Foundational papers**: Highly cited references that everyone builds on
- **Key developments**: Important subsequent work
- **Research streams**: Different directions the work has gone
- **Recent activity**: Latest papers building on this work

Create a narrative map of how this research area has developed.
Note any surprising connections or gaps in the network."""
        }],
        tools=[{"type": "mcp", "server_url": MCP_URL, "token": MCP_TOKEN}]
    )

    for content in response.content:
        if hasattr(content, 'text'):
            return content.text

    return ""

def find_seminal_papers(topic: str) -> str:
    """Find the most influential papers in a field."""

    response = client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=2048,
        system=RESEARCH_SYSTEM_PROMPT,
        messages=[{
            "role": "user",
            "content": f"""Find seminal/foundational papers on: {topic}

1. Search for papers, sorting by citation count
2. For highly-cited papers, analyze:
   - Why it's influential
   - Key contribution
   - How it shaped the field
3. Distinguish between:
   - Foundational theory papers
   - Methodological innovations
   - Empirical breakthroughs
   - Comprehensive reviews

List the essential readings for someone entering this field."""
        }],
        tools=[{"type": "mcp", "server_url": MCP_URL, "token": MCP_TOKEN}]
    )

    for content in response.content:
        if hasattr(content, 'text'):
            return content.text

    return ""
```

## Step 5: CLI tool

```python
#!/usr/bin/env python3
"""Research Assistant CLI."""

import argparse

def main():
    parser = argparse.ArgumentParser(description="AI Research Assistant")
    subparsers = parser.add_subparsers(dest="command", help="Commands")

    # Search
    search_parser = subparsers.add_parser("search", help="Search for papers")
    search_parser.add_argument("topic", help="Search topic")
    search_parser.add_argument("--limit", "-n", type=int, default=20)
    search_parser.add_argument("--year", "-y", type=int, help="Year from")

    # Analyze
    analyze_parser = subparsers.add_parser("analyze", help="Analyze a paper")
    analyze_parser.add_argument("paper_id", help="Paper ID")

    # Compare
    compare_parser = subparsers.add_parser("compare", help="Compare papers")
    compare_parser.add_argument("paper_ids", nargs="+", help="Paper IDs")

    # Review
    review_parser = subparsers.add_parser("review", help="Generate literature review")
    review_parser.add_argument("topic", help="Review topic")
    review_parser.add_argument("--aspects", "-a", nargs="+", help="Aspects to focus on")
    review_parser.add_argument("--output", "-o", help="Output file")

    # Gaps
    gaps_parser = subparsers.add_parser("gaps", help="Identify research gaps")
    gaps_parser.add_argument("topic", help="Topic")

    # Citations
    cite_parser = subparsers.add_parser("citations", help="Analyze citation network")
    cite_parser.add_argument("paper_id", help="Seed paper ID")
    cite_parser.add_argument("--depth", "-d", type=int, default=2)

    # Seminal
    seminal_parser = subparsers.add_parser("seminal", help="Find seminal papers")
    seminal_parser.add_argument("topic", help="Topic")

    args = parser.parse_args()

    if args.command == "search":
        result = search_literature(args.topic, args.limit, args.year)
        print(result)

    elif args.command == "analyze":
        result = analyze_paper(args.paper_id)
        print(result)

    elif args.command == "compare":
        result = compare_papers(args.paper_ids)
        print(result)

    elif args.command == "review":
        result = generate_literature_review(args.topic, args.aspects)
        if args.output:
            with open(args.output, "w") as f:
                f.write(result)
            print(f"Review saved to {args.output}")
        else:
            print(result)

    elif args.command == "gaps":
        result = identify_research_gaps(args.topic)
        print(result)

    elif args.command == "citations":
        result = analyze_citation_network(args.paper_id, args.depth)
        print(result)

    elif args.command == "seminal":
        result = find_seminal_papers(args.topic)
        print(result)

    else:
        parser.print_help()

if __name__ == "__main__":
    main()
```

Usage:

```bash
# Search for papers
./research.py search "transformer attention mechanisms" --year 2020

# Analyze a specific paper
./research.py analyze "10.1234/paper.2023"

# Compare multiple papers
./research.py compare paper1 paper2 paper3

# Generate a literature review
./research.py review "large language models" --output review.md

# Find research gaps
./research.py gaps "multimodal AI"

# Analyze citation network
./research.py citations seed_paper_id --depth 2

# Find seminal papers
./research.py seminal "attention mechanisms in NLP"
```

## Tips for better research assistance

### 1. Use multiple search queries

```python
queries = [
    "main topic exact phrase",
    "topic + synonyms",
    "topic + specific subtopic",
    "topic + methodology keywords"
]
```

### 2. Cross-reference findings

```python
# Don't trust a single paper
def verify_finding(finding: str, topic: str) -> str:
    return ask_assistant(f"""
    Verify this finding across multiple papers:
    Finding: {finding}
    Topic: {topic}

    1. Search for papers that discuss this
    2. Note which papers support/contradict
    3. Assess confidence level
    """)
```

### 3. Track methodology evolution

```python
def methodology_evolution(topic: str, years: int = 10) -> str:
    return ask_assistant(f"""
    How have research methods evolved in {topic} over {years} years?

    1. Find papers from different time periods
    2. Compare methodological approaches
    3. Identify trends and innovations
    """)
```

## Summary

Building a research assistant:

1. **Paper discovery** - Search academic databases
2. **Deep analysis** - Extract key findings and methods
3. **Synthesis** - Connect findings across papers
4. **Gap identification** - Find what's missing
5. **Review generation** - Compile coherent reviews

Build tools with [Gantz](https://gantz.run), accelerate research.

Literature reviews in hours, not weeks.

## Related reading

- [Auto-Generate Documentation](/post/documentation-agents/) - Document generation
- [AI Content Writer](/post/content-writer-agent/) - Content creation
- [PDF to Structured Data](/post/document-processing/) - Document processing

---

*How do you use AI for research? Share your workflow.*
