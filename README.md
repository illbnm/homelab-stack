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
| [Network](stacks/network/) | AdGuard Home, Unbound, WireGuard Easy, Cloudflare DDNS | [#4](../../issues/4) |
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
│   ├── setup-authentik.sh        # SSO: Create OIDC providers for all services
│   ├── nextcloud-oidc-setup.sh   # SSO: Configure Nextcloud Social Login
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
    ├── sso-integration.md         # Authentik SSO setup & service integration
    ├── getting-started.md          # (待实现)
    ├── services.md                # (待实现)
    ├── configuration.md           # (待实现)
    ├── cn-network.md              # (待实现)
    ├── backup-restore.md          # (待实现)
    └── troubleshooting.md         # (待实现)
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

## 📄 License

MIT
