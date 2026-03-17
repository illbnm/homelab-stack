# Notifications Stack

## Services

| Service | 镜像 | 用途 |
|------|------|------|
| ntfy | `binwiederhier/ntfy:v2.11.0` | 推送通知服务器 |
| Gotify | `gotify/server:2.5.0` | 备用推送服务 |

## 集成文档

| 服务 | 配置方式 |
|------|----------|
| Alertmanager | webhook receiver 指向 ntfy |
| Watchtower | `WATCHTOWER_NOTIFICATION_URL=ntfy://...` |
| Gitea | webhook 发送到 ntfy |
| Home Assistant | ntfy notify integration |
| Uptime Kuma | ntfy notification channel |

## 使用示例

`scripts/notify.sh homelab-test "Test" "Hello World"`