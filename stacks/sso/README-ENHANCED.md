# SSO Stack — Authentik 统一身份认证 (Enhanced)

> 生产级统一身份认证平台，支持 OIDC、SAML、LDAP 协议，为所有 HomeLab 服务提供单点登录解决方案。

## 🚀 快速开始

```bash
# 1. 配置环境变量
cp .env.example .env
# 编辑 .env 文件，填充所有必需值

# 2. 生成安全密钥
export AUTHENTIK_SECRET_KEY=$(openssl rand -base64 32)
export AUTHENTIK_POSTGRES_PASSWORD=$(openssl rand -hex 16)
export AUTHENTIK_REDIS_PASSWORD=$(openssl rand -hex 16)
export AUTHENTIK_BOOTSTRAP_TOKEN=$(openssl rand -hex 32)

# 更新 .env 文件
sed -i "s|^AUTHENTIK_SECRET_KEY=.*|AUTHENTIK_SECRET_KEY=$AUTHENTIK_SECRET_KEY|" .env
sed -i "s|^AUTHENTIK_POSTGRES_PASSWORD=.*|AUTHENTIK_POSTGRES_PASSWORD=$AUTHENTIK_POSTGRES_PASSWORD|" .env
sed -i "s|^AUTHENTIK_REDIS_PASSWORD=.*|AUTHENTIK_REDIS_PASSWORD=$AUTHENTIK_REDIS_PASSWORD|" .env
sed -i "s|^AUTHENTIK_BOOTSTRAP_TOKEN=.*|AUTHENTIK_BOOTSTRAP_TOKEN=$AUTHENTIK_BOOTSTRAP_TOKEN|" .env

# 3. 启动基础架构
docker compose up -d

# 4. 等待服务健康启动 (约 60 秒)
docker compose ps

# 5. 自动配置 OIDC 提供者
../../scripts/setup-authentik-enhanced.sh

# 6. 验证安装
../../scripts/test-sso.sh
```

## 🏗️ 架构设计

```
Internet
   │
   ▼
[Traefik v3]  ← 反向代理，自动 HTTPS，Forward Auth
   │
   ├── [Authentik]     ← SSO / OIDC 提供者
   │   ├── authentik-server   ← Web UI + API + 端点
   │   ├── authentik-worker   ← 后台任务
   │   ├── postgresql        ← 数据库
   │   └── redis             ← 缓存/队列
   │
   ├── [Grafana]       ← OIDC 认证
   ├── [Gitea]         ← OIDC 认证
   ├── [Outline]       ← OIDC 认证
   ├── [Portainer]     ← OIDC 认证 + ForwardAuth
   └── [...其他服务]
```

## 📦 服务组件

| 服务 | 镜像 | 端口 | 用途 |
|------|------|------|------|
| authentik-server | `swr.cn-north-4.myhuaweicloud.com/ddn-k8s/ghcr.io/goauthentik/server:2024.8.3` | 9000/9443 | Web UI + API + OIDC 端点 |
| authentik-worker | `swr.cn-north-4.myhuaweicloud.com/ddn-k8s/ghcr.io/goauthentik/server:2024.8.3` | — | 后台任务 |
| postgresql | `postgres:16-alpine` | 5432 (内部) | Authentik 数据库 |
| redis | `redis:7-alpine` | 6379 (内部) | 会话缓存 + 任务队列 |

## 🔧 环境变量配置

### 必需变量

| 变量 | 必需 | 描述 |
|------|------|------|
| `AUTHENTIK_SECRET_KEY` | 是 | 随机密钥 — `openssl rand -base64 32` |
| `AUTHENTIK_POSTGRES_PASSWORD` | 是 | PostgreSQL 密码 |
| `AUTHENTIK_REDIS_PASSWORD` | 是 | Redis 密码 |
| `AUTHENTIK_BOOTSTRAP_EMAIL` | 是 | 初始管理员邮箱 |
| `AUTHENTIK_BOOTSTRAP_PASSWORD` | 是 | 初始管理员密码 |
| `AUTHENTIK_BOOTSTRAP_TOKEN` | 是 | API 令牌 |
| `AUTHENTIK_DOMAIN` | 是 | e.g. `auth.yourdomain.com` |

