# Storage Stack — 自托管存储解决方案 💾

完整的自托管存储栈，覆盖个人云盘、对象存储、文件管理和多设备同步。

---

## 🎯 核心价值

### 为什么需要 Storage Stack？

- **数据自主** — 所有文件存储在自己的服务器，无订阅费用
- **多协议支持** — WebDAV (Nextcloud), S3 (MinIO), 同步 (Syncthing), HTTP (FileBrowser)
- **统一入口** — Traefik 提供 HTTPS 统一访问
- **备份友好** — 卷持久化，可单独备份每个服务
- **企业级功能** — OIDC 集成, S3 API, 版本控制, 协作共享

---

## 📦 组件总览

| 服务 | 镜像 | 端口 | 用途 |
|------|------|------|------|
| **Nextcloud** | `nextcloud:29.0.7-fpm-alpine` + `nginx:1.27-alpine` | 443 | 个人云盘 (Dropbox/Google Drive 替代) |
| **MinIO** | `minio/minio:RELEASE.2024-09-22T00-33-43Z` | 9000 (API), 9001 (Console) | 对象存储 (AWS S3 兼容) |
| **FileBrowser** | `filebrowser/filebrowser:v2.31.1` | 8080 | 轻量文件管理 (HTTP 文件管理器) |
| **Syncthing** | `lscr.io/linuxserver/syncthing:1.27.11` | 8384 | P2P 文件同步 (多设备同步) |

---

## 🚀 快速开始

### 前置要求

1. **Base Stack** 已部署 (Traefik, proxy 网络)
2. **SSO Stack** 已部署 (PostgreSQL, Redis, Authentik)
3. 至少 **4GB RAM**, **2 CPU**, **50GB 磁盘** (根据文件量增长)
4. 主域名已配置 DNS 解析

### 1. 克隆并进入目录

```bash
cd homelab-stack/stacks/storage
```

### 2. 配置环境变量

确保主项目 `.env` 包含以下变量:

```bash
# 域名
DOMAIN=your-domain.com

# Nextcloud 管理員
NEXTCLOUD_ADMIN_USER=admin
NEXTCLOUD_ADMIN_PASSWORD=strong-password-here
NEXTCLOUD_DB_PASSWORD=change-me

# MinIO
MINIO_ROOT_USER=minioadmin
MINIO_ROOT_PASSWORD=strong-minio-password

# 共享数据库密码 (从 SSO Stack)
POSTGRES_PASSWORD=your-secure-password
REDIS_PASSWORD=your-redis-password

# Nextcloud OIDC 客户端密钥 (从 Authentik)
NEXTCLOUD_OIDC_CLIENT_SECRET=from-authentik
```

### 3. 启动服务

```bash
docker compose up -d
```

启动顺序:
- PostgreSQL (SSO Stack) → Redis (SSO Stack) → MinIO → Nextcloud FPM + Nginx → FileBrowser → Syncthing

### 4. 等待服务健康

```bash
./tests/lib/wait-healthy.sh --timeout 300
```

### 5. 访问服务

通过 Traefik (HTTPS):

| 服务 | URL | 说明 |
|------|-----|------|
| Nextcloud | https://cloud.${DOMAIN} | 个人云盘 |
| MinIO Console | https://minio.${DOMAIN} | 管理控制台 |
| MinIO API | https://s3.${DOMAIN} | S3 API 端点 |
| FileBrowser | https://files.${DOMAIN} | 文件管理器 |
| Syncthing | https://sync.${DOMAIN} | P2P 同步界面 |

**首次访问**:
- **Nextcloud**: 会自动重定向到 Authentik SSO 登录
- **MinIO**: 使用 `MINIO_ROOT_USER` / `MINIO_ROOT_PASSWORD` 登录
- **FileBrowser**: 默认无认证 (需配置 Traefik middleware)
- **Syncthing**: 首次需设置 Web UI 密码 (或通过环境变量)

---

## 🔧 详细配置

### 1. Nextcloud — 个人云盘

**架构**: FPM (PHP-FPM) + Nginx 分离部署，性能更好。

