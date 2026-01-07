+++
title = "Automate CI/CD Pipelines with AI Agents"
image = "images/cicd-agents.webp"
date = 2025-11-02
description = "Use AI agents in CI/CD pipelines for automated code review, test analysis, deployment decisions, and incident response."
draft = false
tags = ['mcp', 'tutorial', 'devops']
voice = false

[howto]
name = "Add AI Agents to CI/CD"
totalTime = 30
[[howto.steps]]
name = "Identify automation opportunities"
text = "Find repetitive CI/CD tasks that benefit from AI analysis."
[[howto.steps]]
name = "Create MCP tools"
text = "Build tools for code analysis, test parsing, and notifications."
[[howto.steps]]
name = "Integrate with CI system"
text = "Add agent calls to GitHub Actions, GitLab CI, or Jenkins."
[[howto.steps]]
name = "Handle agent outputs"
text = "Parse agent responses and take appropriate actions."
[[howto.steps]]
name = "Monitor and iterate"
text = "Track agent performance and improve prompts."
+++


Your CI/CD pipeline runs tests. Deploys code. Sends notifications.

But it doesn't think.

AI agents can change that.

## What agents can do in CI/CD

- **Code review**: Analyze PRs for issues, style, security
- **Test analysis**: Explain failures, suggest fixes
- **Deployment decisions**: Assess risk, recommend rollback
- **Incident response**: Investigate alerts, suggest remediation
- **Documentation**: Update docs based on code changes

## Architecture

```
Code Push → CI Pipeline → AI Agent → MCP Tools → Actions
                │              │          │
            Build/Test    Analyze    Comment/Notify/Deploy
```

The agent runs as a step in your pipeline, analyzes context, and takes actions.

## Step 1: Create MCP tools

