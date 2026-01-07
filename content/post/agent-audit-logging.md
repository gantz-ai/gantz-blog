+++
title = "AI Agent Audit Logging: Track Every Action"
image = "images/agent-audit-logging.webp"
date = 2025-11-15
description = "Implement comprehensive audit logging for AI agents. Track tool calls, decisions, and outcomes for compliance, debugging, and security monitoring."
draft = false
tags = ['mcp', 'security', 'logging']
voice = false

[howto]
name = "Implement Agent Audit Logging"
totalTime = 35
[[howto.steps]]
name = "Define audit requirements"
text = "Determine what needs to be logged for compliance."
[[howto.steps]]
name = "Implement structured logging"
text = "Create consistent log format for all events."
[[howto.steps]]
name = "Log all tool executions"
text = "Capture every tool call with inputs and outputs."
[[howto.steps]]
name = "Ensure log integrity"
text = "Protect logs from tampering."
[[howto.steps]]
name = "Set up log analysis"
text = "Enable searching and alerting on logs."
+++


AI agents make decisions. Execute tools. Affect systems.

What did it do? Why? When?

Audit logs answer these questions.

## Why audit logging matters

Audit logs enable:
- **Compliance** - Prove regulatory adherence
- **Security** - Detect suspicious activity
- **Debugging** - Understand failures
- **Accountability** - Track who did what
- **Improvement** - Analyze patterns

Without logs, agents are black boxes.

## Step 1: Define audit requirements

