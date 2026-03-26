# Notifications Stack

> 统一通知中心 - ntfy + Gotify + Apprise

## 服务

| 服务 | 访问地址 | 用途 |
|------|----------|------|
| ntfy | https://ntfy.${DOMAIN} | 推送通知服务，支持 MQTT |
| Gotify | https://gotify.${DOMAIN} | 备用通知网关，支持 WebSocket |
| Apprise | https://apprise.${DOMAIN} | 多平台通知聚合 |

## 快速开始

```bash
# 启动通知栈
./scripts/stack-manager.sh start notifications

# 测试通知
./scripts/notify.sh homelab "Test" "Hello from Homelab!"

# 指定优先级 (1-5)
./scripts/notify.sh homelab "Alert" "Disk space low" 5
```

## 统一通知脚本

```bash
# 发送到 ntfy (默认)
./scripts/notify.sh <topic> <title> <message> [priority]

# 显式发送到 ntfy
./scripts/notify.sh ntfy <topic> <message> [priority]

# 发送到 Gotify
./scripts/notify.sh gotify <title> <message> [priority]

# 同时发送到两个服务
./scripts/notify.sh both <topic> <title> <message> [priority]
```

### 环境变量

| 变量 | 说明 |
|------|------|
| `DOMAIN` | 基础域名 |
| `GOTIFY_TOKEN` | Gotify 应用令牌 |
| `NTFY_AUTH_ENABLED` | ntfy 认证开关 |

## 服务集成

### Alertmanager

在 `config/alertmanager/alertmanager.yml` 中添加 webhook receiver：

```yaml
route:
  group_by: ['alertname']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 12h
  receiver: 'ntfy'

receivers:
  - name: 'ntfy'
    webhook_configs:
      - url: 'https://ntfy.${DOMAIN}/homelab-alerts'
        send_resolved: true

  - name: 'gotify'
    webhook_configs:
      - url: 'https://gotify.${DOMAIN}/message'
        headers:
          X-Gotify-Key: ${GOTIFY_TOKEN}
```

### Watchtower

设置环境变量：

```bash
WATCHTOWER_NOTIFICATION_URL=ntfy://ntfy.${DOMAIN}/homelab-watchtower?priority=3
WATCHTOWER_NOTIFICATION_TYPE=ntfy
```

或在 docker-compose.base.yml 中：

```yaml
watchtower:
  environment:
    - WATCHTOWER_NOTIFICATION_URL=ntfy://ntfy.${DOMAIN}/homelab-watchtower
    - WATCHTOWER_NOTIFICATION_TYPE=ntfy
```

### Gitea Webhook

1. 进入 Gitea 管理面板 → Webhooks
2. 添加 Webhook：
   - 目标 URL: `https://ntfy.${DOMAIN}/homelab-gitea`
   - HTTP 方法: POST
   - 内容类型: application/json
3. 测试 webhook 触发

### Home Assistant

使用 ntfy integration：

```yaml
# configuration.yaml
notify:
  - name: ntfy
    platform: ntfy
    url: https://ntfy.${DOMAIN}/homelab-ha
    priority: 3
    tags:
      - homeassistant

automation:
  - alias: "Doorbell notification"
    trigger:
      - platform: mqtt
        topic: doorbell/pressed
    action:
      - service: notify.ntfy
        data:
          title: "Doorbell"
          message: "Someone is at the door!"
          data:
            priority: 4
            tags:
              - bell
```

### Uptime Kuma

1. 进入 Uptime Kuma → 设置 → 通知
2. 添加新通知：
   - 名称: ntfy
   - 通知方式: ntfy.sh
   - 服务器地址: `https://ntfy.${DOMAIN}`
   - 用户认证: 令牌
   - 令牌: (你的 ntfy 访问令牌)
   - Topic: `homelab-uptime`

### Traefik 日志告警

配合 Loki 和 Alertmanager：

```yaml
# config/loki/loki-config.yml
limits_config:
  reject_old_samples: true
  reject_old_samples_max_age: 168h

 ruler:
  alert_query_url: https://loki.${DOMAIN}/loki/api/v1/rules
```

## ntfy 移动端使用

1. 安装 ntfy App（iOS/Android）
2. 扫描二维码订阅话题：
   - 打开 https://ntfy.${DOMAIN}/homelab
   - 点击 "Subscribe" 按钮显示二维码
3. 使用 App 扫描即可订阅

## MQTT Bridge

ntfy 支持 MQTT 协议，可与其他 IoT 设备集成：

```bash
# MQTT 主题前缀
ntfy/

# 订阅示例
mosquitto_sub -h ntfy.${DOMAIN} -t "ntfy/homelab/#"
```

## 故障排除

### ntfy 无法访问

```bash
# 检查容器状态
docker ps | grep ntfy

# 查看日志
docker logs ntfy

# 检查网络
docker network ls | grep proxy
```

### 通知发送失败

1. 确认 DOMAIN 配置正确
2. 检查 Traefik 日志
3. 验证服务健康状态

### Gotify 认证问题

1. 首次登录：访问 https://gotify.${DOMAIN}，使用 `GOTIFY_PASSWORD` 登录
2. 创建应用：设置 → 插件 → 创建应用
3. 获取令牌并设置 `GOTIFY_TOKEN` 环境变量

## 镜像

| 服务 | 镜像 | 版本 |
|------|------|------|
| ntfy | binwiederhier/ntfy | v2.11.0 |
| Gotify | gotify/server | 2.5.0 |
| Apprise | caronc/apprise | v1.1.6 |
