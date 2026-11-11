# Notifications Stack — ntfy + Gotify Unified Push Center

## Service Integration Matrix

| Service | Integration Method | Configuration Snippet |
|---|---|---|
| **Alertmanager** | Webhook receiver -> `ntfy` | `webhook_configs: [{ url: 'https://ntfy.${DOMAIN}/homelab-alerts', send_resolved: true }]` |
| **Watchtower** | `WATCHTOWER_NOTIFICATION_URL` | `WATCHTOWER_NOTIFICATION_URL=ntfy://${NTFY_TOKEN}@ntfy.${DOMAIN}/watchtower` |
| **Gitea** | Repository / Org Webhook | Target URL: `https://ntfy.${DOMAIN}/gitea-commits` (`Content-Type: application/json`) |
| **Home Assistant** | `ntfy` Notify Integration | `notify: [{ name: ntfy, platform: rest, resource: https://ntfy.${DOMAIN}/homeassistant }]` |
| **Uptime Kuma** | Notification Channel -> `ntfy` | Topic: `uptime-alerts`, Server URL: `https://ntfy.${DOMAIN}`, Auth: Bearer Token |

## CLI Usage

```bash
./scripts/notify.sh homelab-test "Test" "Hello World" high
```
