# 🔔 HomeLab Notifications Stack

统一通知中心，支持 ntfy、Gotify 和 Apprise，为所有服务提供集中式推送能力。

## 📦 服务清单

| 服务 | 镜像 | 端口 | 用途 |
|------|------|------|------|
| ntfy | `binwiederhier/ntfy:v2.11.0` | 80 | 推送通知服务器 |
| Gotify | `gotify/server:2.5.0` | 80 | 备用推送服务 |
| Apprise | `caronc/apprise:v1.14.0` | 8000 | 通知桥接器 |

## 🚀 快速启动

### 1. 配置环境变量

在项目根目录的 `.env` 文件中添加：

```bash
# Notifications
GOTIFY_PASSWORD=your_secure_password
NTFY_AUTH_ENABLED=true
```

### 2. 启动服务

```bash
cd stacks/notifications
docker compose up -d
```

### 3. 访问服务

| 服务 | URL |
|------|-----|
| ntfy Web UI | https://ntfy.${DOMAIN} |
| Gotify | https://gotify.${DOMAIN} |
| Apprise API | https://apprise.${DOMAIN} |

## 📱 使用 ntfy App

### Android/iOS

1. 从 App Store / Play Store 安装 **ntfy** 应用
2. 打开应用，点击右上角 ➕
3. 订阅主题：
   - `homelab` - 通用通知
   - `homelab-alerts` - 告警通知
   - `homelab-updates` - 更新通知

### 桌面端

使用 ntfy Web UI 或安装浏览器扩展。

## 🔧 服务集成

### Alertmanager 集成

Alertmanager 已配置自动将告警推送到 ntfy：

```yaml
# config/alertmanager/alertmanager.yml
receivers:
  - name: default
    webhook_configs:
      - url: 'https://ntfy.${DOMAIN}/homelab-alerts'
        send_resolved: true
```

**订阅告警：**
```bash
ntfy sub homelab-alerts
```

或使用 WebSocket：
```bash
ntfy sub -wss homelab-alerts
```

---

### Watchtower 集成

在 `.env` 中配置 Watchtower 通知：

```bash
# .env
WATCHTOWER_NOTIFICATION_URL=ntfy://homelab-updates
# 或使用自定义主题
WATCHTOWER_NOTIFICATION_URL=ntfy://your-topic
```

或者在 docker-compose.yml 中：

```yaml
services:
  watchtower:
    image: containrrr/watchtower:latest
    environment:
      - WATCHTOWER_NOTIFICATION_URL=ntfy://homelab-updates
      - WATCHTOWER_NOTIFICATION_TYPE=ntfy
```

---

### Gitea Webhook 集成

1. 进入 Gitea 管理后台 → Webhooks
2. 添加新 Webhook：
   - **URL**: `https://ntfy.${DOMAIN}/your-topic`
   - **HTTP Method**: POST
   - **Content Type**: application/json
3. 自定义 JSON payload：

```json
{
  "topic": "homelab-gitea",
  "title": "{{.repo.name}}",
  "message": "{{.commits.[0].message}}",
  "priority": "high"
}
```

---

### Home Assistant 集成

在 `configuration.yaml` 中添加 ntfy 通知服务：

```yaml
notify:
  - name: ntfy
    platform: ntfy
    host: https://ntfy.${DOMAIN}
    topic: homelab-homeassistant
```

使用示例：

```yaml
automation:
  - alias: 门铃通知
    trigger:
      - platform: state
        entity_id: binary_sensor.doorbell
    action:
      - service: notify.ntfy
        data:
          title: "门铃"
          message: "有人按门铃！"
          data:
            priority: high
            tags: bell,door
```

---

### Uptime Kuma 集成

1. 进入 Uptime Kuma 设置 → Notification
2. 添加新通知：
   - **Notification Name**: ntfy
   - **ntfy Server URL**: `https://ntfy.sh` 或 your self-hosted ntfy
   - **Topic**: `homelab-status`
3. 保存并测试

---

### Apprise 集成

Apprise 支持 80+ 通知服务，使用 REST API 发送：

```bash
# 发送通知
curl -X POST https://apprise.${DOMAIN} \
  -H "Content-Type: application/json" \
  -d '{
    "targets": ["ntfy://homelab"],
    "body": "Test message",
    "title": "Alert"
  }'
```

支持的 targets：
- `ntfy://` - ntfy
- `gotify://` - Gotify
- `telegram://` - Telegram
- `discord://` - Discord
- `slack://` - Slack
- 等等...

---

## 📜 统一通知脚本

使用 `scripts/notify.sh` 发送通知：

```bash
# 基本用法
./scripts/notify.sh <topic> <title> <message> [priority]

# 示例
./scripts/notify.sh homelab "Test" "Hello World"
./scripts/notify.sh homelab-alerts "Critical Alert" "Server down!" emergency
```

**优先级：**
- `low` (-1)
- `default` (0)
- `high` (1)
- `max` (2)
- `emergency` (3)

**环境变量：**
```bash
NTFY_URL=https://ntfy.sh          # ntfy 服务器 (默认: https://ntfy.sh)
GOTIFY_URL=http://gotify:80       # Gotify 服务器
GOTIFY_TOKEN=xxx                  # Gotify App Token
```

---

## 🔐 安全性

### ntfy 认证

配置文件 `config/ntfy/server.yml` 中：
- `auth-default-access: deny-all` - 默认拒绝所有访问
- 用户需登录后才能订阅/发布

创建用户：
```bash
docker exec ntfy ntfy user add username password
```

### Gotify 安全

默认用户：`admin`
密码：在 `.env` 中设置 `GOTIFY_PASSWORD`

首次登录后建议：
1. 创建专用 App
2. 使用 App Token 而非 admin 凭证
3. 在 `.env` 中设置 `GOTIFY_TOKEN=your_app_token`

---

## 🧪 测试

### 测试 ntfy

```bash
# 使用 notify.sh 脚本
./scripts/notify.sh homelab-test "Test" "Hello from Homelab!" default

# 直接使用 curl
curl -d "Test message" ntfy.sh/homelab-test

# 带优先级
curl -H "Priority: high" -d "Urgent!" ntfy.sh/homelab-test
```

### 测试 Gotify

```bash
# 使用 Gotify Web UI
# 访问 https://gotify.${DOMAIN}
# 创建 App，获取 Token

# 测试 API
curl -X POST "http://gotify:80/message?token=YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"title":"Test","message":"Hello!","priority":5}'
```

---

## 📁 目录结构

```
stacks/notifications/
├── docker-compose.yml      # 服务定义
├── config/
│   └── ntfy/
│       └── server.yml      # ntfy 服务器配置
└── README.md               # 本文档
```

---

## 🔗 相关链接

- [ntfy 官方文档](https://ntfy.sh/docs/)
- [Gotify 官方文档](https://gotify.net/docs)
- [Apprise GitHub](https://github.com/caronc/apprise)
- [ntfy Android App](https://play.google.com/store/apps/details/io.heckel.ntfy)
- [ntfy iOS App](https://apps.apple.com/us/app/ntfy/id1629565661)

---

**赏金**: $80 USDT  
**Issue**: https://github.com/illbnm/homelab-stack/issues/13