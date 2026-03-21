# 📢 Notifications Stack — 统一通知中心

> ntfy (主) + Gotify (备) + Apprise (路由) — 让所有服务的告警都能推送到你的手机。

## 服务清单

| 服务 | 镜像 | 端口 | 用途 |
|------|------|------|------|
| **ntfy** | `binwiederhier/ntfy:v2.11.0` | 80 | 主推送通知服务器 |
| **Gotify** | `gotify/server:2.5.0` | 80 | 备用推送服务 |
| **Apprise** | `caronc/apprise:v1.1.6` | 8000 | 多渠道通知路由 |

## 快速启动

```bash
# 1. 确保 base infrastructure 已运行
docker compose -f stacks/base/docker-compose.yml up -d

# 2. 配置 .env（如未配置）
# GOTIFY_PASSWORD=your_secure_password
# NTFY_TOKEN=your_ntfy_token

# 3. 启动通知栈
docker compose -f stacks/notifications/docker-compose.yml up -d

# 4. 创建 ntfy 用户（首次）
docker exec ntfy ntfy user add --role=admin admin yourpassword

# 5. 创建 ntfy access token
docker exec ntfy ntfy token add admin yourtoken

# 6. 更新 .env 中的 NTFY_TOKEN

# 7. 测试推送
./scripts/notify.sh homelab-test "Test" "Hello World"
```

## 访问地址

| 服务 | URL |
|------|-----|
| ntfy Web UI | `https://ntfy.${DOMAIN}` |
| Gotify Web UI | `https://gotify.${DOMAIN}` |
| Apprise API | `https://apprise.${DOMAIN}` |

## 手机 App 配置

### ntfy (推荐)

1. 安装 [ntfy App](https://ntfy.sh) (Android / iOS)
2. 添加服务器: `https://ntfy.${DOMAIN}`
3. 登录你创建的用户
4. 订阅 topic: `homelab-alerts`

### Gotify (备用)

1. 安装 [Gotify App](https://gotify.net) (Android)
2. 服务器地址: `https://gotify.${DOMAIN}`
3. 使用 admin 账号登录
4. 在 Apps 页面创建 Application，获取 token

## 统一通知脚本

所有服务通过 `scripts/notify.sh` 发送通知，不直接调用 API：

```bash
./scripts/notify.sh <topic> <title> <message> [priority]
```

**Priority 级别:**

| 值 | 含义 | ntfy | Gotify |
|----|------|------|--------|
| 1 | 最低 | min | 1 |
| 2 | 低 | low | 3 |
| 3 | 默认 | default | 5 |
| 4 | 高 | high | 7 |
| 5 | 紧急 | urgent | 9 |

**示例:**

```bash
# 发送普通告警
./scripts/notify.sh homelab-alerts "Disk Full" "Root partition at 95%" 4

# 发送普通更新
./scripts/notify.sh homelab-updates "Watchtower" "nginx updated to 1.25.1"

# 发送测试消息
./scripts/notify.sh homelab-test "Test" "Hello World"
```

## 环境变量

在 `.env` 中配置以下变量：

```bash
# ntfy 配置
NTFY_TOKEN=your_ntfy_access_token

# Gotify 配置
GOTIFY_PASSWORD=your_secure_password
GOTIFY_TOKEN=your_gotify_app_token
```

## 服务集成

### Alertmanager → ntfy

Alertmanager 已配置为将告警发送到 ntfy。更新 `config/alertmanager/alertmanager.yml` 中的 ntfy webhook URL：

```yaml
receivers:
  - name: ntfy
    webhook_configs:
      - url: 'https://ntfy.${DOMAIN}/homelab-alerts'
        send_resolved: true
```

### Watchtower → ntfy

Watchtower 通过环境变量配置 ntfy 通知。在 `.env` 中添加：

```bash
WATCHTOWER_NOTIFICATION_URL=ntfy://:@ntfy.${DOMAIN}/homelab-updates?priority=3
```

### Gitea → ntfy

在 Gitea 管理面板 → Webhooks 添加新的 Webhook：

- **Payload URL**: `https://ntfy.${DOMAIN}/homelab-gitea`
- **Content Type**: `application/json`
- **Events**: 选择需要的事件

### Home Assistant → ntfy

在 `configuration.yaml` 中添加：

```yaml
notify:
  - name: ntfy
    platform: rest
    resource: https://ntfy.${DOMAIN}/homelab-homeassistant
    title: "Home Assistant"
```

### Uptime Kuma → ntfy

在 Uptime Kuma 中创建新的 Notification：

- **Notification Type**: ntfy
- **nfty Server URL**: `https://ntfy.${DOMAIN}`
- **Topic**: `homelab-uptime`
- **Priority**: 3 (default)

## ntfy 配置说明

ntfy 通过 `config/ntfy/server.yml` 配置：

- `auth-default-access: deny-all` — 默认拒绝未认证访问，需创建用户
- `behind-proxy: true` — 信任反向代理（配合 Traefik 使用）
- `visitor-limit: 30` — 防止滥用

## 故障排查

### ntfy 无法访问

1. 检查 Traefik 路由是否正确配置
2. 验证 DOMAIN 环境变量已设置
3. 检查 ntfy 容器日志: `docker logs ntfy`

### 推送失败

1. 确认 NTFY_TOKEN 已正确配置
2. 检查 ntfy 用户权限（需 admin 或 writer 角色）
3. 测试直接访问: `curl -u user:token https://ntfy.${DOMAIN}/v1/health`

### Gotify fallback 失败

1. 检查 GOTIFY_TOKEN 是否配置
2. 确认 Gotify 容器正常运行: `docker logs gotify`
3. 在 Gotify Web UI 中验证 App token 是否有效