### 自动配置的 OIDC 客户端

| 服务 | 客户端 ID 变量 | 客户端密钥变量 | 回调 URL |
|------|----------------|----------------|----------|
| Grafana | `GRAFANA_OAUTH_CLIENT_ID` | `GRAFANA_OAUTH_CLIENT_SECRET` | `https://grafana.DOMAIN/login/generic_oauth` |
| Gitea | `GITEA_OAUTH_CLIENT_ID` | `GITEA_OAUTH_CLIENT_SECRET` | `https://git.DOMAIN/user/oauth2/Authentik/callback` |
| Outline | `OUTLINE_OAUTH_CLIENT_ID` | `OUTLINE_OAUTH_CLIENT_SECRET` | `https://outline.DOMAIN/auth/oidc.callback` |
| Portainer | `PORTAINER_OAUTH_CLIENT_ID` | `PORTAINER_OAUTH_CLIENT_SECRET` | `https://portainer.DOMAIN/` |

## 🛡️ 认证方式

### OIDC 认证 (推荐)

适用于支持 OAuth2 的服务。运行 setup 脚本自动创建：

```bash
# 自动创建所有 OIDC 提供者
../../scripts/setup-authentik-enhanced.sh
```

### ForwardAuth 认证

适用于没有原生 OAuth2 支持的服务。在服务的 Traefik 标签中添加：

```yaml
traefik.http.routers.<service-name>.middlewares: authentik@file
```

### 服务集成示例

#### Grafana OIDC 配置
```yaml
# 在 grafana.yml 或环境变量中
auth.oauth:
  enabled: true
  allow_sign_up: true
  client_id: ${GRAFANA_OAUTH_CLIENT_ID}
  client_secret: ${GRAFANA_OAUTH_CLIENT_SECRET}
  scopes: openid email profile
  auth_url: https://auth.DOMAIN/application/o/<slug>/authorize/
  token_url: https://auth.DOMAIN/application/o/<slug>/token/
  api_url: https://auth.DOMAIN/application/o/<slug>/userinfo/
```

#### Portainer ForwardAuth
```yaml
# 在 docker-compose.yml 中添加
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.portainer.rule=Host(`portainer.${DOMAIN}`)"
  - "traefik.http.routers.portainer.entrypoints=websecure"
  - "traefik.http.routers.portainer.middlewares=authentik@file"
```

## 🏥 健康检查

### 容器健康状态
```bash
# 检查所有容器状态
docker compose ps

# 检查 Authentik API
curl -sf https://auth.DOMAIN/-/health/ready/

# 检查 PostgreSQL
docker exec authentik-postgres pg_isready -U authentik

# 检查 Redis
docker exec authentik-redis redis-cli -a ${AUTHENTIK_REDIS_PASSWORD} ping
```

### 健康监控脚本
```bash
# 运行完整健康检查
../../scripts/monitor-sso.sh check

# 查看详细状态
../../scripts/monitor-sso.sh status

# 启动持续监控 (配合 cron)
*/5 * * * * /path/to/homelab-stack/scripts/monitor-sso.sh check >> /var/log/sso-monitor.log 2>&1
```

## 💾 备份与恢复

### 创建备份
```bash
# 手动备份
../../scripts/backup-sso.sh backup

# 自动备份 (cron 任务)
# 0 2 * * * /path/to/homelab-stack/scripts/backup-sso.sh backup
```

### 恢复备份
```bash
# 列出可用备份
../../scripts/backup-sso.sh list

# 恢复指定备份
../../scripts/backup-sso.sh restore /backup/authentik/authentik_backup_20240406_120000.tar.gz
```

### 备份策略
- **每日备份**: 保留最近 30 天
- **自动清理**: 超过保留期的备份自动删除
- **预恢复备份**: 恢复前自动创建当前数据备份

## 🧪 测试与验证

### 功能测试
```bash
# 运行完整测试套件
../../scripts/test-sso.sh all

# 仅测试基本设置
../../scripts/test-sso.sh setup

# 仅测试集成
../../scripts/test-sso.sh integration

# 仅测试安全性
../../scripts/test-sso.sh security
```

### 手动测试清单

