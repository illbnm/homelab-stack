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

## Integration

| Service        | Configuration Way                                                                 |
|----------------|-----------------------------------------------------------------------------------|
| Alertmanager   | webhook receiver pointing to `ntfy`                                                 |
| Watchtower     | `WATCHTOWER_NOTIFICATION_URL=ntfy://https://ntfy.${DOMAIN}/homelab-updates`       |
| Gitea          | webhook sending to `ntfy`                                                         |
| Home Assistant | ntfy notify integration                                                           |
| Uptime Kuma    | ntfy notification channel                                                         |

## Usage

To send a notification, use the `notify.sh` script:

