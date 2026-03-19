---
name: 💰 Bounty - Notifications Stack
about: 实现通知服务栈 (ntfy, Gotify) + 统一通知路由
title: '[BOUNTY $80] Notifications Stack — 通知服务'
labels: bounty, easy
assignees: ''
---

## 赏金金额

**$80 USDT**

## 任务描述

实现统一通知中心，让所有其他服务（Watchtower、Alertmanager、Gitea 等）都能向用户推送通知。

## 服务清单

| 服务 | 镜像 | 用途 |
|------|------|------|
| ntfy | `binwiederhier/ntfy:v2.11.0` | 推送通知服务器 |
| Gotify | `gotify/server:2.5.0` | 备用推送服务 |

## 核心要求

### 1. ntfy 配置

```yaml
# config/ntfy/server.yml
base-url: https://ntfy.${DOMAIN}
auth-default-access: deny-all
behind-proxy: true
cache-file: /var/cache/ntfy/cache.db
auth-file: /var/lib/ntfy/user.db
```

### 2. 集成文档

`stacks/notifications/README.md` 必须包含以下服务的通知配置说明：

| 服务 | 配置方式 |
|------|----------|
| Alertmanager | webhook receiver 指向 ntfy |
| Watchtower | `WATCHTOWER_NOTIFICATION_URL=ntfy://...` |
| Gitea | webhook 发送到 ntfy |
| Home Assistant | ntfy notify integration |
| Uptime Kuma | ntfy notification channel |

### 3. 通知脚本

`scripts/notify.sh <topic> <title> <message> [priority]`

其他脚本调用此统一接口，不直接调用 ntfy/Gotify API。

### 4. Alertmanager 路由配置

```yaml
# config/alertmanager/alertmanager.yml
receivers:
  - name: ntfy
    webhook_configs:
      - url: 'https://ntfy.${DOMAIN}/homelab-alerts'
        send_resolved: true
```

## 验收标准

- [ ] ntfy Web UI 可访问
- [ ] 手机安装 ntfy App 可收到测试推送
- [ ] `scripts/notify.sh homelab-test "Test" "Hello World"` 成功推送
- [ ] Alertmanager 告警触发时 ntfy 收到通知
- [ ] Watchtower 更新容器后 ntfy 收到通知
- [ ] README 中所有服务集成说明完整可操作

## 认领方式

评论 "我来认领"。
