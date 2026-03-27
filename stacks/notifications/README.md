# Notifications Stack — 统一通知中心

**赏金任务:** [BOUNTY $80] Notifications Stack — 通知服务  
**服务:** ntfy v2.11.0 + Gotify 2.5.0  
**网络:** `notifications` bridge，共享 `proxy` 给 Traefik

---

## 目录

- [快速启动](#快速启动)
- [服务说明](#服务说明)
- [统一通知脚本](#统一通知脚本)
- [服务集成](#服务集成)
  - [Alertmanager](#1-alertmanager)
  - [Watchtower](#2-watchtower)
  - [Gitea](#3-gitea-webhook)
  - [Home Assistant](#4-home-assistant)
  - [Uptime Kuma](#5-uptime-kuma)
- [验收测试](#验收测试)
- [安全建议](#安全建议)

---

## 快速启动

```bash
# 启动 notifications stack
cd stacks/notifications
docker compose up -d

# 验证服务健康
docker compose ps
curl http://localhost:80/-/health   # ntfy
curl http://localhost:80/health    # gotify
```

访问 `https://ntfy.${DOMAIN}` 进入 ntfy Web UI。

---

## 服务说明

### ntfy

| 项目 | 值 |
|------|-----|
| 镜像 | `binwiederhier/ntfy:v2.11.0` |
| Web UI | `https://ntfy.${DOMAIN}` |
| API 地址 | `https://ntfy.${DOMAIN}/${topic}` |
| 认证策略 | `deny-all`（默认拒绝，需手动授权 topic）|

**访问控制：** 默认禁止匿名访问，首次订阅 topic 后自动放行该用户。

### Gotify

| 项目 | 值 |
|------|-----|
| 镜像 | `gotify/server:2.5.0` |
| Web UI | `https://gotify.${DOMAIN}` |
| 优先级范围 | 0-10 |

Gotify 作为备用通知服务，在 ntfy 不可用时提供冗余。

---

## 统一通知脚本

所有服务统一调用 `scripts/notify.sh`，不直接调用 ntfy/Gotify API。

```bash
./scripts/notify.sh <topic> <title> <message> [priority] [backend]

# 参数说明
topic     # ntfy topic 或 gotify stream（必填）
title     # 通知标题（必填）
message   # 通知正文（必填）
priority  # 1=min 2=low 3=normal 4=high 5=urgent（默认: 3）
backend   # ntfy | gotify（默认: ntfy）
```

**示例：**

```bash
# 发送普通通知到 homelab-test topic
./scripts/notify.sh homelab-test "Test" "Hello World"

# 发送高优先级告警
./scripts/notify.sh homelab-alerts "CRITICAL" "Disk usage > 90%" 5

# 通过 Gotify 发送（备用）
./scripts/notify.sh homelab-backup "Backup Done" "All DBs backed up" 3 gotify
```

**环境变量：**

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `NTFY_BASE_URL` | `https://ntfy.${DOMAIN}` | ntfy 服务地址 |
| `GOTIFY_BASE_URL` | `https://gotify.${DOMAIN}` | Gotify 服务地址 |
| `GOTIFY_TOKEN` | `changeme` | Gotify 应用 Token |

---

## 服务集成

### 1. Alertmanager

Alertmanager 已配置自动将告警转发到 ntfy。

**当前配置：** `config/alertmanager/alertmanager.yml`

```yaml
receivers:
  - name: default
    webhook_configs:
      - url: http://ntfy:80/homelab-alerts
        send_resolved: true
```

**验证告警路由：**

```bash
# 手动触发一条 test alert
curl -X POST http://localhost:9093/api/v1/alerts \
  -H "Content-Type: application/json" \
  -d '[{
    "labels": {"alertname":"TestAlert","severity":"critical"},
    "annotations": {"summary":"Test alert from Alertmanager"}
  }]'
```

订阅 `https://ntfy.${DOMAIN}/homelab-alerts` 应立即收到通知。

---

### 2. Watchtower

Watchtower 监控容器更新并自动推送通知。

在 `.env` 中添加：

```bash
WATCHTOWER_NOTIFICATION_URL=ntfy://ntfy.${DOMAIN}/homelab-watchtower?priority=3
WATCHTOWER_NOTIFICATION_TYPE=ntfy
```

或在 `docker-compose.yml` 中直接指定：

```yaml
services:
  watchtower:
    environment:
      - WATCHTOWER_NOTIFICATION_URL=ntfy://ntfy.${DOMAIN}/homelab-watchtower?priority=3
      - WATCHTOWER_NOTIFICATION_TYPE=ntfy
```

订阅 `https://ntfy.${DOMAIN}/homelab-watchtower` 接收容器更新通知。

---

### 3. Gitea (Webhook)

Gitea 通过 Webhook 发送仓库事件（PR、Issue、Release）到 ntfy。

**Gitea Webhook 配置：**

1. 进入仓库 → Settings → Webhooks → Add Webhook → Gitea
2. 目标 URL：`https://ntfy.${DOMAIN}/homelab-gitea`
3. HTTP Method：`POST`
4. Content Type：`application/json`
5. 勾选 `Push Events`、`Pull Request Events`、`Issues Events`

**自定义 Webhook Body（可选）：**

如果 Gitea 版本不支持直接 POST 到 ntfy，使用中继脚本：

```bash
# 在 Gitea 服务器上部署中继
./scripts/notify.sh homelab-gitea \
  "Gitea Event" \
  "Repository: ${GITEA_REPO} | Event: ${GITEA_EVENT_TYPE}" \
  3
```

---

### 4. Home Assistant

Home Assistant 通过 `notify.ntfy` 集成发送通知。

在 `configuration.yaml` 中添加：

```yaml
notify:
  - name: ntfy
    platform: ntfy
    url: https://ntfy.${DOMAIN}/homelab-homeassistant
    priority: 3
```

**服务调用示例（自动化中使用）：**

```yaml
automation:
  - alias: "Front door motion alert"
    trigger:
      - platform: state
        entity_id: binary_sensor.front_door
        to: 'on'
    action:
      - service: notify.ntfy
        data:
          title: "Motion Detected"
          message: "Front door motion sensor triggered"
          data:
            priority: 4
            tags: door,robot
```

订阅 `https://ntfy.${DOMAIN}/homelab-homeassistant` 接收 Home Assistant 通知。

---

### 5. Uptime Kuma

Uptime Kuma 内置 ntfy 通知渠道。

**配置步骤：**

1. 打开 Uptime Kuma → Settings → Notifications → Add Notification
2. 选择 **Ntfy**
3. 填写配置：

| 字段 | 值 |
|------|-----|
| Ntfy Host | `https://ntfy.${DOMAIN}` |
| Topic | `homelab-uptime` |
| Priority | 3 (Normal) |
| Cooldown | 5 minutes |

4. Save

订阅 `https://ntfy.${DOMAIN}/homelab-uptime` 接收服务存活监控通知。

---

## 验收测试

```bash
# 1. ntfy Web UI 可访问
curl -s -o /dev/null -w "%{http_code}" http://localhost:80/-/health
# 预期: 200

# 2. 手机安装 ntfy App，订阅 homelab-test topic

# 3. 脚本推送测试（通过 scripts/notify.sh）
cd /home/bounty/.openclaw/workspace/homelab-stack
./scripts/notify.sh homelab-test "Test" "Hello World"
# 预期: App 收到推送通知

# 4. Alertmanager → ntfy（发送测试告警）
curl -X POST http://localhost:9093/api/v1/alerts \
  -H "Content-Type: application/json" \
  -d '[{"labels":{"alertname":"TestAlert","severity":"critical"},"annotations":{"summary":"Alertmanager test"}}]'
# 预期: homelab-alerts topic 收到通知

# 5. Watchtower（需现有 watchtower 配置，触发一次容器更新查看）
# 预期: homelab-watchtower topic 收到通知
```

---

## 安全建议

1. **ntfy 默认 deny-all**：保持默认，不开放公开订阅
2. **Topic 命名规范**：每个服务使用独立 topic（如 `homelab-alerts`），避免串扰
3. **Gotify Token**：在 `.env` 中设置强密码 `${GOTIFY_PASSWORD}`，首次登录后立即修改
4. **HTTPS**：所有外部访问强制通过 Traefik（已配置 `websecure` entrypoint）
5. **不推荐**：ntfy 不要开启 Firebase 以外的第三方云通知

---

## 维护

```bash
# 查看 ntfy 日志
docker compose logs -f ntfy

# 查看 gotify 日志
docker compose logs -f gotify

# 重启服务
docker compose restart

# 更新镜像版本（修改 docker-compose.yml 中的 tag 后）
docker compose pull && docker compose up -d
```
