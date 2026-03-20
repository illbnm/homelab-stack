# SSO 统一身份认证集成指南

本文档详细说明如何为 HomeLab Stack 中的所有服务配置 Authentik SSO 统一身份认证。

## 目录

1. [架构概述](#架构概述)
2. [快速开始](#快速开始)
3. [服务集成详情](#服务集成详情)
4. [用户组与权限管理](#用户组与权限管理)
5. [故障排查](#故障排查)
6. [安全最佳实践](#安全最佳实践)

## 架构概述

```
┌─────────────────────────────────────────────────────────────┐
│                        Internet                              │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                    Traefik Reverse Proxy                     │
│              (TLS Termination + ForwardAuth)                 │
└─────────────────────────────────────────────────────────────┘
                            │
            ┌───────────────┼───────────────┐
            │               │               │
            ▼               ▼               ▼
    ┌──────────────┐ ┌──────────────┐ ┌──────────────┐
    │  Authentik   │ │   Grafana    │ │    Gitea     │
    │   Server     │ │  (OIDC)      │ │   (OIDC)     │
    └──────────────┘ └──────────────┘ └──────────────┘
            │
    ┌──────────────┐
    │  PostgreSQL  │
    │    Redis     │
    └──────────────┘
```

### 认证流程

1. 用户访问受保护的服务（如 Grafana）
2. Traefik ForwardAuth 中间件拦截请求
3. 未认证用户被重定向到 Authentik 登录页面
4. 用户登录成功后，Authentik 返回 JWT token
5. Traefik 将 token 传递给后端服务
6. 服务验证 token 并允许访问

## 快速开始

### 1. 部署 SSO 栈

```bash
# 进入 SSO 目录
cd stacks/sso

# 复制并配置环境变量
cp .env.example .env
nano .env

# 生成必要密钥
export AUTHENTIK_SECRET_KEY=$(openssl rand -base64 32)
export AUTHENTIK_POSTGRES_PASSWORD=$(openssl rand -hex 16)
export AUTHENTIK_REDIS_PASSWORD=$(openssl rand -hex 16)

# 更新 .env
sed -i "s|^AUTHENTIK_SECRET_KEY=.*|AUTHENTIK_SECRET_KEY=$AUTHENTIK_SECRET_KEY|" .env
sed -i "s|^AUTHENTIK_POSTGRES_PASSWORD=.*|AUTHENTIK_POSTGRES_PASSWORD=$AUTHENTIK_POSTGRES_PASSWORD|" .env
sed -i "s|^AUTHENTIK_REDIS_PASSWORD=.*|AUTHENTIK_REDIS_PASSWORD=$AUTHENTIK_REDIS_PASSWORD|" .env

# 启动服务
docker compose up -d

# 等待服务就绪（约 60 秒）
docker compose ps
```

### 2. 获取 Authentik API Token

```bash
# 方法 1: Web UI
# 1. 访问 https://auth.DOMAIN/if/admin/
# 2. 使用管理员账号登录
# 3. Admin Interface → Tokens → Create Token
# 4. 复制生成的 token

# 方法 2: API 命令行
curl -X POST https://auth.DOMAIN/api/v3/core/tokens/ \
  -H "Content-Type: application/json" \
  -d '{"identifier":"homelab-setup","expires":"2099-12-31T23:59:59Z"}' \
  -u admin@yourdomain.com:yourpassword
```

### 3. 运行自动配置脚本

```bash
export AUTHENTIK_BOOTSTRAP_TOKEN="your-token-here"
../../scripts/setup-authentik.sh
```

脚本会输出所有服务的 OAuth 凭据：

```
[OK] Created provider: Grafana
  Client ID: xxxxx
  Client Secret: xxxxx
  Redirect URI: https://grafana.example.com/login/generic_oauth
[OK] Created provider: Gitea
...
```

### 4. 重启相关服务

```bash
# 重启所有需要 OIDC 的服务
cd stacks/monitoring && docker compose restart grafana
cd stacks/productivity && docker compose restart gitea outline bookstack
cd stacks/ai && docker compose restart open-webui
cd stacks/storage && docker compose restart nextcloud
cd stacks/base && docker compose restart portainer
```

## 服务集成详情

### Grafana

**集成方式**: 原生 Generic OAuth

**配置文件**: `stacks/monitoring/docker-compose.yml`

**环境变量**:
```yaml
GF_AUTH_GENERIC_OAUTH_ENABLED=true
GF_AUTH_GENERIC_OAUTH_NAME=Authentik
GF_AUTH_GENERIC_OAUTH_CLIENT_ID=${GRAFANA_OAUTH_CLIENT_ID}
GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET=${GRAFANA_OAUTH_CLIENT_SECRET}
GF_AUTH_GENERIC_OAUTH_SCOPES=openid profile email
GF_AUTH_GENERIC_OAUTH_AUTH_URL=https://${AUTHENTIK_DOMAIN}/application/o/authorize/
GF_AUTH_GENERIC_OAUTH_TOKEN_URL=https://${AUTHENTIK_DOMAIN}/application/o/token/
GF_AUTH_GENERIC_OAUTH_API_URL=https://${AUTHENTIK_DOMAIN}/application/o/userinfo/
GF_AUTH_GENERIC_OAUTH_ROLE_ATTRIBUTE_PATH=contains(groups, 'Grafana Admins') && 'Admin'
```

**验证**: 访问 https://grafana.DOMAIN，点击 "Sign in with Authentik"

### Gitea

**集成方式**: 原生 OpenID Connect

**配置文件**: `stacks/productivity/docker-compose.yml`

**环境变量**:
```yaml
GITEA__oauth2__CLIENT_ID=${GITEA_OAUTH_CLIENT_ID}
GITEA__oauth2__CLIENT_SECRET=${GITEA_OAUTH_CLIENT_SECRET}
GITEA__oauth2__PROVIDER=openidConnect
GITEA__oauth2__ISSUER=https://${AUTHENTIK_DOMAIN}/application/o/gitea/
GITEA__oauth2__SCOPE=openid profile email
GITEA__oauth2__GROUP_CLAIM_NAME=groups
```

**验证**: 访问 https://git.DOMAIN，点击 "Sign in with Authentik"

### Outline

**集成方式**: 原生 OIDC

**配置文件**: `stacks/productivity/docker-compose.yml`

**环境变量**:
```yaml
OIDC_CLIENT_ID=${OUTLINE_OAUTH_CLIENT_ID}
OIDC_CLIENT_SECRET=${OUTLINE_OAUTH_CLIENT_SECRET}
OIDC_AUTH_URI=https://${AUTHENTIK_DOMAIN}/application/o/authorize/
OIDC_TOKEN_URI=https://${AUTHENTIK_DOMAIN}/application/o/token/
OIDC_USERINFO_URI=https://${AUTHENTIK_DOMAIN}/application/o/userinfo/
OIDC_LOGOUT_URI=https://${AUTHENTIK_DOMAIN}/application/o/outline/end-session/
OIDC_DISPLAY_NAME=Authentik
OIDC_SCOPES=openid profile email
```

**验证**: 访问 https://docs.DOMAIN，点击 "Sign in with Authentik"

### Open WebUI

**集成方式**: 原生 OIDC

**配置文件**: `stacks/ai/docker-compose.yml`

**环境变量**:
```yaml
ENABLE_OIDC_MIXED_GROUPS=true
OIDC_CLIENT_ID=${OPENWEBUI_OAUTH_CLIENT_ID}
OIDC_CLIENT_SECRET=${OPENWEBUI_OAUTH_CLIENT_SECRET}
OIDC_PROVIDER_URL=https://${AUTHENTIK_DOMAIN}/application/o/open-webui/.well-known/openid-configuration
OIDC_REDIRECT_URI=https://ai.DOMAIN/oauth/callback
OIDC_SCOPES=openid profile email
OIDC_NAME=Authentik
OIDC_AUTO_REDIRECT=true
```

**验证**: 访问 https://ai.DOMAIN，自动重定向到 Authentik 登录

### Nextcloud

**集成方式**: OIDC Login 应用

**前置步骤**:
1. 在 Nextcloud 应用商店安装 "OIDC Login" 应用
2. 运行配置脚本：`../../scripts/nextcloud-oidc-setup.sh`

**配置文件**: `stacks/storage/docker-compose.yml`

**环境变量**:
```yaml
OIDC_CLIENT_ID=${NEXTCLOUD_OAUTH_CLIENT_ID}
OIDC_CLIENT_SECRET=${NEXTCLOUD_OAUTH_CLIENT_SECRET}
OIDC_ISSUER_URL=https://${AUTHENTIK_DOMAIN}/application/o/nextcloud/
OIDC_REDIRECT_URI=https://nextcloud.DOMAIN/apps/oidc_login/oidc
OIDC_DISPLAY_NAME=Authentik
OIDC_AUTO_CREATE_USERS=true
OIDC_AUTO_PROVISION=true
```

**验证**: 访问 https://nextcloud.DOMAIN，点击 "Login with Authentik"

### Portainer

**集成方式**: 原生 OAuth

**配置文件**: `stacks/base/docker-compose.yml`

**环境变量**:
```yaml
PORTAINER_OAUTH_CLIENT_ID=${PORTAINER_OAUTH_CLIENT_ID}
PORTAINER_OAUTH_CLIENT_SECRET=${PORTAINER_OAUTH_CLIENT_SECRET}
PORTAINER_OAUTH_REDIRECT_URL=https://portainer.DOMAIN/
PORTAINER_OAUTH_AUTHORIZE_URL=https://${AUTHENTIK_DOMAIN}/application/o/authorize/
PORTAINER_OAUTH_TOKEN_URL=https://${AUTHENTIK_DOMAIN}/application/o/token/
PORTAINER_OAUTH_USER_INFO_URL=https://${AUTHENTIK_DOMAIN}/application/o/userinfo/
```

**注意**: Portainer OAuth 需要在 Web UI 中完成最终配置
1. 访问 https://portainer.DOMAIN
2. Settings → Authentication → OAuth
3. 填入 Client ID/Secret
4. 保存并启用

### Bookstack

**集成方式**: 原生 OIDC

**配置文件**: `stacks/productivity/docker-compose.yml`

**环境变量**:
```yaml
AUTH_METHOD=oidc
OIDC_CLIENT_ID=${BOOKSTACK_OIDC_CLIENT_ID}
OIDC_CLIENT_SECRET=${BOOKSTACK_OIDC_CLIENT_SECRET}
OIDC_ISSUER=https://${AUTHENTIK_DOMAIN}/application/o/bookstack/
OIDC_NAME=Authentik
```

**验证**: 访问 https://wiki.DOMAIN，点击 "Login with Authentik"

### Prometheus (ForwardAuth 示例)

**集成方式**: Traefik ForwardAuth 中间件

**配置文件**: `stacks/monitoring/docker-compose.yml`

**Labels**:
```yaml
labels:
  - traefik.http.routers.prometheus.middlewares=authentik@file
```

**验证**: 访问 https://prometheus.DOMAIN，自动重定向到 Authentik 登录

## 用户组与权限管理

### 预定义用户组

| 组名 | 描述 | 权限 |
|------|------|------|
| `homelab-admins` | 系统管理员 | 访问所有服务的管理功能 |
| `homelab-users` | 普通用户 | 访问基本服务 |
| `media-users` | 媒体用户 | 仅访问 Jellyfin/Jellyseerr |

### 配置组权限

1. **创建组**:
   - 访问 Authentik Admin: https://auth.DOMAIN/if/admin/
   - Groups → Create Group
   - 输入组名（如 `homelab-admins`）

2. **分配应用权限**:
   - 编辑组 → Applications
   - 添加允许访问的应用

3. **配置角色映射** (以 Grafana 为例):
```yaml
GF_AUTH_GENERIC_OAUTH_ROLE_ATTRIBUTE_PATH=
  contains(groups, 'homelab-admins') && 'Admin' ||
  contains(groups, 'homelab-users') && 'Editor' ||
  'Viewer'
```

### 测试组权限

```bash
# 创建测试用户
# 1. Authentik Admin → Users → Create User
# 2. 添加到 homelab-users 组
# 3. 登录 Grafana 验证角色

# 验证 media-users 无法访问 Grafana
# 1. 创建用户并仅添加到 media-users 组
# 2. 尝试访问 https://grafana.DOMAIN
# 3. 应显示 "Access Denied"
```

## 故障排查

### 常见问题

#### 1. Authentik 容器无法启动

**症状**: 容器立即退出

**检查**:
```bash
docker logs authentik-server
```

**常见原因**:
- `AUTHENTIK_SECRET_KEY` 未设置或为空
- 数据库连接失败（密码不匹配）
- Redis 连接失败

**解决**:
```bash
# 确保密钥已正确生成
export AUTHENTIK_SECRET_KEY=$(openssl rand -base64 32)

# 检查数据库密码
docker logs authentik-postgres | grep "ready"
```

#### 2. OIDC 重定向错误

**症状**: "Redirect URI mismatch" 错误

**原因**: Authentik 中配置的回调 URL 与服务实际 URL 不匹配

**解决**:
```bash
# 检查 Authentik Provider 配置
curl -sf https://auth.DOMAIN/api/v3/providers/oauth2/PROVIDER_ID/ \
  -H "Authorization: Bearer TOKEN" | jq '.redirect_uris'

# 确保与 docker-compose.yml 中的完全一致
# 例如：https://grafana.DOMAIN/login/generic_oauth
```

#### 3. ForwardAuth 循环重定向

**症状**: 浏览器在登录页面和服务之间循环跳转

**原因**: ForwardAuth 配置使用了公网域名而非内部服务名

**解决**:
```yaml
# 确保使用内部地址
middlewares:
  authentik:
    forwardAuth:
      address: "http://authentik-server:9000/outpost.goauthentik.io/auth/traefik"
      # 不是：https://auth.DOMAIN/...
```

#### 4. 用户登录成功但无法访问服务

**症状**: OIDC 登录成功，但服务显示 "Access Denied"

**原因**: 用户组权限未正确配置

**解决**:
1. 检查用户在 Authentik 中的组成员资格
2. 检查服务的角色映射配置
3. 查看服务日志确认收到的组信息

```bash
# 查看 Grafana 日志
docker logs grafana | grep -i "oauth\|auth"

# 查看 Authentik 审计日志
# Admin Interface → Events → Actions
```

### 调试命令

```bash
# 检查所有容器状态
docker compose ps

# 查看 Authentik 日志
docker logs -f authentik-server

# 测试 OIDC 端点
curl -sf https://auth.DOMAIN/application/o/grafana/.well-known/openid-configuration

# 测试 ForwardAuth
curl -v https://prometheus.DOMAIN/ 2>&1 | grep -i "location\|auth"

# 运行集成测试
./scripts/test-sso.sh
```

## 安全最佳实践

### 1. 强密码策略

```bash
# 生成强密码
openssl rand -base64 32  # 用于密钥
openssl rand -hex 16     # 用于密码
```

### 2. 启用 MFA

在 Authentik 中强制管理员启用双因素认证：

1. Admin Interface → Policies → Event Policies
2. 创建 MFA 策略
3. 应用到管理员登录流程

### 3. 定期更新

```bash
# 每周检查更新
watchtower 会自动更新

# 手动检查
docker compose pull
docker compose up -d
```

### 4. 审计日志

定期检查 Authentik 审计日志：

1. Admin Interface → Events → Actions
2. 导出日志进行归档
3. 设置异常登录告警

### 5. 网络隔离

```yaml
# 限制 Admin UI 访问（可选）
labels:
  - "traefik.http.routers.authentik-admin.rule=Host(`auth.DOMAIN`) && PathPrefix(`/if/admin/`)"
  - "traefik.http.routers.authentik-admin.middlewares=authentik,ip-whitelist@file"
```

### 6. 备份策略

```bash
# 每日备份 Authentik 数据库
0 2 * * * docker exec authentik-postgres pg_dump -U authentik authentik > /backup/authentik-$(date +\%Y\%m\%d).sql

# 每周测试恢复
0 3 * * 0 /path/to/test-restore.sh
```

## 参考资源

- [Authentik 官方文档](https://docs.goauthentik.io/)
- [OIDC 规范](https://openid.net/connect/)
- [Traefik ForwardAuth](https://doc.traefik.io/traefik/middlewares/http/forwardauth/)
- [Grafana OAuth](https://grafana.com/docs/grafana/latest/setup-grafana/configure-security/configure-authentication/generic-oauth/)
- [Nextcloud OIDC Login](https://github.com/pulsejet/nextcloud-oidc-login)