1. **基本功能测试**
   - [ ] Authentik UI 可访问: `https://auth.DOMAIN`
   - [ ] 管理员登录: `${AUTHENTIK_BOOTSTRAP_EMAIL}`
   - [ ] 健康检查通过

2. **OIDC 集成测试**
   - [ ] Grafana 登录跳转到 Authentik
   - [ ] Gitea OAuth 回调正常
   - [ ] Outline 认证成功
   - [ ] Portainer OIDC 登录

3. **ForwardAuth 测试**
   - [ ] 受保护服务需要认证
   - [ ] 未认证用户重定向到登录页面
   - [ ] 认证后正常访问服务

4. **安全测试**
   - [ ] HSTS 头部启用
   - [ ] 安全头部正确设置
   - [ ] 密码强度符合要求
   - [ ] 敏感信息不暴露

## 🔧 故障排除

### 常见问题

#### 1. 容器启动失败
```bash
# 检查日志
docker compose logs authentik-server

# 检查环境变量
docker exec authentik-server env | grep AUTHENTIK

# 重新启动
docker compose down
docker compose up -d
```

#### 2. 数据库连接失败
```bash
# 检查 PostgreSQL 状态
docker compose logs postgresql

# 检查数据库连接
docker exec authentik-postgres psql -U authentik -d authentik -c "SELECT 1"

# 等待 PostgreSQL 初始化
sleep 30
```

#### 3. OIDC 配置错误
```bash
# 检查提供者配置
curl -H "Authorization: Bearer ${AUTHENTIK_BOOTSTRAP_TOKEN}" \
  https://auth.DOMAIN/api/v3/providers/oauth2/

# 验证回调 URL
# 确保 redirect_uris 与服务配置完全匹配
```

#### 4. ForwardAuth 循环
```bash
# 检查 Traefik 配置
docker compose logs traefik

# 验证 ForwardAuth 地址
# 确保使用内部主机名: authentik-server:9000
# 而非公开域名
```

#### 5. CN 镜像问题
```bash
# 如果 CN 镜像不可用，切换到官方镜像
sed -i 's|swr.cn-north-4.myhuaweicloud.com/ddn-k8s/ghcr.io/goauthentik/server:2024.8.3|ghcr.io/goauthentik/server:2024.8.3|' docker-compose.yml
```

### 日志查看
```bash
# 查看所有服务日志
docker compose logs -f

# 查看特定服务
docker compose logs -f authentik-server
docker compose logs -f postgresql
docker compose logs -f redis

# 实时监控
tail -f /var/log/sso-monitor.log
```

## 🚀 高级配置

### 自定义流程
```bash
# 访问 Authentik 管理界面
https://auth.DOMAIN/if/admin/

# 配置:
# 1. 用户和组管理
# 2. 应用程序
# 3. 认证流程
# 4. 策略和规则
```

### 邮件配置
```bash
# 在 Authentik UI 中配置 SMTP
# 设置发送邮件的 SMTP 服务器信息
```

### 高级安全策略
```bash
# 配置 MFA (多因素认证)
# 配置登录限制
# 配置会话超时
```

## 📊 监控与告警

### 系统监控
```bash
# 集成 Prometheus 指标
# 访问: https://auth.DOMAIN/metrics/

# 设置 Grafana 仪表板
# 配置告警规则
```

### 业务监控
```bash
# 登录失败监控
# 会话统计
# 应用使用情况
```

## 🔄 升级指南

### 版本升级
```bash
# 1. 备份当前数据
../../scripts/backup-sso.sh backup

# 2. 停止服务
docker compose down

# 3. 更新镜像
docker compose pull

# 4. 启动服务
docker compose up -d

# 5. 验证功能
../../scripts/test-sso.sh all
```

## 📚 相关文档

- [Authentik 官方文档](https://goauthentik.io/docs/)
- [OAuth2 规范](https://oauth.net/2/)
- [Traefik ForwardAuth](https://docs.goauthentik.io/docs/providers/proxy/traefik)
- [Docker Compose 参考](https://docs.docker.com/compose/)

## 🤝 贡献

欢迎提交 Issue 和 Pull Request 来改进此 SSO 实现。

## 📄 许可证

MIT License - 详见 [LICENSE](../../LICENSE)