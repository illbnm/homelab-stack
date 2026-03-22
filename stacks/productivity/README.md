# 🚀 Productivity Stack - 生产力工具栈

完整的自托管生产力套件，包含代码托管、密码管理、团队知识库、PDF 工具和在线白板。

## 📋 服务概览

| 服务 | 访问地址 | 功能 |
|------|----------|------|
| **Gitea** | `https://git.${DOMAIN}` | Git 代码托管，支持 Actions CI/CD |
| **Vaultwarden** | `https://vault.${DOMAIN}` | 密码管理器 (Bitwarden 兼容) |
| **Outline** | `https://docs.${DOMAIN}` | 团队知识库/Wiki |
| **Stirling PDF** | `https://pdf.${DOMAIN}` | PDF 处理工具 (合并/分割/转换等) |
| **Excalidraw** | `https://draw.${DOMAIN}` | 在线白板/绘图工具 |

## 🎯 特性

- ✅ **Gitea** - 轻量级 Git 服务，支持 OIDC 登录、Actions 自动化、禁用公开注册
- ✅ **Vaultwarden** - Bitwarden 兼容，支持浏览器扩展、HTTPS 加密、SMTP 邀请
- ✅ **Outline** - 现代化知识库，支持 Markdown、实时协作、MinIO 存储
- ✅ **Stirling PDF** - 40+ PDF 工具，无需上传到云端
- ✅ **Excalidraw** - 手绘风格白板，支持协作绘图
- ✅ **Traefik 集成** - 自动 HTTPS 证书、反向代理
- ✅ **Authentik OIDC** - 统一身份认证

## 📋 依赖服务

本栈依赖以下共享服务（在 `base` 或 `databases` 栈中定义）：

- **homelab-postgres** - PostgreSQL 数据库
- **homelab-redis** - Redis 缓存
- **homelab-minio** - MinIO 对象存储
- **Traefik** - 反向代理和 HTTPS

## 🚀 快速开始

### 1. 确保依赖服务运行

```bash
# 启动基础服务
cd ../base
docker compose up -d

# 启动数据库服务
cd ../databases
docker compose up -d

# 检查服务状态
docker compose ps
```

### 2. 配置环境变量

```bash
# 复制示例配置
cp .env.example .env

# 编辑配置
nano .env
```

**必须修改的配置：**
- `DOMAIN` - 你的域名
- `AUTHENTIK_DOMAIN` - Authentik 域名
- `GITEA_DB_PASSWORD` - Gitea 数据库密码
- `VAULTWARDEN_DB_PASSWORD` - Vaultwarden 数据库密码
- `OUTLINE_DB_PASSWORD` - Outline 数据库密码
- `REDIS_PASSWORD` - Redis 密码
- `MINIO_ROOT_PASSWORD` - MinIO 密码
- `VAULTWARDEN_ADMIN_TOKEN` - Vaultwarden 管理员令牌
- `OUTLINE_SECRET_KEY` - Outline 密钥 (32 字符)
- `OUTLINE_UTILS_SECRET` - Outline 工具密钥 (32 字符)
- `SMTP_*` - SMTP 邮件配置

**生成安全密钥：**
```bash
# 生成 32 字符随机密钥
openssl rand -hex 16

# 生成 UUID
uuidgen

# 生成强密码
openssl rand -base64 32
```

### 3. 启动服务

```bash
# 启动生产力工具栈
docker compose up -d

# 查看状态
docker compose ps

# 查看日志
docker compose logs -f
```

### 4. 访问服务

启动成功后，通过以下地址访问：

- Gitea: `https://git.yourdomain.com`
- Vaultwarden: `https://vault.yourdomain.com`
- Outline: `https://docs.yourdomain.com`
- Stirling PDF: `https://pdf.yourdomain.com`
- Excalidraw: `https://draw.yourdomain.com`

## 🔧 服务配置指南

### 1. Gitea 配置

#### 首次设置
1. 访问 `https://git.yourdomain.com`
2. 创建管理员账户
3. 配置站点设置

#### 配置 Authentik OIDC
1. 在 Authentik 创建 OAuth2 Provider
   - Provider type: OAuth2
   - Name: Gitea
   - Client ID/Secret: 记录下来
   - Redirect URI: `https://git.yourdomain.com/user/oauth2/Authentik/callback`
2. Gitea 管理后台 → 认证源 → 添加 OAuth2
3. 填写 Authentik 提供的 Client ID/Secret
4. 测试登录

#### 配置 Actions Runner
1. Gitea 管理后台 → Actions → 添加 Runner
2. 复制注册令牌到 `.env`:
   ```
   GITEA_RUNNER_REGISTRATION_TOKEN=your_token
   ```
