# Notifications Stack

Centralized notification hub for your homelab. Routes alerts from all services through ntfy, Gotify, and Apprise.

## Services

| Service | Port | URL | Purpose |
|---------|------|-----|---------|
| **ntfy** | 8095 | `https://ntfy.<DOMAIN>` | Pub/sub push notifications (mobile-first) |
| **Gotify** | — | `https://gotify.<DOMAIN>` | Self-hosted push notification server with web UI |
| **Apprise** | 8096 | `https://apprise.<DOMAIN>` | Unified notification API (150+ services) |

### How They Work Together

```
Alertmanager ──┐
Watchtower  ───┤
Uptime Kuma ───┼──► ntfy ──► Phone App
Gitea       ───┤         └──► Gotify ──► Web Dashboard
Home Assist ───┘
                      ntfy ──► Apprise ──► Slack/Discord/Email/...
```

- **ntfy**: Primary push channel. Lightweight, excellent mobile apps for iOS/Android. All services send alerts here.
- **Gotify**: Secondary push channel. Provides a persistent web dashboard to browse notification history.
- **Apprise**: Translation layer. Can forward ntfy messages to Slack, Discord, Telegram, email, and 150+ other services.

## Quick Start

### 1. Configure Environment

```bash
# Set required variables in .env
GOTIFY_PASSWORD=<your-gotify-password>
GOTIFY_APP_TOKEN=<will-set-after-first-login>
NTFY_ADMIN_USER=admin
NTFY_ADMIN_PASSWORD=<your-ntfy-password>
```

### 2. Start Services

```bash
cd stacks/notifications
docker compose up -d
```

### 3. Create ntfy Users

ntfy is configured with `auth-default-access: deny-all`, so you must create users before subscribing.

```bash
# Create admin user (from the host, using the internal port)
curl -s -u ":<NTFY_ADMIN_PASSWORD>" \
  -X POST http://localhost:8095/v1/users \
  -d '{"username":"admin","password":"<NTFY_ADMIN_PASSWORD>"}'

# Grant admin access to all topics (tier=none = full access)
curl -s -u "admin:<NTFY_ADMIN_PASSWORD>" \
  -X POST http://localhost:8095/v1/access/tokens \
  -d '{"label":"admin-token","expires":""}'
```

Then create the `homelab-alerts` topic (or any topic you need) — topics are created automatically when a message is sent, but the user needs read/write permission:

```bash
# Grant admin read-write access to homelab-alerts topic
curl -s -u "admin:<NTFY_ADMIN_PASSWORD>" \
  -X POST http://localhost:8095/v1/access \
  -d '{"topic":"homelab-alerts","role":"read-write","user":"admin"}'

# Also grant access for the alertmanager topic
curl -s -u "admin:<NTFY_ADMIN_PASSWORD>" \
  -X POST http://localhost:8095/v1/access \
  -d '{"topic":"homelab-updates","role":"read-write","user":"admin"}'
```

### 4. Configure ntfy Mobile App

