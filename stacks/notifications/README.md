# Notifications Stack

Unified notification center using ntfy (push) + Gotify (backup).

## Services

| Service | Version | URL | Purpose |
|---------|---------|-----|---------|
| ntfy | v2.11.0 | `ntfy.<DOMAIN>` | Push notifications |
| Gotify | 2.5.0 | `gotify.<DOMAIN>` | Backup push server |

## Quick Start

```bash
docker compose -f stacks/notifications/docker-compose.yml up -d
```

## Notification Script

```bash
./scripts/notify.sh homelab-test "Test" "Hello from homelab" high
```

## Service Integration

### Watchtower
Add to base docker-compose.yml:
```yaml
WATCHTOWER_NOTIFICATION_URL=ntfy://ntfy:80/homelab-watchtower?priority=high
WATCHTOWER_NOTIFICATION_TITLE=Watchtower Update
```

### Alertmanager
Add to `config/alertmanager/alertmanager.yml`:
```yaml
receivers:
  - name: ntfy
    webhook_configs:
      - url: 'https://ntfy.${DOMAIN}/homelab-alerts'
        send_resolved: true
route:
  receiver: ntfy
```

### Gitea
In Gitea admin → Webhooks → Add webhook:
- Target URL: `https://ntfy.${DOMAIN}/homelab-gitea`
- Content Type: `text/plain`

### Home Assistant
In `configuration.yaml`:
```yaml
notify:
  - platform: rest
    name: ntfy
    method: POST
    headers:
      Title: "Home Assistant"
    data:
      topic: homelab-homeassistant
    resource: https://ntfy.${DOMAIN}
```

### Uptime Kuma
In monitor settings → Notification → ntfy:
- URL: `https://ntfy.${DOMAIN}/homelab-kuma`
- Priority: High

## Auth

Set ntfy credentials:
```bash
docker exec ntfy ntfy user add --role=admin myuser mypassword
```

Gotify default credentials:
- User: `${GOTIFY_USER:-admin}`
- Pass: `${GOTIFY_PASS:-changeme}`
