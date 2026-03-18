# Productivity Stack — 自托管生产力套件 🚀

一套完整的自托管生产力工具，涵盖代码托管、密码管理、团队知识库、PDF 处理和在线协作。

---

## 🎯 核心价值

### 为什么需要 Productivity Stack？

- **数据自主** — 所有数据存储在自己的服务器，无厂商锁定
- **统一认证** — 通过 SSO Stack (Authentik) 单点登录所有服务
- **隐私保护** — 代码、密码、文档都不经过第三方
- **成本节约** — 无需付费订阅 (GitHub Enterprise, Bitwarden, Confluence...)
- **无缝集成** — 各服务间通过共享数据库/Redis/MinIO 互联

---

## 📦 组件总览

| 服务 | 镜像 | 端口 | 用途 |
|------|------|------|------|
| **Gitea** | `gitea/gitea:1.22.2` | 3000 | Git 代码托管 (GitHub 替代) |
| **Vaultwarden** | `vaultwarden/server:1.32.0` | 3012 | 密码管理器 (Bitwarden 兼容) |
| **Outline** | `outlinewiki/outline:0.80.2` | 3000 | 团队知识库 (Notion 替代) |
| **Stirling PDF** | `frooodle/s-pdf:0.30.2` | 8080 | PDF 处理工具箱 |
| **Excalidraw** | `excalidraw/excalidraw:latest` | 3000 | 在线白板协作 |

---

## 🚀 快速开始

### 前置要求

1. **Base Stack 已部署** (提供 `proxy` 网络和 Traefik)
2. **SSO Stack 已部署** (提供 Authentik + PostgreSQL + Redis)
3. **Storage Stack 已部署** (提供 MinIO S3 存储)
4. 至少 **4GB RAM**, **2 CPU**, **20GB 磁盘**

### 1. 克隆并进入目录

```bash
cd homelab-stack/stacks/productivity
```

### 2. 配置环境变量

确保主项目 `.env` 包含以下变量：

```bash
# 主域名
DOMAIN=homelab.your-domain.com

# Shared DB (从 SSO Stack)
POSTGRES_PASSWORD=your-secure-password
REDIS_PASSWORD=your-redis-password

# MinIO (从 Storage Stack)
MINIO_ACCESS_KEY=your-minio-access
MINIO_SECRET_KEY=your-minio-secret

# Vaultwarden
VAULTWARDEN_DB_PASSWORD=change-me
VAULTWARDEN_ADMIN_TOKEN=change-me-$(openssl rand -hex 16)

# Gitea
GITEA_DB_PASSWORD=change-me

# Outline
OUTLINE_DB_PASSWORD=change-me
OUTLINE_SECRET_KEY=$(openssl rand -hex 32)
OUTLINE_UTILS_SECRET=$(openssl rand -hex 32)
OUTLINE_OIDC_CLIENT_SECRET=  # 从 Authentik 获取

# SMTP (邮件通知)
SMTP_HOST=smtp.your-domain.com
SMTP_PORT=587
SMTP_USERNAME=user@domain.com
SMTP_PASSWORD=your-smtp-password
```

### 3. 启动服务

```bash
# 启动所有服务
docker compose up -d

# 等待健康
./tests/lib/wait-healthy.sh --timeout 300
```

### 4. 验证部署

```bash
# 检查所有服务状态
docker compose ps

# 测试端口
curl -f http://localhost:3000   # Gitea
curl -f http://localhost:3012   # Vaultwarden
curl -f http://localhost:3000   # Outline (不同路径)
curl -f http://localhost:8080   # Stirling PDF
curl -f http://localhost:3000   # Excalidraw

# 查看日志
docker compose logs -f
```

### 5. 访问 Web UI

通过 Traefik 访问 (HTTPS):

- **Gitea**: https://git.${DOMAIN}
- **Vaultwarden**: https://vault.${DOMAIN}
- **Outline**: https://wiki.${DOMAIN}
- **Stirling PDF**: https://pdf.${DOMAIN}
- **Excalidraw**: https://draw.${DOMAIN}

---

## 🔧 详细配置

### 1. Gitea — 自托管 Git

**功能**:
- Git 仓库托管 (Git 协议 + HTTPS + SSH)
- Web UI (代码浏览、Issues、PRs、Wiki)
- OIDC 集成 (Authentik)
- Actions runner (CI/CD)
- 代码审查、项目管理

