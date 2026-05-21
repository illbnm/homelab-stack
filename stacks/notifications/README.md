# Notifications Stack

Unified notification hub for HomeLab Stack. Supports push (ntfy), self-hosted push (Gotify), and multi-channel relay (Apprise).

## What's Included

| Service | Version | URL | Purpose |
|---------|---------|-----|---------|
| ntfy | v2.11.0 | `ntfy.<DOMAIN>` | Push notification server (subscribe via browser/mobile) |
| Gotify | v2.6.1 | `gotify.<DOMAIN>` | Self-hosted push notification server with web UI |
| Apprise | v1.1.6 | `apprise.<DOMAIN>` | Multi-channel notification relay (email, Telegram, Discord, etc.) |

## Architecture

```
Homelab Services
    │
    ├──► ntfy.<DOMAIN>   ── browser/mobile push (watchtower, alertmanager)
    ├──► gotify.<DOMAIN> ── Android/web push (via Gotify app)
    └──► apprise.<DOMAIN>── multi-channel relay (email, Slack, Telegram, Discord...)

            ▲
            │ notifications trigger
    ┌───────┴────────┐
    │ Watchtower     │ container update alerts
    │ Alertmanager   │ Prometheus alerts
    │ Gitea          │ repo push/PR events
    │ Home Assistant │ automation alerts
    └────────────────┘
```

## Quick Start

```bash
# From repo root
cp .env.example .env
# Edit .env — set DOMAIN and GOTIFY_PASSWORD

# Start base stack first (required for Traefik + proxy network)
cd stacks/base && docker compose up -d

# Start notifications
cd ../notifications
ln -sf ../../.env .env
docker compose up -d
```

## Configuration

### Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `DOMAIN` | Yes | — | Base domain for all services |
| `TZ` | No | `Asia/Shanghai` | Timezone |
| `GOTIFY_PASSWORD` | Yes | — | Admin password for Gotify |
| `GOTIFY_REGISTRATION` | No | `false` | Allow user self-registration |
| `NTFY_AUTH_DEFAULT_ACCESS` | No | `deny-all` | Default access policy |

### ntfy Setup

1. Visit `https://ntfy.<DOMAIN>`
2. Create a user: `docker exec ntfy ntfy user add --role=admin admin`
3. Grant access: `docker exec ntfy ntfy access '*' admin read-write`
4. Subscribe to topics via browser or mobile app (Android/iOS)

### Gotify Setup

1. Visit `https://gotify.<DOMAIN>`
2. Login with admin / `<GOTIFY_PASSWORD>`
3. Create applications to get API tokens
4. Send test: `curl -X POST "https://gotify.<DOMAIN>/message" -d "title=Test&message=Hello&priority=5" -H "X-Gotify-Key: <token>"`

### Apprise Setup

1. Visit `https://apprise.<DOMAIN>`
2. Add notification URLs (e.g., `mailto://user:pass@smtp.gmail.com`, `tgram://bottoken/ChatID`)
3. Use the API to send: `curl -X POST "https://apprise.<DOMAIN>/notify" -d "title=Alert&body=Something happened"`

## Integration with Other Stacks

### Watchtower (Auto-update notifications)

Add to `.env`:
```env
WATCHTOWER_NOTIFICATIONS=shoutrrr
WATCHTOWER_NOTIFICATION_URL=ntfy://ntfy.${DOMAIN}/watchtower?user=admin&pass=xxx
```

### Alertmanager (Prometheus alerts)

In Alertmanager config (`stacks/monitoring/alertmanager.yml`):
```yaml
receivers:
  - name: 'ntfy'
    webhook_configs:
      - url: 'http://ntfy:80/'
        send_resolved: true
```

### Gitea (Repository events)

In Gitea webhook settings, set URL to:
```
https://ntfy.<DOMAIN>/gitea?auth=user:pass
```

### Home Assistant

In HA `configuration.yaml`:
```yaml
notify:
  - name: ntfy
    platform: rest
    resource: https://ntfy.{{ domain }}/homeassistant
    method: POST
```

## SSO Integration (Authentik)

Both ntfy and Gotify are configured with Traefik ForwardAuth middleware for SSO via Authentik. To enable:

1. Deploy the SSO stack (`stacks/sso/`)
2. Create OIDC providers in Authentik for ntfy and gotify
3. The `authentik-forwardauth@docker` middleware is automatically applied via labels

## CN Network Adaptation

If `CN_MODE=true` in `.env`, use the CN mirror script:

```bash
# Pull images through CN-friendly mirrors
./scripts/setup-cn-mirrors.sh
```

Images available on Docker Hub (no ghcr.io dependency) — compatible with CN mirrors.

## Health Check Verification

```bash
# Check all services
docker exec ntfy curl -sf http://localhost:80/v1/health
docker exec gotify curl -sf http://localhost:80/health
docker exec apprise curl -sf http://localhost:8000/

# One-liner
docker compose ps --format "table {{.Name}}\t{{.Status}}"
```

## Troubleshooting

| Problem | Solution |
|---------|----------|
| ntfy returns 401 | Create admin user and grant access (see setup above) |
| Gotify login fails | Check `GOTIFY_PASSWORD` in `.env` |
| Traefik 404 | Ensure base stack is running and `proxy` network exists |
| Can't send notifications | Check container logs: `docker compose logs ntfy` |
| CN image pull timeout | Set `CN_MODE=true` and run `setup-cn-mirrors.sh` |
