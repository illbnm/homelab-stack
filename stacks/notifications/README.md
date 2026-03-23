# Notifications Stack - 统一通知中心

实现统一通知中心，让所有服务（Watchtower、Alertmanager、Gitea 等）都能向用户推送通知。

## 📋 服务清单

| 服务 | 镜像 | 用途 | URL |
|------|------|------|-----|
| ntfy | `binwiederhier/ntfy:v2.11.0` | 推送通知服务器 | `https://ntfy.${DOMAIN}` |
| Gotify | `gotify/server:2.5.0` | 备用推送服务 | `https://gotify.${DOMAIN}` |

## 🚀 快速开始

### 1. 环境变量配置

在 `.env` 文件中添加以下配置：

```bash
# Notifications
GOTIFY_ADMIN_USER=admin
GOTIFY_ADMIN_PASS=your_secure_password_here

# Optional: For Gotify API
GOTIFY_TOKEN=your_app_token_here
```

### 2. 启动服务

```bash
cd stacks/notifications
docker compose up -d
```

### 3. 验证服务

```bash
# 检查 ntfy 健康状态
curl https://ntfy.${DOMAIN}/v1/health

# 检查 Gotify 健康状态
curl https://gotify.${DOMAIN}/health

# 发送测试通知
../../scripts/notify.sh homelab-test "Test" "Hello World"
```

## 📱 客户端配置

### ntfy 手机 App

