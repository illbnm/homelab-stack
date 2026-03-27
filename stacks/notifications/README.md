# Notifications Stack

> Unified notification center: Gotify, ntfy, and Apprise for multi-channel alerts

## Services

| Service | Image | Access | Purpose |
|---------|-------|--------|---------|
| ntfy | binwiederhier/ntfy:v2.11.0 | `https://ntfy.${DOMAIN}` | Push notifications (MQTT bridge, Android/iOS apps) |
| Gotify | gotify/server:2.5.0 | `https://gotify.${DOMAIN}` | Alert gateway (WebSocket, plugins) |
| Apprise | caronc/apprise:v1.1.6 | `https://apprise.${DOMAIN}` | Multi-platform notification aggregator |

## Quick Start

```bash
# Ensure required env vars are set in .env:
#   GOTIFY_TOKEN=<your-gotify-token>
#   NTFY_TOKEN=<your-ntfy-token>  (optional, for auth)

docker compose -f stacks/notifications/docker-compose.yml up -d
```

### Getting a Gotify Token

1. Open `https://gotify.${DOMAIN}`
2. Login (first user created on first access)
3. Go to **Apps** → **Create App**
4. Copy the generated token and add to `.env`:
   ```
   GOTIFY_TOKEN=your-gotify-token-here
   ```

### Getting an ntfy Token (Optional)

1. Open `https://ntfy.${DOMAIN}/settings`
2. Under **Access Tokens**, click **Create access token**
3. Add to `.env`:
   ```
   NTFY_TOKEN=your-ntfy-token-here
   ```

## Unified Notify Script

A script for sending notifications to all configured channels.

### Usage

```bash
./scripts/notify.sh <priority> <title> <message> [tags]

# Examples:
./scripts/notify.sh low "Backup Done" "PostgreSQL backup complete (250MB)"
./scripts/notify.sh high "ALERT" "Disk usage at 95%" "warning,server"
./scripts/notify.sh urgent "CRITICAL" "Service down" "rotating_light"
```

### Priority Levels

| Priority | ntfy Level | Gotify Level | Use Case |
|----------|------------|--------------|----------|
| `low` | 5 (min) | 1 | Background info |
| `normal` | 3 (default) | 5 | General notifications |
| `high` | 8 | 8 | Important alerts |
| `urgent` | 10 (max) | 10 | Critical errors |

### Tags

Comma-separated tags for visual icons in ntfy apps:
`warning`, `error`, `information_source`, `server`, `bug`, `rocket`, `books`, etc.

## Integration Examples

### Traefik Access Logs → ntfy

Add to docker-compose service labels:
```yaml
labels:
  - "traefik.http.routers.myservice.middlewares=logstash@file"
```

### Alertmanager → Gotify

```yaml
# alertmanager config
receivers:
  - name: gotify
    gotify_configs:
      - url: https://gotify.${DOMAIN}/message
        token: ${GOTIFY_TOKEN}
        severity: critical
```

### Watchtower Updates → ntfy

```yaml
services:
  watchtower:
    environment:
      - WATCHTOWER_NOTIFICATIONS=ntfy
      - WATCHTOWER_NOTIFICATION_NTFY_TOPIC=homelab
      - WATCHTOWER_NOTIFICATION_NTFY_TOKEN=${NTFY_TOKEN}
```

### Home Assistant → ntfy

```yaml
# configuration.yaml
notify:
  - name: ntfy
    platform: rest
    resource: https://ntfy.${DOMAIN}/homelab
    method: POST
    headers:
      Authorization: "Bearer ${NTFY_TOKEN}"
      Priority: "3"
      Tags: "home"
```

### Gitea Notifications → Gotify

Configure in Gitea → Site Administration → Service URLs:
- Gotify URL: `https://gotify.${DOMAIN}`
- Gotify Token: `${GOTIFY_TOKEN}`

## ntfy MQTT Bridge

Enable MQTT bridge for IoT device integration (Zigbee2MQTT, ESPHome, etc.):

1. Uncomment MQTT section in `config/ntfy/server.yml`
2. Add MQTT credentials to `.env`:
   ```
   MQTT_USERNAME=your_mqtt_user
   MQTT_PASSWORD=your_mqtt_password
   ```
3. Restart ntfy service

## Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `GOTIFY_TOKEN` | Yes (for Gotify) | - | Gotify app token |
| `NTFY_TOKEN` | No | - | ntfy access token (enables auth) |
| `NTFY_TOPIC` | No | `homelab` | Default ntfy topic/channel |
| `NTFY_SERVER` | No | `https://ntfy.sh` | ntfy server URL |
| `GOTIFY_SERVER` | No | `https://gotify.${DOMAIN}` | Gotify server URL |

## Network

- All services on `proxy` network (Traefik accessible)
- ntfy MQTT bridge connects to `proxy` network for IoT integration
