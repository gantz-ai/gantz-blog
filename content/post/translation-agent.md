+++
title = "Build a Translation Agent for Any Language"
image = "/images/translation-agent.png"
date = 2025-11-12
description = "Create an AI translation agent that handles documents, websites, and apps. Support any language pair with context-aware translations using MCP tools."
draft = false
tags = ['mcp', 'tutorial', 'translation']
voice = false

[howto]
name = "Build Translation Agent"
totalTime = 30
[[howto.steps]]
name = "Create translation tools"
text = "Build MCP tools for language detection, translation, and validation."
[[howto.steps]]
name = "Implement context handling"
text = "Design prompts that maintain context across translations."
[[howto.steps]]
name = "Build batch processing"
text = "Handle documents, websites, and app strings."
[[howto.steps]]
name = "Add quality assurance"
text = "Implement validation and human review workflows."
[[howto.steps]]
name = "Create localization pipeline"
text = "Build end-to-end localization automation."
+++


Machine translation got good. But "good enough" isn't good enough.

AI can do better. Context-aware. Brand-consistent. Actually natural.

Here's how to build it.

## Beyond basic translation

Traditional translation:
- Word-by-word mapping
- Loses context and nuance
- Ignores brand voice
- No domain expertise

AI translation:
- Understands full context
- Adapts to domain terminology
- Maintains brand voice
- Handles cultural nuances

## What you'll build

- Multi-language translation
- Document translation
- Website localization
- App string translation
- Translation memory
- Quality validation

## Step 1: Create translation tools

