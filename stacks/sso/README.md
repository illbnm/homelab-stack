# SSO Stack — 统一身份认证 🔐

基于 **Authentik** 的 OIDC/SAML 统一身份认证系统，为整个 Homelab 提供单点登录（SSO）服务。

---

## 🎯 功能概览

| 组件 | 用途 | 说明 |
|------|------|------|
| **Authentik Server** | OIDC/SAML 身份提供商 | 核心认证服务 |
| **Authentik Worker** | 后台任务处理 | 异步任务（邮件、清理等）|
| **PostgreSQL** | 专用数据库 | 存储用户、应用、会话 |
| **Redis** | 缓存层 | 会话缓存、限流 |

**支持的服务 (OIDC 集成)**:
- ✅ Grafana
- ✅ Gitea
- ✅ Nextcloud
- ✅ Outline
- ✅ Open WebUI
- ✅ Portainer (通过 ForwardAuth)
- 🔄 轻松添加新服务

**用户组设计**:
```
homelab-admins    → 管理员组 (访问所有管理界面)
homelab-users     → 普通用户组 (访问常用服务)
media-users       → 仅媒体服务 (Jellyfin/Jellyseerr)
```

---

## 🚀 快速开始

### 1. 前置条件

- ✅ **Base Stack** 已部署（Traefik 网络 `proxy` + `internal`）
- ✅ 已设置 `DOMAIN` 环境变量
- ✅ 可访问的域名: `auth.${DOMAIN}` 指向服务器

### 2. 配置环境变量

```bash
cd stacks/sso
cp .env.example .env
vim .env  # 修改以下必需变量
```

**必需变量**:

```bash
# 域名
DOMAIN=auth.example.com  # 改为你的域名

# 随机密钥 (生成方法: openssl rand -base64 60)
AUTHENTIK_SECRET_KEY=your-secret-key-here

# 管理员账户 (首次启动创建)
AUTHENTIK_BOOTSTRAP_EMAIL=admin@example.com
AUTHENTIK_BOOTSTRAP_PASSWORD=your-strong-password

# 数据库密码
AUTHENTIK_DB_PASSWORD=your-db-password
```

### 3. 启动服务

```bash
docker compose up -d
```

等待所有容器健康:

```bash
docker compose ps
```

预期:
```
NAME                IMAGE                                       STATUS          PORTS
authentik-postgres  postgres:16.4-alpine                        Up (healthy)
authentik-redis     redis:7.4.0-alpine                          Up (healthy)
authentik-server    ghcr.io/goauthentik/server:2024.8.3       Up (healthy)
authentik-worker    ghcr.io/goauthentik/server:2024.8.3       Up (healthy)
```

### 4. 访问 Web UI

打开: https://auth.${DOMAIN}

首次登录使用 `AUTHENTIK_BOOTSTRAP_EMAIL` 和 `AUTHENTIK_BOOTSTRAP_PASSWORD`。

---

## 🔧 自动配置 OIDC Providers

项目提供了 `scripts/authentik-setup.sh` 脚本，自动为所有服务创建 OIDC Provider 和 Application。

### 使用方法

```bash
cd stacks/sso
./scripts/authentik-setup.sh --dry-run  # 预览
./scripts/authentik-setup.sh           # 实际执行
```

### 脚本功能

1. **自动生成** OAuth2 Provider (Client ID + Secret)
2. **自动创建** Application 并绑定 Provider
3. **自动创建/分配** 用户组:
   - `homelab-admins` → Portainer, Grafana admin
   - `homelab-users` → Gitea, Nextcloud, Outline, Open WebUI
   - `media-users` → Jellyfin, Jellyseerr
4. **输出配置详情** (Client ID, Secret, Redirect URI)

### 示例输出

```
▶ Grafana
  创建 Provider: OK (PK: 12345678...)
  创建 Application: OK
  用户组: homelab-admins

▶ Gitea
  创建 Provider: OK (PK: 87654321...)
  创建 Application: OK
  用户组: homelab-users
...
```

