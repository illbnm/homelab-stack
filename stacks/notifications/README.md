# Notifications Stack

Unified push notification center for the HomeLab Stack. All services route notifications through **ntfy** (primary) and **Gotify** (backup).

## Services

| Service | Image | Purpose | URL |
|---------|-------|---------|-----|
| ntfy | `binwiederhier/ntfy:v2.11.0` | Push notification server | `https://ntfy.${DOMAIN}` |
| Gotify | `gotify/server:2.5.0` | Backup push service | `https://gotify.${DOMAIN}` |

## Quick Start

```bash
# Start notifications stack
./scripts/stack-manager.sh start notifications

# Test notification
./scripts/notify.sh homelab-test "Test" "Hello World"
```

## Service Integration Guide

### Alertmanager

Alertmanager routes Prometheus alerts to ntfy via webhook. Configured in `config/alertmanager/alertmanager.yml`:

```yaml
receivers:
  - name: ntfy
    webhook_configs:
      - url: "http://ntfy:80/homelab-alerts"
        send_resolved: true
  - name: ntfy-critical
    webhook_configs:
      - url: "http://ntfy:80/homelab-critical"
        send_resolved: true
```

**Setup:** No extra steps — this is configured by default. Critical alerts go to the `homelab-critical` topic; all others to `homelab-alerts`.

### Watchtower

Container update notifications via ntfy. Configured in `stacks/base/docker-compose.yml`:

```yaml
environment:
  - WATCHTOWER_NOTIFICATION_URL=ntfy://ntfy:80/homelab-watchtower
```

**Setup:** Subscribe to the `homelab-watchtower` topic in your ntfy app.

### Gitea

Configure webhook in Gitea Admin → Webhooks:

1. Go to `https://gitea.${DOMAIN}` → Site Administration → Webhooks → Add Webhook
2. Set **Target URL**: `https://ntfy.${DOMAIN}/homelab-gitea`
3. Set **Content Type**: `application/json`
4. Set **Trigger On**: Choose events (push, issues, PR, etc.)
5. Set **HTTP Method**: POST

For per-repo webhooks: Go to repo → Settings → Webhooks → Add Webhook → Custom (ntfy)

### Home Assistant

Add ntfy integration in `configuration.yaml`:

```yaml
notify:
  - platform: rest
    name: homelab_ntfy
    resource: https://ntfy.${DOMAIN}/homelab-ha
    method: POST
    headers:
      Title: "Home Assistant"
    message_param_name: message
```

Use in automations:

```yaml
automation:
  - alias: "Door opened alert"
    trigger:
      platform: state
      entity_id: binary_sensor.front_door
      to: "on"
    action:
      service: notify.homelab_ntfy
      data:
        message: "Front door was opened"
```

### Uptime Kuma

Add ntfy as a notification provider:

1. Go to Settings → Notifications → Setup Notification
2. Type: **ntfy**
3. Server URL: `https://ntfy.${DOMAIN}`
4. Topic: `homelab-uptime`
5. Priority: 4 (default)

### Custom Scripts / Cron Jobs

Use the unified `notify.sh` script:

```bash
# From any script or cron job
./scripts/notify.sh homelab-backups "Backup Complete" "Weekly backup finished at $(date)"

# With priority levels: min, low, default, high, urgent
./scripts/notify.sh homelab-alerts "Disk Full" "Root partition at 95%" urgent
```

## Topics

Subscribe to these topics in your ntfy app for targeted notifications:

| Topic | Description |
|-------|-------------|
| `homelab-alerts` | Prometheus/Alertmanager alerts |
| `homelab-critical` | Critical alerts (severity=critical) |
| `homelab-watchtower` | Container update notifications |
| `homelab-gitea` | Gitea webhook events |
| `homelab-ha` | Home Assistant notifications |
| `homelab-uptime` | Uptime Kuma status changes |
| `homelab-backups` | Backup script results |
| `homelab-test` | Testing topic |

## ntfy App Setup

1. Install the ntfy app on your phone: [Android](https://play.google.com/store/apps/details?id=io.heckel.ntfy) / [iOS](https://apps.apple.com/us/app/ntfy/id1625390481)
2. Add server: `https://ntfy.${DOMAIN}`
3. Subscribe to topics listed above
4. Configure notification sounds, priorities, and muting per topic

## Auth Configuration

By default, ntfy denies all anonymous access. To set up authentication:

```bash
# Create admin user
docker exec ntfy ntfy user add --role=admin admin

# Create a user with publish access
docker exec ntfy ntfy user add publisher
docker exec ntfy ntfy access publisher homelab-alerts write
```

## Verification Checklist

```bash
# 1. Check services are running
./scripts/stack-manager.sh status notifications

# 2. Test ntfy directly
curl -d "Hello from CLI" https://ntfy.${DOMAIN}/homelab-test

# 3. Test via notify.sh
./scripts/notify.sh homelab-test "Test" "Hello World"

# 4. Test Alertmanager integration
curl -X POST http://alertmanager:9093/api/v1/alerts \
  -H "Content-Type: application/json" \
  -d '[{"labels":{"alertname":"TestAlert","severity":"warning"}}]'

# 5. Verify Watchtower notifications are configured
docker inspect watchtower | grep -i ntfy
```
