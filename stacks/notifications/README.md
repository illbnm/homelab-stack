# Notifications Stack

## Services

- **ntfy**: Push notification server
- **Gotify**: Backup push service

## Integration Documentation

| Service        | Configuration Way                                                                 |
|----------------|-----------------------------------------------------------------------------------|
| Alertmanager   | webhook receiver pointing to ntfy                                                 |
| Watchtower     | `WATCHTOWER_NOTIFICATION_URL=ntfy://https://ntfy.${DOMAIN}/homelab-updates`       |
| Gitea          | webhook sent to ntfy                                                              |
| Home Assistant | ntfy notify integration                                                             |
| Uptime Kuma    | ntfy notification channel                                                           |

## Alertmanager Route Configuration

