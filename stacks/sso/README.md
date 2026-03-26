# SSO Stack — Authentik 统一身份认证

基于 [Authentik](https://goauthentik.io/) 的统一身份认证系统，为所有服务提供单点登录（SSO）。

## 架构

```
┌─────────────────────────────────────────────────────────┐
│                      浏览器                              │
└─────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────┐
│                  Traefik (443)                          │
│   ForwardAuth 中间件 → authentik-server:9000            │
└─────────────────────────────────────────────────────────┘
                            │
        ┌───────────────────┼───────────────────┐
        ▼                   ▼                   ▼
┌───────────────┐   ┌───────────────┐   ┌───────────────┐
│   Authentik   │   │   Grafana     │   │    Gitea      │
│   (OIDC)      │   │   (OIDC)      │   │    (OIDC)     │
└───────────────┘   └───────────────┘   └───────────────┘
        │                   │                   │
        │                   ▼                   ▼
        │           ┌───────────────┐   ┌───────────────┐
        │           │   Outline     │   │  Nextcloud    │
        │           │   (OIDC)      │   │   (OIDC)      │
        │           └───────────────┘   └───────────────┘
        │
        ▼
┌───────────────┐   ┌───────────────┐
│ PostgreSQL    │   │     Redis     │
│  (数据存储)    │   │   (缓存/队列)   │
└───────────────┘   └───────────────┘
```

## 服务列表

| 服务 | 镜像 | 端口 | 说明 |
|------|------|------|------|
| authentik-server | `ghcr.io/goauthentik/server:2024.8.3` | 9000/9443 | Web UI + API + OIDC 端点 |
| authentik-worker | `ghcr.io/goauthentik/server:2024.8.3` | — | 后台任务（邮件、通知） |
| postgresql | `postgres:16-alpine` | 5432 (内部) | Authentik 数据库 |
| redis | `redis:7-alpine` | 6379 (内部) | 会话缓存 + 任务队列 |

## 前提条件

- 基础栈已运行（`stacks/base/` — Traefik + proxy 网络）
- 域名 DNS 已配置指向服务器
- 端口 80 + 443 开放

## 快速开始

### 1. 配置环境变量

```bash
cd stacks/sso
cp .env.example .env
nano .env  # 填写所有 REQUIRED 值
```

### 2. 生成密钥

```bash
# 生成随机密钥
export AUTHENTIK_SECRET_KEY=$(openssl rand -base64 32)
export AUTHENTIK_POSTGRES_PASSWORD=$(openssl rand -hex 16)
export AUTHENTIK_REDIS_PASSWORD=$(openssl rand -hex 16)

# 写入 .env
sed -i "s|^AUTHENTIK_SECRET_KEY=.*|AUTHENTIK_SECRET_KEY=$AUTHENTIK_SECRET_KEY|" .env
sed -i "s|^AUTHENTIK_POSTGRES_PASSWORD=.*|AUTHENTIK_POSTGRES_PASSWORD=$AUTHENTIK_POSTGRES_PASSWORD|" .env
sed -i "s|^AUTHENTIK_REDIS_PASSWORD=.*|AUTHENTIK_REDIS_PASSWORD=$AUTHENTIK_REDIS_PASSWORD|" .env
```

### 3. 启动栈

```bash
docker compose up -d

# 等待服务就绪（约 60 秒）
docker compose ps
```

### 4. 创建 OIDC Provider

```bash
# 在项目根目录运行
../../scripts/setup-authentik.sh
```

脚本会自动为以下服务创建 Provider：
- Grafana
- Gitea
- Outline
- Portainer
- Nextcloud
- Open WebUI

## 环境变量

| 变量 | 必填 | 说明 |
|------|------|------|
| `AUTHENTIK_SECRET_KEY` | ✅ | 随机密钥 — `openssl rand -base64 32` |
| `AUTHENTIK_POSTGRES_PASSWORD` | ✅ | PostgreSQL 密码 |
| `AUTHENTIK_REDIS_PASSWORD` | ✅ | Redis 密码 |
| `AUTHENTIK_BOOTSTRAP_EMAIL` | ✅ | 初始管理员邮箱 |
| `AUTHENTIK_BOOTSTRAP_PASSWORD` | ✅ | 初始管理员密码 |
| `AUTHENTIK_BOOTSTRAP_TOKEN` | ✅ | API Token（setup 脚本需要） |
| `AUTHENTIK_DOMAIN` | ✅ | 例如 `auth.yourdomain.com` |

## 获取 AUTHENTIK_BOOTSTRAP_TOKEN

1. 首次登录 Authentik Web UI（https://auth.${DOMAIN}）
2. 进入 Settings → Token
3. 点击 "Create Token"
4. 复制生成的 Token 并填入 `.env`

## 用户组

预定义以下用户组用于权限控制：

| 组名 | 说明 |
|------|------|
| `homelab-admins` | 管理员组，访问所有服务管理界面 |
| `homelab-users` | 普通用户组，访问普通服务 |
| `media-users` | 媒体用户组，仅访问 Jellyfin/Jellyseerr |

### 在 Authentik 中管理用户组

1. 登录 Authentik：https://auth.${DOMAIN}
2. 进入 Directory → Groups
3. 创建或编辑组，添加成员

## 集成其他服务

### OIDC 集成（推荐）

适用于原生支持 OAuth2/OIDC 的服务。运行 `../../scripts/setup-authentik.sh` 自动创建 Provider。

支持原生 OIDC 的服务：
- Grafana
- Gitea（通过 Web UI 配置）
- Outline
- Nextcloud（Social Login App）
- Open WebUI
- Portainer

详细集成说明见 [docs/sso-integration.md](../../docs/sso-integration.md)

### ForwardAuth 集成

适用于不原生支持 OIDC 的服务。在服务的 `docker-compose.yml` 中添加 Traefik label：

```yaml
labels:
  - "traefik.http.routers.<name>.middlewares=authentik@file"
```

例如为 Jellyfin 添加 SSO 保护：

```yaml
services:
  jellyfin:
    # ...
    labels:
      - traefik.enable=true
      - "traefik.http.routers.jellyfin.rule=Host(`jellyfin.${DOMAIN}`)"
      - traefik.http.routers.jellyfin.entrypoints=websecure
      - "traefik.http.routers.jellyfin.middlewares=authentik@file"
```

## 健康检查

```bash
# 检查所有容器状态
docker compose ps

# 检查 Authentik API
curl -sf https://auth.${DOMAIN}/-/health/ready/ && echo OK

# 检查管理界面
curl -sf https://auth.${DOMAIN}/if/admin/ -o /dev/null && echo OK
```

## 故障排除

| 症状 | 解决方法 |
|------|----------|
| 容器立即退出 | 检查 `AUTHENTIK_SECRET_KEY` 是否设置且非空 |
| 数据库连接拒绝 | 等待 30 秒让 PostgreSQL 初始化；检查密码是否匹配 |
| OIDC 重定向错误 | 确保 Authentik Provider 的回调地址与服务配置完全一致 |
| ForwardAuth 循环 | 确保使用内部 hostname `authentik-server:9000` 而非公网域名 |
| `ghcr.io` 拉取超时 | 在 docker-compose.yml 中切换到 CN 镜像 |

## CN 镜像

如果 `ghcr.io` 不可访问，编辑 `docker-compose.yml` 取消注释 CN 镜像行：

```yaml
# image: swr.cn-north-4.myhuaweicloud.com/ddn-k8s/ghcr.io/goauthentik/server:2024.8.3
```

## 更多信息

- [Authentik 官方文档](https://docs.goauthentik.io/)
- [SSO 集成指南](../../docs/sso-integration.md)
