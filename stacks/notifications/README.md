# 🔔 Notifications Stack (ntfy + Gotify)

> Production-grade unified notification hub for HomeLab Stack.

Provides real-time push notifications across all self-hosted services using **ntfy** (with native iOS/Android client and web push support) and **Gotify** as a reliable secondary webhook endpoint.

---

## 📦 Services

| Service | Image | Port | Description |
|---|---|---|---|
| **ntfy** | `binwiederhier/ntfy:v2.11.0` | 80 | Primary push notification server |
| **gotify** | `gotify/server:2.5.0` | 80 | Secondary webhook push receiver |

---

## 🚀 Quick Start

1. Ensure the base proxy network is running:
   ```bash
   docker network create proxy || true
   ```
2. Start the notification stack:
   ```bash
   docker compose -f stacks/notifications/docker-compose.yml up -d
   ```
3. Verify access:
   - **ntfy:** `https://ntfy.${DOMAIN}`
   - **Gotify:** `https://gotify.${DOMAIN}`

---

## 🛠️ Unified Dispatch Script: `scripts/notify.sh`

All internal scripts and automation tasks should dispatch alerts through the unified script:

```bash
./scripts/notify.sh <topic> <title> <message> [priority]
```

### Examples:
```bash
# Default notification
./scripts/notify.sh homelab "Backup Completed" "Daily PostgreSQL backup finished in 4.2s."

# High priority alert
./scripts/notify.sh homelab-alerts "Security Warning" "Multiple failed login attempts detected on Traefik." high

# Critical urgency
./scripts/notify.sh homelab-alerts "Disk Full" "Root filesystem / has exceeded 95% usage." urgent
```

Priority mappings:
- `1` / `min`: Low noise
- `2` / `low`: Information only
- `3` / `default`: Standard alert
- `4` / `high`: Important banner
- `5` / `urgent` / `max`: High-priority vibration & sound override

---

## 🔗 Integrations Across Other Services

### 1. Alertmanager
Configured in `config/alertmanager/alertmanager.yml`:
```yaml
receivers:
  - name: ntfy
    webhook_configs:
      - url: 'https://ntfy.${DOMAIN}/homelab-alerts'
        send_resolved: true
```

### 2. Watchtower (Container Updates)
In `stacks/base/docker-compose.yml`, pass the environment variable:
```yaml
environment:
  - WATCHTOWER_NOTIFICATIONS=shoutrrr
  - WATCHTOWER_NOTIFICATION_URL=generic+https://ntfy.${DOMAIN}/homelab-watchtower
```

### 3. Gitea (Repository Webhooks)
Under repository settings -> **Webhooks** -> **Add Webhook** -> **Gitea / Custom**:
- Target URL: `https://ntfy.${DOMAIN}/gitea-events`
- HTTP Method: `POST`
- Event triggers: Push, Pull Request, Issue

### 4. Home Assistant
In `configuration.yaml`:
```yaml
notify:
  - name: ntfy
    platform: rest
    resource: https://ntfy.${DOMAIN}/ha-alerts
    method: POST_JSON
    data:
      topic: ha-alerts
      title: "{{ title }}"
      message: "{{ message }}"
```

### 5. Uptime Kuma (Liveness Monitoring)
Under **Settings** -> **Notifications** -> **Setup Notification**:
- Notification Type: `ntfy`
- Server URL: `https://ntfy.${DOMAIN}`
- Topic: `homelab-uptime`
- Authentication: Token or Basic Auth (if enabled)

---

## 🔒 Security & Access Control

`config/ntfy/server.yml` enforces authenticated access:
```yaml
base-url: https://ntfy.${DOMAIN}
auth-default-access: deny-all
behind-proxy: true
cache-file: /var/cache/ntfy/cache.db
auth-file: /var/lib/ntfy/user.db
```

To create an authorized user:
```bash
docker exec -it ntfy ntfy user add --role admin admin
```
