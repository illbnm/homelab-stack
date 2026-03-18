# Notifications Stack

Unified notification center for all HomeLab services.

## What's Included

| Service | Version | URL | Purpose |
|---------|---------|-----|---------|
| ntfy | v2.11.0 | `ntfy.<DOMAIN>` | Push notifications (mobile + desktop) |
| Apprise | v1.1.6 | `apprise.<DOMAIN>` | Multi-channel notification routing |

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Notification Sources                          │
├──────────────┬──────────────┬──────────────┬───────────────────┤
│ Alertmanager │  Watchtower  │    Gitea     │  Home Assistant   │
│  (webhook)   │  (shoutrrr)  │  (webhook)   │  (REST notify)   │
└──────┬───────┴──────┬───────┴──────┬───────┴──────┬────────────┘
       │              │              │              │
       ▼              ▼              ▼              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      ntfy Server                                │
│  Topics: homelab-alerts, homelab-backup, homelab-updates, ...   │
│  Auth: per-topic access control                                 │
│  Cache: 12h offline message delivery                            │
└───────────────────────────┬─────────────────────────────────────┘
                            │
              ┌─────────────┼─────────────┐
              ▼             ▼             ▼
        ┌──────────┐ ┌──────────┐ ┌──────────────┐
        │ Mobile   │ │ Desktop  │ │ Apprise      │
        │ ntfy App │ │ Browser  │ │ (50+ targets)│
        └──────────┘ └──────────┘ └──────────────┘
                                        │
                              ┌─────────┼─────────┐
                              ▼         ▼         ▼
                          Telegram   Slack    Email ...
```

## Quick Start

```bash
# 1. Deploy
cp stacks/notifications/.env.example stacks/notifications/.env
docker compose -f stacks/notifications/docker-compose.yml up -d

# 2. Create admin user (ntfy)
docker exec ntfy ntfy user add --role=admin admin

# 3. Test notification
./scripts/notify.sh homelab-test "Test" "Hello World"

# 4. Install ntfy mobile app
# iOS: https://apps.apple.com/app/ntfy/id1625396347
# Android: https://play.google.com/store/apps/details?id=io.heckel.ntfy
# Subscribe to: https://ntfy.<DOMAIN>/homelab-alerts
```

## scripts/notify.sh — Unified Notification Interface

```bash
notify.sh <topic> <title> <message> [priority]
```

All HomeLab scripts use this unified interface instead of calling ntfy directly.

### Arguments

| Argument | Required | Description |
|----------|----------|-------------|
| `topic` | ✅ | ntfy topic name |
| `title` | ✅ | Notification title |
| `message` | ✅ | Notification body |
| `priority` | — | `min`, `low`, `default`, `high`, `urgent` |

### Environment

| Variable | Description |
|----------|-------------|
| `NTFY_URL` | ntfy server URL |
| `NTFY_TOKEN` | Auth token for protected topics |

### Examples

```bash
# Basic notification
./scripts/notify.sh homelab-test "Test" "Hello from HomeLab"

# High priority alert
./scripts/notify.sh homelab-alerts "Disk Full" "Root partition 95% used" high

# Backup notification
./scripts/notify.sh homelab-backup "Backup Complete" "All stacks backed up" default

# Low priority update
./scripts/notify.sh homelab-updates "Container Update" "3 containers updated" low
```

## ntfy Configuration

Server config at `config/ntfy/server.yml`:

| Setting | Value | Purpose |
|---------|-------|---------|
| `base-url` | `https://ntfy.<DOMAIN>` | Public URL |
| `behind-proxy` | `true` | Trust Traefik headers |
| `auth-default-access` | `deny-all` | Require auth by default |
| `cache-duration` | `12h` | Offline message retention |
| `attachment-file-size-limit` | `15M` | Max attachment size |
| `attachment-total-size-limit` | `1G` | Total attachment storage |

### User Management