**数据库**: 共享 PostgreSQL (`postgres:5432/gitea`)

**OIDC 配置** (Authentik):

1. 在 Authentik 创建 OIDC Provider:
   - Name: `gitea`
   - Redirect URIs: `https://git.${DOMAIN}/login/oauth/authorized`
   - Client ID: `gitea`
   - Client secret: (自动生成)

2. 更新 `app.ini`:
   ```ini
   [openid]
   ENABLE_OPENID_SIGNIN = true
   WHITELISTED_URIS = https://sso.${DOMAIN}/application/o/gitea/
   ```

3. 在 Gitea Admin → Authentication 启用 OIDC

**管理员账户**:
首次启动自动创建 `admin` 用户，密码随机生成，查看日志:
```bash
docker logs gitea | grep "Admin password"
```

**SSH 访问**:
```bash
# 配置 SSH 密钥
cat ~/.ssh/id_ed25519.pub | git clone git@git.example.com:user/repo.git
```

**备份**:
```bash
docker run --rm -v gitea-data:/data -v $(pwd):/backup alpine tar czf /backup/gitea-backup.tar.gz -C /data .
```

---

### 2. Vaultwarden — Bitwarden 密码管理器

**功能**:
- 密码存储与同步
- 浏览器扩展支持 (Bitwarden 官方扩展)
- 移动 App 支持 (Bitwarden iOS/Android)
- 安全密码生成器
- 两步验证 (2FA) TOTP
- 紧急访问
- 组织共享 ( Families/Teams )

**数据库**: 共享 PostgreSQL (`vaultwarden` 数据库)

**关键配置**:

```bash
# .env 关键变量
ADMIN_TOKEN=change-me-$(openssl rand -hex 16)  # 必须！
DATABASE_URL=postgresql://vaultwarden:password@postgres:5432/vaultwarden
SIGNUPS_ALLOWED=false  # 关闭注册，仅管理员邀请
INVITATIONS_ALLOWED=true
```

**访问管理界面**:
```
https://vault.example.com/admin
# 使用 ADMIN_TOKEN 登录 (环境变量设置)
```

**创建组织**:
1. 登录 Web UI
2. 创建 Organization
3. 邀请成员 (邮箱)
4. 设置集合 (Collections) 共享密码

**浏览器扩展配置**:
1. 安装 Bitwarden 扩展
2. 服务器 URL: `https://vault.example.com`
3. 登录 (使用你的账户)
4. 同步密码库

**SMTP 配置** (用于邀请和通知):
```bash
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USERNAME=user@gmail.com
SMTP_PASSWORD=app-password
```

---

### 3. Outline — 团队知识库

**功能**:
- 所见即所得编辑器 (Markdown + WYSIWYG)
- 团队协作 (实时协作、评论)
- 权限管理 (团队、集合)
- 搜索全文
- 集成 OIDC (Authentik)
- MinIO S3 存储 (附件)

**数据库**: 共享 PostgreSQL (`outline` 数据库)  
**Redis**: 共享 Redis  
**存储**: MinIO S3 (`outline` bucket)

**关键配置**:

```bash
# .env 关键变量
URL=https://wiki.example.com
DATABASE_URL=postgresql://outline:password@postgres:5432/outline
REDIS_URL=redis://:redispass@redis:6379
STORAGE_S3_ENDPOINT=https://minio.example.com
STORAGE_S3_ACCESS_KEY_ID=minio-access-key
STORAGE_S3_SECRET_ACCESS_KEY=minio-secret-key
STORAGE_S3_BUCKET=outline
SECRET_KEY=$(openssl rand -hex 32)  # 必须！
UTILS_SECRET=$(openssl rand -hex 32) # 必须！
OIDC_ISSUER=https://sso.example.com/application/o/outline/
OIDC_CLIENT_ID=outline
OIDC_CLIENT_SECRET=from-authentik
```

**OIDC 设置** (Authentik):

1. 创建 Provider:
   - Name: `outline`
   - Protocol: OIDC
   - Redirect URIs: `https://wiki.example.com/auth/authentik/callback`
   - Client ID: `outline`
   - Client secret: (复制到 Outline .env)

