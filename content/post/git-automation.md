+++
title = "Git Automation: Let AI Manage Your Repositories"
image = "images/git-automation.webp"
date = 2025-11-01
description = "Automate Git workflows with AI agents. Auto-generate commit messages, manage branches, resolve conflicts, and maintain repositories."
draft = false
tags = ['mcp', 'tutorial', 'automation']
voice = false

[howto]
name = "Automate Git with AI"
totalTime = 25
[[howto.steps]]
name = "Create Git MCP tools"
text = "Build tools for common Git operations."
[[howto.steps]]
name = "Set up the agent"
text = "Configure an agent with Git repository context."
[[howto.steps]]
name = "Automate commit messages"
text = "Let AI generate meaningful commit messages."
[[howto.steps]]
name = "Automate branch management"
text = "Use AI to create, merge, and clean up branches."
[[howto.steps]]
name = "Handle conflicts"
text = "Get AI assistance resolving merge conflicts."
+++


Writing commit messages. Managing branches. Resolving conflicts.

Git work that doesn't require creativity. Perfect for AI.

## What can be automated?

- **Commit messages**: Generate from diff
- **Branch names**: Create from issue/task description
- **PR descriptions**: Summarize changes automatically
- **Conflict resolution**: Suggest solutions
- **Branch cleanup**: Identify and remove stale branches
- **Changelog generation**: Compile from commits

## Step 1: Create Git MCP tools

Using [Gantz](https://gantz.run):

```yaml
# gantz.yaml
name: git-tools

tools:
  - name: git_status
    description: Get the current Git status
    script:
      shell: git status --porcelain

  - name: git_diff
    description: Get the diff of staged or unstaged changes
    parameters:
      - name: staged
        type: boolean
        default: false
    script:
      shell: |
        if [ "{{staged}}" = "true" ]; then
          git diff --cached
        else
          git diff
        fi

  - name: git_log
    description: Get recent commit history
    parameters:
      - name: count
        type: integer
        default: 10
      - name: format
        type: string
        default: "%h %s"
    script:
      shell: git log -{{count}} --pretty=format:"{{format}}"

  - name: git_commit
    description: Create a commit with a message
    parameters:
      - name: message
        type: string
        required: true
    script:
      shell: git commit -m "{{message}}"

  - name: git_add
    description: Stage files for commit
    parameters:
      - name: files
        type: string
        default: "."
    script:
      shell: git add {{files}}

  - name: git_branch
    description: List, create, or switch branches
    parameters:
      - name: action
        type: string
        default: "list"
      - name: name
        type: string
    script:
      shell: |
        case "{{action}}" in
          list) git branch -a ;;
          create) git checkout -b "{{name}}" ;;
          switch) git checkout "{{name}}" ;;
          delete) git branch -d "{{name}}" ;;
        esac

  - name: git_stash
    description: Stash or apply stashed changes
    parameters:
      - name: action
        type: string
        default: "push"
    script:
      shell: git stash {{action}}

  - name: git_merge
    description: Merge a branch into current branch
    parameters:
      - name: branch
        type: string
        required: true
    script:
      shell: git merge {{branch}}

  - name: git_conflicts
    description: List files with merge conflicts
    script:
      shell: git diff --name-only --diff-filter=U

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

```bash
gantz run --auth
```

## Step 2: Auto-generate commit messages

```python
import anthropic

MCP_URL = "https://git-tools.gantz.run/sse"
MCP_TOKEN = "gtz_abc123"

client = anthropic.Anthropic()

def generate_commit_message():
    """Generate a commit message from staged changes."""

    response = client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=500,
        system="""You are a Git commit message generator.
        Generate clear, conventional commit messages following this format:
        <type>(<scope>): <description>

        Types: feat, fix, docs, style, refactor, test, chore
        Keep the description under 50 characters.
        Add a body if the changes are complex.

        Examples:
        - feat(auth): add JWT token validation
        - fix(api): handle null response from server
        - docs(readme): update installation instructions
        """,
        messages=[{
            "role": "user",
            "content": """Look at the staged changes using git_diff (staged=true).
            Generate an appropriate commit message based on what changed.
            Only output the commit message, nothing else."""
        }],
        tools=[{"type": "mcp", "server_url": MCP_URL, "token": MCP_TOKEN}]
    )

    # Extract the commit message from response
    for content in response.content:
        if hasattr(content, 'text'):
            return content.text.strip()

    return None

