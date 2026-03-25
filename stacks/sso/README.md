# SSO Stack — Authentik Unified Authentication

基于 Authentik 的统一身份认证系统，让所有服务支持单点登录（SSO）。

## 服务架构

```
┌─────────────────────────────────────────────────────────┐
│                     SSO Stack                           │
├─────────────────────────────────────────────────────────┤
│                                                          │
│   Authentik Server                                       │
│   ├── Web UI (auth.{domain})                           │
│   ├── REST API                                          │
│   └── OIDC/SAML Provider                               │
│                                                          │
│   Authentik Worker                                       │
│   └── Background tasks (flows, policies, outposts)     │
│                                                          │
│   PostgreSQL — Authentik Database                        │
│   Redis — Cache & Queue                                  │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

## 支持的服务

| 服务 | 集成方式 | 状态 |
|------|---------|------|
| Grafana | OIDC | ✅ 原生支持 |
| Gitea | OIDC | ✅ 原生支持 |
| Nextcloud | OIDC (social login) | ✅ 原生支持 |
| Outline | OIDC | ✅ 原生支持 |
| Open WebUI | OIDC | ✅ 原生支持 |
| Portainer | OAuth2 | ✅ 原生支持 |
| Traefik (ForwardAuth) | Middleware | ✅ 支持非OIDC服务 |
| Jellyfin | Proxy拦截 | 🔜 待集成 |
| Plex | Proxy拦截 | 🔜 待集成 |

## 快速开始

### 1. 配置环境变量

```bash
cd homelab-stack
cp stacks/sso/.env.example stacks/sso/.env
nano stacks/sso/.env
```

必须配置：
```env
AUTHENTIK_DOMAIN=auth.yourdomain.com
AUTHENTIK_SECRET_KEY=$(openssl rand -base64 32)
AUTHENTIK_POSTGRES_PASSWORD=your_postgres_password
AUTHENTIK_REDIS_PASSWORD=your_redis_password
AUTHENTIK_BOOTSTRAP_EMAIL=admin@yourdomain.com
AUTHENTIK_BOOTSTRAP_PASSWORD=your_secure_password
```

### 2. 启动服务

```bash
docker compose -f stacks/sso/docker-compose.yml up -d
```

### 3. 初始化配置

```bash
# 等待约60秒让Authentik完成首次启动
sleep 60

# 运行自动配置脚本
./scripts/authentik-setup.sh
```

这个脚本会自动：
- 创建用户组（homelab-admins, homelab-users, media-users）
- 为每个服务创建OAuth2 Provider
- 为每个服务创建Application
- 输出客户端凭据

### 4. 配置各服务

脚本会输出类似这样的凭据：

```
=== Grafana Credentials ===
GRAFANA_OAUTH_CLIENT_ID=authentik-grafana-a1b2c3d4
GRAFANA_OAUTH_CLIENT_SECRET=xxxxx
Redirect URI: https://grafana.yourdomain.com/login/generic_oauth
```

将这些填入对应服务的 `.env` 文件，然后重启服务。

## 用户组

| 组 | 权限 | 说明 |
|----|------|------|
| homelab-admins | 完全访问 | 管理员组，可访问所有服务的管理界面 |
| homelab-users | 标准访问 | 普通用户组，可访问常规服务 |
| media-users | 受限访问 | 仅能访问媒体服务（Jellyfin等） |

## Traefik ForwardAuth

对于不支持OIDC的服务，使用ForwardAuth中间件：

```yaml
# docker-compose.yml
labels:
  - "traefik.http.routers.service.middlewares=authentik-auth@file"
```

中间件定义在 `config/traefik/dynamic/middlewares.yml`：

| 中间件 | 说明 |
|--------|------|
| authentik-auth | 基本认证，信任ForwardHeader |
| authentik-auth-strict | 严格认证，可配合组使用 |
| rate-limit | 限流 |
| security-headers | 安全头 |

## 服务OIDC配置

### Grafana

```ini
# grafana.ini
[auth.generic_oauth]
enabled = true
name = Authentik
icon = signin
scopes = openid profile email groups
auth_url = https://auth.yourdomain.com/application/o/authorize/
token_url = https://auth.yourdomain.com/application/o/token/
api_url = https://auth.yourdomain.com/application/o/userinfo/