---

## 🌐 各服务集成配置

### Grafana (OIDC)

**配置位置**: `config/grafana/grafana.ini`

```ini
[auth.generic_oauth]
enabled = true
name = Authentik
allow_sign_up = true
client_id = <从 authentik-setup.sh 输出获取>
client_secret = <从 authentik-setup.sh 输出获取>
scopes = openid profile email
auth_url = https://auth.${DOMAIN}/application/o/authorize/
token_url = https://auth.${DOMAIN}/application/o/token/
api_url = https://auth.${DOMAIN}/application/v1/users/@me
redirect_uri = https://grafana.${DOMAIN}/login/generic_oauth
```

重启 Grafana 后，登录页面会出现 "Authentik" 登录选项。

### Gitea (OIDC)

**配置位置**: `stacks/productivity/.env` (或 Gitea 配置文件)

```bash
# OIDC 设置
OIDC_ENABLED=true
OIDC_NAME=Authentik
OIDC_DISPLAY_NAME=Authentik SSO
OIDC_PROVIDER=https://auth.${DOMAIN}
OIDC_CLIENT_ID=<Client ID from script>
OIDC_CLIENT_SECRET=<Client Secret from script>
OIDC_SCOPES=openid profile email
OIDC_REDIRECT=https://gitea.${DOMAIN}/user/oauth/authentik/callback
OIDC_CREATE_USER=true
OIDC_UPDATE_PROFILE=true
```

### Nextcloud (OIDC)

需要安装 **Social login** 或 **OIDC** 插件。

**脚本集成**: `scripts/nextcloud-oidc-setup.sh`

```bash
cd stacks/productivity  # 或其他包含 Nextcloud 的栈
../sso/scripts/nextcloud-oidc-setup.sh --domain ${DOMAIN} --client-id <ID> --client-secret <Secret>
```

手动配置 (admin 界面):
- 设置 → 管理 → OAuth 2.0
- 名称: `authentik`
- 客户端 ID/Secret: 从 script 输出获取
- 授权端点: `https://auth.${DOMAIN}/application/o/authorize/`
- Token 端点: `https://auth.${DOMAIN}/application/o/token/`
- 用户信息端点: `https://auth.${DOMAIN}/application/v1/users/@me`

### Outline (OIDC)

**配置位置**: `stacks/productivity/.env`

```bash
# OIDC 配置
OIDC_ENABLED=true
OIDC_ISSUER=https://auth.${DOMAIN}/application/o/oidc/
OIDC_CLIENT_ID=<Client ID>
OIDC_CLIENT_SECRET=<Client Secret>
OIDC_SCOPES=openid email profile
```

### Open WebUI (OIDC)

**配置位置**: `stacks/ai/.env`

```bash
# OIDC 配置
OIDC_ENABLED=true
OIDC_ISSUER=https://auth.${DOMAIN}/application/o/oidc/
OIDC_CLIENT_ID=<Client ID>
OIDC_CLIENT_SECRET=<Client Secret>
OIDC_REDIRECT_URI=https://openwebui.${DOMAIN}/api/auth/oauth2/callback
```

### Portainer (ForwardAuth)

Portainer 不支持原生 OIDC，使用 Traefik ForwardAuth。

**配置位置**: `stacks/base/.env` (Portainer 配置)

```bash
# 在 Portainer 容器 labels 中添加:
TRAEFIK_MIDDLEWARES=auth@docker
```

**Traefik 配置**: `config/traefik/dynamic/middlewares.yml`

```yaml
http:
  middlewares:
    auth:
      forwardAuth:
        address: "http://authentik-server:9000/outpost.goauthentik.io/auth/traefik"
        trustForwardHeader: true
        authResponseHeaders:
          - "X-authentik-username"
          - "X-authentik-groups"
```

Portainer 配置补丁示例 (`stacks/base/docker-compose.yml` 或 overlay):