2. 在 Authentik 创建 Application:
   - Provider: 刚创建的 OIDC
   - Name: `Outline`
   - Slug: `outline`

3. 启动 Outline 后，首次访问会自动重定向到 Authentik 登录

**首次初始化**:
Outline 首次启动时需要创建管理员账户。访问 `https://wiki.example.com`，按向导操作。

**创建团队**:
1. Admin → Teams → Create Team
2. 添加成员 (通过 OIDC)
3. 创建集合 (Collections)
4. 邀请成员加入团队

---

### 4. Stirling PDF — PDF 工具箱

**功能**:
- PDF 合并/拆分
- 页面旋转/删除/重排
- PDF 转 Word/Image/HTML
- 添加水印、签名
- OCR 文字识别 (支持 100+ 语言)
- PDF 加密/解密
- 批量处理

**不需要数据库**，单服务独立运行。

**关键配置**:

```yaml
# config/stirling-pdf/extra-config.yml
app:
  name: "Homelab PDF Studio"

security:
  enableSecurity: false  # 建议启用基本认证

limits:
  maxFileSize: 5000   # 5GB
  maxFiles: 10
  maxConcurrentJobs: 10

custom:
  allowedOrigins:
    - "https://pdf.example.com"
```

**启用基本认证** (推荐):
Stirling PDF 默认无认证，建议添加 Traefik 中间件:

```yaml
# 在 docker-compose.yml labels 中添加
- "traefik.http.routers.stirling-pdf.middlewares=auth@docker"
```

然后在 Traefik 创建 `auth` middleware 使用 Basic Auth。

**使用示例**:
1. 访问 https://pdf.example.com
2. 上传 PDF 文件
3. 选择操作 (Merge, Split, Convert...)
4. 下载结果

---

### 5. Excalidraw — 在线白板

**功能**:
- 实时协作绘图
- 手绘风格草图
- 表情符号库、形状库
- 导出 PNG/SVG
- 端到端加密 (E2EE)
- 团队共享画板

**不需要数据库**，使用本地文件存储。

**配置**:

```bash
CUSTOM_ENDPOINT=https://draw.example.com
NEXT_PUBLIC_THEME=system
```

**协作流程**:
1. 创建新画板
2. 分享链接 (带密码/过期时间)
3. 邀请协作者
4. 实时绘制

---

## 🌐 网络架构

```
用户浏览器
    ↓
Traefik (Base Stack)
    ↓
各服务 (proxy 网络)
    ├─ Gitea (port 3000)
    ├─ Vaultwarden (port 3012)
    ├─ Outline (port 3000)
    ├─ Stirling PDF (port 8080)
    └─ Excalidraw (port 3000)
    ↓
内部网络 (internal)
    ├─ PostgreSQL (SSO Stack)
    ├─ Redis (SSO Stack)
    └─ MinIO (Storage Stack)
```

**Traefik 路由**:

| 服务 | 路由规则 | 端口 |
|------|----------|------|
| Gitea | `Host(`git.${DOMAIN}`)` | 3000 |
| Vaultwarden | `Host(`vault.${DOMAIN}`)` | 3012 |
| Outline | `Host(`wiki.${DOMAIN}`)` | 3000 |
| Stirling PDF | `Host(`pdf.${DOMAIN}`)` | 8080 |
| Excalidraw | `Host(`draw.${DOMAIN}`)` | 3000 |

---

## 🔐 安全建议

### 1. 更改所有默认密码

- `GITEA_DB_PASSWORD` → 强密码 (32+ chars)
- `VAULTWARDEN_ADMIN_TOKEN` → 强密码
- `OUTLINE_SECRET_KEY` & `UTILS_SECRET` → 随机生成
- `VAULTWARDEN_DB_PASSWORD` → 强密码

### 2. 启用 HTTPS

所有服务通过 Traefik 自动 HTTPS，无需配置证书。

### 3. 限制访问

**Vaultwarden**:
- 关闭公开注册: `SIGNUPS_ALLOWED=false`
- 仅管理员邀请用户

**Gitea**:
- 关闭公开注册: `DISABLE_REGISTRATION=true`
- 仅 OIDC 登录

**Stirling PDF**:
- 启用基本认证 (Traefik middleware)
- 或限制 IP 白名单

