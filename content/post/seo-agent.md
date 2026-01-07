+++
title = "Building an AI SEO Agent with MCP: Automated Search Optimization"
image = "images/seo-agent.webp"
date = 2025-06-10
description = "Build intelligent SEO agents with MCP and Gantz. Learn keyword research, content optimization, and automated search rankings improvement."
draft = false
tags = ['seo', 'agent', 'ai', 'mcp', 'marketing', 'gantz']
voice = false

[howto]
name = "How To Build an AI SEO Agent with MCP"
totalTime = 40
[[howto.steps]]
name = "Design agent architecture"
text = "Plan SEO agent capabilities and data flows"
[[howto.steps]]
name = "Integrate SEO APIs"
text = "Connect to search consoles and SEO tools"
[[howto.steps]]
name = "Build analysis tools"
text = "Create keyword and content analysis functions"
[[howto.steps]]
name = "Add optimization logic"
text = "Implement AI-driven optimization recommendations"
[[howto.steps]]
name = "Deploy with Gantz"
text = "Deploy your SEO agent using Gantz CLI"
+++

An AI SEO agent automates search engine optimization tasks, from keyword research to content optimization, helping websites rank higher and drive organic traffic.

## Why Build an SEO Agent?

AI-powered SEO enables:

- **Automated keyword research**: Discover opportunities 24/7
- **Content optimization**: AI-driven improvements
- **Competitor analysis**: Track ranking changes
- **Technical SEO**: Automated site audits
- **Performance tracking**: Real-time rank monitoring

## SEO Agent Architecture

```yaml
# gantz.yaml
name: seo-agent
version: 1.0.0

tools:
  analyze_keywords:
    description: "Research and analyze keywords"
    parameters:
      seed_keyword:
        type: string
        required: true
      market:
        type: string
        default: "us"
    handler: seo.analyze_keywords

  audit_page:
    description: "SEO audit of a page"
    parameters:
      url:
        type: string
        required: true
    handler: seo.audit_page

  analyze_competitors:
    description: "Analyze competitor SEO"
    parameters:
      domain:
        type: string
        required: true
      competitors:
        type: array
    handler: seo.analyze_competitors

  optimize_content:
    description: "Optimize content for SEO"
    parameters:
      content:
        type: string
        required: true
      target_keyword:
        type: string
        required: true
    handler: seo.optimize_content

  track_rankings:
    description: "Track keyword rankings"
    parameters:
      domain:
        type: string
        required: true
      keywords:
        type: array
        required: true
    handler: seo.track_rankings

  generate_content_brief:
    description: "Generate SEO content brief"
    parameters:
      keyword:
        type: string
        required: true
    handler: seo.generate_content_brief
```

## Handler Implementation

