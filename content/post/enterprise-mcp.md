+++
title = "Enterprise MCP: Deploy AI Agents at Scale"
image = "/images/enterprise-mcp.png"
date = 2025-11-07
description = "Deploy MCP and AI agents in enterprise environments. Governance, compliance, multi-tenant architecture, and enterprise integration patterns."
draft = false
tags = ['mcp', 'enterprise', 'architecture']
voice = false

[howto]
name = "Deploy Enterprise MCP"
totalTime = 45
[[howto.steps]]
name = "Design governance model"
text = "Establish policies for AI agent usage."
[[howto.steps]]
name = "Implement multi-tenancy"
text = "Isolate tenants with shared infrastructure."
[[howto.steps]]
name = "Add compliance controls"
text = "Meet regulatory requirements."
[[howto.steps]]
name = "Integrate with enterprise systems"
text = "Connect to SSO, LDAP, and enterprise APIs."
[[howto.steps]]
name = "Establish monitoring"
text = "Enterprise-grade observability."
+++


AI agents aren't just for startups.

Enterprises need them too. With governance.

Here's how to deploy MCP at enterprise scale.

## Enterprise requirements

Enterprises need:
- **Governance** - Policies and controls
- **Compliance** - Regulatory adherence
- **Multi-tenancy** - Isolated environments
- **Integration** - Enterprise systems
- **Scale** - Thousands of users

## Step 1: Governance model

