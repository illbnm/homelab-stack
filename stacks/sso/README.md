# SSO Stack — Authentik 统一身份认证

基于 [Authentik](https://goauthentik.io/) 的统一身份认证系统，为所有 HomeLab 服务提供单点登录（SSO）支持。

## 架构

```
Browser
  │
  ▼
Traefik (443)
  │  ForwardAuth middleware → authentik-server:9000
  │
  ├── auth.DOMAIN     → Authentik UI (login, admin, user portal)
  ├── grafana.DOMAIN  → Grafana (OIDC)
  ├── git.DOMAIN      → Gitea (OIDC)
  ├── cloud.DOMAIN    → Nextcloud (OIDC)
  ├── outline.DOMAIN  → Outline (OIDC)
  ├── webui.DOMAIN    → Open WebUI (OIDC)
  └── portainer.DOMAIN → Portainer (OAuth2)

Internal:
  authentik-server ─┐
                    ├── postgresql:5432
  authentik-worker ─┘
                    └── redis:6379
```

## 服务清单

| 服务 | 镜像 | 端口 | 用途 |
|------|------|------|------|
| authentik-server | `ghcr.io/goauthentik/server:2024.8.3` | 9000/9443 | Web UI + API + OIDC 端点 |
| authentik-worker | `ghcr.io/goauthentik/server:2024.8.3` | — | 后台任务（邮件、通知） |
| postgresql | `postgres:16-alpine` | 5432 (内部) | Authentik 数据库 |
| redis | `redis:7-alpine` | 6379 (内部) | 会话缓存 + 任务队列 |

## 前提条件

- Base stack 已运行（`stacks/base/` — Traefik + proxy network）
- 域名 DNS 已指向服务器
- 端口 80 + 443 开放

## 快速开始

### 1. 复制并填写环境变量

```bash
cd stacks/sso
cp .env.example .env
nano .env  # 填写所有 REQUIRED 值
```

### 2. 生成密钥

```bash
# 生成安全密钥
export AUTHENTIK_SECRET_KEY=$(openssl rand -base64 32)
export AUTHENTIK_POSTGRES_PASSWORD=$(openssl rand -hex 16)
export AUTHENTIK_REDIS_PASSWORD=$(openssl rand -hex 16)
export AUTHENTIK_BOOTSTRAP_TOKEN=$(openssl rand -hex 32)
export AUTHENTIK_BOOTSTRAP_PASSWORD=$(openssl rand -hex 16)

# 更新 .env 文件
sed -i "s|^AUTHENTIK_SECRET_KEY=.*|AUTHENTIK_SECRET_KEY=$AUTHENTIK_SECRET_KEY|" .env
sed -i "s|^AUTHENTIK_POSTGRES_PASSWORD=.*|AUTHENTIK_POSTGRES_PASSWORD=$AUTHENTIK_POSTGRES_PASSWORD|" .env
sed -i "s|^AUTHENTIK_REDIS_PASSWORD=.*|AUTHENTIK_REDIS_PASSWORD=$AUTHENTIK_REDIS_PASSWORD|" .env
sed -i "s|^AUTHENTIK_BOOTSTRAP_TOKEN=.*|AUTHENTIK_BOOTSTRAP_TOKEN=$AUTHENTIK_BOOTSTRAP_TOKEN|" .env
sed -i "s|^AUTHENTIK_BOOTSTRAP_PASSWORD=.*|AUTHENTIK_BOOTSTRAP_PASSWORD=$AUTHENTIK_BOOTSTRAP_PASSWORD|" .env
```

### 3. 启动服务

```bash
docker compose up -d
```

### 4. 等待服务健康（首次启动约 60 秒）

```bash
docker compose ps
```

### 5. 运行自动配置脚本

```bash
# 为所有服务创建 OIDC Provider
../../scripts/setup-authentik.sh
```

脚本输出示例：
```
==> Creating user groups...
[✓]   Group created: homelab-admins (1)
[✓]   Group created: homelab-users (2)
[✓]   Group created: media-users (3)

==> Creating OIDC providers...
服务            | Client ID                              | Redirect URI
--------------------------------------------------------------------------------
[✓]   Application created: Grafana
[✓]   Application created: Gitea
[✓]   Application created: Nextcloud
[✓]   Application created: Outline
[✓]   Application created: Open WebUI
[✓]   Application created: Portainer

==> Setup Complete!
[✓] All OIDC providers created successfully
Credentials written to: .env
```

## 环境变量

| 变量 | 必需 | 说明 |
|------|------|------|
| `AUTHENTIK_SECRET_KEY` | YES | 随机密钥 — `openssl rand -base64 32` |
| `AUTHENTIK_POSTGRES_PASSWORD` | YES | PostgreSQL 密码 |
| `AUTHENTIK_REDIS_PASSWORD` | YES | Redis 密码 |
| `AUTHENTIK_BOOTSTRAP_EMAIL` | YES | 初始管理员邮箱 |
| `AUTHENTIK_BOOTSTRAP_PASSWORD` | YES | 初始管理员密码 |
| `AUTHENTIK_BOOTSTRAP_TOKEN` | YES | 设置脚本 API Token |
| `AUTHENTIK_DOMAIN` | YES | 例如 `auth.yourdomain.com` |

## 集成其他服务

### 方式 A：原生 OIDC（推荐）

运行 `../../scripts/setup-authentik.sh` 自动创建 Provider 并将凭据写入 `.env`。

支持原生 OIDC 的服务：Grafana、Gitea、Nextcloud、Outline、Open WebUI、Portainer。

#### Grafana 配置

编辑 `stacks/monitoring/.env`：

```bash
GF_AUTH_GENERIC_OAUTH_ENABLED=true
GF_AUTH_GENERIC_OAUTH_NAME=Authentik
GF_AUTH_GENERIC_OAUTH_CLIENT_ID=<从 .env 获取>
GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET=<从 .env 获取>
GF_AUTH_GENERIC_OAUTH_SCOPES=openid profile email
GF_AUTH_GENERIC_OAUTH_AUTH_URL=https://auth.${DOMAIN}/application/o/authorize/
GF_AUTH_GENERIC_OAUTH_TOKEN_URL=https://auth.${DOMAIN}/application/o/token/
GF_AUTH_GENERIC_OAUTH_API_URL=https://auth.${DOMAIN}/application/o/userinfo/
```

#### Gitea 配置

编辑 `stacks/productivity/.env`：

```bash
GITEA__OAUTH2__ENABLED=true
GITEA__OAUTH2__NAME=Authentik
GITEA__OAUTH2__CLIENT_ID=<从 .env 获取>
GITEA__OAUTH2__CLIENT_SECRET=<从 .env 获取>
GITEA__OAUTH2__PROVIDER_URL=https://auth.${DOMAIN}/application/o/gitea/
```

### 方式 B：ForwardAuth（无 OAuth2 支持的服务）

在服务的 docker-compose 标签中添加：

```yaml
labels:
  - "traefik.http.routers.<name>.middlewares=authentik@file"
```

Authentik 将拦截未认证的请求并重定向到登录页面。

## 用户组设计

系统预置三个用户组：

| 用户组 | 权限 | 适用服务 |
|--------|------|----------|
| `homelab-admins` | 访问所有服务管理界面 | Grafana Admin, Portainer, Gitea Admin |
| `homelab-users` | 访问普通服务 | Nextcloud, Outline, Open WebUI |
| `media-users` | 仅访问媒体服务 | Jellyfin, Jellyseerr |

### 在 Authentik 中配置访问策略

1. 登录 Authentik Web UI (`https://auth.DOMAIN/if/admin/`)
2. 进入 **Applications → Applications**
3. 选择要配置的应用
4. 点击 **Policy/Group/User Bindings**
5. 添加绑定，选择对应用户组

## 健康检查

```bash
# 检查所有容器状态
docker compose ps

# 检查 Authentik API
curl -sf https://auth.DOMAIN/-/health/ready/ && echo OK

# 检查管理界面
curl -sf https://auth.DOMAIN/if/admin/ -o /dev/null && echo OK
```

## 验收清单

- [ ] Authentik Web UI 可访问，管理员可登录
- [ ] `scripts/setup-authentik.sh` 自动创建所有 Provider 并输出凭据
- [ ] 用户组已创建（homelab-admins, homelab-users, media-users）
- [ ] Grafana 可用 Authentik 账号登录
- [ ] Gitea 可用 Authentik 账号登录
- [ ] Nextcloud 可用 Authentik 账号登录
- [ ] Outline 可用 Authentik 账号登录
- [ ] Open WebUI 可用 Authentik 账号登录
- [ ] Portainer 可用 Authentik 账号登录
- [ ] ForwardAuth 中间件保护至少一个无原生 OIDC 的服务
- [ ] 用户组权限隔离正确（media-users 无法访问 Grafana admin）
- [ ] README 包含新增服务接入 Authentik 的教程

## 新增服务接入指南

### 步骤 1：在 Authentik 创建 Provider

1. 登录 Authentik Web UI
2. 进入 **Applications → Providers**
3. 点击 **Create** → **OAuth2/OpenID Provider**
4. 填写：
   - Name: 服务名称
   - Client type: Confidential
   - Redirect URIs: 服务的回调 URL
   - Signing Key: 选择默认密钥
5. 保存并记录 `Client ID` 和 `Client Secret`

### 步骤 2：创建 Application

1. 进入 **Applications → Applications**
2. 点击 **Create**
3. 填写：
   - Name: 服务名称
   - Provider: 选择刚创建的 Provider
   - Open URL: 服务地址
4. 保存

### 步骤 3：配置服务

根据服务文档配置 OIDC/OAuth2。

### 步骤 4：配置访问策略

1. 进入 **Applications → Applications**
2. 选择应用
3. 点击 **Policy/Group/User Bindings**
4. 添加绑定，选择允许访问的用户组

## 故障排查

| 症状 | 解决方案 |
|------|----------|
| 容器立即退出 | 检查 `AUTHENTIK_SECRET_KEY` 是否设置且非空 |
| 数据库连接拒绝 | 等待 30 秒让 PostgreSQL 初始化；检查密码匹配 |
| OIDC 重定向不匹配 | 确保 Authentik 中的 `redirect_uris` 与回调 URL 完全匹配 |
| ForwardAuth 循环 | 确保 outpost URL 使用内部主机名 `authentik-server:9000` |
| `ghcr.io` 拉取超时 | 在 docker-compose.yml 中切换到 CN 镜像 |
| 脚本创建 Provider 失败 | 检查 `AUTHENTIK_BOOTSTRAP_TOKEN` 是否正确 |

## 国内镜像

如果 `ghcr.io` 访问困难，编辑 `docker-compose.yml` 取消 CN 镜像注释：

```yaml
# image: swr.cn-north-4.myhuaweicloud.com/ddn-k8s/ghcr.io/goauthentik/server:2024.8.3
```

## 参考链接

- [Authentik 官方文档](https://docs.goauthentik.io/)
- [OAuth2/OIDC 规范](https://openid.net/connect/)
- [Traefik ForwardAuth](https://doc.traefik.io/traefik/middlewares/http/forwardauth/)

## 赏金信息

**金额**: $300 USDT  
**Issue**: [illbnm/homelab-stack #9](https://github.com/illbnm/homelab-stack/issues/9)
