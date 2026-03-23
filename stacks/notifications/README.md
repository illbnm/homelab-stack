# Notifications Stack

统一通知中心，提供 ntfy 消息推送和 apprise 多渠道通知集成。

## 📋 服务清单

| 服务 | 镜像 | 用途 |
|------|------|------|
| ntfy | binwiederhier/ntfy:v2.11.0 | 轻量级消息推送服务 |
| apprise | caronc/apprise:v1.1.6 | 多渠道通知网关 |

## 🚀 快速开始

### 1. 依赖 Base 栈

本栈依赖 Base 栈提供的反向代理，请先完成 [Base 栈](../base/README.md) 的部署。

### 2. 启动服务

```bash
cd stacks/notifications
docker compose up -d
```

### 3. 访问 Web UI

- ntfy: https://ntfy.${DOMAIN}
- apprise: https://apprise.${DOMAIN}

## 🔔 ntfy 通知配置

ntfy 默认拒绝所有访问，需在 Web UI 中创建用户/话题或通过 API 管理权限。

### Alertmanager

在 `config/alertmanager/alertmanager.yml` 中已配置 ntfy webhook receiver：

```yaml
receivers:
  - name: default
    webhook_configs:
      - url: http://ntfy:80/alertmanager
        send_resolved: true
```

确保 Prometheus/Alertmanager 栈与 notifications 栈在同一 Docker 网络中（通过 `internal` 网络）。

### Watchtower

在 Base 栈的 `docker-compose.yml` 中配置 Watchtower 通知：

```yaml
environment:
  - WATCHTOWER_NOTIFICATIONS=ntfy
  - WATCHTOWER_NOTIFICATION_NTFY_TOPIC=watchtower
  - WATCHTOWER_NOTIFICATION_NTFY_HOST=ntfy
  - WATCHTOWER_NOTIFICATION_NTFY_PRIORITY=3
```

### Gitea

在 Gitea 的 `app.ini` 中配置 ntfy  webhook：

```ini
[webhook]
NTFY = true
NTFY_URL = http://ntfy:80/<topic>
```

### Home Assistant

在 `configuration.yaml` 中添加 ntfy 通知集成：

```yaml
notify:
  - name: ntfy
    platform: rest
    resource: http://ntfy:80/<topic>
    method: POST_JSON
    data:
      topic: <topic>
    headers:
      Content-Type: application/json
```

使用时调用 `notify.ntfy` 服务。

### Uptime Kuma

1. 进入 Uptime Kuma → **Settings** → **Notifications**
2. 点击 **Add Notification**
3. 选择 **Custom** 或 **Webhook**
4. 配置：
   - **URL**: `http://ntfy:80/<topic>`
   - **Method**: `POST`
   - **Body**: 
     ```json
     {
       "topic": "<topic>",
       "title": "{{STATUS}} - {{NAME}}",
       "message": "{{MSG}}",
       "priority": 3
     }
     ```
   - **Content Type**: `application/json`

## 📁 目录结构

```
stacks/notifications/
├── docker-compose.yml   # 服务配置
└── README.md           # 本文档

scripts/
└── notify.sh           # 命令行通知脚本

config/alertmanager/
└── alertmanager.yml    # Alertmanager 配置（含 ntfy receiver）
```

## 🔧 脚本用法

使用 `scripts/notify.sh` 发送命令行通知：

```bash
# 基本用法
./scripts/notify.sh <topic> <title> <message> [priority]

# 示例
./scripts/notify.sh homelab-test "Test" "Hello World" 3
./scripts/notify.sh alerts "Disk Full" "Server disk usage above 90%" 4

# 设置自定义 ntfy 主机
NTFY_HOST=ntfy.internal ./scripts/notify.sh test "Title" "Body"
```

## 🌐 网络说明

- **proxy** (external): 用于 Traefik 反向代理，ntfy/apprise Web UI 通过此网络暴露
- **internal** (bridge): 内部服务通信网络，仅 ntfy/apprise 可访问，其他服务通过此网络发送通知

ntfy 配置了 `--behind-proxy` 和 `--auth-default-access deny-all`，确保安全暴露 Web UI 的同时限制话题访问。