def smart_commit():
    """Stage all changes and commit with AI-generated message."""

    # First, stage changes
    response = client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=1000,
        messages=[{
            "role": "user",
            "content": """
            1. Use git_status to see what files changed
            2. Use git_add to stage all changes
            3. Use git_diff with staged=true to see what will be committed
            4. Generate a commit message based on the changes
            5. Use git_commit with that message
            6. Report what you did
            """
        }],
        tools=[{"type": "mcp", "server_url": MCP_URL, "token": MCP_TOKEN}]
    )

    for content in response.content:
        if hasattr(content, 'text'):
            print(content.text)
```

## Step 3: Smart branch management

```python
def create_feature_branch(description: str):
    """Create a branch with a good name from description."""

    response = client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=500,
        system="""Generate Git branch names following these conventions:
        - feature/short-description
        - fix/issue-description
        - chore/maintenance-task

        Use lowercase, hyphens for spaces, keep it short but descriptive.
        """,
        messages=[{
            "role": "user",
            "content": f"""
            Create a new branch for this task: {description}

            1. Generate an appropriate branch name
            2. Use git_branch with action=create and the name
            3. Confirm the branch was created
            """
        }],
        tools=[{"type": "mcp", "server_url": MCP_URL, "token": MCP_TOKEN}]
    )

    for content in response.content:
        if hasattr(content, 'text'):
            print(content.text)

def cleanup_branches():
    """Find and remove stale branches."""

    response = client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=1000,
        messages=[{
            "role": "user",
            "content": """
            Help me clean up Git branches:

            1. Use git_branch to list all branches
            2. Use git_log to check when each branch was last updated
            3. Identify branches that:
               - Are already merged to main
               - Haven't been updated in over 30 days
               - Look like abandoned feature branches
            4. List the branches you recommend deleting
            5. Ask before actually deleting anything

            Don't delete main, master, develop, or release branches.
            """
        }],
        tools=[{"type": "mcp", "server_url": MCP_URL, "token": MCP_TOKEN}]
    )

    for content in response.content:
        if hasattr(content, 'text'):
            print(content.text)
```

## Step 4: Conflict resolution assistant

```python
def resolve_conflicts():
    """Help resolve merge conflicts."""

    response = client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=2000,
        system="""You are a Git conflict resolution assistant.
        When analyzing conflicts:
        1. Understand what both sides were trying to do
        2. Determine if changes can be combined or if one should win
        3. Explain your reasoning
        4. Provide the resolved code

        Common patterns:
        - Both sides added to the same list → combine them
        - Both modified the same function → understand intent, merge logic
        - One side deleted, one modified → usually keep the modification
        """,
        messages=[{
            "role": "user",
            "content": """
            There are merge conflicts. Please help resolve them:

            1. Use git_conflicts to see which files have conflicts
            2. For each file with conflicts:
               a. Use read_file to see the current state
               b. Analyze the conflict markers (<<<<<<<, =======, >>>>>>>)
               c. Explain what each side changed
               d. Propose a resolution
               e. Use write_file to save the resolved version
            3. After resolving all conflicts, use git_add to stage them

            Show me your analysis and the resolved code for each file.
            """
        }],
        tools=[{"type": "mcp", "server_url": MCP_URL, "token": MCP_TOKEN}]
    )

    for content in response.content:
        if hasattr(content, 'text'):
            print(content.text)
