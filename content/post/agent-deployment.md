+++
title = "Deploy AI Agents to Production: Complete Guide"
image = "images/agent-deployment.webp"
date = 2025-11-21
description = "Deploy AI agents to production safely. Docker, Kubernetes, serverless options, environment configuration, and rollout strategies using MCP."
draft = false
tags = ['mcp', 'devops', 'deployment']
voice = false

[howto]
name = "Deploy AI Agents"
totalTime = 40
[[howto.steps]]
name = "Containerize agents"
text = "Package agents with Docker for consistent deployment."
[[howto.steps]]
name = "Configure environments"
text = "Set up staging and production environments."
[[howto.steps]]
name = "Implement health checks"
text = "Add readiness and liveness probes."
[[howto.steps]]
name = "Set up CI/CD"
text = "Automate testing and deployment pipelines."
[[howto.steps]]
name = "Configure rollouts"
text = "Implement safe deployment strategies."
+++


Your agent works locally. Now ship it.

Containers. Infrastructure. Configuration. Rollouts.

Here's the complete deployment guide.

## Deployment considerations for AI

AI agents differ from regular services:
- Higher latency (LLM calls)
- Cost per request (API usage)
- Non-deterministic outputs
- External dependencies (AI APIs)
- Rate limits and quotas

Plan for these in your deployment strategy.

## Step 1: Containerization

```dockerfile
# Dockerfile
FROM python:3.11-slim

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application
COPY . .

# Create non-root user
RUN useradd --create-home appuser && chown -R appuser /app
USER appuser

# Environment variables
ENV PORT=8080
ENV PYTHONUNBUFFERED=1

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:${PORT}/health || exit 1

# Run
EXPOSE ${PORT}
CMD ["python", "main.py"]
```

requirements.txt:
```
anthropic>=0.18.0
flask>=3.0.0
redis>=5.0.0
prometheus-client>=0.19.0
gunicorn>=21.0.0
```

main.py:
```python
from flask import Flask, request, jsonify
import anthropic
import os

app = Flask(__name__)
client = anthropic.Anthropic()

MCP_URL = os.environ.get("MCP_URL")
MCP_TOKEN = os.environ.get("MCP_TOKEN")

@app.route("/health")
def health():
    """Health check endpoint."""
    return jsonify({"status": "healthy"})

@app.route("/ready")
def ready():
    """Readiness check - verify dependencies."""
    try:
        # Check MCP server
        import requests
        resp = requests.get(f"{MCP_URL}/health", timeout=5)
        if resp.status_code != 200:
            return jsonify({"status": "not ready", "reason": "MCP unavailable"}), 503
    except:
        return jsonify({"status": "not ready", "reason": "MCP connection failed"}), 503

    return jsonify({"status": "ready"})

@app.route("/agent", methods=["POST"])
def run_agent():
    """Run the agent."""
    data = request.json
    task = data.get("task")

    response = client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=4096,
        messages=[{"role": "user", "content": task}],
        tools=[{"type": "mcp", "server_url": MCP_URL, "token": MCP_TOKEN}]
    )

    result = ""
    for content in response.content:
        if hasattr(content, 'text'):
            result += content.text

    return jsonify({"result": result})

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8080))
    app.run(host="0.0.0.0", port=port)
```

Build and test:
```bash
docker build -t my-agent:latest .
docker run -p 8080:8080 \
  -e ANTHROPIC_API_KEY=$ANTHROPIC_API_KEY \
  -e MCP_URL=$MCP_URL \
  -e MCP_TOKEN=$MCP_TOKEN \
  my-agent:latest
```

## Step 2: Kubernetes deployment

```yaml
# deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ai-agent
  labels:
    app: ai-agent
spec:
  replicas: 3
  selector:
    matchLabels:
      app: ai-agent
  template:
    metadata:
      labels:
        app: ai-agent
    spec:
      containers:
      - name: agent
        image: my-agent:latest
        ports:
        - containerPort: 8080
        env:
        - name: ANTHROPIC_API_KEY
          valueFrom:
            secretKeyRef:
              name: agent-secrets
              key: anthropic-api-key
        - name: MCP_URL
          valueFrom:
            configMapKeyRef:
              name: agent-config
              key: mcp-url
        - name: MCP_TOKEN
          valueFrom:
            secretKeyRef:
              name: agent-secrets
              key: mcp-token
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 10
          periodSeconds: 30
        readinessProbe:
          httpGet:
            path: /ready
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 10
---
apiVersion: v1
kind: Service
metadata:
  name: ai-agent
spec:
  selector:
    app: ai-agent
  ports:
  - port: 80
    targetPort: 8080
  type: ClusterIP
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: agent-config
data:
  mcp-url: "https://tools.gantz.run/sse"
  log-level: "info"
---
apiVersion: v1
kind: Secret
metadata:
  name: agent-secrets
type: Opaque
stringData:
  anthropic-api-key: "sk-ant-..."
  mcp-token: "gtz_..."
```

