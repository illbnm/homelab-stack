# Notifications Stack — Unified Push Notifications

Central notification hub for all HomeLab services. Uses **ntfy** as the primary push notification server with **Gotify** as backup and **Apprise** for multi-platform routing.

## Architecture

```
All Services (Alertmanager, Watchtower, Gitea, HA, Uptime Kuma)
   │
   ├──→ scripts/notify.sh (unified interface)
   │         │
   │         ▼
   │    ntfy:80  ───→ ntfy Android/iOS App
   │
   ├──→ Gotify:80 (backup push)
   │
   └──→ Apprise:8000 (Telegram, Discord, Slack, Email…)
```

## Services

| Service | Image | Port | Purpose |
|---------|-------|------|---------|
| ntfy | `binwiederhier/ntfy:v2.11.0` | 80 (internal) | Primary push notifications |
| gotify | `gotify/server:2.5.0` | 80 (internal) | Backup push server |
| apprise | `caronc/apprise:v1.1.6` | 8000 (internal) | Multi-platform router (Telegram, Discord…) |

## Quick Start

```bash
# 1. Start the stack
cd stacks/notifications && docker compose up -d

# 2. Test a notification
../../scripts/notify.sh test "Hello" "Notifications working!" 3 check

# 3. Install the ntfy app on your phone
# Android: https://play.google.com/store/apps/details?id=io.heckel.ntfy
# iOS: https://apps.apple.com/us/app/ntfy/id1625396347
# Subscribe to: https://ntfy.${DOMAIN}/homelab-alerts
```

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `NTFY_TOKEN` | For auth | ntfy access token (generate in ntfy web UI) |
| `GOTIFY_ADMIN_USER` | No | Gotify admin username (default: admin) |
| `GOTIFY_ADMIN_PASSWORD` | No | Gotify admin password (default: admin) |

## Using `scripts/notify.sh`

All services and scripts should use this unified interface:

```bash
# Basic usage
./scripts/notify.sh <topic> <title> <message> [priority] [tags]

# Examples
./scripts/notify.sh backup-status "Backup OK" "Daily backup completed" 3 check
./scripts/notify.sh disk-space "Warning" "Root disk at 85%" 4 warning
./scripts/notify.sh homelab-alerts "CRITICAL" "Container down: nginx" 5 skull
```

**Priority levels:** 1=min, 2=low, 3=default, 4=high, 5=urgent

## Service Integrations

### Alertmanager → ntfy

Alertmanager pushes all alerts to ntfy. Configured in `config/alertmanager/alertmanager.yml`:

```yaml
receivers:
  - name: ntfy
    webhook_configs:
      - url: "http://ntfy:80/homelab-alerts"
        send_resolved: true
```

### Watchtower → ntfy

Watchtower sends update notifications via ntfy URL. Add to `stacks/base/docker-compose.yml`:

```yaml
watchtower:
  environment:
    - WATCHTOWER_NOTIFICATIONS=ntfy
    - WATCHTOWER_NOTIFICATION_NTFY_URL=https://ntfy.${DOMAIN}/watchtower
    - WATCHTOWER_NOTIFICATION_NTFY_TOPIC=watchtower
    - WATCHTOWER_NOTIFICATION_NTFY_TOKEN=${NTFY_TOKEN}
```

### Gitea → ntfy

In Gitea Admin Panel → System Webhooks → Add Webhook:

| Field | Value |
|-------|-------|
| Target URL | `https://ntfy.${DOMAIN}/gitea` |
| HTTP Method | POST |
| POST Content Type | JSON |
| Secret | (empty) |
| Trigger On | Push, Pull Request, Release |

### Home Assistant → ntfy

Add to `configuration.yaml`:

```yaml
notify:
  - name: ntfy
    platform: rest
    resource: https://ntfy.${DOMAIN}/home-assistant
    method: POST
    headers:
      Title: "Home Assistant"
      Priority: 3
    message_param_name: message
```

### Uptime Kuma → ntfy

1. Settings → Notifications → Setup Notification
2. Type: ntfy
3. Server URL: `https://ntfy.${DOMAIN}`
4. Topic: `uptime-kuma`
5. Username/Password: (your ntfy credentials)

### Custom Cron Jobs → notify.sh

```bash
# In any cron script
/path/to/scripts/notify.sh \
  cron-status \
  "Cron: Database Backup" \
  "Backup completed at $(date)" \
  3 check
```

## Gotify Setup

1. Login at `https://gotify.${DOMAIN}` (default: admin/admin)
2. Create a client/app token in Apps → Create Application
3. Use the token in ntfy or Apprise to forward notifications

## Apprise Integration

Apprise lets you route notifications to 100+ platforms. Edit `config/apprise/config.yml`:

```yaml
# Telegram
telegram://${BOT_TOKEN}/${CHAT_ID}/

# Discord
discord://${WEBHOOK_ID}/${WEBHOOK_TOKEN}/

# Slack
slack://${TOKEN}/#alerts

# Email
mailto://smtp.example.com:587?user=alerts@example.com&pass=password
```

Then call Apprise API:

```bash
curl -X POST https://apprise.${DOMAIN}/notify \
  -d '{"urls": "tgram://BOT_TOKEN/CHAT_ID", "body": "Alert from HomeLab!"}'
```

## Mobile Setup

1. Install **ntfy** ([Android](https://play.google.com/store/apps/details?id=io.heckel.ntfy) / [iOS](https://apps.apple.com/us/app/ntfy/id1625396347))
2. Open Settings → Add server
3. URL: `https://ntfy.${DOMAIN}`
4. Subscribe to topics: `homelab-alerts`, `backup-status`, `watchtower`

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| ntfy returns 403 | Set `NTFY_TOKEN` or enable `NTFY_AUTH_DEFAULT_ACCESS=read-only` |
| notify.sh fails | Check ntfy is running: `docker compose -f stacks/notifications/docker-compose.yml ps` |
| Mobile app can't connect | Ensure DNS resolves to your server, port 443 open |
| Alertmanager not sending | Check config mount: `config/alertmanager/alertmanager.yml` is ro-mounted |