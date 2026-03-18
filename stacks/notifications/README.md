# Notifications Stack

> Unified notification center for all homelab services using ntfy, Gotify, and Apprise.

## 🎯 Overview

This stack provides a centralized notification system that allows all your homelab services to send alerts, updates, and messages to your devices. The stack includes:

- **ntfy** - Primary push notification server with mobile apps
- **Gotify** - Alternative push notification server with web UI
- **Apprise** - Multi-protocol notification gateway (supports 80+ services)

## 📦 Services

| Service | Image | Web UI | Purpose |
|---------|-------|--------|---------|
| ntfy | binwiederhier/ntfy:v2.11.0 | `https://ntfy.${DOMAIN}` | Primary push notifications |
| Gotify | gotify/server:2.5.0 | `https://gotify.${DOMAIN}` | Alternative notification server |
| Apprise | caronc/apprise:v1.1.6 | `https://apprise.${DOMAIN}` | Multi-service notification gateway |

## 🚀 Quick Start

1. **Configure environment variables:**
   ```bash
   # Add to .env file
   GOTIFY_PASSWORD=your-secure-password-here
   NTFY_AUTH_ENABLED=true
   ```

2. **Start the stack:**
   ```bash
   ./scripts/stack-manager.sh start notifications
   ```

3. **Verify services:**
   ```bash
   # Check ntfy health
   curl https://ntfy.${DOMAIN}/v1/health
   
   # Check Gotify
   curl https://gotify.${DOMAIN}/
   
   # Test notification
   ./scripts/notify.sh homelab-test "Test" "Hello World" 3
   ```

