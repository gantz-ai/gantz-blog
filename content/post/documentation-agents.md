+++
title = "Auto-Generate Documentation with AI Agents"
image = "images/documentation-agents.webp"
date = 2025-11-07
description = "Build AI agents that automatically generate and maintain documentation from your codebase. API docs, README files, and more."
draft = false
tags = ['mcp', 'tutorial', 'documentation']
voice = false

[howto]
name = "Auto-Generate Documentation"
totalTime = 30
[[howto.steps]]
name = "Create code analysis tools"
text = "Build MCP tools for reading and analyzing code."
[[howto.steps]]
name = "Design documentation prompts"
text = "Create prompts for different documentation types."
[[howto.steps]]
name = "Build the doc generator"
text = "Implement the agent that generates documentation."
[[howto.steps]]
name = "Set up automation"
text = "Automate doc generation on code changes."
[[howto.steps]]
name = "Maintain doc quality"
text = "Review and refine generated documentation."
+++


Documentation gets outdated the moment you write it.

Code changes. Docs don't.

Unless AI keeps them in sync.

## The documentation problem

Every project has:
- README that's six months stale
- API docs missing new endpoints
- Code comments describing deleted features
- Wikis nobody updates

The solution isn't "write more docs." It's automated documentation that updates itself.

## What AI can document

- **API references**: Endpoints, parameters, responses
- **Function documentation**: Purpose, args, return values
- **README files**: Installation, usage, examples
- **Changelogs**: What changed and why
- **Architecture docs**: How systems connect
- **Inline comments**: What complex code does

## Step 1: Create documentation tools

