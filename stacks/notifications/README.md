# Notifications Stack

统一通知中心，为所有 homelab 服务提供通知推送能力。

## 服务架构

```
┌─────────────────────────────────────────────────────────┐
│                    Notifications Stack                  │
├─────────────────────────────────────────────────────────┤
│                                                          │
│   ntfy (Push Server)                                     │
│   ├── 自托管推送服务，支持 iOS/Android App              │
│   ├── Webhook 接收来自其他服务                           │
│   └── 无需注册账户，本地部署                            │
│                                                          │
│   gotify (Alternative Push)                              │
│   ├── 备用推送服务，ntfy 不可用时切换                   │
│   └── 支持更多通知渠道                                   │
│                                                          │
│   apprise (Notification Router)                          │
│   ├── 统一通知路由，支持 50+ 通知服务                    │
│   ├── Telegram, Discord, Slack, Email, etc.            │
│   └── 将通知转发到多个平台                               │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

## 快速开始

### 1. 启动服务

```bash
cd homelab-stack
docker compose -f stacks/notifications/docker-compose.yml up -d
```

### 2. 访问 Web UI

- **ntfy**: https://ntfy.`${DOMAIN}`
- **gotify**: https://gotify.`${DOMAIN}`
- **apprise**: https://apprise.`${DOMAIN}`

### 3. 初始化 ntfy 用户

首次使用时，需要在 ntfy Web UI 中创建用户账户：

1. 访问 https://ntfy.`${DOMAIN}`
2. 点击右上角菜单
3. 选择 "Settings" -> "Users"
4. 创建用户名和密码

### 4. 测试推送

```bash
# 测试通知（需要先配置 NTFY_HOST 环境变量）
export NTFY_HOST=ntfy
./scripts/notify.sh homelab-test "Test Alert" "Hello from homelab!"

# 带优先级
./scripts/notify.sh homelab-alerts "Critical" "Disk almost full" 5
```

## 服务集成

### Alertmanager 集成

编辑 `config/alertmanager/alertmanager.yml`：

```yaml
global:
  resolve_timeout: 5m

route:
  group_by: [alertname, cluster]
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 12h
  receiver: ntfy
  routes:
    - match:
        severity: critical
      receiver: ntfy
      continue: true

receivers:
  - name: ntfy
    webhook_configs:
      - url: 'http://ntfy:80/homelab-alerts'
        send_resolved: true
```

### Watchtower 集成

在 `.env` 中添加：

```env
WATCHTOWER_NOTIFICATION_URL=ntfy://homelab-updates
WATCHTOWER_NOTIFICATION_EVENTTYPE=container-update
```

或在 `docker-compose.base.yml` 中为 watchtower 添加：

```yaml
environment:
  - WATCHTOWER_NOTIFICATION_URL=ntfy://homelab-updates
  - WATCHTOWER_NOTIFICATION_SCRIPT=/notify.sh
```

### Gitea Webhook 集成

1. 登录 Gitea
2. 进入仓库 -> Settings -> Webhooks
3. 添加 Webhook，选择 "Gitea"
4. URL: `http://ntfy:80/gitea-events`
5. HTTP Method: POST
6. 触发条件选择你需要的事件

### Home Assistant 集成

在 `configuration.yaml` 中：

```yaml
notify:
  - name: ntfy
    platform: ntfy
    url: http://ntfy:80
    topic: home-assistant
```

使用示例：

```yaml
automation:
  - alias: "Doorbell notification"
    trigger:
      - platform: mqtt
        topic: doorbell/pressed
    action:
      - service: notify.ntfy
        data:
          title: "Doorbell"
          message: "Someone is at the door!"
          data:
            priority: 4
            tags: doorbell
```

### Uptime Kuma 集成

1. 进入 Uptime Kuma -> Settings -> Notification
2. 添加新通知渠道
3. 选择 "ntfy" 或 "Custom HTTP"
4. 配置：
   - URL: `http://ntfy:80/uptime-kuma`
   - Method: POST
   - Body: `{"topic": "uptime-kuma", "title": "{{STATUS}}", "message": "{{MSG}}"}`

## apprise 通知服务配置

apprise 支持 50+ 通知服务，常见配置：

### Telegram

```yaml
# config/apprise/apprise.yml
urls:
  - tgram://BOT_TOKEN/CHAT_ID
```

### Discord

```yaml
urls:
  - discord://WEBHOOK_ID/WEBHOOK_TOKEN
```

### Slack

```yaml
urls:
  - slack://TOKEN/CHANNEL/
```

### Email

```yaml
urls:
  - mailto://USER:PASSWORD@SMTP.EXAMPLE.COM:587
```

## notify.sh 使用说明

统一通知脚本，其他脚本应调用此接口：

```bash
./scripts/notify.sh <topic> <title> <message> [priority]
```

参数说明：

| 参数 | 说明 | 示例 |
|------|------|------|
| topic | ntfy topic 名称 | homelab-alerts |
| title | 通知标题 | "Disk Alert" |
| message | 通知内容 | "Disk usage > 90%" |
| priority | 优先级 (1-5) | 5 |

优先级说明：

| 值 | 名称 | 使用场景 |
|----|------|---------|
| 1 | Min | 调试信息 |
| 2 | Low | 一般更新 |
| 3 | Default | 普通通知 |
| 4 | High | 重要警告 |
| 5 | Max | 紧急告警 |

## 环境变量

| 变量 | 默认值 | 说明 |
|------|--------|------|
| TZ | Asia/Shanghai | 时区 |
| DOMAIN | (必填) | 你的域名 |
| NTFY_HOST | ntfy | ntfy 服务地址 |
| NTFY_PORT | 80 | ntfy 服务端口 |

## 健康检查

```bash
# 检查 ntfy
curl http://ntfy:80/v1/health

# 检查 gotify
curl http://gotify:80/health

# 检查 apprise
curl http://apprise:8000/
```

## 故障排除

### ntfy 推送失败

1. 检查 ntfy 服务状态：`docker compose -f stacks/notifications/docker-compose.yml ps`
2. 检查 ntfy 日志：`docker compose -f stacks/notifications/docker-compose.yml logs ntfy`
3. 确认 ntfy 认证设置正确（auth-default-access）

### 手机 App 收不到通知

1. 确认手机和服务器在同一网络
2. 检查 ntfy 服务的 `behind-proxy` 设置
3. 确认 Traefik HTTPS 配置正确
4. 尝试使用自签证书并信任证书

### Alertmanager 告警不推送

1. 检查 alertmanager 配置中 ntfy URL 是否正确
2. 检查 alertmanager 日志：`docker compose -f stacks/monitoring/docker-compose.yml logs alertmanager`
3. 确认 alertmanager 能够访问 ntfy 服务（同一网络）

## 相关文档

- [ntfy 官方文档](https://ntfy.sh/docs/)
- [gotify 官方文档](https://gotify.net/docs)
- [apprise 官方文档](https://github.com/caronc/apprise)
- [Alertmanager 配置](https://prometheus.io/docs/alerting/latest/configuration/)
