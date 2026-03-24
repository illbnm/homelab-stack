# 📢 Notifications Stack

> Push notification services for your homelab — ntfy + Gotify

## Services

| Service | Purpose | Web UI |
|---------|---------|--------|
| **ntfy** | Pub-sub push notifications (phone apps, curl, webhooks) | `https://ntfy.${DOMAIN}` |
| **Gotify** | Self-hosted push notifications with Android app | `https://gotify.${DOMAIN}` |

## Quick Start

```bash
# Copy environment template
cp .env.example .env
# Edit .env — set GOTIFY_PASSWORD and domain

# Start the stack
docker compose up -d
```

## Integration Guide

### Alertmanager Webhook

Point Alertmanager at ntfy as a webhook receiver:

```yaml
# In config/alertmanager/alertmanager.yml
receivers:
  - name: ntfy-receiver
    webhook_configs:
      - url: 'https://ntfy.example.com/alerts'
        send_resolved: true
```

Or use `scripts/notify.sh` in a CronJob / script-based alert:

```bash
# Alert from any script
./scripts/notify.sh -t "Disk Full" -p high "Root filesystem is 95% full"
```

### Watchtower Notifications

Add to your Watchtower environment:

```yaml
environment:
  WATCHTOWER_NOTIFICATIONS: ntfy
  WATCHTOWER_NOTIFICATION_NTFY_URL: https://ntfy.example.com
  WATCHTOWER_NOTIFICATION_NTFY_TOPIC: homelab
  WATCHTOWER_NOTIFICATION_NTFY_TOKEN: ${NTFY_TOKEN}
  WATCHTOWER_NOTIFICATION_NTFY_PRIORITY: default
```

### Gitea Webhook

In Gitea → Repository → Settings → Webhooks → Add Webhook:

- **URL**: `https://ntfy.example.com/gitea`
- **Content Type**: `application/json`
- **Secret**: leave blank (or set for verification)
- **Trigger**: choose events you want notifications for

### Home Assistant Integration

Use the [ntfy integration](https://www.home-assistant.io/integrations/ntfy/) or call via REST:

```yaml
notify:
  - platform: rest
    name: ntfy
    resource: https://ntfy.example.com/homelab
    method: POST
    headers:
      Authorization: "Bearer ${NTFY_TOKEN}"
    message_param_name: data
```

### Uptime Kuma

In Uptime Kuma → Settings → Notifications:

1. Add **ntfy** notification type
2. Server URL: `https://ntfy.example.com`
3. Topic: `homelab`
4. Auth: Bearer token if ntfy auth is enabled

### Gotify Android App

1. Install [Gotify Android](https://gotify.net/docs/install)
2. Add server URL: `https://gotify.${DOMAIN}`
3. Create an application token in the Gotify web UI

## Unified Notify Script

`scripts/notify.sh` sends to both ntfy and Gotify simultaneously:

```bash
# Basic usage
./scripts/notify.sh "Something happened"

# With title and priority
./scripts/notify.sh -t "Backup Complete" -p low "Weekly backup finished"

# Send to only one service
./scripts/notify.sh -s ntfy "ntfy only message"
./scripts/notify.sh -s gotify "gotify only message"
```

## Environment Variables

See [`.env.example`](.env.example) for all configurable options.

| Variable | Default | Description |
|----------|---------|-------------|
| `GOTIFY_PASSWORD` | — | **Required.** Gotify admin password |
| `NTFY_AUTH_ENABLED` | `true` | Enable ntfy authentication |
| `DOMAIN` | — | Base domain for Traefik routing |
| `NTFY_TOKEN` | — | ntfy bearer token for authenticated publishes |
| `GOTIFY_TOKEN` | — | Gotify application token |
| `NTFY_TOPIC` | `homelab` | Default ntfy topic |

## Health Checks

Both services have built-in health checks:

- **ntfy**: `curl -sf http://localhost:80/v1/health`
- **Gotify**: `curl -sf http://localhost:80/health`

Check status:
```bash
docker ps --filter "name=ntfy" --filter "name=gotify" --format "table {{.Names}}\t{{.Status}}"
```

## Architecture

```
                     ┌──────────────┐
   Scripts/Services ─┤  notify.sh   ├──→ ntfy  → 📱 ntfy app
                     └──────────────┘   │
                                        └──→ Gotify → 📱 Gotify app
   Alertmanager ─────→ ntfy webhook
   Watchtower  ─────→ ntfy webhook
   Gitea       ─────→ ntfy webhook
```
