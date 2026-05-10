# 📢 Notifications Stack — Bounty #13

This stack provides centralized notification services for the HomeLab, supporting multiple notification channels through ntfy and Gotify, with Alertmanager integration.

## Architecture

```
┌─────────────┐     ┌──────────┐     ┌─────────────────┐
│  Prometheus  │────▶│Alert mgr│────▶│     ntfy        │
│  Alert Rules │     │          │     │ (Web UI + Push) │
└─────────────┘     └──────────┘     └────────┬────────┘
                                              │
              ┌───────────────────────────────┤
              │                               │
              ▼                               ▼
      ┌───────────────┐             ┌──────────────────┐
      │   Gotify      │             │  Mobile/Desktop  │
      │ (App Push)    │             │  ntfy App / Web  │
      └───────────────┘             └──────────────────┘
```

## Services

| Service | URL | Description |
|---------|-----|-------------|
| **ntfy** | https://ntfy.${DOMAIN} | Lightweight push notification service with web UI |
| **Gotify** | https://gotify.${DOMAIN} | Self-hosted push notification server with mobile apps |
| **Apprise** | https://apprise.${DOMAIN} | Multi-platform notification gateway (Slack, Telegram, Email, etc.) |

## Quick Start

```bash
# 1. Ensure the proxy network exists
docker network create proxy

# 2. Configure environment
cp .env.example .env
# Edit .env — set DOMAIN, GOTIFY_ADMIN_PASSWORD

# 3. Start the notifications stack
docker compose up -d

# 4. Verify health
docker compose ps
curl -s https://ntfy.${DOMAIN}/v1/health
curl -s https://gotify.${DOMAIN}/health
```

## Configuration

### ntfy

Configuration file: `config/ntfy/server.yml`

ntfy is configured as a self-hosted push notification server. It:
- Serves a web UI at https://ntfy.${DOMAIN} for subscribing to topics
- Accepts JSON/HTTP POST for publishing messages
- Supports attachments, priority levels, and scheduled delivery
- Runs behind Traefik with TLS termination

**Sending a notification to ntfy:**

```bash
curl -d "Backup completed" ntfy.${DOMAIN}/homelab-alerts
```

**With title and priority:**

```bash
curl -H "Title: Backup Status" -H "Priority: high" -d "Backup completed successfully" ntfy.${DOMAIN}/homelab-alerts
```

### Gotify

Gotify provides push notifications to mobile devices via its Android/iOS apps.
- Admin UI: https://gotify.${DOMAIN}
- Default admin password: set via `GOTIFY_ADMIN_PASSWORD` environment variable

**Sending a notification to Gotify via API:**

```bash
curl -X POST "https://gotify.${DOMAIN}/message?token=YOUR_APP_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"title": "Alert", "message": "Something happened", "priority": 5}'
```

### Apprise

Apprise acts as a notification router that can forward to 100+ notification services:
- Slack, Discord, Telegram, Pushover, email, SMS, and more
- Configure via Apprise web UI at https://apprise.${DOMAIN}
- See [Apprise Wiki](https://github.com/caronc/apprise/wiki) for all supported services

## Unified notify.sh Script

The `scripts/notify.sh` script provides a unified CLI for sending notifications to both ntfy and Gotify:

```bash
# Send to both ntfy and Gotify (default)
./scripts/notify.sh "Backup completed successfully"

# Send with custom title and priority
./scripts/notify.sh -t "CRITICAL" -p high -s ntfy "Disk usage above 90%"

# Send to ntfy only
./scripts/notify.sh -s ntfy "Service restarted"

# Custom topic
./scripts/notify.sh -T my-custom-topic "Custom channel message"

# Quiet mode (no output)
./scripts/notify.sh -q "Silent notification"
```

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `NOTIFY_NTFY_URL` | https://ntfy.${DOMAIN} | ntfy server URL |
| `NOTIFY_NTFY_TOPIC` | homelab-alerts | Default ntfy topic |
| `NOTIFY_GOTIFY_URL` | https://gotify.${DOMAIN} | Gotify server URL |
| `NOTIFY_GOTIFY_TOKEN` | — | Gotify application token |
| `NOTIFY_DEFAULT_TITLE` | HomeLab Alert | Default notification title |

## Alertmanager Integration

Alertmanager is configured to send alerts to ntfy via webhook:

```yaml
receivers:
  - name: default
    webhook_configs:
      - url: http://ntfy:80
        send_resolved: true
```

This means all Prometheus alerts (and alert resolutions) are automatically pushed to the ntfy default topic. Subscribe to it from your phone to get real-time HomeLab alerts.

## Usage Examples (From Other Stacks)

```bash
# Backup completion
./scripts/notify.sh -t "Backup" "Database backup completed — 2.3GB written to MinIO"

# Health check
./scripts/notify.sh -p high -T health-alerts "Service nginx is DOWN"

# Disk warning from cron
./scripts/notify.sh -p max "CRITICAL: Disk /dev/sda1 at 95% capacity"

# CI/CD pipeline
./scripts/notify.sh -t "Deploy" "v2.1.3 deployed to production successfully"
```

## Troubleshooting

| Problem | Check |
|---------|-------|
| ntfy not starting | Check `config/ntfy/server.yml` syntax. Ensure `proxy` network exists. |
| Gotify not starting | Verify `GOTIFY_ADMIN_PASSWORD` is set. Port 80 may conflict. |
| Can't reach services via HTTPS | Confirm DNS resolves for `ntfy.${DOMAIN}` and `gotify.${DOMAIN}` |
| Alertmanager not sending | Check Alertmanager webhook URL points to `http://ntfy:80` (internal Docker network) |
| notifications script fails | Ensure `curl` is installed. Check `.env` has correct URLs.