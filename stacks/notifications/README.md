# Notifications Stack

Unified notification center featuring **ntfy** and **Gotify** for self-hosted event routing.

## Services

| Service | Version | URL | Purpose |
|---------|---------|-----|---------|
| ntfy | `v2.11.0` | `https://ntfy.<DOMAIN>` | Push notification server (HTTP API & Webhooks) |
| Gotify | `2.5.0` | `https://gotify.<DOMAIN>` | Backup push notification server with Web UI |

## Unified Notification CLI

Use the unified notification script for sending alerts from any local script or cron job:

```bash
./scripts/notify.sh <topic> <title> <message> [priority]
```

Example:
```bash
./scripts/notify.sh alerts "Backup Complete" "Database backup uploaded successfully." 3
```

## Service Integration Guide

| Service | Configuration Method |
|---------|----------------------|
| **Alertmanager** | Configure webhook receiver pointing to `https://ntfy.<DOMAIN>/<topic>` (see `config/alertmanager/alertmanager.yml`) |
| **Watchtower** | Set environment variable: `WATCHTOWER_NOTIFICATION_URL=ntfy://ntfy.<DOMAIN>/watchtower?token=YOUR_TOKEN` |
| **Gitea** | Add Webhook -> Post Receivers -> URL: `https://ntfy.<DOMAIN>/gitea` (JSON payload) |
| **Home Assistant** | Configure ntfy notify integration via configuration.yaml using `https://ntfy.<DOMAIN>` |
| **Uptime Kuma** | Add Notification Channel -> Webhook -> URL: `https://ntfy.<DOMAIN>/uptime-kuma` |

## Configuration Files

- `stacks/notifications/config/server.yml`: ntfy server configuration
- `stacks/notifications/docker-compose.yml`: Stack definitions and Traefik reverse proxy routing