```bash
# Add admin user
docker exec ntfy ntfy user add --role=admin admin

# Add regular user
docker exec ntfy ntfy user add viewer

# Grant topic access
docker exec ntfy ntfy access viewer 'homelab-*' read-only
docker exec ntfy ntfy access admin '*' read-write

# Generate auth token
docker exec ntfy ntfy token add --user=admin

# List users
docker exec ntfy ntfy user list
```

### Topic Organization

| Topic | Purpose | Consumer |
|-------|---------|----------|
| `homelab-alerts` | Alertmanager critical/warning alerts | Admin |
| `homelab-backup` | Backup completion/failure notifications | Admin |
| `homelab-updates` | Watchtower container update notifications | Admin |
| `homelab-gitea` | Gitea events (push, PR, issues) | Dev team |
| `homelab-hass` | Home Assistant automations | Home users |

## Service Integration Guide

### 1. Alertmanager → ntfy (Webhook)

Config: `config/alertmanager/alertmanager.yml`

```yaml
receivers:
  - name: ntfy-critical
    webhook_configs:
      - url: "http://ntfy:80/homelab-alerts"
        send_resolved: true

  - name: ntfy-default
    webhook_configs:
      - url: "http://ntfy:80/homelab-alerts"
        send_resolved: true

route:
  receiver: ntfy-default
  routes:
    - match:
        severity: critical
      receiver: ntfy-critical
```

**How it works:**
- Alertmanager sends alerts as webhook POST to ntfy
- ntfy publishes to `homelab-alerts` topic
- Mobile app / browser receives push notification
- `send_resolved: true` sends recovery notifications too

**Test:**
```bash
# Trigger a test alert
curl -X POST http://alertmanager:9093/api/v1/alerts -H 'Content-Type: application/json' -d '[{
  "labels": {"alertname": "TestAlert", "severity": "warning"},
  "annotations": {"summary": "Test alert from CLI"},
  "startsAt": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"
}]'
```

### 2. Watchtower → ntfy (Shoutrrr)

In `.env` or `stacks/base/docker-compose.yml`:

```bash
WATCHTOWER_NOTIFICATION_URL=shoutrrr://ntfy.${DOMAIN}/homelab-updates
```

Or with auth:
```bash
WATCHTOWER_NOTIFICATION_URL=shoutrrr://ntfy.${DOMAIN}/homelab-updates?auth=Bearer+tk_your_token
```

**What you'll receive:**
- Container name that was updated
- Old → new image digest
- Update timestamp

### 3. Gitea → ntfy (Webhook)

1. Go to **Gitea** → **Site Administration** → **Webhooks** (or per-repository)
2. Add webhook:

| Field | Value |
|-------|-------|
| Target URL | `https://ntfy.<DOMAIN>/homelab-gitea` |
| HTTP Method | POST |
| Content Type | application/json |
| Secret | (leave empty or use ntfy token) |
| Trigger | Push, Pull Request, Issues |

**Headers** (if ntfy auth is enabled):
```
Authorization: Bearer tk_your_token
```

**Alternative via Apprise:**
```bash
# In Gitea webhook URL, use Apprise endpoint
# POST https://apprise.<DOMAIN>/notify/
# Body: { "urls": "ntfys://ntfy.<DOMAIN>/homelab-gitea", "title": "...", "body": "..." }
```

### 4. Home Assistant → ntfy (REST Notify)

Add to Home Assistant `configuration.yaml`:

```yaml
# Method 1: REST notify platform
notify:
  - name: ntfy_homelab
    platform: rest
    resource: https://ntfy.<DOMAIN>/homelab-hass
    method: POST_JSON
    headers:
      Authorization: "Bearer tk_your_token"
    data:
      topic: homelab-hass
    title_param_name: title
    message_param_name: message

# Method 2: Using ntfy integration (HACS)
# Install via HACS → Integrations → ntfy
# Configure:
#   URL: https://ntfy.<DOMAIN>
#   Topic: homelab-hass
#   Token: tk_your_token
```

