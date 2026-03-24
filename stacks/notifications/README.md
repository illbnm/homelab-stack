# Notifications Stack

Unified notification center for the HomeLab. All services route notifications through **ntfy** (primary) with **Gotify** as a backup channel.

## Services

| Service | Image | Port | URL | Purpose |
|---------|-------|------|-----|---------|
| ntfy | `binwiederhier/ntfy:v2.11.0` | 80 | `https://ntfy.${DOMAIN}` | Primary push notification server |
| Gotify | `gotify/server:2.5.0` | 80 | `https://gotify.${DOMAIN}` | Backup push notification service |

## Quick Start

```bash
# 1. Ensure proxy network exists
docker network create proxy 2>/dev/null || true

# 2. Start the notifications stack
cd stacks/notifications
docker compose up -d

# 3. Verify services are healthy
docker compose ps

# 4. Send a test notification
../../scripts/notify.sh homelab-test "Test" "Hello World"
```

## ntfy Configuration

The ntfy server config lives at `config/ntfy/server.yml`:

```yaml
base-url: https://ntfy.${DOMAIN}
auth-default-access: deny-all
behind-proxy: true
cache-file: /var/cache/ntfy/cache.db
auth-file: /var/lib/ntfy/user.db
```

### Creating ntfy Users & ACLs

```bash
# Enter the ntfy container
docker exec -it ntfy sh

# Add admin user
ntfy user add --role=admin admin

# Add a regular user
ntfy user add homelab

# Grant access to specific topics
ntfy access homelab homelab-alerts rw
ntfy access homelab watchtower ro

# Grant access to all topics for a user
ntfy access homelab '*' rw
```

### ntfy Mobile App Setup

