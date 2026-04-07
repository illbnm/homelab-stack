# 🛡️ Robustness & China Network Adaptation

> Complete guide for environment robustness and China network compatibility

## 📋 Overview

This implementation provides comprehensive robustness features for HomeLab Stack, ensuring reliable deployment in any network environment with special focus on China mainland network adaptation.

## 🚀 Quick Start

### For China Users

```bash
# 1. Configure Docker mirrors
sudo ./scripts/setup-cn-mirrors.sh

# 2. Localize container images
./scripts/localize-images.sh --cn

# 3. Verify connectivity
./scripts/check-connectivity.sh

# 4. Install with robust error handling
./install.sh
```

### For International Users

```bash
# 1. Check connectivity
./scripts/check-connectivity.sh

# 2. Install with robust error handling
./install.sh
```

---

## 📦 Components

### 1. Docker Mirror Setup (`setup-cn-mirrors.sh`)

Interactive script to configure Docker registry mirrors for China network acceleration.

**Features:**
- Auto-detection of China network environment
- Multiple mirror sources with fallback
- Backup existing Docker configuration
- Verify mirror configuration with test pull

**Usage:**
```bash
sudo ./scripts/setup-cn-mirrors.sh
```

**Mirror Sources:**
- DaoCloud (docker.m.daocloud.io) - Most reliable
- 163 (hub-mirror.c.163.com) - NetEase
- Baidu Cloud (mirror.baidubce.com)
- GCR Mirror (mirror.gcr.io)

**What it does:**
- Creates backup of `/etc/docker/daemon.json`
- Configures multiple registry mirrors
- Restarts Docker daemon
- Verifies with `docker pull hello-world`

---

### 2. Image Localization (`localize-images.sh`)

Automatically replaces foreign container registries with China-accessible mirrors.

**Features:**
- Replace gcr.io, ghcr.io, k8s.gcr.io, registry.k8s.io, quay.io
- Dry-run mode for preview
- Automatic backup before modification
- Restore functionality

**Usage:**
```bash
# Preview changes (recommended first)
./scripts/localize-images.sh --dry-run

# Apply China mirror replacements
./scripts/localize-images.sh --cn

# Check if localization is needed
./scripts/localize-images.sh --check

# Restore original files
./scripts/localize-images.sh --restore
```

**Configuration:** `config/cn-mirrors.yml`

The script uses a YAML configuration file that maps foreign registries to CN mirrors:

```yaml
mirrors:
  gcr.io/cadvisor/cadvisor: gcr.m.daocloud.io/cadvisor/cadvisor
  ghcr.io/goauthentik/server: ghcr.m.daocloud.io/goauthentik/server
  # ... more mappings
```

---

### 3. Connectivity Checker (`check-connectivity.sh`)

Comprehensive network connectivity diagnostics tool.

**Features:**
- Tests reachability of all essential registries
- Measures latency with slow detection
- DNS resolution tests
- Port availability checks
- Provides actionable recommendations

**Usage:**
```bash
./scripts/check-connectivity.sh
```

**Test Results:**
```
[OK]   Docker Hub (hub.docker.com) — 120ms
[SLOW] GitHub (github.com) — 1200ms ⚠️
[FAIL] gcr.io — Connection failed ✗
```

**Recommendations:**
- Suggests mirror configuration if failures detected
- Provides specific commands to fix issues

---

### 4. Robust Install Script (`install.sh`)

Enhanced installer with comprehensive error handling and CN support.

**Features:**
- Auto-install Docker on Ubuntu/Debian/CentOS/Arch
- Check Docker Compose version (promote v2)
- Port conflict detection
- Disk space and memory checks
- Firewall rules verification
- Retry logic for network requests
- Non-root user handling
- China network auto-detection

**Usage:**
```bash
./install.sh
```

**Robustness Features:**
- Exponential backoff for failed network requests
- Automatic user addition to docker group
- Validates system resources before proceeding
- Creates backups of configuration files
- Logs all operations for troubleshooting

**Error Handling:**
```bash
# All network requests use retry logic
curl_retry() {
  local max_attempts=3
  local delay=5
  # Exponential backoff: 5s -> 10s -> 20s
}
```

---

### 5. Health Wait Script (`wait-healthy.sh`)

Wait for all containers in a stack to become healthy.

**Features:**
- Polls health check status
- Custom timeout configuration
- Automatic log collection on failure
- Exit codes for automation

**Usage:**
```bash
# Wait for specific stack
./scripts/wait-healthy.sh --stack monitoring --timeout 300

# Wait for specific compose file
./scripts/wait-healthy.sh --file ./stacks/media/docker-compose.yml

# Default timeout (300s)
./scripts/wait-healthy.sh --stack base
```

**Exit Codes:**
- `0` - All containers healthy
- `1` - Timeout with unhealthy containers
- `2` - Stack or compose file not found

**Output Example:**
```
[45s/300s] Checking health status... ✓✓✓✓
✓ All containers are healthy!

=== Health Check Summary ===
  Total services:  4
  Healthy:         4
  No health check: 0
  Time elapsed:    45s
```

---

### 6. Diagnostic Tool (`diagnose.sh`)

Comprehensive system diagnostic collection tool.

**Features:**
- System information (OS, CPU, memory, disk)
- Docker configuration and status
- Container health status
- Network configuration
- Error log collection
- Configuration validation
- Connectivity tests
- Actionable recommendations