```

## Step 5: PR description generator

```python
def generate_pr_description(base_branch: str = "main"):
    """Generate a PR description from commits."""

    response = client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=1500,
        system="""Generate GitHub PR descriptions with:
        ## Summary
        Brief description of changes

        ## Changes
        - Bullet points of what changed

        ## Testing
        How to test the changes

        ## Screenshots (if applicable)
        Placeholder for UI changes
        """,
        messages=[{
            "role": "user",
            "content": f"""
            Generate a PR description for merging into {base_branch}:

            1. Use git_log to see commits on this branch (not on {base_branch})
            2. Use git_diff to see all changes compared to {base_branch}
            3. Analyze the changes and generate a comprehensive PR description
            4. Include:
               - What the changes do
               - Why they were made (infer from commit messages/code)
               - Any breaking changes or migration notes
               - Testing instructions

            Output the PR description in markdown format.
            """
        }],
        tools=[{"type": "mcp", "server_url": MCP_URL, "token": MCP_TOKEN}]
    )

    for content in response.content:
        if hasattr(content, 'text'):
            print(content.text)
```

## CLI tool

Create a command-line interface:

```python
#!/usr/bin/env python3
"""Git AI Assistant CLI."""

import sys
import argparse

def main():
    parser = argparse.ArgumentParser(description="Git AI Assistant")
    subparsers = parser.add_subparsers(dest="command", help="Commands")

    # Commit command
    commit_parser = subparsers.add_parser("commit", help="Smart commit")
    commit_parser.add_argument("--all", "-a", action="store_true",
                               help="Stage all changes")

    # Branch commands
    branch_parser = subparsers.add_parser("branch", help="Branch operations")
    branch_parser.add_argument("action", choices=["create", "cleanup"])
    branch_parser.add_argument("--description", "-d", help="Branch description")

    # Conflict resolution
    subparsers.add_parser("resolve", help="Resolve merge conflicts")

    # PR description
    pr_parser = subparsers.add_parser("pr", help="Generate PR description")
    pr_parser.add_argument("--base", "-b", default="main",
                          help="Base branch")

    args = parser.parse_args()

    if args.command == "commit":
        smart_commit()
    elif args.command == "branch":
        if args.action == "create":
            create_feature_branch(args.description or "new feature")
        elif args.action == "cleanup":
            cleanup_branches()
    elif args.command == "resolve":
        resolve_conflicts()
    elif args.command == "pr":
        generate_pr_description(args.base)
    else:
        parser.print_help()

if __name__ == "__main__":
    main()
```

Usage:

```bash
# Smart commit with AI-generated message
./git-ai commit --all

# Create branch from description
./git-ai branch create -d "Add user authentication with OAuth"

# Clean up stale branches
./git-ai branch cleanup

# Resolve merge conflicts
./git-ai resolve

# Generate PR description
./git-ai pr --base main
```

## Git hooks integration

Add AI to Git hooks:

```bash
# .git/hooks/prepare-commit-msg
#!/bin/bash

# Only run if no message provided
if [ -z "$(cat $1)" ]; then
    # Generate message with AI
    message=$(python git-ai commit --generate-only)
    echo "$message" > $1
fi
```

```bash
# .git/hooks/pre-push
#!/bin/bash

# Check for common issues before push
python git-ai check --pre-push

if [ $? -ne 0 ]; then
    echo "AI found issues. Review and fix before pushing."
    exit 1
fi
```

## Summary

AI-powered Git automation:

1. **Commit messages** - Generate from diff automatically
2. **Branch names** - Create meaningful names from descriptions
3. **PR descriptions** - Summarize changes comprehensively
4. **Conflict resolution** - Get intelligent merge suggestions
5. **Branch cleanup** - Find and remove stale branches

Build tools with [Gantz](https://gantz.run), use them from CLI or hooks.

Less Git busywork, more actual coding.

## Related reading

- [Automate CI/CD with AI](/post/cicd-agents/) - Pipeline automation
- [Build an AI Code Reviewer](/post/code-review-agents/) - PR reviews
- [Trigger Agents from Webhooks](/post/webhook-mcp/) - GitHub events

---

*How do you automate Git workflows? Share your approach.*