1. Install **ntfy** from [Google Play](https://play.google.com/store/apps/details?id=io.heckel.ntfy) or [F-Droid](https://f-droid.org/packages/io.heckel.ntfy/)
2. Open the app and add your server: `https://ntfy.${DOMAIN}`
3. Subscribe to topics: `homelab-alerts`, `watchtower`, `homelab-test`
4. Enter your username and password when prompted

## Unified Notification Script

All services should use `scripts/notify.sh` instead of calling ntfy/Gotify APIs directly.

```bash
# Usage
scripts/notify.sh <topic> <title> <message> [priority]

# Priority levels: 1=min, 2=low, 3=default, 4=high, 5=urgent

# Examples
scripts/notify.sh homelab-test "Test" "Hello World"
scripts/notify.sh homelab-alerts "Disk Full" "Root partition at 95%" 5
scripts/notify.sh watchtower "Update" "Container nginx updated to v1.25" 2
```

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `NTFY_URL` | `http://ntfy:80` | ntfy server URL |
| `NTFY_TOKEN` | (empty) | ntfy auth token |
| `GOTIFY_URL` | `http://gotify:80` | Gotify server URL |
| `GOTIFY_TOKEN` | (empty) | Gotify app token (enables fallback) |

The script tries ntfy first. If ntfy fails and `GOTIFY_TOKEN` is set, it falls back to Gotify.

---

## Service Integration Guide

### Alertmanager → ntfy

Alertmanager sends resolved and firing alerts to ntfy via webhook.

**Config file:** `config/alertmanager/alertmanager.yml`

```yaml
receivers:
  - name: ntfy
    webhook_configs:
      - url: 'http://ntfy:80/homelab-alerts'
        send_resolved: true
```

The Alertmanager container must be on the same Docker network as ntfy, or use the Traefik URL `https://ntfy.${DOMAIN}/homelab-alerts`.

To test:

```bash
# Fire a test alert via Alertmanager API
curl -X POST http://localhost:9093/api/v1/alerts \
  -H "Content-Type: application/json" \
  -d '[{
    "labels": {"alertname": "TestAlert", "severity": "critical"},
    "annotations": {"summary": "Test alert from Alertmanager"},
    "startsAt": "2024-01-01T00:00:00Z"
  }]'
```

---

### Watchtower → ntfy

Watchtower notifies when containers are updated. Add these environment variables to the Watchtower service in `stacks/base/docker-compose.yml`:

```yaml
services:
  watchtower:
    environment:
      - WATCHTOWER_NOTIFICATION_URL=generic+https://ntfy.${DOMAIN}/watchtower
      - WATCHTOWER_NOTIFICATION_TEMPLATE={{range .}}{{.Message}}{{end}}
```

**Alternative (internal network):**

If Watchtower and ntfy share a Docker network, use the internal URL:

```yaml
environment:
  - WATCHTOWER_NOTIFICATION_URL=generic+http://ntfy:80/watchtower
  - WATCHTOWER_NOTIFICATION_TEMPLATE={{range .}}{{.Message}}{{end}}
```

To verify, manually trigger a Watchtower check:

```bash
docker exec watchtower /watchtower --run-once
```

---

### Gitea → ntfy

Gitea supports webhooks that can push events (push, PR, issues) to ntfy.

1. Go to **Gitea → Repository Settings → Webhooks → Add Webhook**
2. Select **Custom** webhook type
3. Configure:

| Field | Value |
|-------|-------|
| Target URL | `https://ntfy.${DOMAIN}/gitea` |
| HTTP Method | `POST` |
| Content Type | `application/json` |
| Secret | (leave empty or set ntfy token) |

4. Add a custom header for the notification title:
   - Header: `Title`
   - Value: `Gitea Event`

5. Select events to trigger on: Push, Pull Request, Issues, etc.

**With authentication:** If ntfy requires auth, add a header:
- Header: `Authorization`
- Value: `Bearer <your-ntfy-token>`

---

### Home Assistant → ntfy

Home Assistant has native ntfy integration for automations and alerts.

#### Method 1: RESTful Notifications (configuration.yaml)

```yaml
notify:
  - name: ntfy_homelab
    platform: rest
    resource: https://ntfy.${DOMAIN}/homelab-hass
    method: POST_JSON
    headers:
      Authorization: "Bearer <your-ntfy-token>"
    data:
      topic: homelab-hass
    title_param_name: title
    message_param_name: message
```

#### Method 2: ntfy Custom Integration (via HACS)

1. Install the **ntfy** integration from HACS
2. Configure in **Settings → Integrations → Add Integration → ntfy**
3. Enter:
   - Server URL: `https://ntfy.${DOMAIN}`
   - Topic: `homelab-hass`
   - Username/Password or Token

#### Using in Automations

```yaml
automation:
  - alias: "Notify on door open"
    trigger:
      - platform: state
        entity_id: binary_sensor.front_door
        to: "on"
    action:
      - service: notify.ntfy_homelab
        data:
          title: "Door Alert"
          message: "Front door was opened"
```

---

### Uptime Kuma → ntfy

Uptime Kuma can send notifications to ntfy when monitors go up or down.

1. Go to **Uptime Kuma → Settings → Notifications → Setup Notification**
2. Select **ntfy** as the notification type
3. Configure:

| Field | Value |
|-------|-------|
| Server URL | `https://ntfy.${DOMAIN}` |
| Topic | `uptime-kuma` |
| Priority | `4` (high) for down alerts |
| Username | (your ntfy username) |
| Password | (your ntfy password) |

4. Click **Test** to verify, then **Save**

To apply to all monitors, check **"Apply on all existing monitors"** or set it as the default notification.

---

## Gotify Setup (Backup Service)

Gotify serves as a fallback notification channel.

### Initial Setup

1. Open `https://gotify.${DOMAIN}` in your browser
2. Log in with the default credentials (set via `GOTIFY_PASSWORD` in `.env`)
3. Create an Application:
   - Go to **Apps → Create Application**
   - Name: `homelab`
   - Copy the generated **App Token**
4. Set the token in your environment:
   ```bash
   export GOTIFY_TOKEN="your-app-token"
   ```

### Gotify Mobile App

1. Install the Gotify app from [Google Play](https://play.google.com/store/apps/details?id=com.github.gotify) or [F-Droid](https://f-droid.org/packages/com.github.gotify/)
2. Add your server: `https://gotify.${DOMAIN}`
3. Log in with your credentials

---

## Architecture

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│ Alertmanager │────▶│              │     │              │
├──────────────┤     │              │     │              │
│  Watchtower  │────▶│     ntfy     │────▶│  Mobile App  │
├──────────────┤     │  (primary)   │     │  / Web UI    │
│    Gitea     │────▶│              │     │              │
├──────────────┤     └──────┬───────┘     └──────────────┘
│   Home Asst  │────▶       │
├──────────────┤            │ fallback
│  Uptime Kuma │────▶       ▼
├──────────────┤     ┌──────────────┐     ┌──────────────┐
│   Other      │     │    Gotify    │────▶│  Mobile App  │
│   Services   │────▶│  (backup)    │     │  / Web UI    │
└──────────────┘     └──────────────┘     └──────────────┘

All services → scripts/notify.sh → ntfy (→ Gotify fallback)
```

## Troubleshooting

### ntfy not receiving notifications

1. Check ntfy is healthy: `docker compose ps`
2. Check logs: `docker compose logs ntfy`
3. Verify topic ACLs: `docker exec ntfy ntfy access list`
4. Test directly: `curl -d "test" https://ntfy.${DOMAIN}/test-topic`

### Gotify not receiving notifications

1. Check Gotify is healthy: `docker compose ps`
2. Check logs: `docker compose logs gotify`
3. Verify app token: `curl "https://gotify.${DOMAIN}/application" -H "X-Gotify-Key: <client-token>"`

### Alertmanager not forwarding alerts

1. Check Alertmanager can reach ntfy: `docker exec alertmanager wget -qO- http://ntfy:80/v1/health`
2. Reload Alertmanager config: `curl -X POST http://localhost:9093/-/reload`
3. Check Alertmanager logs: `docker logs alertmanager`

### Watchtower not sending notifications

1. Verify env vars are set: `docker exec watchtower env | grep WATCHTOWER_NOTIFICATION`
2. Check Watchtower logs: `docker logs watchtower`
3. Trigger a manual check: `docker exec watchtower /watchtower --run-once`
