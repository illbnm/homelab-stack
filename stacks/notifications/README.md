# Notifications Stack

Unified notification hub — ntfy (primary) + Gotify (backup).

## Services

| Service | URL | Purpose |
|---------|-----|---------|
| ntfy | ntfy.yourdomain.com | Push notifications (Android/iOS apps available) |
| Gotify | gotify.yourdomain.com | Web UI + REST API notifications |

## Setup

```bash
cp .env.example .env && nano .env
# Replace ${DOMAIN} in config/ntfy/server.yml with your actual domain

docker compose up -d
```

## Integrations

### Watchtower → ntfy
```yaml
environment:
  - WATCHTOWER_NOTIFICATION_URL=generic+https://ntfy.yourdomain.com/watchtower
```

### Alertmanager → ntfy
```yaml
receivers:
  - name: ntfy
    webhook_configs:
      - url: https://ntfy.yourdomain.com/alerts
        send_resolved: true
```

### Gitea → ntfy
Settings → Webhooks → Add → ntfy URL: `https://ntfy.yourdomain.com/gitea`

### Send a test notification
```bash
curl -d "Test from homelab" https://ntfy.yourdomain.com/homelab
```

## Mobile Apps

- **ntfy**: [Android](https://play.google.com/store/apps/details?id=io.heckel.ntfy) | [iOS](https://apps.apple.com/app/ntfy/id1625396347)
- **Gotify**: Android only via [APK](https://github.com/gotify/android/releases)
