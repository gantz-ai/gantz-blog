+++
title = "AI Agent Sandboxing: Isolate Agents for Security"
image = "/images/agent-sandboxing.png"
date = 2025-11-17
description = "Sandbox AI agents for security. Use containers, VMs, and restricted environments to isolate agent execution and limit blast radius with MCP."
draft = false
tags = ['mcp', 'security', 'sandboxing']
voice = false

[howto]
name = "Sandbox AI Agents"
totalTime = 40
[[howto.steps]]
name = "Define isolation requirements"
text = "Determine what needs to be isolated and why."
[[howto.steps]]
name = "Implement container isolation"
text = "Use Docker with security constraints."
[[howto.steps]]
name = "Add network restrictions"
text = "Limit network access to required services."
[[howto.steps]]
name = "Set resource limits"
text = "Constrain CPU, memory, and storage."
[[howto.steps]]
name = "Configure runtime security"
text = "Add seccomp, AppArmor, and capability drops."
+++


AI agents execute code. Code can be dangerous.

Without isolation, one compromised agent = compromised system.

Here's how to sandbox agents properly.

## Why sandboxing matters

AI agents with tools can:
- Execute arbitrary shell commands
- Access filesystems
- Make network requests
- Modify databases
- Install packages

One prompt injection or bug could exploit any of these.

## Isolation layers

Defense in depth:

```
┌─────────────────────────────────────┐
│           Host System               │
│  ┌───────────────────────────────┐  │
│  │      Container Runtime        │  │
│  │  ┌─────────────────────────┐  │  │
│  │  │    Sandbox Container    │  │  │
│  │  │  ┌───────────────────┐  │  │  │
│  │  │  │   Agent Process   │  │  │  │
│  │  │  │  ┌─────────────┐  │  │  │  │
│  │  │  │  │ Tool Exec   │  │  │  │  │
│  │  │  │  └─────────────┘  │  │  │  │
│  │  │  └───────────────────┘  │  │  │
│  │  └─────────────────────────┘  │  │
│  └───────────────────────────────┘  │
└─────────────────────────────────────┘
```

## Step 1: Container isolation

