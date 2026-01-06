+++
title = "Build a Local Web Scraper with AI Selectors"
date = 2025-11-18
image = "/images/agent-train-05.png"
draft = false
tags = ['tutorial', 'python', 'automation']
+++


Web scraping is tedious. Finding the right CSS selectors? Painful.

What if AI could figure out the selectors for you?

Let's build it.

## What we're building

A scraper where you describe what you want, and AI finds it.

```
User: "Get all product names and prices from this page"

Agent:
1. Fetches the page
2. Analyzes the HTML structure
3. Identifies: product names are in ".product-title"
             prices are in ".price-tag"
4. Extracts data
5. Returns structured results
```

No more inspecting elements. No more broken selectors.

## The architecture

```
┌─────────────────┐
│  "Get product   │
│    prices"      │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│   AI Agent      │
│   (Selector     │
│    Finder)      │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│   MCP Tools     │
│   ├─ fetch_page │
│   ├─ analyze    │
│   └─ extract    │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Structured     │
│  JSON Output    │
└─────────────────┘
```

## Step 1: Define the tools

```yaml
# gantz.yaml
tools:
  - name: fetch_page
    description: Fetch a web page and return HTML
    parameters:
      - name: url
        type: string
        required: true
    script:
      shell: |
        curl -sL -A "Mozilla/5.0 (compatible; DataBot/1.0)" "{{url}}"

  - name: fetch_page_rendered
    description: Fetch page with JavaScript rendered (requires chromium)
    parameters:
      - name: url
        type: string
        required: true
    script:
      shell: |
        # Using playwright or puppeteer CLI
        npx playwright-cli screenshot "{{url}}" --full-page /dev/null 2>/dev/null
        npx playwright-cli pdf "{{url}}" /dev/null 2>&1 | head -1000

  - name: extract_text
    description: Extract visible text from HTML
    parameters:
      - name: html_file
        type: string
        required: true
    script:
      shell: |
        cat "{{html_file}}" | python3 -c "
        import sys
        from html.parser import HTMLParser

        class TextExtractor(HTMLParser):
            def __init__(self):
                super().__init__()
                self.text = []
                self.skip = False

            def handle_starttag(self, tag, attrs):
                if tag in ['script', 'style', 'meta', 'link']:
                    self.skip = True

            def handle_endtag(self, tag):
                if tag in ['script', 'style', 'meta', 'link']:
                    self.skip = False

            def handle_data(self, data):
                if not self.skip:
                    text = data.strip()
                    if text:
                        self.text.append(text)

        parser = TextExtractor()
        parser.feed(sys.stdin.read())
        print('\n'.join(parser.text))
        "

  - name: analyze_structure
    description: Analyze HTML structure and find patterns
    parameters:
      - name: url
        type: string
        required: true
    script:
      shell: |
        curl -sL "{{url}}" | python3 -c "
        import sys
        from html.parser import HTMLParser
        from collections import Counter

        class StructureAnalyzer(HTMLParser):
            def __init__(self):
                super().__init__()
                self.elements = Counter()
                self.classes = Counter()
                self.ids = []
                self.depth = 0
                self.structure = []

            def handle_starttag(self, tag, attrs):
                attrs_dict = dict(attrs)
                self.elements[tag] += 1

                if 'class' in attrs_dict:
                    for cls in attrs_dict['class'].split():
                        self.classes[cls] += 1

                if 'id' in attrs_dict:
                    self.ids.append(attrs_dict['id'])

                # Track repeating structures (likely lists)
                if self.elements[tag] > 3:
                    self.structure.append(f'{tag} (repeated {self.elements[tag]}x)')

        parser = StructureAnalyzer()
        parser.feed(sys.stdin.read())

        print('=== Common Elements ===')
        for elem, count in parser.elements.most_common(15):
            print(f'{elem}: {count}')

        print('\n=== Common Classes ===')
        for cls, count in parser.classes.most_common(20):
            print(f'.{cls}: {count}')

        print('\n=== IDs Found ===')
        for id in parser.ids[:20]:
            print(f'#{id}')
        "

  - name: extract_by_selector
    description: Extract content using CSS selector
    parameters:
      - name: url
        type: string
        required: true
      - name: selector
        type: string
        required: true
      - name: attribute
        type: string
        default: "text"
    script:
      shell: |
        curl -sL "{{url}}" | python3 -c "
        import sys
        from bs4 import BeautifulSoup

        html = sys.stdin.read()
        soup = BeautifulSoup(html, 'html.parser')

        elements = soup.select('{{selector}}')

        for el in elements[:50]:
            if '{{attribute}}' == 'text':
                print(el.get_text(strip=True))
            elif '{{attribute}}' == 'html':
                print(str(el))
            else:
                print(el.get('{{attribute}}', ''))
        "

  - name: extract_table
    description: Extract table data as JSON
    parameters:
      - name: url
        type: string
        required: true
      - name: table_selector
        type: string
        default: "table"
    script:
      shell: |
        curl -sL "{{url}}" | python3 -c "
        import sys
        import json
        from bs4 import BeautifulSoup

        html = sys.stdin.read()
        soup = BeautifulSoup(html, 'html.parser')

        table = soup.select_one('{{table_selector}}')
        if not table:
            print(json.dumps({'error': 'Table not found'}))
            sys.exit(1)

        headers = [th.get_text(strip=True) for th in table.select('th')]
        rows = []

        for tr in table.select('tr'):
            cells = [td.get_text(strip=True) for td in tr.select('td')]
            if cells:
                if headers:
                    rows.append(dict(zip(headers, cells)))
                else:
                    rows.append(cells)

        print(json.dumps(rows, indent=2))
        "

  - name: extract_links
    description: Extract all links from page
    parameters:
      - name: url
        type: string
        required: true
      - name: filter_pattern
        type: string
        default: ""
    script:
      shell: |
        curl -sL "{{url}}" | python3 -c "
        import sys
        import re
        from urllib.parse import urljoin
        from bs4 import BeautifulSoup

        html = sys.stdin.read()
        soup = BeautifulSoup(html, 'html.parser')

        base_url = '{{url}}'
        pattern = '{{filter_pattern}}'

        for a in soup.select('a[href]'):
            href = a.get('href', '')
            text = a.get_text(strip=True)
            full_url = urljoin(base_url, href)

            if pattern and not re.search(pattern, full_url):
                continue

            print(f'{text} -> {full_url}')
        "

  - name: extract_multiple
    description: Extract multiple fields with different selectors
    parameters:
      - name: url
        type: string
        required: true
      - name: selectors
        type: string
        description: "JSON object mapping field names to selectors"
        required: true
    script:
      shell: |
        curl -sL "{{url}}" | python3 -c "
        import sys
        import json
        from bs4 import BeautifulSoup

        html = sys.stdin.read()
        soup = BeautifulSoup(html, 'html.parser')

        selectors = json.loads('{{selectors}}')
        results = []

        # Find the maximum number of items
        max_items = 0
        for selector in selectors.values():
            count = len(soup.select(selector))
            max_items = max(max_items, count)

        # Extract each item
        for i in range(max_items):
            item = {}
            for field, selector in selectors.items():
                elements = soup.select(selector)
                if i < len(elements):
                    item[field] = elements[i].get_text(strip=True)
                else:
                    item[field] = None
            results.append(item)

        print(json.dumps(results, indent=2))
        "

  - name: save_results
    description: Save scraped data to file
    parameters:
      - name: data
        type: string
        required: true
      - name: filename
        type: string
        required: true
      - name: format
        type: string
        default: "json"
    script:
      shell: |
        if [ "{{format}}" = "csv" ]; then
          echo '{{data}}' | python3 -c "
        import sys, json, csv
        data = json.loads(sys.stdin.read())
        if data:
            writer = csv.DictWriter(sys.stdout, fieldnames=data[0].keys())
            writer.writeheader()
            writer.writerows(data)
        " > "{{filename}}"
        else
          echo '{{data}}' > "{{filename}}"
        fi
        echo "Saved to {{filename}}"
```

