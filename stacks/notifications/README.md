# Notifications Stack (ntfy + Gotify + Apprise)

This stack provides unified notification delivery across the homelab infrastructure using **ntfy** as the primary notification hub and **Gotify** as a secure self-hosted alternative.

## Services Included

| Service | Port | Default URL | Purpose |
|---|---|---|---|
| **ntfy** | 80 | `https://ntfy.${DOMAIN}` | Primary push notification broker (HTTP-based) |
| **Gotify** | 80 | `https://gotify.${DOMAIN}` | Backup/Secondary self-hosted push notifications |
| **Apprise** | 8000 | `https://apprise.${DOMAIN}` | Multi-target alert gateway |

## Architecture & Configuration

- **ntfy Configuration**: Mounted from `config/ntfy/server.yml`
- **Authentication**: `auth-default-access: deny-all` with SQLite user database at `/var/lib/ntfy/user.db`
- **Cache**: Persistent cache storage at `/var/cache/ntfy/cache.db`

---

## Service Integrations

### 1. Alertmanager
Configured in `config/alertmanager/alertmanager.yml`:
- **Receiver**: `ntfy`
- **Webhook URL**: `https://ntfy.${DOMAIN}/homelab-alerts`
- `send_resolved: true`

### 2. Watchtower
Add the following environment variables to the Watchtower container definition:
- `WATCHTOWER_NOTIFICATIONS=shoutrrr`
- `WATCHTOWER_NOTIFICATION_URL=ntfy://ntfy.${DOMAIN}/homelab-watchtower`

### 3. Gitea
In Gitea repository or system settings (`Settings -> Webhooks`):
- **Target URL**: `https://ntfy.${DOMAIN}/homelab-gitea`
- **HTTP Method**: `POST`
- **Content Type**: `application/json`

### 4. Home Assistant
Add to `configuration.yaml` in Home Assistant:

```yaml
notify:
  - name: ntfy
    platform: rest
    resource: https://ntfy.${DOMAIN}/homelab-ha
    method: POST

```

### 5. Uptime Kuma
In Uptime Kuma Notification Settings (`Settings -> Notifications -> Setup Notification`):
- **Notification Type**: `ntfy`
- **ntfy Server URL**: `https://ntfy.${DOMAIN}`
- **Topic**: `homelab-uptime`
- **Priority**: `Default` or `High`
