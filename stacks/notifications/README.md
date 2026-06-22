# Notifications Stack

统一通知中心。

## 服务集成说明

| 服务 | 配置方式 |
|------|----------|
| Alertmanager | webhook receiver 指向 ntfy |
| Watchtower | `WATCHTOWER_NOTIFICATION_URL=ntfy://...` |
| Gitea | webhook 发送到 ntfy |
| Home Assistant | ntfy notify integration |
| Uptime Kuma | ntfy notification channel |