Using [Gantz](https://gantz.run):

```yaml
# gantz.yaml
name: enterprise-tools

# Governance configuration
governance:
  approval_required:
    - production_deploy
    - data_export
    - external_api_calls
  audit_all: true
  retention_days: 90

# Role-based access
rbac:
  roles:
    admin:
      permissions: ["*"]
    developer:
      permissions: ["read", "execute", "develop"]
    viewer:
      permissions: ["read"]

tools:
  - name: governed_action
    description: Action with governance controls
    governance:
      requires_approval: true
      audit: true
      allowed_roles: ["admin", "developer"]
    parameters:
      - name: action
        type: string
        required: true
    script:
      command: python
      args: ["scripts/governed_action.py"]
```

Governance framework:

```python
from typing import Dict, Any, List, Optional, Callable
from dataclasses import dataclass
from enum import Enum
import time

class PolicyType(Enum):
    REQUIRE_APPROVAL = "require_approval"
    RATE_LIMIT = "rate_limit"
    DATA_CLASSIFICATION = "data_classification"
    AUDIT_REQUIRED = "audit_required"
    ROLE_REQUIRED = "role_required"

@dataclass
class Policy:
    """Governance policy."""
    name: str
    type: PolicyType
    config: Dict[str, Any]
    enforcement: str  # "enforce", "warn", "audit"

@dataclass
class PolicyViolation:
    """Record of policy violation."""
    policy_name: str
    action: str
    user: str
    timestamp: float
    details: str
    enforcement_action: str

class GovernanceEngine:
    """Enforce governance policies."""

    def __init__(self):
        self.policies: Dict[str, Policy] = {}
        self.violations: List[PolicyViolation] = []

    def add_policy(self, policy: Policy):
        """Add a governance policy."""
        self.policies[policy.name] = policy

    def check_policies(
        self,
        action: str,
        user: str,
        context: Dict[str, Any]
    ) -> tuple:
        """Check all policies. Returns (allowed, violations)."""

        violations = []

        for name, policy in self.policies.items():
            result = self._check_policy(policy, action, user, context)

            if not result["allowed"]:
                violation = PolicyViolation(
                    policy_name=name,
                    action=action,
                    user=user,
                    timestamp=time.time(),
                    details=result["reason"],
                    enforcement_action=policy.enforcement
                )
                violations.append(violation)
                self.violations.append(violation)

        # Determine if action is allowed
        blocking = [v for v in violations if v.enforcement_action == "enforce"]
        allowed = len(blocking) == 0

        return allowed, violations

    def _check_policy(
        self,
        policy: Policy,
        action: str,
        user: str,
        context: Dict[str, Any]
    ) -> Dict[str, Any]:
        """Check a single policy."""

        if policy.type == PolicyType.REQUIRE_APPROVAL:
            actions = policy.config.get("actions", [])
            if action in actions:
                if not context.get("approved"):
                    return {
                        "allowed": False,
                        "reason": f"Action {action} requires approval"
                    }

        elif policy.type == PolicyType.ROLE_REQUIRED:
            required_roles = policy.config.get("roles", [])
            user_roles = context.get("user_roles", [])
            if not any(r in user_roles for r in required_roles):
                return {
                    "allowed": False,
                    "reason": f"Requires one of roles: {required_roles}"
                }

        elif policy.type == PolicyType.RATE_LIMIT:
            limit = policy.config.get("limit", 100)
            window = policy.config.get("window_seconds", 3600)
            current_count = context.get("request_count", 0)
            if current_count >= limit:
                return {
                    "allowed": False,
                    "reason": f"Rate limit exceeded: {current_count}/{limit}"
                }

        elif policy.type == PolicyType.DATA_CLASSIFICATION:
            allowed_levels = policy.config.get("allowed_levels", [])
            data_level = context.get("data_classification", "public")
            if data_level not in allowed_levels:
                return {
                    "allowed": False,
                    "reason": f"Data classification {data_level} not allowed"
                }

        return {"allowed": True}

# Setup enterprise governance
governance = GovernanceEngine()

governance.add_policy(Policy(
    name="production_approval",
    type=PolicyType.REQUIRE_APPROVAL,
    config={"actions": ["deploy_production", "modify_database", "delete_data"]},
    enforcement="enforce"
))

governance.add_policy(Policy(
    name="data_access",
    type=PolicyType.DATA_CLASSIFICATION,
    config={"allowed_levels": ["public", "internal"]},
    enforcement="enforce"
))

governance.add_policy(Policy(
    name="rate_limit",
    type=PolicyType.RATE_LIMIT,
    config={"limit": 1000, "window_seconds": 3600},
    enforcement="warn"
))
```

## Step 2: Multi-tenancy

Isolate tenants:

```python
from typing import Dict, Any, Optional
from dataclasses import dataclass
import threading

@dataclass
class Tenant:
    """Enterprise tenant."""
    id: str
    name: str
    config: Dict[str, Any]
    quotas: Dict[str, int]
    allowed_tools: List[str]

class TenantManager:
    """Manage multi-tenant environment."""

    def __init__(self):
        self.tenants: Dict[str, Tenant] = {}
        self._current_tenant = threading.local()

    def register_tenant(self, tenant: Tenant):
        """Register a new tenant."""
        self.tenants[tenant.id] = tenant

    def get_current_tenant(self) -> Optional[Tenant]:
        """Get current tenant from context."""
        return getattr(self._current_tenant, 'tenant', None)

    def set_current_tenant(self, tenant_id: str):
        """Set current tenant context."""
        if tenant_id not in self.tenants:
            raise ValueError(f"Unknown tenant: {tenant_id}")
        self._current_tenant.tenant = self.tenants[tenant_id]

    def get_tenant_config(self, key: str, default: Any = None) -> Any:
        """Get configuration for current tenant."""
        tenant = self.get_current_tenant()
        if tenant:
            return tenant.config.get(key, default)
        return default

    def check_quota(self, resource: str, amount: int = 1) -> bool:
        """Check if tenant has quota for resource."""
        tenant = self.get_current_tenant()
        if not tenant:
            return False

        current = tenant.config.get(f"{resource}_used", 0)
        limit = tenant.quotas.get(resource, 0)

        return current + amount <= limit

    def is_tool_allowed(self, tool_name: str) -> bool:
        """Check if tool is allowed for tenant."""
        tenant = self.get_current_tenant()
        if not tenant:
            return False

        if "*" in tenant.allowed_tools:
            return True

        return tool_name in tenant.allowed_tools

class MultiTenantAgent:
    """Agent with multi-tenant support."""

    def __init__(
        self,
        tenant_manager: TenantManager,
        governance: GovernanceEngine
    ):
        self.tenants = tenant_manager
        self.governance = governance

    def execute(
        self,
        tenant_id: str,
        user_id: str,
        action: str,
        params: Dict[str, Any]
    ) -> Dict[str, Any]:
        """Execute action for tenant."""

        # Set tenant context
        self.tenants.set_current_tenant(tenant_id)
        tenant = self.tenants.get_current_tenant()

        # Check tool allowed
        if not self.tenants.is_tool_allowed(action):
            return {
                "error": f"Tool {action} not allowed for tenant",
                "allowed_tools": tenant.allowed_tools
            }

        # Check quota
        if not self.tenants.check_quota("api_calls"):
            return {"error": "API quota exceeded"}

        # Check governance
        allowed, violations = self.governance.check_policies(
            action,
            user_id,
            {"tenant_id": tenant_id, **params}
        )

        if not allowed:
            return {
                "error": "Policy violation",
                "violations": [v.details for v in violations]
            }

        # Execute action
        return self._execute_action(action, params)

    def _execute_action(self, action: str, params: Dict[str, Any]) -> Dict[str, Any]:
        """Actually execute the action."""
        # Implementation
        pass

# Setup tenants
tenant_mgr = TenantManager()

tenant_mgr.register_tenant(Tenant(
    id="acme-corp",
    name="Acme Corporation",
    config={"model": "claude-sonnet-4-20250514", "max_tokens": 4096},
    quotas={"api_calls": 10000, "storage_mb": 1000},
    allowed_tools=["search", "analyze", "generate"]
))

tenant_mgr.register_tenant(Tenant(
    id="globex",
    name="Globex Inc",
    config={"model": "claude-opus-4-20250514", "max_tokens": 8192},
    quotas={"api_calls": 50000, "storage_mb": 5000},
    allowed_tools=["*"]  # All tools
))
```

## Step 3: Compliance controls

Meet regulatory requirements:

```python
from typing import Dict, Any, List
from dataclasses import dataclass
from enum import Enum

class ComplianceFramework(Enum):
    SOC2 = "soc2"
    HIPAA = "hipaa"
    GDPR = "gdpr"
    PCI_DSS = "pci_dss"

@dataclass
class ComplianceRequirement:
    """Specific compliance requirement."""
    framework: ComplianceFramework
    control_id: str
    description: str
    implementation: str

class ComplianceEngine:
    """Ensure compliance with regulatory frameworks."""

    def __init__(self):
        self.requirements: Dict[str, List[ComplianceRequirement]] = {}
        self.audit_log: List[Dict[str, Any]] = []

    def add_requirement(self, req: ComplianceRequirement):
        """Add compliance requirement."""
        framework = req.framework.value
        if framework not in self.requirements:
            self.requirements[framework] = []
        self.requirements[framework].append(req)

    def check_action(
        self,
        action: str,
        context: Dict[str, Any],
        frameworks: List[ComplianceFramework]
    ) -> tuple:
        """Check action against compliance requirements."""

        findings = []

        for framework in frameworks:
            reqs = self.requirements.get(framework.value, [])
            for req in reqs:
                result = self._check_requirement(req, action, context)
                if not result["compliant"]:
                    findings.append({
                        "framework": framework.value,
                        "control": req.control_id,
                        "finding": result["finding"]
                    })

        compliant = len(findings) == 0

        # Always log for audit
        self._audit_log(action, context, compliant, findings)

        return compliant, findings

    def _check_requirement(
        self,
        req: ComplianceRequirement,
        action: str,
        context: Dict[str, Any]
    ) -> Dict[str, Any]:
        """Check a specific requirement."""

        # SOC2 - Access Control
        if req.control_id == "SOC2-AC-1":
            if not context.get("authenticated"):
                return {
                    "compliant": False,
                    "finding": "User not authenticated"
                }

        # HIPAA - PHI Protection
        if req.control_id == "HIPAA-164.502":
            if context.get("contains_phi") and not context.get("phi_authorized"):
                return {
                    "compliant": False,
                    "finding": "PHI access not authorized"
                }

        # GDPR - Data Subject Rights
        if req.control_id == "GDPR-17":
            if action == "delete_user_data" and not context.get("deletion_verified"):
                return {
                    "compliant": False,
                    "finding": "Data deletion not verified"
                }

        # PCI-DSS - Cardholder Data
        if req.control_id == "PCI-3.4":
            if context.get("contains_pan") and not context.get("pan_encrypted"):
                return {
                    "compliant": False,
                    "finding": "PAN not encrypted"
                }

        return {"compliant": True}

    def _audit_log(
        self,
        action: str,
        context: Dict[str, Any],
        compliant: bool,
        findings: List[Dict]
    ):
        """Log for audit trail."""
        self.audit_log.append({
            "timestamp": time.time(),
            "action": action,
            "user": context.get("user"),
            "compliant": compliant,
            "findings": findings,
            "context": {k: v for k, v in context.items() if k not in ["password", "token"]}
        })

    def generate_compliance_report(
        self,
        framework: ComplianceFramework,
        start_date: float,
        end_date: float
    ) -> Dict[str, Any]:
        """Generate compliance report."""

        relevant_logs = [
            log for log in self.audit_log
            if start_date <= log["timestamp"] <= end_date
        ]

        framework_findings = [
            log for log in relevant_logs
            if any(f["framework"] == framework.value for f in log.get("findings", []))
        ]

        return {
            "framework": framework.value,
            "period": {"start": start_date, "end": end_date},
            "total_actions": len(relevant_logs),
            "compliant_actions": len([l for l in relevant_logs if l["compliant"]]),
            "findings_count": len(framework_findings),
            "compliance_rate": (
                len([l for l in relevant_logs if l["compliant"]]) /
                len(relevant_logs) if relevant_logs else 1
            )
        }

# Setup compliance
compliance = ComplianceEngine()

compliance.add_requirement(ComplianceRequirement(
    framework=ComplianceFramework.SOC2,
    control_id="SOC2-AC-1",
    description="Access control policies",
    implementation="All actions require authentication"
))

compliance.add_requirement(ComplianceRequirement(
    framework=ComplianceFramework.GDPR,
    control_id="GDPR-17",
    description="Right to erasure",
    implementation="Data deletion must be verified"
))
```

## Step 4: Enterprise integration

Connect to enterprise systems:

```python
from typing import Dict, Any, Optional
from abc import ABC, abstractmethod

class EnterpriseIntegration(ABC):
    """Base class for enterprise integrations."""

    @abstractmethod
    def authenticate(self, credentials: Dict[str, Any]) -> Optional[str]:
        pass

    @abstractmethod
    def get_user_info(self, token: str) -> Dict[str, Any]:
        pass

class SAMLIntegration(EnterpriseIntegration):
    """SAML SSO integration."""

    def __init__(self, idp_url: str, sp_entity_id: str):
        self.idp_url = idp_url
        self.sp_entity_id = sp_entity_id

    def authenticate(self, saml_response: str) -> Optional[str]:
        """Validate SAML response and return session token."""
        # Parse and validate SAML response
        # Return session token
        pass

    def get_user_info(self, token: str) -> Dict[str, Any]:
        """Get user info from SAML attributes."""
        pass

class LDAPIntegration(EnterpriseIntegration):
    """LDAP/Active Directory integration."""

    def __init__(self, ldap_url: str, base_dn: str):
        self.ldap_url = ldap_url
        self.base_dn = base_dn

    def authenticate(self, credentials: Dict[str, Any]) -> Optional[str]:
        """Authenticate against LDAP."""
        import ldap3

        server = ldap3.Server(self.ldap_url)
        conn = ldap3.Connection(
            server,
            user=credentials["username"],
            password=credentials["password"]
        )

        if conn.bind():
            # Generate session token
            import uuid
            return str(uuid.uuid4())
        return None

    def get_user_info(self, token: str) -> Dict[str, Any]:
        """Get user info from LDAP."""
        pass

    def get_user_groups(self, username: str) -> List[str]:
        """Get user's group memberships."""
        pass

class ServiceNowIntegration:
    """ServiceNow ITSM integration."""

    def __init__(self, instance_url: str, credentials: Dict[str, str]):
        self.instance_url = instance_url
        self.credentials = credentials

    def create_incident(self, details: Dict[str, Any]) -> str:
        """Create ServiceNow incident."""
        import requests

        response = requests.post(
            f"{self.instance_url}/api/now/table/incident",
            auth=(self.credentials["user"], self.credentials["password"]),
            json=details
        )

        return response.json()["result"]["sys_id"]

    def create_change_request(self, details: Dict[str, Any]) -> str:
        """Create change request for agent actions."""
        pass

class EnterpriseAgentIntegration:
    """Integrate agent with enterprise systems."""

    def __init__(
        self,
        auth_provider: EnterpriseIntegration,
        servicenow: Optional[ServiceNowIntegration] = None
    ):
        self.auth = auth_provider
        self.servicenow = servicenow

    def authenticate_user(self, credentials: Dict[str, Any]) -> Dict[str, Any]:
        """Authenticate user through enterprise SSO."""
        token = self.auth.authenticate(credentials)

        if not token:
            return {"authenticated": False, "error": "Authentication failed"}

        user_info = self.auth.get_user_info(token)

        return {
            "authenticated": True,
            "token": token,
            "user": user_info
        }

    def request_change_approval(
        self,
        action: str,
        details: Dict[str, Any]
    ) -> str:
        """Request change approval through ServiceNow."""
        if not self.servicenow:
            raise ValueError("ServiceNow not configured")

        change_id = self.servicenow.create_change_request({
            "short_description": f"AI Agent Action: {action}",
            "description": str(details),
            "type": "standard",
            "risk": details.get("risk", "moderate")
        })

        return change_id
```

## Step 5: Enterprise monitoring

Enterprise-grade observability:

```python
from prometheus_client import Counter, Histogram, Gauge
import logging
from typing import Dict, Any

# Enterprise metrics
enterprise_requests = Counter(
    'enterprise_agent_requests_total',
    'Total requests by tenant',
    ['tenant', 'action', 'status']
)

enterprise_latency = Histogram(
    'enterprise_agent_latency_seconds',
    'Request latency by tenant',
    ['tenant'],
    buckets=[0.1, 0.5, 1, 2, 5, 10, 30]
)

enterprise_quota_usage = Gauge(
    'enterprise_quota_usage_ratio',
    'Quota usage ratio',
    ['tenant', 'quota_type']
)

compliance_violations = Counter(
    'enterprise_compliance_violations_total',
    'Compliance violations',
    ['tenant', 'framework', 'control']
)

class EnterpriseMonitoring:
    """Enterprise monitoring and alerting."""

    def __init__(self):
        self.logger = logging.getLogger("enterprise.agent")

        # Configure structured logging
        handler = logging.StreamHandler()
        handler.setFormatter(logging.Formatter(
            '{"timestamp": "%(asctime)s", "level": "%(levelname)s", '
            '"tenant": "%(tenant)s", "message": "%(message)s"}'
        ))
        self.logger.addHandler(handler)

    def log_request(
        self,
        tenant_id: str,
        action: str,
        user: str,
        status: str,
        duration: float,
        details: Dict[str, Any] = None
    ):
        """Log request with enterprise context."""

        # Update metrics
        enterprise_requests.labels(
            tenant=tenant_id,
            action=action,
            status=status
        ).inc()

        enterprise_latency.labels(tenant=tenant_id).observe(duration)

        # Structured log
        self.logger.info(
            f"Action: {action}, Status: {status}, Duration: {duration:.2f}s",
            extra={
                "tenant": tenant_id,
                "user": user,
                "action": action,
                "status": status,
                "duration": duration,
                "details": details
            }
        )

    def log_compliance_event(
        self,
        tenant_id: str,
        framework: str,
        control: str,
        compliant: bool,
        details: str
    ):
        """Log compliance event."""

        if not compliant:
            compliance_violations.labels(
                tenant=tenant_id,
                framework=framework,
                control=control
            ).inc()

        level = logging.INFO if compliant else logging.WARNING
        self.logger.log(
            level,
            f"Compliance check: {framework}/{control} - {'Pass' if compliant else 'Fail'}",
            extra={
                "tenant": tenant_id,
                "framework": framework,
                "control": control,
                "compliant": compliant,
                "details": details
            }
        )

    def update_quota_metrics(self, tenant_id: str, quotas: Dict[str, Dict[str, int]]):
        """Update quota usage metrics."""
        for quota_type, values in quotas.items():
            if values["limit"] > 0:
                ratio = values["used"] / values["limit"]
                enterprise_quota_usage.labels(
                    tenant=tenant_id,
                    quota_type=quota_type
                ).set(ratio)
```

## Summary

Enterprise MCP deployment:

1. **Governance** - Policies and controls
2. **Multi-tenancy** - Isolated environments
3. **Compliance** - Regulatory adherence
4. **Integration** - Enterprise systems
5. **Monitoring** - Enterprise observability

Build tools with [Gantz](https://gantz.run), deploy at enterprise scale.

AI for everyone. Governance for peace of mind.

## Related reading

- [Agent ROI](/post/agent-roi/) - Business value
- [MCP Security](/post/mcp-security-best-practices/) - Security controls
- [Agent Audit Logging](/post/agent-audit-logging/) - Audit trails

---

*How do you deploy AI agents in enterprise? Share your approaches.*
