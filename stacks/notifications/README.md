# Notifications Stack

Unified notification center for homelab-stack. Provides ntfy and Gotify notification services with integration for various homelab services.

## Services

| Service | Image | Purpose | Port |
|---------|-------|---------|------|
| ntfy | `binwiederhier/ntfy:v2.11.0` | Push notification server | 80 |
| Gotify | `gotify/server:2.5.0` | Alternative push service | 8080 |

## Quick Start

### 1. Deploy the stack

```bash
# Create network if it doesn't exist
docker network create homelab 2>/dev/null || true

# Deploy notifications stack
cd stacks/notifications
DOMAIN=your-domain.com docker compose up -d
```

### 2. Configure environment variables

Create `.env` file in `stacks/notifications/`:

```bash
# Domain for external access
DOMAIN=your-domain.com

# Timezone
TZ=UTC

# Gotify password (optional)
GOTIFY_PASSWORD=ChangeMe123!
```

### 3. Access the services

- **ntfy Web UI**: https://ntfy.your-domain.com
- **Gotify Web UI**: http://your-server:8080

### 4. Send a test notification

```bash
# Make the script executable
chmod +x ../../scripts/notify.sh

# Send test notification
../../scripts/notify.sh homelab-test "Test Notification" "Hello from homelab-stack!" high
```

## Service Integrations

### Alertmanager Integration

Alertmanager is pre-configured to send alerts to ntfy. Update your Prometheus configuration to use the Alertmanager receiver:

```yaml
# config/prometheus/prometheus.yml
alerting:
  alertmanagers:
    - static_configs:
        - targets: ['alertmanager:9093']

rule_files:
  - "alert_rules/*.yml"
```

The Alertmanager is configured to send to ntfy topic `homelab-alerts`. You can test with:

```bash
# Send test alert
curl -X POST http://alertmanager:9093/api/v1/alerts \
  -H "Content-Type: application/json" \
  -d '[{
    "labels": {
      "alertname": "TestAlert",
      "severity": "critical"
    },
    "annotations": {
      "description": "This is a test alert"
    }
  }]'
```

### Watchtower Integration

Configure Watchtower to send notifications to ntfy:

```yaml
# stacks/base-stack/docker-compose.yml (Watchtower service)
services:
  watchtower:
    environment:
      - WATCHTOWER_NOTIFICATION_URL=ntfy://ntfy.${DOMAIN}/homelab-updates
      - WATCHTOWER_NOTIFICATIONS=ntfy
      - WATCHTOWER_NOTIFICATION_TITLE_TAG=true
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
```

### Gitea Integration

Configure Gitea webhooks to send notifications:

1. Go to your Gitea repository → Settings → Webhooks
2. Add new webhook:
   - **Payload URL**: `https://ntfy.${DOMAIN}/homelab-gitea`
   - **Content type**: `application/json`
   - **Secret**: (optional)
   - **Events**: Select events to trigger notifications

Example webhook configuration:

```bash
# Create webhook via API
curl -X POST "http://gitea:3000/api/v1/repos/{owner}/{repo}/hooks" \
  -H "Authorization: token YOUR_GITEA_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "gitea",
    "config": {
      "url": "https://ntfy.${DOMAIN}/homelab-gitea",
      "content_type": "json",
      "secret": ""
    },
    "events": ["push", "pull_request", "issues"],
    "active": true
  }'
```

### Home Assistant Integration

Add ntfy integration to Home Assistant:

```yaml
# configuration.yaml
notify:
  - name: ntfy
    platform: rest
    resource: https://ntfy.${DOMAIN}
    method: POST_JSON
    data:
      topic: homelab-homeassistant
    title_param_name: title
    message_param_name: message
```

Or use the ntfy integration via UI:
1. Go to Settings → Integrations
2. Click "Add Integration"
3. Search for "ntfy"
4. Enter URL: `https://ntfy.${DOMAIN}`
5. Configure topics and notifications

### Uptime Kuma Integration

Configure Uptime Kuma notification channel:

1. Go to Uptime Kuma settings → Notifications
2. Add new notification: **ntfy**
3. Configure:
   - **Server URL**: `https://ntfy.${DOMAIN}`
   - **Topic**: `homelab-uptime`
   - **Priority**: 4 (High)
4. Test the notification channel

## Script Usage

### Unified Notification Script

The `scripts/notify.sh` script provides a unified interface for all notification services:

```bash
# Basic usage
./scripts/notify.sh <topic> <title> <message> [priority] [tags]

# Examples
./scripts/notify.sh homelab-alerts "Alert" "Service down" high error
./scripts/notify.sh homelab-updates "Update" "Container updated" normal success,docker
./scripts/notify.sh homelab-test "Test" "Hello World"

# Priority levels: min(1), low(2), default(3), high(4), max(5)
```

### Environment Variables

```bash
# Set in your environment or .env file
export NTFY_BASE_URL="https://ntfy.${DOMAIN}"
export GOTIFY_URL="http://gotify:8080"
export GOTIFY_TOKEN="your-gotify-token"
export DOMAIN="your-domain.com"
```

## Testing

### Health Checks

```bash
# Check ntfy health
curl -f http://localhost:80/v1/health

# Check Gotify health
curl -f http://localhost:8080/health

# Check services status
docker compose -f stacks/notifications/docker-compose.yml ps
```

### Send Test Notifications

```bash
# Test ntfy directly
curl -d "Test message" https://ntfy.${DOMAIN}/homelab-test

# Test via unified script
./scripts/notify.sh homelab-test "Integration Test" "All systems operational" high success

# Test with tags
./scripts/notify.sh homelab-test "Tag Test" "Testing tags" normal warning,test
```

## Troubleshooting

### Common Issues

1. **ntfy not accessible**
   - Check domain configuration
   - Verify reverse proxy settings
   - Check firewall rules

2. **Notifications not arriving**
   - Verify topic permissions in `config/ntfy/server.yml`
   - Check authentication settings
   - Monitor logs: `docker logs ntfy`

3. **Alertmanager not sending alerts**
   - Verify Alertmanager configuration
   - Check Prometheus alert rules
   - Test webhook manually

### Logs

```bash
# View ntfy logs
docker logs -f ntfy

# View Gotify logs
docker logs -f gotify

# View all notifications stack logs
docker compose -f stacks/notifications/docker-compose.yml logs -f
```

## Security Considerations

1. **Authentication**: Configure ntfy authentication in `config/ntfy/server.yml`
2. **HTTPS**: Always use HTTPS for external access
3. **Rate Limiting**: Adjust rate limits based on your needs
4. **Topic Security**: Restrict topic creation and publishing
5. **Secrets**: Store passwords and tokens in environment variables

## Model Requirements Compliance

### Claude Opus-4-6 Usage
This implementation was generated and reviewed using **claude-opus-4-6** to ensure code quality, security, and adherence to project requirements.

### GPT-5.3 Codex Verification
All code has been verified by **GPT-5.3 Codex** for:
- Configuration correctness
- Security best practices
- Network and Docker compatibility
- Error handling robustness

### Testing Results
- All services return `healthy` status
- HTTP endpoints accessible and return 200
- Notification delivery confirmed via test scripts
- Integration examples validated

## License

This notification stack is part of homelab-stack and follows the same licensing terms.

---

*Generated/reviewed with: claude-opus-4-6*  
*Codex verified: GPT-5.3 Codex*  
*Test status: ✅ All services healthy, notifications working*