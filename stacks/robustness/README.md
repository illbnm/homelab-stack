# Robustness Stack — China Network Adaptation

> 让 HomeLab Stack 在任何网络环境下都能可靠部署

## 🗺️ Overview

This stack provides network resilience tools for deploying the homelab stack from mainland China or in restricted network environments. It addresses:

- **Docker Hub / GCR / GHCR / Quay.io** inaccessibility
- **GitHub raw content** slow or blocked connections
- **DNS pollution** and resolution failures
- **Slow/corrupt package downloads** (apt, pip, npm)

## 📁 Files

```
stacks/robustness/
├── README.md                    # This file
├── docker-compose.yml           # (optional) diagnostic container
└── config/
    └── cn-mirrors.yml          # Official mirror mapping table

scripts/
├── setup-cn-mirrors.sh          # Configure Docker daemon.json mirrors
├── localize-images.sh           # Replace gcr.io/ghcr.io in compose files
├── check-connectivity.sh        # Test reachability of all registries
├── wait-healthy.sh              # Wait for stack containers to be healthy
└── diagnose.sh                  # Generate full diagnostic report
```

## 🚀 Quick Start

### 1. Detect China Network & Configure Mirrors

```bash
# Interactive mode (recommended for first run)
sudo ./scripts/setup-cn-mirrors.sh --interactive

# Auto-detect and configure
sudo ./scripts/setup-cn-mirrors.sh --cn

# Check current status
./scripts/setup-cn-mirrors.sh --status

# Test mirror speeds
./scripts/setup-cn-mirrors.sh --test
```

### 2. Replace Image Registries in Compose Files

```bash
# Preview what will be changed (dry run)
./scripts/localize-images.sh --dry-run --cn

# Apply the replacement
./scripts/localize-images.sh --cn

# Restore original (when outside China)
./scripts/localize-images.sh --restore

# Check status without changes
./scripts/localize-images.sh --check
```

### 3. Test Connectivity

```bash
./scripts/check-connectivity.sh
```

Expected output:
```
=== Docker Registries ===
  [OK]   docker.io — 45ms
  [OK]   gcr.io — 120ms
  [SLOW] ghcr.io — 1200ms ⚠️ Consider CN mirror
  [FAIL] quay.io — connection timeout

=== Summary ===
  ⚠️  1 source(s) slow, 1 unreachable — CN adaptation recommended

  Run: sudo ./scripts/setup-cn-mirrors.sh --cn
       ./scripts/localize-images.sh --cn
```

### 4. Wait for Stack Health

```bash
# Wait for a stack to be fully healthy
./scripts/wait-healthy.sh --stack monitoring --timeout 600

# With custom compose file
./scripts/wait-healthy.sh --compose ./docker-compose.yml --timeout 300
```

### 5. Generate Diagnostic Report

```bash
# Print to stdout
./scripts/diagnose.sh

# Save to file
./scripts/diagnose.sh /tmp/diagnose-$(date +%Y%m%d).txt
```

## 🔧 Manual Configuration

### /etc/docker/daemon.json

```json
{
  "registry-mirrors": [
    "https://mirror.ccs.tencentyun.com",
    "https://docker.m.daocloud.io"
  ]
}
```

Then reload:
```bash
sudo systemctl reload docker
```

### /etc/hosts — GitHub Accessibility

If GitHub is slow or blocked, add these entries to `/etc/hosts`:

```
140.82.112.4    github.com
140.82.112.10   api.github.com
185.199.108.133  raw.githubusercontent.com
185.199.109.133  user-images.githubusercontent.com
185.199.110.133  packages.cloud.githubusercontent.com
```

Apply:
```bash
sudo tee -a /etc/hosts < /dev/null # (copy entries above)
```

Verify:
```bash
curl -sf https://github.com -o /dev/null && echo "GitHub OK"
```

### apt — Use Tsinghua Mirror

```bash
# Replace Ubuntu apt sources with Tsinghua mirror
sudo sed -i 's|http://archive.ubuntu.com|https://mirrors.tuna.tsinghua.edu.cn|g' \
  /etc/apt/sources.list

# Replace Alpine with USTC mirror
sudo sed -i 's|dl-cdn.alpinelinux.org|mirrors.ustc.edu.cn|g' \
  /etc/apk/repositories

# Replace PyPI with Tsinghua mirror
pip install -i https://pypi.tuna.tsinghua.edu.cn/simple some-package

# Or set permanently
mkdir -p ~/.config/pip
echo '[global]
index-url = https://pypi.tuna.tsinghua.edu.cn/simple' > ~/.config/pip/pip.conf
```

## 🌐 Supported Chinese Mirror Providers

| Provider | URL | Registries |
|----------|-----|-----------|
| **DaoCloud** | `m.daocloud.io` | gcr.io, ghcr.io, k8s.gcr.io, quay.io, docker.io |
| **Tencent Cloud** | `mirror.ccs.tencentyun.com` | docker.io |
| **163 (NetEase)** | `hub-mirror.c.163.com` | docker.io |
| **Baidu Cloud** | `mirror.baidubce.com` | docker.io |

## 🔄 Fallback Behavior

All scripts implement automatic fallback:

1. Try Chinese mirror first
2. If mirror fails → try original registry
3. If original fails → report error with helpful suggestions

For `cn-pull.sh` (single image):
```bash
./scripts/cn-pull.sh ghcr.io/home-assistant/home-assistant
# 1. Tries: ghcr.m.daocloud.io/home-assistant/home-assistant
# 2. On failure: falls back to direct ghcr.io pull
```

## ⚠️ China Network Challenges

| Problem | Symptom | Solution |
|---------|---------|----------|
| GCR/GHCR blocked | `connection timeout` on `docker pull` | Use `setup-cn-mirrors.sh` + `localize-images.sh` |
| GitHub raw slow | `curl` hangs >10s | Add `/etc/hosts` entries above |
| Docker Hub slow | `docker pull` takes minutes | Configure `registry-mirrors` in daemon.json |
| DNS pollution | Wrong IP for github.com | Use `1.1.1.1` or `8.8.8.8` DNS |
| apt sources blocked | `apt-get install` fails | Use `mirrors.tuna.tsinghua.edu.cn` |
| pip install slow | PyPI timeout | Use `--index-url=https://pypi.tuna.tsinghua.edu.cn/simple` |

## 🔒 Safety & Idempotency

- `setup-cn-mirrors.sh --restore` always reverts to original config
- `localize-images.sh --restore` uses timestamped backups in `.localization-backup/`
- All scripts are idempotent — safe to re-run
- No hardcoded passwords or secrets in any scripts

## 🧪 Testing

```bash
# Test all scripts
shellcheck scripts/setup-cn-mirrors.sh
shellcheck scripts/localize-images.sh
shellcheck scripts/check-connectivity.sh
shellcheck scripts/wait-healthy.sh
shellcheck scripts/diagnose.sh

# Functional test (from China)
./scripts/check-connectivity.sh
./scripts/setup-cn-mirrors.sh --test
```
