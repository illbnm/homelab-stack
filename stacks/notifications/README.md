# Notifications Stack

Push notification services for your homelab with unified integrations.

## Services

| Service | URL | Description |
|---------|-----|-------------|
| ntfy | `https://ntfy.${DOMAIN}` | Lightweight HTTP-based push notification service |
| Gotify | `https://gotify.${DOMAIN}` | Self-hosted notification server with web UI |
| Apprise | `https://apprise.${DOMAIN}` | Multi-service notification aggregator |

## Quick Start

```bash
# Deploy the stack
cd stacks/notifications
docker compose up -d

# Test notifications
./scripts/notify.sh test "Hello" "This is a test notification" high
```

## Configuration

### Environment Variables (.env)

```bash
# Required
DOMAIN=yourdomain.com

# Gotify (optional, for fallback)
GOTIFY_TOKEN=your_gotify_app_token

# ntfy Authentication (optional)
NTFY_USER=your_username
NTFY_PASS=your_password
```

### ntfy Configuration

Server config: `config/ntfy/server.yml`

```yaml
base-url: "https://ntfy.${DOMAIN}"
auth-default-access: "deny-all"
behind-proxy: true
cache-duration: "12h"
```

### Gotify Setup

1. Login at `https://gotify.${DOMAIN}`
   - Default: `admin` / password from `.env` (GOTIFY_PASSWORD)
2. Create a new application in the web UI
3. Copy the application token for use in integrations

## Service Integrations

### Alertmanager (Prometheus)

Add webhook receiver to `config/alertmanager/alertmanager.yml`:

```yaml
receivers:
  - name: ntfy
    webhook_configs:
      - url: http://ntfy/alertmanager
        send_resolved: true
```

**Example route:**

```yaml
route:
  receiver: ntfy
  group_wait: 30s
  repeat_interval: 12h
  routes:
    - match:
        severity: critical
      receiver: ntfy
```

### Watchtower (Auto-updates)

Configure in `.env`:

```bash
# ntfy integration
WATCHTOWER_NOTIFICATIONS_LEVEL=warn
WATCHTOWER_NOTIFICATION_URL=ntfy://ntfy.${DOMAIN}/watchtower?priority=high

# Gotify integration (alternative)
WATCHTOWER_NOTIFICATION_URL=gotify://${GOTIFY_TOKEN}@gotify.${DOMAIN}
```

### Gitea (Webhook)

**Via Web UI:**
1. Go to **Repository Settings** → **Webhooks** → **Add Webhook**
2. Set URL: `https://ntfy.${DOMAIN}/gitea`
3. Content type: `application/json`
4. Events: Select desired events (push, issues, PRs, etc.)
5. Add webhook

**Custom payload template:**
```json
{
  "title": "{{ .Repository.FullName }}",
  "message": "{{ .RefType }} {{ .Ref }} by {{ .Pusher.Name }} - {{ .Commits | len }} commit(s)",
  "priority": "default"
}
```

### Home Assistant

**Via Configuration YAML:**

```yaml
# configuration.yaml
notify:
  - name: ntfy
    platform: rest
    resource: https://ntfy.${DOMAIN}/homeassistant
    method: POST_JSON
    message_param_name: message
    title_param_name: title
    headers:
      Authorization: "Bearer YOUR_NTFY_TOKEN"
```

**Automation example:**

```yaml
automation:
  - alias: "Send Notification on Alert"
    trigger:
      - platform: state
        entity_id: binary_sensor.front_door
        to: "on"
    action:
      - service: notify.ntfy
        data:
          title: "Front Door Opened"
          message: "The front door was opened at {{ now().strftime('%H:%M') }}"
          data:
            priority: high
```

### Uptime Kuma

**Via Web UI:**
1. Go to **Settings** → **Notification**
2. Add notification: **ntfy**
3. Configure:
   - **ntfy Server URL:** `https://ntfy.${DOMAIN}`
   - **Topic:** `uptimekuma`
   - **Priority:** `5` (default)
4. Test notification

### Other Services

#### Using cURL (ntfy)

```bash
# Basic notification
curl -X POST https://ntfy.${DOMAIN}/mytopic -d "Hello World"

# With title and priority
curl -X POST https://ntfy.${DOMAIN}/alerts \
  -H "Title: High CPU Alert" \
  -H "Priority: urgent" \
  -d "CPU usage above 90% for 5 minutes"

# With authentication
curl -X POST https://ntfy.${DOMAIN}/private \
  -u username:password \
  -d "Authenticated message"

# JSON payload
curl -X POST https://ntfy.${DOMAIN}/mytopic \
  -H "Content-Type: application/json" \
  -d '{"message":"Hello","title":"Notification","priority":5}'
```

#### Using cURL (Gotify)

```bash
# Basic notification
curl -X POST https://gotify.${DOMAIN}/message?token=YOUR_TOKEN \
  -F "title=Alert" \
  -F "message=Something happened" \
  -F "priority=5"

# JSON format
curl -X POST https://gotify.${DOMAIN}/message?token=YOUR_TOKEN \
  -H "Content-Type: application/json" \
  -d '{"title":"Alert","message":"Something happened","priority":5}'
```

## Unified Notification Script

The `scripts/notify.sh` script provides a unified interface with automatic fallback:

```bash
# Usage
./scripts/notify.sh <topic> <title> <message> [priority]

# Examples
./scripts/notify.sh alerts "Deployment" "App deployed successfully"
./scripts/notify.sh alerts "Critical Error" "Database connection failed" urgent
./scripts/notify.sh updates "System" "New updates available" low
```

**Priority levels:** `min`, `low`, `default`, `high`, `urgent`

## Mobile Apps

### ntfy
- **Android:** [ntfy app on Google Play](https://play.google.com/store/apps/details?id=com.ntfy.app)
- **iOS:** [ntfy app on App Store](https://apps.apple.com/us/app/ntfy/id1625396347)
- Subscribe to topics in-app to receive push notifications

### Gotify
- **Android:** [Gotify app on Google Play](https://play.google.com/store/apps/details?id=com.github.gotify.android)
- **iOS:** [Gotify app on App Store](https://apps.apple.com/us/app/gotify/id1469744588)
- Configure server URL and client token in app settings

## Security Considerations

1. **Access Control:** ntfy is configured with `auth-default-access: deny-all` for security
2. **TLS:** All services use HTTPS via Traefik with Let's Encrypt
3. **Authentication:** Configure ntfy users for private topics
4. **Rate Limiting:** Adjust visitor limits in `config/ntfy/server.yml` as needed

## Troubleshooting

### ntfy

```bash
# Check logs
docker logs ntfy

# Test health endpoint
curl http://localhost:80/v1/health

# Test publish
curl -X POST http://localhost:80/test -d "Hello"
```

### Gotify

```bash
# Check logs
docker logs gotify

# Check database
docker exec -it gotify ls -la /app/data

# Reset admin password
docker exec -it gotify /app/gotify users password admin newpassword
```

### Common Issues

| Issue | Solution |
|-------|----------|
| Notifications not received | Check firewall, verify Traefik routing, check service logs |
| Auth failures | Verify credentials in `.env`, check ntfy auth file |
| Gotify fallback not working | Ensure `GOTIFY_TOKEN` is set in `.env` |
| Rate limiting errors | Adjust limits in `config/ntfy/server.yml` |

## Resources

- [ntfy Documentation](https://ntfy.sh/)
- [Gotify Documentation](https://gotify.net/docs/)
- [Apprise Documentation](https://github.com/caronc/apprise)
