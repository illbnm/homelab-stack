# Notifications Stack

> Unified notification center - ntfy + Gotify

## 💰 Bounty

**$80 USDT** - See [BOUNTY.md](../../BOUNTY.md)

## Services

| Service | Image | Purpose |
|---------|-------|---------|
| ntfy | `binwiederhier/ntfy:v2.11.0` | Push notification server |
| Gotify | `gotify/server:2.5.0` | Alternative push service |

## Quick Start

### 1. Configure environment

```bash
cd stacks/notifications
cp .env.example .env
# Edit .env with your settings
```

### 2. Start services

```bash
docker compose up -d
```

### 3. Test notification

```bash
# Test ntfy
curl -d "Test message" http://localhost:8080/homelab-test

# Or use the notify script
./scripts/notify.sh homelab "Test" "Hello World"
```

## Access URLs

| Service | URL |
|---------|-----|
| ntfy | `https://ntfy.yourdomain.com` |
| Gotify | `https://gotify.yourdomain.com` |

## Configuration

### Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `DOMAIN` | Your domain | `example.com` |
| `NTFY_ADMIN_USER` | ntfy admin username | `admin` |
| `NTFY_ADMIN_PASSWORD` | ntfy admin password | `xxxx` |
| `GOTIFY_ADMIN_USER` | Gotify admin username | `admin` |
| `GOTIFY_ADMIN_PASSWORD` | Gotify admin password | `xxxx` |
| `GOTIFY_APP_TOKEN` | Gotify app token | `xxxx` |

## Integration Guides

### 1. Watchtower

Add to your service's docker-compose.yml:

```yaml
environment:
  - WATCHTOWER_NOTIFICATIONS=ntfy
  - WATCHTOWER_NOTIFICATION_URL=http://ntfy:80/homelab-watchtower
```

Or for Gotify:

```yaml
environment:
  - WATCHTOWER_NOTIFICATIONS=gotify
  - WATCHTOWER_NOTIFICATION_GOTIFY_URL=http://gotify:80
  - WATCHTOWER_NOTIFICATION_GOTIFY_TOKEN=${GOTIFY_APP_TOKEN}
```

### 2. Alertmanager

Add webhook receiver to `config/alertmanager/alertmanager.yml`:

```yaml
receivers:
  - name: 'ntfy'
    webhook_configs:
      - url: 'http://ntfy:80/homelab-alerts'
        send_resolved: true
```

### 3. Home Assistant

Add to `configuration.yaml`:

```yaml
notify:
  - name: ntfy
    platform: ntfy
    url: http://ntfy:80
    topic: homelab-homeassistant
```

### 4. Uptime Kuma

1. Go to **Settings → Notification**
2. Add notification: **ntfy**
3. Configure:
   - URL: `http://ntfy:80`
   - Topic: `homelab-uptime`

### 5. Gitea

1. Go to **Site Administration → Webhooks**
2. Add webhook:
   - URL: `http://ntfy:80/homelab-gitea`
   - Events: Push, Issues, PR

### 6. Generic curl

```bash
# Send to ntfy
curl -H "Title: Alert" -d "Disk space low" http://ntfy:80/homelab-alerts

# Send with priority
curl -H "Title: Critical" -H "Priority: 4" -d "Server down!" http://ntfy:80/homelab-critical
```

## notify.sh Script

Use the unified notification script:

```bash
# Basic notification
./notify.sh homelab "Title" "Message"

# With priority (max, high, default, low, min)
./notify.sh homelab "Alert" "Disk full" "high"
```

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `NTFY_SERVER` | `http://ntfy:80` | ntfy server URL |
| `GOTIFY_SERVER` | `http://gotify:80` | Gotify server URL |
| `GOTIFY_TOKEN` | - | Gotify app token |

## Mobile App

### ntfy

1. Install ntfy app from [App Store](https://apps.apple.com/app/ntfy/id1629121564) / [Play Store](https://play.google.com/store/apps/details?id=io.heckel.ntfy)
2. Subscribe to your topic: `https://ntfy.yourdomain.com/homelab`
3. Enable notifications

### Gotify

1. Install Gotify app from [Play Store](https://play.google.com/store/apps/details=com.gotify.android)
2. Configure server: `https://gotify.yourdomain.com`
3. Create app token and login

## ntfy Topics

| Topic | Purpose |
|-------|---------|
| `homelab-alerts` | General alerts |
| `homelab-critical` | Critical alerts |
| `homelab-watchtower` | Container updates |
| `homelab-backup` | Backup status |
| `homelab-health` | Health checks |

## Troubleshooting

### Check logs

```bash
docker logs ntfy
docker logs gotify
```

### Common issues

1. **Notifications not arriving**
   - Check ntfy topic subscription
   - Verify network connectivity between containers

2. **ntfy authentication error**
   - Check `NTFY_ADMIN_USER` and `NTFY_ADMIN_PASSWORD`
   - Verify auth-default-access setting

3. **Gotify app token invalid**
   - Create app token in Gotify UI
   - Update `GOTIFY_APP_TOKEN` in .env

## File Structure

```
stacks/notifications/
├── docker-compose.yml    # Main compose file
├── .env.example         # Environment template
└── README.md            # This file

config/
├── ntfy/
│   └── server.yml       # ntfy configuration
└── alertmanager/
    └── alertmanager.yml # Alertmanager routing

scripts/
└── notify.sh           # Unified notification script
```

## License

MIT