Using [Gantz](https://gantz.run):

```yaml
# gantz.yaml
name: doc-generator

tools:
  - name: list_source_files
    description: List source code files in the project
    parameters:
      - name: pattern
        type: string
        default: "**/*.{py,js,ts,go,rs}"
        description: Glob pattern for files
      - name: exclude
        type: string
        default: "node_modules,vendor,dist"
    script:
      shell: |
        find . -type f \( -name "*.py" -o -name "*.js" -o -name "*.ts" -o -name "*.go" -o -name "*.rs" \) \
          | grep -v -E "(node_modules|vendor|dist|__pycache__|\.git)" \
          | head -100

  - name: read_file
    description: Read the contents of a file
    parameters:
      - name: path
        type: string
        required: true
    script:
      shell: cat "{{path}}"

  - name: write_file
    description: Write content to a file
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

  - name: get_function_signatures
    description: Extract function signatures from a file
    parameters:
      - name: path
        type: string
        required: true
    script:
      shell: |
        # Python functions
        grep -n "^def \|^async def \|^class " "{{path}}" 2>/dev/null || \
        # JavaScript/TypeScript functions
        grep -n "^function \|^export function \|^export const .* = " "{{path}}" 2>/dev/null || \
        # Go functions
        grep -n "^func " "{{path}}" 2>/dev/null || \
        echo "No functions found"

  - name: get_api_routes
    description: Extract API route definitions
    parameters:
      - name: path
        type: string
        default: "."
    script:
      shell: |
        # Express/Fastify routes
        rg -n "@(Get|Post|Put|Delete|Patch)\(|app\.(get|post|put|delete|patch)\(" {{path}} --type ts --type js 2>/dev/null || \
        # FastAPI/Flask routes
        rg -n "@app\.(get|post|put|delete|patch)\(|@router\." {{path}} --type py 2>/dev/null || \
        echo "No routes found"

  - name: get_existing_docs
    description: Read existing documentation files
    parameters:
      - name: path
        type: string
        default: "."
    script:
      shell: |
        find {{path}} -name "README.md" -o -name "*.md" -o -name "docs" -type d | head -20

  - name: get_package_info
    description: Get package metadata
    parameters:
      - name: path
        type: string
        default: "."
    script:
      shell: |
        # Check for package.json
        if [ -f "{{path}}/package.json" ]; then
          cat "{{path}}/package.json"
        # Check for pyproject.toml
        elif [ -f "{{path}}/pyproject.toml" ]; then
          cat "{{path}}/pyproject.toml"
        # Check for Cargo.toml
        elif [ -f "{{path}}/Cargo.toml" ]; then
          cat "{{path}}/Cargo.toml"
        # Check for go.mod
        elif [ -f "{{path}}/go.mod" ]; then
          cat "{{path}}/go.mod"
        else
          echo "No package file found"
        fi

  - name: git_log
    description: Get recent git commit history
    parameters:
      - name: count
        type: integer
        default: 20
      - name: since
        type: string
        description: Date since (e.g., "2024-01-01")
    script:
      shell: |
        if [ -n "{{since}}" ]; then
          git log --since="{{since}}" --pretty=format:"%h %s" -{{count}}
        else
          git log --pretty=format:"%h %s" -{{count}}
        fi
```

```bash
gantz run --auth
```

## Step 2: README generator

```python
import anthropic

MCP_URL = "https://doc-generator.gantz.run/sse"
MCP_TOKEN = "gtz_abc123"

client = anthropic.Anthropic()

def generate_readme(project_path: str = ".") -> str:
    """Generate a README.md for a project."""

    response = client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=4096,
        system="""You are a technical documentation writer.

        Create README files that are:
        - Clear and concise
        - Well-structured with proper headings
        - Focused on practical usage
        - Include real code examples

        README structure:
        1. Project name and one-line description
        2. Features (bullet points)
        3. Installation
        4. Quick start / Usage
        5. Configuration (if applicable)
        6. API reference (if applicable)
        7. Contributing
        8. License

        Don't include sections that don't apply.
        Use code blocks with proper language tags.
        Keep it under 500 lines unless the project is complex.""",
        messages=[{
            "role": "user",
            "content": f"""Generate a README.md for the project at {project_path}.

Steps:
1. Use get_package_info to understand what the project is
2. Use list_source_files to see the codebase structure
3. Read the main entry point file to understand functionality
4. If there are existing docs, use get_existing_docs to incorporate them
5. Generate a complete, professional README

Output the README content directly in markdown format."""
        }],
        tools=[{"type": "mcp", "server_url": MCP_URL, "token": MCP_TOKEN}]
    )

    for content in response.content:
        if hasattr(content, 'text'):
            return content.text

    return ""

def update_readme(project_path: str = ".") -> str:
    """Update an existing README with current state."""

    response = client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=4096,
        system="""You update existing README files.

        Keep:
        - Existing structure and style
        - Custom sections the author added
        - Project branding and tone

        Update:
        - Installation instructions if dependencies changed
        - Usage examples if API changed
        - Feature list if capabilities changed

        Don't remove information without good reason.
        Preserve the original author's voice.""",
        messages=[{
            "role": "user",
            "content": f"""Update the README.md for {project_path}.

1. Read the existing README.md
2. Analyze current code to find changes
3. Update outdated sections
4. Keep custom content intact
5. Output the updated README"""
        }],
        tools=[{"type": "mcp", "server_url": MCP_URL, "token": MCP_TOKEN}]
    )

    for content in response.content:
        if hasattr(content, 'text'):
            return content.text

    return ""
```

## Step 3: API documentation generator

```python
def generate_api_docs(project_path: str = ".") -> str:
    """Generate API documentation from route definitions."""

    response = client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=8192,
        system="""You generate API documentation.

        For each endpoint, document:
        - HTTP method and path
        - Description of what it does
        - Request parameters (path, query, body)
        - Response format with examples
        - Error responses
        - Authentication requirements

        Format in markdown with clear sections.
        Include curl examples for each endpoint.
        Group related endpoints together.""",
        messages=[{
            "role": "user",
            "content": f"""Generate API documentation for {project_path}.

1. Use get_api_routes to find all endpoints
2. For each route file, use read_file to see implementation details
3. Extract:
   - Route paths and methods
   - Request/response types
   - Validation rules
   - Authentication requirements
4. Generate comprehensive API docs

Format as markdown with a table of contents."""
        }],
        tools=[{"type": "mcp", "server_url": MCP_URL, "token": MCP_TOKEN}]
    )

    for content in response.content:
        if hasattr(content, 'text'):
            return content.text

    return ""

def generate_openapi_spec(project_path: str = ".") -> str:
    """Generate OpenAPI/Swagger specification."""

    response = client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=8192,
        system="""You generate OpenAPI 3.0 specifications.

        Create valid OpenAPI YAML with:
        - Info section with title, description, version
        - Servers section
        - Paths with all operations
        - Request bodies with schemas
        - Response schemas
        - Security definitions
        - Components for reusable schemas

        Infer types from code. Use realistic examples.
        Follow OpenAPI 3.0 specification exactly.""",
        messages=[{
            "role": "user",
            "content": f"""Generate OpenAPI spec for {project_path}.

1. Find all API routes
2. Analyze each endpoint's implementation
3. Extract request/response types
4. Generate valid OpenAPI 3.0 YAML

Output only the YAML content."""
        }],
        tools=[{"type": "mcp", "server_url": MCP_URL, "token": MCP_TOKEN}]
    )

    for content in response.content:
        if hasattr(content, 'text'):
            return content.text

    return ""
```

## Step 4: Function documentation

```python
def document_functions(file_path: str) -> str:
    """Generate docstrings for functions in a file."""

    response = client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=4096,
        system="""You write function documentation.

        For each function, create a docstring that includes:
        - One-line summary
        - Detailed description (if complex)
        - Args with types and descriptions
        - Returns with type and description
        - Raises for exceptions
        - Example usage (for public functions)

        Match the project's documentation style if one exists.
        Use Google-style docstrings for Python.
        Use JSDoc for JavaScript/TypeScript.""",
        messages=[{
            "role": "user",
            "content": f"""Generate documentation for functions in {file_path}.

1. Read the file
2. For each function without documentation:
   - Analyze what it does
   - Identify parameters and return types
   - Write appropriate docstring
3. Output the file with added documentation"""
        }],
        tools=[{"type": "mcp", "server_url": MCP_URL, "token": MCP_TOKEN}]
    )

    for content in response.content:
        if hasattr(content, 'text'):
            return content.text

    return ""

def generate_type_docs(project_path: str = ".") -> str:
    """Generate documentation for types and interfaces."""

    response = client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=4096,
        system="""You document types and data structures.

        For each type/interface/class:
        - Purpose and when to use it
        - Properties with descriptions
        - Methods (for classes)
        - Related types
        - Example instantiation

        Group related types together.
        Show inheritance relationships.""",
        messages=[{
            "role": "user",
            "content": f"""Document types in {project_path}.

1. Find type definition files
2. For each type, document:
   - What it represents
   - Each property
   - How it's used
3. Output as markdown documentation"""
        }],
        tools=[{"type": "mcp", "server_url": MCP_URL, "token": MCP_TOKEN}]
    )

    for content in response.content:
        if hasattr(content, 'text'):
            return content.text

    return ""
```

## Step 5: Changelog generator

```python
def generate_changelog(since: str = None, version: str = None) -> str:
    """Generate changelog from git commits."""

    response = client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=2048,
        system="""You write changelogs.

        Format following Keep a Changelog (keepachangelog.com):
        - Group by: Added, Changed, Deprecated, Removed, Fixed, Security
        - Be specific but concise
        - Include issue/PR references if available
        - User-focused, not implementation details

        Turn commit messages into user-readable changes.
        Combine related commits into single entries.
        Skip internal changes users don't care about.""",
        messages=[{
            "role": "user",
            "content": f"""Generate changelog{' for version ' + version if version else ''}{' since ' + since if since else ''}.

1. Use git_log to get recent commits{' since ' + since if since else ''}
2. Group commits by type (feature, fix, etc.)
3. Write user-friendly descriptions
4. Format as Keep a Changelog markdown

Output the changelog content."""
        }],
        tools=[{"type": "mcp", "server_url": MCP_URL, "token": MCP_TOKEN}]
    )

    for content in response.content:
        if hasattr(content, 'text'):
            return content.text

    return ""

def update_changelog(new_version: str) -> str:
    """Add new version to existing changelog."""

    response = client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=2048,
        system="""You update changelogs.

        - Read existing CHANGELOG.md
        - Add new version at the top
        - Keep existing entries unchanged
        - Follow existing format and style""",
        messages=[{
            "role": "user",
            "content": f"""Add version {new_version} to CHANGELOG.md.

1. Read existing CHANGELOG.md
2. Get commits since last version tag
3. Generate new version entry
4. Insert at top, after header
5. Output complete updated changelog"""
        }],
        tools=[{"type": "mcp", "server_url": MCP_URL, "token": MCP_TOKEN}]
    )

    for content in response.content:
        if hasattr(content, 'text'):
            return content.text

    return ""
```

## Step 6: Architecture documentation

```python
def generate_architecture_docs(project_path: str = ".") -> str:
    """Generate architecture documentation."""

    response = client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=4096,
        system="""You document software architecture.

        Include:
        - High-level system overview
        - Component diagram (describe in text/mermaid)
        - Data flow
        - Key design decisions
        - Technology stack
        - Directory structure explanation

        Focus on helping new developers understand the system.
        Explain WHY not just WHAT.""",
        messages=[{
            "role": "user",
            "content": f"""Generate architecture documentation for {project_path}.

1. Analyze the directory structure
2. Read key files to understand components
3. Identify patterns and architecture style
4. Generate comprehensive architecture doc

Include a mermaid diagram for visual representation."""
        }],
        tools=[{"type": "mcp", "server_url": MCP_URL, "token": MCP_TOKEN}]
    )

    for content in response.content:
        if hasattr(content, 'text'):
            return content.text

    return ""
```

## Step 7: CLI tool

```python
#!/usr/bin/env python3
"""Documentation Generator CLI."""

import argparse
import os

def main():
    parser = argparse.ArgumentParser(description="AI Documentation Generator")
    subparsers = parser.add_subparsers(dest="command", help="Commands")

    # README
    readme_parser = subparsers.add_parser("readme", help="Generate README")
    readme_parser.add_argument("--update", action="store_true", help="Update existing")
    readme_parser.add_argument("--output", "-o", default="README.md")

    # API docs
    api_parser = subparsers.add_parser("api", help="Generate API docs")
    api_parser.add_argument("--format", choices=["md", "openapi"], default="md")
    api_parser.add_argument("--output", "-o", default="docs/api.md")

    # Function docs
    func_parser = subparsers.add_parser("functions", help="Document functions")
    func_parser.add_argument("file", help="File to document")
    func_parser.add_argument("--output", "-o", help="Output file")

    # Changelog
    log_parser = subparsers.add_parser("changelog", help="Generate changelog")
    log_parser.add_argument("--since", help="Since date or version")
    log_parser.add_argument("--version", "-v", help="New version number")

    # Architecture
    arch_parser = subparsers.add_parser("architecture", help="Architecture docs")
    arch_parser.add_argument("--output", "-o", default="docs/architecture.md")

    # All
    all_parser = subparsers.add_parser("all", help="Generate all documentation")

    args = parser.parse_args()

    if args.command == "readme":
        if args.update:
            content = update_readme()
        else:
            content = generate_readme()

        with open(args.output, "w") as f:
            f.write(content)
        print(f"Generated {args.output}")

    elif args.command == "api":
        if args.format == "openapi":
            content = generate_openapi_spec()
            output = args.output.replace(".md", ".yaml")
        else:
            content = generate_api_docs()
            output = args.output

        os.makedirs(os.path.dirname(output) or ".", exist_ok=True)
        with open(output, "w") as f:
            f.write(content)
        print(f"Generated {output}")

    elif args.command == "functions":
        content = document_functions(args.file)
        output = args.output or args.file
        with open(output, "w") as f:
            f.write(content)
        print(f"Documented {output}")

    elif args.command == "changelog":
        if args.version:
            content = update_changelog(args.version)
        else:
            content = generate_changelog(args.since)
        print(content)

    elif args.command == "architecture":
        content = generate_architecture_docs()
        os.makedirs(os.path.dirname(args.output) or ".", exist_ok=True)
        with open(args.output, "w") as f:
            f.write(content)
        print(f"Generated {args.output}")

    elif args.command == "all":
        print("Generating all documentation...")

        # README
        readme = generate_readme()
        with open("README.md", "w") as f:
            f.write(readme)
        print("✓ README.md")

        # API docs
        api_docs = generate_api_docs()
        os.makedirs("docs", exist_ok=True)
        with open("docs/api.md", "w") as f:
            f.write(api_docs)
        print("✓ docs/api.md")

        # Architecture
        arch = generate_architecture_docs()
        with open("docs/architecture.md", "w") as f:
            f.write(arch)
        print("✓ docs/architecture.md")

        print("Documentation complete!")

    else:
        parser.print_help()

if __name__ == "__main__":
    main()
```

Usage:

```bash
# Generate README
./docgen.py readme

# Update existing README
./docgen.py readme --update

# Generate API documentation
./docgen.py api

# Generate OpenAPI spec
./docgen.py api --format openapi

# Document a specific file
./docgen.py functions src/utils.py

# Generate changelog
./docgen.py changelog --version 1.2.0

# Generate architecture docs
./docgen.py architecture

# Generate everything
./docgen.py all
```

## CI/CD integration

Automate docs on every release:

```yaml
# .github/workflows/docs.yml
name: Update Documentation

on:
  push:
    branches: [main]
  release:
    types: [published]

jobs:
  docs:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Setup Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.11'

      - name: Install dependencies
        run: pip install anthropic requests

      - name: Generate documentation
        env:
          ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
          MCP_URL: ${{ secrets.MCP_URL }}
          MCP_TOKEN: ${{ secrets.MCP_TOKEN }}
        run: |
          # Update README
          python docgen.py readme --update

          # Update API docs
          python docgen.py api

          # Update changelog on release
          if [ "${{ github.event_name }}" == "release" ]; then
            python docgen.py changelog --version ${{ github.event.release.tag_name }}
          fi

      - name: Commit changes
        run: |
          git config user.name "Documentation Bot"
          git config user.email "bot@example.com"
          git add -A
          git diff --cached --quiet || git commit -m "docs: update documentation"
          git push
```

## Tips for better documentation

### 1. Keep context small

Don't try to document everything at once:

```python
# Good: Document one module at a time
document_functions("src/auth/login.py")

# Bad: Try to document entire codebase
document_functions("src/")  # Too much context
```

### 2. Preserve human content

```python
PRESERVE_MARKERS = """
When updating docs, preserve:
- <!-- custom --> ... <!-- /custom --> blocks
- Sections marked "DO NOT AUTO-UPDATE"
- Personal notes and acknowledgments
- Project badges and shields
"""
```

### 3. Match project style

```python
# Include existing docs in context
existing_readme = read_file("README.md")
prompt = f"""
Match the style of this existing README:
{existing_readme}

Generate new content for...
"""
```

### 4. Validate output

```python
def validate_markdown(content: str) -> bool:
    """Basic markdown validation."""
    issues = []

    # Check for broken links
    links = re.findall(r'\[([^\]]+)\]\(([^\)]+)\)', content)
    for text, url in links:
        if not url.startswith(('http', '/', '#')):
            issues.append(f"Possibly broken link: {url}")

    # Check for unclosed code blocks
    if content.count('```') % 2 != 0:
        issues.append("Unclosed code block")

    return len(issues) == 0, issues
```

## Summary

AI documentation generation:

1. **README files** - Project overview and quick start
2. **API documentation** - Endpoints, parameters, responses
3. **Function docs** - Docstrings and type documentation
4. **Changelogs** - Release notes from commits
5. **Architecture** - System design and decisions

Build tools with [Gantz](https://gantz.run), keep docs in sync automatically.

Documentation that writes itself. Finally.

## Related reading

- [Build an AI Code Reviewer](/post/code-review-agents/) - Code review automation
- [Git Automation with MCP](/post/git-automation/) - Git operations
- [Automate CI/CD with AI](/post/cicd-agents/) - Pipeline integration

---

*How do you keep documentation updated? Share your approach.*
