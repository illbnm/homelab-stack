# Notifications Stack — 统一通知中心

Unified notification center using **ntfy** (primary) + **Gotify** (backup) + **Apprise** (routing).

## Services

| Service | URL | Purpose |
|---------|-----|---------|
| ntfy | `https://ntfy.${DOMAIN}` | Push notification server (primary) |
| Gotify | `https://gotify.${DOMAIN}` | Backup push service |
| Apprise | `https://apprise.${DOMAIN}` | Notification routing/aggregation |

## Quick Start

```bash
cd stacks/notifications
docker compose up -d
```

## Unified Notification Script

All services should use `scripts/notify.sh` instead of calling ntfy/Gotify APIs directly:

```bash
# Usage: notify.sh <topic> <title> <message> [priority]
# Priority: 1=min, 2=low, 3=default, 4=high, 5=urgent

./scripts/notify.sh homelab-test "Test" "Hello World"
./scripts/notify.sh homelab-alerts "Disk Full" "Root partition at 95%" 5
```

## Service Integration

### Alertmanager → ntfy

Already configured in `config/alertmanager/alertmanager.yml`:

```yaml
receivers:
  - name: ntfy
    webhook_configs:
      - url: 'http://ntfy:80/homelab-alerts'
        send_resolved: true
```

### Watchtower → ntfy

Add to your Watchtower environment:

```env
WATCHTOWER_NOTIFICATION_URL=ntfy://ntfy.${DOMAIN}/homelab-updates
WATCHTOWER_NOTIFICATION_TEMPLATE={{range .}}{{.Time.Format "2006-01-02 15:04:05"}} ({{.Type}}): {{.Message}}{{end}}
```

### Gitea → ntfy

1. Go to Gitea → Repository Settings → Webhooks → Add Webhook
2. URL: `https://ntfy.${DOMAIN}/gitea-events`
3. Content Type: `application/json`
4. Events: Push, Pull Request, Issues

### Home Assistant → ntfy

Add to `configuration.yaml`:

```yaml
notify:
  - name: ntfy
    platform: rest
    resource: https://ntfy.${DOMAIN}/homelab-ha
    method: POST_JSON
    headers:
      Authorization: !secret ntfy_token
    data:
      topic: homelab-ha
    title_param_name: title
    message_param_name: message
```

### Uptime Kuma → ntfy

1. Go to Settings → Notifications → Setup Notification
2. Type: ntfy
3. Server URL: `https://ntfy.${DOMAIN}`
4. Topic: `homelab-uptime`
5. Priority: `high` (for down alerts)

## ntfy Configuration

Config file: `config/ntfy/server.yml`

```yaml
base-url: https://ntfy.${DOMAIN}
auth-default-access: deny-all
behind-proxy: true
cache-file: /var/cache/ntfy/cache.db
auth-file: /var/lib/ntfy/user.db
```

### Create ntfy user (after first start)

```bash
docker exec -it ntfy ntfy user add --role=admin admin
docker exec -it ntfy ntfy token add admin
```

## Environment Variables

Add to your `.env`:

```env
DOMAIN=example.com
GOTIFY_ADMIN_USER=admin
GOTIFY_ADMIN_PASS=your-secure-password
NTFY_TOKEN=tk_your_token_here
```

## Mobile App Setup

1. Install ntfy app ([Android](https://play.google.com/store/apps/details?id=io.heckel.ntfy) / [iOS](https://apps.apple.com/app/ntfy/id1625396347))
2. Add server: `https://ntfy.${DOMAIN}`
3. Subscribe to topics: `homelab-alerts`, `homelab-updates`, `homelab-uptime`
