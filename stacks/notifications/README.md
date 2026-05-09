# Notifications Stack — ntfy + Gotify Unified Notification Center

Push notifications for all HomeLab services. Uses **ntfy** as primary and **Gotify** as backup.

## Services

| Service | Image | Port | Purpose |
|---------|-------|------|---------|
| ntfy | `binwiederhier/ntfy:v2.11.0` | 80 (internal) | Push notification server |
| Gotify | `gotify/server:2.5.0` | 80 (internal) | Backup push service |

## Quick Start

```bash
# 1. Configure
cp .env.example .env
nano .env

# 2. Start
docker compose up -d

# 3. Test notification
../../scripts/notify.sh test "Hello" "Notifications work!"

# 4. Install ntfy app on your phone
# Android: https://play.google.com/store/apps/details?id=io.heckel.ntfy
# iOS: https://apps.apple.com/app/ntfy/id1625396347
# Or use web: https://ntfy.YOUR_DOMAIN
```

## Integrating Services

### Alertmanager → ntfy

```yaml
# config/alertmanager/alertmanager.yml
receivers:
  - name: ntfy
    webhook_configs:
      - url: "https://ntfy.${DOMAIN}/homelab-alerts"
        send_resolved: true
        http_config:
          authorization:
            type: Bearer
            credentials: "${NTFY_TOKEN}"
```

### Watchtower → ntfy

```yaml
# stacks/base/docker-compose.yml
services:
  watchtower:
    environment:
      WATCHTOWER_NOTIFICATIONS: ntfy
      WATCHTOWER_NOTIFICATION_NTFY_URL: "https://ntfy.${DOMAIN}/watchtower"
      WATCHTOWER_NOTIFICATION_NTFY_TOPIC: watchtower
      WATCHTOWER_NOTIFICATION_NTFY_TOKEN: "${NTFY_TOKEN}"
```

### Gitea → ntfy Webhook

1. Go to Gitea → Repository Settings → Webhooks
2. Add Webhook → Gitea
3. Target URL: `https://ntfy.${DOMAIN}/gitea`
4. HTTP Method: POST
5. Add Header: `Authorization: Bearer ${NTFY_TOKEN}`

### Home Assistant → ntfy

```yaml
# configuration.yaml
notify:
  - name: ntfy
    platform: rest
    resource: https://ntfy.${DOMAIN}/home-assistant
    method: POST
    headers:
      Authorization: "Bearer ${NTFY_TOKEN}"
```

### Uptime Kuma → ntfy

1. Settings → Notifications → Setup Notification
2. Type: Webhook
3. URL: `https://ntfy.${DOMAIN}/uptime-kuma`
4. Method: POST
5. Custom Body:
```json
{"topic":"uptime-kuma","title":"{{title}}","message":"{{msg}}"}
```
6. Headers: `Authorization: Bearer ${NTFY_TOKEN}`

### Using notify.sh in Scripts

```bash
# In any script:
../../scripts/notify.sh homelab-info "Backup Done" "Daily backup completed (42MB)" default floppy_disk
../../scripts/notify.sh homelab-alerts "CPU Spike" "Load average: 12.5" urgent warning
```

## Mobile Setup

### ntfy App

1. Install from app store
2. Tap `+` → Add server
3. Server URL: `https://ntfy.YOUR_DOMAIN`
4. Subscribe to topics: `homelab-alerts`, `homelab-info`, `watchtower`

### Gotify App

1. Install from app store
2. Server URL: `https://gotify.YOUR_DOMAIN`
3. Login with admin credentials
4. Create an app token in Web UI

## Health Check

```bash
# ntfy
curl -s https://ntfy.${DOMAIN}/v1/health

# Gotify
curl -s https://gotify.${DOMAIN}/

# Test full pipeline
./scripts/notify.sh test "Health Check" "All systems operational" default heartbeat
```

## CN Mirror

If Docker Hub is slow, pre-pull images:

```bash
docker pull docker.m.daocloud.io/binwiederhier/ntfy:v2.11.0
docker tag docker.m.daocloud.io/binwiederhier/ntfy:v2.11.0 binwiederhier/ntfy:v2.11.0
```