**Automation example:**
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
          title: "🚪 Door Opened"
          message: "Front door was opened at {{ now().strftime('%H:%M') }}"
```

### 5. Uptime Kuma → ntfy

1. Go to **Uptime Kuma** → **Settings** → **Notifications**
2. Click **Setup Notification**:

| Field | Value |
|-------|-------|
| Notification Type | ntfy |
| Server URL | `https://ntfy.<DOMAIN>` |
| Topic | `homelab-alerts` |
| Priority | `high` (for downtime alerts) |
| Token | `tk_your_token` (if auth enabled) |

3. Click **Test** to verify
4. Apply to monitors

### 6. Backup Script → ntfy

The `scripts/backup.sh` automatically uses `scripts/notify.sh`:

```bash
# Set in .env
NTFY_URL=https://ntfy.<DOMAIN>
NTFY_BACKUP_TOPIC=homelab-backup
```

Events:
- ✅ Backup complete
- ⚠️ Partial backup (with warnings)
- ❌ Backup failed
- 🔄 Restore complete

## Apprise — Multi-Channel Routing

Apprise supports 50+ notification services. Use the web UI at `https://apprise.<DOMAIN>`.

### API Usage

```bash
# Send via CLI
curl -X POST https://apprise.<DOMAIN>/notify/ \
  -H "Content-Type: application/json" \
  -d '{
    "urls": ["ntfys://ntfy.<DOMAIN>/homelab-alerts", "tgram://BOT_TOKEN/CHAT_ID"],
    "title": "Alert",
    "body": "Something happened"
  }'

# Pre-configure notification targets
curl -X POST https://apprise.<DOMAIN>/add/homelab/ \
  -H "Content-Type: application/json" \
  -d '{
    "urls": ["ntfys://ntfy.<DOMAIN>/homelab-alerts", "slack://webhook-url"]
  }'

# Send to pre-configured group
curl -X POST https://apprise.<DOMAIN>/notify/homelab/ \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Alert",
    "body": "Something happened"
  }'
```

### Common Apprise URLs

| Service | URL Format |
|---------|-----------|
| ntfy | `ntfys://ntfy.<DOMAIN>/topic` |
| Telegram | `tgram://BOT_TOKEN/CHAT_ID` |
| Slack | `slack://TokenA/TokenB/TokenC/#channel` |
| Discord | `discord://WebhookID/WebhookToken` |
| Email | `mailto://user:pass@smtp.gmail.com?to=you@example.com` |
| Gotify | `gotifys://gotify.<DOMAIN>/YOUR_TOKEN` |
| Matrix | `matrix://user:pass@matrix.org/#room` |
| Pushover | `pover://user_key@app_token` |

## Troubleshooting

### ntfy Web UI not accessible
```bash
# Check container health
docker compose -f stacks/notifications/docker-compose.yml ps

# Check logs
docker logs ntfy

# Test internal health
docker exec ntfy curl -sf http://localhost:80/v1/health
```

### Can't receive notifications on mobile
1. Verify topic subscription: Open ntfy app → check topic name matches
2. Check auth: `docker exec ntfy ntfy access <user> <topic>`
3. Check cache: Messages sent while offline are cached for 12h
4. Check priority: `min` priority may be filtered by phone settings

### Alertmanager not sending to ntfy
```bash
# Check alertmanager can reach ntfy (they share Docker network)
docker exec alertmanager wget -qO- http://ntfy:80/v1/health

# Check alertmanager config reload
docker exec alertmanager amtool config show

# Check alert status
docker exec alertmanager amtool alert query
```

### notify.sh returns "NTFY_URL not set"
```bash
# Set in .env
echo 'NTFY_URL=https://ntfy.<DOMAIN>' >> .env

# Or export for current session
export NTFY_URL=https://ntfy.<DOMAIN>
```
