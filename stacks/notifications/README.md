# Notifications Stack — 统一通知中心

> **Services:** ntfy (push notifications) + Apprise (multi-gateway notification router)
>
> **Bounty:** $80 USDT ✅

## 快速开始

### 1. 环境配置

确保 `.env` 文件中已设置：

```bash
DOMAIN=yourdomain.com
TZ=Asia/Shanghai
NTFY_AUTH_ENABLED=true
```

### 2. 启动服务

```bash
# 确保网络已创建
docker network create proxy 2>/dev/null || true
docker network create monitoring 2>/dev/null || true

# 启动 notifications stack
cd stacks/notifications
docker compose up -d
```

### 3. 验证服务

- **ntfy Web UI:** https://ntfy.yourdomain.com
- **Apprise API:** https://apprise.yourdomain.com

### 4. 测试推送

```bash
# 使用统一通知脚本
./scripts/notify.sh homelab-test "Test" "Hello World"

# 或直接使用 curl
curl -H "Title: Test" -H "Priority: 3" -d "Hello World" https://ntfy.yourdomain.com/homelab-test
```

---

## 服务集成配置

### Alertmanager

Alertmanager 已配置为向 ntfy 发送告警通知。

**配置文件:** `config/alertmanager/alertmanager.yml`

```yaml
receivers:
  - name: ntfy-critical
    webhook_configs:
      - url: 'http://ntfy:80/homelab-alerts?priority=5&tags=warning,rotating_light'
        send_resolved: true
```

**测试:**

```bash
# 在 Alertmanager UI 中手动触发告警
# 或等待 Prometheus 触发告警
```

---

### Watchtower

Watchtower 自动更新容器后发送通知。

**更新 `stacks/base/docker-compose.yml`:**

```yaml
watchtower:
  image: containrrr/watchtower:1.7.1
  environment:
    - TZ=${TZ}
    - WATCHTOWER_CLEANUP=true
    - WATCHTOWER_SCHEDULE=0 0 4 * * *
    # 添加 ntfy 通知配置
    - WATCHTOWER_NOTIFICATIONS=shoutrrr
    - WATCHTOWER_NOTIFICATION_URL=ntfy://ntfy:80/homelab-updates?priority=3
```

**或使用 Apprise URL:**

```yaml
- WATCHTOWER_NOTIFICATION_URL=apprise://apprise:8000/homelab-updates?title=Watchtower
```

**订阅主题:** https://ntfy.yourdomain.com/homelab-updates

---

### Gitea

Gitea 通过 webhook 发送通知。

**方式一: 使用 ntfy webhook**

1. 进入 Gitea 仓库设置 → Webhooks → 添加 Webhook
2. 配置:

```
Target URL: https://ntfy.yourdomain.com/gitea-events
HTTP Method: POST
Content Type: application/json
Secret: (留空或设置 token)
Trigger On: Push, Pull Request, Release
```

3. 测试 webhook 即可收到推送

**方式二: 使用脚本**

创建 `scripts/gitea-notify.sh`:

```bash
#!/bin/bash
# Gitea webhook receiver

EVENT=$(cat)
TOPIC="gitea-events"
TITLE="Gitea Event"
MESSAGE="$EVENT"

./scripts/notify.sh "$TOPIC" "$TITLE" "$MESSAGE"
```

---

### Home Assistant

Home Assistant 通过 ntfy integration 发送通知。

**配置 `configuration.yaml`:**

```yaml
notify:
  - name: ntfy
    platform: rest
    resource: https://ntfy.yourdomain.com/hass
    method: POST
    message_param_name: message
    title_param_name: title
    data:
      priority: 3
```

**自动化示例:**

```yaml
automation:
  - alias: "Send notification when door opens"
    trigger:
      - platform: state
        entity_id: binary_sensor.front_door
        to: "on"
    action:
      - service: notify.ntfy
        data:
          title: "Front Door Opened"
          message: "The front door has been opened"
          data:
            priority: 4
```

**或使用官方 ntfy integration (HACS):**

```yaml
ntfy:
  host: https://ntfy.yourdomain.com
  username: !secret ntfy_user
  password: !secret ntfy_pass
```

---

### Uptime Kuma

Uptime Kuma 可配置 ntfy 作为通知渠道。

**方式一: 通过 Apprise**

1. 进入 Uptime Kuma → Settings → Notifications
2. 添加 Apprise 类型通知
3. Apprise URL:

```
ntfy://ntfy.yourdomain.com/uptime-kuma?priority=4
```

**方式二: 通过 Webhook**

1. 添加 Webhook 类型通知
2. URL: `https://ntfy.yourdomain.com/uptime-kuma`
3. Method: POST
4. Headers: `Title: Uptime Kuma Alert`

---

### 其他服务

**通用方式:**