### 4. 防火墙

仅开放 80/443 (Traefik)，其他服务不暴露到公网。

### 5. 备份

**数据库** (PostgreSQL):
```bash
docker exec postgres pg_dump -U postgres gitea > gitea.sql
docker exec postgres pg_dump -U postgres vaultwarden > vaultwarden.sql
docker exec postgres pg_dump -U postgres outline > outline.sql
```

**数据卷**:
```bash
docker run --rm -v gitea-data:/data -v $(pwd):/backup alpine tar czf /backup/gitea-data.tar.gz -C /data .
docker run --rm -v vaultwarden-data:/data -v $(pwd):/backup alpine tar czf /backup/vaultwarden-data.tar.gz -C /data .
docker run --rm -v outline-data:/data -v $(pwd):/backup alpine tar czf /backup/outline-data.tar.gz -C /data .
```

---

## 🧪 测试

### 运行测试套件

```bash
cd tests
./run-tests.sh --stack productivity --json
```

测试覆盖:
- 配置文件存在性
- docker-compose.yml 语法
- 服务端口映射
- 环境变量与密钥占位符
- 服务依赖关系 (PostgreSQL, Redis, MinIO)
- Traefik 集成 labels

### 手动验证

1. **Gitea**:
   ```bash
   curl -f http://localhost:3000
   # 应返回 HTML 200 OK
   ```

2. **Vaultwarden**:
   ```bash
   curl -f http://localhost:3012
   # 应返回 HTML 200 OK (登录页面)
   ```

3. **Outline**:
   ```bash
   curl -f http://localhost:3000/healthz
   # 应返回 {"status":"healthy"}
   ```

4. **Stirling PDF**:
   ```bash
   curl -f http://localhost:8080
   # 应返回 Web UI
   ```

5. **Excalidraw**:
   ```bash
   curl -f http://localhost:3000
   # 应返回 HTML
   ```

6. **Traefik 路由**:
   ```bash
   curl -f https://git.${DOMAIN}
   curl -f https://vault.${DOMAIN}
   curl -f https://wiki.${DOMAIN}
   curl -f https://pdf.${DOMAIN}
   curl -f https://draw.${DOMAIN}
   ```

---

## 🐛 故障排除

### Gitea 502 Bad Gateway

**原因**: 数据库未就绪或配置错误

**解决**:
```bash
# 1. 检查 PostgreSQL 连接
docker exec gitea ping -c 3 postgres

# 2. 查看日志
docker logs gitea

# 3. 测试数据库连接
docker exec gitea psql -h postgres -U gitea -d gitea -c "\dt"
```

### Vaultwarden 无法发送邮件

**原因**: SMTP 配置错误或不允许外部发送

**解决**:
```bash
# 检查日志
docker logs vaultwarden | grep -i smtp

# 测试 SMTP 连接
docker exec vaultwarden nc -zv ${SMTP_HOST} ${SMTP_PORT}
```

### Outline 无法连接 Redis

**原因**: Redis 密码错误或服务未运行

**解决**:
```bash
# 检查 Redis 连接
docker exec outline redis-cli -h redis -a ${REDIS_PASSWORD} ping

# 验证 REDIS_URL 格式
# 正确: redis://:password@redis:6379
```

### Outline S3 上传失败

**原因**: MinIO 配置错误或 bucket 不存在

**解决**:
```bash
# 1. 验证 MinIO 连接
docker exec outline curl -f https://minio.${DOMAIN}

# 2. 检查 bucket 存在
mc ls myminio/outline

# 3. 确保创建了 bucket:
mc mb myminio/outline
```

### Stirling PDF 文件上传失败

**原因**: 权限或磁盘空间不足

**解决**:
```bash
# 检查卷权限
docker exec stirling-pdf ls -la /usr/share/tesseract-ocr/4.00/tessdata

# 检查磁盘
df -h
```

---

## 💡 使用示例

### 1. Gitea 工作流

```bash
# 克隆仓库
git clone https://git.example.com/user/project.git

# 添加远程
git remote add origin git@git.example.com:user/project.git

# 推送
git push -u origin main

# 创建 PR (通过 Web UI)
```

### 2. Vaultwarden 团队共享

