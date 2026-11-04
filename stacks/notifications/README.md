# 🔔 Notifications Stack — 统一通知服务中心

本 Stack 提供基于 **ntfy** 与 **Gotify** 的私有化统一消息推送平台，配合 **Apprise** 实现向多渠道的消息中继转发，并提供统一的 CLI 调度脚本 `scripts/notify.sh`。

---

## 📦 服务清单

| 服务 | 镜像版本 | 访问入口 | 说明 |
| :--- | :--- | :--- | :--- |
| **ntfy** | `binwiederhier/ntfy:v2.11.0` | `https://ntfy.${DOMAIN}` | 主推送服务，支持 Web Push、iOS/Android App、WebSocket/SSE 订阅 |
| **Gotify** | `gotify/server:2.5.0` | `https://gotify.${DOMAIN}` | 备用自建推送服务器，轻量级 REST API 与 WebSocket |
| **Apprise** | `caronc/apprise:v1.1.6` | `https://apprise.${DOMAIN}` | 60+ 消息通道中继网关 (Telegram, Discord, Email, Pushover 等) |

---

## 🚀 启动与部署

1. 确保已在根目录配置 `.env` 文件中的 `${DOMAIN}` 及 Traefik 证书解析。
2. 启动通知服务栈：
   ```bash
   cd stacks/notifications
   docker compose up -d
   ```
3. 检查容器健康状态：
   ```bash
   docker compose ps
   ```

---

## 🛠️ 各服务集成通知配置指南

### 1. Alertmanager (监控告警)
编辑 `config/alertmanager/alertmanager.yml`：
```yaml
route:
  receiver: 'ntfy'

receivers:
  - name: 'ntfy'
    webhook_configs:
      - url: 'https://ntfy.${DOMAIN}/homelab-alerts'
        send_resolved: true
```

### 2. Watchtower (容器自动更新)
在 `stacks/base/docker-compose.yml` 的 `watchtower` 环境变量中加入：
```yaml
environment:
  - WATCHTOWER_NOTIFICATIONS=shoutrrr
  - WATCHTOWER_NOTIFICATION_URL=generic+https://ntfy.${DOMAIN}/homelab-watchtower?title=Watchtower+Update
```

### 3. Gitea (代码仓库事件)
1. 进入 Gitea 仓库管理 -> `Webhooks` -> `Add Webhook` -> 选择 `Gitea` 或 `Discord` 格式。
2. 目标 URL 填入：`https://ntfy.${DOMAIN}/homelab-gitea`。
3. 勾选触发事件（Push、Pull Request 等）。

### 4. Home Assistant (智能家居)
在 Home Assistant 的 `configuration.yaml` 中配置 rest/webhook notify：
```yaml
notify:
  - name: ntfy_alerts
    platform: rest
    resource: https://ntfy.${DOMAIN}/home-assistant
    method: POST_JSON
    data:
      title: "{{ title }}"
      message: "{{ message }}"
      priority: 3
```

### 5. Uptime Kuma (服务可用性监测)
1. 在 Uptime Kuma 界面点击 `Settings` -> `Notifications` -> `Setup Notification`。
2. Notification Type 选择 `ntfy`。
3. Server URL 填入：`https://ntfy.${DOMAIN}`。
4. Topic 填入：`uptime-kuma`。
5. Priority 设为 `Default` 或 `High`，点击 `Test` 测试推送。

---

## 📟 统一调度脚本 (`scripts/notify.sh`)

所有自动化运维脚本与 Cron 任务应统一调用 `scripts/notify.sh`：

```bash
# 赋予执行权限
chmod +x scripts/notify.sh

# 发送测试消息
./scripts/notify.sh homelab-test "测试标题" "Hello World from HomeLab!" 3

# 发送紧急故障告警 (Priority 5 = Urgent)
./scripts/notify.sh homelab-alerts "磁盘告警" "根目录使用率超过 90%！" 5
```

---

## ✅ 验收自查项

- [x] ntfy Web UI 与 Gotify Web UI 通过 HTTPS 域名正常访问
- [x] ntfy 配置文件 `config/ntfy/server.yml` 启用安全代理与身份认证
- [x] `scripts/notify.sh` 脚本经过验证且具备自动降级 (Fallback)
- [x] 所有常见自建服务 (Alertmanager, Watchtower, Gitea, HA, Uptime Kuma) 集成步骤均已验证
