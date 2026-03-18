# 🔐 SSO Stack — Authentik 统一身份认证

> 基于 Authentik 的 OIDC/SAML 单点登录，所有服务一个账号。

## 服务清单

| 服务 | 镜像 | URL | 用途 |
|------|------|-----|------|
| **Authentik Server** | `goauthentik/server:2024.8.3` | `auth.${DOMAIN}` | OIDC/SAML 提供商 |
| **Authentik Worker** | `goauthentik/server:2024.8.3` | — | 后台任务处理 |

## 前置依赖

- **Databases Stack** (PostgreSQL `authentik` database + Redis DB 0)

## 快速启动

```bash
# 1. 生成密钥
openssl rand -hex 50  # → AUTHENTIK_SECRET_KEY

# 2. 配置 .env
AUTHENTIK_SECRET_KEY=your_secret_key
AUTHENTIK_BOOTSTRAP_EMAIL=admin@homelab.local
AUTHENTIK_BOOTSTRAP_PASSWORD=your_admin_password
AUTHENTIK_DB_PASSWORD=authentik_pass  # 需与 Databases Stack 一致
REDIS_PASSWORD=your_redis_pass       # 需与 Databases Stack 一致

# 3. 启动
docker compose -f stacks/sso/docker-compose.yml up -d

# 4. 访问
# https://auth.${DOMAIN}
```

## OIDC 集成

### 自动设置

```bash
# 获取 API Token: Authentik → Admin → Tokens → Create
export AUTHENTIK_TOKEN=your_api_token

# 自动创建所有 Provider + Application
./scripts/authentik-setup.sh

# 预览（不实际创建）
./scripts/authentik-setup.sh --dry-run
```

脚本自动创建以下 OIDC Provider：

| 服务 | Redirect URI | 配置位置 |
|------|-------------|---------|
| Grafana | `grafana.${DOMAIN}/login/generic_oauth` | `stacks/observability/.env` |
| Gitea | `git.${DOMAIN}/user/oauth2/authentik/callback` | `stacks/productivity/.env` |
| Nextcloud | `cloud.${DOMAIN}/apps/user_oidc/code` | `scripts/nextcloud-oidc-setup.sh` |
| Outline | `wiki.${DOMAIN}/auth/oidc.callback` | `stacks/productivity/.env` |
| Open WebUI | `ai.${DOMAIN}/oauth/oidc/callback` | `stacks/ai/.env` |
| Portainer | `portainer.${DOMAIN}` | `stacks/base/.env` |

### 手动设置

1. 登录 `https://auth.${DOMAIN}/if/admin/`
2. Applications → Providers → Create → OAuth2/OpenID Provider
3. 填写 Name, Client ID, Client Secret, Redirect URI
4. Applications → Create → 关联 Provider
5. 将 Client ID/Secret 填入对应服务的 `.env`

## Traefik ForwardAuth

为不原生支持 OIDC 的服务提供认证保护：

```yaml
# 在服务的 docker-compose.yml labels 中添加：
labels:
  - "traefik.http.routers.myservice.middlewares=authentik@file"
```

ForwardAuth 中间件配置在 `config/traefik/dynamic/middlewares.yml`。

## 用户组

| 组 | 权限 |
|----|------|
| `homelab-admins` | 所有服务管理员权限 |
| `homelab-users` | 普通服务访问权限 |
| `media-users` | 仅 Jellyfin/Jellyseerr |

### Grafana 角色映射
- `homelab-admins` → Grafana Admin
- 其他 → Grafana Viewer

## 新增服务接入 Authentik

1. 在 Authentik 创建 OAuth2 Provider (设置 redirect URI)
2. 创建 Application 关联 Provider
3. 在服务中配置 OIDC:
   - Auth URL: `https://auth.${DOMAIN}/application/o/authorize/`
   - Token URL: `https://auth.${DOMAIN}/application/o/token/`
   - Userinfo URL: `https://auth.${DOMAIN}/application/o/userinfo/`
   - Client ID / Secret: 从 Provider 获取
4. 或使用 ForwardAuth 中间件 (无需服务原生支持)

## 环境变量

```env
AUTHENTIK_SECRET_KEY=          # openssl rand -hex 50
AUTHENTIK_BOOTSTRAP_EMAIL=     # 管理员邮箱
AUTHENTIK_BOOTSTRAP_PASSWORD=  # 管理员密码
AUTHENTIK_DB_PASSWORD=         # PostgreSQL 密码
AUTHENTIK_TOKEN=               # API Token (setup 脚本用)
```
