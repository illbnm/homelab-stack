# 🔔 Notifications Stack (ntfy + Apprise / Gotify)

This stack provides a unified notification dispatch hub for the Homelab ecosystem.

---

## 📦 Services Included

- **ntfy (`v2.11.0`)**: High-performance HTTP-based pub-sub push notification service.
- **Apprise (`v1.1.6`) / Gotify**: Backup push server and universal notification router.

---

## ⚙️ Configuration & Deployment

### 1. File Structure
- `config/ntfy/server.yml`: Server configuration enforcing proxy header trust and authentication rules.
- `config/alertmanager/alertmanager.yml`: Alertmanager webhook receiver pointing to `ntfy`.
- `scripts/notify.sh`: Unified CLI interface for sending notifications.

### 2. Launch Stack

```bash
docker compose -f stacks/notifications/docker-compose.yml up -d
```

---

## 🛠️ Service Integrations Guide

### 1. Alertmanager Integration
Configure webhook receivers in `config/alertmanager/alertmanager.yml`:

```yaml
receivers:
  - name: ntfy
    webhook_configs:
      - url: 'https://ntfy.${DOMAIN}/homelab-alerts'
        send_resolved: true
```

### 2. Watchtower Integration
Pass the `ntfy` URL environment variable in your Watchtower container configuration:

```yaml
environment:
  - WATCHTOWER_NOTIFICATION_URL=ntfy://ntfy.${DOMAIN}/homelab-watchtower
```

### 3. Gitea Webhook Integration
1. Open Gitea -> **Repository Settings** -> **Webhooks**.
2. Add Webhook -> Select **ntfy**.
3. Target URL: `https://ntfy.${DOMAIN}/gitea-commits`

### 4. Home Assistant Integration
Add `ntfy` notification channel in `configuration.yaml`:

```yaml
notify:
  - name: ntfy
    platform: rest
    resource: https://ntfy.${DOMAIN}/ha-alerts
    method: POST_JSON
```

### 5. Uptime Kuma Integration
1. Go to **Settings** -> **Notifications** -> **Add Notification**.
2. Select Notification Type: **ntfy**.
3. Set Topic URL: `https://ntfy.${DOMAIN}/uptime-kuma`.

---

## 🧪 Testing Notifications CLI

Send a test message using the unified CLI script:

```bash
./scripts/notify.sh homelab-test "System Alert" "Notification system operational!" 4
```