```python
# handlers/seo.py
import httpx
import os
from bs4 import BeautifulSoup

SERP_API_KEY = os.environ.get('SERP_API_KEY')
SEMRUSH_API_KEY = os.environ.get('SEMRUSH_API_KEY')


async def analyze_keywords(seed_keyword: str, market: str = "us") -> dict:
    """Research and analyze keywords."""
    # Get keyword data
    keyword_data = await fetch_keyword_data(seed_keyword, market)

    # Get related keywords
    related = await fetch_related_keywords(seed_keyword, market)

    # AI analysis
    from gantz import MCPClient
    mcp = MCPClient()

    result = mcp.execute_tool('ai_analyze', {
        'type': 'keyword_analysis',
        'seed': seed_keyword,
        'data': keyword_data,
        'related': related,
        'analyze': ['difficulty', 'opportunity', 'intent', 'clusters']
    })

    return {
        'seed_keyword': seed_keyword,
        'search_volume': keyword_data.get('volume'),
        'difficulty': keyword_data.get('difficulty'),
        'cpc': keyword_data.get('cpc'),
        'intent': result.get('intent'),
        'opportunity_score': result.get('opportunity'),
        'related_keywords': result.get('keyword_clusters', []),
        'recommendations': result.get('recommendations', [])
    }


async def audit_page(url: str) -> dict:
    """SEO audit of a page."""
    # Fetch page
    async with httpx.AsyncClient() as client:
        response = await client.get(url, timeout=30.0)
        html = response.text

    soup = BeautifulSoup(html, 'html.parser')

    # Extract SEO elements
    audit_data = {
        'title': soup.title.string if soup.title else None,
        'meta_description': get_meta_description(soup),
        'h1_tags': [h1.text for h1 in soup.find_all('h1')],
        'h2_tags': [h2.text for h2 in soup.find_all('h2')],
        'images_without_alt': len([img for img in soup.find_all('img') if not img.get('alt')]),
        'internal_links': count_internal_links(soup, url),
        'external_links': count_external_links(soup, url),
        'word_count': len(soup.get_text().split()),
        'has_schema': bool(soup.find('script', type='application/ld+json'))
    }

    # AI analysis
    from gantz import MCPClient
    mcp = MCPClient()

    result = mcp.execute_tool('ai_analyze', {
        'type': 'seo_audit',
        'url': url,
        'elements': audit_data,
        'check': ['title', 'meta', 'headings', 'content', 'technical']
    })

    return {
        'url': url,
        'score': result.get('score'),
        'issues': result.get('issues', []),
        'warnings': result.get('warnings', []),
        'opportunities': result.get('opportunities', []),
        'recommendations': result.get('recommendations', [])
    }


async def analyze_competitors(domain: str, competitors: list = None) -> dict:
    """Analyze competitor SEO."""
    if not competitors:
        competitors = await discover_competitors(domain)

    competitor_data = []
    for comp in competitors[:5]:
        data = await fetch_domain_metrics(comp)
        data['domain'] = comp
        competitor_data.append(data)

    # AI analysis
    from gantz import MCPClient
    mcp = MCPClient()

    result = mcp.execute_tool('ai_analyze', {
        'type': 'competitor_analysis',
        'domain': domain,
        'competitors': competitor_data,
        'analyze': ['gaps', 'opportunities', 'strengths', 'weaknesses']
    })

    return {
        'domain': domain,
        'competitors': competitor_data,
        'content_gaps': result.get('content_gaps', []),
        'keyword_opportunities': result.get('keyword_gaps', []),
        'backlink_opportunities': result.get('backlink_gaps', []),
        'recommendations': result.get('recommendations', [])
    }


async def optimize_content(content: str, target_keyword: str) -> dict:
    """Optimize content for SEO."""
    from gantz import MCPClient
    mcp = MCPClient()

    # Analyze current content
    analysis = mcp.execute_tool('ai_analyze', {
        'type': 'content_seo',
        'content': content,
        'keyword': target_keyword,
        'check': ['keyword_density', 'readability', 'structure', 'entities']
    })

    # Generate optimized version
    optimized = mcp.execute_tool('ai_generate', {
        'type': 'seo_optimized_content',
        'original': content,
        'keyword': target_keyword,
        'improvements': analysis.get('improvements', [])
    })

    return {
        'target_keyword': target_keyword,
        'original_score': analysis.get('score'),
        'optimized_score': optimized.get('score'),
        'changes': optimized.get('changes', []),
        'optimized_content': optimized.get('content'),
        'meta_suggestions': optimized.get('meta', {})
    }


async def track_rankings(domain: str, keywords: list) -> dict:
    """Track keyword rankings."""
    rankings = []

    for keyword in keywords:
        rank_data = await fetch_serp_position(domain, keyword)
        rankings.append({
            'keyword': keyword,
            'position': rank_data.get('position'),
            'url': rank_data.get('url'),
            'change': rank_data.get('change')
        })

    # AI insights
    from gantz import MCPClient
    mcp = MCPClient()

    result = mcp.execute_tool('ai_analyze', {
        'type': 'ranking_insights',
        'domain': domain,
        'rankings': rankings,
        'analyze': ['trends', 'opportunities', 'risks']
    })

    return {
        'domain': domain,
        'rankings': rankings,
        'average_position': sum(r['position'] for r in rankings if r['position']) / len(rankings),
        'improving': result.get('improving', []),
        'declining': result.get('declining', []),
        'insights': result.get('insights', [])
    }


async def generate_content_brief(keyword: str) -> dict:
    """Generate SEO content brief."""
    # Analyze SERP
    serp_data = await analyze_serp(keyword)

    # AI brief generation
    from gantz import MCPClient
    mcp = MCPClient()

    result = mcp.execute_tool('ai_generate', {
        'type': 'content_brief',
        'keyword': keyword,
        'serp_analysis': serp_data,
        'include': ['outline', 'word_count', 'entities', 'questions', 'competitors']
    })

    return {
        'keyword': keyword,
        'search_intent': result.get('intent'),
        'recommended_word_count': result.get('word_count'),
        'title_suggestions': result.get('titles', []),
        'outline': result.get('outline', []),
        'must_include': result.get('entities', []),
        'questions_to_answer': result.get('questions', []),
        'competitor_insights': result.get('competitor_analysis')
    }


def get_meta_description(soup):
    """Extract meta description."""
    meta = soup.find('meta', attrs={'name': 'description'})
    return meta.get('content') if meta else None


def count_internal_links(soup, base_url):
    """Count internal links."""
    from urllib.parse import urlparse
    base_domain = urlparse(base_url).netloc
    links = soup.find_all('a', href=True)
    return len([l for l in links if base_domain in l['href'] or l['href'].startswith('/')])


def count_external_links(soup, base_url):
    """Count external links."""
    from urllib.parse import urlparse
    base_domain = urlparse(base_url).netloc
    links = soup.find_all('a', href=True)
    return len([l for l in links if l['href'].startswith('http') and base_domain not in l['href']])
```