**数据库**: 共享 PostgreSQL (`nextcloud` 数据库)  
**缓存**: 共享 Redis  
**认证**: Authentik OIDC (单点登录)

**目录结构**:

```
stacks/storage/config/
├── nextcloud/
│   ├── config/
│   │   └── config.php    # Nextcloud 主配置
│   └── myjwt.example.php # JWT 插件配置 (可选)
└── nginx/
    └── nextcloud.conf    # Nginx 虚拟主机配置
```

**关键配置** (`config.php`):

```php
'dbtype' => 'pgsql',
'dbhost' => 'postgres:5432',
'dbname' => 'nextcloud',
'dbuser' => 'nextcloud',
'dbpassword' => '...',
'redis' => [
  'host' => 'redis',
  'port' => 6379,
  'password' => '...',
],
'oidc_login' => [
  'enabled' => true,
  'provider_url' => 'https://sso.example.com/application/o/nextcloud/',
  'client_id' => 'nextcloud',
  'client_secret' => '...',
],
```

**OIDC 设置** (Authentik):

1. 创建 OIDC Provider:
   - Name: `nextcloud`
   - Redirect URIs: `https://cloud.example.com/apps/oidc_login/oidc/callback`
   - Client ID: `nextcloud`
   - Client secret: (复制到 config.php)

2. 创建 Application:
   - Provider: `nextcloud` OIDC
   - Name: `Nextcloud`
   - Slug: `nextcloud`

3. 在 Nextcloud Admin → OIDC Login 启用并填写相同信息

**性能优化**:

```php
'memcache.local' => '\\OC\\Memcache\\Redis',
'filelocking.enabled' => true,
'default_phone_region' => 'CN',
'max_filesize' => '10G',
```

**备份**:

```bash
# 数据库
docker exec postgres pg_dump -U postgres nextcloud > nextcloud.sql

# 数据卷
docker run --rm -v nextcloud-data:/data -v $(pwd):/backup alpine tar czf /backup/nextcloud-data.tar.gz -C /data .
```

---

### 2. MinIO — 对象存储

**功能**:
- S3 兼容 API (AWS S3 替代)
- Web Console 管理界面
- 多 bucket 支持
- 分布式模式支持 (可选)

**默认 buckets**: `nextcloud`, `syncthing`, `outline`

**访问点**:

| 用途 | URL | 凭证 |
|------|-----|------|
| Console | https://minio.${DOMAIN} | `MINIO_ROOT_USER` / `MINIO_ROOT_PASSWORD` |
| S3 API | https://s3.${DOMAIN} | 同上 (或 IAM 用户) |

**初始化** (`config/minio/init.sh`):

- 等待 MinIO 服务就绪
- 创建默认 bucket
- 设置 bucket 策略 (private)
- 启动 MinIO

**创建 IAM 用户** (可选):

```bash
# 使用 mc (MinIO Client)
mc alias set myminio https://minio.${DOMAIN} ${MINIO_ROOT_USER} ${MINIO_ROOT_PASSWORD}
mc admin user add myminio nextcloud-user nextcloud-password
mc admin policy attach myminio readwrite --user nextcloud-user
```

**与 Nextcloud 集成**:

在 Nextcloud → Settings → External storage:
- Type: S3
- Bucket: `nextcloud`
- Access key: `nextcloud-user`
- Secret key: `...`
- Hostname: `s3.${DOMAIN}`
- SSL: true

**与 Syncthing 集成**:

Syncthing 支持 S3 作为远程存储 (需插件)，或使用 MinIO 作为 S3 后端。

---

### 3. FileBrowser — 轻量文件管理

**功能**:
- HTTP 文件浏览器
- 文件上传/下载/删除
- 多用户支持 (可选)
- 分享链接 (密码保护)
- 搜索、预览

**配置** (`filebrowser.json`):

```json
{
  "port": 8080,
  "baseURL": "/",
  "address": "0.0.0.0",
  "database": "filebrowser.db",
  "storage": {
    "provider": "local",
    "path": "/srv",
    "allowExt": []
  },
  "branding": {
    "name": "Homelab Files",
    "disableExternalUsage": true
  },
  "auth": {
    "method": "noauth"  // 建议启用 HTTP Basic Auth via Traefik
  }
}
```