Tools for CI/CD automation. Using [Gantz](https://gantz.run):

```yaml
# gantz.yaml
name: cicd-tools

tools:
  - name: analyze_diff
    description: Get the diff for the current PR/commit
    parameters:
      - name: base
        type: string
        default: "main"
    script:
      shell: git diff {{base}}...HEAD

  - name: get_test_results
    description: Get test results from the latest run
    script:
      shell: cat test-results.json

  - name: get_build_logs
    description: Get build logs
    parameters:
      - name: lines
        type: integer
        default: 100
    script:
      shell: tail -n {{lines}} build.log

  - name: comment_on_pr
    description: Add a comment to the current PR
    parameters:
      - name: body
        type: string
        required: true
    script:
      shell: |
        gh pr comment $PR_NUMBER --body "{{body}}"

  - name: add_label
    description: Add a label to the current PR
    parameters:
      - name: label
        type: string
        required: true
    script:
      shell: gh pr edit $PR_NUMBER --add-label "{{label}}"

  - name: request_review
    description: Request a review from a team member
    parameters:
      - name: reviewer
        type: string
        required: true
    script:
      shell: gh pr edit $PR_NUMBER --add-reviewer "{{reviewer}}"

  - name: send_slack_alert
    description: Send an alert to Slack
    parameters:
      - name: channel
        type: string
        required: true
      - name: message
        type: string
        required: true
    script:
      shell: |
        curl -X POST -H "Authorization: Bearer $SLACK_TOKEN" \
          -H "Content-Type: application/json" \
          -d '{"channel": "{{channel}}", "text": "{{message}}"}' \
          https://slack.com/api/chat.postMessage
```

## Step 2: Create the agent script

```python
#!/usr/bin/env python3
"""CI/CD AI Agent - Runs as a pipeline step."""

import os
import sys
import anthropic

MCP_URL = os.environ.get("MCP_URL", "https://cicd-tools.gantz.run/sse")
MCP_TOKEN = os.environ.get("MCP_TOKEN")

def run_agent(task: str, context: str = ""):
    """Run the CI/CD agent with a specific task."""

    client = anthropic.Anthropic()

    system_prompt = f"""You are a CI/CD automation assistant.
    You analyze code changes, test results, and build outputs to help developers.

    Current context:
    - Repository: {os.environ.get('GITHUB_REPOSITORY', 'unknown')}
    - Branch: {os.environ.get('GITHUB_REF_NAME', 'unknown')}
    - PR Number: {os.environ.get('PR_NUMBER', 'N/A')}
    - Commit: {os.environ.get('GITHUB_SHA', 'unknown')[:8]}

    {context}

    Be concise and actionable. Focus on what developers need to know.
    """

    response = client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=4096,
        system=system_prompt,
        messages=[{"role": "user", "content": task}],
        tools=[{"type": "mcp", "server_url": MCP_URL, "token": MCP_TOKEN}]
    )

    # Process response
    result = ""
    for content in response.content:
        if hasattr(content, 'text'):
            result += content.text

    return result

def analyze_pr():
    """Analyze a pull request."""
    task = """
    Please analyze this pull request:

    1. Use analyze_diff to see what changed
    2. Check for:
       - Security issues (hardcoded secrets, SQL injection, etc.)
       - Code quality issues
       - Missing tests for new functionality
       - Breaking changes
    3. Comment on the PR with your findings using comment_on_pr
    4. Add appropriate labels (bug, feature, needs-tests, security, etc.)
    5. If changes look risky, request review from a senior developer

    Be constructive and helpful in your feedback.
    """
    return run_agent(task)

def analyze_test_failures():
    """Analyze why tests failed."""
    task = """
    Tests have failed in this pipeline run.

    1. Use get_test_results to see what failed
    2. Use get_build_logs to get more context
    3. Analyze the failures and identify:
       - Root cause of each failure
       - Whether it's a flaky test or real issue
       - Suggested fixes
    4. Comment on the PR with your analysis
    5. If it seems like a critical issue, alert the team on Slack

    Focus on actionable insights that help developers fix issues quickly.
    """
    return run_agent(task)

def analyze_build_failure():
    """Analyze why the build failed."""
    task = """
    The build has failed.

    1. Use get_build_logs to see what went wrong
    2. Identify the root cause:
       - Dependency issues?
       - Compilation errors?
       - Configuration problems?
    3. Comment on the PR with:
       - What failed
       - Why it failed
       - How to fix it
    4. Add the 'build-failure' label

    Be specific about the error and solution.
    """
    return run_agent(task)

def pre_deploy_check():
    """Check if deployment is safe."""
    task = """
    We're about to deploy to production.

    1. Use analyze_diff to see what's being deployed
    2. Check for:
       - Database migrations that might be risky
       - Breaking API changes
       - Features that should be behind feature flags
       - Anything that needs special attention during deploy
    3. Provide a risk assessment (low/medium/high)
    4. If high risk, alert the team on Slack before proceeding

    Output a clear go/no-go recommendation with reasoning.
    """
    return run_agent(task)

def post_deploy_check():
    """Verify deployment succeeded."""
    task = """
    Deployment just completed.

    1. The deployment logs show the status
    2. If there are any errors or warnings, analyze them
    3. Notify the team on Slack about the deployment status
    4. If anything looks wrong, suggest immediate actions

    Keep the notification concise but informative.
    """
    return run_agent(task)

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: cicd_agent.py <command>")
        print("Commands: analyze-pr, test-failure, build-failure, pre-deploy, post-deploy")
        sys.exit(1)

    command = sys.argv[1]

    commands = {
        "analyze-pr": analyze_pr,
        "test-failure": analyze_test_failures,
        "build-failure": analyze_build_failure,
        "pre-deploy": pre_deploy_check,
        "post-deploy": post_deploy_check,
    }

    if command not in commands:
        print(f"Unknown command: {command}")
        sys.exit(1)

    result = commands[command]()
    print(result)
```

## Step 3: Integrate with GitHub Actions

```yaml
# .github/workflows/ci.yml
name: CI with AI Agent

on:
  pull_request:
    types: [opened, synchronize]
  push:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Run tests
        id: tests
        continue-on-error: true
        run: |
          npm test 2>&1 | tee test-output.log
          npm test -- --json > test-results.json || true

      - name: Run build
        id: build
        continue-on-error: true
        run: |
          npm run build 2>&1 | tee build.log

      - name: AI Analysis
        if: always()
        env:
          ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
          MCP_URL: ${{ secrets.MCP_URL }}
          MCP_TOKEN: ${{ secrets.MCP_TOKEN }}
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          PR_NUMBER: ${{ github.event.pull_request.number }}
        run: |
          pip install anthropic

          if [ "${{ steps.tests.outcome }}" == "failure" ]; then
            python cicd_agent.py test-failure
          elif [ "${{ steps.build.outcome }}" == "failure" ]; then
            python cicd_agent.py build-failure
          elif [ "${{ github.event_name }}" == "pull_request" ]; then
            python cicd_agent.py analyze-pr
          fi

  deploy:
    needs: test
    if: github.ref == 'refs/heads/main' && github.event_name == 'push'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Pre-deploy check
        env:
          ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
          MCP_URL: ${{ secrets.MCP_URL }}
          MCP_TOKEN: ${{ secrets.MCP_TOKEN }}
        run: |
          python cicd_agent.py pre-deploy

      - name: Deploy
        run: ./deploy.sh

      - name: Post-deploy check
        env:
          ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
          MCP_URL: ${{ secrets.MCP_URL }}
          MCP_TOKEN: ${{ secrets.MCP_TOKEN }}
        run: |
          python cicd_agent.py post-deploy
```

## GitLab CI integration

```yaml
# .gitlab-ci.yml
stages:
  - test
  - analyze
  - deploy

test:
  stage: test
  script:
    - npm test -- --json > test-results.json || true
    - npm run build 2>&1 | tee build.log
  artifacts:
    paths:
      - test-results.json
      - build.log
    when: always

ai-analysis:
  stage: analyze
  when: always
  needs: [test]
  script:
    - pip install anthropic
    - |
      if [ -f test-results.json ]; then
        python cicd_agent.py analyze-results
      fi
  variables:
    ANTHROPIC_API_KEY: $ANTHROPIC_API_KEY
    MCP_URL: $MCP_URL
    MCP_TOKEN: $MCP_TOKEN

deploy:
  stage: deploy
  only:
    - main
  script:
    - python cicd_agent.py pre-deploy
    - ./deploy.sh
    - python cicd_agent.py post-deploy
```

## Example outputs

### PR Analysis

```markdown
## AI Code Review

### Summary
This PR adds user authentication using JWT tokens.

### Findings

**Security** ⚠️
- Line 45: JWT secret is hardcoded. Move to environment variable.
- Line 78: Missing rate limiting on login endpoint.

**Code Quality** ✅
- Good separation of concerns
- Tests cover main paths

**Suggestions**
- Add test for token expiration
- Consider adding refresh token support

### Labels Added
- `security`
- `needs-review`

### Requested Reviews
- @security-team
```

### Test Failure Analysis

```markdown
## Test Failure Analysis

### Failed Tests
1. `auth.test.js` - testLoginWithInvalidPassword
2. `auth.test.js` - testTokenExpiration

### Root Cause
The tests are failing because the mock time is not being reset between tests.
Test 1 sets the clock forward, affecting test 2.

### Fix
Add `jest.useRealTimers()` in the `afterEach` hook:

```javascript
afterEach(() => {
  jest.useRealTimers();
});
```

### Confidence
High - This is a common pattern issue with Jest timer mocks.
```

## Best practices

1. **Scope the agent's actions** - Limit what it can do (comment, label) vs what needs human approval (merge, deploy)

2. **Provide context** - Include relevant info in the system prompt (repo, PR, commit)

3. **Handle failures gracefully** - Agent errors shouldn't block the pipeline

4. **Log everything** - Track what the agent did for debugging

5. **Iterate on prompts** - Improve based on actual results

## Summary

AI agents in CI/CD:

1. **Analyze code changes** automatically
2. **Explain failures** with actionable fixes
3. **Assess deployment risk** before production
4. **Notify teams** intelligently
5. **Save developer time** on repetitive analysis

Build tools with [Gantz](https://gantz.run), integrate with any CI system.

Your pipeline becomes smarter, not just faster.

## Related reading

- [Build an AI Code Reviewer](/post/code-review-agents/) - Detailed review agent
- [Git Automation with MCP](/post/git-automation/) - Git operations
- [Trigger Agents from Webhooks](/post/webhook-mcp/) - Event-driven agents

---

*How do you use AI in your CI/CD pipelines? Share your automation.*