3. 重启 Runner 服务:
   ```bash
   docker compose restart gitea-actions-runner
   ```
4. 验证 Runner 状态：
   ```bash
   docker compose logs gitea-actions-runner
   ```

#### 禁用公开注册
已在配置中默认禁用：
```yaml
GITEA__service__DISABLE_REGISTRATION=true
```

只有管理员可以创建新账户或发送邀请。

### 2. Vaultwarden 配置

#### 首次设置
1. 访问 `https://vault.yourdomain.com`
2. 创建个人账户
3. 安装浏览器扩展 (Bitwarden)

#### 管理后台
访问 `https://vault.yourdomain.com/admin`
- 使用 `VAULTWARDEN_ADMIN_TOKEN` 登录
- 管理用户、邀请、系统设置

#### 邀请用户
1. 管理后台 → 用户 → 发送邀请
2. 输入用户邮箱
3. 用户收到邮件后注册
4. 管理员批准加入组织

#### 配置浏览器扩展
1. 安装 Bitwarden 浏览器扩展
2. 设置 → 自托管服务器
3. 输入：`https://vault.yourdomain.com`
4. 保存并登录

#### SMTP 配置
确保 `.env` 中 SMTP 配置正确，Vaultwarden 才能发送邀请邮件：
```bash
SMTP_HOST=smtp.yourdomain.com
SMTP_PORT=587
SMTP_USER=your_smtp_username
SMTP_PASS=your_smtp_password
```

### 3. Outline 配置

#### 首次设置
1. 访问 `https://docs.yourdomain.com`
2. 使用 Authentik OIDC 登录
3. 创建团队和工作区

#### 配置 Authentik OIDC
1. 在 Authentik 创建 OAuth2 Provider
   - Provider type: OAuth2
   - Name: Outline
   - Redirect URI: `https://docs.yourdomain.com/auth/oidc.callback`
2. 在 `.env` 中配置:
   ```
   OUTLINE_OAUTH_CLIENT_ID=your_client_id
   OUTLINE_OAUTH_CLIENT_SECRET=your_client_secret
   ```

#### MinIO 存储桶配置
1. 访问 MinIO Console: `https://minio.yourdomain.com`
2. 创建存储桶 `outline`
3. 设置访问策略为 `private`
4. Outline 会自动上传文件到 MinIO

### 4. Stirling PDF 配置

#### 使用指南
1. 访问 `https://pdf.yourdomain.com`
2. 选择需要的 PDF 工具
3. 上传文件 → 处理 → 下载

**支持的操作：**
- 合并/分割 PDF
- PDF 转 Word/Excel/图片
- 添加水印/签名
- OCR 文字识别
- 压缩/优化 PDF
- 40+ 其他工具

### 5. Excalidraw 配置

#### 使用指南
1. 访问 `https://draw.yourdomain.com`
2. 开始绘图（无需登录）
3. 保存到本地或导出

**协作功能：**
- 点击"实时协作"生成分享链接
- 多人同时编辑
- 支持导出为 PNG/SVG

## 🔐 安全配置

### 1. HTTPS 证书

本项目使用 Traefik 自动配置 HTTPS：

```yaml
labels:
  - traefik.http.routers.xxx.tls=true
```

**要求：**
- 域名 DNS 解析到服务器 IP
- Traefik 已配置证书解析器

### 2. 防火墙配置

```bash
# 仅开放必要端口
sudo ufw allow 80/tcp    # HTTP (证书申请)
sudo ufw allow 443/tcp   # HTTPS
sudo ufw allow 2222/tcp  # Gitea SSH
sudo ufw enable
```

### 3. 强密码策略

所有密码必须使用强密码：
```bash
# 生成强密码示例
openssl rand -base64 32
```

### 4. 定期备份

```bash
# 备份 PostgreSQL 数据库
docker exec homelab-postgres pg_dumpall \
  -U postgres > postgres-backup-$(date +%Y%m%d).sql

# 备份 MinIO 数据
tar -czf minio-backup-$(date +%Y%m%d).tar.gz \
  /path/to/minio/data
```

## 🔄 自动化工作流程

### 代码开发流程
```
开发者推送代码 → Gitea
    ↓
触发 Actions → Gitea Runner
    ↓
执行 CI/CD → 自动测试/部署
```

### 密码管理流程
```
管理员发送邀请 → 邮件通知
    ↓
用户注册 → 安全存储密码
    ↓
浏览器扩展同步 → 自动填充
```

### 文档协作流程
```
团队成员 → Authentik 登录
    ↓
访问 Outline → 创建/编辑文档
    ↓
实时协作 → 文件存储到 MinIO
```

## 📊 健康检查