Run with [Gantz](https://gantz.run):

```bash
pip install beautifulsoup4  # Dependency
gantz
```

## Step 2: System prompt

```python
SYSTEM_PROMPT = """You are a web scraping assistant. You help users extract data from websites.

Your workflow:
1. First, analyze the page structure using analyze_structure
2. Identify patterns and repeating elements
3. Determine the best selectors for the requested data
4. Test selectors with extract_by_selector
5. If correct, extract all data
6. Return structured results

Selector tips:
- Look for repeating classes (likely list items)
- Product cards often use: .product, .item, .card
- Prices often use: .price, .cost, .amount
- Titles often use: h1, h2, .title, .name
- Use specific classes over generic tags

Always:
- Test selectors before bulk extraction
- Handle missing data gracefully
- Respect robots.txt and rate limits
- Return clean, structured data
"""
```

## Step 3: Example sessions

### Example 1: E-commerce products

```
User: "Scrape product names and prices from https://example-shop.com/products"

Agent:
[calls analyze_structure]

Page structure analysis:
- 24 instances of .product-card
- Classes found: .product-title (24x), .price (24x), .product-image (24x)

Looks like products are in .product-card containers.
Let me test the selectors:

[calls extract_by_selector with ".product-card .product-title"]
Results: "Wireless Headphones", "USB-C Cable", "Phone Stand"...

[calls extract_by_selector with ".product-card .price"]
Results: "$49.99", "$12.99", "$24.99"...

Selectors confirmed. Extracting all products:

[calls extract_multiple with selectors: {
  "name": ".product-card .product-title",
  "price": ".product-card .price"
}]

Results:
[
  {"name": "Wireless Headphones", "price": "$49.99"},
  {"name": "USB-C Cable", "price": "$12.99"},
  {"name": "Phone Stand", "price": "$24.99"},
  ...
]

Found 24 products. Save to file?
```

### Example 2: News articles

```
User: "Get headlines and links from news.site.com"

Agent:
[calls analyze_structure]

Structure analysis:
- .article-headline (15x)
- .article-link (15x)
- .story-card (15x)

[calls extract_by_selector with ".story-card .article-headline"]
"Breaking: Market hits record high"
"New study reveals..."
"City council votes on..."

[calls extract_links with filter_pattern="/article/"]

Headlines with links:
[
  {
    "headline": "Breaking: Market hits record high",
    "url": "https://news.site.com/article/market-record-2024"
  },
  {
    "headline": "New study reveals climate data",
    "url": "https://news.site.com/article/climate-study"
  },
  ...
]

Found 15 articles.
```

### Example 3: Table data

```
User: "Extract the comparison table from review-site.com/phones"

Agent:
[calls analyze_structure]

Found table with class .comparison-table

[calls extract_table with table_selector=".comparison-table"]

Results:
[
  {
    "Model": "Phone X",
    "Price": "$999",
    "Battery": "4500mAh",
    "Screen": "6.7 inch",
    "Rating": "4.5/5"
  },
  {
    "Model": "Phone Y",
    "Price": "$899",
    "Battery": "4000mAh",
    "Screen": "6.1 inch",
    "Rating": "4.3/5"
  },
  ...
]

Extracted 8 phones from comparison table.
```

### Example 4: Pagination

```
User: "Scrape all job listings from jobs.example.com, handle pagination"

Agent:
[calls analyze_structure on page 1]

Found:
- .job-listing (20x per page)
- .job-title, .company-name, .salary
- .pagination with page links

I'll scrape page by page:

Page 1:
[calls extract_multiple]
Got 20 listings

[calls extract_links with filter_pattern="page="]
Found pages: 1, 2, 3, 4, 5

Page 2:
[calls extract_multiple on jobs.example.com?page=2]
Got 20 listings

...continuing through all pages...

Complete results:
- Total pages: 5
- Total jobs: 97

[
  {"title": "Senior Developer", "company": "TechCorp", "salary": "$120k-$150k"},
  {"title": "Product Manager", "company": "StartupXYZ", "salary": "$100k-$130k"},
  ...
]

Save as CSV or JSON?
```

## Step 4: Smart selector finding

AI can analyze HTML snippets to find patterns:

```yaml
  - name: find_selectors
    description: Analyze HTML snippet to suggest selectors
    parameters:
      - name: url
        type: string
        required: true
      - name: sample_text
        type: string
        description: "Text that appears in the target element"
        required: true
    script:
      shell: |
        curl -sL "{{url}}" | python3 -c "
        import sys
        from bs4 import BeautifulSoup

        html = sys.stdin.read()
        soup = BeautifulSoup(html, 'html.parser')

        # Find elements containing the sample text
        sample = '{{sample_text}}'

        for elem in soup.find_all(string=lambda t: t and sample.lower() in t.lower()):
            parent = elem.parent

            # Build selector path
            path = []
            current = parent
            for _ in range(5):  # Up to 5 levels
                if current.name:
                    selector = current.name
                    if current.get('class'):
                        selector += '.' + '.'.join(current.get('class'))
                    if current.get('id'):
                        selector = f'#{current.get(\"id\")}'
                    path.append(selector)
                current = current.parent
                if not current or current.name == '[document]':
                    break

            path.reverse()
            print(f'Text: {elem.strip()[:50]}')
            print(f'Element: <{parent.name} class=\"{parent.get(\"class\", [])}\">')
            print(f'Suggested selector: {\" > \".join(path[-3:])}')
            print(f'Simple selector: {parent.name}.{\".\" .join(parent.get(\"class\", []))}')
            print('---')
        "
```

Usage:

```
User: "I want to scrape prices, one of them is '$29.99'"

Agent:
[calls find_selectors with sample_text="$29.99"]

Found element containing "$29.99":
- Element: <span class="price current-price">
- Suggested selector: div.product-card > div.price-wrapper > span.price
- Simple selector: span.price.current-price

Let me verify:
[calls extract_by_selector with "span.price.current-price"]

Results: "$29.99", "$49.99", "$19.99"...

This selector works. Use it for extraction?
```

## Step 5: Error handling

```yaml
  - name: safe_fetch
    description: Fetch with retry and error handling
    parameters:
      - name: url
        type: string
        required: true
      - name: retries
        type: number
        default: 3
    script:
      shell: |
        for i in $(seq 1 {{retries}}); do
          response=$(curl -sL -w "\n%{http_code}" -A "Mozilla/5.0" "{{url}}" 2>/dev/null)
          status=$(echo "$response" | tail -1)
          body=$(echo "$response" | sed '$d')

          if [ "$status" = "200" ]; then
            echo "$body"
            exit 0
          elif [ "$status" = "429" ]; then
            echo "Rate limited, waiting..." >&2
            sleep $((i * 5))
          elif [ "$status" = "404" ]; then
            echo '{"error": "Page not found"}'
            exit 1
          else
            echo "Attempt $i failed with status $status" >&2
            sleep $((i * 2))
          fi
        done

        echo '{"error": "Failed after {{retries}} attempts"}'
        exit 1
```

## Step 6: Output formatting

```yaml
  - name: format_output
    description: Format scraped data for display or export
    parameters:
      - name: data
        type: string
        required: true
      - name: format
        type: string
        default: "table"
    script:
      shell: |
        echo '{{data}}' | python3 -c "
        import sys
        import json

        data = json.loads(sys.stdin.read())
        format_type = '{{format}}'

        if format_type == 'table':
            if data:
                headers = list(data[0].keys())
                # Print header
                print(' | '.join(headers))
                print('-' * (len(' | '.join(headers))))
                # Print rows
                for row in data:
                    print(' | '.join(str(row.get(h, ''))[:30] for h in headers))

        elif format_type == 'csv':
            import csv
            if data:
                writer = csv.DictWriter(sys.stdout, fieldnames=data[0].keys())
                writer.writeheader()
                writer.writerows(data)

        elif format_type == 'markdown':
            if data:
                headers = list(data[0].keys())
                print('| ' + ' | '.join(headers) + ' |')
                print('| ' + ' | '.join(['---'] * len(headers)) + ' |')
                for row in data:
                    print('| ' + ' | '.join(str(row.get(h, '')) for h in headers) + ' |')
        else:
            print(json.dumps(data, indent=2))
        "
```

## Full workflow example

```
User: "I need to scrape competitor pricing from shop.competitor.com/products"

Agent: I'll analyze the page and find the right selectors.

[calls analyze_structure]

Page analysis:
- Found 30 .product-item elements
- Common classes: .product-name (30x), .product-price (30x), .product-sku (30x)
- Also found: .rating-stars, .stock-status

Let me test these selectors:

[calls extract_by_selector with ".product-item .product-name" limit 3]
"Premium Widget", "Basic Widget", "Pro Widget"

[calls extract_by_selector with ".product-item .product-price" limit 3]
"$99.00", "$49.00", "$149.00"

Selectors confirmed. Now extracting all data:

[calls extract_multiple with:
  {
    "name": ".product-item .product-name",
    "price": ".product-item .product-price",
    "sku": ".product-item .product-sku"
  }
]

Results (30 products):

| name           | price   | sku      |
|----------------|---------|----------|
| Premium Widget | $99.00  | WDG-001  |
| Basic Widget   | $49.00  | WDG-002  |
| Pro Widget     | $149.00 | WDG-003  |
| ...            | ...     | ...      |

[calls save_results as competitor_prices.json]

Done! Saved 30 products to competitor_prices.json

Want me to:
1. Export as CSV?
2. Scrape additional pages?
3. Add more fields (ratings, stock)?
```

## Summary

Build a local web scraper with:

1. **Fetch tools**: Get HTML content
2. **Analyze tools**: Understand page structure
3. **Extract tools**: Pull data with selectors
4. **AI selector finding**: Describe what you want, AI finds it

Run locally with [Gantz](https://gantz.run). No cloud APIs, no rate limits, your data stays local.

Just say "get the prices" and let AI figure out the selectors.

---

*What websites do you wish you could scrape more easily?*