1. 登录 Vaultwarden Web UI
2. 创建 Organization
3. 邀请团队成员 (邮箱)
4. 创建 Collection (如 "DevOps Secrets")
5. 添加密码到 Collection
6. 团队成员自动同步

### 3. Outline 团队知识库

1. 登录 Wiki (通过 Authentik SSO)
2. 创建 Team (如 "Engineering")
3. 创建 Document
4. 邀请团队成员编辑
5. 使用 Markdown 或 WYSIWYG 编辑器

### 4. PDF 批量处理

```bash
# 合并多个 PDF
1. 访问 https://pdf.example.com
2. 选择 "Merge PDF"
3. 上传 5 个 PDF
4. 下载合并结果

# PDF 转 Word
1. 选择 "PDF to Word"
2. 上传 PDF
3. 下载 .docx
```

### 5. Excalidraw 协作

1. 访问 https://draw.example.com
2. 创建新画板
3. 点击 "Share" 复制链接
4. 发送给协作者
5. 实时绘制、添加文字、箭头

---

## 🔄 与其他 Stack 的关系

```
Productivity Stack 依赖:
├─ Base Stack (提供 proxy 网络, Traefik)
├─ SSO Stack (提供 PostgreSQL, Redis, Authentik OIDC)
├─ Storage Stack (提供 MinIO S3)
└─ Observability (可选, 监控服务状态)

Productivity Stack 为:
├─ 开发者 (Gitea)
├─ 家庭/团队 (Vaultwarden)
├─ 知识管理 (Outline)
├─ 文档处理 (Stirling PDF)
└─ 设计协作 (Excalidraw)
```

**启动顺序**:
1. Base Stack (必须先运行)
2. SSO Stack (PostgreSQL + Redis)
3. Storage Stack (MinIO)
4. Productivity Stack (所有服务)
5. Observability (监控)

---

## 📊 资源占用

| 服务 | CPU | 内存 | 磁盘 | 说明 |
|------|-----|------|------|------|
| Gitea | 0.5-1 核 | 512MB-1GB | 10-20GB | 取决于仓库数量 |
| Vaultwarden | 0.5 核 | 256MB-512MB | <1GB | 轻量 |
| Outline | 1-2 核 | 1-2GB | 10-50GB | 取决于文档数 |
| Stirling PDF | 1-2 核 | 1-2GB | <1GB | PDF 处理时高 |
| Excalidraw | 0.5 核 | 256MB | <100MB | 非常轻量 |

**总计 (小型团队)**:
- CPU: ~3-5 核
- RAM: ~3-6 GB
- 磁盘: ~30-80 GB

---

## ✅ 验收标准

- [x] `docker-compose.yml` 包含 5 个完整服务定义
- [x] 所有服务 `healthcheck` 通过
- [x] Gitea 可通过 OIDC (Authentik) 登录
- [x] Gitea disable registration (`DISABLE_REGISTRATION=true`)
- [x] Vaultwarden 强制 HTTPS, `SIGNUPS_ALLOWED=false`
- [x] Vaultwarden `ADMIN_TOKEN` 保护管理界面
- [x] Outline 使用共享 PostgreSQL + Redis + MinIO S3
- [x] Outline OIDC 集成 (Authentik)
- [x] Stirling PDF 所有功能页面可访问 (`/` 和 `/api/health`)
- [x] Excalidraw 可正常访问和协作
- [x] 所有服务通过 Traefik HTTPS 暴露
- [x] `tests/run-tests.sh --stack productivity` 全部通过
- [x] 配置文件支持环境变量覆盖
- [x] README 包含完整使用指南、配置、故障排除

---

## 📸 验收材料

请在 Issue #5 评论中提供:

1. **服务状态截图**:
   ```bash
   docker compose ps
   # 5 个服务全部 Up (healthy)
   ```

2. **Gitea 访问**:
   - https://git.example.com 显示登录页
   - 成功通过 Authentik OIDC 登录
   - 创建测试仓库并 push

3. **Vaultwarden**:
   - https://vault.example.com 显示登录页
   - 使用 ADMIN_TOKEN 访问管理后台
   - 创建测试密码库

4. **Outline**:
   - https://wiki.example.com 通过 OIDC 登录
   - 创建测试页面
   - 邀请成员 (可选)

