# Productivity Stack

> Gitea + Vaultwarden + Outline + Stirling PDF + Excalidraw

生产力工具栈：代码托管、密码管理、团队知识库、PDF处理、在线白板。

## 📦 服务列表

| 服务 | 镜像 | 端口 | 说明 |
|------|------|------|------|
| Gitea | gitea/gitea:1.22.2 | 3000 | Git代码托管，支持Actions runner |
| Vaultwarden | vaultwarden/server:1.32.0 | 80 | Bitwarden兼容密码管理器 |
| Outline | outlinewiki/outline:0.80.2 | 3000 | 团队知识库，支持OIDC |
| Stirling PDF | frooodle/s-pdf:0.30.2 | 8080 | PDF处理工具箱 |
| Excalidraw | excalidraw/excalidraw:latest-sha | 80 | 在线协作白板 |

## 🌐 访问地址

| 服务 | URL |
|------|-----|
| Gitea | https://git.${DOMAIN} |
| Vaultwarden | https://vault.${DOMAIN} |
| Outline | https://docs.${DOMAIN} |
| Stirling PDF | https://pdf.${DOMAIN} |
| Excalidraw | https://draw.${DOMAIN} |

## 🚀 快速启动

```bash
# 1. 进入目录
cd stacks/productivity

# 2. 复制并编辑环境变量
cp .env.example .env
nano .env

# 3. 启动服务
docker compose up -d

# 4. 查看服务状态
docker compose ps
```

## 🔧 前置要求

必须先启动以下栈：

```bash
# 1. 基础架构（数据库 + Redis + Traefik）
docker compose -f ../databases/docker-compose.yml up -d
docker compose -f ../base/docker-compose.yml up -d

# 2. SSO认证（Authentik OIDC）
docker compose -f ../sso/docker-compose.yml up -d
# 运行Authentik配置脚本
../../scripts/setup-authentik.sh

# 3. 对象存储（MinIO，Outline文件存储后端）
docker compose -f ../storage/docker-compose.yml up -d
```

## ⚙️ 配置说明

### Authentik OIDC 配置

在Authentik中为以下服务创建OAuth2 Application：

**Gitea:**
- Name: `Gitea`
- Redirect URIs: `https://git.${DOMAIN}/user/oauth2/Authentik/callback`
- Provider: Authentik

**Outline:**
- Name: `Outline`
- Redirect URIs: `https://docs.${DOMAIN}/auth/authentik.callback`
- Provider: Authentik

### MinIO Bucket

Outline使用MinIO作为文件存储后端。首次使用前需要创建`outline` bucket：

```bash
# 使用MinIO Console或mc客户端
mc mb minio/outline
# 设置公开读取策略（用于图片访问）
mc anonymous set download minio/outline
```

### Gitea Actions Runner

Gitea Actions runner已内置启用。runner通过Gitea UI注册：

1. 以管理员登录 Gitea → Settings → Actions → Runners
2. 点击"Create Runner"，获取注册令牌
3. Runner会自动连接（通过卷挂载的Docker socket）

### Vaultwarden SMTP

邮件通知需要配置SMTP。Vaultwarden管理界面：
`https://vault.${DOMAIN}/admin`

- 仅管理员可邀请新用户
- 浏览器扩展通过HTTPS连接

## 🔐 安全建议

- [ ] 首次启动后立即更改所有默认密码
- [ ] Vaultwarden的`ADMIN_TOKEN`使用强随机值：`openssl rand -base64 48`
- [ ] Gitea的`GITEA_OAUTH2_JWT_SECRET`使用：`openssl rand -base64 32`
- [ ] Outline的密钥使用：`openssl rand -hex 32`
- [ ] 确保所有服务通过HTTPS访问（Traefik自动配置）
- [ ] Vaultwarden管理界面仅通过HTTPS访问

## 🔄 备份

关键数据卷：

```bash
docker compose stop
# 备份数据卷
docker run --rm -v homelab_stack_productivity_gitea-data:/data -v $(pwd):/backup ubuntu tar czf /backup/gitea-data.tar.gz /data
docker run --rm -v homelab_stack_productivity_vaultwarden-data:/data -v $(pwd):/backup ubuntu tar czf /backup/vaultwarden-data.tar.gz /data
docker run --rm -v homelab_stack_productivity_outline-data:/data -v $(pwd):/backup ubuntu tar czf /backup/outline-data.tar.gz /data
docker run --rm -v homelab_stack_productivity_excalidraw-data:/data -v $(pwd):/backup ubuntu tar czf /backup/excalidraw-data.tar.gz /data
docker run --rm -v homelab_stack_productivity_stirling-pdf-data:/data -v $(pwd):/backup ubuntu tar czf /backup/stirling-pdf-data.tar.gz /data
# 重启服务
docker compose start
```

## 🐛 故障排查

### Gitea Actions不执行
- 检查Docker socket是否正确挂载
- 确认runner已在Settings → Actions中注册

### Outline上传图片失败
- 确认MinIO bucket `outline`已创建
- 检查MinIO凭证是否正确配置在Outline环境变量中
- 确认网络连通性（Outline容器能否访问`s3.${DOMAIN}`）

### Vaultwarden浏览器扩展无法连接
- 确认使用HTTPS访问Vaultwarden
- 检查`DOMAIN`环境变量配置正确
- 浏览器扩展设置中的Vault URI必须为`https://vault.${DOMAIN}`

### Stirling PDF功能性受限
- 某些高级功能（如OCR）需要额外依赖
- 确认`JAVA_OPTS`内存配置足够（建议2g+）