Using [Gantz](https://gantz.run):

```yaml
# gantz.yaml
name: translation-agent

tools:
  - name: detect_language
    description: Detect the language of text
    parameters:
      - name: text
        type: string
        required: true
    script:
      command: python
      args: ["scripts/detect_language.py"]
      stdin: "{{text}}"

  - name: translate_text
    description: Translate text using Claude (for complex translations)
    parameters:
      - name: text
        type: string
        required: true
      - name: source_lang
        type: string
        required: true
      - name: target_lang
        type: string
        required: true
      - name: context
        type: string
        description: Additional context for better translation
    script:
      command: python
      args: ["scripts/translate.py", "{{source_lang}}", "{{target_lang}}", "{{context}}"]
      stdin: "{{text}}"

  - name: get_translation_memory
    description: Check translation memory for existing translations
    parameters:
      - name: text
        type: string
        required: true
      - name: target_lang
        type: string
        required: true
    script:
      command: python
      args: ["scripts/tm_lookup.py", "{{target_lang}}"]
      stdin: "{{text}}"

  - name: save_translation
    description: Save translation to memory for future use
    parameters:
      - name: source_text
        type: string
        required: true
      - name: translated_text
        type: string
        required: true
      - name: source_lang
        type: string
        required: true
      - name: target_lang
        type: string
        required: true
    script:
      command: python
      args: ["scripts/tm_save.py", "{{source_lang}}", "{{target_lang}}", "{{source_text}}", "{{translated_text}}"]

  - name: get_glossary
    description: Get domain-specific glossary terms
    parameters:
      - name: domain
        type: string
        default: "general"
      - name: target_lang
        type: string
        required: true
    script:
      shell: cat "glossaries/{{domain}}_{{target_lang}}.json" 2>/dev/null || echo "{}"

  - name: validate_translation
    description: Validate translation quality
    parameters:
      - name: source_text
        type: string
        required: true
      - name: translated_text
        type: string
        required: true
      - name: target_lang
        type: string
        required: true
    script:
      command: python
      args: ["scripts/validate.py", "{{target_lang}}"]
      stdin: "{{source_text}}\n---\n{{translated_text}}"

  - name: extract_strings
    description: Extract translatable strings from code files
    parameters:
      - name: file_path
        type: string
        required: true
    script:
      command: python
      args: ["scripts/extract_strings.py", "{{file_path}}"]

  - name: read_file
    description: Read file contents
    parameters:
      - name: path
        type: string
        required: true
    script:
      shell: cat "{{path}}"

  - name: write_file
    description: Write content to file
    parameters:
      - name: path
        type: string
        required: true
      - name: content
        type: string
        required: true
    script:
      shell: |
        cat > "{{path}}" << 'CONTENT'
        {{content}}
        CONTENT
```

Language detection script:

```python
# scripts/detect_language.py
import sys
from langdetect import detect, detect_langs

text = sys.stdin.read()

try:
    language = detect(text)
    probabilities = detect_langs(text)

    print(f"Detected: {language}")
    print(f"Probabilities: {probabilities}")
except Exception as e:
    print(f"Error: {e}")
```

Translation memory lookup:

```python
# scripts/tm_lookup.py
import sys
import json
import hashlib
import os

target_lang = sys.argv[1]
source_text = sys.stdin.read().strip()

# Hash the source text for lookup
text_hash = hashlib.md5(source_text.encode()).hexdigest()

# Look up in translation memory
tm_file = f"tm/{target_lang}.json"

if os.path.exists(tm_file):
    with open(tm_file) as f:
        tm = json.load(f)

    if text_hash in tm:
        result = tm[text_hash]
        print(json.dumps({
            "found": True,
            "translation": result["translation"],
            "confidence": result.get("confidence", 1.0),
            "context": result.get("context", "")
        }))
    else:
        print(json.dumps({"found": False}))
else:
    print(json.dumps({"found": False}))
```

```bash
gantz run --auth
```

## Step 2: The translation agent

```python
import anthropic
from typing import List, Optional, Dict
import json

MCP_URL = "https://translation-agent.gantz.run/sse"
MCP_TOKEN = "gtz_abc123"

client = anthropic.Anthropic()

TRANSLATION_SYSTEM_PROMPT = """You are an expert translator.

Your translations are:
- Accurate to the original meaning
- Natural in the target language
- Contextually appropriate
- Culturally adapted (not just literal)

Guidelines:
1. **Preserve meaning**: The translation should convey the same message
2. **Be natural**: Write how a native speaker would write
3. **Consider context**: Adapt formality, tone, and style
4. **Handle idioms**: Find equivalent expressions, don't translate literally
5. **Keep formatting**: Preserve structure, lists, emphasis
6. **Use glossary terms**: Apply domain-specific terminology consistently

When translating:
- First understand the full context
- Consider the target audience
- Maintain the author's voice/tone
- Flag any cultural issues or ambiguities"""

def translate(text: str, source_lang: str, target_lang: str,
              context: str = "", domain: str = "general") -> str:
    """Translate text with context awareness."""

    response = client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=4096,
        system=TRANSLATION_SYSTEM_PROMPT,
        messages=[{
            "role": "user",
            "content": f"""Translate this text from {source_lang} to {target_lang}.

Text to translate:
{text}

{f'Context: {context}' if context else ''}

Steps:
1. Use get_translation_memory to check for existing translations
2. Use get_glossary for domain-specific terms (domain: {domain})
3. Translate the text naturally
4. Use validate_translation to check quality
5. Use save_translation to store the result

Output only the translation, nothing else."""
        }],
        tools=[{"type": "mcp", "server_url": MCP_URL, "token": MCP_TOKEN}]
    )

    for content in response.content:
        if hasattr(content, 'text'):
            return content.text

    return ""

def translate_document(file_path: str, target_lang: str,
                       preserve_format: bool = True) -> str:
    """Translate an entire document."""

    response = client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=8192,
        system=TRANSLATION_SYSTEM_PROMPT,
        messages=[{
            "role": "user",
            "content": f"""Translate the document at {file_path} to {target_lang}.

1. Use read_file to get the document content
2. Detect the source language
3. Get relevant glossary terms
4. Translate section by section to maintain context
5. {'Preserve the original formatting (markdown, HTML, etc.)' if preserve_format else 'Output plain text'}
6. Save translations to memory for consistency

Output the complete translated document."""
        }],
        tools=[{"type": "mcp", "server_url": MCP_URL, "token": MCP_TOKEN}]
    )

    for content in response.content:
        if hasattr(content, 'text'):
            return content.text

    return ""

def batch_translate(texts: List[str], target_lang: str,
                    source_lang: str = None) -> List[str]:
    """Translate multiple texts efficiently."""

    texts_json = json.dumps(texts)

    response = client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=8192,
        system=TRANSLATION_SYSTEM_PROMPT,
        messages=[{
            "role": "user",
            "content": f"""Translate these texts to {target_lang}:

{texts_json}

1. Check translation memory for each
2. Use consistent terminology across all texts
3. Maintain any formatting or placeholders
4. Output as JSON array of translations

{f'Source language: {source_lang}' if source_lang else 'Detect source language'}"""
        }],
        tools=[{"type": "mcp", "server_url": MCP_URL, "token": MCP_TOKEN}]
    )

    for content in response.content:
        if hasattr(content, 'text'):
            try:
                return json.loads(content.text)
            except:
                return [content.text]

    return []
```

## Step 3: App localization

```python
def localize_app_strings(source_file: str, target_lang: str,
                        output_file: str) -> str:
    """Translate app localization strings."""

    response = client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=8192,
        system=TRANSLATION_SYSTEM_PROMPT + """

        For app localization:
        - Keep strings concise (UI space is limited)
        - Preserve placeholders like {name}, %s, {{variable}}
        - Consider context (button, label, error message, etc.)
        - Match formality of the app's voice""",
        messages=[{
            "role": "user",
            "content": f"""Localize app strings from {source_file} to {target_lang}.

1. Use read_file to get the source strings
2. Parse the format (JSON, YAML, properties, etc.)
3. Translate each string appropriately:
   - UI buttons: Keep short
   - Error messages: Be clear and helpful
   - Labels: Match formality
   - Preserve all placeholders exactly
4. Save to {output_file} in the same format
5. Use write_file to save the result

Report any strings that need special attention."""
        }],
        tools=[{"type": "mcp", "server_url": MCP_URL, "token": MCP_TOKEN}]
    )

    for content in response.content:
        if hasattr(content, 'text'):
            return content.text

    return ""

def extract_and_translate(code_path: str, target_lang: str) -> Dict:
    """Extract strings from code and translate them."""

    response = client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=4096,
        system=TRANSLATION_SYSTEM_PROMPT,
        messages=[{
            "role": "user",
            "content": f"""Extract and translate strings from {code_path}.

1. Use extract_strings to find translatable strings
2. Identify:
   - User-facing strings (need translation)
   - Technical strings (keep as-is)
   - Potentially hardcoded strings
3. Translate user-facing strings to {target_lang}
4. Output as localization file (JSON format)

Include:
- Original string as key
- Translation as value
- Context comment for ambiguous strings"""
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
```

## Step 4: Website localization

```python
def translate_webpage(url: str, target_lang: str) -> str:
    """Translate a webpage while preserving structure."""

    response = client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=8192,
        system=TRANSLATION_SYSTEM_PROMPT + """

        For webpage translation:
        - Preserve all HTML structure
        - Don't translate code, URLs, or technical attributes
        - Translate alt text and title attributes
        - Handle SEO elements (meta description, titles)
        - Preserve inline styles and classes""",
        messages=[{
            "role": "user",
            "content": f"""Translate the webpage content from this URL: {url}

1. Fetch the page content
2. Extract translatable text (not code or markup)
3. Translate to {target_lang}
4. Reconstruct HTML with translated content
5. Update lang attribute

Output the translated HTML."""
        }],
        tools=[{"type": "mcp", "server_url": MCP_URL, "token": MCP_TOKEN}]
    )

    for content in response.content:
        if hasattr(content, 'text'):
            return content.text

    return ""

def translate_markdown(content: str, target_lang: str) -> str:
    """Translate markdown while preserving formatting."""

    response = client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=8192,
        system=TRANSLATION_SYSTEM_PROMPT,
        messages=[{
            "role": "user",
            "content": f"""Translate this markdown to {target_lang}:

```markdown
{content}
```

Preserve:
- Heading levels (#, ##, etc.)
- Bold and italic formatting
- Links (translate link text, keep URLs)
- Code blocks (don't translate code)
- Lists and tables structure
- Images (translate alt text only)

Output the translated markdown."""
        }]
    )

    for c in response.content:
        if hasattr(c, 'text'):
            return c.text

    return ""
```

## Step 5: Quality assurance

```python
def review_translation(source: str, translation: str,
                       target_lang: str) -> Dict:
    """Review translation quality."""

    response = client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=2048,
        messages=[{
            "role": "user",
            "content": f"""Review this translation:

Source: {source}

Translation ({target_lang}): {translation}

Use validate_translation and analyze:

1. **Accuracy** (1-5): Does it convey the correct meaning?
2. **Fluency** (1-5): Does it sound natural?
3. **Terminology** (1-5): Are terms used correctly?
4. **Style** (1-5): Does it match the source tone?

For any score below 4, provide:
- The issue
- Suggested improvement

Output as JSON."""
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

def back_translate(translated: str, original_lang: str) -> str:
    """Back-translate to verify accuracy."""

    response = client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=4096,
        system="You translate text back to the original language for verification.",
        messages=[{
            "role": "user",
            "content": f"""Translate this back to {original_lang}:

{translated}

This is a back-translation to verify accuracy.
Translate literally to show what the current translation actually says."""
        }]
    )

    for content in response.content:
        if hasattr(content, 'text'):
            return content.text

    return ""

def compare_with_original(original: str, back_translated: str) -> Dict:
    """Compare original with back-translation."""

    response = client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=1024,
        messages=[{
            "role": "user",
            "content": f"""Compare these texts:

Original: {original}

Back-translation: {back_translated}

Identify:
1. Meaning changes (critical)
2. Nuance losses (important)
3. Minor differences (acceptable)

Output as JSON with:
- match_score (0-100)
- issues: list of problems found
- acceptable: boolean"""
        }]
    )

    for content in response.content:
        if hasattr(content, 'text'):
            try:
                return json.loads(content.text)
            except:
                return {"raw": content.text}

    return {}
```

## Step 6: CLI tool

```python
#!/usr/bin/env python3
"""Translation Agent CLI."""

import argparse
import json

def main():
    parser = argparse.ArgumentParser(description="AI Translation Agent")
    subparsers = parser.add_subparsers(dest="command", help="Commands")

    # Translate text
    text_parser = subparsers.add_parser("text", help="Translate text")
    text_parser.add_argument("text", help="Text to translate")
    text_parser.add_argument("--to", "-t", required=True, help="Target language")
    text_parser.add_argument("--from", "-f", dest="source", help="Source language")
    text_parser.add_argument("--context", "-c", help="Additional context")

    # Translate document
    doc_parser = subparsers.add_parser("document", help="Translate document")
    doc_parser.add_argument("file", help="Document path")
    doc_parser.add_argument("--to", "-t", required=True, help="Target language")
    doc_parser.add_argument("--output", "-o", help="Output file")

    # Localize app
    app_parser = subparsers.add_parser("app", help="Localize app strings")
    app_parser.add_argument("file", help="Source strings file")
    app_parser.add_argument("--to", "-t", required=True, help="Target language")
    app_parser.add_argument("--output", "-o", help="Output file")

    # Review
    review_parser = subparsers.add_parser("review", help="Review translation")
    review_parser.add_argument("--source", "-s", required=True, help="Source text")
    review_parser.add_argument("--translation", "-t", required=True, help="Translation")
    review_parser.add_argument("--lang", "-l", required=True, help="Target language")

    # Batch
    batch_parser = subparsers.add_parser("batch", help="Batch translate")
    batch_parser.add_argument("file", help="JSON file with texts")
    batch_parser.add_argument("--to", "-t", required=True, help="Target language")
    batch_parser.add_argument("--output", "-o", help="Output file")

    args = parser.parse_args()

    if args.command == "text":
        result = translate(args.text, args.source or "auto", args.to, args.context or "")
        print(result)

    elif args.command == "document":
        result = translate_document(args.file, args.to)
        if args.output:
            with open(args.output, "w") as f:
                f.write(result)
            print(f"Saved to {args.output}")
        else:
            print(result)

    elif args.command == "app":
        output = args.output or f"strings_{args.to}.json"
        result = localize_app_strings(args.file, args.to, output)
        print(result)

    elif args.command == "review":
        result = review_translation(args.source, args.translation, args.lang)
        print(json.dumps(result, indent=2))

    elif args.command == "batch":
        with open(args.file) as f:
            texts = json.load(f)

        results = batch_translate(texts, args.to)

        if args.output:
            with open(args.output, "w") as f:
                json.dump(results, f, indent=2, ensure_ascii=False)
            print(f"Saved to {args.output}")
        else:
            print(json.dumps(results, indent=2, ensure_ascii=False))

    else:
        parser.print_help()

if __name__ == "__main__":
    main()
```

Usage:

```bash
# Translate text
./translate.py text "Hello, how are you?" --to es

# Translate with context
./translate.py text "Spring is coming" --to ja --context "discussing seasons"

# Translate a document
./translate.py document README.md --to fr --output README.fr.md

# Localize app strings
./translate.py app en.json --to de --output de.json

# Review a translation
./translate.py review --source "Click here" --translation "Klicken Sie hier" --lang de

# Batch translate
./translate.py batch strings.json --to es --output strings.es.json
```

## Summary

Building a translation agent:

1. **Context-aware translation** - Understand meaning, not just words
2. **Translation memory** - Consistency across translations
3. **Domain glossaries** - Correct terminology
4. **App localization** - Handle strings, placeholders, constraints
5. **Quality assurance** - Validation and back-translation

Build tools with [Gantz](https://gantz.run), localize anything.

Translation that actually sounds native.

## Related reading

- [AI Content Writer](/post/content-writer-agent/) - Content creation
- [PDF to Structured Data](/post/document-processing/) - Document handling
- [Auto-Generate Documentation](/post/documentation-agents/) - Doc generation

---

*How do you handle localization? Share your approach.*