## SEO Agent Orchestration

```python
# seo_agent.py
from gantz import MCPClient

mcp = MCPClient(config_path='gantz.yaml')


async def run_full_audit(domain: str) -> dict:
    """Run comprehensive SEO audit."""
    results = {
        'domain': domain,
        'audits': []
    }

    # Get pages to audit
    pages = await discover_pages(domain)

    for page in pages[:20]:
        audit = mcp.execute_tool('audit_page', {'url': page})
        results['audits'].append(audit)

    # Competitor analysis
    competitors = mcp.execute_tool('analyze_competitors', {'domain': domain})

    # AI summary
    summary = mcp.execute_tool('ai_generate', {
        'type': 'seo_report',
        'audits': results['audits'],
        'competitors': competitors,
        'sections': ['executive_summary', 'issues', 'opportunities', 'action_plan']
    })

    return {
        'domain': domain,
        'overall_score': summary.get('score'),
        'executive_summary': summary.get('summary'),
        'critical_issues': summary.get('critical', []),
        'opportunities': summary.get('opportunities', []),
        'action_plan': summary.get('action_plan', [])
    }


async def content_strategy(domain: str, seed_keywords: list) -> dict:
    """Generate content strategy."""
    keyword_data = []

    for keyword in seed_keywords:
        analysis = mcp.execute_tool('analyze_keywords', {'seed_keyword': keyword})
        keyword_data.append(analysis)

    # AI strategy generation
    result = mcp.execute_tool('ai_generate', {
        'type': 'content_strategy',
        'domain': domain,
        'keyword_research': keyword_data,
        'generate': ['content_calendar', 'pillar_pages', 'clusters', 'priorities']
    })

    return {
        'domain': domain,
        'pillar_pages': result.get('pillars', []),
        'content_clusters': result.get('clusters', []),
        'content_calendar': result.get('calendar', []),
        'priority_keywords': result.get('priorities', [])
    }
```

## Deploy with Gantz CLI

```bash
# Install Gantz
npm install -g gantz

# Initialize SEO agent
gantz init --template seo-agent

# Set API keys
export SERP_API_KEY=your-serp-key
export SEMRUSH_API_KEY=your-semrush-key

# Deploy
gantz deploy --platform railway

# Run full audit
gantz run run_full_audit --domain example.com

# Analyze keywords
gantz run analyze_keywords --seed-keyword "ai automation"

# Generate content brief
gantz run generate_content_brief --keyword "mcp integration guide"
```

Build intelligent SEO automation at [gantz.run](https://gantz.run).

## Related Reading

- [Social Media Agent](/post/social-media-agent/) - Social automation
- [Content Generation](/post/mcp-content-generation/) - AI content creation
- [Lead Scoring Agent](/post/lead-scoring-agent/) - Marketing automation

## Conclusion

An AI SEO agent transforms search optimization from manual work to intelligent automation. With continuous analysis, optimization recommendations, and content strategy, you can improve rankings systematically.

Start building your SEO agent with Gantz today.