Using [Gantz](https://gantz.run) with Docker:

```yaml
# gantz.yaml
name: sandboxed-agent

sandbox:
  type: docker
  image: gantz/sandbox:latest
  network: restricted
  readonly_root: true

tools:
  - name: analyze_code
    description: Analyze code in sandbox
    parameters:
      - name: code
        type: string
        required: true
    sandbox: true  # Run in sandbox
    script:
      command: python
      args: ["-c", "{{code}}"]
```

Secure Dockerfile:

```dockerfile
# Dockerfile.sandbox
FROM python:3.11-slim-bookworm

# Create non-root user
RUN useradd --create-home --shell /bin/bash sandbox \
    && mkdir -p /app /tmp/work \
    && chown -R sandbox:sandbox /app /tmp/work

# Install minimal dependencies
RUN pip install --no-cache-dir \
    anthropic \
    requests \
    && rm -rf /root/.cache

# Remove unnecessary packages
RUN apt-get remove -y \
    wget curl git \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/*

# Set security labels
LABEL security.sandbox="true"
LABEL security.network="restricted"

# Switch to non-root user
USER sandbox
WORKDIR /app

# Read-only filesystem by default
# (enforced at runtime)

ENTRYPOINT ["python"]
```

Docker compose for sandboxed execution:

```yaml
# docker-compose.sandbox.yaml
version: '3.8'

services:
  agent-sandbox:
    build:
      context: .
      dockerfile: Dockerfile.sandbox

    # Security options
    security_opt:
      - no-new-privileges:true
      - seccomp:seccomp-profile.json
      - apparmor:sandbox-profile

    # Read-only root filesystem
    read_only: true

    # Temp filesystem for writes
    tmpfs:
      - /tmp:size=100M,mode=1777

    # Resource limits
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 512M
        reservations:
          cpus: '0.1'
          memory: 128M

    # No capabilities
    cap_drop:
      - ALL

    # Network isolation
    networks:
      - sandbox-net

    # Environment
    environment:
      - SANDBOX=true
      - PYTHONDONTWRITEBYTECODE=1

networks:
  sandbox-net:
    driver: bridge
    internal: true  # No external access
```

## Step 2: Network restrictions

Control what agents can access:

```python
import subprocess
import ipaddress
from typing import List, Optional

class NetworkPolicy:
    """Network access policy for sandboxes."""

    def __init__(self):
        self.allowed_hosts: List[str] = []
        self.allowed_ports: List[int] = []
        self.blocked_ranges: List[str] = [
            "10.0.0.0/8",      # Private networks
            "172.16.0.0/12",
            "192.168.0.0/16",
            "169.254.0.0/16",  # Link-local
            "127.0.0.0/8",     # Localhost
        ]

    def allow_host(self, host: str, port: int = 443):
        """Allow access to specific host."""
        self.allowed_hosts.append(host)
        if port not in self.allowed_ports:
            self.allowed_ports.append(port)

    def is_allowed(self, host: str, port: int) -> bool:
        """Check if connection is allowed."""
        # Check explicit allowlist
        if self.allowed_hosts and host not in self.allowed_hosts:
            return False

        if self.allowed_ports and port not in self.allowed_ports:
            return False

        # Check blocked ranges (for IP addresses)
        try:
            ip = ipaddress.ip_address(host)
            for blocked in self.blocked_ranges:
                if ip in ipaddress.ip_network(blocked):
                    return False
        except ValueError:
            pass  # Not an IP, it's a hostname

        return True

    def to_iptables(self) -> List[str]:
        """Generate iptables rules."""
        rules = []

        # Default deny
        rules.append("iptables -P OUTPUT DROP")

        # Allow DNS
        rules.append("iptables -A OUTPUT -p udp --dport 53 -j ACCEPT")

        # Allow specific hosts
        for host in self.allowed_hosts:
            for port in self.allowed_ports:
                rules.append(
                    f"iptables -A OUTPUT -p tcp -d {host} --dport {port} -j ACCEPT"
                )

        return rules

class SandboxNetworkManager:
    """Manage network for sandboxed containers."""

    def __init__(self):
        self.policies = {}

    def create_network(self, name: str, policy: NetworkPolicy) -> str:
        """Create isolated Docker network."""
        # Create network
        result = subprocess.run([
            "docker", "network", "create",
            "--driver", "bridge",
            "--internal",  # No external access by default
            "--subnet", "172.28.0.0/16",
            name
        ], capture_output=True, text=True)

        self.policies[name] = policy
        return name

    def apply_policy(self, container_id: str, policy: NetworkPolicy):
        """Apply network policy to container."""
        for rule in policy.to_iptables():
            subprocess.run([
                "docker", "exec", container_id,
                "sh", "-c", rule
            ])

# Usage
policy = NetworkPolicy()
policy.allow_host("api.anthropic.com", 443)
policy.allow_host("tools.gantz.run", 443)

manager = SandboxNetworkManager()
manager.create_network("agent-sandbox", policy)
```

Kubernetes NetworkPolicy:

```yaml
# network-policy.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: agent-sandbox-policy
spec:
  podSelector:
    matchLabels:
      app: agent-sandbox

  policyTypes:
    - Ingress
    - Egress

  # No ingress allowed
  ingress: []

  # Limited egress
  egress:
    # Allow DNS
    - to:
        - namespaceSelector: {}
          podSelector:
            matchLabels:
              k8s-app: kube-dns
      ports:
        - protocol: UDP
          port: 53

    # Allow specific external APIs
    - to:
        - ipBlock:
            cidr: 0.0.0.0/0
            except:
              - 10.0.0.0/8
              - 172.16.0.0/12
              - 192.168.0.0/16
      ports:
        - protocol: TCP
          port: 443
```

## Step 3: Filesystem isolation

Restrict file access:

```python
import os
import tempfile
from pathlib import Path
from typing import List, Optional

class FilesystemSandbox:
    """Isolated filesystem for agent execution."""

    def __init__(self, base_dir: str = None):
        self.base_dir = Path(base_dir or tempfile.mkdtemp(prefix="agent-sandbox-"))
        self.allowed_paths: List[Path] = []
        self.readonly_paths: List[Path] = []

    def setup(self):
        """Setup sandbox filesystem."""
        # Create directory structure
        (self.base_dir / "work").mkdir(exist_ok=True)
        (self.base_dir / "input").mkdir(exist_ok=True)
        (self.base_dir / "output").mkdir(exist_ok=True)

        # Set permissions
        os.chmod(self.base_dir / "input", 0o555)  # Read-only
        os.chmod(self.base_dir / "work", 0o755)   # Read-write
        os.chmod(self.base_dir / "output", 0o755) # Read-write

        self.allowed_paths = [
            self.base_dir / "work",
            self.base_dir / "output"
        ]
        self.readonly_paths = [
            self.base_dir / "input"
        ]

    def add_input(self, name: str, content: str):
        """Add input file."""
        path = self.base_dir / "input" / name
        path.write_text(content)
        os.chmod(path, 0o444)  # Read-only

    def get_output(self, name: str) -> Optional[str]:
        """Get output file."""
        path = self.base_dir / "output" / name
        if path.exists():
            return path.read_text()
        return None

    def is_path_allowed(self, path: str, write: bool = False) -> bool:
        """Check if path access is allowed."""
        resolved = Path(path).resolve()

        # Check if in allowed paths
        for allowed in self.allowed_paths:
            if resolved.is_relative_to(allowed):
                return True

        # Check readonly paths (only for read)
        if not write:
            for readonly in self.readonly_paths:
                if resolved.is_relative_to(readonly):
                    return True

        return False

    def cleanup(self):
        """Remove sandbox directory."""
        import shutil
        shutil.rmtree(self.base_dir, ignore_errors=True)

    def to_docker_mounts(self) -> List[str]:
        """Generate Docker mount options."""
        return [
            f"-v {self.base_dir}/input:/sandbox/input:ro",
            f"-v {self.base_dir}/work:/sandbox/work:rw",
            f"-v {self.base_dir}/output:/sandbox/output:rw"
        ]

# Usage
sandbox = FilesystemSandbox()
sandbox.setup()
sandbox.add_input("data.json", '{"key": "value"}')

# Run agent in sandbox
# ...

output = sandbox.get_output("result.json")
sandbox.cleanup()
```

## Step 4: Resource limits

Prevent resource exhaustion:

```python
import resource
import signal
from contextlib import contextmanager
from typing import Optional

class ResourceLimits:
    """Resource limits for sandboxed execution."""

    def __init__(
        self,
        max_cpu_time: int = 30,        # seconds
        max_memory: int = 512_000_000,  # 512MB
        max_file_size: int = 10_000_000, # 10MB
        max_processes: int = 10,
        max_open_files: int = 50
    ):
        self.max_cpu_time = max_cpu_time
        self.max_memory = max_memory
        self.max_file_size = max_file_size
        self.max_processes = max_processes
        self.max_open_files = max_open_files

    def apply(self):
        """Apply resource limits to current process."""
        # CPU time
        resource.setrlimit(
            resource.RLIMIT_CPU,
            (self.max_cpu_time, self.max_cpu_time)
        )

        # Memory
        resource.setrlimit(
            resource.RLIMIT_AS,
            (self.max_memory, self.max_memory)
        )

        # File size
        resource.setrlimit(
            resource.RLIMIT_FSIZE,
            (self.max_file_size, self.max_file_size)
        )

        # Processes
        resource.setrlimit(
            resource.RLIMIT_NPROC,
            (self.max_processes, self.max_processes)
        )

        # Open files
        resource.setrlimit(
            resource.RLIMIT_NOFILE,
            (self.max_open_files, self.max_open_files)
        )

class TimeoutHandler:
    """Handle execution timeouts."""

    def __init__(self, timeout: int):
        self.timeout = timeout
        self.timed_out = False

    def _handler(self, signum, frame):
        self.timed_out = True
        raise TimeoutError(f"Execution timed out after {self.timeout}s")

    @contextmanager
    def __call__(self):
        """Context manager for timeout."""
        old_handler = signal.signal(signal.SIGALRM, self._handler)
        signal.alarm(self.timeout)

        try:
            yield
        finally:
            signal.alarm(0)
            signal.signal(signal.SIGALRM, old_handler)

def run_sandboxed(func, limits: ResourceLimits = None, timeout: int = 30):
    """Run function with resource limits."""
    import multiprocessing

    def wrapper(result_queue):
        try:
            if limits:
                limits.apply()

            with TimeoutHandler(timeout):
                result = func()
                result_queue.put(("success", result))
        except Exception as e:
            result_queue.put(("error", str(e)))

    result_queue = multiprocessing.Queue()
    process = multiprocessing.Process(target=wrapper, args=(result_queue,))
    process.start()
    process.join(timeout + 5)  # Extra buffer

    if process.is_alive():
        process.terminate()
        process.join()
        return ("error", "Process killed")

    if not result_queue.empty():
        return result_queue.get()

    return ("error", "No result")

# Usage
limits = ResourceLimits(
    max_cpu_time=10,
    max_memory=256_000_000
)

status, result = run_sandboxed(
    lambda: execute_agent_code(code),
    limits=limits,
    timeout=15
)
```

## Step 5: Secure runtime

Additional security measures:

```python
import subprocess
import json
from typing import Dict, Any

class SecureRuntime:
    """Secure runtime for agent execution."""

    def __init__(self, sandbox_image: str = "gantz/sandbox:latest"):
        self.sandbox_image = sandbox_image
        self.seccomp_profile = self._create_seccomp_profile()

    def _create_seccomp_profile(self) -> Dict[str, Any]:
        """Create restrictive seccomp profile."""
        return {
            "defaultAction": "SCMP_ACT_ERRNO",
            "architectures": ["SCMP_ARCH_X86_64"],
            "syscalls": [
                # Allow basic syscalls
                {"names": ["read", "write", "close", "fstat"], "action": "SCMP_ACT_ALLOW"},
                {"names": ["mmap", "mprotect", "munmap"], "action": "SCMP_ACT_ALLOW"},
                {"names": ["brk", "rt_sigaction", "rt_sigprocmask"], "action": "SCMP_ACT_ALLOW"},
                {"names": ["access", "openat", "newfstatat"], "action": "SCMP_ACT_ALLOW"},
                {"names": ["getdents64", "lseek"], "action": "SCMP_ACT_ALLOW"},
                {"names": ["exit_group", "exit"], "action": "SCMP_ACT_ALLOW"},
                {"names": ["futex", "clock_gettime"], "action": "SCMP_ACT_ALLOW"},

                # Networking (restricted)
                {"names": ["socket", "connect", "sendto", "recvfrom"], "action": "SCMP_ACT_ALLOW"},

                # Deny dangerous syscalls explicitly
                {"names": ["execve"], "action": "SCMP_ACT_ERRNO"},
                {"names": ["fork", "vfork", "clone"], "action": "SCMP_ACT_ERRNO"},
                {"names": ["ptrace"], "action": "SCMP_ACT_ERRNO"},
                {"names": ["mount", "umount"], "action": "SCMP_ACT_ERRNO"},
            ]
        }

    def execute(
        self,
        code: str,
        filesystem: FilesystemSandbox,
        network: NetworkPolicy,
        limits: ResourceLimits
    ) -> Dict[str, Any]:
        """Execute code in secure sandbox."""

        # Write seccomp profile
        import tempfile
        with tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False) as f:
            json.dump(self.seccomp_profile, f)
            seccomp_path = f.name

        try:
            # Build docker command
            cmd = [
                "docker", "run",
                "--rm",
                "--read-only",
                "--security-opt", f"seccomp={seccomp_path}",
                "--security-opt", "no-new-privileges:true",
                "--cap-drop", "ALL",
                "--memory", f"{limits.max_memory}",
                "--cpus", "0.5",
                "--pids-limit", str(limits.max_processes),
                "--network", "none",  # Start with no network
            ]

            # Add mounts
            cmd.extend(filesystem.to_docker_mounts())

            # Add tmpfs for temp files
            cmd.extend(["--tmpfs", "/tmp:size=100M,mode=1777"])

            # Add image and command
            cmd.extend([
                self.sandbox_image,
                "-c", code
            ])

            # Execute
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                timeout=limits.max_cpu_time + 10
            )

            return {
                "success": result.returncode == 0,
                "stdout": result.stdout,
                "stderr": result.stderr,
                "returncode": result.returncode
            }

        finally:
            os.unlink(seccomp_path)

# Usage
runtime = SecureRuntime()
filesystem = FilesystemSandbox()
filesystem.setup()

result = runtime.execute(
    code="print('Hello from sandbox')",
    filesystem=filesystem,
    network=NetworkPolicy(),
    limits=ResourceLimits()
)

filesystem.cleanup()
```

## Step 6: Monitoring sandboxes

Track sandbox activity:

```python
from prometheus_client import Counter, Histogram, Gauge
import logging

sandbox_executions = Counter(
    'sandbox_executions_total',
    'Total sandbox executions',
    ['status']
)

sandbox_duration = Histogram(
    'sandbox_execution_seconds',
    'Sandbox execution duration',
    buckets=[0.1, 0.5, 1, 5, 10, 30]
)

sandbox_violations = Counter(
    'sandbox_violations_total',
    'Security violations in sandbox',
    ['type']
)

active_sandboxes = Gauge(
    'active_sandboxes',
    'Currently active sandboxes'
)

class SandboxMonitor:
    """Monitor sandbox activity."""

    def __init__(self):
        self.logger = logging.getLogger("sandbox")

    def record_execution(self, success: bool, duration: float):
        """Record sandbox execution."""
        status = "success" if success else "failure"
        sandbox_executions.labels(status=status).inc()
        sandbox_duration.observe(duration)

    def record_violation(self, violation_type: str, details: dict):
        """Record security violation."""
        sandbox_violations.labels(type=violation_type).inc()
        self.logger.warning(
            f"Sandbox violation: {violation_type}",
            extra=details
        )

    def sandbox_started(self):
        """Record sandbox start."""
        active_sandboxes.inc()

    def sandbox_stopped(self):
        """Record sandbox stop."""
        active_sandboxes.dec()
```

## Summary

Sandboxing AI agents:

1. **Container isolation** - Docker with security options
2. **Network restrictions** - Limit external access
3. **Filesystem isolation** - Restrict file access
4. **Resource limits** - Prevent exhaustion
5. **Secure runtime** - Seccomp, capabilities, AppArmor
6. **Monitoring** - Track violations

Build tools with [Gantz](https://gantz.run), execute safely.

Isolation is not optional. It's essential.

## Related reading

- [Secure Tool Execution](/post/secure-tool-execution/) - Execute tools safely
- [MCP Security](/post/mcp-security-best-practices/) - Security fundamentals
- [Agent Error Handling](/post/agent-error-handling/) - Handle sandbox errors

---

*How do you isolate your AI agents? Share your approaches.*
