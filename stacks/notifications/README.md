# Notifications Stack

统一通知中心，支持多种通知方式和第三方服务集成。

## 服务概览

- **Gotify** - 实时推送通知服务器
- **Apprise** - 通用通知网关，支持 80+ 服务

## 快速开始

1. 复制环境配置文件：
```bash
cp .env.example .env
```

2. 编辑 `.env` 文件配置域名和密钥：
```bash
# 域名配置
GOTIFY_DOMAIN=gotify.yourdomain.com
APPRISE_DOMAIN=apprise.yourdomain.com

# Gotify 管理员密码
GOTIFY_ADMIN_PASSWORD=your_secure_password

# 数据库配置
POSTGRES_USER=notifications
POSTGRES_PASSWORD=your_db_password
POSTGRES_DB=notifications
```

3. 启动服务：
```bash
docker compose up -d
```

## 服务访问

- **Gotify**: `https://gotify.yourdomain.com`
- **Apprise API**: `https://apprise.yourdomain.com`

## Gotify 配置

### 创建应用

1. 登录 Gotify Web 界面
2. 点击 "APPS" 创建新应用
3. 记录生成的 App Token 用于发送通知
4. 创建客户端获取 Client Token 用于接收通知

### 发送测试通知

```bash
curl -X POST "https://gotify.yourdomain.com/message" \
  -H "X-Gotify-Key: APP_TOKEN_HERE" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "测试通知",
    "message": "HomeLab 通知系统正常运行",
    "priority": 5
  }'
```

### 移动客户端

下载 Gotify Android 客户端：
- F-Droid: https://f-droid.org/packages/com.github.gotify/
- GitHub Releases: https://github.com/gotify/android/releases

配置连接：
- **服务器 URL**: `https://gotify.yourdomain.com`
- **客户端令牌**: 从 Web 界面获取的 Client Token

## Apprise 配置

### 支持的服务

Apprise 支持 80+ 通知服务：
- **即时消息**: Telegram, Discord, Slack, Microsoft Teams
- **邮件**: SMTP, Gmail, Outlook
- **推送**: Pushover, Pushbullet, Ntfy
- **企业**: DingTalk, 飞书, 企业微信
- **短信**: Twilio, AWS SNS

### 配置文件示例

在 `./data/apprise/config.yml` 中配置服务：

```yaml
# Telegram 机器人
tgram://BOT_TOKEN/CHAT_ID

# Discord Webhook
discord://webhook_id/webhook_token

# 邮件通知
mailto://username:password@gmail.com?to=admin@yourdomain.com

# 企业微信
wxteams://corpid/corpsecret/agentid

# Gotify 集成
gotify://gotify.yourdomain.com/APP_TOKEN
```

### API 使用示例

发送通知到所有配置的服务：
```bash
curl -X POST "https://apprise.yourdomain.com/notify" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "系统告警",
    "body": "服务器 CPU 使用率过高",
    "type": "warning"
  }'
```

发送到指定标签的服务：
```bash
curl -X POST "https://apprise.yourdomain.com/notify/admin" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "管理员通知",
    "body": "需要立即处理的问题"
  }'
```

## 服务集成

### Docker 容器监控

使用 Watchtower 发送更新通知：
```bash
docker run -d \
  --name watchtower \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -e WATCHTOWER_NOTIFICATION_URL="gotify://gotify.yourdomain.com/APP_TOKEN" \
  containrrr/watchtower --notifications
```

### 监控告警集成

Prometheus Alertmanager webhook 配置：
```yaml
global:
  gotify_api_url: 'https://gotify.yourdomain.com/'

route:
  receiver: 'gotify'

receivers:
- name: 'gotify'
  webhook_configs:
  - url: 'https://apprise.yourdomain.com/notify'
    send_resolved: true
```

### 备份任务通知

在备份脚本中添加通知：
```bash
#!/bin/bash
backup_result=$(perform_backup.sh)

if [ $? -eq 0 ]; then
  curl -X POST "https://gotify.yourdomain.com/message" \
    -H "X-Gotify-Key: $GOTIFY_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
      "title": "备份成功",
      "message": "定时备份任务完成",
      "priority": 2
    }'
else
  curl -X POST "https://gotify.yourdomain.com/message" \
    -H "X-Gotify-Key: $GOTIFY_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
      "title": "备份失败",
      "message": "备份任务执行失败，请检查日志",
      "priority": 8
    }'
fi
```

## Webhook 示例

### GitHub Webhook

创建 GitHub Webhook 推送代码变更通知：