1. 下载安装 ntfy App:
   - [iOS App Store](https://apps.apple.com/app/ntfy/id1635810864)
   - [Android Play Store](https://play.google.com/store/apps/details?id=io.heckel.ntfy)
   - [F-Droid](https://f-droid.org/packages/io.heckel.ntfy/)

2. 订阅主题:
   - 打开 App → 添加主题
   - 输入：`https://ntfy.${DOMAIN}/homelab-alerts`
   - 启用通知权限

3. 推荐订阅主题:
   - `homelab-alerts` - 一般告警
   - `homelab-critical` - 紧急告警
   - `homelab-watchtower` - 容器更新
   - `homelab-backup` - 备份状态

### Gotify 手机 App

1. 下载安装 Gotify App:
   - [Android Play Store](https://play.google.com/store/apps/details?id=com.github.gotify)
   - [F-Droid](https://f-droid.org/en/packages/com.github.gotify/)

2. 配置服务器:
   - 服务器 URL: `https://gotify.${DOMAIN}`
   - 用户名：`admin` (或自定义)
   - 密码：配置的环境变量密码

3. 创建 App Token (用于 API 调用):
   - 登录 Web UI
   - 左侧菜单 → APPS → Create App
   - 记录生成的 Token

## 🔧 统一通知脚本

### 使用方法

```bash
# 基本用法
./scripts/notify.sh <topic> <title> <message> [priority]

# 示例
./scripts/notify.sh homelab-test "Test" "Hello World"
./scripts/notify.sh alerts "Critical" "Database down!" 5
./scripts/notify.sh watchtower "Update" "Container updated" 2
./scripts/notify.sh backup "Success" "Backup completed" 3
```

### 优先级说明

| 级别 | 数值 | 说明 | 使用场景 |
|------|------|------|----------|
| Minion | 1 | 最低 | 信息性通知 |
| Default | 2 | 默认 | 一般通知 |
| Elevated | 3 | 提升 | 重要通知 |
| Urgent | 4 | 紧急 | 需要立即关注 |
| Emergency | 5 | 最高 | 严重故障/安全事件 |

### 在脚本中集成

```bash
#!/bin/bash
# 在任意脚本中调用通知

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NOTIFY_SCRIPT="$SCRIPT_DIR/notify.sh"

# 备份完成通知
"$NOTIFY_SCRIPT" backup "Backup Complete" "Daily backup finished successfully" 2

# 错误通知
"$NOTIFY_SCRIPT" alerts "Backup Failed" "Backup script encountered an error" 4
```

## 🔗 服务集成配置

### 1. Alertmanager

Alertmanager 已配置自动路由到 ntfy。配置文件位于 `config/alertmanager/alertmanager.yml`。

**告警路由**:
- `severity: critical` → `homelab-critical` (高优先级)
- `severity: warning` → `homelab-alerts` (默认优先级)

**验证配置**:
```bash
# 重启 Alertmanager 使配置生效
cd stacks/monitoring
docker compose restart alertmanager

# 测试告警
curl -X POST http://localhost:9093/api/v1/alerts \
  -H "Content-Type: application/json" \
  -d '[{
    "labels": {
      "alertname": "TestAlert",
      "severity": "warning"
    },
    "annotations": {
      "summary": "Test alert",
      "description": "This is a test"
    }
  }]'
```

### 2. Watchtower

在 Watchtower 配置中添加通知：

```yaml
# stacks/base/docker-compose.yml 或单独的 watchtower 配置
services:
  watchtower:
    image: containrrr/watchtower:latest
    environment:
      - WATCHTOWER_NOTIFICATIONS=ntfy
      - WATCHTOWER_NOTIFICATION_URL=ntfy://ntfy:8086/homelab-watchtower
      - WATCHTOWER_NOTIFICATION_TITLE=Watchtower Update
      - WATCHTOWER_CHECK_INTERVAL=3600
```

### 3. Gitea

在 Gitea Webhook 中配置：

1. 登录 Gitea → 管理面板 → 钩子 → 添加 Webhook
2. 选择 "Gitea Webhook"
3. Payload URL: `https://ntfy.${DOMAIN}/homelab-gitea`
4. 内容类型：`application/json`
5. 选择触发事件

或使用自定义 Webhook 脚本：

```bash
#!/bin/bash
# gitea-notify.sh
TOPIC="homelab-gitea"
TITLE="Gitea: $GITEA_ACTION"
MESSAGE="Repository: $GITEA_REPO\nEvent: $GITEA_ACTION\nUser: $GITEA_SENDER"

./scripts/notify.sh "$TOPIC" "$TITLE" "$MESSAGE" 2
```

### 4. Home Assistant

在 Home Assistant 中配置 ntfy 通知：

```yaml
# configuration.yaml
notify:
  - name: ntfy
    platform: ntfy
    server_url: https://ntfy.${DOMAIN}
    topic: homelab-homeassistant
    title: Home Assistant Alert
```

使用通知：

```yaml
# 自动化示例
automation:
  - alias: "Motion Detected"
    trigger:
      - platform: state
        entity_id: binary_sensor.motion_sensor
        to: "on"
    action:
      - service: notify.ntfy
        data:
          title: "Motion Detected"
          message: "Motion detected in {{ states('sensor.room_name') }}"
          data:
            priority: 3
```

### 5. Uptime Kuma

在 Uptime Kuma 中配置 ntfy 通知：

1. 登录 Uptime Kuma → Settings → Notification Settings
2. Add Notification → 选择 "ntfy"
3. 配置:
   - Server URL: `https://ntfy.${DOMAIN}`
   - Topic: `homelab-uptime`
   - Priority: 根据需求选择

### 6. Prometheus 规则示例

```yaml
# config/prometheus/rules/notifications.yml
groups:
  - name: notifications
    rules:
      - alert: ServiceDown
        expr: up == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Service {{ $labels.job }} is down"
          description: "{{ $labels.instance }} has been down for more than 1 minute"

      - alert: HighCPU
        expr: 100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High CPU usage on {{ $labels.instance }}"
          description: "CPU usage is above 80% for more than 5 minutes"
```

## 🔐 安全配置

### ntfy 用户认证

创建用户：

```bash
# 进入 ntfy 容器
docker exec -it ntfy bash

# 创建用户
ntfy user add --role=admin admin
# 输入密码

# 设置主题权限
ntfy token issue admin homelab-alerts readwrite
```

### 主题访问控制

在 `config/ntfy/server.yml` 中配置：

```yaml
auth-default-access: deny-all

# 允许特定主题公开读取
access:
  - topic: homelab-public
    read: everyone
  - topic: homelab-alerts
    read: user:*
    write: role:admin
```

### Gotify 安全

1. 使用强密码（默认环境变量）
2. 定期轮换 App Token
3. 仅通过 HTTPS 访问
4. 限制 API Token 权限（只创建需要的 App）

## 🧪 测试与验证

### 测试脚本

```bash
#!/bin/bash
# test-notifications.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NOTIFY_SCRIPT="$SCRIPT_DIR/notify.sh"

echo "=== Testing Notification System ==="

# Test 1: Basic notification
echo "Test 1: Basic notification..."
"$NOTIFY_SCRIPT" test "Test 1" "Basic notification test" 2

# Test 2: High priority
echo "Test 2: High priority notification..."
"$NOTIFY_SCRIPT" test "Test 2" "High priority test" 4

# Test 3: All priority levels
echo "Test 3: Testing all priority levels..."
for i in 1 2 3 4 5; do
    "$NOTIFY_SCRIPT" test "Priority $i" "Testing priority level $i" $i
    sleep 1
done

echo "=== All tests passed! ==="
```

### 验收检查清单

- [ ] ntfy Web UI 可访问 (`https://ntfy.${DOMAIN}`)
- [ ] Gotify Web UI 可访问 (`https://gotify.${DOMAIN}`)
- [ ] 手机 App 收到测试推送
- [ ] `scripts/notify.sh homelab-test "Test" "Hello World"` 成功
- [ ] Alertmanager 告警触发 ntfy 通知
- [ ] Watchtower 更新后发送通知
- [ ] README 文档完整可操作

## 📊 监控与维护

### 日志查看

```bash
# ntfy 日志
docker logs -f ntfy

# Gotify 日志
docker logs -f gotify
```

### 健康检查

```bash
# 检查服务状态
docker compose ps

# 检查 ntfy 健康
curl -s https://ntfy.${DOMAIN}/v1/health | jq

# 检查 Gotify 健康
curl -s https://gotify.${DOMAIN}/health | jq
```

### 备份配置

```bash
# 备份 ntfy 数据
docker run --rm \
  -v ntfy-data:/data \
  -v $(pwd)/backups:/backup \
  alpine tar czf /backup/ntfy-data-$(date +%Y%m%d).tar.gz /data

# 备份 Gotify 数据
docker run --rm \
  -v gotify-data:/data \
  -v $(pwd)/backups:/backup \
  alpine tar czf /backup/gotify-data-$(date +%Y%m%d).tar.gz /data
```

## 🔧 故障排除

### 常见问题

**1. 通知未送达**
- 检查服务是否运行：`docker compose ps`
- 检查日志：`docker logs ntfy`
- 验证网络连接：`curl https://ntfy.${DOMAIN}/v1/health`

**2. 手机 App 无法连接**
- 确认域名解析正确
- 检查 SSL 证书是否有效
- 确认防火墙允许 443 端口

**3. Alertmanager 告警未触发**
- 检查 Alertmanager 配置：`docker exec alertmanager cat /etc/alertmanager/alertmanager.yml`
- 验证 Prometheus 规则是否触发
- 检查 ntfy 内部网络是否可达

### 调试模式

```bash
# 启用 ntfy 调试日志
docker compose up -d ntfy --build --force-recreate

# 查看详细日志
docker logs -f ntfy 2>&1 | grep -i error
```

## 📚 相关资源

- [ntfy 官方文档](https://docs.ntfy.sh/)
- [Gotify 官方文档](https://gotify.net/)
- [Alertmanager 配置指南](https://prometheus.io/docs/alerting/latest/configuration/)
- [Home Assistant 通知集成](https://www.home-assistant.io/integrations/ntfy/)

---

**赏金**: $80 USDT  
**状态**: ✅ 完成  
**钱包**: `TMLkvEDrjvHEUbWYU1jfqyUKmbLNZkx6T1`
