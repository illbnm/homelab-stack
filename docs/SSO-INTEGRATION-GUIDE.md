# SSO 集成指南 — Authentik 统一身份认证

本指南详细说明如何为 HomeLab 中的所有服务配置 Authentik SSO。

## 📋 前置条件

1. **Base Stack 运行中** (Traefik + proxy network)
2. **域名配置正确** (DNS 指向服务器)
3. **SSL 证书可用** (Let's Encrypt)

## 🚀 快速开始

### 步骤 1: 配置 SSO Stack

```bash
cd stacks/sso
cp .env.example .env

# 生成必要的安全密钥
export AUTHENTIK_SECRET_KEY=$(openssl rand -base64 32)
export AUTHENTIK_POSTGRES_PASSWORD=$(openssl rand -hex 16)
export AUTHENTIK_REDIS_PASSWORD=$(openssl rand -hex 16)
export AUTHENTIK_BOOTSTRAP_TOKEN=$(openssl rand -hex 32)

# 更新 .env 文件
sed -i "s|^AUTHENTIK_SECRET_KEY=.*|AUTHENTIK_SECRET_KEY=$AUTHENTIK_SECRET_KEY|" .env
sed -i "s|^AUTHENTIK_POSTGRES_PASSWORD=.*|AUTHENTIK_POSTGRES_PASSWORD=$AUTHENTIK_POSTGRES_PASSWORD|" .env
sed -i "s|^AUTHENTIK_REDIS_PASSWORD=.*|AUTHENTIK_REDIS_PASSWORD=$AUTHENTIK_REDIS_PASSWORD|" .env
sed -i "s|^AUTHENTIK_BOOTSTRAP_TOKEN=.*|AUTHENTIK_BOOTSTRAP_TOKEN=$AUTHENTIK_BOOTSTRAP_TOKEN|" .env

# 设置管理员账号
echo "AUTHENTIK_BOOTSTRAP_EMAIL=admin@yourdomain.com" >> .env
echo "AUTHENTIK_BOOTSTRAP_PASSWORD=$(openssl rand -base64 16)" >> .env
```

### 步骤 2: 启动 SSO Stack

```bash
docker compose up -d

# 等待服务就绪（约 60 秒）
docker compose ps
# 所有容器状态应为 healthy
```

### 步骤 3: 运行初始化脚本

```bash
cd ../..
./scripts/setup-authentik.sh
```

脚本会自动：
- 等待 Authentik API 就绪
- 为每个服务创建 OIDC Provider
- 生成 Client ID 和 Client Secret
- 写入到各 stack 的 `.env` 文件

### 步骤 4: 重启其他 Stack

```bash
# 重启所有依赖 SSO 的服务
cd stacks/monitoring && docker compose up -d
cd ../productivity && docker compose up -d
cd ../ai && docker compose up -d
cd ../base && docker compose up -d
```

## 🔧 服务集成详情

### 1. Grafana (OIDC)

**配置文件**: `stacks/monitoring/docker-compose.yml`

```yaml
environment:
  - GF_AUTH_GENERIC_OAUTH_ENABLED=true
  - GF_AUTH_GENERIC_OAUTH_NAME=Authentik
  - GF_AUTH_GENERIC_OAUTH_CLIENT_ID=${GRAFANA_OAUTH_CLIENT_ID}
  - GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET=${GRAFANA_OAUTH_CLIENT_SECRET}
  - GF_AUTH_GENERIC_OAUTH_SCOPES=openid profile email
  - GF_AUTH_GENERIC_OAUTH_AUTH_URL=https://auth.DOMAIN/application/o/authorize/
  - GF_AUTH_GENERIC_OAUTH_TOKEN_URL=https://auth.DOMAIN/application/o/token/
  - GF_AUTH_GENERIC_OAUTH_API_URL=https://auth.DOMAIN/application/o/userinfo/
```

**验证**:
1. 访问 https://grafana.DOMAIN
2. 点击 "Sign in with Authentik"
3. 使用 Authentik 账号登录

### 2. Gitea (OIDC)

**配置文件**: `stacks/productivity/docker-compose.yml`

```yaml
environment:
  - GITEA__openid__ENABLE=true
  - GITEA__openid__CONNECT_URL=https://auth.DOMAIN/.well-known/openid-configuration
  - GITEA__openid__CLIENT_ID=${GITEA_OAUTH_CLIENT_ID}
  - GITEA__openid__CLIENT_SECRET=${GITEA_OAUTH_CLIENT_SECRET}
```

**验证**:
1. 访问 https://git.DOMAIN
2. 点击 "Login with OpenID Connect"
3. 使用 Authentik 账号登录

### 3. Outline (OIDC)

**配置文件**: `stacks/productivity/docker-compose.yml`

```yaml
environment:
  - OIDC_CLIENT_ID=${OUTLINE_OAUTH_CLIENT_ID}
  - OIDC_CLIENT_SECRET=${OUTLINE_OAUTH_CLIENT_SECRET}
  - OIDC_AUTH_URI=https://auth.DOMAIN/application/o/authorize/
  - OIDC_TOKEN_URI=https://auth.DOMAIN/application/o/token/
  - OIDC_USERINFO_URI=https://auth.DOMAIN/application/o/userinfo/
```

**验证**:
1. 访问 https://docs.DOMAIN
2. 点击 "Continue with Authentik"
3. 使用 Authentik 账号登录

### 4. Open WebUI (OIDC)

**配置文件**: `stacks/ai/docker-compose.yml`

```yaml
environment:
  - ENABLE_OIDC_MIXED_FLOW=True
  - OIDC_PROVIDER_NAME=Authentik
  - OIDC_CLIENT_ID=${OPENWEBUI_OAUTH_CLIENT_ID}
  - OIDC_CLIENT_SECRET=${OPENWEBUI_OAUTH_CLIENT_SECRET}
  - OIDC_AUTH_SERVER_URL=https://auth.DOMAIN/application/o/openwebui/
  - OIDC_TOKEN_URL=https://auth.DOMAIN/application/o/token/
  - OIDC_USERINFO_URL=https://auth.DOMAIN/application/o/userinfo/
```

**验证**:
1. 访问 https://ai.DOMAIN
2. 点击 "Sign in with Authentik"
3. 使用 Authentik 账号登录

### 5. Portainer (OAuth)

**配置文件**: `stacks/base/docker-compose.yml`

```yaml
environment:
  - PORTAINER_OAUTH_AUTH_URL=https://auth.DOMAIN/application/o/authorize/
  - PORTAINER_OAUTH_TOKEN_URL=https://auth.DOMAIN/application/o/token/
  - PORTAINER_OAUTH_USER_INFO_URL=https://auth.DOMAIN/application/o/userinfo/
  - PORTAINER_OAUTH_CLIENT_ID=${PORTAINER_OAUTH_CLIENT_ID}
  - PORTAINER_OAUTH_CLIENT_SECRET=${PORTAINER_OAUTH_CLIENT_SECRET}
```

**验证**:
1. 访问 https://portainer.DOMAIN
2. 点击 "Login with Authentik"
3. 使用 Authentik 账号登录

### 6. ForwardAuth (无原生 OAuth 的服务)

对于不支持 OAuth 的服务，使用 Traefik ForwardAuth 中间件：

```yaml
labels:
  - traefik.http.routers.<service>.middlewares=authentik@file
```

在 `config/traefik/dynamic/middlewares.yml` 中配置：

```yaml
middlewares:
  authentik:
    forwardAuth:
      address: "http://authentik-server:9000/outpost.goauthentik.io/auth/traefik"
      trustForwardHeader: true
      authResponseHeaders:
        - X-authentik-username
        - X-authentik-groups
        - X-authentik-email
```

## 👥 用户组管理

### 创建用户组

在 Authentik Admin UI 中：

1. 访问 https://auth.DOMAIN/if/admin/
2. 进入 **Directory** → **Groups**
3. 创建以下组：

| 组名 | 描述 | 访问权限 |
|------|------|----------|
| `homelab-admins` | 管理员组 | 所有服务的管理权限 |
| `homelab-users` | 普通用户 | 所有服务的普通权限 |
| `media-users` | 媒体用户 | 仅访问 Jellyfin/Jellyseerr |

### 配置组权限

**Grafana 角色映射**:
```yaml
- GF_AUTH_GENERIC_OAUTH_ROLE_ATTRIBUTE_PATH=contains(groups, 'homelab-admins') && 'Admin' || contains(groups, 'homelab-users') && 'Editor' || 'Viewer'
```

**Outline 权限**:
在 Authentik 中配置 Policy，限制特定组访问。

## 🔍 故障排查

### 问题 1: OIDC 回调失败

**症状**: 登录后重定向到错误页面

**解决**:
```bash
# 检查回调 URL 是否匹配
curl -s https://auth.DOMAIN/application/o/grafana/ | jq '.redirect_uris'

# 应该包含：https://grafana.DOMAIN/login/generic_oauth
```

### 问题 2: ForwardAuth 循环重定向

**症状**: 不断重定向到登录页面

**解决**:
```yaml
# 确保使用内部地址
middlewares:
  authentik:
    forwardAuth:
      address: "http://authentik-server:9000/outpost.goauthentik.io/auth/traefik"
      # 不是 https://auth.DOMAIN/...
```

### 问题 3: 容器无法连接 Authentik

**症状**: 服务启动失败，日志显示连接拒绝

**解决**:
```bash
# 检查网络配置
docker network ls | grep proxy
docker network inspect proxy

# 确保所有服务都在 proxy 网络中
docker inspect <container> | grep Networks
```

### 问题 4: SSL 证书错误

**症状**: 浏览器显示证书警告

**解决**:
```bash
# 检查 acme.json 权限
chmod 600 config/traefik/acme.json

# 检查 Traefik 日志
docker logs traefik | grep -i acme
```

## 📊 监控和维护

### 检查 SSO 状态

```bash
# 所有容器健康
docker compose ps

# Authentik API 响应
curl -sf https://auth.DOMAIN/-/health/ready/ && echo "OK"

# 查看登录日志
docker logs authentik-server | grep -i login
```

### 备份 Authentik 数据

```bash
# 备份数据库
docker exec authentik-postgres pg_dump -U authentik authentik > authentik-backup.sql

# 备份媒体文件
tar -czf authentik-media-backup.tar.gz /var/lib/docker/volumes/authentik_media/_data
```

### 恢复 Authentik

```bash
# 恢复数据库
docker exec -i authentik-postgres psql -U authentik authentik < authentik-backup.sql

# 恢复媒体文件
tar -xzf authentik-media-backup.tar.gz -C /
```

## 🎯 验收清单

- [ ] Authentik Web UI 可访问，管理员可登录
- [ ] `setup-authentik.sh` 成功创建所有 Provider
- [ ] Grafana 可用 Authentik 账号登录
- [ ] Gitea 可用 Authentik 账号登录
- [ ] Outline 可用 Authentik 账号登录
- [ ] Open WebUI 可用 Authentik 账号登录
- [ ] Portainer 可用 Authentik 账号登录
- [ ] 用户组权限隔离正确
- [ ] ForwardAuth 保护至少一个无原生 OIDC 的服务

---

**文档版本**: 1.0  
**最后更新**: 2026-03-18  
**维护者**: 牛马 - 软件开发专家
