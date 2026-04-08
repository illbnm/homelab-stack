# Productivity Stack - 生产力工具栈

自托管生产力套件，包括代码托管、密码管理、团队知识库和 PDF 处理工具。

## 🚀 服务列表

| 服务 | 端口 | 功能 | 访问地址 |
|------|------|------|----------|
| **Gitea** | 3000 | Git 代码托管 | https://gitea.${DOMAIN} |
| **Vaultwarden** | 80 | 密码管理器 (Bitwarden 兼容) | https://vault.${DOMAIN} |
| **Outline** | 3000 | 团队知识库 | https://wiki.${DOMAIN} |
| **Stirling PDF** | 8080 | PDF 处理工具 | https://pdf.${DOMAIN} |
| **MinIO** | 9000/9001 | 对象存储 (Outline 文件存储) | https://minio.${DOMAIN} |

## 📋 前置要求

1. **Traefik** 运行正常（见 `stacks/base/`）
2. **Authentik** 配置完成（见 `stacks/sso/`）
3. **域名 DNS** 已解析到服务器 IP
4. **SMTP 服务器**（可选，用于 Vaultwarden 邮件通知）

## 🔧 快速开始

### 1. 复制环境变量

```bash
cp .env.example .env
```

### 2. 生成密钥

```bash
# 生成强密码（运行多次，填入 .env 对应字段）
openssl rand -base64 32

# 示例：
# GITEA_SECRET_KEY=$(openssl rand -base64 32)
# OUTLINE_SECRET_KEY=$(openssl rand -base64 32)
# OUTLINE_UTILS_SECRET=$(openssl rand -base64 32)
# VAULTWARDEN_ADMIN_TOKEN=$(openssl rand -base64 32)
# MINIO_ROOT_PASSWORD=$(openssl rand -base64 32)
# REDIS_PASSWORD=$(openssl rand -base64 32)
# POSTGRES_SUPER_PASSWORD=$(openssl rand -base64 32)
# GITEA_DB_PASSWORD=$(openssl rand -base64 32)
# OUTLINE_DB_PASSWORD=$(openssl rand -base64 32)
```

### 3. 配置 Authentik OIDC

#### Gitea OIDC 配置

1. 登录 Authentik 管理界面：https://auth.${DOMAIN}
2. 创建 OAuth2/OpenID Provider：
   - Name: `Gitea`
   - Authorization flow: `default-provider-authorization-implicit-consent`
   - Client type: `Confidential`
   - Redirect URIs: `https://gitea.${DOMAIN}/user/oauth2/authentik/callback`
3. 创建 Application：
   - Name: `Gitea`
   - Provider: `Gitea`
   - Launch URL: `https://gitea.${DOMAIN}`

#### Outline OIDC 配置

1. 创建 OAuth2/OpenID Provider：
   - Name: `Outline`
   - Client type: `Confidential`
   - Redirect URIs: `https://wiki.${DOMAIN}/auth/oidc.callback`
2. 创建 Application：
   - Name: `Outline`
   - Provider: `Outline`
3. 复制 Client ID 和 Client Secret 到 `.env`：
   ```bash
   OUTLINE_OIDC_CLIENT_ID=<client-id>
   OUTLINE_OIDC_CLIENT_SECRET=<client-secret>
   ```

### 4. 启动服务

```bash
# 启动所有服务
docker compose up -d

# 查看日志
docker compose logs -f

# 检查服务状态
docker compose ps
```

### 5. 初始化 MinIO Bucket

Outline 需要在 MinIO 中创建 bucket：

```bash
# 安装 MinIO Client (mc)
wget https://dl.min.io/client/mc/release/linux-amd64/mc
chmod +x mc
sudo mv mc /usr/local/bin/

# 配置 mc
mc alias set myminio https://minio.${DOMAIN} ${MINIO_ROOT_USER} ${MINIO_ROOT_PASSWORD}

# 创建 outline bucket
mc mb myminio/outline

# 设置 bucket 策略为私有
mc anonymous set none myminio/outline
```

## 📊 服务配置详解

### Gitea

**特点**：
- 禁用公开注册（仅管理员创建账号）
- 支持 Authentik OIDC 登录
- Gitea Actions Runner 已启用
- 使用共享 PostgreSQL 数据库

**首次登录**：
1. 访问 https://gitea.${DOMAIN}
2. 点击 "Sign in with Authentik"
3. 在 Authentik 中授权
4. 自动创建 Gitea 账号

**创建管理员账号**：
```bash
docker exec -u git gitea gitea admin user create --username admin --password ${PASSWORD} --email admin@${DOMAIN} --admin
```

### Vaultwarden

**特点**：
- Bitwarden 完全兼容
- 禁用公开注册（仅管理员邀请）
- 支持 SMTP 邮件通知
- HTTPS 必须（浏览器扩展要求）

