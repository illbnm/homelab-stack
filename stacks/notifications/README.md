# Notifications Stack

Unified notification center for all homelab services using **ntfy** and **Gotify**.

## 🎯 Overview

This stack provides a centralized notification system that allows all other services in your homelab to send push notifications to your devices.

| Service | Purpose | Web UI |
|---------|---------|--------|
| **ntfy** | Primary push notification server | `https://ntfy.${DOMAIN}` |
| **Gotify** | Backup push notification server | `https://gotify.${DOMAIN}` |
| **Apprise** | Multi-platform notification aggregator | `https://apprise.${DOMAIN}` |

## 📋 Prerequisites

- Docker and Docker Compose installed
- Traefik reverse proxy configured (from base stack)
- Domain name with DNS configured
- (Optional) ntfy mobile app for push notifications

## 🚀 Quick Start

1. **Start the stack:**
   ```bash
   docker compose -f stacks/notifications/docker-compose.yml up -d
   ```

2. **Verify services are running:**
   ```bash
   docker compose -f stacks/notifications/docker-compose.yml ps
   ```

3. **Test ntfy notification:**
   ```bash
   curl -d "Hello from Homelab!" https://ntfy.${DOMAIN}/homelab-test
   ```

4. **Subscribe to topics:**
   - Open `https://ntfy.${DOMAIN}` in your browser
   - Subscribe to topics like `homelab-alerts`, `updates`, etc.

## 📱 Mobile App Setup

### ntfy (Recommended)