1. Download **ntfy** from [App Store](https://apps.apple.com/app/ntfy/id1625396347) or [Google Play](https://play.google.com/store/apps/details?id=io.heckel.ntfy)
2. Open the app → tap the **+** button
3. Add your server: `https://ntfy.<DOMAIN>`
4. Subscribe to topics: `homelab-alerts`, `homelab-updates`
5. Enter your ntfy credentials when prompted
6. Enable **background notifications** in app settings

### 5. Setup Gotify

1. Open `https://gotify.<DOMAIN>` in your browser
2. Login with username `admin` and your `GOTIFY_PASSWORD`
3. **Create an app token**: Click the **APPS** button (top right) → **CREATE APPLICATION**
   - Name: `homelab`
   - Description: `Homelab notifications`
4. Copy the generated token and set it in `.env` as `GOTIFY_APP_TOKEN`
5. Restart services that need the token: `docker compose restart`

## Unified Notification Script

`scripts/notify.sh` sends notifications to both ntfy and Gotify simultaneously.

```bash
# Basic usage
./scripts/notify.sh <topic> <title> <message> [priority]

# Examples
./scripts/notify.sh homelab-alerts "Server Warning" "Disk usage at 85%" 4
./scripts/notify.sh homelab-updates "Update Available" "nginx:1.25 -> 1.26" 2
./scripts/notify.sh test "Test" "This is a test notification" 5
```

**Priority levels**: min=1, low=2, default=3, high=4, max=5

## Service Integration

### Alertmanager

Already configured in `config/alertmanager/alertmanager.yml`. Alerts are sent to `http://ntfy:80/homelab-alerts`.

No additional configuration needed.

### Watchtower

Add to your Watchtower docker-compose environment:

```yaml
environment:
  - WATCHTOWER_NOTIFICATION_URL=http://ntfy:80/homelab-updates
  - WATCHTOWER_NOTIFICATIONS=ntfy
```

### Gitea

1. Go to Gitea → **Settings** → **Notifications**
2. Add a webhook pointing to `http://ntfy:80/gitea-events`
3. Or use Gitea's built-in ntfy integration in **Settings** → **Webhooks**

### Home Assistant

Add to your `configuration.yaml`:

```yaml
notify:
  - name: ntfy
    platform: rest
    resource: http://ntfy:80/homeassistant
    method: POST_JSON
    data:
      title: "{{ title }}"
      message: "{{ message }}"
      priority: "{{ priority | default(3) }}"
```

### Uptime Kuma

1. Open Uptime Kuma → **Settings** → **Notifications**
2. Click **Add**
3. Select **ntfy** from the notification type dropdown
4. Fill in:
   - **ntfy Server URL**: `http://ntfy:80`
   - **ntfy Topic**: `homelab-uptime`
5. Save and test

## Acceptance Testing

Run these checks after deployment:

```bash
# 1. Check all containers are healthy
docker compose ps

# 2. Test ntfy (send a test notification)
curl -X POST http://localhost:8095/homelab-alerts \
  -H "Title: Test Alert" \
  -H "Priority: 3" \
  -d "If you see this, ntfy is working!"

# 3. Test Gotify health
curl -sf http://localhost:8080/health

# 4. Test Apprise health
curl -sf http://localhost:8096/

# 5. Test the unified notification script (run from repo root)
./scripts/notify.sh test "Acceptance Test" "All notification services are operational" 5

# 6. Verify you receive the notification on your phone (ntfy app) and browser (Gotify)
```

## Troubleshooting

### ntfy: "401 Unauthorized" when sending messages

The topic requires authentication. Make sure you've created users and granted access:

```bash
# Check existing users
curl -s -u "admin:<password>" http://localhost:8095/v1/users

# Grant access to the topic
curl -s -u "admin:<password>" \
  -X POST http://localhost:8095/v1/access \
  -d '{"topic":"homelab-alerts","role":"read-write","user":"admin"}'
```

### Gotify: "GOTIFY_APP_TOKEN not set"

You need to create an application token in the Gotify web UI and add it to your `.env` file. See step 5 in the Quick Start.

### Notifications not arriving on phone

1. Check the ntfy app is subscribed to the correct topic
2. Verify background notifications are enabled (iOS: Settings → ntfy → Notifications; Android: check battery optimization)
3. Test by sending directly: `curl -X POST https://ntfy.<DOMAIN>/homelab-alerts -d "test"`
4. Check ntfy server logs: `docker logs ntfy --tail 50`

### Alertmanager not sending to ntfy

1. Check Alertmanager can reach ntfy: `docker exec alertmanager wget -qO- http://ntfy:80/v1/health`
2. Verify `alertmanager.yml` is valid: `docker exec alertmanager amtool check-config /etc/alertmanager/alertmanager.yml`
3. Check Alertmanager logs: `docker logs alertmanager --tail 50`

### Gotify shows 502 Bad Gateway

Traefik might not have the correct service port. Verify Gotify is running: `docker compose logs gotify`. Make sure the container is healthy before checking Traefik.