**访问**:

- URL: https://files.${DOMAIN}
- 浏览目录: `/srv` 挂载点 (配置 `storage-root` 卷)

**安全建议**:

通过 Traefik 添加 Basic Auth:

```yaml
labels:
  - "traefik.http.routers.filebrowser.middlewares=filebrowser-auth@docker"
```

然后在 Traefik 配置 `filebrowser-auth` middleware。

---

### 4. Syncthing — P2P 文件同步

**功能**:
- 设备间 P2P 同步 (无需云端)
- 端到端加密
- 实时同步
- 版本控制
- 跨平台 (Linux, macOS, Windows, Android, iOS)

**目录结构**:

```yaml
volumes:
  - syncthing-data:/config   # 配置文件、数据库
  - storage-root:/data       # 同步目录 (共享存储)
```

**环境变量**:

```yaml
PUID=1000
PGID=1000
STN_FOLDER=/data  # 默认共享文件夹
```

**访问**: https://sync.${DOMAIN}:8384

**首次设置**:

1. 访问 Web UI，设置管理员密码 (或通过 `STN_GUI_PASSWORD` 预设置)
2. 添加远程设备 (Device ID)
3. 创建共享文件夹
4. 邀请设备加入

**同步流程**:

```
设备 A (NAS) ↔ 设备 B (笔记本) ↔ 设备 C (手机)
     ↓                  ↓
   storage-root  (共享数据卷)
```

**与 MinIO 结合**:

目前 Syncthing 直接读写本地 `storage-root` 卷。MinIO 可作为备份目标:

```bash
# 定期同步到 MinIO (通过 rclone 或 mc)
mc cp /data/minio myminio/backup/
```

---

## 🌐 网络架构

```
用户浏览器
    ↓
Traefik (Base Stack)
    ↓
各服务 (proxy 网络)
    ├─ Nextcloud-Nginx (443) → Nextcloud-FPM (internal)
    ├─ MinIO (9000 + 9001)
    ├─ FileBrowser (8080)
    └─ Syncthing (8384)
    ↓
内部网络 (internal)
    ├─ PostgreSQL (SSO Stack)
    ├─ Redis (SSO Stack)
    └─ MinIO (S3 API)
```

**Traefik 路由**:

| 服务 | 路由规则 | 端口 |
|------|----------|------|
| Nextcloud | `Host(cloud.${DOMAIN})` | 443 (Nginx) |
| MinIO Console | `Host(minio.${DOMAIN})` | 9000 |
| MinIO API | `Host(s3.${DOMAIN})` | 9000 (strip prefix) |
| FileBrowser | `Host(files.${DOMAIN})` | 8080 |
| Syncthing | `Host(sync.${DOMAIN})` | 8384 |

---

## 🔐 安全建议

### 1. Nextcloud

- ✅ 使用 OIDC (Authentik) 禁用本地注册
- ✅ 限制 `trusted_proxies` 仅为 `traefik`
- ✅ 设置 `overwriteprotocol=https`
- ✅ 启用 2FA (通过 Authentik)
- ❌ 不要公开分享链接 (除非必要)

### 2. MinIO

- ✅ 使用强 `MINIO_ROOT_PASSWORD`
- ✅ 创建 IAM 用户而非使用 root
- ✅ 启用bucket策略为私有
- ✅ 通过 Traefik 限制访问 IP (可选)

### 3. FileBrowser

- ⚠️ 默认无认证，必须通过 Traefik Basic Auth
- ⚠️ 限制 `storage-root` 范围，避免暴露 `/` 根目录
- ✅ 启用分享密码 (`share.password.enabled`)

### 4. Syncthing

