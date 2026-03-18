# Notifications Stack

This stack provides a unified notification center for HomeLab services.

## Services

- **ntfy** (`ntfy.${DOMAIN}`) - primary push notification server
- **Gotify** (`gotify.${DOMAIN}`) - fallback/secondary push notification server
- **Apprise** (`apprise.${DOMAIN}`) - optional outbound notification gateway

## Start

```bash
./scripts/stack-manager.sh up notifications
```

## Unified notify script

Use one script for all internal notification calls:

```bash
./scripts/notify.sh homelab-test "Test" "Hello World" high
```

Parameters:

1. `topic` (e.g. `homelab-alerts`)
2. `title`
3. `message`
4. `priority` (optional: `low|default|high|max`)

## Integrations

### Alertmanager -> ntfy

Configure `config/alertmanager/alertmanager.yml` receiver to point to:

```yaml
receivers:
  - name: ntfy
    webhook_configs:
      - url: 'https://ntfy.${DOMAIN}/homelab-alerts'
        send_resolved: true
```

### Watchtower -> ntfy

Set env in base stack (watchtower service):

```env
WATCHTOWER_NOTIFICATION_URL=ntfy://ntfy.${DOMAIN}/homelab-alerts
```

### Gitea -> ntfy

Configure a webhook in Gitea repo settings:

- Target URL: `https://ntfy.${DOMAIN}/gitea-events`
- Method: `POST`

### Home Assistant -> ntfy

Add ntfy integration/notify target in Home Assistant:

- Server: `https://ntfy.${DOMAIN}`
- Topic: `homeassistant-events`

### Uptime Kuma -> ntfy

Create an ntfy notification channel:

- Host: `https://ntfy.${DOMAIN}`
- Topic: `uptime-alerts`

## Health checks

- ntfy: `https://ntfy.${DOMAIN}/v1/health`
- gotify: `https://gotify.${DOMAIN}/health`
- apprise: `https://apprise.${DOMAIN}/`
