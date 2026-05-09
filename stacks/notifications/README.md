# Notifications Stack

统一通知中心，让所有 homelab 服务（Watchtower、Alertmanager、Gitea 等）通过 ntfy 推送通知到手机/桌面。

## 服务

| 服务 | 镜像 | 端口 | 用途 |
|------|------|------|------|
| ntfy | `binwiederhier/ntfy:v2.11.0` | 80 (内部) | 主推送通知服务 |
| Gotify | `gotify/server:2.5.0` | 80 (内部) | 备用推送服务 |
| Apprise | `caronc/apprise:v1.1.6` | 8000 | 多平台通知路由 |

## 快速开始

```bash
# 1. 创建配置目录
mkdir -p config/ntfy config/alertmanager

# 2. 启动服务
docker compose up -d

# 3. 测试推送
./scripts/notify.sh homelab-test "Test" "Hello from autarky-bot!" 3
```

## 各服务集成配置

### Watchtower
在 `docker-compose.yml` 中添加：
```yaml
watchtower:
  environment:
    - WATCHTOWER_NOTIFICATIONS=ntfy
    - WATCHTOWER_NOTIFICATION_URL=https://ntfy.${DOMAIN}/watchtower
    - WATCHTOWER_NOTIFICATION_HTTP_HEADERS=Authorization: Bearer ${NTFY_TOKEN}
```

### Alertmanager
已配置 `config/alertmanager/alertmanager.yml`，webhook receiver 指向 ntfy。
```yaml
receivers:
  - name: ntfy
    webhook_configs:
      - url: "https://ntfy.${DOMAIN}/homelab-alerts"
        send_resolved: true
```

### Gitea
1. 进入 Gitea → 仓库 → Settings → Webhooks
2. 添加 Webhook，URL: `https://ntfy.${DOMAIN}/gitea`
3. Content type: `application/json`
4. 选择触发事件

### Home Assistant
```yaml
# configuration.yaml
notify:
  - platform: rest
    name: ntfy
    resource: https://ntfy.${DOMAIN}/home-assistant
    method: POST
    headers:
      Authorization: "Bearer ${NTFY_TOKEN}"
```

### Uptime Kuma
1. Settings → Notifications → 添加
2. 类型：Webhook
3. URL: `https://ntfy.${DOMAIN}/uptime-kuma`
4. 添加 Header: `Title: {{monitorName}}`

## 通知脚本

统一接口 `scripts/notify.sh`：
```bash
./scripts/notify.sh <topic> <title> <message> [priority] [tags]
```

示例：
```bash
# 发送低级通知
./scripts/notify.sh backup "备份完成" "数据库备份成功" 2 floppy_disk

# 发送紧急告警
./scripts/notify.sh alerts "磁盘空间不足" "根分区已使用 95%" 5 warning
```

## 手机端

- **ntfy**: 安装 [ntfy App](https://ntfy.sh/) → 添加服务器 `https://ntfy.${DOMAIN}` → 订阅 topic
- **Gotify**: 安装 Gotify App → 连接服务器 `https://gotify.${DOMAIN}`

## 环境变量

| 变量 | 必填 | 说明 |
|------|------|------|
| `DOMAIN` | ✅ | 域名 |
| `TZ` | ❌ | 时区，默认 Asia/Shanghai |
| `NTFY_TOKEN` | ❌ | ntfy API token（启用认证时必填） |
| `GOTIFY_TOKEN` | ❌ | Gotify app token |
