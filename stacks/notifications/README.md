# Notifications Stack

Unified notification center for HomeLab Stack. Deploy **ntfy** and **Gotify** so every service can push alerts to your phone, desktop, or webhook consumers.

## What's Included

| Service | Version | URL | Purpose |
|---------|---------|-----|---------|
| ntfy | 2.11.0 | `ntfy.<DOMAIN>` | HTTP pub/sub push notifications |
| Gotify | 2.5.0 | `gotify.<DOMAIN>` | Self-hosted push notification server with web UI & apps |

## Prerequisites

- Base infrastructure stack running (Traefik, proxy network)
- `.env` file configured (see below)

## Quick Start

```bash
# From repo root
cd stacks/notifications
ln -sf ../../.env .env
docker compose up -d
```

## Configuration

### Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `DOMAIN` | ✅ | — | Base domain (from root `.env`) |
| `TZ` | — | `Asia/Shanghai` | Timezone |
| `GOTIFY_PASSWORD` | ✅ | — | Gotify `admin` user password |
| `NTFY_AUTH_ENABLED` | — | `true` | Enable ntfy authentication |

### ntfy Configuration

Server config is at `config/ntfy/server.yml`. Key settings:

- **Auth**: deny-all by default; create users/topics after first deploy
- **Behind proxy**: enabled (Traefik handles TLS)
- **Cache**: 12h default, 5G attachment limit

#### Create ntfy Users & Topics

```bash
# Access ntfy container
docker exec -it ntfy sh

# Create admin user
ntfy user add --role=admin admin

# Create a topic with restricted access
ntfy access admin homelab-alerts rw

# Generate a user token (for scripts / webhooks)
ntfy token add admin
```

### Gotify Configuration

Gotify stores data in `gotify-data` volume. On first login:

1. Navigate to `https://gotify.<DOMAIN>`
2. Login with username `admin` and the `GOTIFY_PASSWORD` value
3. Create application tokens for services that need to push notifications
4. Install Gotify mobile/desktop client and connect with token

---

## Service Integration Guide

### Alertmanager → ntfy (Prometheus Alerts)

Edit `config/alertmanager/alertmanager.yml`:

```yaml
receivers:
  - name: ntfy
    webhook_configs:
      - url: 'https://ntfy.${DOMAIN}/homelab-alerts'
        send_resolved: true
        http_config:
          basic_auth:
            username: admin
            password: '<ntfy-admin-password>'

route:
  receiver: ntfy
  routes:
    - match:
        severity: critical
      receiver: ntfy
      continue: true
```

Then reload Alertmanager: `curl -X POST http://localhost:9093/-/reload`

### Watchtower → Gotify

Add to Watchtower environment in `stacks/base/docker-compose.yml`:

```yaml
environment:
  WATCHTOWER_NOTIFICATIONS: gotify
  WATCHTOWER_NOTIFICATION_GOTIFY_URL: https://gotify.${DOMAIN}
  WATCHTOWER_NOTIFICATION_GOTIFY_TOKEN: '<gotify-app-token>'
  WATCHTOWER_NOTIFICATION_GOTIFY_TLS_SKIP_VERIFY: "false"
```

### Gitea → ntfy

In Gitea: **Settings → Webhooks → Add Webhook → Custom**

- Target URL: `https://ntfy.${DOMAIN}/gitea-events`
- Content type: `application/json`
- Trigger on: Push, Pull Request, Issue events

### Home Assistant → ntfy

Add to `configuration.yaml`:

```yaml
notify:
  - platform: ntfy
    name: homelab
    url: https://ntfy.${DOMAIN}
    topic: ha-alerts
    authentication: basic
    username: admin
    password: !secret ntfy_password
```

### Uptime Kuma → ntfy

In Uptime Kuma: **Settings → Notifications → Add Notification**

- Type: ntfy
- Server URL: `https://ntfy.${DOMAIN}`
- Topic: `uptime-kuma`
- Priority: 4 (default)
- Username/Password: ntfy credentials

### Uptime Kuma → Gotify

In Uptime Kuma: **Settings → Notifications → Add Notification**

- Type: Gotify
- Server URL: `https://gotify.${DOMAIN}`
- Application Token: `<gotify-app-token>`

---

## Notification Script

Use `scripts/notify.sh` as a unified CLI interface from any script or cron job:

```bash
# Basic usage
./scripts/notify.sh <topic> <title> <message> [priority]

# Examples
./scripts/notify.sh homelab-test "Test" "Hello World"
./scripts/notify.sh backup "Backup Complete" "DB backup finished at $(date)" 4
./scripts/notify.sh alerts "Disk Warning" "Usage at 85%" 5
```

Priority levels: 1 (min) → 5 (max/urgent). Default: 3.

---

## Architecture

```
                    ┌─────────────────────────────────┐
                    │          Traefik (:443)          │
                    └──────┬──────────────┬───────────┘
                           │              │
              ┌────────────▼──┐    ┌──────▼──────────┐
              │  ntfy.<DOMAIN>│    │gotify.<DOMAIN>  │
              │   (pub/sub)   │    │  (push server)  │
              └──────┬────────┘    └──────┬──────────┘
                     │                    │
          ┌──────────┼──────────┐        │
          │          │          │        │
   Alertmanager  Gitea     Uptime    Watchtower
   (webhook)   (webhook)   Kuma     (env var)
```

## Troubleshooting

```bash
# Check service health
docker ps --filter "name=ntfy" --filter "name=gotify"

# ntfy logs
docker logs ntfy --tail 50

# Gotify logs
docker logs gotify --tail 50

# Test ntfy push
curl -u admin:password -d "Test message" https://ntfy.${DOMAIN}/test-topic

# Test Gotify push
curl -X POST "https://gotify.${DOMAIN}/message?token=YOUR_TOKEN" \
  -F "title=Test" -F "message=Hello" -F "priority=5"
```