**Usage:**
```bash
./scripts/diagnose.sh
```

**Output:**
- Console output with colored status
- Full report saved to `diagnose-report.txt`

**Report Sections:**
1. System Information
2. Docker Information
3. Container Status
4. Network Information
5. Recent Error Logs
6. Configuration Status
7. Network Connectivity Tests
8. Recommendations

**Use Cases:**
- Pre-deployment health check
- Troubleshooting deployment issues
- Collecting information for issue reports

---

## 🎯 Workflow Examples

### First-time Installation in China

```bash
# Step 1: Check current connectivity
./scripts/check-connectivity.sh

# Step 2: Configure Docker mirrors
sudo ./scripts/setup-cn-mirrors.sh

# Step 3: Localize container images
./scripts/localize-images.sh --dry-run  # Preview
./scripts/localize-images.sh --cn       # Apply

# Step 4: Install with robust installer
./install.sh

# Step 5: Verify deployment
./scripts/wait-healthy.sh --stack base --timeout 300

# Step 6: Generate diagnostic report if issues
./scripts/diagnose.sh
```

### Troubleshooting Network Issues

```bash
# 1. Check connectivity
./scripts/check-connectivity.sh

# 2. If failures detected, configure mirrors
sudo ./scripts/setup-cn-mirrors.sh

# 3. Localize images if needed
./scripts/localize-images.sh --cn

# 4. Collect diagnostic report
./scripts/diagnose.sh

# 5. Attach diagnose-report.txt when creating issue
```

### Automated Deployment

```bash
#!/bin/bash
# Automated deployment script

# Install with non-interactive mode
./install.sh

# Wait for base stack
if ./scripts/wait-healthy.sh --stack base --timeout 600; then
  echo "Base stack healthy, deploying services..."
  ./scripts/stack-manager.sh start sso
  ./scripts/wait-healthy.sh --stack sso --timeout 300
else
  echo "Base stack failed, collecting diagnostics..."
  ./scripts/diagnose.sh
  exit 1
fi
```

---

## 📊 Verification

### Verify Mirror Configuration

```bash
# Check Docker info for mirrors
docker info | grep -A 5 "Registry Mirrors"

# Test pull speed
time docker pull gcr.io/cadvisor/cadvisor:v0.50.0
```

### Verify Image Localization

```bash
# Check compose files for foreign registries
./scripts/localize-images.sh --check

# Should return: "All images already using accessible registries"
```

### Verify Health Checks

```bash
# Check specific stack
./scripts/wait-healthy.sh --stack monitoring --timeout 300

# Check all running containers
docker ps --format 'table {{.Names}}\t{{.Status}}'
```

---

## 🔧 Configuration

### Custom Mirror Sources

Edit `config/cn-mirrors.yml` to add custom mirror mappings:

```yaml
mirrors:
  # Add custom mappings
  gcr.io/custom-image: gcr.m.daocloud.io/custom-image

# Use regional mirrors
aliyun:
  gcr.io/cadvisor/cadvisor: registry.cn-hangzhou.aliyuncs.com/google_containers/cadvisor
```

### Custom Timeout Values

```bash
# wait-healthy.sh supports custom timeout
./scripts/wait-healthy.sh --stack media --timeout 600  # 10 minutes
```

---

## 🐛 Troubleshooting

### Docker Pull Fails

```bash
# 1. Check connectivity
./scripts/check-connectivity.sh

# 2. Configure mirrors
sudo ./scripts/setup-cn-mirrors.sh

# 3. Localize images
./scripts/localize-images.sh --cn

# 4. Use cn-pull script for individual images
./scripts/cn-pull.sh gcr.io/cadvisor/cadvisor:v0.50.0
```

### Container Unhealthy

```bash
# 1. Check container logs
docker logs <container-name>

# 2. Wait with detailed output
./scripts/wait-healthy.sh --stack <name> --timeout 600

# 3. Collect diagnostic report
./scripts/diagnose.sh

# 4. Check logs in report
cat diagnose-report.txt | grep -A 20 "Recent Error Logs"
```

### Network Timeout

```bash
# 1. Check connectivity
./scripts/check-connectivity.sh

# 2. Increase timeout if needed
./scripts/wait-healthy.sh --stack <name> --timeout 900  # 15 minutes

# 3. Check DNS resolution
nslookup hub.docker.com
```

---

## 📝 Shell Script Quality

All scripts follow best practices:

- ✅ **Strict mode**: `set -euo pipefail`
- ✅ **Error handling**: Comprehensive trap and exit codes
- ✅ **Logging**: Both console and file output
- ✅ **Idempotency**: Safe to run multiple times
- ✅ **Validation**: Check prerequisites before execution
- ✅ **ShellCheck**: Passes without errors

Run shellcheck:
```bash
shellcheck scripts/*.sh
```

---

## 🎓 Learning Resources

- [Docker Mirror Configuration](https://docs.docker.com/registry/recipes/mirror/)
- [China Docker Mirror Guide](https://yeasy.gitbook.io/docker_practice/install/mirror)
- [Shell Scripting Best Practices](https://github.com/dylanaraps/pure-bash-bible)

---

## 🤝 Contributing

Found a bug or want to improve the robustness?

1. Run `./scripts/diagnose.sh` and attach the report
2. Describe your network environment
3. List steps to reproduce
4. Submit PR with improvements

---

## 📜 License

MIT License - Part of HomeLab Stack project