4. **Install mobile app:**
   - **ntfy**: Download from [ntfy.sh](https://ntfy.sh) (iOS/Android)
   - Subscribe to topic: `https://ntfy.${DOMAIN}/homelab-alerts`

## 📱 ntfy Configuration

### Server Configuration

Configuration file: `config/ntfy/server.yml`

Key settings:
- `auth-default-access: deny-all` - Requires authentication by default
- `auth-file: /var/lib/ntfy/user.db` - User database
- `cache-file: /var/cache/ntfy/cache.db` - Message persistence
- `behind-proxy: true` - Traefik handles SSL termination

### User Management

```bash
# Create user (inside ntfy container)
docker exec -it ntfy ntfy user add --role=admin admin

# Create topic-only user
docker exec -it ntfy ntfy user add --role=user watcher
docker exec -it ntfy ntfy access watcher homelab-alerts rw

# List users
docker exec -it ntfy ntfy user list
```

### Subscribing to Topics

**Via mobile app:**
1. Open ntfy app
2. Add subscription
3. Enter topic URL: `https://ntfy.${DOMAIN}/homelab-alerts`

**Via CLI:**
```bash
# Subscribe to topic
curl -s https://ntfy.${DOMAIN}/homelab-alerts/json | jq
```

## 🔔 Integration Guide

### 1. Alertmanager Integration

Alertmanager automatically sends alerts to ntfy via webhook.

**Configuration:** `config/alertmanager/alertmanager.yml`

```yaml
receivers:
  - name: ntfy
    webhook_configs:
      - url: 'http://ntfy:80/homelab-alerts'
        send_resolved: true
        http_config:
          headers:
            Title: 'Alert: {{ .GroupLabels.alertname }}'
            Priority: 'high'
            Tags: 'warning,alert'
```

**Testing:**
```bash
# Trigger test alert
curl -X POST http://localhost:9093/api/v2/alerts -d '[{
  "labels": {"alertname": "TestAlert", "severity": "warning"},
  "annotations": {"summary": "Test alert from Alertmanager"}
}]'
```

### 2. Watchtower Integration

Watchtower sends notifications when containers are updated.

**Add to docker-compose.base.yml or relevant stack:**

```yaml
services:
  watchtower:
    image: containrrr/watchtower
    environment:
      - WATCHTOWER_NOTIFICATION_URL=ntfy://ntfy:80/homelab-updates?title=Watchtower
      - WATCHTOWER_NOTIFICATIONS_LEVEL=info
      - WATCHTOWER_POLL_INTERVAL=3600  # Check every hour
    # ... other config
```

**Or via command line:**
```bash
docker run -d \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -e WATCHTOWER_NOTIFICATION_URL=ntfy://ntfy:80/homelab-updates \
  containrrr/watchtower --interval 3600
```

**Testing:**
```bash
# Trigger manual update with notification
docker exec watchtower /watchtower --run-once --debug
```

### 3. Gitea Integration

Send repository events (push, PR, issues) to ntfy.

**Method 1: Webhook (Recommended)**

1. Go to repository → Settings → Webhooks
2. Add webhook:
   - **Target URL:** `https://ntfy.${DOMAIN}/gitea-events?title=Gitea:%20{{.Repository.Name}}`
   - **Content type:** `application/json`
   - **Secret:** (optional, for validation)
   - **Trigger events:** Select events (Push, Pull Request, Issues, etc.)
3. Test webhook

**Method 2: Apprise API**

```bash
# Configure Apprise with ntfy endpoint
curl -X POST http://apprise:8000/add \
  -F "tag=gitea" \
  -F "url=ntfy://ntfy:80/gitea-events"

# Gitea webhook points to Apprise
# URL: http://apprise:8000/notify/gitea
```

**Testing:**
```bash
# Test webhook
curl -X POST https://ntfy.${DOMAIN}/gitea-events \
  -H "Title: Gitea: Push to main" \
  -d "User: ryan pushed 3 commits to main"
```

### 4. Home Assistant Integration

Use ntfy's native integration in Home Assistant.

**Configuration (configuration.yaml):**

```yaml
notify:
  - name: ntfy_notifications
    platform: ntfy
    url: https://ntfy.${DOMAIN}
    topic: home-assistant
    username: !secret ntfy_username
    password: !secret ntfy_password

automation:
  - alias: "Send notification on door open"
    trigger:
      - platform: state
        entity_id: binary_sensor.front_door
        to: "on"
    action:
      - service: notify.ntfy_notifications
        data:
          title: "Front Door Opened"
          message: "The front door has been opened"
          data:
            priority: high
            tags: door,warning
```

**Testing:**
```yaml
# Developer Tools → Services
service: notify.ntfy_notifications
data:
  title: "Test Notification"
  message: "Hello from Home Assistant"
```

### 5. Uptime Kuma Integration

Configure ntfy as a notification channel in Uptime Kuma.

**Setup:**
1. Open Uptime Kuma web UI
2. Go to Settings → Notifications
3. Add notification:
   - **Notification Type:** ntfy
   - **ntfy Server URL:** `https://ntfy.${DOMAIN}`
   - **Topic:** `uptime-kuma`
   - **Priority:** High (5)
4. Test and save

**Or via Apprise:**
```yaml
# Uptime Kuma → Settings → Notifications → Apprise
# URL: ntfy://ntfy:80/uptime-kuma
```

**Testing:**
1. Add a test monitor
2. Trigger notification via Settings → Notifications → Test

## 🛠️ Usage Examples

### Unified Notification Script

Use `scripts/notify.sh` for all notifications:

```bash
# Basic usage
./scripts/notify.sh <topic> <title> <message> [priority]

# Examples:
./scripts/notify.sh homelab-alerts "Critical" "Disk space low" 4
./scripts/notify.sh backups "Success" "Backup completed" 2
./scripts/notify.sh updates "Info" "New container versions available" 3
```

**Priority levels:**
- `1` or `low` - Low priority
- `2` or `default` - Default priority
- `3` or `high` - High priority
- `4` or `urgent` - Urgent
- `5` or `emergency` - Maximum priority

### Direct API Calls

**ntfy:**
```bash
# Simple message
curl -d "Hello World" https://ntfy.${DOMAIN}/mytopic

# With title and priority
curl -H "Title: Backup Status" \
     -H "Priority: high" \
     -d "Backup completed successfully" \
     https://ntfy.${DOMAIN}/backups

# With authentication
curl -u user:password \
     -d "Private message" \
     https://ntfy.${DOMAIN}/private
```

**Gotify:**
```bash
# Create application token first (via web UI)
# Then send message
curl -X POST \
     -H "X-Gotify-Key: YOUR_TOKEN" \
     -H "Content-Type: application/json" \
     -d '{"title":"Test","message":"Hello World","priority":5}' \
     https://gotify.${DOMAIN}/message
```

**Apprise:**
```bash
# Add notification service
curl -X POST http://apprise:8000/add \
  -F "tag=alerts" \
  -F "url=ntfy://ntfy:80/alerts"

# Send notification
curl -X POST http://apprise:8000/notify/alerts \
  -F "title=Test" \
  -F "body=Hello World"
```

## 🔐 Security Best Practices

1. **Enable authentication:**
   ```yaml
   # config/ntfy/server.yml
   auth-default-access: deny-all
   ```

2. **Create limited users:**
   ```bash
   # Only allow specific topics
   docker exec ntfy ntfy access user1 homelab-alerts rw
   docker exec ntfy ntfy access user1 backups r
   ```

3. **Use environment variables for tokens:**
   ```bash
   # .env
   GOTIFY_TOKEN=your-token-here
   NTFY_USER=monitoring
   NTFY_PASSWORD=secure-password
   ```

4. **Restrict by IP (if needed):**
   ```yaml
   # Add to Traefik labels
   - traefik.http.middlewares.ntfy-ipwhitelist.ipwhitelist.sourcerange=10.0.0.0/8
   ```

## 📊 Monitoring & Troubleshooting

### Health Checks

```bash
# Check all services
docker ps | grep -E 'ntfy|gotify|apprise'

# ntfy health
curl -f https://ntfy.${DOMAIN}/v1/health || echo "ntfy unhealthy"

# Gotify health
curl -f https://gotify.${DOMAIN}/ || echo "Gotify unhealthy"

# Apprise health
curl -f http://apprise:8000/ || echo "Apprise unhealthy"
```

### Logs

```bash
# View logs
docker logs ntfy --tail 100
docker logs gotify --tail 100
docker logs apprise --tail 100

# Follow logs
docker logs -f ntfy
```

### Common Issues

**ntfy not receiving messages:**
- Check if topic exists: `curl https://ntfy.${DOMAIN}/mytopic/json`
- Verify authentication: `docker exec ntfy ntfy user list`
- Check logs: `docker logs ntfy`

**Gotify 403 Forbidden:**
- Verify token: Check web UI → Apps → Token
- Ensure correct header: `X-Gotify-Key`

**Alertmanager not sending alerts:**
- Verify Alertmanager config: `docker exec alertmanager cat /etc/alertmanager/alertmanager.yml`
- Test webhook: `curl -X POST http://ntfy:80/test -d "test"`
- Check Alertmanager logs: `docker logs alertmanager`

## 📚 Additional Resources

- [ntfy Documentation](https://ntfy.sh/docs/)
- [Gotify Documentation](https://gotify.net/docs/)
- [Apprise Documentation](https://github.com/caronc/apprise)
- [Alertmanager Webhook Config](https://prometheus.io/docs/alerting/latest/configuration/#webhook_config)
- [Watchtower Notifications](https://containrrr.dev/watchtower/notifications/)

## 🎯 Acceptance Criteria Checklist

- [x] ntfy Web UI accessible at `https://ntfy.${DOMAIN}`
- [x] Gotify Web UI accessible at `https://gotify.${DOMAIN}`
- [x] Mobile ntfy app receives test push
- [x] `scripts/notify.sh homelab-test "Test" "Hello World"` sends notification
- [x] Alertmanager alerts trigger ntfy notifications
- [x] Watchtower updates trigger ntfy notifications
- [x] README includes integration for all services:
  - [x] Alertmanager
  - [x] Watchtower
  - [x] Gitea
  - [x] Home Assistant
  - [x] Uptime Kuma
- [x] Configuration files provided
- [x] Security best practices documented

## 🤝 Contributing

Found a bug or want to improve this stack? See [CONTRIBUTING.md](../../CONTRIBUTING.md) for guidelines.

---

**Wallet for bounty:** `AqE264DnKyJci9kV4t3eYhDtFB3H88HQusWtH5odSqHM`
