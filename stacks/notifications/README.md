# Notifications Stack

统一通知中心，让所有其他服务（Watchtower、Alertmanager、Gitea 等）都能向用户推送通知。

## 服务清单

| 服务 | 镜像 | 端口 | 用途 |
|------|------|------|------|
| ntfy | binwiederhier/ntfy:v2.11.0 | 8076 | 推送通知服务器 |
| Gotify | gotify/server:2.5.0 | 8077 | 备用推送服务 |

## 快速开始

### 1. 环境配置

在 `.env` 文件中添加以下配置：

```bash
# Notifications
GOTIFY_PASSWORD=your_secure_password
NTFY_AUTH_ENABLED=true
```

### 2. 启动服务

```bash
# 启动 notifications stack
docker compose -f stacks/notifications/docker-compose.yml up -d

# 查看日志
docker compose -f stacks/notifications/docker-compose.yml logs -f
```

### 3. 访问 Web UI

- **ntfy**: http://ntfy.yourdomain.com (需要先配置 Base Infrastructure)
- **Gotify**: http://gotify.yourdomain.com

或直接访问端口：
- **ntfy**: http://localhost:8076
- **Gotify**: http://localhost:8077

## 使用方法

### 通过脚本发送通知

```bash
# 基本用法
./scripts/notify.sh <topic> <title> <message> [priority]

# 示例
./scripts/notify.sh homelab-test "Test" "Hello World"
./scripts/notify.sh homelab-alerts "Warning" "High CPU usage" "high"
./scripts/notify.sh homelab-alerts "Alert" "Disk space low" "urgent"
```

### 优先级

| 优先级 | 值 | 说明 |
|--------|-----|------|
| low | 1 | 低优先级 |
| medium | 2 | 中等优先级（默认）|
| high | 3 | 高优先级 |
| urgent | 4 | 紧急 |
| max | 5 | 最高 |

### 通过 ntfy App 订阅

1. 下载 ntfy App（iOS/Android）
2. 添加服务器：http://ntfy.yourdomain.com 或使用自托管版本
3. 订阅 topic 即可接收推送

## 服务集成

### Alertmanager

在 `config/alertmanager/alertmanager.yml` 中添加：

```yaml
receivers:
  - name: 'ntfy'
    webhook_configs:
      - url: 'http://ntfy:8076/homelab-alerts'
        send_resolved: true

route:
  group_by: ['alertname']
  receiver: 'ntfy'
```

### Watchtower

```bash
# 通过环境变量配置
WATCHTOWER_NOTIFICATION_URL=ntfy://homelab-watchtower?priority=high
```

或者在 docker-compose 中：

```yaml
services:
  watchtower:
    environment:
      - WATCHTOWER_NOTIFICATION_URL=ntfy://homelab-watchtower?priority=high
```

### Gitea Webhook

1. 登录 Gitea
2. 进入仓库设置 → Webhooks
3. 添加新 webhook：
   - URL: `http://ntfy:8076/gitea`
   - Content Type: application/json

### Home Assistant

在 `configuration.yaml` 中添加：

```yaml
notify:
  - name: ntfy
    platform: ntfy
    host: http://ntfy:8076
    topic: home-assistant
```

### Uptime Kuma

1. 进入 Uptime Kuma 设置 → Notifications
2. 添加 ntfy 通知：
   - URL: `http://ntfy:8076/uptime-kuma`
   - Priority: High

## 故障排除

### ntfy 无法发送推送

1. 检查 ntfy 服务是否正常运行：
   ```bash
   docker ps | grep ntfy
   docker logs ntfy
   ```

2. 检查配置文件是否正确挂载：
   ```bash
   docker exec ntfy cat /config/server.yml
   ```

3. 测试直接发送：
   ```bash
   curl -d "test message" http://localhost:8076/test
   ```

### Gotify 无法登录

1. 检查环境变量 `GOTIFY_PASSWORD` 是否设置
2. 默认用户名：`admin`
3. 如果忘记密码，需要重新创建容器

### Traefik 无法发现服务

确保创建了 proxy 网络：

```bash
docker network create proxy 2>/dev/null || true
```

确保服务有正确的 labels：

```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.ntfy.rule=Host(`ntfy.${DOMAIN}`)"
```

## 配置详解

### ntfy 配置 (config/ntfy/server.yml)

```yaml
# 基础 URL
base-url: https://ntfy.yourdomain.com

# 认证策略
auth-default-access: deny-all  # 默认拒绝所有访问，需要用户手动授权

# 代理模式
behind-proxy: true

# 缓存设置
cache-file: /var/cache/ntfy/cache.db
cache-duration: 30m
```

### 环境变量

| 变量 | 默认值 | 说明 |
|------|--------|------|
| DOMAIN | - | 你的域名 |
| TZ | Asia/Shanghai | 时区 |
| GOTIFY_PASSWORD | admin | Gotify 管理员密码 |
| NTFY_AUTH_ENABLED | true | 启用 ntfy 认证 |

## 安全建议

1. **ntfy 认证**: 建议保持 `auth-default-access: deny-all`，并为每个应用创建独立用户
2. **HTTPS**: 通过 Traefik 配置 HTTPS，使用 Let's Encrypt 自动签发证书
3. **访问控制**: 使用 ntfy 的内置用户管理限制 topic 访问
4. **Gotify 密码**: 使用强密码并定期更换

## 相关链接

- [ntfy 官方文档](https://ntfy.sh/docs/)
- [Gotify 官方文档](https://gotify.net/docs)
- [HomeLab Stack 主项目](https://github.com/illbnm/homelab-stack)
