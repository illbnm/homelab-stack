# 通知服务栈 (Notifications Stack)

## 概述

统一通知中心，让 HomeLab 所有服务（Watchtower、Alertmanager、Gitea 等）都能向用户推送通知。

- **ntfy** — 主通知推送服务器（支持 iOS/Android/Web）
- **Gotify** — 备用推送服务

## 快速启动

```bash
# 1. 确保 .env 中已配置
GOTIFY_PASSWORD=<your-password>
NTFY_AUTH_ENABLED=true

# 2. 启动通知栈
./scripts/stack-manager.sh start notifications

# 3. 测试通知
./scripts/notify.sh homelab-test "Test" "Hello World" default
```

## ntfy 配置

ntfy 配置文件位于 `config/ntfy/server.yml`，默认设置：

| 配置项 | 值 | 说明 |
|--------|------|------|
| base-url | `https://ntfy.${DOMAIN}` | 访问地址 |
| auth-default-access | `deny-all` | 默认拒绝，需认证 |
| behind-proxy | `true` | Traefik 反代模式 |
| enable-attachments | `false` | 禁用附件（节省空间） |
| cache-duration | `12h` | 消息缓存时间 |

### 手机 App 推送

1. 安装 ntfy App（[iOS](https://apps.apple.com/app/ntfy/id1625395795) / [Android](https://play.google.com/store/apps/details?id=io.heckel.ntfy)）
2. 订阅主题：`https://ntfy.${DOMAIN}/homelab-alerts`
3. 如启用认证，App 中配置用户名密码

## 通知脚本

统一通知入口 `scripts/notify.sh`：

```bash
# 基本用法
./scripts/notify.sh <topic> <title> <message> [priority]

# 示例
./scripts/notify.sh homelab-alerts "Disk Warning" "Root disk at 90%" high
./scripts/notify.sh watchtower "Container Updated" "nginx upgraded to 1.27" default
```

**优先级：** `min` | `low` | `default` | `high` | `urgent`

其他脚本调用此统一接口，**不要直接调用** ntfy/Gotify API。

## 各服务集成配置

### Alertmanager

Alertmanager 已预配置 ntfy webhook（`config/alertmanager/alertmanager.yml`）：

```yaml
receivers:
  - name: ntfy
    webhook_configs:
      - url: 'http://ntfy:80/homelab-alerts'
        send_resolved: true
```

告警会自动推送到 ntfy 的 `homelab-alerts` 主题。

### Watchtower

在 Watchtower 的环境变量中配置：

```bash
WATCHTOWER_NOTIFICATIONS=shoutrrr
WATCHTOWER_NOTIFICATION_URL=ntfy://ntfy.${DOMAIN}/watchtower
```

### Gitea

在 Gitea Web UI 中添加 Webhook：

1. **管理面板** → **Webhook** → **添加 Webhook（Gitea）**
2. **目标 URL**：`https://ntfy.${DOMAIN}/gitea-events`
3. **触发事件**：选择需要的通知类型（Push、Release、Issue 等）
4. **HTTP 方法**：POST

### Home Assistant

在 `configuration.yaml` 中添加：

```yaml
notify:
  - platform: ntfy
    url: https://ntfy.${DOMAIN}
    topic: ha-notifications
    authentication: basic
    username: <ntfy-username>
    password: <ntfy-password>
```

### Uptime Kuma

1. **Settings** → **Notifications** → **添加通知**
2. **通知类型**：ntfy
3. **ntfy 主题 URL**：`https://ntfy.${DOMAIN}/uptime-kuma`
4. **测试通知**验证连接

## Gotify 备用通知

Gotify 作为备用通知通道，访问地址：`https://gotify.${DOMAIN}`

首次登录后在 **Settings** → **Clients** 创建客户端 Token，填入 `.env` 的 `GOTIFY_TOKEN`。

## 端口与网络

| 服务 | 内部端口 | 外部访问 |
|------|----------|----------|
| ntfy | 80 | `ntfy.${DOMAIN}` (Traefik) |
| Gotify | 80 | `gotify.${DOMAIN}` (Traefik) |

两个服务均加入 `proxy` 网络，通过 Traefik 暴露，**不直接映射宿主机端口**。

## 健康检查

```bash
# 检查 ntfy
curl -sf https://ntfy.${DOMAIN}/v1/health

# 检查 Gotify
curl -sf https://gotify.${DOMAIN}/health
```
