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
