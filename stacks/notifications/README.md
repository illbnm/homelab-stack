# Notifications Stack

Unified notification center — push alerts and messages from any service to any platform.

**Components:**
- [Gotify](https://gotify.net/) 2.5 — Self-hosted push notification server with Android/Web client
- [Apprise API](https://github.com/caronc/apprise-api) — Gateway to 90+ notification services (Telegram, Slack, Discord, Email, Matrix, ntfy...)

## Quick Start

```bash
cp .env.example .env
nano .env

docker compose up -d
```

## Usage

### Gotify — Push Notifications

1. Create an app in the Gotify UI: `https://notify.${DOMAIN}`
2. Send a notification via REST:

```bash
curl -X POST "https://notify.${DOMAIN}/message?token=<APP_TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{"message": "Backup completed!", "priority": 5, "title": "Homelab"}'
```

3. Android app available at: https://github.com/gotify/android

### Apprise — Multi-Platform Notifications

Configure notification targets in `https://apprise.${DOMAIN}`, then notify via:

```bash
# Send to all configured channels
curl -X POST "https://apprise.${DOMAIN}/notify/homelab" \
  -d '{"body": "Deployment done!", "title": "CI/CD"}'
```

Supported services include Telegram, Discord, Slack, Email, Pushover, ntfy, Matrix, and 80+ more.

## Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `DOMAIN` | Your base domain | Yes |
| `GOTIFY_ADMIN_USER` | Gotify admin username | No (default: `admin`) |
| `GOTIFY_ADMIN_PASSWORD` | Gotify admin password | Yes |
| `TZ` | Timezone | Yes |
