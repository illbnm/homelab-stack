# 🏠 HomeLab Stack

> One-click self-hosted services deployment platform for home servers and VPS.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Bounties](https://img.shields.io/badge/bounties-%242340-orange)](BOUNTY.md)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)
[![Docker](https://img.shields.io/badge/docker-required-blue.svg)](https://docs.docker.com/get-docker/)
[![Self Hosted](https://img.shields.io/badge/self--hosted-40%2B%20services-purple.svg)](BOUNTY.md)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)
[![Bounties Available](https://img.shields.io/badge/bounties-available-orange.svg)](BOUNTY.md)

**HomeLab Stack** is a production-grade, one-command deployment platform for 40+ self-hosted services. It handles reverse proxying, SSO, monitoring, alerting, backups, and CN network compatibility — all wired together out of the box.

---

## 🚀 Quick Start

```bash
# 1. Clone the repo
git clone https://github.com/YOUR_USERNAME/homelab-stack.git
cd homelab-stack

# 2. Check dependencies & setup environment
./install.sh

# 3. Launch base infrastructure
docker compose -f docker-compose.base.yml up -d

# 4. Launch any stack
./scripts/stack-manager.sh start media
./scripts/stack-manager.sh start monitoring
./scripts/stack-manager.sh start sso
```

> **China users**: Run `./scripts/setup-cn-mirrors.sh` first to configure Docker registry mirrors and apt sources.

---

## 📦 Service Catalog

| Stack | Services | Bounty |
|-------|----------|--------|
| [Base Infrastructure](stacks/base/) | Traefik, Portainer, Watchtower | ✅ Core |
| [Media](stacks/media/) | Jellyfin, Sonarr, Radarr, Prowlarr, qBittorrent, Jellyseerr | [#2](../../issues/2) |
| [Storage](stacks/storage/) | Nextcloud, MinIO, FileBrowser, Syncthing | [#3](../../issues/3) |
| [Monitoring](stacks/monitoring/) | Grafana, Prometheus, Loki, Alertmanager, Uptime Kuma | [#4](../../issues/4) |
| [Network](stacks/network/) | AdGuard Home, WireGuard Easy, Cloudflare DDNS, Nginx Proxy Manager | [#5](../../issues/5) |
| [Productivity](stacks/productivity/) | Gitea, Vaultwarden, Outline, Stirling-PDF, IT-Tools | [#6](../../issues/6) |
| [AI](stacks/ai/) | Ollama, Open WebUI, LocalAI, n8n | [#7](../../issues/7) |
| [Home Automation](stacks/home-automation/) | Home Assistant, Node-RED, Mosquitto, Zigbee2MQTT, ESPHome | [#8](../../issues/8) |
| [SSO / Auth](stacks/sso/) | Authentik, PostgreSQL, Redis | [#9](../../issues/9) |
| [Dashboard](stacks/dashboard/) | Homepage, Heimdall | [#10](../../issues/10) |
| [Notifications](stacks/notifications/) | Gotify, Ntfy, Apprise | [#11](../../issues/11) |

---

## 🏗️ Architecture

```
Internet
   │
   ▼
[Traefik v3]  ← Reverse proxy, auto HTTPS, Forward Auth
   │
   ├── [Authentik]     ← SSO / OIDC provider (all services)
   │
   ├── [Monitoring]    ← Prometheus + Grafana + Loki + Alertmanager
   │
   ├── [Media Stack]   ← Jellyfin + *arr suite
   ├── [Storage Stack] ← Nextcloud + MinIO
   ├── [AI Stack]      ← Ollama + Open WebUI
   └── [...]
```

All stacks share:
- A common `proxy` Docker network (Traefik accessible)
- A shared `databases` stack (PostgreSQL + Redis + MariaDB)
- Authentik SSO via Forward Auth middleware
- Centralized logging via Promtail → Loki

---

## 📁 Project Structure

```
homelab-stack/
├── install.sh                    # Entry point — env check + guided setup
├── docker-compose.base.yml       # Core infrastructure
├── .env.example                  # All configurable variables
├── BOUNTY.md                     # Bounty task overview
│
├── stacks/                       # One directory per service group
│   ├── media/
│   ├── storage/
│   ├── monitoring/
│   ├── network/
│   ├── productivity/
│   ├── ai/
│   ├── home-automation/
│   ├── sso/
│   ├── dashboard/
│   ├── databases/
│   └── notifications/
│
├── scripts/
│   ├── check-deps.sh             # Dependency + network check
│   ├── setup-env.sh              # Interactive .env generator
│   ├── setup-cn-mirrors.sh       # CN mirror configuration
│   ├── stack-manager.sh          # Start/stop/update stacks
│   ├── backup.sh                 # Volume backup
│   └── prefetch-images.sh        # Pre-pull all images
│
├── config/
│   ├── traefik/
│   ├── prometheus/
│   ├── alertmanager/
│   ├── loki/
│   ├── grafana/
│   └── authentik/
│
└── docs/
    ├── getting-started.md
    ├── services.md
    ├── configuration.md
    ├── cn-network.md
    ├── sso-integration.md
    ├── backup-restore.md
    └── troubleshooting.md
```

---

## 💰 Contributing & Bounties

This project has **active bounties** on open issues. See [BOUNTY.md](BOUNTY.md) for the full list.

Each bounty task is self-contained with:
- Exact deliverables
- Acceptance criteria
- Test instructions

See [CONTRIBUTING.md](CONTRIBUTING.md) for contribution guidelines.

---

## 📋 Requirements

- Linux (Ubuntu 22.04+ recommended) or macOS
- Docker Engine 24+
- Docker Compose v2.20+
- 4GB RAM minimum (8GB+ recommended)
- A domain name (optional, but recommended for HTTPS)

---

## 💾 Backup & Recovery

### Quick Backup

```bash
# 备份所有栈
./scripts/backup.sh --target all

# 仅备份媒体栈
./scripts/backup.sh --target media

# 预览备份内容 (不实际执行)
./scripts/backup.sh --target all --dry-run
```

### List & Verify Backups

```bash
# 列出所有备份
./scripts/backup.sh --list

# 验证备份完整性
./scripts/backup.sh --verify
```

### Restore from Backup

```bash
# 恢复指定备份
./scripts/backup.sh --restore 20260331_120000
```

### Backup Targets

支持多种备份目标 (通过 `.env` 中的 `BACKUP_TARGET` 配置):

- **local**: 本地目录 (默认)
- **s3**: Amazon S3 或兼容存储
- **b2**: Backblaze B2
- **sftp**: SFTP 服务器

### Automated Backups

添加到 crontab 实现自动备份:

```bash
# 每天凌晨 2 点自动备份
0 2 * * * /path/to/homelab-stack/scripts/backup.sh --target all >> /var/log/homelab-backup.log 2>&1
```

### Disaster Recovery

完整的灾难恢复文档请参考 [docs/disaster-recovery.md](docs/disaster-recovery.md)

---

## 📄 License

MIT
