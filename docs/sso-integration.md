# Authentik SSO 集成指南

本文档说明如何将新服务接入 Authentik 统一身份认证系统。

## 目录

- [概述](#概述)
- [OIDC 集成（推荐）](#oidc-集成推荐)
- [ForwardAuth 集成](#forwardauth-集成)
- [各服务集成详情](#各服务集成详情)
- [用户组与权限](#用户组与权限)

## 概述

Authentik 作为 OIDC/SAML 提供者，为所有服务提供单点登录支持。

```
┌─────────────────────────────────────────────────────────┐
│                      浏览器                              │
└─────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────┐
│                   Authentik (auth.example.com)           │
│   - 统一登录页面                                          │
│   - 用户组管理                                            │
│   - OIDC/SAML Provider                                   │
└─────────────────────────────────────────────────────────┘
                            │
        ┌───────────────────┼───────────────────┐
        ▼                   ▼                   ▼
   Grafana             Outline              其他服务
   Gitea               Nextcloud            (ForwardAuth)
   Open WebUI          Portainer
```

## OIDC 集成（推荐）

适用于原生支持 OAuth2/OIDC 的服务。

### 步骤 1：运行 Authentik 初始化脚本

```bash
# 首次设置：为所有服务创建 OIDC Provider
./scripts/setup-authentik.sh

# 预览模式（不实际创建）
./scripts/setup-authentik.sh --dry-run
```

脚本会自动：
- 创建 OIDC Provider（每个服务一个）
- 创建对应的 Application
- 输出 Client ID 和 Client Secret

### 步骤 2：配置服务 .env

从脚本输出中获取以下变量，添加到对应服务的 `.env` 文件：

```env
# Grafana
GRAFANA_OAUTH_CLIENT_ID=<your-client-id>
GRAFANA_OAUTH_CLIENT_SECRET=<your-client-secret>

# Outline
OUTLINE_OAUTH_CLIENT_ID=<your-client-id>
OUTLINE_OAUTH_CLIENT_SECRET=<your-client-secret>

# Gitea (通过 Web UI 配置)
# 见下方 Gitea 集成说明

# Nextcloud
NEXTCLOUD_OAUTH_CLIENT_ID=<your-client-id>
NEXTCLOUD_OAUTH_CLIENT_SECRET=<your-client-secret>

# Open WebUI
OPEN_WEBUI_OAUTH_CLIENT_ID=<your-client-id>
OPEN_WEBUI_OAUTH_CLIENT_SECRET=<your-client-secret>

# Portainer
PORTAINER_OAUTH_CLIENT_ID=<your-client-id>
PORTAINER_OAUTH_CLIENT_SECRET=<your-client-secret>
```

### 步骤 3：重启服务

```bash
docker compose -f stacks/<stack-name>/docker-compose.yml up -d
```

## ForwardAuth 集成

适用于不原生支持 OIDC 的服务。通过 Traefik 中间件拦截请求，未认证用户重定向到 Authentik 登录页。

### 配置方法

在服务的 `docker-compose.yml` 中添加 Traefik label：

```yaml
labels:
  - "traefik.http.routers.<service-name>.middlewares=authentik@file"
```

### 示例

假设你想为 Jellyfin 添加 SSO 保护：

```yaml
services:
  jellyfin:
    image: jellyfin/jellyfin:10.9.7
    # ... 其他配置 ...
    labels:
      - traefik.enable=true
      - "traefik.http.routers.jellyfin.rule=Host(`jellyfin.${DOMAIN}`)"
      - traefik.http.routers.jellyfin.entrypoints=websecure
      - traefik.http.routers.jellyfin.tls=true
      # 添加这一行启用 Authentik 认证
      - "traefik.http.routers.jellyfin.middlewares=authentik@file"
```

### 可用的 ForwardAuth 中间件

| 中间件 | 说明 |
|--------|------|
| `authentik@file` | 完整 SSO，登录后重定向回原服务 |
| `authentik-basic@file` | 仅返回 401，不重定向（适合 API） |

### 获取用户信息

ForwardAuth 会将以下 header 传递给后端服务：

| Header | 说明 |
|--------|------|
| `X-authentik-username` | 用户名 |
| `X-authentik-email` | 邮箱 |
| `X-authentik-groups` | 用户组（逗号分隔） |
| `X-authentik-name` | 显示名称 |
| `X-authentik-uid` | 用户 ID |

## 各服务集成详情

### Grafana

**配置文件：** `stacks/monitoring/docker-compose.yml`

Grafana 原生支持 OIDC。环境变量已配置：

```env
GF_AUTH_GENERIC_OAUTH_ENABLED=true
GF_AUTH_GENERIC_OAUTH_NAME=Authentik
GF_AUTH_GENERIC_OAUTH_CLIENT_ID=${GRAFANA_OAUTH_CLIENT_ID}
GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET=${GRAFANA_OAUTH_CLIENT_SECRET}
GF_AUTH_GENERIC_OAUTH_AUTH_URL=https://${AUTHENTIK_DOMAIN}/application/o/authorize/
GF_AUTH_GENERIC_OAUTH_TOKEN_URL=https://${AUTHENTIK_DOMAIN}/application/o/token/
GF_AUTH_GENERIC_OAUTH_API_URL=https://${AUTHENTIK_DOMAIN}/application/o/userinfo/
```

**权限映射：**
```env
GF_AUTH_GENERIC_OAUTH_ROLE_ATTRIBUTE_PATH=contains(groups, 'Grafana Admins') && 'Admin' || contains(groups, 'Grafana Editors') && 'Editor' || 'Viewer'
```

### Gitea

**配置方式：** Web UI（不支持环境变量配置 OAuth2 客户端）

Gitea 不支持通过环境变量配置 OAuth2 客户端。需要在 Gitea Web UI 中注册 Authentik 作为 OAuth2 来源。

**步骤：**
1. 在 Authentik 中创建 Gitea 的 OAuth2 Provider（回调地址：`https://git.${DOMAIN}/user/oauth2/Authentik/callback`）
2. 在 Gitea 中：Settings → Applications → OAuth2 Applications
3. 点击 "New OAuth2 Application"
4. 填写：
   - Application Name: `Authentik`
   - Redirect URI: `https://git.${DOMAIN}/user/oauth2/Authentik/callback`
5. 保存 Client ID 和 Client Secret
6. 在 Authentik 中配置对应的 Client ID 和 Secret

### Outline

**配置文件：** `stacks/productivity/docker-compose.yml`

Outline 原生支持 OIDC。环境变量已配置：

```env
OIDC_CLIENT_ID=${OUTLINE_OAUTH_CLIENT_ID}
OIDC_CLIENT_SECRET=${OUTLINE_OAUTH_CLIENT_SECRET}
OIDC_AUTH_URI=https://${AUTHENTIK_DOMAIN}/application/o/authorize/
OIDC_TOKEN_URI=https://${AUTHENTIK_DOMAIN}/application/o/token/
OIDC_USERINFO_URI=https://${AUTHENTIK_DOMAIN}/application/o/userinfo/
OIDC_LOGOUT_URI=https://${AUTHENTIK_DOMAIN}/application/o/outline/end-session/
OIDC_DISPLAY_NAME=Authentik
OIDC_SCOPES=openid profile email
```

### Nextcloud

**配置方式：** Social Login App + OIDC Provider

Nextcloud 需要安装 Social Login App，然后配置 Authentik 作为 OIDC 提供者。

**步骤：**
1. 安装 Social Login App：
   ```bash
   docker exec nextcloud occ app:install sociallogin
   ```

2. 配置 Authentik Provider：
   - 创建 OAuth2 Provider
   - 回调地址：`https://nextcloud.${DOMAIN}/apps/sociallogin/custom_oidc/Authentik`

3. 运行初始化脚本：
   ```bash
   docker exec -it nextcloud bash /hooks/oidc-setup.sh
   ```

4. 或手动配置：
   ```bash
   docker exec nextcloud occ config:app:set sociallogin oidc_config_authentik \
     --value='{"name":"Authentik","clientId":"YOUR_CLIENT_ID","clientSecret":"YOUR_CLIENT_SECRET","issuer":"https://auth.example.com/application/o/nextcloud/"}'
   ```

### Open WebUI

**配置文件：** `stacks/ai/docker-compose.yml`

```env
OIDC_CLIENT_ID=${OPEN_WEBUI_OAUTH_CLIENT_ID}
OIDC_CLIENT_SECRET=${OPEN_WEBUI_OAUTH_CLIENT_SECRET}
OIDC_ISSUER=https://${AUTHENTIK_DOMAIN}/application/o/openwebui/
OIDC_CALLBACK_URL=https://ai.${DOMAIN}/auth/callback
OIDC_SCOPES=openid profile email
```

### Portainer

**配置文件：** `stacks/base/docker-compose.yml`

Portainer 支持 OAuth2/OIDC。环境变量已配置：

```env
AUTHENTICATION=oidc
OAUTH_CLIENT_ID=${PORTAINER_OAUTH_CLIENT_ID}
OAUTH_CLIENT_SECRET=${PORTAINER_OAUTH_CLIENT_SECRET}
OAUTH_PROVIDER=OIDC
OAUTH_OIDC_ISSUER=${AUTHENTIK_DOMAIN}/application/o/portainer/
```

## 用户组与权限

Authentik 中预定义了以下用户组：

| 组名 | 说明 | 典型用途 |
|------|------|----------|
| `homelab-admins` | 管理员组 | 访问所有服务的管理界面 |
| `homelab-users` | 普通用户组 | 访问普通服务 |
| `media-users` | 媒体用户组 | 仅访问 Jellyfin/Jellyseerr |

### 使用用户组控制访问

#### Grafana 权限示例

```env
# 如果用户在 "homelab-admins" 组，则授予 Admin 角色
# 如果用户在 "Grafana Editors" 组，则授予 Editor 角色
# 否则授予 Viewer 角色
GF_AUTH_GENERIC_OAUTH_ROLE_ATTRIBUTE_PATH=contains(groups, 'homelab-admins') && 'Admin' || contains(groups, 'Grafana Editors') && 'Editor' || 'Viewer'
```

#### ForwardAuth 保护特定路由

使用 Authentik 的 policy 功能，可以基于用户组限制访问：

1. 在 Authentik Web UI 中创建 Policy：
   - Source: `authentik Managed Service`
   - Action: `MFA`
   - User Groups: 选择允许访问的组

2. 或者在 Traefik label 中使用 middleware 组合：

```yaml
labels:
  # 首先使用 ForwardAuth 认证
  - "traefik.http.routers.<service>.middlewares=authentik@file"
```

### 添加新用户到组

1. 登录 Authentik：https://auth.${DOMAIN}
2. 进入 Directory → Groups
3. 选择目标组（如 `homelab-admins`）
4. 点击 "Add members" 添加用户

## 故障排除

### OIDC 重定向错误

**症状：** 登录后提示 "redirect_uri mismatch"

**解决：** 确保 Authentik Provider 中的回调地址与服务的配置完全匹配，包括协议（https）和端口。

### ForwardAuth 循环重定向

**症状：** 浏览器不断在登录页和服务之间跳转

**解决：** 确保 Traefik 配置使用内部 hostname `authentik-server:9000`，不要使用公网域名。

### 用户组不生效

**症状：** 用户登录后权限不符合预期

**解决：** 
1. 检查 Authentik 中用户确实属于目标组
2. 检查服务的 `groups` claim 配置
3. 检查 Grafana 的 `ROLE_ATTRIBUTE_PATH` 表达式

## 获取帮助

- [Authentik 文档](https://docs.goauthentik.io/)
- [项目 Issues](https://github.com/illbnm/homelab-stack/issues)