```bash
# 检查所有服务状态
docker compose ps

# 预期输出：所有服务显示 (healthy)
NAME                  STATUS
gitea                 Up (healthy)
gitea-actions-runner  Up
vaultwarden           Up (healthy)
outline               Up (healthy)
stirling-pdf          Up (healthy)
excalidraw            Up (healthy)

# 查看特定服务日志
docker compose logs gitea
docker compose logs vaultwarden
docker compose logs outline
```

## ❓ 常见问题 (FAQ)

### Q1: Vaultwarden 浏览器扩展无法连接

**可能原因：** HTTPS 证书问题

**解决方案：**
1. 确认域名解析正确
2. 检查 Traefik 证书状态
3. 验证 `.env` 中的 DOMAIN 配置

### Q2: Gitea Actions Runner 无法连接

**检查清单：**
1. 确认 Gitea 已启用 Actions
2. 检查 Runner 注册令牌是否正确
3. 查看 Runner 日志：
   ```bash
   docker compose logs gitea-actions-runner
   ```
4. 重新生成令牌并重启 Runner

### Q3: Outline 无法登录 OIDC

**解决方案：**
1. 检查 Authentik Provider 配置
2. 确认回调 URL 正确
3. 查看 Outline 日志：
   ```bash
   docker compose logs outline
   ```
4. 验证 Client ID/Secret 配置

### Q4: SMTP 邮件发送失败

**检查清单：**
1. 验证 SMTP 服务器地址和端口
2. 检查用户名密码
3. 确认 SMTP_SECURITY 设置正确
4. 查看 Vaultwarden 日志：
   ```bash
   docker compose logs vaultwarden | grep SMTP
   ```

### Q5: 服务无法启动，显示网络错误

**解决方案：**
1. 确保外部网络已创建：
   ```bash
   docker network create proxy
   docker network create databases
   docker network create storage
   ```
2. 或者先启动 base 和 databases 栈

## 🛡️ 安全建议

1. **定期更新** - 保持镜像最新版本
   ```bash
   docker compose pull
   docker compose up -d
   ```

2. **强密码策略** - 所有服务使用复杂密码

3. **启用双因素认证** - Gitea/Vaultwarden 支持 2FA

4. **定期备份** - 备份数据和数据库

5. **监控日志** - 定期检查异常登录

6. **限制访问** - 使用防火墙限制 IP 访问

## 📊 资源占用参考

| 服务 | CPU | 内存 | 磁盘 |
|------|-----|------|------|
| Gitea | 低 | 300MB | 取决于仓库 |
| Gitea Runner | 低 | 200MB | <100MB |
| Vaultwarden | 极低 | 50MB | <100MB |
| Outline | 中 | 500MB | 取决于文档 |
| Stirling PDF | 低 | 200MB | <500MB |
| Excalidraw | 极低 | 50MB | <50MB |

**总计：** ~1.3GB 内存，低 CPU 占用

## 📝 环境变量说明

| 变量 | 说明 |
|------|------|
| `DOMAIN` | 你的域名 |
| `AUTHENTIK_DOMAIN` | Authentik 域名 |
| `GITEA_DB_PASSWORD` | Gitea 数据库密码 |
| `GITEA_OAUTH2_JWT_SECRET` | Gitea JWT 密钥 |
| `GITEA_RUNNER_REGISTRATION_TOKEN` | Gitea Runner 令牌 |
| `VAULTWARDEN_DB_PASSWORD` | Vaultwarden 数据库密码 |
| `VAULTWARDEN_ADMIN_TOKEN` | Vaultwarden 管理员令牌 |
| `OUTLINE_DB_PASSWORD` | Outline 数据库密码 |
| `OUTLINE_SECRET_KEY` | Outline 加密密钥 (32 字符) |
| `OUTLINE_OAUTH_CLIENT_ID` | Outline OAuth Client ID |
| `SMTP_HOST` | SMTP 服务器地址 |
| `SMTP_PORT` | SMTP 端口 |

## 🔗 相关资源

- [Gitea 文档](https://docs.gitea.com/)
- [Vaultwarden Wiki](https://github.com/dani-garcia/vaultwarden/wiki)
- [Outline 文档](https://docs.getoutline.com/)
- [Stirling PDF GitHub](https://github.com/Stirling-Tools/Stirling-PDF)
- [Excalidraw 官网](https://excalidraw.com/)
- [Authentik 文档](https://docs.goauthentik.io/)

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

## 📄 许可证

MIT License

---

**开发者备注：**
- 所有服务使用官方镜像
- 支持 Traefik 自动 HTTPS
- 集成 Authentik 统一认证
- 完整的健康检查和日志
- 生产环境就绪配置
