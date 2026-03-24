# 通知服务栈 (Notifications Stack)

统一通知中心，让所有服务（Watchtower、Alertmanager、Gitea 等）都能向用户推送通知。

## 服务清单

| 服务 | 镜像 | 端口 | 用途 |
|------|------|------|------|
| ntfy | `binwiederhier/ntfy:v2.11.0` | 8088 | 主推送通知服务器 |
| Gotify | `gotify/server:2.5.0` | 8089 | 备用推送服务 |

## 快速开始

### 1. 启动服务

```bash
cd stacks/notifications
docker compose up -d
```

### 2. 访问 Web UI

- **ntfy**: https://ntfy.your-domain.com
- **Gotify**: https://gotify.your-domain.com

### 3. 安装手机 App

- **ntfy**: [Android](https://play.google.com/store/apps/details?id=io.heckel.ntfy) | [iOS](https://apps.apple.com/us/app/ntfy/id1635463162)
- **Gotify**: [Android](https://play.google.com/store/apps/details?id=com.github.gotify)

### 4. 订阅主题

在手机 App 中订阅主题：`homelab-alerts`

## 验收清单

- [ ] ntfy Web UI 可访问
- [ ] 手机 App 可收到测试推送
- [ ] `scripts/notify.sh homelab-test "Test" "Hello World"` 成功
- [ ] Alertmanager 告警触发时收到通知
- [ ] Watchtower 更新后收到通知

**赏金**: $80 USDT