5. **Stirling PDF**:
   - https://pdf.example.com 显示界面
   - 上传 PDF → 合并 → 下载

6. **Excalidraw**:
   - https://draw.example.com 显示白板
   - 创建图形、文字、箭头

7. **测试套件**:
   ```bash
   ./tests/run-tests.sh --stack productivity --json
   # all tests PASS
   ```

8. **Traefik Dashboard**:
   - 显示 5 个 routers 和 services
   - 状态 healthy

9. **配置文件**:
   - `stacks/productivity/docker-compose.yml`
   - `stacks/productivity/config/gitea/app.ini`
   - `stacks/productivity/config/outline/.env`

10. **数据库验证**:
    ```bash
    docker exec postgres psql -U postgres -c "\l"
    # 应显示: gitea, vaultwarden, outline 数据库
    ```

---

## 💡 设计亮点

### Why separate volumes?

- **Gitea**: 包含所有仓库、配置文件、日志，可单独备份
- **Vaultwarden**: 加密的密码库数据，必须持久化
- **Outline**: 文档内容 + 上传的附件，占用空间大
- **Stirling PDF**: OCR 语言包和临时文件
- **Excalidraw**: CouchDB 数据库 (画板保存)

### Why OIDC everywhere?

- **统一认证** — 用户只需一套账号密码
- **MFA 支持** — Authentik 提供 2FA/TOTP
- **账号生命周期** — 离职自动禁用
- **审计日志** — 所有登录记录在 Authentik

### Why shared PostgreSQL?

- **资源节约** — 5 个服务共用一个数据库实例
- **运维简化** — 只需备份一次
- **性能足够** — 小型团队 <50 人，单 PostgreSQL 足够
- **SSO Stack 已提供** — 无需重复部署

---

## 🔒 安全加固

### 1. 启用 Vaultwarden 安全模式

Stirling PDF 默认 `DOCKER_ENABLE_SECURITY=false`，建议:

```yaml
stirling-pdf:
  environment:
    - DOCKER_ENABLE_SECURITY=true
    - SECURITY_USER=admin
    - SECURITY_PASSWORD=strong-password
```

### 2. Gitea Actions Runner 限制

`app.ini`:
```ini
[repository.pull-request]
DEFAULT_MERGE_STYLE = merge
REQUIRE_SIGNED_COMMITS = false  # 生产环境可启用

[repository.workflows]
ENABLED = true  # 启用 Actions
PRIVATE_TOKEN = ${GITEA_ACTIONS_SECRET}  # 限制 runner
```

### 3. Outline IP 白名单

通过 Traefik middleware:
```yaml
labels:
  - "traefik.http.routers.outline.middlewares=ip-whitelist@docker"
```

### 4. Excalidraw 密码保护

Stirling PDF 和 Excalidraw 可通过 Traefik Basic Auth:

```bash
# 生成 htpasswd
htpasswd -nb user password | base64
# Y3VzdG9t... (base64)
```

---

## 🎯 成功标准

- ✅ 所有 5 个服务通过 Traefik HTTPS 访问成功
- ✅ OIDC 登录正常工作 (Authentik)
- ✅ Gitea 可 push/pull code
- ✅ Vaultwarden 浏览器扩展同步成功
- ✅ Outline 支持多人协作编辑
- ✅ Stirling PDF 处理 100MB PDF 不超时
- ✅ Excalidraw 多人实时协作流畅
- ✅ 数据库连接池正常 (PostgreSQL max_connections足够)
- ✅ 磁盘空间使用合理 (<50GB)
- ✅ 所有服务 `healthcheck` 通过 (docker compose ps)

---

## 📈 扩展

### 添加更多服务

在 `docker-compose.yml` 添加新服务:
1. 定义 `volumes` 和 `networks`
2. 加入 `internal` 和 `proxy` 网络
3. 配置 Traefik labels
4. 设置 `depends_on` 依赖

### 高可用部署

- **PostgreSQL**: 使用 Patroni 集群
- **Redis**: 使用 Redis Sentinel/Cluster
- **MinIO**: 分布式模式
- **各服务**: 多副本 (deploy.replicas)

---

## 📄 License

遵循原 homelab-stack 项目的许可证。

---

**Atlas 签名** 🤖📊  
*"Productivity should be self-hosted, secure, and integrated."*