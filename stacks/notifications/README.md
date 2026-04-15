# Notifications Stack — ntfy + Gotify + Apprise

# 通知中心 — ntfy + Gotify + Apprise 统一通知服务

---

## Architecture / 架构概览

```
                    +-----------+
                    |  Traefik  |  (HTTPS termination)
                    +-----+-----+
                          |
          +---------------+---------------+
          |               |               |
    +-----+-----+  +-----+-----+  +------+------+
    |   ntfy    |  |  Gotify   |  |   Apprise   |
    | (primary) |  | (backup)  |  |  (router)   |
    +-----+-----+  +-----+-----+  +------+------+
          |               |               |
     WebPush/App     Push/REST     Multi-channel
     UnifiedPush     Plugins       Telegram/Discord
     WebSocket       WebSocket     Slack/Email/SMS
                                   WeChat/DingTalk
```

**Priority Routing / 优先级路由:**

| Priority / 优先级 | Channels / 渠道 | Use Case / 场景 |
|---|---|---|
| Critical / 紧急 | SMS, Phone call, Pushover (emergency) | Server down, security breach / 服务器宕机, 安全事件 |
| Normal / 普通 | ntfy push, Telegram, Discord | Deployment complete, backup done / 部署完成, 备份完成 |
| Info / 信息 | Log only, ntfy low-priority | Routine updates, cron results / 例行更新, 定时任务结果 |

---

## Quick Start / 快速开始

### Prerequisites / 前置条件

- Docker & Docker Compose installed / 已安装 Docker 和 Docker Compose
- Base stack running (Traefik) / 基础栈已运行 (Traefik)
- `proxy` network created / 已创建 `proxy` 网络

### 1. Configure environment / 配置环境变量

```bash
# Copy and edit .env (if not done already)
# 复制并编辑 .env（如尚未操作）
cp .env.example .env
vim .env   # Fill in NOTIFICATIONS section / 填写 NOTIFICATIONS 部分
```

### 2. Create config directories / 创建配置目录

```bash
mkdir -p config/ntfy config/gotify config/apprise
```

### 3. Start services / 启动服务

```bash
cd stacks/notifications
docker compose up -d
```

### 4. Set up ntfy admin user / 创建 ntfy 管理员

```bash
# Create admin user / 创建管理员用户
docker exec ntfy ntfy user add --role=admin admin

# Grant read-write to all topics / 授予所有主题读写权限
docker exec ntfy ntfy access admin '*' rw

# Allow anonymous read on public topics / 允许匿名读取公共主题
docker exec ntfy ntfy access everyone 'announcements' ro
```

### 5. Verify services / 验证服务

```bash
# Check health / 检查健康状态
docker compose ps

# Test ntfy / 测试 ntfy
curl -u admin:YOUR_PASSWORD -d "Hello from homelab!" https://ntfy.yourdomain.com/test

# Test Gotify / 测试 Gotify
# Login at https://gotify.yourdomain.com, create an app token, then:
# 登录 https://gotify.yourdomain.com，创建应用 token，然后：
curl "https://gotify.yourdomain.com/message?token=APP_TOKEN" \
  -F "title=Test" -F "message=Hello from homelab!"

# Test Apprise / 测试 Apprise
curl -X POST https://apprise.yourdomain.com/notify/ \
  -d '{"urls": "ntfy://ntfy:80/test", "title": "Test", "body": "Hello!"}'
```

---

## Local Development / 本地开发

```bash
cd stacks/notifications
docker compose -f docker-compose.yml -f docker-compose.local.yml up -d

# Services available at / 服务地址：
# ntfy:    http://localhost:8090
# Gotify:  http://localhost:8091
# Apprise: http://localhost:8092
```

---

## CN Mirror / 国内镜像

For users in China, replace image references in docker-compose.yml:

国内用户，替换 docker-compose.yml 中的镜像地址：

```yaml
# ntfy
image: docker.m.daocloud.io/binwiederhier/ntfy:v2.11.0

# Gotify
image: docker.m.daocloud.io/gotify/server:2.5.0

# Apprise
image: docker.m.daocloud.io/caronc/apprise:1.9.0
```