任何支持 webhook 或 HTTP 通知的服务都可以使用 ntfy:

```bash
# 基本 HTTP POST
curl -H "Title: Alert Title" -d "Message body" https://ntfy.yourdomain.com/topic-name

# 带优先级
curl -H "Title: Critical Alert" -H "Priority: 5" -d "Server down!" https://ntfy.yourdomain.com/alerts

# 带标签
curl -H "Title: Backup Complete" -H "Tags: backup,success" -d "All data backed up" https://ntfy.yourdomain.com/backups
```

---

## 统一通知脚本

**位置:** `scripts/notify.sh`

**用法:**

```bash
./scripts/notify.sh <topic> <title> <message> [priority]
```

**参数:**

| 参数 | 说明 | 示例 |
|------|------|------|
| topic | ntfy 主题名称 | homelab-alerts, backups |
| title | 通知标题 | "Backup Complete" |
| message | 通知内容 | "All databases backed up" |
| priority | 优先级 (1-5) | 1=min, 3=default, 5=max |

**示例:**

```bash
# 普通通知
./scripts/notify.sh homelab-alerts "Test" "Hello World"

# 高优先级
./scripts/notify.sh homelab-alerts "Critical" "Server down!" 5

# 从其他脚本调用
./scripts/notify.sh backups "Backup Status" "$(cat backup.log)" 3
```

---

## Apprise 多网关路由

Apprise 支持将通知转发到 80+ 服务。

**支持的服务:** Discord, Slack, Telegram, Pushover, Email, Twilio, etc.

**配置文件:** `/config/apprise.conf` (Apprise 容器内)

**示例配置:**

```ini
# Discord
discord://webhook_id/webhook_token

# Slack
slack://botname/tokenA/tokenB/channel

# Telegram
tgram://bot_token/chat_id

# Email (SMTP)
mailto://user:password@example.com

# Pushover
pover://user_key@api_token
```

**使用 API:**

```bash
# 发送到所有配置的服务
curl -X POST http://apprise:8000/notify \
  -d "body=Hello World" \
  -d "title=Notification"

# 发送到特定服务
curl -X POST http://apprise:8000/notify/discord \
  -d "body=Hello Discord"
```

---

## 移动端配置

### Android

1. 安装 ntfy App: [Google Play](https://play.google.com/store/apps/details?id=io.heckel.ntfy) 或 [F-Droid](https://f-droid.org/packages/io.heckel.ntfy/)
2. 打开 App → 设置 → 默认服务器
3. 输入: `https://ntfy.yourdomain.com`
4. 订阅主题

### iOS

1. 安装 ntfy App: [App Store](https://apps.apple.com/app/ntfy/id1628306794)
2. 配置服务器和订阅主题

---

## 认证配置

### 启用用户认证

```bash
# 进入 ntfy 容器
docker exec -it ntfy sh

# 创建用户
ntfy user add admin --role admin

# 创建只读用户
ntfy user add viewer --role user

# 为用户授权主题
ntfy access admin homelab-alerts rw
ntfy access viewer homelab-alerts r
```

### Token 认证

```bash
# 创建 token
ntfy token create admin

# 使用 token
NTFY_TOKEN=tk_xxxxxx ./scripts/notify.sh alerts "Title" "Message"
```

---

## 故障排除

### 检查服务状态

```bash
# 检查 ntfy 健康状态
curl https://ntfy.yourdomain.com/v1/health

# 检查容器日志
docker logs ntfy
docker logs apprise
```

### 常见问题

**1. 无法收到推送**

- 检查 Traefik 路由是否正确
- 检查 ntfy 容器是否运行
- 检查防火墙是否放行

**2. 移动端无法连接**

- 确认服务器 URL 正确 (https://ntfy.yourdomain.com)
- 检查 SSL 证书是否有效
- 检查认证配置

**3. Alertmanager 不发送通知**

- 检查 Alertmanager 配置是否正确
- 确认 alertmanager 容器在 monitoring 网络
- 检查 ntfy 是否在 monitoring 网络

---

## 验收清单

- [x] ntfy Web UI 可访问
- [ ] 手机安装 ntfy App 可收到测试推送
- [ ] `scripts/notify.sh homelab-test "Test" "Hello World"` 成功推送
- [ ] Alertmanager 告警触发时 ntfy 收到通知
- [ ] Watchtower 更新容器后 ntfy 收到通知
- [ ] README 中所有服务集成说明完整可操作

---

## 相关文件

| 文件 | 说明 |
|------|------|
| `stacks/notifications/docker-compose.yml` | Docker 服务定义 |
| `config/ntfy/server.yml` | ntfy 服务配置 |
| `config/alertmanager/alertmanager.yml` | Alertmanager 集成配置 |
| `scripts/notify.sh` | 统一通知脚本 |

---

*实现于 2026-03-25 • Bounty: $80 USDT*