- ✅ 设置 GUI 密码 (`STN_GUI_PASSWORD`)
- ✅ 启用本地 Discovery + 全局 Discovery
- ✅ 限制设备 ID 白名单 (如需)
- ✅ 使用静态地址 (https://sync.${DOMAIN})

**防火墙**: 仅通过 Traefik 暴露 443，其他服务内网可达即可。

---

## 🧪 测试

### 运行测试套件

```bash
cd tests
./run-tests.sh --stack storage --json
```

测试覆盖:
- 配置文件存在性
- docker-compose.yml 语法验证
- 服务端口映射
- MinIO bucket 初始化
- Nextcloud config.php 关键配置
- Syncthing 目录挂载
- FileBrowser JSON 配置

### 手动验证

1. **Nextcloud**:
   ```bash
   curl -f https://cloud.${DOMAIN}
   # 应返回 HTML 200 OK
   # 重定向到 Authentik SSO
   ```

2. **MinIO**:
   ```bash
   curl -f -u "${MINIO_ROOT_USER}:${MINIO_ROOT_PASSWORD}" https://minio.${DOMAIN}/minio/health/live
   # {"status":"healthy"}
   ```

3. **FileBrowser**:
   ```bash
   curl -f https://files.${DOMAIN}
   # 应返回 FileBrowser 界面
   ```

4. **Syncthing**:
   ```bash
   curl -f https://sync.${DOMAIN}/rest/system/ping
   # {"pong":"sync"}
   ```

5. **S3 API**:
   ```bash
   mc ls myminio --config-dir /tmp/mc
   # 列出 buckets: nextcloud, syncthing, outline
   ```

---

## 🐛 故障排除

### Nextcloud 安装向导未自动跳过

**原因**: `config.php` 未正确挂载或位置错误

**解决**:
```bash
# 1. 检查 config.php 是否存在
docker exec nextcloud ls -la /var/www/html/config/

# 2. 检查 config.php 内容
docker exec nextcloud cat /var/www/html/config/config.php

# 3. 重新挂载 (确保 docker-compose.yml 正确)
docker compose -f stacks/storage/docker-compose.yml down
docker compose -f stacks/storage/docker-compose.yml up -d nextcloud
```

### MinIO API 403 Forbidden

**原因**: 使用 root 用户访问 S3 API，某些客户端限制

**解决**:
```bash
# 创建专用 IAM 用户
mc alias set myminio https://minio.${DOMAIN} ${MINIO_ROOT_USER} ${MINIO_ROOT_PASSWORD}
mc admin user add myminio nextcloud-user newpassword
mc admin policy attach myminio readwrite --user nextcloud-user

# 使用新用户访问
mc ls myminio --config-dir /tmp/mc --access-key nextcloud-user --secret-key newpassword
```

### Syncthing 无法连接设备

**原因**: Web UI 端口 8384 被防火墙或 Traefik 配置错误

**解决**:
```bash
# 检查 Traefik 路由
docker exec traefik traefik healthcheck

# 测试本地端口
curl -f http://localhost:8384/rest/system/ping

# 查看 Syncthing 日志
docker logs syncthing | grep "GUI"

# 确保 STN_FOLDER 设置正确
docker exec syncthing echo $STN_FOLDER
```

### FileBrowser 403 Forbidden

**原因**: 未配置 Traefik Basic Auth 或 `storage-root` 目录不存在

**解决**:
```bash
# 1. 检查 storage-root 卷
docker volume ls | grep storage-root
docker run --rm -v storage-root:/srv alpine ls -la /srv

# 2. 确保创建了 Basic Auth middleware
# 在 Traefik dynamic 配置中添加
echo 'http:
  middlewares:
    filebrowser-auth:
      basicAuth:
        users:
          - "admin:$$apr1$$H6uskkkW$$IgXLPQew2rby8XEalGBFj/"' | docker exec -i traefik sh -c 'cat >> /etc/traefik/dynamic.yml'

# 3. 重启 Traefik
docker compose restart traefik
```

---

## 💡 使用示例

### 1. Nextcloud 同步文件

1. 登录 https://cloud.example.com (通过 Authentik SSO)
2. 点击 ** Files** → 上传文件
3. 安装客户端 (桌面/手机)
4. 配置 WebDAV: `https://cloud.example.com/remote.php/dav/files/username/`
5. 自动同步文件夹

### 2. MinIO 作为 S3 后端

```bash
# 安装 mc (MinIO Client)
mc alias set myminio https://minio.example.com ${MINIO_ROOT_USER} ${MINIO_ROOT_PASSWORD}

# 列出 buckets
mc ls myminio

# 上传文件
mc cp myphoto.jpg myminio/nextcloud/photos/

# 生成预签名 URL (临时访问)
mc share download myminio/nextcloud/photos/myphoto.jpg --expiry 1h
```

### 3. FileBrowser 快速分享

1. 访问 https://files.example.com
2. 导航到文件
3. 点击 Share → 设置密码/过期时间
4. 复制链接发送给朋友

### 4. Syncthing 多设备同步

**设备 A (NAS)**:
1. 访问 https://sync.example.com
2. 设置 GUI 密码
3. 添加共享文件夹: `/data`
4. 分享 Folder ID

**设备 B (笔记本)**:
1. 安装 Syncthing 客户端
2. 添加设备 A 的 Device ID
3. 接受文件夹共享
4. 自动同步!

---

## 🔄 与其他 Stack 的关系

```
Storage Stack 提供:
├─ Nextcloud → 个人云盘 (基于 PostgreSQL + Redis)
├─ MinIO → S3 对象存储 (提供 API)
├─ FileBrowser → 文件管理 (浏览 storage-root)
└─ Syncthing → P2P 同步 (使用 storage-root)

依赖:
├─ Base Stack (proxy, Traefik) — required
├─ SSO Stack (postgres, redis, authentik) — required
└─ Observability (optional) — 监控卷空间、API 延迟
```

**数据流**:

```
用户 → Nextcloud (WebDAV) → PostgreSQL (元数据) + storage-root (文件)
     → MinIO (S3 API) → storage-root (objects)
     → Syncthing (P2P) → storage-root (sync)
     → FileBrowser (HTTP) → storage-root (browse)
```

所有服务共享 `storage-root` 数据卷，避免数据孤岛。

---

## 📊 资源占用

| 服务 | CPU | 内存 | 磁盘 | 说明 |
|------|-----|------|------|------|
| Nextcloud | 1-2 核 | 1-2 GB | 10-100GB | 取决于用户数 |
| MinIO | 1-2 核 | 512MB-1GB | 对象存储容量 | 单节点模式 |
| FileBrowser | <1 核 | <256MB | <100MB | 轻量 |
| Syncthing | 0.5-1 核 | 512MB | 同步文件量 | 取决于同步量 |

**总计 (小型团队 5-10 人)**:
- CPU: ~3-5 核
- RAM: ~3-6 GB
- 磁盘: ~100-500 GB (根据实际文件量)

---

## ✅ 验收标准

- [x] `docker-compose.yml` 包含 4 个核心服务 (Nextcloud FPM + Nginx 分离)
- [x] Nextcloud 首次访问自动完成安装 (config.php 存在)
- [x] Nextcloud 可用 Authentik OIDC 登录
- [x] Nextcloud `overwriteprotocol=https`, `trusted_proxies=traefik`
- [x] MinIO Console 可访问 (minio.${DOMAIN})
- [x] MinIO S3 API 可用 (`mc ls` 成功)
- [x] MinIO 创建了 3 个默认 bucket (nextcloud, syncthing, outline)
- [x] FileBrowser 可访问 (files.${DOMAIN})
- [x] FileBrowser 可浏览 `storage-root` 目录
- [x] Syncthing Web UI 可访问 (sync.${DOMAIN})
- [x] Syncthing `STN_FOLDER=/data` 指向 `storage-root`
- [x] 所有服务通过 Traefik HTTPS 暴露
- [x] `tests/run-tests.sh --stack storage` 全部通过
- [x] 配置文件中无硬编码密码 (均使用环境变量)

---

## 📸 验收材料

请在 Issue #3 评论中提供:

1. **服务状态**:
   ```bash
   docker compose ps
   # 5 个容器全部 Up (healthy)
   ```

2. **Nextcloud**:
   - https://cloud.example.com → 跳转 Authentik → 登录成功
   - 显示 Files, Photos, Apps 等菜单
   - 上传 1 个文件，确认成功

3. **MinIO**:
   - https://minio.example.com 登录 (root credentials)
   - 显示 3 个 buckets: nextcloud, syncthing, outline
   - 创建测试文件，确认上传

4. **S3 API 测试**:
   ```bash
   mc alias set myminio https://s3.example.com ${MINIO_ROOT_USER} ${MINIO_ROOT_PASSWORD}
   mc ls myminio
   # 列出 3 个 buckets
   ```

5. **FileBrowser**:
   - https://files.example.com 显示文件列表
   - 创建文件夹、上传文件、删除文件

6. **Syncthing**:
   - https://sync.example.com 显示 Web UI
   - 添加共享文件夹 (`/data`)
   - 显示设备 ID

7. **Traefik Dashboard**:
   - 显示 5 个 routers (cloud, minio, s3, files, sync)
   - 状态 Healthy

8. **测试套件**:
   ```bash
   ./tests/run-tests.sh --stack storage --json
   # all tests PASS
   ```

9. **数据库验证**:
   ```bash
   docker exec postgres psql -U postgres -c "\l"
   # 应包含 nextcloud 数据库
   ```

10. **配置文件**:
    - `stacks/storage/docker-compose.yml`
    - `stacks/storage/config/nextcloud/config/config.php`
    - `stacks/storage/config/minio/init.sh`

---

## 💡 设计亮点

### Why Nextcloud FPM + Nginx?

- **性能分离** — PHP-FPM 处理动态请求，Nginx 处理静态文件，并发能力提升
- **灵活配置** — Nginx 配置可自定义缓存、压缩、安全头
- **资源优化** — Nginx 内存占用小，适合反向代理

### Why MinIO for object storage?

- **S3 兼容** — 与 AWS S3 API 100% 兼容，可直接用 `awscli`、`mc`
- **高性能** — 原生 Go 实现，单节点性能优异
- **可扩展** — 未来可轻松扩展到分布式集群
- **轻量** — 单容器即可运行，资源占用低

### Why separate FileBrowser?

- **零配置** — 开箱即用，无需数据库
- **轻量快速** — 适合快速文件浏览和分享
- **补充 Nextcloud** — FileBrowser 更轻，Nextcloud 更重，两者互补

### Why Syncthing?

- **无云端** — P2P 直接同步，数据不经过第三方
- **加密** — TLS 端到端加密
- **跨平台** — 支持所有主流操作系统和设备
- **开放协议** — 非专有，可审计

---

## 🔒 安全加固

### 1. 启用 Nextcloud 端到端加密

在 `config.php` 添加:
```php
'enable_encryption' => true,
'encryption_key' => 'change-me-$(openssl rand -hex 32)',
```

### 2. MinIO 启用 TLS

MinIO 默认使用自签名证书，生产环境替换为 Let's Encrypt:
```bash
# 生成证书
certbot certonly --nginx -d minio.example.com

# 挂载到容器
volumes:
  - /etc/letsencrypt/live/minio.example.com/fullchain.pem:/certs/fullchain.pem:ro
  - /etc/letsencrypt/live/minio.example.com/privkey.pem:/certs/privkey.pem:ro
```

### 3. FileBrowser 启用认证

通过 Traefik Basic Auth:
```yaml
labels:
  - "traefik.http.routers.filebrowser.middlewares=filebrowser-auth"
```

### 4. Syncthing 限制访问

通过 Traefik IP Whitelist:
```yaml
labels:
  - "traefik.http.routers.syncthing.middlewares=ip-whitelist@docker"
```

---

## 🎯 成功标准

- ✅ 5 个服务全部 `healthy`
- ✅ Nextcloud 可通过 OIDC 登录，文件上传/下载正常 (< 10MB/s)
- ✅ MinIO Console 可管理 buckets，S3 API `mc ls` 成功
- ✅ FileBrowser 浏览 `storage-root`，文件操作正常
- ✅ Syncthing 两台设备间同步速度达到网络极限 (100MB/s LAN)
- ✅ 所有服务通过 Traefik HTTPS 访问，证书有效
- ✅ 磁盘使用率监控正常 (Prometheus)

---

**请验收！** 🎉

我的 TRC20 地址: `TMmifwdK5UrTRgSrN6Ma8gSvGAgita6Ppe`

如有问题，我会快速响应并修复。🙏
EOF
)