```yaml
portainer:
  labels:
    - "traefik.enable=true"
    - "traefik.http.routers.portainer.rule=Host(`portainer.${DOMAIN}`)"
    - "traefik.http.routers.portainer.entrypoints=websecure"
    - "traefik.http.routers.portainer.tls=true"
    - "traefik.http.routers.portainer.middlewares=authentik-forward-auth@docker"
```

---

## 🛠️ 用户组管理

Authentik 预定义以下组（`scripts/authentik-setup.sh` 自动创建）：

| 组名 | 权限 | 成员示例 |
|------|------|----------|
| `homelab-admins` | 所有服务管理权限 | 管理员账号 |
| `homelab-users` | 常用服务 (Gitea, Nextcloud, Outline, Open WebUI) | 开发者、家庭成员 |
| `media-users` | 仅媒体服务 (Jellyfin, Jellyseerr) | 普通家庭成员 |

**添加用户到组**:

1. 登录 Authentik Web UI
2. Users → 选择用户 → Groups
3. 添加 `homelab-users` 或 `media-users`
4. 保存

---

## 🔄 Traefik ForwardAuth 配置

对于不支持 OIDC 的服务（如 Portainer），使用 ForwardAuth 中间件。

**配置文件**: `config/traefik/dynamic/middlewares.yml`

```yaml
http:
  middlewares:
    authentik-forward-auth:
      forwardAuth:
        address: "http://authentik-server:9000/outpost.goauthentik.io/auth/traefik"
        trustForwardHeader: true
        authResponseHeaders:
          - "X-authentik-username"
          - "X-authentik-groups"
          - "X-authentik-email"
```

**使用示例**: 在任何服务的 docker-compose.yml 中:

```yaml
labels:
  - "traefik.http.routers.myapp.middlewares=authentik-forward-auth@docker"
```

---

## ✅ 验收检查清单

完成以下所有项目才能申请赏金：

- [x] Authentik 部署完成，Web UI 可访问 (`https://auth.${DOMAIN}`)
- [x] 管理员可登录 (使用 `.env` 中的 bootstrap 凭据)
- [x] `scripts/authentik-setup.sh` 运行成功，自动创建所有 Provider
- [ ] **Grafana**: 可用 Authentik 账号登录
- [ ] **Gitea**: 可用 Authentik 账号登录 (OIDC 登录按钮)
- [ ] **Nextcloud**: 可用 Authentik 账号登录 (Social login)
- [ ] **Outline**: 可用 Authentik 账号登录
- [ ] **Open WebUI**: 可用 Authentik 账号登录
- [ ] **Portainer**: 自动跳转 Authentik 登录，登录后允许访问
- [ ] **用户组隔离**:
  - [ ] `media-users` 组用户无法访问 Grafana admin
  - [ ] `homelab-admins` 可访问所有管理界面
- [ ] README 包含新增服务接入 Authentik 的完整教程
- [ ] 提供 **截图 + 配置文件** 作为验收证明

---

## 🧪 测试流程

### 1. 测试 Authentik 基本功能

```bash
# 检查容器状态
docker compose ps

# 查看日志
docker compose logs -f authentik-server
```

访问 https://auth.${DOMAIN}，确认登录正常。

### 2. 测试自动配置脚本

```bash
cd stacks/sso
./scripts/authentik-setup.sh --dry-run  # 预览
./scripts/authentik-setup.sh           # 执行
```

登录 Authentik Web UI → Applications，查看是否已创建所有应用。

### 3. 测试各服务 OIDC 集成

按以下顺序测试（建议）：

1. **Grafana** - 最直接，登录后看到用户名同步
2. **Gitea** - 测试 OIDC 登录按钮
3. **Nextcloud** - 测试 Social login 流程
4. **Outline** - 测试 OIDC 登录
5. **Open WebUI** - 测试 OIDC 登录
6. **Portainer** - 测试 ForwardAuth 拦截

**测试要点**:
- ✅ 点击 "Login with Authentik" 能正常跳转
- ✅ 输入 Authentik 账号密码后能返回目标服务
- ✅ 用户名/邮箱正确同步到目标服务
- ✅ 已登录状态能保持 (session)
- ✅ 不同组用户权限正确 (媒体用户看不到 admin 界面)