Or set `CN_MODE=true` in `.env` and run `scripts/setup-cn-mirrors.sh`.

或在 `.env` 中设置 `CN_MODE=true` 并运行 `scripts/setup-cn-mirrors.sh`。

---

## Integration Examples / 集成示例

### AlertManager -> ntfy (Prometheus/Grafana Alerts)

Update `config/alertmanager/alertmanager.yml`:

修改 `config/alertmanager/alertmanager.yml`：

```yaml
route:
  group_by: [alertname, severity]
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 4h
  receiver: ntfy-normal
  routes:
    # Critical alerts -> ntfy high priority + Apprise multi-channel
    # 紧急告警 -> ntfy 高优先级 + Apprise 多渠道
    - match:
        severity: critical
      receiver: ntfy-critical
      continue: true
    - match:
        severity: critical
      receiver: apprise-critical

    # Warning alerts -> ntfy normal priority
    # 警告 -> ntfy 普通优先级
    - match:
        severity: warning
      receiver: ntfy-normal

    # Info -> low priority
    # 信息 -> 低优先级
    - match:
        severity: info
      receiver: ntfy-info

receivers:
  - name: ntfy-critical
    webhook_configs:
      - url: 'http://ntfy:80/alerts-critical'
        send_resolved: true
        http_config:
          basic_auth:
            username: 'alertmanager'
            password_file: '/etc/alertmanager/ntfy-password'
        # ntfy headers for priority
        # ntfy 优先级标头
        # Set via Alertmanager template or custom webhook adapter

  - name: ntfy-normal
    webhook_configs:
      - url: 'http://ntfy:80/alerts'
        send_resolved: true
        http_config:
          basic_auth:
            username: 'alertmanager'
            password_file: '/etc/alertmanager/ntfy-password'

  - name: ntfy-info
    webhook_configs:
      - url: 'http://ntfy:80/alerts-info'
        send_resolved: true

  - name: apprise-critical
    webhook_configs:
      - url: 'http://apprise:8000/notify/'
        send_resolved: true

inhibit_rules:
  - source_match:
      severity: critical
    target_match:
      severity: warning
    equal: [alertname, instance]
```

**ntfy ACL for AlertManager / 为 AlertManager 配置 ntfy 权限:**

```bash
# Create a dedicated user for AlertManager
# 为 AlertManager 创建专用用户
docker exec ntfy ntfy user add alertmanager
docker exec ntfy ntfy access alertmanager 'alerts-*' write-only
```

### GitHub / GitLab CI Webhook Relay

#### GitHub Actions -> ntfy

```yaml
# .github/workflows/deploy.yml
- name: Notify deployment
  if: always()
  run: |
    STATUS="${{ job.status }}"
    PRIORITY=$([[ "$STATUS" == "failure" ]] && echo "urgent" || echo "default")
    curl -H "Title: Deploy $STATUS - ${{ github.repository }}" \
         -H "Priority: $PRIORITY" \
         -H "Tags: $([[ "$STATUS" == "success" ]] && echo "white_check_mark" || echo "x")" \
         -H "Authorization: Bearer ${{ secrets.NTFY_TOKEN }}" \
         -d "Commit: ${{ github.sha }}\nBranch: ${{ github.ref_name }}\nActor: ${{ github.actor }}" \
         https://ntfy.yourdomain.com/ci-github
```

#### GitLab CI -> ntfy

```yaml
# .gitlab-ci.yml
notify:
  stage: .post
  script:
    - |
      curl -H "Title: Pipeline ${CI_PIPELINE_STATUS} - ${CI_PROJECT_NAME}" \
           -H "Priority: $([[ "${CI_PIPELINE_STATUS}" == "failed" ]] && echo "urgent" || echo "default")" \
           -H "Authorization: Bearer ${NTFY_TOKEN}" \
           -d "Pipeline: ${CI_PIPELINE_URL}" \
           https://ntfy.yourdomain.com/ci-gitlab
  when: always
```

