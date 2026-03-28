# HomeLab Stack — Stacks Overview

This directory contains all service stacks for the HomeLab. Each stack is self-contained and can be deployed independently (except for dependencies noted below).

> **Important:** The **Base Stack** (`base/`) must be deployed **before** any other stack, as it provides the shared `proxy` Docker network and Traefik reverse proxy.

## Stack Index

| Stack | Description | Order |
|-------|-------------|-------|
| [base/](base/README.md) | Traefik + Portainer + Watchtower | **0 — Deploy first** |
| [network/](network/) | AdGuard Home + WireGuard + Nginx Proxy Manager | 1 |
| [sso/](sso/README.md) | Authentik (OIDC/SSO provider) | 2 |
| [databases/](databases/) | PostgreSQL + Redis + MariaDB | 2 |
| [storage/](storage/) | Nextcloud + MinIO + FileBrowser | 2 |
| [media/](media/) | Jellyfin + Sonarr + Radarr + qBittorrent + Prowlarr | 3 |
| [productivity/](productivity/) | Gitea + Vaultwarden + Outline + BookStack | 3 |
| [home-automation/](home-automation/) | Home Assistant + Node-RED + Zigbee2MQTT + Mosquitto | 3 |
| [monitoring/](monitoring/) | Prometheus + Grafana + Loki + Alertmanager | 3 |
| [notifications/](notifications/) | ntfy + Apprise | 4 |
| [backup/](backup/) | Restic + Duplicati (automated backups) | 4 |
| [ai/](ai/) | Ollama + Open WebUI + Stable Diffusion | 4 |
| [dashboard/](dashboard/) | Homarr / organizr (dashboard) | 4 |

## Quick Start

```bash
# 1. Deploy base stack first
cd stacks/base
ln -sf ../../.env .env
docker compose up -d

# 2. Deploy any additional stack
cd ../network
ln -sf ../../.env .env
docker compose up -d
```

## Shared Network

All stacks use the `proxy` Docker network created by the base stack. This network is used by Traefik to route traffic to services based on hostname labels.

```bash
# Create the proxy network (if not already created)
docker network create proxy
```

## Environment Variables

All stacks share the root `.env` file. Copy `.env.example` to `.env` at the repo root and configure:

| Variable | Required | Description |
|----------|----------|-------------|
| `DOMAIN` | ✅ | Base domain, e.g. `home.example.com` |
| `TZ` | ✅ | Timezone, e.g. `Asia/Shanghai` |
| `ACME_EMAIL` | ✅ | Email for Let's Encrypt certificates |
| `CN_MODE` | — | `true` to use CN Docker mirrors |

## Port Reference

| Port | Service | Notes |
|------|---------|-------|
| 53 | AdGuard Home | May conflict with systemd-resolved |
| 80/443 | Traefik | Base stack |
| 51820/UDP | WireGuard | VPN server |
| 51821 | WireGuard Web UI | HTTP (not HTTPS) |
| 8181 | Nginx Proxy Manager Admin | HTTP |
| 8143 | Nginx Proxy Manager SSL | |

## DNS Configuration

After deploying the network stack, configure your router or device DNS to point to your HomeLab server's IP on port 53. AdGuard Home will then filter ads and provide DNS-based tracking protection.

### systemd-resolved Conflict

On systems with systemd-resolved, port 53 is occupied. Use the fix script:

```bash
# Check if systemd-resolved is using port 53
sudo ./scripts/fix-dns-port.sh --check

# Disable systemd-resolved (requires reboot)
sudo ./scripts/fix-dns-port.sh --apply
```