[auth]
disable_login_form = true
auto_login = true
```

### Gitea

```env
OAUTH2_ENABLED=true
OAUTH2_CLIENT_ID=your_client_id
OAUTH2_CLIENT_SECRET=your_client_secret
OAUTH2_AUTO_DISCOVERY=true
OAUTH2_AUTH_URL=https://auth.yourdomain.com/application/o/authorize/
OAUTH2_TOKEN_URL=https://auth.yourdomain.com/application/o/token/
OAUTH2_PROFILE_URL=https://auth.yourdomain.com/application/o/userinfo/
OAUTH2_EMAIL_URL=https://auth.yourdomain.com/application/o/userinfo/
```

### Nextcloud

安装OIDC Login App后配置：

```env
OIDC_LOGIN_ENABLED=true
OIDC_LOGIN_CLIENT_ID=your_client_id
OIDC_LOGIN_CLIENT_SECRET=your_client_secret
OIDC_LOGIN_ISSUER=https://auth.yourdomain.com/application/o/authentik/
OIDC_LOGIN_REDIRECT_URL=https://nextcloud.yourdomain.com/apps/oidc_login/oidc/callback
```

### Outline

```env
AUTH_OIDC_ENABLED=true
AUTH_OIDC_ISSUER_URL=https://auth.yourdomain.com/application/o/authentik/
AUTH_OIDC_CLIENT_ID=your_client_id
AUTH_OIDC_CLIENT_SECRET=your_client_secret
AUTH_OIDC_CALLBACK_URL=https://outline.yourdomain.com/auth/oidc.Authentik/callback
```

### Open WebUI

```env
OAUTH_ENABLED=true
OAUTH_CLIENT_ID=your_client_id
OAUTH_CLIENT_SECRET=your_client_secret
OAUTH_AUTHORIZATION_ENDPOINT=https://auth.yourdomain.com/application/o/authorize/
OAUTH_TOKEN_ENDPOINT=https://auth.yourdomain.com/application/o/token/
OAUTH_USERINFO_ENDPOINT=https://auth.yourdomain.com/application/o/userinfo/
```

### Portainer

```env
AUTHENTIK_URL=https://auth.yourdomain.com
OAUTH_CLIENT_ID=your_client_id
OAUTH_CLIENT_SECRET=your_client_secret
OAUTH_REDIRECT_URI=https://portainer.yourdomain.com/oauth2/callback
OAUTH_SCOPES=openid profile email groups
```

## 新增服务接入Authentik

1. **创建Provider**（通过Authentik UI或API）

2. **配置服务**（参考上文章节）

3. **创建Application**（关联Provider）

4. **设置组权限**（可选）

## 故障排除

### Authentik登录无响应

```bash
# 检查服务状态
docker compose -f stacks/sso/docker-compose.yml ps

# 查看日志
docker compose -f stacks/sso/docker-compose.yml logs authentik-server
docker compose -f stacks/sso/docker-compose.yml logs authentik-worker
```

### OAuth登录失败

1. 确认Redirect URI与Provider配置完全匹配
2. 检查客户端时区和时间是否正确
3. 查看Authentik日志中的详细错误

### ForwardAuth不工作

1. 确认中间件配置已加载
2. 检查Traefik动态配置路径
3. 确认服务与Authentik在同一网络

## 相关文档

- [Authentik 官方文档](https://goauthentik.io/docs/)
- [Authentik OIDC配置](https://goauthentik.io/docs/providers/oauth2/)
- [Authentik Outpost](https://goauthentik.io/docs/outposts/)
- [Traefik ForwardAuth](https://doc.traefik.io/traefik/middlewares/http/forwardauth/)
