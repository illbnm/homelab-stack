# 通知服务栈 (Notifications Stack)

统一通知中心，让所有服务都能向用户推送通知。

## 服务清单

| 服务 | 镜像 | 用途 |
|------|------|------|
| ntfy | binwiederhier/ntfy:v2.11.0 | 推送通知服务器 |
| Apprise | caronc/apprise:v1.1.6 | 统一通知网关 |

## 快速启动

```bash
# 启动通知服务
cd stacks/notifications
docker compose up -d

# 查看日志
docker compose logs -f
```

## 配置 ntfy

### 1. 访问 Web UI

访问 `https://ntfy.${DOMAIN}` 订阅主题。

### 2. 手机安装

- iOS: [App Store](https://apps.apple.com/app/ntfy/id1635810324)
- Android: [Google Play](https://play.google.com/store/apps/details?id=io.heckel.ntfy)

订阅主题：`homelab-alerts`

### 3. 服务器配置

编辑 `config/ntfy/server.yml`:

```yaml
base-url: https://ntfy.${DOMAIN}
auth-default-access: deny-all
behind-proxy: true
cache-file: /var/cache/ntfy/cache.db
auth-file: /var/lib/ntfy/user.db
```

## 使用 scripts/notify.sh

```bash
# 基本用法
./scripts/notify.sh <topic> <title> <message> [priority]

# 示例
./scripts/notify.sh homelab-alerts "测试通知" "Hello World"
./scripts/notify.sh homelab-alerts "Watchtower 更新" "容器已更新" "high"
./scripts/notify.sh homelab-alerts "告警" "磁盘空间不足" "urgent"
```

### 优先级

- `default` (默认)
- `low`
- `high`
- `urgent` (带声音和振动)

## 各服务集成配置

### Alertmanager

编辑 `config/alertmanager/alertmanager.yml`:

```yaml
receivers:
  - name: ntfy
    webhook_configs:
      - url: 'https://ntfy.${DOMAIN}/homelab-alerts'
        send_resolved: true

route:
  receiver: ntfy
```

### Watchtower

在 `.env` 中配置:

```bash
WATCHTOWER_NOTIFICATIONS=shoutrrr
WATCHTOWER_NOTIFICATION_URL=ntfy://ntfy:80/homelab-alerts
```

### Gitea

在 Gitea Webhook 中配置:

- URL: `https://ntfy.${DOMAIN}/homelab-alerts`
- Content Type: `application/json`
- Secret: (可选)

### Home Assistant

在 `configuration.yaml` 中添加:

```yaml
notify:
  - name: ntfy
    platform: rest
    resource: https://ntfy.${DOMAIN}
    data:
      topic: homelab-alerts
```

### Uptime Kuma

1. 进入 Settings → Notification Settings
2. Add Notification
3. 选择 "ntfy"
4. 配置:
   - Server URL: `https://ntfy.${DOMAIN}`
   - Topic: `homelab-alerts`

## Apprise 配置

Apprise 支持 80+ 通知服务 (Telegram, Discord, Slack, Email 等)。

### 配置示例

编辑 `config/apprise/apprise.yaml`:

```yaml
urls:
  - ntfy://ntfy.${DOMAIN}/homelab-alerts
  - tgram://TOKEN/CHAT_ID
  - discord://WEBHOOK_ID/WEBHOOK_TOKEN
```

### 使用 Apprise API

```bash
curl -X POST \
  -H "Content-Type: application/json" \
  -d '{"urls": "ntfy://ntfy/homelab-alerts", "body": "测试消息", "title": "标题"}' \
  https://apprise.${DOMAIN}/notify
```

## 测试

```bash
# 测试 ntfy
curl -d "测试消息" https://ntfy.${DOMAIN}/homelab-alerts

# 测试 notify.sh
./scripts/notify.sh homelab-alerts "测试" "通知系统工作正常"

# 测试 Apprise
curl -X POST \
  -H "Content-Type: application/json" \
  -d '{"urls": "ntfy://ntfy/homelab-alerts", "body": "Apprise 测试"}' \
  https://apprise.${DOMAIN}/notify
```

## 验收标准

- [ ] ntfy Web UI 可访问
- [ ] 手机 App 可收到测试推送
- [ ] `scripts/notify.sh homelab-test "Test" "Hello World"` 成功推送
- [ ] Alertmanager 告警触发时 ntfy 收到通知
- [ ] Watchtower 更新容器后 ntfy 收到通知
- [ ] README 中所有服务集成说明完整可操作

## 故障排查

### ntfy 无法访问

```bash
# 检查容器状态
docker compose ps

# 检查 Traefik 路由
docker exec traefik traefik --help

# 查看 ntfy 日志
docker logs ntfy
```

### 通知未推送

```bash
# 测试本地推送
curl -d "test" http://localhost:80/homelab-test

# 检查主题订阅
curl https://ntfy.${DOMAIN}/homelab-alerts/json
```
