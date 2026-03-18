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
# NTFY_AUTH_ENABLED=true

# 3. 启动通知栈
docker compose -f stacks/notifications/docker-compose.yml up -d

# 4. 创建 ntfy 用户（首次）
docker exec ntfy ntfy user add --role=admin admin

# 5. 创建 ntfy access token
docker exec ntfy ntfy token add admin

# 6. 测试推送
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
| 5 | 紧急 | urgent | 10 |

**示例:**

```bash
# 普通通知
./scripts/notify.sh homelab-updates "Watchtower" "nginx updated to 1.25"

# 高优先级告警
./scripts/notify.sh homelab-alerts "Disk Full" "Root partition at 95%" 4

# 紧急告警
./scripts/notify.sh homelab-critical "Service Down" "PostgreSQL is unreachable" 5
```

**Fallback 机制:** ntfy 发送失败时自动切换到 Gotify。

## 环境变量

在 `.env` 中配置：

```bash
# 必填
GOTIFY_PASSWORD=your_secure_password

# 可选 — notify.sh 使用
NTFY_URL=https://ntfy.${DOMAIN}
NTFY_TOKEN=tk_xxxxxxxx          # ntfy access token
GOTIFY_URL=http://gotify:80
GOTIFY_TOKEN=xxxxxxxx           # Gotify application token
```

## 服务集成配置

### Alertmanager → ntfy

已在 `config/alertmanager/alertmanager.yml` 中配置：

```yaml
receivers:
  - name: ntfy
    webhook_configs:
      - url: "http://ntfy:80/homelab-alerts"
        send_resolved: true
```

Alertmanager 触发告警时，会自动通过 webhook 推送到 ntfy 的 `homelab-alerts` topic。

如果 ntfy 启用了认证，取消注释 `http_config.authorization` 部分并填入 token。

### Watchtower → ntfy

在 `stacks/base/docker-compose.yml` 的 Watchtower 服务中添加环境变量：

```yaml
services:
  watchtower:
    environment:
      - WATCHTOWER_NOTIFICATION_URL=generic+https://ntfy.${DOMAIN}/homelab-updates?auth=Bearer+${NTFY_TOKEN}
      # 或使用 notify.sh（需挂载脚本）:
      # - WATCHTOWER_NOTIFICATION_TEMPLATE={{.Title}} updated from {{.OldImage}} to {{.NewImage}}
```

**无认证模式:**

```yaml
- WATCHTOWER_NOTIFICATION_URL=generic+https://ntfy.${DOMAIN}/homelab-updates
```

### Gitea → ntfy

1. 进入 Gitea 仓库 → Settings → Webhooks → Add Webhook → Custom
2. 配置:
   - **Target URL:** `https://ntfy.${DOMAIN}/homelab-gitea`
   - **HTTP Method:** POST
   - **Content Type:** `application/json`
   - **Header:** `Authorization: Bearer ${NTFY_TOKEN}` (如启用认证)
   - **Header:** `Title: Gitea Event`
   - **Header:** `Priority: 3`
3. 选择触发事件 (Push, PR, Issue 等)

### Home Assistant → ntfy

在 `configuration.yaml` 中添加：

```yaml
notify:
  - name: ntfy_homelab
    platform: rest
    resource: https://ntfy.${DOMAIN}/homelab-ha
    method: POST_JSON
    headers:
      Authorization: !secret ntfy_token   # Bearer tk_xxx
      Priority: "3"
    data:
      topic: homelab-ha
    title_param_name: title
    message_param_name: message
```

**使用:**

```yaml
automation:
  - alias: "Motion Alert"
    trigger:
      - platform: state
        entity_id: binary_sensor.motion
        to: "on"
    action:
      - service: notify.ntfy_homelab
        data:
          title: "Motion Detected"
          message: "Motion detected in living room"
```

### Uptime Kuma → ntfy

1. 进入 Uptime Kuma → Settings → Notifications → Setup Notification
2. 选择 **ntfy**
3. 配置:
   - **Server URL:** `https://ntfy.${DOMAIN}`
   - **Topic:** `homelab-uptime`
   - **Username/Password** 或 **Access Token:** 你的 ntfy 凭证
   - **Priority:** `4` (high)
4. 点击 Test → 确认手机收到通知

## ntfy 配置说明

配置文件: `config/ntfy/server.yml`

```yaml
base-url: https://ntfy.${DOMAIN}
auth-default-access: deny-all      # 默认拒绝匿名访问
behind-proxy: true                  # Traefik 反代模式
cache-file: /var/cache/ntfy/cache.db
auth-file: /var/lib/ntfy/user.db
```

### 用户管理

```bash
# 添加管理员
docker exec ntfy ntfy user add --role=admin admin

# 添加普通用户
docker exec ntfy ntfy user add reader

# 授权 topic 访问
docker exec ntfy ntfy access reader 'homelab-*' read-only

# 生成 access token（用于 API 调用）
docker exec ntfy ntfy token add admin

# 列出用户
docker exec ntfy ntfy user list
```

## 常见问题

### ntfy 推送收不到？

1. 检查服务状态: `docker compose -f stacks/notifications/docker-compose.yml ps`
2. 检查日志: `docker logs ntfy`
3. 测试 API: `curl -d "test" https://ntfy.${DOMAIN}/homelab-test`
4. 确认手机 App 已订阅正确的 topic 和服务器

### Gotify 登录失败？

1. 确认 `.env` 中 `GOTIFY_PASSWORD` 已设置
2. 首次启动后密码不可通过环境变量修改，需进入 Web UI 修改

### Alertmanager 告警不触发？

1. 检查 Prometheus rules: `curl http://prometheus:9090/api/v1/rules`
2. 检查 Alertmanager 状态: `curl http://alertmanager:9093/api/v2/status`
3. 确认 ntfy 容器在同一 Docker network

### notify.sh 权限错误？

```bash
chmod +x scripts/notify.sh
```
