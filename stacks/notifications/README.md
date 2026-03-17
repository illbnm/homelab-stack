# Notifications Stack

Unified notification center for Homelab Stack. Supports both ntfy and Gotify backends.

## Services

| Service | Version | Description |
|---------|---------|-------------|
| ntfy | v2.11.0 | Push notification server |
| Gotify | 2.5.0 | Alternative push notification server |

## Quick Start

```bash
# Copy environment template
cp stacks/notifications/.env.example .env

# Start the notification stack
docker compose -f stacks/notifications/docker-compose.yml up -d
```

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `DOMAIN` | Your domain | `yourdomain.com` |
| `NTFY_PORT` | ntfy WebUI port | `8086` |
| `NTFY_AUTH_ENABLED` | Enable ntfy authentication | `true` |
| `GOTIFY_PORT` | Gotify WebUI port | `8087` |
| `GOTIFY_PASSWORD` | Gotify admin password | `changeme` |

## Notification Script

Use `scripts/notify.sh` for unified notifications across all services:

```bash
# Basic notification
./scripts/notify.sh homelab-test "Test" "Hello World"

# With priority (1-5 or min/low/medium/high/urgent)
./scripts/notify.sh homelab-alerts "Alert" "High CPU usage" high
```

### Environment Variables for notify.sh

| Variable | Description | Default |
|----------|-------------|---------|
| `NTFY_ENABLED` | Enable ntfy backend | `true` |
| `GOTIFY_ENABLED` | Enable Gotify backend | `false` |
| `NTFY_SERVER` | ntfy server URL | `http://ntfy:80` |
| `GOTIFY_SERVER` | Gotify server URL | `http://gotify:80` |
| `GOTIFY_TOKEN` | Gotify app token | - |

## Service Integration

### Alertmanager

Add webhook receiver to `config/alertmanager/alertmanager.yml`:

```yaml
receivers:
  - name: 'ntfy'
    webhook_configs:
      - url: 'http://ntfy:80/homelab-alerts'
        send_resolved: true
```

### Watchtower

Set environment variable in your `.env`:

```bash
WATCHTOWER_NOTIFICATION_URL=ntfy://homelab-watchtower
WATCHTOWER_NOTIFICATIONS=ntfy
```

### Gitea

Create a webhook:
- URL: `https://ntfy.${DOMAIN}/homelab-gitea`
- Events: Push, Issues, Pull requests

### Home Assistant

Add to `configuration.yaml`:

```yaml
notify:
  - name: ntfy
    platform: ntfy
    host: http://ntfy
    topic: homelab-homeassistant
```

### Uptime Kuma

Create notification channel:
- URL: `https://ntfy.${DOMAIN}/homelab-uptime`
- Method: POST

## Access

| Service | URL |
|---------|-----|
| ntfy | https://ntfy.${DOMAIN} |
| Gotify | https://gotify.${DOMAIN} |

## Security

- ntfy is configured with `auth-default-access: deny-all` - authentication is required by default
- Change the default ntfy user credentials after first login
- Gotify default user: `admin` / `${GOTIFY_PASSWORD}`

## Testing

```bash
# Test ntfy notification
curl -d "Test message" ntfy.${DOMAIN}/homelab-test

# Or use the notify script
./scripts/notify.sh homelab-test "Test" "Hello from Homelab Stack"
```

## Troubleshooting

### ntfy not receiving notifications

1. Check if authentication is required
2. Verify the topic exists and is accessible
3. Check ntfy logs: `docker logs ntfy`

### Notifications not appearing

1. Verify network connectivity between containers
2. Check Alertmanager logs: `docker logs alertmanager`
3. Ensure webhook URL is correct