#### Generic Webhook -> Apprise (multi-channel relay)

```bash
# Send to all channels tagged 'devops'
# 发送到所有标记为 'devops' 的渠道
curl -X POST https://apprise.yourdomain.com/notify/ \
  -H "Content-Type: application/json" \
  -d '{
    "tag": "devops",
    "title": "Deployment Complete",
    "body": "v2.1.0 deployed to production",
    "type": "success"
  }'
```

### Watchtower -> Apprise

In your base stack `.env`:

```bash
WATCHTOWER_NOTIFICATION_URL="http://apprise:8000/notify/?tag=homelab,updates"
```

Or configure Watchtower directly:

```yaml
# stacks/base/docker-compose.yml — watchtower service
environment:
  - WATCHTOWER_NOTIFICATIONS=shoutrrr
  - WATCHTOWER_NOTIFICATION_URL=generic+http://apprise:8000/notify/
```

---

## ntfy Topic ACL / ntfy 主题权限控制

When `NTFY_AUTH_DEFAULT_ACCESS=deny-all` (recommended for production):

当 `NTFY_AUTH_DEFAULT_ACCESS=deny-all`（生产环境推荐）：

```bash
# === User Management / 用户管理 ===

# Create admin / 创建管理员
docker exec ntfy ntfy user add --role=admin admin

# Create service accounts / 创建服务账号
docker exec ntfy ntfy user add alertmanager
docker exec ntfy ntfy user add cibot
docker exec ntfy ntfy user add watchtower

# === Topic ACL / 主题权限 ===

# Admin: full access to everything / 管理员：所有主题完全访问
docker exec ntfy ntfy access admin '*' rw

# AlertManager: write-only to alert topics / AlertManager：仅写入告警主题
docker exec ntfy ntfy access alertmanager 'alerts-*' write-only

# CI bot: write-only to CI topics / CI 机器人：仅写入 CI 主题
docker exec ntfy ntfy access cibot 'ci-*' write-only

# Everyone (anonymous): read-only on public topics / 匿名用户：仅读取公共主题
docker exec ntfy ntfy access everyone 'announcements' ro
docker exec ntfy ntfy access everyone 'status' ro

# === Token-based auth (for API/webhook) / Token 认证（API/webhook 用） ===

# Generate access token / 生成访问令牌
docker exec ntfy ntfy token add alertmanager

# Use in HTTP header / 在 HTTP 标头中使用
# Authorization: Bearer tk_xxxxxxxxxxxxxxxxxxxxxxxx

# === List current ACL / 查看当前权限 ===
docker exec ntfy ntfy access
docker exec ntfy ntfy user list
```

---

## Alert Template Examples / 告警模板示例

### ntfy with rich formatting / ntfy 富文本通知

```bash
# Markdown message with action buttons
# Markdown 消息带操作按钮
curl -H "Title: Disk Space Warning" \
     -H "Priority: high" \
     -H "Tags: warning,floppy_disk" \
     -H "Actions: view, Open Grafana, https://grafana.yourdomain.com/d/disk; \
                  http, Acknowledge, https://ntfy.yourdomain.com/alerts-ack, body=acknowledged" \
     -H "Markdown: yes" \
     -d "**Server:** homelab-01
**Disk:** /dev/sda1
**Usage:** 92%
**Free:** 8.2 GB

Action required within 24h." \
     https://ntfy.yourdomain.com/alerts
```

### Apprise multi-channel broadcast / Apprise 多渠道广播

```bash
# Send to Telegram + Discord + ntfy simultaneously
# 同时发送到 Telegram + Discord + ntfy
curl -X POST https://apprise.yourdomain.com/notify/ \
  -H "Content-Type: application/json" \
  -d '{
    "tag": "normal",
    "title": "Backup Complete",
    "body": "Daily backup finished successfully.\nSize: 2.3 GB\nDuration: 12m 34s",
    "type": "success"
  }'
```

### Gotify with priority levels / Gotify 优先级通知