1. **Download the app:**
   - [iOS App Store](https://apps.apple.com/app/ntfy/id1255233922)
   - [Google Play Store](https://play.google.com/store/apps/details?id=io.heckel.ntfy)
   - [F-Droid](https://f-droid.org/en/packages/io.heckel.ntfy/)

2. **Configure your server:**
   - Open the app
   - Settings → Default server
   - Enter your server URL: `https://ntfy.${DOMAIN}`

3. **Subscribe to topics:**
   - Add subscription: `homelab-alerts`
   - Add subscription: `updates`
   - Add subscription: `backups`

### Gotify

1. **Download the app:**
   - [Google Play Store](https://play.google.com/store/apps/details?id=com.github.gotify)
   - [F-Droid](https://f-droid.org/packages/com.github.gotify/)

2. **Configure:**
   - Open `https://gotify.${DOMAIN}`
   - Create an application
   - Copy the token to use with the notification script

## 🔔 Service Integration

### Alertmanager (Prometheus Alerts)

Alertmanager is pre-configured to send alerts to ntfy. The configuration is in `config/alertmanager/alertmanager.yml`.

**Topic mapping:**
| Alert Severity | ntfy Topic | Priority |
|----------------|------------|----------|
| Warning | `homelab-alerts` | default |
| Critical | `homelab-alerts-critical` | high |

**Test Alertmanager integration:**
```bash
# Create a test alert
curl -XPOST http://localhost:9093/api/v2/alerts \
  -H "Content-Type: application/json" \
  -d '[{
    "labels": {"alertname": "TestAlert", "severity": "warning"},
    "annotations": {"summary": "This is a test alert"}
  }]'
```

### Watchtower (Container Updates)

Configure Watchtower to send notifications when containers are updated:

```bash
# Add to .env
WATCHTOWER_NOTIFICATION_URL=ntfy://ntfy:80/homelab-updates?title=Watchtower

# Or via environment in docker-compose.yml
environment:
  - WATCHTOWER_NOTIFICATION_URL=ntfy://ntfy:80/homelab-updates
  - WATCHTOWER_NOTIFICATIONS_LEVEL=info
```

### Gitea (Git Webhooks)

Send push notifications on repository events:

1. **Create a webhook in Gitea:**
   - Repository → Settings → Webhooks → Add Webhook
   - Target URL: `https://ntfy.${DOMAIN}/gitea-events`
   - HTTP Method: POST
   - Content Type: application/json

2. **Custom payload (optional):**
   ```json
   {
     "topic": "gitea-events",
     "title": "{{ .Repository.FullName }} - {{ .Action }}",
     "message": "{{ .Pusher.UserName }} pushed to {{ .Ref }}"
   }
   ```

### Home Assistant

Add ntfy as a notification integration:

1. **Configuration:**
   ```yaml
   # configuration.yaml
   notify:
     - name: ntfy
       platform: rest
       method: POST
       title_param: title
       message_param: message
       resource: https://ntfy.{{ DOMAIN }}/homeassistant
       data:
         priority: default
         tags: homeassistant
   ```

2. **Automation example:**
   ```yaml
   automation:
     - alias: "Notify on person arrival"
       trigger:
         - platform: state
           entity_id: device_tracker.phone
           to: "home"
       action:
         - service: notify.ntfy
           data:
             title: "Person Arrived"
             message: "Phone is now at home"
             data:
               priority: default
   ```

### Uptime Kuma

Configure ntfy as a notification channel:

1. **Create notification channel:**
   - Settings → Notifications → Add Notification
   - Type: ntfy
   - ntfy Server URL: `https://ntfy.${DOMAIN}`
   - Topic: `uptime-kuma`
   - Priority: default

2. **Assign to monitors:**
   - Edit each monitor
   - Select the ntfy notification channel

## 🛠️ Notification Script

Use the unified notification script for consistent notifications:

```bash
# Basic usage
./scripts/notify.sh <topic> <title> <message> [priority]

# Examples:
./scripts/notify.sh homelab "Backup Complete" "All databases backed up"
./scripts/notify.sh alerts "Critical" "Disk usage above 90%" high
./scripts/notify.sh updates "Container Updated" "nginx updated to v1.25" low

# From another script
./scripts/notify.sh backups "Backup Failed" "Error: disk full" urgent
```

**Priority levels:**
| Priority | ntfy | Gotify | Use Case |
|----------|------|--------|----------|
| Minimum | min | 1 | Non-urgent info |
| Low | low | 3 | FYI notifications |
| Default | default | 5 | Normal notifications |
| High | high | 8 | Important alerts |
| Urgent | urgent | 10 | Critical alerts |

**Environment variables:**
```bash
# Required
export DOMAIN=home.example.com

# Optional
export NTFY_URL=https://ntfy.$DOMAIN
export NTFY_TOKEN=your_access_token  # For protected topics
export GOTIFY_URL=https://gotify.$DOMAIN
export GOTIFY_TOKEN=your_app_token   # For Gotify fallback
export FALLBACK_ENABLED=true
```

## 🔐 Security Configuration

### ntfy Authentication

1. **Create admin user:**
   ```bash
   docker exec -it ntfy ntfy user add --role=admin admin
   ```

2. **Create service users (optional):**
   ```bash
   docker exec -it ntfy ntfy user add --role=user watchtower
   docker exec -it ntfy ntfy access watchtower homelab-updates rw
   ```

3. **Protect topics:**
   ```bash
   # Restrict topic access
   docker exec -it ntfy ntfy access everyone homelab-alerts none
   docker exec -it ntfy ntfy access admin homelab-alerts rw
   ```

### Gotify Authentication

1. **Login to Gotify:**
   - Open `https://gotify.${DOMAIN}`
   - Default: admin/admin (change immediately!)

2. **Create applications:**
   - Apps → Create Application
   - Name: "Homelab Notifications"
   - Copy the token

3. **Update environment:**
   ```bash
   export GOTIFY_TOKEN=your_app_token
   ```

## 📊 Monitoring

### Health Checks

```bash
# Check ntfy health
curl -sf https://ntfy.${DOMAIN}/v1/health

# Check Gotify health
curl -sf https://gotify.${DOMAIN}/health

# Check Apprise health
curl -sf https://apprise.${DOMAIN}/status
```

### Logs

```bash
# View ntfy logs
docker logs ntfy -f

# View Gotify logs
docker logs gotify -f

# View all notification stack logs
docker compose -f stacks/notifications/docker-compose.yml logs -f
```

## 🔧 Troubleshooting

### ntfy not receiving notifications

1. **Check service is running:**
   ```bash
   docker ps | grep ntfy
   curl https://ntfy.${DOMAIN}/v1/health
   ```

2. **Check topic permissions:**
   ```bash
   docker exec -it ntfy ntfy access
   ```

3. **Check firewall:**
   - Ensure port 443 is open
   - Check Traefik routing

### Gotify token issues

1. **Verify token:**
   ```bash
   curl -H "X-Gotify-Key: YOUR_TOKEN" https://gotify.${DOMAIN}/application
   ```

2. **Regenerate token:**
   - Login to Gotify UI
   - Apps → Regenerate Token

### Mobile app not receiving push notifications

1. **Check server URL:**
   - Settings → Default server
   - Must be exactly `https://ntfy.${DOMAIN}`

2. **Check topic subscription:**
   - Verify you're subscribed to the topic
   - Check notification permissions

3. **Check battery optimization (Android):**
   - Disable battery optimization for ntfy app
   - Enable "Instant Delivery" mode

## 📚 Additional Resources

- [ntfy Documentation](https://ntfy.sh/docs/)
- [ntfy GitHub](https://github.com/binwiederhier/ntfy)
- [Gotify Documentation](https://gotify.net/docs/)
- [Gotify GitHub](https://github.com/gotify/server)
- [Apprise Documentation](https://github.com/caronc/apprise)

## 📝 TODO

- [ ] Add Telegram/Discord bot integration
- [ ] Add SMTP fallback
- [ ] Create Grafana dashboard for notification metrics
- [ ] Add notification templating system
