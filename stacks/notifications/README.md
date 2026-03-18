# Notifications Stack — 统一通知中心

提供可靠的多通道通知服务，支持 **ntfy** 和 **Gotify** 双后端，通过统一脚本接口集成所有服务。

---

## 🎯 功能

| 特性 | 说明 |
|------|------|
| **双通道推送** | ntfy (推荐) + Gotify (备用) |
| **统一接口** | `scripts/notify.sh` 一键调用 |
| **自动降级** | ntfy 失败自动切换到 gotify |
| **优先级支持** | low/normal/high/urgent |
| **多订阅者** | 支持多个 topic，灵活订阅 |
| **Web UI** | 通过 traefik 反代，HTTPS 访问 |

---

## 📦 服务清单

| 服务 | 镜像 | 端口 | 公网域名 |
|------|------|------|----------|
| **ntfy** | `binwiederhier/ntfy:v2.11.0` | 80 | `https://ntfy.${DOMAIN}` |
| **Gotify** | `gotify/server:2.5.0` | 80 | `https://gotify.${DOMAIN}` |

---

## 🚀 快速开始

### 1. 前置条件

- 已部署 **Base Stack** (Traefik 网络已创建)
- 已设置 `DOMAIN` 环境变量
- 已创建 `stacks/notifications/.env` 文件

### 2. 环境变量

创建 `stacks/notifications/.env`:

```bash
# 基础配置
DOMAIN=homelab.example.com
TZ=Asia/Shanghai

# ntfy 配置 (可选覆盖)
NTFY_BASE_URL=https://ntfy.${DOMAIN}

# Gotify 配置 (可选覆盖)
GOTIFY_URL=https://gotify.${DOMAIN}
```

### 3. 启动服务

```bash
cd stacks/notifications
docker compose up -d
```

### 4. 验证

```bash
# 检查容器状态
docker compose ps

# 测试通知
./scripts/notify.sh test "Test Notification" "This is a test message" high
```

---

## 🔔 使用通知脚本

### 基本语法

```bash
./scripts/notify.sh <topic> <title> <message> [priority]
```

### 示例

```bash
# 高优先级告警
./scripts/notify.sh system-alerts "🚨 Critical: Disk Full" "/dev/sda1 at 95% capacity" urgent

# 普通状态更新
./scripts/notify.sh backup-status "✅ Backup Complete" "Daily backup finished in 15m" normal

# 低优先级日志
./scripts/notify.sh housekeeping "Cleanup" "Old logs removed, freed 2GB" low
```

### 优先级映射

| 参数 | ntfy 级别 | gotify 级别 |
|------|-----------|-------------|
| `low` | min | 0 |
| `normal` (默认) | default | 5 |
| `high` | high | 10 |
| `urgent` | max | 15 |

---

## 🔗 服务集成

### Alertmanager (Prometheus 告警)

修改 `config/alertmanager/alertmanager.yml`:

```yaml
receivers:
  - name: 'ntfy'
    webhook_configs:
      - url: 'https://ntfy.${DOMAIN}/homelab-alerts'
        send_resolved: true

route:
  receiver: 'ntfy'
```

然后重启 Alertmanager:

```bash
docker compose -f stacks/observability/docker-compose.yml restart alertmanager
```

测试告警:

```bash
# 模拟一个告警
curl -XPOST http://alertmanager:9093/-/alerts -d '[{
  "labels": {
    "severity": "critical",
    "alertname": "DiskFull"
  },
  "annotations": {
    "summary": "Disk /data is full"
  }
}]'
```

### Watchtower (容器更新通知)

在 `stacks/base/.env` 中添加:

```bash
WATCHTOWER_NOTIFICATION_URL=ntfy://ntfy.${DOMAIN}/watchtower
WATCHTOWER_NOTIFICATIONS=email
# 可选: 认证信息
# WATCHTOWER_NOTIFICATION_USER=
# WATCHTOWER_NOTIFICATION_PASSWORD=
```

Watchtower 会在容器更新后自动推送通知到 ntfy topic `watchtower`。

### Gitea (代码推送)

在 Gitea 配置中 (`config/app.ini` 或环境变量):

```ini
[service]
# 启用 Webhook
START_SSH_SERVER = true

[webhook]
# 添加 ntfy 作为自定义 webhook
# URL: https://ntfy.${DOMAIN}/gitea-pushes
# 设置推送事件触发
```

或者使用 Gitea Webhook 界面:
1. 进入仓库 → Settings → Webhooks
2. Add Webhook → "Custom"
3. Target URL: `https://ntfy.${DOMAIN}/gitea-pushes`
4. 选择触发事件: Push events

### Uptime Kuma (状态监控)

Uptime Kuma 自带通知功能:
1. Settings → Notifications → Add Notification
2. Type: "NTFY"
3. URL: `https://ntfy.${DOMAIN}/uptime-kuma`
4. Topic: `uptime`
5. 保存并应用到对应监控项

---

## 📱 订阅通知

### ntfy 移动端

1. 下载 ntfy App (iOS/Android)
2. 添加服务器: `https://ntfy.${DOMAIN}`
3. 订阅 topic (例如 `homelab-alerts`, `backup-status`)

### Web 订阅

访问 `https://ntfy.${DOMAIN}`，直接在 Web 界面订阅 topic。

### Gotify

访问 `https://gotify.${DOMAIN}`，登录后:
1. 左侧 "Applications" → 创建新应用
2. 生成 client token
3. 使用 app token 订阅 topic

---

## ✅ 验收检查清单

- [ ] `docker compose up -d` 成功启动 ntfy + gotify
- [ ] 两个服务健康检查通过 (`docker compose ps`)
- [ ] Traefik 反代生效: `https://ntfy.${DOMAIN}` 可访问 Web UI
- [ ] `./scripts/notify.sh test "Test" "Hello"` 成功推送
- [ ] 手机 ntfy App 订阅后收到通知
- [ ] Alertmanager 集成测试: 触发测试告警 → 收到推送
- [ ] Watchtower 集成: 手动更新容器 → 收到 ntfy 消息
- [ ] 所有服务的集成文档完整 (见 README 各章节)

---

## 🔧 故障排除

### 通知未收到

1. 检查 ntfy/gotify 容器日志:
   ```bash
   docker compose logs -f ntfy
   docker compose logs -f gotify
   ```

2. 验证 Web access:
   ```bash
   curl -I https://ntfy.${DOMAIN}
   curl -I https://gotify.${DOMAIN}
   ```

3. 测试脚本执行:
   ```bash
   ./scripts/notify.sh debug "Test" "Debug message" high
   ```

4. 检查 topic 订阅:
   - ntfy: Web UI 中查看 "Subscriptions"
   - Gotify: Apps → 确认 client token 有效

### 认证问题

如果启用了 ntfy 认证，需在 `notify.sh` 添加:

```bash
NTFY_AUTH_USER="your_user"
NTFY_AUTH_PASS="your_pass"
```

并在 curl 命令加入 `-u "$NTFY_AUTH_USER:$NTFY_AUTH_PASS"`

---

## 🎯 设计原则

- **Zero trust**: 默认拒绝所有发布，需显式创建 topic 或订阅
- **Redundancy**: ntfy 为主，gotify 为备，自动切换
- **Simplicity**: 单一脚本接口，隐藏后端复杂度
- **Observability**: 脚本返回状态码，便于 CI 集成

---

## 📄 License

此实现遵循原 homelab-stack 项目的许可证要求。