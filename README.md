# Homelab Stack - Notifications Layer

统一通知中心，集成 ntfy + Gotify + Apprise，为所有 Homelab 服务提供一致的通知体验。

## 服务清单

| 服务 | 镜像 | 用途 | 端口 |
|------|------|------|------|
| ntfy | binwiederhier/ntfy:v2.11.0 | 主要推送通知服务器 | 80 |
| Gotify | gotify/server:2.5.0 | 备用推送服务 | 80 |
| Apprise | caronc/apprise:1.9.0 | 统一通知聚合器 | 8000 |

## 快速开始

### 1. 配置环境变量

```bash
cd /path/to/homelab-notifications
cp .env.example .env
# 编辑 .env 文件，设置 DOMAIN 和所有密码
```

### 2. 启动服务

```bash
docker compose up -d
```

### 3. 验证健康状态

```bash
docker compose ps
# 所有服务应该显示 healthy
```

### 4. 测试通知

```bash
# 使用统一脚本
./scripts/notify.sh homelab-test "测试通知" "Hello from Homelab!"

# 或直接使用 curl
curl -X POST -H "Title: 测试" -d "这是一条测试通知" http://localhost/homelab-test
```

## 核心功能

### 1. ntfy 推送通知

**特点：**
- 支持 Web、Android、iOS 客户端
- 支持附件、动作按钮、优先级
- 支持主题订阅
- 可配置上游服务器（用于移动端推送）

**访问：**
- Web UI: https://ntfy.${DOMAIN}
- API: `curl -X POST -H "Title: 标题" -d "内容" https://ntfy.${DOMAIN}/主题`

**移动端：**
- Android: [ntfy app](https://play.google.com/store/apps/details?id=io.heckel.ntfy)
- iOS: [ntfy app](https://apps.apple.com/us/app/ntfy/id1635244160)

### 2. Gotify 推送通知

**特点：**
- 轻量级推送服务
- 支持 WebSocket 实时推送
- 支持插件扩展
- 内置 Web 界面

**访问：**
- Web UI: https://gotify.${DOMAIN}
- 默认用户：admin（首次登录需修改密码）

**移动端：**
- Android: [Gotify app](https://play.google.com/store/apps/details?id=com.github.gotify)

### 3. Apprise 通知聚合

**特点：**
- 支持 80+ 通知服务（邮件、Telegram、Discord、Slack 等）
- 统一 API 接口
- 支持标签路由

**API 使用：**
```bash
# 发送通知
curl -X POST -H "Content-Type: application/json" \
  -d '{"urls": "ntfy://ntfy:80/homelab", "title": "测试", "body": "内容"}' \
  http://localhost:8000/notify
```

## 服务集成

### Alertmanager 集成

```yaml
# alertmanager.yml
receivers:
  - name: 'ntfy'
    webhook_configs:
      - url: 'http://ntfy:80/homelab-alerts'
        send_resolved: true
```

### Watchtower 集成

```yaml
# docker-compose.yml
watchtower:
  environment:
    - WATCHTOWER_NOTIFICATION_URL=gotify://gotify:80/TOKEN_HERE
    - WATCHTOWER_NOTIFICATION_TYPES=starting,running,failed
```

### Gitea 集成

1. 进入 Gitea 管理面板
2. 添加 Webhook: `https://ntfy.${DOMAIN}/homelab-gitea`
3. 选择触发事件（Push、PR、Issue 等）

### Home Assistant 集成

```yaml
# configuration.yaml
notify:
  - name: ntfy
    platform: rest
    resource: http://ntfy:80/homelab-homeassistant
    method: POST
    headers:
      Title: "🏠 Home Assistant"
```

### Uptime Kuma 集成

1. 进入 Uptime Kuma 设置
2. 添加通知方式 → Webhook
3. URL: `http://ntfy:80/homelab-uptime`
4. 自定义内容：`{{heartbeatName}}: {{msg}}`

## 环境变量

```bash
# 域名配置
DOMAIN=your-domain.com

# ntfy 配置
NTFY_BASE_URL=https://ntfy.${DOMAIN}
NTFY_UPSTREAM_BASE_URL=  # 可选：https://ntfy.sh

# Gotify 配置
GOTIFY_ADMIN_USER=admin
GOTIFY_ADMIN_PASS=YourStrongPassword123!

# 通知脚本配置
NTFY_URL=http://ntfy:80
GOTIFY_URL=http://gotify:80
GOTIFY_TOKEN=your-gotify-token
```

## 通知脚本

`scripts/notify.sh` 提供统一的通知接口：

```bash
# 用法
./scripts/notify.sh <topic> <title> <message> [priority]

# 示例
./scripts/notify.sh homelab-alerts "服务器重启" "Homelab 服务器将于 10 分钟后重启" 4
./scripts/notify.sh homelab-backup "备份完成" "每日备份成功完成" 3
./scripts/notify.sh homelab-security "安全警告" "检测到异常登录尝试" 5
```

**优先级：**
- 1 = min（最低）
- 2 = low（低）
- 3 = default（默认）
- 4 = high（高）
- 5 = urgent（紧急）

## 健康检查

```bash
# ntfy
curl http://localhost:80/health

# Gotify
curl http://localhost:80/health

# Apprise
curl http://localhost:8000/health

# 或检查 Docker 状态
docker compose ps
```

## 备份与恢复

### ntfy 数据备份

```bash
# 备份
docker run --rm \
  -v homelab-ntfy-data:/data \
  -v $(pwd):/backup \
  alpine tar czf /backup/ntfy-data.tar.gz -C /data .

# 恢复
docker run --rm \
  -v homelab-ntfy-data:/data \
  -v $(pwd):/backup \
  alpine tar xzf /backup/ntfy-data.tar.gz -C /data
```

### Gotify 数据备份

```bash
# 备份
docker run --rm \
  -v homelab-gotify-data:/data \
  -v $(pwd):/backup \
  alpine tar czf /backup/gotify-data.tar.gz -C /data .
```

## 安全注意事项

1. **使用强密码** - 所有密码应至少 16 位
2. **启用 HTTPS** - 通过 Traefik 配置 SSL
3. **限制访问** - ntfy 默认拒绝所有访问，需配置用户
4. **定期更新** - 保持镜像版本最新
5. **Token 管理** - Gotify Token 定期轮换

## 故障排除

### ntfy 无法推送

```bash
# 检查日志
docker compose logs ntfy

# 验证配置
docker compose exec ntfy ntfy serve --config /etc/ntfy/server.yml --dry-run
```

### Gotify 连接失败

```bash
# 检查服务状态
docker compose ps gotify

# 验证 Token
curl http://localhost:80/app/settings/ -H "X-Gotify-Key: YOUR_TOKEN"
```

### Apprise 配置错误

```bash
# 验证配置文件
docker compose exec apprise apprise -c /config/apprise.yml -t "测试" -b "内容"
```

## 验收标准

- [x] ntfy 服务正常运行，可接收推送
- [x] Gotify 服务正常运行，可接收推送
- [x] Apprise 服务正常运行，可聚合通知
- [x] 统一通知脚本可用
- [x] Traefik 集成配置正确
- [x] 健康检查配置完整
- [x] README 包含所有服务集成说明
- [x] 无硬编码密码/密钥
- [x] 镜像锁定具体版本

---

**Bounty**: [Issue #13](https://github.com/illbnm/homelab-stack/issues/13)
**金额**: $80 USDT
**钱包**: TMLkvEDrjvHEUbWYU1jfqyUKmbLNZkx6T1
