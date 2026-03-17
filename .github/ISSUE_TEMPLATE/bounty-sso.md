---
name: 💰 Bounty - SSO Stack
about: 实现统一身份认证 (Authentik OIDC/SSO)
title: '[BOUNTY $300] SSO Stack — 统一身份认证'
labels: bounty, hard
assignees: ''
---

## 赏金金额

**$300 USDT**

## 任务描述

实现基于 Authentik 的统一身份认证系统，让所有服务支持单点登录（SSO）。这是整个项目中复杂度最高的 task。

## 服务清单

| 服务 | 镜像 | 用途 |
|------|------|------|
| Authentik Server | `ghcr.io/goauthentik/server:2024.8.3` | OIDC/SAML 提供商 |
| Authentik Worker | `ghcr.io/goauthentik/server:2024.8.3` | 后台任务 |
| PostgreSQL | `postgres:16.4-alpine` | Authentik 专用数据库 |
| Redis | `redis:7.4.0-alpine` | Authentik 缓存 |

## 核心要求

### 1. 基础部署

- Authentik 通过 `auth.${DOMAIN}` 访问
- 配置管理员账号（首次启动自动创建）
- 健康检查严格，其他依赖 SSO 的服务等待 Authentik 就绪

### 2. 必须完成的 OIDC 集成

每个服务需提供 **截图 + 配置文件** 作为验收证明：

| 服务 | 集成方式 | 配置位置 |
|------|----------|----------|
| Grafana | OIDC | `config/grafana/grafana.ini` |
| Gitea | OIDC | `stacks/productivity/.env` |
| Nextcloud | OIDC (social login app) | `scripts/nextcloud-oidc-setup.sh` |
| Outline | OIDC | `stacks/productivity/.env` |
| Open WebUI | OIDC | `stacks/ai/.env` |
| Portainer | OAuth | `stacks/base/.env` |

### 3. Authentik 初始化脚本

`scripts/authentik-setup.sh`：

- 使用 Authentik API 自动创建所有 OAuth2/OIDC Provider
- 自动创建对应 Application
- 输出每个服务需要填入的 `Client ID` 和 `Client Secret`
- 支持 `--dry-run` 预览

```bash
./scripts/authentik-setup.sh
# 输出:
# [OK] Created provider: Grafana
#      Client ID: xxxxx
#      Client Secret: xxxxx
#      Redirect URI: https://grafana.example.com/login/generic_oauth
# [OK] Created provider: Gitea
# ...
```

### 4. Traefik ForwardAuth

为不原生支持 OIDC 的服务配置 Traefik ForwardAuth 中间件：

```yaml
# config/traefik/dynamic/middlewares.yml
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

### 5. 用户组设计

```
Groups:
  homelab-admins    → 访问所有服务管理界面
  homelab-users     → 访问普通服务
  media-users       → 仅访问 Jellyfin/Jellyseerr
```

### 6. 环境变量

```bash
AUTHENTIK_SECRET_KEY=
AUTHENTIK_BOOTSTRAP_EMAIL=
AUTHENTIK_BOOTSTRAP_PASSWORD=
AUTHENTIK_DB_PASSWORD=
AUTHENTIK_DOMAIN=auth.example.com
```

## 验收标准

- [ ] Authentik Web UI 可访问，管理员可登录
- [ ] `authentik-setup.sh` 自动创建所有 Provider 并输出凭据
- [ ] Grafana 可用 Authentik 账号登录
- [ ] Gitea 可用 Authentik 账号登录
- [ ] Nextcloud 可用 Authentik 账号登录
- [ ] Outline 可用 Authentik 账号登录
- [ ] ForwardAuth 中间件保护至少一个无原生 OIDC 的服务
- [ ] 用户组权限隔离正确（media-users 无法访问 Grafana admin）
- [ ] README 包含：新增服务如何接入 Authentik 的教程

## 认领方式

评论 "我来认领"。
