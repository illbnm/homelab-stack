# Notifications Stack — ntfy + Gotify + Apprise

**Bounty**: [#13](https://github.com/illbnm/homelab-stack/issues/13) · **$80 USDT**

Unified notification center for all homelab services. Three layers:

| Service | Purpose | URL |
|---------|---------|-----|
| ntfy | Primary push notifications | https://ntfy.${DOMAIN} |
| Gotify | Fallback / backup notifications | https://gotify.${DOMAIN} |
| Apprise | Unified notification aggregator | https://apprise.${DOMAIN} |

## Quick Start

```bash
cd stacks/notifications
cp ../.env.example .env  # Set DOMAIN=your-domain.com
docker compose up -d
```

## Service Configuration

### ntfy

Access ntfy at `https://ntfy.${DOMAIN}`. Topics are created on-demand.
Subscribe to topics directly in the web UI or via the ntfy mobile app.

#### Alertmanager Integration

Add to `config/alertmanager/alertmanager.yml`:

```yaml
receivers:
  - name: ntfy
    webhook_configs:
      - url: http://ntfy:80/alertmanager
        send_resolved: true
```

#### Watchtower Integration

```yaml
# In your docker-compose.override.yml
services:
  watchtower:
    environment:
      - WATCHTOWER_NOTIFICATIONS_URL=ntfy://
      - WATCHTOWER_NOTIFICATION_TITLE=Watchtower Update
```

#### Generic cURL

```bash
curl -d "Container update available" \
     -H "Tags: warning" \
     https://ntfy.${DOMAIN}/watchtower
```

### Gotify

Access Gotify at `https://gotify.${DOMAIN}`.
Create an application token in the Gotify web UI, then use:

```bash
curl -X POST "https://gotify.${DOMAIN}/message" \
  -H "Token: YOUR_APP_TOKEN" \
  -d "message=Alert&priority=5"
```

#### Grafana Alerting Integration

Add Gotify as a contact point in Grafana:
- URL: `https://gotify.${DOMAIN}`
- Token: Your Gotify app token

### Apprise

Access Apprise at `https://apprise.${DOMAIN}`.
Configure notification targets in `apprise.yml`:

```bash
# Send notification via Apprise API
curl -X POST http://apprise:8000/v1/notify \
  -H "Content-Type: application/json" \
  -d '{"urls":["ntfy://channel"],"body":"Service alert"}'
```

## Network

All services connect to the `proxy` Docker network (external).
Traefik handles SSL termination and routing.

## Volumes

| Volume | Purpose |
|--------|---------|
| `ntfy-data` | User database, topic state |
| `ntfy-cache` | Attachment cache |
| `apprise-config` | Apprise notification config |
| `gotify-data` | Gotify persistent data |

## Health Checks

All services expose health endpoints:
- ntfy: `GET /v1/health` → `{"ok":true}`
- Gotify: `GET /ping` → `pong`
- Apprise: `GET /` → HTTP 200

## Wallet

USDT payment wallet: `edisonlv` (on RustChain — same as previous payments)
