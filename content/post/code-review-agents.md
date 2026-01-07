+++
title = "Build an AI Code Reviewer That Actually Works"
image = "/images/code-review-agents.png"
date = 2025-11-06
description = "Create an automated code review agent using MCP tools. Analyze PRs for bugs, security issues, and style violations automatically."
draft = false
tags = ['mcp', 'tutorial', 'code-review']
voice = false

[howto]
name = "Build AI Code Reviewer"
totalTime = 35
[[howto.steps]]
name = "Create code analysis tools"
text = "Build MCP tools for reading diffs, checking patterns, and analyzing code."
[[howto.steps]]
name = "Design review prompts"
text = "Create effective prompts for different review aspects."
[[howto.steps]]
name = "Implement review agent"
text = "Build the agent that orchestrates the review process."
[[howto.steps]]
name = "Integrate with GitHub"
text = "Connect the reviewer to pull requests via webhooks."
[[howto.steps]]
name = "Fine-tune feedback"
text = "Adjust prompts for constructive, actionable reviews."
+++


Automated code reviews that developers actually appreciate.

Not the ones that nitpick every space. The ones that catch real issues.

Here's how to build one with MCP.

## Why AI code review?

Human reviewers are valuable. But they:
- Have limited time
- Miss patterns across large PRs
- Review inconsistently
- Take time zones to respond

AI reviewers can:
- Check every PR instantly
- Apply consistent standards
- Catch patterns humans miss
- Never get tired

The goal: AI handles the mechanical checks, humans focus on architecture and design.

## What good AI review looks like

**Bad AI review:**
```
Line 45: Consider using const instead of let.
Line 67: Missing semicolon.
Line 89: Function could be shorter.
```

**Good AI review:**
```
## Security Issue
Line 45-52: The user input is passed directly to the SQL query
without sanitization. This creates a SQL injection vulnerability.

**Suggestion:** Use parameterized queries:
```sql
db.query('SELECT * FROM users WHERE id = ?', [userId])
```

## Logic Bug
Line 89: The loop condition `i <= arr.length` will cause an
off-by-one error, accessing undefined on the last iteration.

**Fix:** Change to `i < arr.length`
```

Focus on issues that matter. Provide fixes, not just complaints.

## Step 1: Create code analysis tools

