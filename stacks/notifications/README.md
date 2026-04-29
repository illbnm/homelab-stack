# Notifications Stack

Unified notification center for your homelab. All services (Watchtower, Alertmanager, Gitea, etc.) push notifications through ntfy or Gotify.

## Services

| Service | Image | Port | Purpose |
|---------|-------|------|---------|
| ntfy | `binwiederhier/ntfy:v2.11.0` | 80 | Primary push notification server |
| Gotify | `gotify/server:2.5.0` | 80 | Backup push notification server |
| Alertmanager | `prom/alertmanager:v0.27.0` | 9093 | Alert routing to ntfy |

## Quick Start

```bash
cp .env.example .env
# Edit .env — set DOMAIN, GOTIFY_ADMIN_PASS
docker compose up -d
```

### Post-deploy: Create ntfy admin user

```bash
docker exec ntfy ntfy user add --role=admin admin
# Set a password when prompted
```

### Test notification

```bash
./scripts/notify.sh homelab-test "Test" "Hello from homelab!"
```

## Service Integrations

### Alertmanager → ntfy

Alertmanager is pre-configured in `config/alertmanager/alertmanager.yml` with three routes:

| Route | ntfy Topic | Priority |
|-------|-----------|----------|
| Default | `homelab-alerts` | default |
| Critical alerts | `homelab-alerts` | high |
| Warning alerts | `homelab-alerts` | default |

Subscribe to `homelab-alerts` in the ntfy web UI or app to receive alerts.

### Watchtower → ntfy

Add to your Watchtower environment:

```yaml
environment:
  - WATCHTOWER_NOTIFICATION_URL=ntfy://ntfy.${DOMAIN}/watchtower?priority=default
```

Or using the unified script:

```bash
# In a custom Watchtower post-update hook
./scripts/notify.sh watchtower "Container Updated" "$WATCHTOWER_UPDATED_CONTAINERS"
```

### Gitea → ntfy

In Gitea, go to **Site Administration → Webhooks → Add webhook**:

- **Type:** ntfy or Gitea-compatible webhook
- **URL:** `https://ntfy.${DOMAIN}/gitea`
- **HTTP method:** POST
- **Content type:** application/json

Or use the unified script in a Gitea hook:

```bash
./scripts/notify.sh gitea "New Push" "${GITEA_REPOSITORY}: ${GITEA_COMMIT_SHA}"
```

### Home Assistant → ntfy

Add to `configuration.yaml`:

```yaml
notify:
  - name: ntfy
    platform: rest
    resource: https://ntfy.{{ domain }}/homeassistant
    method: POST
    title_param: Title
    message_param: message
```

Then use in automations:

```yaml
automation:
  - alias: "Notify on door open"
    trigger:
      - platform: state
        entity_id: binary_sensor.front_door
        to: "on"
    action:
      - service: notify.ntfy
        data:
          title: "Front Door"
          message: "Door opened"
          data:
            priority: high
```

### Uptime Kuma → ntfy

In Uptime Kuma, go to **Settings → Notifications → Add**:

- **Type:** ntfy
- **Server URL:** `https://ntfy.${DOMAIN}`
- **Topic:** `uptime-kuma`
- **Priority:** default

## Unified Notification Script

`scripts/notify.sh` is the single interface all other scripts should use:

```bash
# Syntax
./scripts/notify.sh <topic> <title> <message> [priority]

# Examples
./scripts/notify.sh homelab-alerts "Disk Warning" "/dev/sda1 is 85% full" high
./scripts/notify.sh updates "Watchtower" "Container nginx updated to 1.25"
./scripts/notify.sh gitea "PR Merged" "#42 merged into main" default

# Use Gotify backend instead
NOTIFY_BACKEND=gotify GOTIFY_TOKEN=xxx ./scripts/notify.sh alerts "Alert" "Something happened"
```

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `NTFY_URL` | `https://ntfy.example.com` | ntfy server URL |
| `GOTIFY_URL` | `https://gotify.example.com` | Gotify server URL |
| `GOTIFY_TOKEN` | (empty) | Gotify app token (required for Gotify) |
| `NOTIFY_BACKEND` | `ntfy` | `ntfy` or `gotify` |

## Mobile Setup

Install the **ntfy** app ([Android](https://play.google.com/store/apps/details?id=io.heckel.ntfy) / [iOS](https://apps.apple.com/app/ntfy/id1625396347)) and subscribe to topics:

1. Open the ntfy app
2. Tap **+** → enter `https://ntfy.${DOMAIN}`
3. Subscribe to topics: `homelab-alerts`, `watchtower`, `gitea`, `uptime-kuma`
4. Test: run `./scripts/notify.sh homelab-alerts "Test" "Mobile push works!" high`

## Configuration Reference

### ntfy (`config/ntfy/server.yml`)

| Setting | Value | Purpose |
|---------|-------|---------|
| `auth-default-access` | `deny-all` | Require auth for all topics |
| `behind-proxy` | `true` | Trust X-Forwarded-For from Traefik |
| `enable-signup` | `false` | No public user registration |
| `enable-login` | `true` | Allow existing users to log in |
| `enable-reservations` | `true` | Allow topic ownership |

### Alertmanager (`config/alertmanager/alertmanager.yml`)

- Routes alerts to ntfy via webhook
- Critical alerts: high priority, repeat every 1h
- Warning alerts: default priority, repeat every 4h
- Resolved alerts are also sent

Generated/reviewed with: claude-opus-4-6