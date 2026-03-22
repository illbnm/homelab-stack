# Notifications Stack

Unified notification center providing **ntfy** and **Gotify** for push notifications to mobile and desktop.

## Services

| Service | Image | Purpose | URL |
|---------|-------|---------|-----|
| ntfy | `binwiederhier/ntfy:v2.11.0` | Push notifications server | https://ntfy.${DOMAIN} |
| Gotify | `gotify/server:2.5.0` | Alternative push server | https://gotify.${DOMAIN} |

## Configuration

### ntfy

The ntfy server is configured via `config/ntfy/server.yml` mounted into the container:

```yaml
base-url: https://ntfy.${DOMAIN}
auth-default-access: deny-all
behind-proxy: true
cache-file: /var/cache/ntfy/cache.db
auth-file: /var/lib/ntfy/user.db
```

These settings ensure that ntfy operates behind Traefik, with authentication (user accounts) required to publish/subscribe.

### Gotify

Gotify runs with default settings; no additional configuration required.

## Unified Notification Script

`scripts/notify.sh` provides a simple interface to send notifications:

```bash
./scripts/notify.sh <topic> <title> <message> [priority]
```

Example:

```bash
./scripts/notify.sh homelab "Backup Complete" "Daily backup finished successfully" high
```

The script sends to ntfy by default. To also send to Gotify, uncomment the Gotify section in the script and set `GOTIFY_APP_TOKEN` in your `.env`.

## Integrating with Other Services

### Alertmanager

Configure Alertmanager to send alerts to ntfy via webhook:

```yaml
receivers:
  - name: ntfy
    webhook_configs:
      - url: 'https://ntfy.${DOMAIN}/homelab-alerts'
        send_resolved: true
```

In the alerts rule, set `route` to use this receiver.

### Watchtower

Set environment variable in Watchtower service:

```yaml
environment:
  - WATCHTOWER_NOTIFICATION_URL=ntfy://ntfy.${DOMAIN}/watchtower
  - WATCHTOWER_NOTIFICATION_TEMPLATE={{count}} containers updated: {{list}}.
```

(Note: Watchtower uses its own notification URL format.)

### Gitea

Create a webhook in Gitea admin to send repository events to:

```
https://ntfy.${DOMAIN}/gitea-events
```

Choose "application/json" payload and set secret if desired.

### Home Assistant

Use the ntfy integration in Home Assistant:

- Notification service: `ntfy`
- Server URL: `https://ntfy.${DOMAIN}`
- Topic: choose per-notification or a default.

### Uptime Kuma

Add an ntfy notification button in Uptime Kuma settings:

- URL: `https://ntfy.${DOMAIN}/{topic}`
- Use `POST` method with title in headers.

## Health Checks

Both services provide health endpoints:

- ntfy: `GET /v1/health` (returns 200)
- Gotify: `GET /health` (plain text "ok")

## Security

- Notifications endpoints are exposed via HTTPS with Let's Encrypt.
- ntfy defaults to requiring authentication for publish/subscribe; rely on Traefik forward auth with Authentik if SSO is enabled, or configure ntfy's built-in user DB.
- Consider restricting topics to avoid spam.

## Troubleshooting

- Verify Traefik routing: `traefik.${DOMAIN}` should show dashboard; `ntfy.${DOMAIN}` and `gotify.${DOMAIN}` should load their UIs.
- Test script: `./scripts/notify.sh test "Test" "Hello World"` should push to your device with ntfy app installed.