---

## 📝 提交验收材料

申请验收时请在 GitHub Issue 评论中提供:

1. **Authentik Web UI 截图**:
   - Applications 列表 (显示所有创建的 App)
   - Users 列表 (显示组分配)
2. **各服务登录验证截图**:
   - Grafana 登录后显示用户名
   - Gitea 登录后显示用户信息
   - Nextcloud 用户设置显示 OIDC 来源
   - Outline 用户资料
   - Open WebUI 界面
   - Portainer 登录拦截 → Authentik → 成功进入
3. **配置文件**:
   - `config/grafana/grafana.ini` (OIDC 部分)
   - `stacks/productivity/.env` (Gitea/Outline OIDC 配置)
   - `config/traefik/dynamic/middlewares.yml` (ForwardAuth 配置)
4. **用户组测试**:
   - 证明 `media-users` 组用户无法访问 Grafana admin 的截图
   - 证明 `homelab-admins` 可访问所有界面的截图

---

## 🔐 安全建议

1. **强密码**: `.env` 中的 `AUTHENTIK_BOOTSTRAP_PASSWORD` 必须为高强度密码
2. **HTTPS**: 确保 `auth.${DOMAIN}` 使用有效 HTTPS 证书 (Traefik 自动提供)
3. **防火墙**: 仅开放 443 端口，9000 端口仅内网访问
4. **定期备份**: 备份 `authentik-data` 卷和 PostgreSQL 数据
5. **审计日志**: 定期查看 Authentik → Security → Audit Log
6. **MFA 强制**: 可为敏感服务启用 MFA (Authentik 支持的 TOTP/WebAuthn)

---

## 🛠️ 运维命令

```bash
# 查看所有容器日志
docker compose logs -f

# 重启 Authentik
docker compose restart authentik-server authentik-worker

# 重置管理员密码
docker compose exec authentik-server authentik-cli bootstrap-password -- administrator

# 备份数据库
docker compose exec postgres pg_dump -U authentik authentik > backup-$(date +%Y%m%d).sql

# 恢复数据库
docker compose exec -T postgres psql -U authentik authentik < backup-20260318.sql

# 查看 API 健康
curl -H "Authorization: Bearer ${AUTHENTIK_BOOTSTRAP_TOKEN}" "${AUTHENTIK_URL}/api/v3/application/adapters/oauth2/"
```

---

## 🎯 设计决策

### 为什么用 Authentik 而不是 Keycloak?

| 特性 | Authentik | Keycloak |
|------|-----------|----------|
| 部署复杂度 | Docker 部署简单 | Java 环境，内存占用高 |
| 现代化程度 | 现代 UI/UX (Vue.js) | 传统 UI |
| OIDC 支持 | 完整 OIDC/SAML | 完整 OIDC/SAML |
| 社区活跃度 | 活跃，快速迭代 | 成熟但较慢 |
| 资源占用 | ~500MB RAM | ~2GB+ RAM |

Authentik 更适合资源受限的 Homelab 环境。

### 为什么服务穿透需要 ForwardAuth?

部分服务 (Portainer) 不支持原生 OIDC，但可以用 Traefik 的 `forwardAuth` 中间件实现:

```
用户 → Portainer → Traefik 拦截 → Authentik 认证 → 返回 Portainer
```

这样无需要求每个服务都实现 OIDC 客户端。

---

## 📚 参考资源

- [Authentik 官方文档](https://docs.goauthentik.io/)
- [OIDC 协议规范](https://openid.net/connect/)
- [Traefik ForwardAuth 文档](https://doc.traefik.io/traefik/middlewares/forwardauth/)
- [homelab-stack 主仓库](https://github.com/illbnm/homelab-stack)

---

**Atlas 签名** 🤖💰  
*"Secure identities, unified access."*

---

## 📄 License

遵循原 homelab-stack 项目的许可证。