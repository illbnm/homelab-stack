# 🛠️ Productivity Stack — Gitea + Vaultwarden + Outline + Stirling PDF + Excalidraw

> 自托管生产力套件：代码托管、密码管理、团队知识库、PDF 工具、在线白板。

## 服务清单

| 服务 | 镜像 | URL | 用途 |
|------|------|-----|------|
| **Gitea** | `gitea/gitea:1.22.2` | `git.${DOMAIN}` | Git 代码托管 |
| **Vaultwarden** | `vaultwarden/server:1.32.0` | `vault.${DOMAIN}` | 密码管理器 |
| **Outline** | `outlinewiki/outline:0.80.2` | `wiki.${DOMAIN}` | 团队知识库 |
| **Stirling PDF** | `frooodle/s-pdf:0.30.2` | `pdf.${DOMAIN}` | PDF 处理工具 |
| **Excalidraw** | `excalidraw/excalidraw` | `draw.${DOMAIN}` | 在线白板 |

## 前置依赖

- **Base Stack** (Traefik)
- **Databases Stack** (PostgreSQL + Redis)
- **Storage Stack** (MinIO — Outline 文件存储)

## 快速启动

```bash
# 1. 生成密钥
openssl rand -hex 32  # → OUTLINE_SECRET_KEY
openssl rand -hex 32  # → OUTLINE_UTILS_SECRET
openssl rand -base64 48  # → VAULTWARDEN_ADMIN_TOKEN

# 2. 配置 .env
GITEA_DB_PASSWORD=gitea_pass          # 需与 Databases Stack 一致
OUTLINE_DB_PASSWORD=outline_pass      # 需与 Databases Stack 一致
REDIS_PASSWORD=your_redis_pass        # 需与 Databases Stack 一致
VAULTWARDEN_ADMIN_TOKEN=your_token
OUTLINE_SECRET_KEY=your_secret
OUTLINE_UTILS_SECRET=your_utils_secret
SMTP_HOST=smtp.example.com
SMTP_PORT=587
SMTP_USER=user@example.com
SMTP_PASS=your_smtp_password

# 3. 启动
docker compose -f stacks/productivity/docker-compose.yml up -d
```

## Gitea

### 配置
- 数据库: 共享 PostgreSQL (`gitea` database)
- 缓存/Session/Queue: 共享 Redis DB 2
- SSH: 端口 2222 (`git clone ssh://git@git.example.com:2222/user/repo.git`)
- 注册: 默认禁用 (`GITEA_DISABLE_REGISTRATION=true`)

### Authentik OIDC
在 Authentik 创建 OAuth2 Provider，然后在 Gitea → Site Administration → Authentication Sources → Add OAuth2。

### Gitea Actions Runner
```bash
docker run -d --name gitea-runner \
  -e GITEA_INSTANCE_URL=https://git.${DOMAIN} \
  -e GITEA_RUNNER_REGISTRATION_TOKEN=<token> \
  gitea/act_runner:latest
```

## Vaultwarden

### 安全要求
- 必须通过 HTTPS 访问（浏览器扩展要求）
- 公开注册已禁用，仅管理员可邀请
- 管理界面: `https://vault.${DOMAIN}/admin` (需要 ADMIN_TOKEN)

### 浏览器扩展
1. 安装 Bitwarden 浏览器扩展
2. 设置 → Self-hosted → Server URL: `https://vault.${DOMAIN}`
3. 登录

### WebSocket
已配置 Traefik WebSocket 路由，支持实时同步推送。

## Outline

### 配置
- 数据库: 共享 PostgreSQL (`outline` database)
- 缓存: 共享 Redis DB 1
- 文件存储: MinIO (Storage Stack) `outline` bucket

### Authentik OIDC
配置 `.env` 中的 OIDC 变量:
```env
OUTLINE_OIDC_CLIENT_ID=outline
OUTLINE_OIDC_CLIENT_SECRET=your_secret
OUTLINE_OIDC_AUTH_URI=https://auth.example.com/application/o/authorize/
OUTLINE_OIDC_TOKEN_URI=https://auth.example.com/application/o/token/
OUTLINE_OIDC_USERINFO_URI=https://auth.example.com/application/o/userinfo/
```

## Stirling PDF

访问 `https://pdf.${DOMAIN}`，无需登录。

功能: 合并、拆分、旋转、压缩、OCR、水印、加密、转换等。

## Excalidraw

访问 `https://draw.${DOMAIN}`，无需登录。

在线协作白板，支持导出 PNG/SVG。