Using [Gantz](https://gantz.run):

```yaml
# gantz.yaml
name: code-reviewer

tools:
  - name: get_pr_diff
    description: Get the diff for a pull request
    parameters:
      - name: repo
        type: string
        required: true
        description: Repository in owner/repo format
      - name: pr_number
        type: integer
        required: true
    script:
      shell: |
        gh pr diff {{pr_number}} --repo {{repo}}

  - name: get_pr_files
    description: List files changed in a PR
    parameters:
      - name: repo
        type: string
        required: true
      - name: pr_number
        type: integer
        required: true
    script:
      shell: |
        gh pr view {{pr_number}} --repo {{repo}} --json files --jq '.files[].path'

  - name: get_file_content
    description: Get the full content of a file at a specific ref
    parameters:
      - name: repo
        type: string
        required: true
      - name: path
        type: string
        required: true
      - name: ref
        type: string
        default: "HEAD"
    script:
      shell: |
        gh api repos/{{repo}}/contents/{{path}}?ref={{ref}} --jq '.content' | base64 -d

  - name: post_review_comment
    description: Post a review comment on a PR
    parameters:
      - name: repo
        type: string
        required: true
      - name: pr_number
        type: integer
        required: true
      - name: body
        type: string
        required: true
      - name: path
        type: string
      - name: line
        type: integer
    script:
      shell: |
        if [ -n "{{path}}" ] && [ -n "{{line}}" ]; then
          gh api repos/{{repo}}/pulls/{{pr_number}}/comments \
            -f body="{{body}}" \
            -f path="{{path}}" \
            -F line={{line}} \
            -f side="RIGHT"
        else
          gh pr comment {{pr_number}} --repo {{repo}} --body "{{body}}"
        fi

  - name: submit_review
    description: Submit the final review with approval status
    parameters:
      - name: repo
        type: string
        required: true
      - name: pr_number
        type: integer
        required: true
      - name: body
        type: string
        required: true
      - name: event
        type: string
        default: "COMMENT"
        description: "APPROVE, REQUEST_CHANGES, or COMMENT"
    script:
      shell: |
        gh api repos/{{repo}}/pulls/{{pr_number}}/reviews \
          -f body="{{body}}" \
          -f event="{{event}}"

  - name: get_pr_context
    description: Get PR title, description, and metadata
    parameters:
      - name: repo
        type: string
        required: true
      - name: pr_number
        type: integer
        required: true
    script:
      shell: |
        gh pr view {{pr_number}} --repo {{repo}} --json title,body,author,labels,baseRefName,headRefName

  - name: check_patterns
    description: Search for specific patterns in code
    parameters:
      - name: pattern
        type: string
        required: true
        description: Regex pattern to search for
      - name: path
        type: string
        default: "."
    script:
      shell: |
        rg "{{pattern}}" {{path}} --json || echo "[]"
```

```bash
gantz run --auth
```

## Step 2: The review agent

```python
import anthropic
import json
from typing import Optional

MCP_URL = "https://code-reviewer.gantz.run/sse"
MCP_TOKEN = "gtz_abc123"

client = anthropic.Anthropic()

REVIEW_SYSTEM_PROMPT = """You are an expert code reviewer. Your reviews are:

1. **Focused on impact**: Only comment on issues that matter
   - Security vulnerabilities (critical)
   - Bugs and logic errors (high)
   - Performance issues (medium)
   - Maintainability concerns (low)

2. **Constructive**: Always provide solutions, not just problems
   - Show the fix, not just the issue
   - Explain why it matters
   - Be respectful and helpful

3. **Contextual**: Consider the PR's purpose
   - A quick fix doesn't need architectural critique
   - A new feature should have tests
   - Refactoring shouldn't change behavior

4. **Concise**: Don't over-explain
   - Developers are smart
   - Get to the point
   - Skip obvious style issues (let linters handle those)

Severity levels:
- 🔴 Critical: Security issues, data loss risks, crashes
- 🟠 High: Bugs, race conditions, incorrect logic
- 🟡 Medium: Performance issues, missing error handling
- 🔵 Low: Suggestions, minor improvements

When you find no significant issues, say so briefly and approve."""

def review_pr(repo: str, pr_number: int) -> str:
    """Perform a comprehensive code review."""

    response = client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=4096,
        system=REVIEW_SYSTEM_PROMPT,
        messages=[{
            "role": "user",
            "content": f"""Review PR #{pr_number} in {repo}.

Steps:
1. Use get_pr_context to understand what this PR is trying to do
2. Use get_pr_files to see which files changed
3. Use get_pr_diff to see the actual changes
4. For complex changes, use get_file_content to see full context
5. Analyze for:
   - Security issues (SQL injection, XSS, secrets, auth bypass)
   - Bugs (null references, off-by-one, race conditions)
   - Logic errors (wrong conditions, missing cases)
   - Performance (N+1 queries, unnecessary loops)
   - Error handling (uncaught exceptions, missing validation)
6. Use post_review_comment for inline feedback on specific lines
7. Use submit_review for the overall summary

Remember:
- Be constructive and specific
- Provide code examples for fixes
- Don't nitpick style (that's what linters are for)
- Consider the context and purpose of the changes"""
        }],
        tools=[{"type": "mcp", "server_url": MCP_URL, "token": MCP_TOKEN}]
    )

    # Extract final response
    for content in response.content:
        if hasattr(content, 'text'):
            return content.text

    return "Review completed"

def quick_security_scan(repo: str, pr_number: int) -> str:
    """Quick scan for security issues only."""

    response = client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=2048,
        system="""You are a security-focused code reviewer.

        Look specifically for:
        - SQL injection vulnerabilities
        - Cross-site scripting (XSS)
        - Authentication/authorization bypasses
        - Hardcoded secrets or credentials
        - Insecure deserialization
        - Path traversal vulnerabilities
        - Command injection
        - Insecure cryptographic usage

        If you find security issues, they must be addressed before merge.
        Be specific about the vulnerability and how to fix it.""",
        messages=[{
            "role": "user",
            "content": f"""Security scan PR #{pr_number} in {repo}.

1. Use get_pr_diff to see the changes
2. Use check_patterns to search for dangerous patterns:
   - SQL: query, execute, raw
   - Secrets: password, api_key, secret, token
   - Injection: eval, exec, system, shell
3. Flag any security concerns with severity
4. Provide specific remediation steps"""
        }],
        tools=[{"type": "mcp", "server_url": MCP_URL, "token": MCP_TOKEN}]
    )

    for content in response.content:
        if hasattr(content, 'text'):
            return content.text

    return "Security scan completed"
```

## Step 3: Specialized reviewers

Different aspects need different prompts:

```python
def review_tests(repo: str, pr_number: int) -> str:
    """Review test coverage and quality."""

    response = client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=2048,
        system="""You review test code specifically.

        Check for:
        - Test coverage: Are new features tested?
        - Test quality: Do tests actually verify behavior?
        - Edge cases: Are boundaries and errors tested?
        - Test isolation: Can tests run independently?
        - Mocking: Is mocking used appropriately?
        - Naming: Do test names describe what they test?

        Missing tests for new functionality is a blocker.
        Poor test quality is worth mentioning but not blocking.""",
        messages=[{
            "role": "user",
            "content": f"""Review tests in PR #{pr_number} in {repo}.

1. Get the diff and identify test files
2. Check if new code has corresponding tests
3. Evaluate test quality and coverage
4. Suggest missing test cases if needed"""
        }],
        tools=[{"type": "mcp", "server_url": MCP_URL, "token": MCP_TOKEN}]
    )

    for content in response.content:
        if hasattr(content, 'text'):
            return content.text

    return "Test review completed"

def review_performance(repo: str, pr_number: int) -> str:
    """Review for performance issues."""

    response = client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=2048,
        system="""You are a performance-focused reviewer.

        Look for:
        - N+1 query patterns
        - Unnecessary iterations over large collections
        - Missing pagination
        - Inefficient algorithms
        - Memory leaks (unreleased resources)
        - Blocking operations in async contexts
        - Missing caching opportunities
        - Large payload sizes

        Focus on patterns that will cause problems at scale.
        Minor optimizations aren't worth blocking a PR.""",
        messages=[{
            "role": "user",
            "content": f"""Performance review PR #{pr_number} in {repo}.

1. Analyze the diff for performance patterns
2. Look for database queries in loops
3. Check for expensive operations
4. Suggest optimizations where impactful"""
        }],
        tools=[{"type": "mcp", "server_url": MCP_URL, "token": MCP_TOKEN}]
    )

    for content in response.content:
        if hasattr(content, 'text'):
            return content.text

    return "Performance review completed"

def review_architecture(repo: str, pr_number: int) -> str:
    """Review architectural concerns for larger PRs."""

    response = client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=2048,
        system="""You review code architecture and design.

        Consider:
        - Does this follow existing patterns in the codebase?
        - Is the code in the right place?
        - Are abstractions appropriate?
        - Is there unnecessary coupling?
        - Will this be maintainable long-term?
        - Are there simpler alternatives?

        For small PRs, architectural concerns rarely apply.
        For large features, suggest improvements constructively.""",
        messages=[{
            "role": "user",
            "content": f"""Architectural review PR #{pr_number} in {repo}.

1. Understand the scope and purpose of changes
2. Evaluate if the approach fits the codebase
3. Suggest structural improvements if warranted
4. Only flag issues that significantly impact maintainability"""
        }],
        tools=[{"type": "mcp", "server_url": MCP_URL, "token": MCP_TOKEN}]
    )

    for content in response.content:
        if hasattr(content, 'text'):
            return content.text

    return "Architecture review completed"
```

## Step 4: GitHub webhook integration

Connect to GitHub via webhooks:

```python
from flask import Flask, request, jsonify
import hmac
import hashlib

app = Flask(__name__)

WEBHOOK_SECRET = "your-webhook-secret"

def verify_signature(payload, signature):
    expected = 'sha256=' + hmac.new(
        WEBHOOK_SECRET.encode(),
        payload,
        hashlib.sha256
    ).hexdigest()
    return hmac.compare_digest(expected, signature)

@app.route("/webhook", methods=["POST"])
def github_webhook():
    # Verify signature
    signature = request.headers.get("X-Hub-Signature-256", "")
    if not verify_signature(request.data, signature):
        return jsonify({"error": "Invalid signature"}), 401

    event = request.headers.get("X-GitHub-Event")
    payload = request.json

    if event == "pull_request":
        action = payload.get("action")

        if action in ["opened", "synchronize"]:
            pr = payload["pull_request"]
            repo = payload["repository"]["full_name"]
            pr_number = pr["number"]

            # Determine review depth based on PR size
            changed_files = pr.get("changed_files", 0)
            additions = pr.get("additions", 0)

            print(f"Reviewing PR #{pr_number} in {repo}")
            print(f"Changed files: {changed_files}, Additions: {additions}")

            # Always run security scan
            security_result = quick_security_scan(repo, pr_number)

            # Full review for larger PRs
            if changed_files > 5 or additions > 200:
                review_result = review_pr(repo, pr_number)
                test_result = review_tests(repo, pr_number)

                # Architecture review for very large changes
                if changed_files > 20 or additions > 1000:
                    arch_result = review_architecture(repo, pr_number)
            else:
                review_result = review_pr(repo, pr_number)

            return jsonify({"status": "reviewed"})

    return jsonify({"status": "ignored"})

if __name__ == "__main__":
    app.run(port=5000)
```

## Step 5: The complete CLI tool

```python
#!/usr/bin/env python3
"""AI Code Reviewer CLI."""

import argparse
import anthropic

MCP_URL = "https://code-reviewer.gantz.run/sse"
MCP_TOKEN = "gtz_abc123"

client = anthropic.Anthropic()

def main():
    parser = argparse.ArgumentParser(description="AI Code Reviewer")
    parser.add_argument("repo", help="Repository (owner/repo)")
    parser.add_argument("pr", type=int, help="PR number")
    parser.add_argument("--type", choices=["full", "security", "tests", "performance", "architecture"],
                        default="full", help="Type of review")
    parser.add_argument("--approve", action="store_true", help="Auto-approve if no issues")

    args = parser.parse_args()

    print(f"Reviewing PR #{args.pr} in {args.repo}...")

    if args.type == "full":
        result = review_pr(args.repo, args.pr)
    elif args.type == "security":
        result = quick_security_scan(args.repo, args.pr)
    elif args.type == "tests":
        result = review_tests(args.repo, args.pr)
    elif args.type == "performance":
        result = review_performance(args.repo, args.pr)
    elif args.type == "architecture":
        result = review_architecture(args.repo, args.pr)

    print(result)

if __name__ == "__main__":
    main()
```

Usage:

```bash
# Full review
./review.py owner/repo 123

# Security scan only
./review.py owner/repo 123 --type security

# Test coverage review
./review.py owner/repo 123 --type tests

# Performance review
./review.py owner/repo 123 --type performance
```

## Tips for better reviews

### 1. Calibrate severity

Not everything is critical:

```python
SEVERITY_GUIDE = """
🔴 CRITICAL - Must fix before merge:
- Security vulnerabilities
- Data corruption risks
- System crashes
- Authentication bypass

🟠 HIGH - Should fix before merge:
- Logic bugs
- Race conditions
- Missing error handling for likely cases

🟡 MEDIUM - Consider fixing:
- Performance issues
- Code duplication
- Unclear naming

🔵 LOW - Nice to have:
- Style suggestions
- Minor refactoring
- Documentation improvements
"""
```

### 2. Provide context

Always explain why:

```python
# Bad
"Don't use eval()"

# Good
"Using eval() with user input creates a code injection vulnerability.
An attacker could execute arbitrary code by passing `__import__('os').system('rm -rf /')`.
Use ast.literal_eval() for safe evaluation of literals, or json.loads() for JSON."
```

### 3. Show the fix

```python
# Bad
"This SQL query is vulnerable"

# Good
"""This query is vulnerable to SQL injection.

Current code:
```python
query = f"SELECT * FROM users WHERE id = {user_id}"
```

Fixed:
```python
query = "SELECT * FROM users WHERE id = %s"
cursor.execute(query, (user_id,))
```
"""
```

### 4. Know when to approve

```python
APPROVAL_CRITERIA = """
Approve when:
- No security issues
- No obvious bugs
- Code is reasonably clear
- Tests exist for new behavior

Don't block for:
- Style preferences
- Minor improvements
- "I would have done it differently"
- Missing tests for trivial changes
"""
```

## Example review output

```markdown
## AI Code Review Summary

**PR #42**: Add user authentication endpoint

### 🔴 Critical Issues

**SQL Injection in login handler** (auth/login.py:45)
```python
# Current (vulnerable)
cursor.execute(f"SELECT * FROM users WHERE email = '{email}'")

# Fixed
cursor.execute("SELECT * FROM users WHERE email = %s", (email,))
```

### 🟠 High Priority

**Missing rate limiting** (auth/login.py:38)
The login endpoint has no rate limiting, enabling brute force attacks.
Consider adding rate limiting middleware or using a library like `slowapi`.

### 🟡 Suggestions

**Password hashing could be stronger** (auth/utils.py:12)
Currently using MD5. Consider bcrypt or argon2 for better security.

### ✅ What's Good

- Clean separation of auth logic
- Good error messages without leaking info
- Tests cover main success path

### Recommendation: REQUEST_CHANGES

The SQL injection vulnerability must be fixed before merge.
```

## Summary

Building an AI code reviewer:

1. **Create MCP tools** for GitHub operations
2. **Design focused prompts** for different review types
3. **Integrate via webhooks** for automatic reviews
4. **Calibrate feedback** to be constructive and actionable
5. **Know when to approve** vs request changes

Build tools with [Gantz](https://gantz.run), create reviewers that developers appreciate.

The goal isn't to replace human reviewers. It's to free them for the work that matters.

## Related reading

- [Automate CI/CD with AI](/post/cicd-agents/) - Pipeline integration
- [Git Automation with MCP](/post/git-automation/) - Git operations
- [Auto-Generate Documentation](/post/documentation-agents/) - Doc generation

---

*How do you use AI for code review? Share your approach.*