Horizontal Pod Autoscaler:
```yaml
# hpa.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: ai-agent-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: ai-agent
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Pods
    pods:
      metric:
        name: agent_requests_per_second
      target:
        type: AverageValue
        averageValue: "10"
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300
    scaleUp:
      stabilizationWindowSeconds: 60
```

## Step 3: MCP tools deployment

Deploy [Gantz](https://gantz.run) alongside your agent:

```yaml
# gantz-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: gantz-tools
spec:
  replicas: 2
  selector:
    matchLabels:
      app: gantz-tools
  template:
    metadata:
      labels:
        app: gantz-tools
    spec:
      containers:
      - name: gantz
        image: gantz/gantz:latest
        ports:
        - containerPort: 3000
        volumeMounts:
        - name: gantz-config
          mountPath: /app/gantz.yaml
          subPath: gantz.yaml
        env:
        - name: GANTZ_AUTH_TOKEN
          valueFrom:
            secretKeyRef:
              name: gantz-secrets
              key: auth-token
      volumes:
      - name: gantz-config
        configMap:
          name: gantz-config
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: gantz-config
data:
  gantz.yaml: |
    name: production-tools

    tools:
      - name: search_database
        description: Search the production database
        parameters:
          - name: query
            type: string
            required: true
        script:
          shell: psql "$DATABASE_URL" -c "{{query}}" --csv
```

## Step 4: CI/CD pipeline

```yaml
# .github/workflows/deploy.yml
name: Deploy Agent

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4

    - name: Set up Python
      uses: actions/setup-python@v5
      with:
        python-version: '3.11'

    - name: Install dependencies
      run: pip install -r requirements.txt -r requirements-dev.txt

    - name: Run tests
      run: pytest tests/ -v
      env:
        ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}

    - name: Run linting
      run: |
        flake8 .
        black --check .

  build:
    needs: test
    runs-on: ubuntu-latest
    if: github.event_name == 'push'
    steps:
    - uses: actions/checkout@v4

    - name: Build Docker image
      run: docker build -t my-agent:${{ github.sha }} .

    - name: Push to registry
      run: |
        echo ${{ secrets.REGISTRY_PASSWORD }} | docker login -u ${{ secrets.REGISTRY_USER }} --password-stdin
        docker tag my-agent:${{ github.sha }} registry.example.com/my-agent:${{ github.sha }}
        docker push registry.example.com/my-agent:${{ github.sha }}

  deploy-staging:
    needs: build
    runs-on: ubuntu-latest
    environment: staging
    steps:
    - uses: actions/checkout@v4

    - name: Deploy to staging
      run: |
        kubectl set image deployment/ai-agent \
          agent=registry.example.com/my-agent:${{ github.sha }} \
          --namespace staging

    - name: Wait for rollout
      run: kubectl rollout status deployment/ai-agent --namespace staging --timeout=300s

    - name: Run smoke tests
      run: |
        STAGING_URL=$(kubectl get svc ai-agent -n staging -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
        curl -f "$STAGING_URL/health"
        curl -f "$STAGING_URL/ready"

  deploy-production:
    needs: deploy-staging
    runs-on: ubuntu-latest
    environment: production
    steps:
    - uses: actions/checkout@v4

    - name: Deploy to production
      run: |
        kubectl set image deployment/ai-agent \
          agent=registry.example.com/my-agent:${{ github.sha }} \
          --namespace production

    - name: Wait for rollout
      run: kubectl rollout status deployment/ai-agent --namespace production --timeout=600s
```

## Step 5: Safe rollout strategies

Canary deployment:
```yaml
# canary-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ai-agent-canary
spec:
  replicas: 1  # Just one canary pod
  selector:
    matchLabels:
      app: ai-agent
      track: canary
  template:
    metadata:
      labels:
        app: ai-agent
        track: canary
    spec:
      containers:
      - name: agent
        image: my-agent:new-version
        # Same config as main deployment
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ai-agent-canary
  annotations:
    nginx.ingress.kubernetes.io/canary: "true"
    nginx.ingress.kubernetes.io/canary-weight: "10"  # 10% traffic to canary
spec:
  rules:
  - host: api.example.com
    http:
      paths:
      - path: /agent
        pathType: Prefix
        backend:
          service:
            name: ai-agent-canary
            port:
              number: 80
```

Blue-green with feature flags:
```python
# Feature flag for new agent version
import os

def get_agent_version():
    """Determine which agent version to use."""

    # Check feature flag
    new_version_enabled = os.environ.get("NEW_AGENT_VERSION") == "true"
    new_version_percentage = int(os.environ.get("NEW_AGENT_PERCENTAGE", "0"))

    # Gradual rollout
    import random
    if new_version_enabled and random.randint(1, 100) <= new_version_percentage:
        return "v2"

    return "v1"

def run_agent(task: str) -> str:
    version = get_agent_version()

    if version == "v2":
        return run_agent_v2(task)
    else:
        return run_agent_v1(task)
```

## Step 6: Serverless deployment

AWS Lambda:
```python
# lambda_handler.py
import json
import anthropic
import os

client = anthropic.Anthropic()

MCP_URL = os.environ.get("MCP_URL")
MCP_TOKEN = os.environ.get("MCP_TOKEN")

def handler(event, context):
    """AWS Lambda handler."""

    body = json.loads(event.get("body", "{}"))
    task = body.get("task")

    if not task:
        return {
            "statusCode": 400,
            "body": json.dumps({"error": "task required"})
        }

    try:
        response = client.messages.create(
            model="claude-sonnet-4-20250514",
            max_tokens=4096,
            messages=[{"role": "user", "content": task}],
            tools=[{"type": "mcp", "server_url": MCP_URL, "token": MCP_TOKEN}]
        )

        result = ""
        for content in response.content:
            if hasattr(content, 'text'):
                result += content.text

        return {
            "statusCode": 200,
            "body": json.dumps({"result": result})
        }

    except Exception as e:
        return {
            "statusCode": 500,
            "body": json.dumps({"error": str(e)})
        }
```

SAM template:
```yaml
# template.yaml
AWSTemplateFormatVersion: '2010-09-09'
Transform: AWS::Serverless-2016-10-31

Resources:
  AgentFunction:
    Type: AWS::Serverless::Function
    Properties:
      Handler: lambda_handler.handler
      Runtime: python3.11
      Timeout: 300  # 5 minutes for LLM calls
      MemorySize: 512
      Environment:
        Variables:
          MCP_URL: !Ref MCPUrl
          MCP_TOKEN: !Ref MCPToken
          ANTHROPIC_API_KEY: !Ref AnthropicApiKey
      Events:
        Api:
          Type: Api
          Properties:
            Path: /agent
            Method: post

Parameters:
  MCPUrl:
    Type: String
  MCPToken:
    Type: String
    NoEcho: true
  AnthropicApiKey:
    Type: String
    NoEcho: true
```

## Step 7: Monitoring in production

```python
# Production monitoring middleware
from functools import wraps
import time
from prometheus_client import Counter, Histogram, generate_latest

request_count = Counter(
    'agent_requests_total',
    'Total agent requests',
    ['status']
)

request_latency = Histogram(
    'agent_request_latency_seconds',
    'Agent request latency',
    buckets=[0.1, 0.5, 1, 2, 5, 10, 30, 60]
)

token_usage = Counter(
    'agent_tokens_total',
    'Tokens used',
    ['type']
)

def monitor_request(f):
    @wraps(f)
    def wrapper(*args, **kwargs):
        start = time.time()
        try:
            result = f(*args, **kwargs)
            request_count.labels(status='success').inc()
            return result
        except Exception as e:
            request_count.labels(status='error').inc()
            raise
        finally:
            request_latency.observe(time.time() - start)
    return wrapper

@app.route("/metrics")
def metrics():
    return generate_latest(), 200, {'Content-Type': 'text/plain'}
```

## Summary

Deploying AI agents:

1. **Containerize** - Docker for consistent environments
2. **Orchestrate** - Kubernetes for scaling and management
3. **Configure** - Separate config from code
4. **Automate** - CI/CD for safe deployments
5. **Roll out safely** - Canary and blue-green strategies
6. **Monitor** - Track health and performance

Build tools with [Gantz](https://gantz.run), deploy to production confidently.

From local to production. Safely.

## Related reading

- [Agent Scaling](/post/agent-scaling/) - Scale for load
- [Agent Testing](/post/agent-testing/) - Test before deploy
- [Agent Observability](/post/agent-observability/) - Monitor in production

---

*How do you deploy AI agents? Share your infrastructure.*