**首次登录**：
1. 访问 https://vault.${DOMAIN}
2. 点击 "Create Account"（需管理员邀请）
3. 或访问 https://vault.${DOMAIN}/admin 使用 `VAULTWARDEN_ADMIN_TOKEN` 登录

**管理员邀请用户**：
```bash
# 登录管理界面：https://vault.${DOMAIN}/admin
# 使用 VAULTWARDEN_ADMIN_TOKEN
# 在 "Users" 页面邀请用户
```

**浏览器扩展配置**：
1. 安装 Bitwarden 浏览器扩展
2. 设置 → 自定义服务器
3. 服务器 URL: `https://vault.${DOMAIN}`
4. 登录

### Outline

**特点**：
- 使用共享 PostgreSQL + Redis
- MinIO 作为文件存储后端
- 支持 Authentik OIDC 登录
- Markdown 编辑器 + 实时协作

**首次登录**：
1. 访问 https://wiki.${DOMAIN}
2. 点击 "Continue with Authentik"
3. 在 Authentik 中授权
4. 自动创建 Outline 账号

**配置文件存储**：
Outline 使用 MinIO 存储附件和图片：
- Bucket: `outline`
- 访问方式: S3 API
- 权限: 私有

### Stirling PDF

**特点**：
- 无需登录（公开访问）
- 支持 50+ PDF 操作
- 无外部依赖
- 轻量级（基于 Apache PDFBox）

**可用功能**：
- 合并/拆分 PDF
- 旋转/裁剪
- 页码/水印
- PDF 转 Word/Excel/PPT
- 图片转 PDF
- 签名/表单
- OCR（需额外配置）

**访问方式**：
直接访问 https://pdf.${DOMAIN}，无需登录。

## 🔒 安全配置

### 1. 防火墙

仅开放必要端口：
```bash
# 仅 Traefik 端口对外
ufw allow 80/tcp
ufw allow 443/tcp
# 内部服务端口不对外
```

### 2. 定期备份

```bash
# 备份 PostgreSQL
docker exec productivity-postgres pg_dumpall -U postgres > backup_$(date +%Y%m%d).sql

# 备份 MinIO
mc mirror myminio/outline ./minio-backup/

# 备份 Vaultwarden
docker cp vaultwarden:/data ./vaultwarden-backup/
```

### 3. 监控

使用 `stacks/monitoring/` 中的 Prometheus + Grafana：
- 监控容器健康状态
- 监控数据库连接数
- 监控存储使用情况

## 🛠️ 故障排查

### Gitea 无法启动

```bash
# 检查数据库连接
docker exec productivity-postgres psql -U postgres -c "\l"

# 检查日志
docker logs gitea

# 常见问题：
# 1. 数据库密码错误 → 检查 .env
# 2. SECRET_KEY 未设置 → 生成并填入 .env
# 3. OIDC 配置错误 → 检查 Authentik Provider
```

### Vaultwarden 浏览器扩展无法连接

```bash
# 检查 HTTPS 证书
curl -I https://vault.${DOMAIN}

# 常见问题：
# 1. 证书未签发 → 检查 Traefik logs
# 2. 域名未解析 → 检查 DNS
# 3. 端口未开放 → 检查防火墙
```

### Outline 文件上传失败

```bash
# 检查 MinIO 连接
mc admin info myminio

# 检查 bucket 权限
mc anonymous get myminio/outline

# 常见问题：
# 1. bucket 未创建 → 运行 mc mb
# 2. 权限错误 → 设置为 none
# 3. MinIO 密码错误 → 检查 .env
```

## 📚 相关文档

- [Gitea 文档](https://docs.gitea.io/)
- [Vaultwarden Wiki](https://github.com/dani-garcia/vaultwarden/wiki)
- [Outline 文档](https://docs.getoutline.com/)
- [Stirling PDF](https://github.com/Stirling-Tools/Stirling-PDF)
- [MinIO 文档](https://min.io/docs/minio/linux/)

## 🔄 更新

```bash
# 拉取最新镜像
docker compose pull

# 重新创建容器
docker compose up -d

# 清理旧镜像
docker image prune -f
```

## 🗑️ 卸载

```bash
# 停止并删除容器
docker compose down

# 删除数据卷（⚠️ 不可恢复）
docker compose down -v

# 删除镜像
docker rmi $(docker images 'gitea/*' 'vaultwarden/*' 'outlinewiki/*' 'frooodle/*' -q)
```

## 📝 许可证

- Gitea: MIT
- Vaultwarden: AGPL-3.0
- Outline: Business Source License 1.1
- Stirling PDF: MPL-2.0
- MinIO: AGPL-3.0
