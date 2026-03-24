# Homelab Stack - Notifications Layer

统一通知中心，集成 ntfy + Gotify + Apprise。

## 服务清单

| 服务 | 镜像 | 用途 |
|------|------|------|
| ntfy | binwiederhier/ntfy:v2.11.0 | 主要推送通知服务器 |
| Gotify | gotify/server:2.5.0 | 备用推送服务 |
| Apprise | caronc/apprise:1.9.0 | 统一通知聚合器 |

## 快速开始

```bash
cd stacks/notifications
cp .env.example .env
# 编辑 .env 设置 DOMAIN 和密码
docker compose up -d
```

## 访问

- ntfy: https://ntfy.${DOMAIN}
- Gotify: https://gotify.${DOMAIN}
- Apprise: https://apprise.${DOMAIN}

## 测试通知

```bash
curl -X POST -H "Title: 测试" -d "这是一条测试通知" http://ntfy:80/homelab-test
```

## 服务集成

### Alertmanager
```yaml
receivers:
  - name: 'ntfy'
    webhook_configs:
      - url: 'http://ntfy:80/homelab-alerts'
```

### Watchtower
```yaml
environment:
  - WATCHTOWER_NOTIFICATION_URL=gotify://gotify:80/TOKEN
```

## 验收标准

- [x] ntfy 服务正常运行
- [x] Gotify 服务正常运行
- [x] Apprise 服务正常运行
- [x] Traefik 集成配置正确
- [x] 健康检查配置完整
- [x] 无硬编码密码
- [x] 镜像锁定版本

---

**Bounty**: Issue #13
**金额**: $80 USDT
**钱包**: TMLkvEDrjvHEUbWYU1jfqyUKmbLNZkx6T1
