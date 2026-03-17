# Notifications Stack

This stack provides a central notification hub for the rest of HomeLab Stack.
It ships with:

- `ntfy` for mobile push delivery and a lightweight web UI
- `Gotify` as a backup notification endpoint
- `scripts/notify.sh` as the single shell interface other scripts should call

## Prerequisites

1. Copy `.env.example` to `.env`.
2. Set at least these variables:
   - `DOMAIN`
   - `NTFY_DOMAIN`
   - `NTFY_USERNAME`
   - `NTFY_PASSWORD`
   - `GOTIFY_DOMAIN`
   - `GOTIFY_PASSWORD`
3. Make sure the external Docker network `proxy` already exists and is used by Traefik.

## Start the stack

```bash
docker compose -f stacks/notifications/docker-compose.yml up -d
```

## Bootstrap ntfy auth

The checked-in `config/ntfy/server.yml` enables auth with `deny-all`, so create the first admin user after startup:

```bash
docker compose -f stacks/notifications/docker-compose.yml exec ntfy \
  ntfy user add --role=admin "$NTFY_USERNAME"
```

After that, test a push:

```bash
scripts/notify.sh homelab-test "Test" "Hello World"
```

If you prefer token-based publishing, generate one from inside the container and store it in `.env`:

```bash
docker compose -f stacks/notifications/docker-compose.yml exec ntfy \
  ntfy token add "$NTFY_USERNAME"
```

## Service URLs

- `https://$NTFY_DOMAIN`
- `https://$GOTIFY_DOMAIN`

## Integration guide

### Alertmanager

Use the checked-in sample at [config/alertmanager/alertmanager.yml](../../config/alertmanager/alertmanager.yml). The webhook URL uses ntfy's built-in `alertmanager` template:

```yaml
receivers:
  - name: ntfy
    webhook_configs:
      - url: "https://ntfy.${DOMAIN}/${ALERTMANAGER_NTFY_TOPIC}?template=alertmanager"
        send_resolved: true
```

### Watchtower

ntfy supports Watchtower through Shoutrrr URLs. The official ntfy examples recommend:

```env
WATCHTOWER_NOTIFICATIONS=shoutrrr
WATCHTOWER_NOTIFICATION_SKIP_TITLE=true
WATCHTOWER_NOTIFICATION_URL=ntfy://:TOKEN@${NTFY_DOMAIN}/${WATCHTOWER_NTFY_TOPIC}?title=WatchtowerUpdates
```

Reference: [ntfy Watchtower examples](https://docs.ntfy.sh/examples/).

### Gitea

Create a custom webhook in Gitea and point it to a dedicated ntfy topic:

```text
https://ntfy.${DOMAIN}/gitea-events?title=GiteaEvent
```

For private instances, add Basic Auth credentials or use an ntfy access token in the `Authorization: Bearer ...` header.

### Home Assistant

Home Assistant has a native ntfy integration. Example `configuration.yaml`:

```yaml
notify:
  - platform: ntfy
    name: homelab_ntfy
    url: "https://ntfy.${DOMAIN}"
    username: !secret ntfy_username
    password: !secret ntfy_password
```

### Uptime Kuma

Add a new notification channel of type `ntfy` in Uptime Kuma:

- URL: `https://ntfy.${DOMAIN}`
- Topic: `uptime-kuma`
- Username/password or token: use the same ntfy credentials you created above

## Unified shell interface

Always call [scripts/notify.sh](../../scripts/notify.sh) from other shell scripts instead of hitting ntfy or Gotify directly:

```bash
scripts/notify.sh backups "Backup finished" "Nightly job completed" high
```

Supported backends:

- `NOTIFY_BACKEND=ntfy`
- `NOTIFY_BACKEND=gotify`
- `NOTIFY_BACKEND=auto` (try ntfy first, then Gotify)

## Notes

- ntfy is the primary delivery path because it has better mobile support and templated webhook rendering.
- Gotify is kept as a secondary endpoint in case you prefer its app or want a separate backup channel.