**Webhook URL**: `https://apprise.yourdomain.com/notify/github`

**处理脚本** (可选，使用 webhook 中间件)：
```python
from flask import Flask, request
import requests

app = Flask(__name__)

@app.route('/github', methods=['POST'])
def github_webhook():
    data = request.json

    if 'commits' in data:
        repo = data['repository']['name']
        commits = len(data['commits'])

        message = {
            "title": f"代码推送 - {repo}",
            "body": f"收到 {commits} 个新提交",
            "type": "info"
        }

        requests.post("https://apprise.yourdomain.com/notify", json=message)

    return "OK"
```

### Home Assistant 集成

在 Home Assistant `configuration.yaml` 中配置：
```yaml
notify:
  - name: gotify
    platform: rest
    resource: https://gotify.yourdomain.com/message
    method: POST
    headers:
      X-Gotify-Key: YOUR_APP_TOKEN
      Content-Type: application/json
    data:
      title: "{{ title }}"
      message: "{{ message }}"
      priority: 5
```

使用示例：
```yaml
automation:
  - alias: "门铃通知"
    trigger:
      platform: state
      entity_id: binary_sensor.doorbell
      to: 'on'
    action:
      service: notify.gotify
      data:
        title: "访客到访"
        message: "有人按响了门铃"
```

## 通知优先级

### Gotify 优先级等级

- **0**: 最低优先级，静默通知
- **2**: 低优先级，无声通知
- **4**: 正常优先级，默认声音
- **6**: 高优先级，重复提醒
- **8**: 紧急优先级，持续提醒直到确认

### 通知分类建议

```bash
# 信息类通知 (priority: 2)
- 系统启动完成
- 定时任务成功
- 用户登录

# 警告类通知 (priority: 5)
- 磁盘空间不足
- 服务重启
- 性能下降

# 错误类通知 (priority: 8)
- 服务宕机
- 备份失败
- 安全入侵
```

## 故障排除

### 常见问题

1. **无法发送通知**
   ```bash
   # 检查容器状态
   docker compose ps

   # 查看日志
   docker compose logs gotify
   docker compose logs apprise
   ```

2. **移动端连接失败**
   - 确认域名 SSL 证书有效
   - 检查防火墙端口开放
   - 验证 Client Token 正确

3. **Apprise 配置不生效**
   ```bash
   # 测试配置文件语法
   docker compose exec apprise apprise --config=/config/apprise.yml --dry-run

   # 查看支持的服务
   docker compose exec apprise apprise --details
   ```

### 调试模式

启用详细日志：
```yaml
# docker-compose.yml
environment:
  - GOTIFY_SERVER_LOGLEVEL=debug
  - APPRISE_LOG_LEVEL=debug
```

### 网络连接测试

```bash
# 测试容器间通信
docker compose exec apprise nslookup gotify

# 测试外部连接
docker compose exec apprise curl -I https://api.telegram.org

# 验证 Webhook 可达性
curl -X POST https://apprise.yourdomain.com/notify/test \
  -H "Content-Type: application/json" \
  -d '{"title": "连接测试", "body": "测试消息"}'
```

## 安全建议

1. **访问控制**
   - 使用强密码
   - 定期轮换 API Token
   - 限制网络访问来源

2. **数据保护**
   - 启用 HTTPS 传输
   - 敏感信息使用环境变量
   - 定期备份配置文件

3. **监控日志**
   - 监控异常登录
   - 记录 API 调用频率
   - 设置告警阈值

## 数据备份

```bash
#!/bin/bash
# 备份通知配置和数据

# 停止服务
docker compose down

# 备份数据目录
tar -czf notifications-backup-$(date +%Y%m%d).tar.gz \
  ./data/gotify \
  ./data/apprise \
  ./data/postgres

# 重启服务
docker compose up -d
```

## 性能调优

### 数据库优化

在 `docker-compose.yml` 中调整 PostgreSQL 配置：
```yaml
postgres:
  environment:
    - POSTGRES_INITDB_ARGS=--auth-host=scram-sha-256
  command: |
    postgres
    -c max_connections=100
    -c shared_buffers=256MB
    -c effective_cache_size=1GB
```

### Gotify 配置优化

```yaml
gotify:
  environment:
    - GOTIFY_SERVER_KEEPALIVEPERIODSECONDS=0
    - GOTIFY_SERVER_LISTENADDR=""
    - GOTIFY_SERVER_PORT=80
    - GOTIFY_SERVER_RESPONSEHEADERS="X-Custom-Header: custom-value"