Using [Gantz](https://gantz.run):

```yaml
# gantz.yaml
name: audited-agent

audit:
  enabled: true
  log_path: /var/log/agent-audit.jsonl
  retention_days: 90
  log_level: info  # debug, info, warn, error

  # What to log
  events:
    - tool_execution
    - authentication
    - authorization
    - errors
    - model_calls

  # What to redact
  redact:
    - password
    - api_key
    - token
    - secret
    - credit_card

tools:
  - name: query_database
    description: Query the database
    audit: true  # Enable per-tool
    parameters:
      - name: query
        type: string
        required: true
    script:
      shell: psql "$DATABASE_URL" -c "{{query}}"
```

Audit requirements definition:

```python
from enum import Enum
from typing import List, Set
from dataclasses import dataclass

class AuditEventType(Enum):
    """Types of auditable events."""
    TOOL_CALL_START = "tool_call_start"
    TOOL_CALL_END = "tool_call_end"
    TOOL_CALL_ERROR = "tool_call_error"
    MODEL_REQUEST = "model_request"
    MODEL_RESPONSE = "model_response"
    AUTH_SUCCESS = "auth_success"
    AUTH_FAILURE = "auth_failure"
    AUTHZ_GRANTED = "authz_granted"
    AUTHZ_DENIED = "authz_denied"
    DATA_ACCESS = "data_access"
    DATA_MODIFICATION = "data_modification"
    SECURITY_ALERT = "security_alert"

class AuditSeverity(Enum):
    """Audit event severity."""
    DEBUG = "debug"
    INFO = "info"
    WARNING = "warning"
    ERROR = "error"
    CRITICAL = "critical"

@dataclass
class AuditConfig:
    """Audit logging configuration."""
    enabled: bool = True
    log_path: str = "/var/log/agent-audit.jsonl"
    retention_days: int = 90
    min_severity: AuditSeverity = AuditSeverity.INFO

    # Events to log
    enabled_events: Set[AuditEventType] = None

    # Fields to redact
    redact_fields: Set[str] = None

    # Log destinations
    destinations: List[str] = None  # file, stdout, siem, cloudwatch

    def __post_init__(self):
        if self.enabled_events is None:
            self.enabled_events = set(AuditEventType)

        if self.redact_fields is None:
            self.redact_fields = {
                "password", "api_key", "token", "secret",
                "credit_card", "ssn", "private_key"
            }

        if self.destinations is None:
            self.destinations = ["file"]

    def should_log(self, event_type: AuditEventType) -> bool:
        """Check if event type should be logged."""
        return event_type in self.enabled_events
```

## Step 2: Structured audit events

Consistent event format:

```python
import json
import uuid
import time
import hashlib
from typing import Dict, Any, Optional, List
from dataclasses import dataclass, field, asdict

@dataclass
class AuditEvent:
    """Structured audit event."""

    # Event identification
    event_id: str = field(default_factory=lambda: str(uuid.uuid4()))
    event_type: str = ""
    timestamp: float = field(default_factory=time.time)

    # Context
    session_id: Optional[str] = None
    correlation_id: Optional[str] = None
    user_id: Optional[str] = None
    agent_id: Optional[str] = None

    # Event details
    action: str = ""
    resource: Optional[str] = None
    parameters: Dict[str, Any] = field(default_factory=dict)
    result: Optional[str] = None
    error: Optional[str] = None

    # Metadata
    severity: str = "info"
    duration_ms: Optional[float] = None
    ip_address: Optional[str] = None
    user_agent: Optional[str] = None

    # Integrity
    previous_hash: Optional[str] = None
    event_hash: Optional[str] = None

    def compute_hash(self, previous_hash: str = None) -> str:
        """Compute event hash for integrity."""
        self.previous_hash = previous_hash

        content = json.dumps({
            "event_id": self.event_id,
            "event_type": self.event_type,
            "timestamp": self.timestamp,
            "action": self.action,
            "parameters": self.parameters,
            "previous_hash": self.previous_hash
        }, sort_keys=True)

        self.event_hash = hashlib.sha256(content.encode()).hexdigest()
        return self.event_hash

    def to_json(self) -> str:
        """Convert to JSON string."""
        return json.dumps(asdict(self))

    @classmethod
    def from_json(cls, json_str: str) -> 'AuditEvent':
        """Parse from JSON string."""
        data = json.loads(json_str)
        return cls(**data)

class AuditEventBuilder:
    """Builder for audit events."""

    def __init__(self):
        self.event = AuditEvent()

    def event_type(self, type: AuditEventType) -> 'AuditEventBuilder':
        self.event.event_type = type.value
        return self

    def action(self, action: str) -> 'AuditEventBuilder':
        self.event.action = action
        return self

    def user(self, user_id: str) -> 'AuditEventBuilder':
        self.event.user_id = user_id
        return self

    def session(self, session_id: str) -> 'AuditEventBuilder':
        self.event.session_id = session_id
        return self

    def correlation(self, correlation_id: str) -> 'AuditEventBuilder':
        self.event.correlation_id = correlation_id
        return self

    def resource(self, resource: str) -> 'AuditEventBuilder':
        self.event.resource = resource
        return self

    def parameters(self, params: Dict[str, Any]) -> 'AuditEventBuilder':
        self.event.parameters = params
        return self

    def result(self, result: str) -> 'AuditEventBuilder':
        self.event.result = result
        return self

    def error(self, error: str) -> 'AuditEventBuilder':
        self.event.error = error
        self.event.severity = "error"
        return self

    def severity(self, severity: AuditSeverity) -> 'AuditEventBuilder':
        self.event.severity = severity.value
        return self

    def duration(self, duration_ms: float) -> 'AuditEventBuilder':
        self.event.duration_ms = duration_ms
        return self

    def build(self) -> AuditEvent:
        """Build the audit event."""
        return self.event

# Usage
event = (
    AuditEventBuilder()
    .event_type(AuditEventType.TOOL_CALL_END)
    .action("search_database")
    .user("user123")
    .parameters({"query": "SELECT * FROM users"})
    .result("10 rows returned")
    .duration(150.5)
    .build()
)
```

## Step 3: Audit logger implementation

```python
import os
import json
import threading
import queue
from typing import List, Optional
from abc import ABC, abstractmethod
from datetime import datetime

class AuditDestination(ABC):
    """Abstract audit log destination."""

    @abstractmethod
    def write(self, event: AuditEvent):
        pass

    @abstractmethod
    def flush(self):
        pass

class FileAuditDestination(AuditDestination):
    """Write audit logs to file."""

    def __init__(self, path: str, rotation_size_mb: int = 100):
        self.path = path
        self.rotation_size = rotation_size_mb * 1024 * 1024
        self.file = None
        self.lock = threading.Lock()
        self._open_file()

    def _open_file(self):
        os.makedirs(os.path.dirname(self.path), exist_ok=True)
        self.file = open(self.path, "a")

    def write(self, event: AuditEvent):
        with self.lock:
            self._check_rotation()
            self.file.write(event.to_json() + "\n")

    def _check_rotation(self):
        """Rotate file if too large."""
        if os.path.exists(self.path):
            if os.path.getsize(self.path) > self.rotation_size:
                self.file.close()
                timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
                os.rename(self.path, f"{self.path}.{timestamp}")
                self._open_file()

    def flush(self):
        with self.lock:
            self.file.flush()

class SIEMAuditDestination(AuditDestination):
    """Send audit logs to SIEM."""

    def __init__(self, endpoint: str, api_key: str):
        self.endpoint = endpoint
        self.api_key = api_key
        self.buffer: List[AuditEvent] = []
        self.buffer_size = 100

    def write(self, event: AuditEvent):
        self.buffer.append(event)
        if len(self.buffer) >= self.buffer_size:
            self.flush()

    def flush(self):
        if not self.buffer:
            return

        import requests
        try:
            requests.post(
                self.endpoint,
                json={"events": [e.to_json() for e in self.buffer]},
                headers={"Authorization": f"Bearer {self.api_key}"},
                timeout=10
            )
            self.buffer = []
        except Exception as e:
            print(f"Failed to send to SIEM: {e}")

class AuditLogger:
    """Main audit logging system."""

    def __init__(self, config: AuditConfig):
        self.config = config
        self.destinations: List[AuditDestination] = []
        self.queue = queue.Queue()
        self.last_hash: Optional[str] = None
        self.lock = threading.Lock()

        self._setup_destinations()
        self._start_worker()

    def _setup_destinations(self):
        """Setup configured destinations."""
        if "file" in self.config.destinations:
            self.destinations.append(
                FileAuditDestination(self.config.log_path)
            )

    def _start_worker(self):
        """Start async logging worker."""
        def worker():
            while True:
                event = self.queue.get()
                if event is None:
                    break
                for dest in self.destinations:
                    try:
                        dest.write(event)
                    except Exception as e:
                        print(f"Audit write failed: {e}")
                self.queue.task_done()

        thread = threading.Thread(target=worker, daemon=True)
        thread.start()

    def log(self, event: AuditEvent):
        """Log an audit event."""
        if not self.config.enabled:
            return

        if not self.config.should_log(
            AuditEventType(event.event_type)
        ):
            return

        # Redact sensitive fields
        event.parameters = self._redact(event.parameters)

        # Compute hash for integrity
        with self.lock:
            event.compute_hash(self.last_hash)
            self.last_hash = event.event_hash

        # Queue for async writing
        self.queue.put(event)

    def _redact(self, data: Dict[str, Any]) -> Dict[str, Any]:
        """Redact sensitive fields."""
        if not isinstance(data, dict):
            return data

        result = {}
        for key, value in data.items():
            key_lower = key.lower()

            if any(field in key_lower for field in self.config.redact_fields):
                result[key] = "[REDACTED]"
            elif isinstance(value, dict):
                result[key] = self._redact(value)
            elif isinstance(value, list):
                result[key] = [
                    self._redact(v) if isinstance(v, dict) else v
                    for v in value
                ]
            else:
                result[key] = value

        return result

    def flush(self):
        """Flush all destinations."""
        self.queue.join()
        for dest in self.destinations:
            dest.flush()

# Global logger
_audit_logger: Optional[AuditLogger] = None

def get_audit_logger() -> AuditLogger:
    global _audit_logger
    if _audit_logger is None:
        _audit_logger = AuditLogger(AuditConfig())
    return _audit_logger

def audit_log(event: AuditEvent):
    """Log an audit event."""
    get_audit_logger().log(event)
```

## Step 4: Tool execution auditing

Automatically audit all tool calls:

```python
import time
from functools import wraps
from typing import Callable, Any

def audited_tool(tool_name: str):
    """Decorator to audit tool execution."""

    def decorator(func: Callable) -> Callable:
        @wraps(func)
        def wrapper(*args, **kwargs):
            # Get audit context
            correlation_id = kwargs.pop('_correlation_id', str(uuid.uuid4()))
            user_id = kwargs.pop('_user_id', 'unknown')
            session_id = kwargs.pop('_session_id', None)

            # Log start
            start_event = (
                AuditEventBuilder()
                .event_type(AuditEventType.TOOL_CALL_START)
                .action(tool_name)
                .correlation(correlation_id)
                .user(user_id)
                .session(session_id)
                .parameters(kwargs)
                .build()
            )
            audit_log(start_event)

            start_time = time.time()

            try:
                result = func(*args, **kwargs)
                duration = (time.time() - start_time) * 1000

                # Log success
                end_event = (
                    AuditEventBuilder()
                    .event_type(AuditEventType.TOOL_CALL_END)
                    .action(tool_name)
                    .correlation(correlation_id)
                    .user(user_id)
                    .result(str(result)[:1000])  # Truncate
                    .duration(duration)
                    .build()
                )
                audit_log(end_event)

                return result

            except Exception as e:
                duration = (time.time() - start_time) * 1000

                # Log error
                error_event = (
                    AuditEventBuilder()
                    .event_type(AuditEventType.TOOL_CALL_ERROR)
                    .action(tool_name)
                    .correlation(correlation_id)
                    .user(user_id)
                    .error(str(e))
                    .duration(duration)
                    .severity(AuditSeverity.ERROR)
                    .build()
                )
                audit_log(error_event)

                raise

        return wrapper
    return decorator

# Usage
@audited_tool("search_database")
def search_database(query: str, limit: int = 10) -> list:
    """Search database with full audit logging."""
    import subprocess
    result = subprocess.run(
        ["psql", os.environ["DATABASE_URL"], "-c", query],
        capture_output=True,
        text=True
    )
    return result.stdout

# Call with audit context
results = search_database(
    query="SELECT * FROM users",
    limit=10,
    _user_id="user123",
    _correlation_id="req-abc123"
)
```

## Step 5: Log integrity verification

Ensure logs haven't been tampered with:

```python
import hashlib
from typing import List, Tuple, Optional

class LogIntegrityVerifier:
    """Verify audit log integrity using hash chains."""

    def __init__(self, log_path: str):
        self.log_path = log_path

    def verify(self) -> Tuple[bool, List[str]]:
        """Verify entire log file integrity."""
        errors = []
        previous_hash = None
        line_number = 0

        with open(self.log_path, "r") as f:
            for line in f:
                line_number += 1

                try:
                    event = AuditEvent.from_json(line.strip())

                    # Verify hash chain
                    if event.previous_hash != previous_hash:
                        errors.append(
                            f"Line {line_number}: Hash chain broken. "
                            f"Expected previous: {previous_hash}, "
                            f"got: {event.previous_hash}"
                        )

                    # Verify event hash
                    expected_hash = self._compute_hash(event, previous_hash)
                    if event.event_hash != expected_hash:
                        errors.append(
                            f"Line {line_number}: Event hash mismatch. "
                            f"Event may have been tampered."
                        )

                    previous_hash = event.event_hash

                except Exception as e:
                    errors.append(f"Line {line_number}: Parse error: {e}")

        is_valid = len(errors) == 0
        return is_valid, errors

    def _compute_hash(self, event: AuditEvent, previous_hash: str) -> str:
        """Recompute event hash."""
        content = json.dumps({
            "event_id": event.event_id,
            "event_type": event.event_type,
            "timestamp": event.timestamp,
            "action": event.action,
            "parameters": event.parameters,
            "previous_hash": previous_hash
        }, sort_keys=True)

        return hashlib.sha256(content.encode()).hexdigest()

    def find_tampering(self) -> List[int]:
        """Find specific lines that were tampered with."""
        tampered = []
        _, errors = self.verify()

        for error in errors:
            if "Hash chain broken" in error or "hash mismatch" in error:
                # Extract line number
                line_num = int(error.split(":")[0].replace("Line ", ""))
                tampered.append(line_num)

        return tampered

# Usage
verifier = LogIntegrityVerifier("/var/log/agent-audit.jsonl")
is_valid, errors = verifier.verify()

if not is_valid:
    print("Log integrity check FAILED!")
    for error in errors:
        print(f"  - {error}")
```

## Step 6: Log analysis and alerting

```python
import re
from collections import defaultdict
from typing import Dict, List, Any
from datetime import datetime, timedelta

class AuditLogAnalyzer:
    """Analyze audit logs for patterns and anomalies."""

    def __init__(self, log_path: str):
        self.log_path = log_path

    def load_events(
        self,
        start_time: float = None,
        end_time: float = None,
        event_types: List[str] = None
    ) -> List[AuditEvent]:
        """Load events matching criteria."""
        events = []

        with open(self.log_path, "r") as f:
            for line in f:
                event = AuditEvent.from_json(line.strip())

                if start_time and event.timestamp < start_time:
                    continue
                if end_time and event.timestamp > end_time:
                    continue
                if event_types and event.event_type not in event_types:
                    continue

                events.append(event)

        return events

    def detect_anomalies(self, window_hours: int = 1) -> List[Dict[str, Any]]:
        """Detect anomalous patterns."""
        anomalies = []
        now = time.time()
        start = now - (window_hours * 3600)

        events = self.load_events(start_time=start)

        # Check for high error rates
        error_count = sum(1 for e in events if e.severity == "error")
        total_count = len(events)

        if total_count > 10 and error_count / total_count > 0.2:
            anomalies.append({
                "type": "high_error_rate",
                "error_rate": error_count / total_count,
                "window_hours": window_hours
            })

        # Check for unusual user activity
        user_actions = defaultdict(int)
        for event in events:
            if event.user_id:
                user_actions[event.user_id] += 1

        for user, count in user_actions.items():
            if count > 1000:  # Threshold
                anomalies.append({
                    "type": "excessive_user_activity",
                    "user_id": user,
                    "action_count": count
                })

        # Check for auth failures
        auth_failures = sum(
            1 for e in events
            if e.event_type == "auth_failure"
        )

        if auth_failures > 10:
            anomalies.append({
                "type": "auth_failure_spike",
                "failure_count": auth_failures
            })

        return anomalies

    def generate_report(self, hours: int = 24) -> Dict[str, Any]:
        """Generate audit report."""
        now = time.time()
        start = now - (hours * 3600)
        events = self.load_events(start_time=start)

        # Aggregate statistics
        by_type = defaultdict(int)
        by_user = defaultdict(int)
        by_action = defaultdict(int)
        errors = []
        durations = []

        for event in events:
            by_type[event.event_type] += 1
            if event.user_id:
                by_user[event.user_id] += 1
            by_action[event.action] += 1

            if event.severity == "error":
                errors.append(event)

            if event.duration_ms:
                durations.append(event.duration_ms)

        return {
            "period_hours": hours,
            "total_events": len(events),
            "events_by_type": dict(by_type),
            "events_by_user": dict(by_user),
            "events_by_action": dict(by_action),
            "error_count": len(errors),
            "avg_duration_ms": sum(durations) / len(durations) if durations else 0,
            "max_duration_ms": max(durations) if durations else 0,
            "anomalies": self.detect_anomalies(hours)
        }

class AuditAlerter:
    """Send alerts based on audit events."""

    def __init__(self, analyzer: AuditLogAnalyzer):
        self.analyzer = analyzer
        self.alert_rules = []

    def add_rule(
        self,
        name: str,
        condition: callable,
        action: callable
    ):
        """Add alerting rule."""
        self.alert_rules.append({
            "name": name,
            "condition": condition,
            "action": action
        })

    def check_alerts(self):
        """Check all alert rules."""
        anomalies = self.analyzer.detect_anomalies()

        for anomaly in anomalies:
            for rule in self.alert_rules:
                if rule["condition"](anomaly):
                    rule["action"](anomaly)

# Usage
analyzer = AuditLogAnalyzer("/var/log/agent-audit.jsonl")
alerter = AuditAlerter(analyzer)

# Add alert rules
alerter.add_rule(
    name="high_error_rate",
    condition=lambda a: a["type"] == "high_error_rate" and a["error_rate"] > 0.3,
    action=lambda a: send_slack_alert(f"High error rate: {a['error_rate']:.1%}")
)

alerter.add_rule(
    name="auth_failures",
    condition=lambda a: a["type"] == "auth_failure_spike",
    action=lambda a: send_pagerduty_alert(f"Auth failure spike: {a['failure_count']}")
)
```

## Summary

Audit logging for AI agents:

1. **Define requirements** - What must be logged
2. **Structured events** - Consistent format
3. **Comprehensive logging** - Capture all actions
4. **Ensure integrity** - Tamper-proof logs
5. **Analyze patterns** - Detect anomalies
6. **Alert on issues** - Real-time notifications

Build tools with [Gantz](https://gantz.run), audit everything.

If it's not logged, it didn't happen.

## Related reading

- [MCP Security](/post/mcp-security-best-practices/) - Security fundamentals
- [Agent Observability](/post/agent-observability/) - Monitoring agents
- [Secure Tool Execution](/post/secure-tool-execution/) - Execute safely

---

*How do you audit your AI systems? Share your approaches.*
