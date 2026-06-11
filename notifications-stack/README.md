# Notifications Stack — ntfy + Gotify
Unified notification center for homelab services.

## Integrations
- **Alertmanager**: webhook to ntfy `/homelab-alerts`
- **Watchtower**: `WATCHTOWER_NOTIFICATION_URL=ntfy://ntfy.localhost/watchtower`
- **Gitea**: webhook to ntfy `/gitea`
- **Home Assistant**: ntfy notify integration
- **Uptime Kuma**: ntfy notification channel

## Deployment
1. Start: `docker compose up -d`
2. Send test notification: `./scripts/notify.sh homelab-test "Test" "Hello World"`