```bash
# Priority: 0=min, 1-3=low, 4-7=normal, 8-10=high
# Get APP_TOKEN from Gotify web UI
# 从 Gotify 网页界面获取 APP_TOKEN
curl "https://gotify.yourdomain.com/message?token=APP_TOKEN" \
  -F "title=SSL Certificate Expiring" \
  -F "message=Certificate for *.yourdomain.com expires in 7 days" \
  -F "priority=8" \
  -F 'extras={"client::display":{"contentType":"text/markdown"}}'
```

### Homelab daily digest template / Homelab 每日摘要模板

```bash
#!/bin/bash
# scripts/daily-digest.sh — Run via cron at 09:00 daily
# 每日 09:00 通过 cron 运行

NTFY_URL="https://ntfy.yourdomain.com/homelab-digest"
NTFY_TOKEN="tk_your_token_here"

# Gather stats / 收集统计
CONTAINERS=$(docker ps --format '{{.Names}}' | wc -l)
DISK_USAGE=$(df -h / | awk 'NR==2{print $5}')
MEMORY=$(free -h | awk 'NR==2{printf "%s/%s (%.0f%%)", $3, $2, $3/$2*100}')
UPDATES=$(docker exec watchtower /watchtower --check 2>&1 | grep -c "update available" || echo 0)

curl -H "Title: Homelab Daily Digest" \
     -H "Priority: low" \
     -H "Tags: clipboard,house" \
     -H "Authorization: Bearer $NTFY_TOKEN" \
     -H "Markdown: yes" \
     -d "**Date:** $(date +%Y-%m-%d)
**Containers:** $CONTAINERS running
**Disk:** $DISK_USAGE used
**Memory:** $MEMORY
**Pending Updates:** $UPDATES

All systems nominal." \
     "$NTFY_URL"
```

---

## Environment Variables / 环境变量

| Variable | Default | Description |
|---|---|---|
| `GOTIFY_PASSWORD` | (required) | Gotify admin password / Gotify 管理员密码 |
| `GOTIFY_ADMIN_USER` | `admin` | Gotify admin username / Gotify 管理员用户名 |
| `GOTIFY_REGISTRATION` | `false` | Allow user registration / 允许用户注册 |
| `NTFY_AUTH_DEFAULT_ACCESS` | `deny-all` | Default topic access / 默认主题访问权限 |
| `NTFY_ENABLE_SIGNUP` | `false` | Allow user signup / 允许用户注册 |
| `NTFY_UPSTREAM_BASE_URL` | `https://ntfy.sh` | Upstream for iOS push relay / iOS 推送中继上游 |
| `NTFY_CACHE_DURATION` | `48h` | Message cache duration / 消息缓存时长 |
| `NTFY_ATTACHMENT_TOTAL_SIZE_LIMIT` | `1G` | Total attachment size limit / 附件总大小限制 |
| `NTFY_ATTACHMENT_FILE_SIZE_LIMIT` | `50M` | Per-file attachment limit / 单文件附件限制 |
| `APPRISE_SECRET_KEY` | (empty) | API secret for persistent config / API 持久化配置密钥 |
| `APPRISE_STATELESS_URLS` | (empty) | Pre-configured Apprise URLs / 预配置 Apprise 地址 |
| `APPRISE_WORKER_COUNT` | `1` | Apprise worker count / Apprise 工作进程数 |

---

## FAQ / 常见问题

### Q: ntfy push notifications don't work on iOS / iOS 推送不工作？

A: ntfy requires an upstream relay for iOS push (Apple Push Notification service).
Ensure `NTFY_UPSTREAM_BASE_URL=https://ntfy.sh` is set (default). This proxies push
notifications through the official ntfy.sh server for APNs delivery.

ntfy 需要上游中继来发送 iOS 推送（Apple 推送通知服务）。
确保设置了 `NTFY_UPSTREAM_BASE_URL=https://ntfy.sh`（默认值）。这会通过官方 ntfy.sh 服务器代理推送。

