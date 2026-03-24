# Notifications Stack — 统一通知中心

统一的推送通知服务栈，支持多种通知渠道集成。

## 服务概览

| 服务 | 用途 | Web UI |
|------|------|--------|
| **ntfy** | 主推送服务 | https://ntfy.${DOMAIN} |
| **Gotify** | 备用推送服务 | https://gotify.${DOMAIN} |
| **Apprise** | 通知网关（支持100+服务） | https://apprise.${DOMAIN} |

## 快速开始

```bash
# 1. 配置环境变量
cp .env.example .env
# 编辑 .env 设置 GOTIFY_PASSWORD

# 2. 启动服务
./scripts/stack-manager.sh start notifications

# 3. 测试通知
./scripts/notify.sh homelab-test "Test" "Hello from HomeLab Stack"
```

## ntfy 配置

### 创建用户和主题

```bash
# 进入容器
docker exec -it ntfy sh

# 创建用户
ntfy user add admin

# 创建带权限的主题
ntfy access homelab-alerts admin read-write
ntfy access homelab-alerts everyone deny

# 允许匿名读取（可选）
ntfy access homelab-alerts everyone read
```

### 客户端配置

**移动端 App:**
- [Android](https://play.google.com/store/apps/details?id=io.heckel.ntfy)
- [iOS](https://apps.apple.com/us/app/ntfy/id1625390892)

**配置服务器:**
1. 打开 App → Settings → Default server
2. 输入 `https://ntfy.${DOMAIN}`
3. 订阅主题（如 `homelab-alerts`）

## Gotify 配置

### 首次登录

1. 访问 `https://gotify.${DOMAIN}`
2. 默认账号: `admin` / 密码: `${GOTIFY_PASSWORD}`
3. 登录后立即修改密码

### 创建应用

1. 进入 Apps → Create Application
2. 输入应用名称（如 "HomeLab Alerts"）
3. 复制生成的 Token

### 客户端

- [Android](https://github.com/gotify/android/releases)
- [Web](https://gotify.${DOMAIN})

## 服务集成

### Alertmanager (Prometheus)

```yaml
# config/alertmanager/alertmanager.yml
route:
  receiver: ntfy
  
receivers:
  - name: ntfy
    webhook_configs:
      - url: 'https://ntfy.${DOMAIN}/alerts'
        send_resolved: true
        http_config:
          basic_auth:
            username: admin
            password: your_password
```

### Watchtower (容器更新通知)

```yaml
# docker-compose.yml
services:
  watchtower:
    environment:
      - WATCHTOWER_NOTIFICATION_URL=ntfy://ntfy.${DOMAIN}/watchtower
      - WATCHTOWER_NOTIFICATION_TITLE=HomeLab Update
```

或使用 Gotify:
```yaml
environment:
  - WATCHTOWER_NOTIFICATION_URL=gotify://gotify.${DOMAIN}/${GOTIFY_TOKEN}
```

### Gitea (代码推送通知)

**方式1: Webhook**
1. Gitea 仓库 → Settings → Webhooks → Add Webhook
2. 类型: Gitea
3. URL: `https://ntfy.${DOMAIN}/gitea?title={{.Repository.Name}}`
4. Secret: (可选，用于验证)

**方式2: Apprise**
```yaml
# Gitea app.ini
[webhook]
ALLOWED_HOST_LIST = ntfy.${DOMAIN}
```

### Home Assistant

```yaml
# configuration.yaml
notify:
  - name: ntfy
    platform: rest
    method: POST_JSON
    authentication: basic
    username: admin
    password: your_password
    title_param: title
    message_param: message
    resource: https://ntfy.${DOMAIN}/homeassistant
```

### Uptime Kuma

1. Uptime Kuma → Settings → Notifications → Setup Notification
2. 类型: ntfy
3. Server URL: `https://ntfy.${DOMAIN}`
4. Topic: `uptime-kuma`

### n8n (工作流自动化)

```json
{
  "nodes": [{
    "type": "n8n-nodes-base.httpRequest",
    "parameters": {
      "method": "POST",
      "url": "https://ntfy.${DOMAIN}/n8n",
      "authentication": "genericCredentialType",
      "headers": {
        "Title": "n8n Workflow Alert"
      },
      "body": "{{ $json.message }}"
    }
  }]
}
```

## 统一通知脚本

`scripts/notify.sh` 提供统一的通知接口：

```bash
# 基本用法
./scripts/notify.sh <topic> <title> <message> [priority]

# 示例
./scripts/notify.sh homelab-alerts "Server Alert" "High CPU usage" high
./scripts/notify.sh backups "Backup Complete" "Database backed up"
./scripts/notify.sh info "Update" "New version available" low
```

**优先级:**
- `low` - 低优先级（静默通知）
- `default` - 默认优先级
- `high` - 高优先级（可能触发通知声音）
- `urgent` - 紧急（必定触发通知）

## Apprise 集成示例

Apprise 支持 100+ 通知服务，通过统一 API：

```bash
# 发送到多个服务
curl -X POST https://apprise.${DOMAIN}/notify \
  -H "Content-Type: application/json" \
  -d '{
    "urls": "mailto://user:pass@gmail.com,slack://token",
    "title": "Alert",
    "body": "Something happened"
  }'
```

**支持的常用服务:**
- Email (SMTP)
- Slack
- Discord
- Telegram
- Pushover
- Pushbullet
- 等等...

## 故障排除

### ntfy 无法接收通知

```bash
# 检查服务状态
docker logs ntfy --tail 100

# 测试连接
curl -v https://ntfy.${DOMAIN}/v1/health

# 检查认证
docker exec -it ntfy ntfy user list
```

### Gotify Token 无效

```bash
# 重新生成 Token
# 1. 登录 Gotify Web UI
# 2. Apps → 选择应用 → Regenerate Token
```

### 防火墙问题

确保以下端口开放：
- 443 (HTTPS) - Traefik 入口
- 80 (HTTP) - 用于 Let's Encrypt 验证

## 安全建议

1. **启用认证**: 默认配置拒绝匿名访问
2. **限制主题权限**: 使用 `ntfy access` 控制读写权限
3. **HTTPS Only**: 通过 Traefik 强制 HTTPS
4. **定期轮换 Token**: 更新 Gotify/Apprise API Token

## 参考资料

- [ntfy 官方文档](https://ntfy.sh/docs/)
- [Gotify 文档](https://gotify.net/docs/)
- [Apprise Wiki](https://github.com/caronc/apprise/wiki)
- [Alertmanager Webhook 配置](https://prometheus.io/docs/alerting/latest/configuration/#webhook_config)