# Robustness & CN Network Adaptation

> **Bounty #8 — $250**  
> Docker mirror acceleration, image localization, and environment health checks for China-based deployments.

## Overview

This feature adds three scripts that make HomeLab Stack work reliably in mainland China, where Docker Hub, GCR, GHCR, and other registries are often blocked or extremely slow.

| Script | Purpose |
|--------|---------|
| `scripts/setup-cn-mirrors.sh` | Configure Docker daemon with CN mirror registries |
| `scripts/localize-images.sh` | Replace blocked registry references in compose files |
| `scripts/check-environment.sh` | Comprehensive environment health report |

## Quick Start

```bash
# 1. Check your environment first
./scripts/check-environment.sh

# 2. If in CN network, setup Docker mirrors (requires root)
sudo ./scripts/setup-cn-mirrors.sh

# 3. Localize compose files for blocked registries
./scripts/localize-images.sh --cn
```

---

## Script 1: `setup-cn-mirrors.sh`

Configures `/etc/docker/daemon.json` with Chinese mirror registries for faster image pulls.

### Mirrors Used (by priority)

| Mirror | Provider |
|--------|----------|
| `docker.m.daocloud.io` | DaoCloud |
| `mirror.baidubce.com` | Baidu |
| `ccr.ccs.tencentyun.com` | Tencent |
| `hub-mirror.c.163.com` | NetEase |
| `registry.docker-cn.com` | Docker CN |

### Usage

```bash
# Setup mirrors (default)
sudo ./scripts/setup-cn-mirrors.sh

# Show current mirror status
./scripts/setup-cn-mirrors.sh --status

# Restore previous daemon.json
sudo ./scripts/setup-cn-mirrors.sh --restore

# Test mirror connectivity
sudo ./scripts/setup-cn-mirrors.sh --verify
```

### Features

- **Idempotent**: safe to run multiple times
- **Auto-backup**: backs up existing `/etc/docker/daemon.json` before changes
- **Merge-aware**: preserves existing daemon.json settings when possible (uses python3 or jq)
- **Auto-restart**: restarts Docker daemon after configuration
- **Verification**: tests pull after setup

---

## Script 2: `localize-images.sh`

Scans all `docker-compose*.yml` files in `stacks/` and replaces blocked registries with CN-accessible mirrors.

### Registry Mapping

| Original | CN Mirror |
|----------|-----------|
| `gcr.io` | `gcr.m.daocloud.io` |
| `ghcr.io` | `ghcr.m.daocloud.io` |
| `k8s.gcr.io` | `k8s-gcr.m.daocloud.io` |
| `registry.k8s.io` | `k8s.m.daocloud.io` |
| `quay.io` | `quay.m.daocloud.io` |
| `us-docker.pkg.dev` | `us-docker.m.daocloud.io` |
| `eu-docker.pkg.dev` | `eu-docker.m.daocloud.io` |
| `asia-docker.pkg.dev` | `asia-docker.m.daocloud.io` |
| `docker.io` | `docker.m.daocloud.io` |

### Usage

```bash
# Check which registries are blocked
./scripts/localize-images.sh --check

# Preview changes (dry run)
./scripts/localize-images.sh --dry-run

# Apply localization
./scripts/localize-images.sh --cn

# Test image accessibility via mirrors (slow)
./scripts/localize-images.sh --accessibility

# Restore original compose files
./scripts/localize-images.sh --restore
```

### Features

- **Safe by default**: defaults to `--check` mode, requires `--cn` to apply
- **Automatic backups**: backs up each modified file before changes
- **Dry-run mode**: preview changes without modifying files
- **Full restore**: can undo all changes from backups

---

## Script 3: `check-environment.sh`

Comprehensive health check that reports on Docker, network, ports, disk, and CN readiness.

### Checks Performed

| Category | Checks |
|----------|--------|
| **Docker** | Version, daemon status, root disk space, volumes, containers |
| **Network** | DNS, global internet, GitHub, Docker Hub, CN mirrors, proxy |
| **Ports** | 80, 443, 3000, 5432, 6379, 8080, 8443, 9090 |
| **Disk** | Root filesystem, HomeLab dir, Docker disk usage |
| **System** | OS, kernel, memory, CPU, uptime |
| **CN Readiness** | Mirror config, blocked registries, NTP sync |
| **Compose** | YAML validation for all stack files |

### Usage

```bash
# Full environment report
./scripts/check-environment.sh

# Source in another script for PASS/FAIL/WARN counters
source ./scripts/check-environment.sh
echo "Failed checks: $FAIL"
```

### Exit Codes

| Code | Meaning |
|------|---------|
| 0 | All checks passed (or only warnings) |
| 1 | Warnings present |
| 2 | Critical failures detected |

---

## Integration with HomeLab Stack

### CN Mode in setup-env.sh

The `setup-env.sh` script already supports `CN_MODE=true`. When enabled, combine with:

```bash
# Full CN setup workflow
sudo ./scripts/setup-cn-mirrors.sh        # Configure Docker mirrors
./scripts/localize-images.sh --cn         # Localize compose images
./scripts/check-environment.sh            # Verify everything works
```

### cn-pull.sh Compatibility

The existing `cn-pull.sh` provides per-image mirror translation for manual pulls. The new scripts complement it by:

- `setup-cn-mirrors.sh`: System-wide Docker daemon config (all pulls accelerated)
- `localize-images.sh`: Compose file changes (permanent, works with `docker compose up`)
- `check-environment.sh`: Pre-flight checks before deployment

### Recommended Workflow

```bash
# Fresh deployment in CN network
git clone https://github.com/illbnm/homelab-stack.git
cd homelab-stack

# Step 1: Environment check
./scripts/check-environment.sh

# Step 2: Setup env
./scripts/setup-env.sh

# Step 3: Docker mirrors (if in CN)
sudo ./scripts/setup-cn-mirrors.sh

# Step 4: Localize images (if in CN)
./scripts/localize-images.sh --cn

# Step 5: Deploy
cd stacks/base && docker compose up -d
```

## Troubleshooting

### Mirror pull fails

```bash
# Check mirror status
./scripts/setup-cn-mirrors.sh --status

# Verify connectivity
sudo ./scripts/setup-cn-mirrors.sh --verify

# Restore original config
sudo ./scripts/setup-cn-mirrors.sh --restore
```

### Compose files broken after localization

```bash
# Restore from backup
./scripts/localize-images.sh --restore
```

### Images still can't pull

```bash
# Check which images are blocked
./scripts/localize-images.sh --check

# Test accessibility
./scripts/localize-images.sh --accessibility

# Use per-image pull with fallback
./scripts/cn-pull.sh <image-name>
```

---

## Additional Scripts (Bounty #8 — Part 2)

### Script 4: `check-connectivity.sh`

Standalone network connectivity check targeting all critical registries and services.

| Check | Targets |
|-------|---------|
| **Host reachability** | Docker Hub, GitHub, gcr.io, ghcr.io, Quay.io |
| **DNS resolution** | hub.docker.com, github.com, gcr.io, ghcr.io |
| **Outbound ports** | 443, 80 on Docker Hub; 443 on GitHub, gcr.io, ghcr.io |

#### Usage

```bash
./scripts/check-connectivity.sh
```

#### Output Format

```
🔍 网络连通性检测
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📡 主机可达性
  [OK]   Docker Hub (hub.docker.com)       — 延迟 120ms
  [SLOW] GitHub (github.com)               — 延迟 1200ms ⚠️ 建议开启镜像加速
  [FAIL] gcr.io                            — 连接超时 ✗ 需要使用国内镜像

建议: 检测到 1 个不可达源，建议运行 ./scripts/setup-cn-mirrors.sh
```

#### Exit Codes

| Code | Meaning |
|------|---------|
| 0 | All reachable (or only slow) |
| 1 | One or more hosts unreachable |

---

### Script 5: `wait-healthy.sh`

Waits for all containers in a Docker Compose stack to reach healthy state. Useful after `docker compose up -d` for CI/CD or deploy scripts.

#### Usage

```bash
# Wait for monitoring stack, max 5 minutes
./scripts/wait-healthy.sh --stack monitoring --timeout 300

# Wait for base services
./scripts/wait-healthy.sh --stack base --timeout 120
```

#### Features

- Polls every 5 seconds
- Detects early container exits (before timeout)
- On failure: prints last 50 log lines of each unhealthy container

#### Exit Codes

| Code | Meaning |
|------|---------|
| 0 | All containers healthy |
| 1 | Timeout — some containers still not healthy |
| 2 | Container exited unexpectedly |

---

### Script 6: `diagnose.sh`

One-click diagnostic report. Collects Docker, system, container, network, and config info.

#### Usage

```bash
# Print to terminal
./scripts/diagnose.sh

# Write to file
./scripts/diagnose.sh --output diagnose-report.txt
```

#### Sections Collected

1. Docker version and configuration
2. System info (OS, kernel, memory, disk)
3. All container statuses
4. Recent error logs (keyword: error/fatal/panic)
5. Network connectivity (calls `check-connectivity.sh` if available)
6. docker-compose YAML validation

---

### Script 7: `curl_retry.sh`

Shared utility function for curl with exponential backoff. Not run directly — `source` it from other scripts.

#### Usage

```bash
source scripts/curl_retry.sh

# Basic usage (same args as curl)
curl_retry -o file.tar.gz https://example.com/file.tar.gz

# Custom retry params
export CURL_RETRY_MAX=5
export CURL_RETRY_DELAY=3
curl_retry -X POST https://api.example.com/webhook
```

#### Default Behavior

- 3 attempts
- 10s connect timeout, 60s max time per attempt
- Exponential backoff: 5s → 10s → 20s

---

### Config: `config/cn-mirrors.yml`

YAML mapping of all `gcr.io` and `ghcr.io` images used in the stack to their DaoCloud mirror equivalents. Used by `setup-cn-mirrors.sh` and `localize-images.sh`.

#### Format

```yaml
mirrors:
  gcr.io/cadvisor/cadvisor: m.daocloud.io/gcr.io/cadvisor/cadvisor
  ghcr.io/goauthentik/server: m.daocloud.io/ghcr.io/goauthentik/server
  ghcr.io/open-webui/open-webui: m.daocloud.io/ghcr.io/open-webui/open-webui
  # ... (all gcr.io/ghcr.io images from compose files)
```