### Q: How to test notifications without exposing to internet / 如何在不暴露到公网的情况下测试？

A: Use the local dev override:

使用本地开发覆盖：

```bash
docker compose -f docker-compose.yml -f docker-compose.local.yml up -d
curl -d "test" http://localhost:8090/test
```

### Q: How to send notifications from other Docker containers / 其他容器如何发送通知？

A: All services on the `proxy` network can reach notification services by container name:

`proxy` 网络上的所有服务可通过容器名访问通知服务：

```bash
# From any container on the proxy network / 从 proxy 网络上的任何容器
curl -d "alert!" http://ntfy:80/my-topic
curl "http://gotify:8080/message?token=TOKEN" -F "title=Alert" -F "message=test"
curl -X POST http://apprise:8000/notify/ -d '{"urls":"ntfy://ntfy:80/test","body":"hello"}'
```

### Q: Gotify vs ntfy — which should I use / 用哪个？

A: Use both for redundancy. ntfy is the primary (supports UnifiedPush, WebPush, has
better mobile apps and richer features). Gotify is the backup with plugin support.
Apprise routes to both + external channels.

建议两者都用以实现冗余。ntfy 是主力（支持 UnifiedPush、WebPush，移动端体验更好）。
Gotify 作为备用，支持插件。Apprise 同时路由到两者及外部渠道。

### Q: How to configure Telegram notifications / 如何配置 Telegram 通知？

A: 1. Create a bot via @BotFather, get the token
   2. Get your chat ID (send a message to the bot, then check
      `https://api.telegram.org/bot<TOKEN>/getUpdates`)
   3. Add to Apprise config or use stateless URL:

```bash
# In .env
APPRISE_STATELESS_URLS=tgram://BOT_TOKEN/CHAT_ID

# Or in config/apprise/apprise.yml
urls:
  - url: tgram://BOT_TOKEN/CHAT_ID
    tag: normal, telegram
```

1. 通过 @BotFather 创建机器人，获取 token
2. 获取你的 chat ID（给机器人发消息，然后访问
   `https://api.telegram.org/bot<TOKEN>/getUpdates`）
3. 添加到 Apprise 配置或使用无状态 URL（如上）

### Q: How to configure Discord notifications / 如何配置 Discord 通知？

A: 1. In your Discord server: Server Settings -> Integrations -> Webhooks -> New Webhook
   2. Copy the webhook URL, it looks like:
      `https://discord.com/api/webhooks/WEBHOOK_ID/WEBHOOK_TOKEN`
   3. Add to Apprise:

```bash
APPRISE_STATELESS_URLS=discord://WEBHOOK_ID/WEBHOOK_TOKEN
```

### Q: Messages are not cached / 消息没有被缓存？

A: Check that the ntfy cache volume is mounted correctly and `NTFY_CACHE_DURATION`
is set. Default is 48h. Messages older than this are automatically purged.

检查 ntfy 缓存卷是否正确挂载，以及 `NTFY_CACHE_DURATION` 是否已设置。默认 48 小时。
超过此时间的消息会自动清除。

### Q: Rate limiting issues / 速率限制问题？

A: Increase `NTFY_VISITOR_REQUEST_LIMIT_BURST` in `.env` (default: 60).
For authenticated users, you can set higher limits per-user via the CLI.

在 `.env` 中增加 `NTFY_VISITOR_REQUEST_LIMIT_BURST`（默认：60）。
对于已认证用户，可以通过 CLI 为每个用户设置更高的限制。

### Q: How to backup notification data / 如何备份通知数据？

A: The Docker volumes contain all persistent data:

Docker 卷包含所有持久数据：

```bash
# Backup / 备份
docker run --rm -v ntfy-data:/data -v $(pwd):/backup alpine \
  tar czf /backup/ntfy-data-$(date +%Y%m%d).tar.gz -C /data .

docker run --rm -v gotify-data:/data -v $(pwd):/backup alpine \
  tar czf /backup/gotify-data-$(date +%Y%m%d).tar.gz -C /data .
```
