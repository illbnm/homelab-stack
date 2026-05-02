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

## 📄 License

MIT

## 📦 Media Stack Setup

The Media Stack provides a complete set of tools for managing your media collection, including torrent downloading, media management, and media serving. This stack includes Jellyfin, Sonarr, Radarr, Prowlarr, qBittorrent, and Jellyseerr. Below are the steps to set up and configure this stack.

### 📁 Directory Structure

Before starting the stack, ensure the following directory structure is in place:

```
/data/
├── torrents/
│   ├── movies/
│   └── tv/
└── media/
    ├── movies/
    └── tv/
```

These directories are used for storing downloaded torrents and the final media files respectively.

### 📜 Environment Variables

Create a `.env` file in the `stacks/media/` directory with the following variables:

```env
MEDIA_ROOT=/data/media
DOWNLOADS_ROOT=/data/torrents
PUID=1000
PGID=1000
TZ=Asia/Shanghai

JELLYFIN_WEBUI_PASSWORD=your_password
SONARR_API_KEY=your_api_key
RADARR_API_KEY=your_api_key
PROWLARR_API_KEY=your_api_key
QBTT_API_KEY=your_api_key
JELLYSEERR_API_KEY=your_api_key
```

### 📁 Docker Compose Configuration

Here is the `docker-compose.yml` file for the Media Stack:

```yaml
version: '3.8'

services:
  jellyfin:
    image: jellyfin/jellyfin:10.9.11
    container_name: jellyfin
    volumes:
      - ${MEDIA_ROOT}:/config
      - ${MEDIA_ROOT}:/media
    environment:
      - PUID=${PUID}
      - PGID=${PGID}
      - TZ=${TZ}
    ports:
      - 8080:8080
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080"]
      interval: 10s
      timeout: 10s
      retries: 5

  sonarr:
    image: lscr.io/linuxserver/sonarr:4.0.11
    container_name: sonarr
    volumes:
      - ${DOWNLOADS_ROOT}/tv:/data
    environment:
      - PUID=${PUID}
      - PGID=${PGID}
      - TZ=${TZ}
      - Sonarr_ApiKey=${SONARR_API_KEY}
    ports:
      - 8981:8981
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8981"]
      interval: 10s
      timeout: 10s
      retries: 5
    depends_on:
      - qbittorrent

  radarr:
    image: lscr.io/linuxserver/radarr:5.8.1
    container_name: radarr
    volumes:
      - ${DOWNLOADS_ROOT}/movies:/data
    environment:
      - PUID=${PUID}
      - PGID=${PGID}
      - TZ=${TZ}
      - Radarr_ApiKey=${RADARR_API_KEY}
    ports:
      - 8982:8982
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8982"]
      interval: 10s
      timeout: 10s
      retries: 5
    depends_on:
      - qbittorrent

  prowlarr:
    image: lscr.io/linuxserver/prowlarr:1.22.0
    container_name: prowlarr
    volumes:
      - /etc/localtime:/etc/localtime:ro
    environment:
      - PUID=${PUID}
      - PGID=${PGID}
      - TZ=${TZ}
      - Prowlarr_ApiKey=${PROWLARR_API_KEY}
    ports:
      - 8983:8983
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8983"]
      interval: 10s
      timeout: 10s
      retries: 5

  qbittorrent:
    image: lscr.io/linuxserver/qbittorrent:4.6.7
    container_name: qbittorrent
    volumes:
      - ${DOWNLOADS_ROOT}:/data
    environment:
      - PUID=${PUID}
      - PGID=${PGID}
      - TZ=${TZ}
      - qBittorrent_WebUIPassword=${QBTT_API_KEY}
    ports:
      - 8081:8081
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8081"]
      interval: 10s
      timeout: 10s
      retries: 5

  jellyseerr:
    image: fallenbagel/jellyseerr:2.1.1
    container_name: jellyseerr
    volumes:
      - /etc/localtime:/etc/localtime:ro
    environment:
      - PUID=${PUID}
      - PGID=${PGID}
      - TZ=${TZ}
      - Jellyseerr_ApiKey=${JELLYSEERR_API_KEY}
    ports:
      - 8984:8984
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8984"]
      interval: 10s
      timeout: 10s
      retries: 5
```

### 📝 Configuration Notes

- Ensure that the Traefik reverse proxy is configured to route traffic to these services using the appropriate subdomains.
- For Sonarr and Radarr to connect to qBittorrent, configure the API keys in their respective settings.
- Jellyfin should be configured to point to the media directories under `/data/media`.
