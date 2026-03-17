# Notifications Stack

This stack sets up a unified notification center using `ntfy` and `Gotify` for sending notifications from various services.

## Services

- **ntfy**: Push notification server.
- **Gotify**: Backup push service.

## Configuration

### ntfy

Configuration for `ntfy` is located in `config/ntfy/server.yml`.

### Gotify

Configuration for `Gotify` is located in `config/gotify/server.yml`.

## Integration with Other Services

| Service        | Configuration Way                                                                 |
|----------------|-----------------------------------------------------------------------------------|
| Alertmanager   | Configure webhook receiver to point to `ntfy` at `https://ntfy.${DOMAIN}/homelab-alerts` |
| Watchtower     | Set `WATCHTOWER_NOTIFICATION_URL=ntfy://https://ntfy.${DOMAIN}/homelab-watchtower`    |
| Gitea          | Configure webhook to send to `ntfy` at `https://ntfy.${DOMAIN}/homelab-gitea`          |
| Home Assistant | Use `ntfy` notify integration                                                       |
| Uptime Kuma    | Configure ntfy notification channel                                                 |

## Usage

To send a notification, use the `notify.sh` script:

