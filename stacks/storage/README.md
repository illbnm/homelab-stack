# Storage Stack

完整的自托管存储服务栈：个人云盘、对象存储、文件管理、P2P 同步。

## 服务概览

| 服务 | 镜像 | URL | 用途 |
|------|------|-----|------|
| Nextcloud | `nextcloud:29.0.7-fpm-alpine` | `https://cloud.${DOMAIN}` | 个人云盘 |
| Nextcloud Nginx | `nginx:1.27-alpine` | — | Nextcloud FPM 前端 |
| MinIO | `minio/minio:RELEASE.2024-09-22T00-33-43Z` | Console: `https://minio.${DOMAIN}`<br>API: `https://s3.${DOMAIN}` | S3 兼容对象存储 |
| FileBrowser | `filebrowser/filebrowser:v2.31.1` | `https://files.${DOMAIN}` | 轻量文件管理 |
| Syncthing | `lscr.io/linuxserver/syncthing:1.27.11` | `https://sync.${DOMAIN}` | P2P 文件同步 |

## 架构图

```
                    ┌─────────────┐
                    │   Traefik   │
                    │  (proxy)    │
                    └──────┬──────┘
           ┌───────────────┼───────────────┬──────────────┬──────────────┐
           │               │               │              │              │
    ┌──────┴──────┐ ┌──────┴──────┐ ┌──────┴──────┐ ┌────┴─────┐ ┌─────┴──────┐
    │  Nextcloud  │ │   MinIO     │ │ FileBrowser │ │Syncthing │ │  MinIO     │
    │   Nginx     │ │  Console    │ │             │ │          │ │  API       │
    │   :80       │ │  :9001      │ │   :80       │ │  :8384   │ │  :9000     │
    └──────┬──────┘ └─────────────┘ └─────────────┘ └──────────┘ └────────────┘
           │
    ┌──────┴──────┐         ┌──────────────┐
    │  Nextcloud  │────────▶│  PostgreSQL  │ (databases stack)
    │   FPM       │────────▶│  Redis       │ (databases stack)
    │   :9000     │         └──────────────┘
    └─────────────┘
```

## Quick Start

### 前置条件

1. **Databases 栈运行中** — PostgreSQL + Redis
2. **Traefik 已部署** — `proxy` 网络已创建
3. **DNS 记录已配置** — 指向 Traefik 服务器

### 部署步骤

```bash
cd stacks/storage

# 1. 配置环境变量
cp .env.example .env
nano .env  # 填入真实密码和域名

# 2. 准备 FileBrowser 配置
cp filebrowser/settings.json.example filebrowser/settings.json
# 编辑 settings.json，替换 {{FILEBROWSER_ADMIN_PASS}} 为实际密码

# 3. 创建存储目录
mkdir -p ${STORAGE_ROOT}/{nextcloud/{config,data,apps},minio,syncthing/{config,data}}

# 4. 确保网络存在
docker network create proxy 2>/dev/null
docker network create databases 2>/dev/null

# 5. 在 Databases 栈中创建 Nextcloud 数据库
docker exec -it homelab-postgres psql -U postgres -c \
  "CREATE USER nc_user WITH PASSWORD 'your_password';"
docker exec -it homelab-postgres psql -U postgres -c \
  "CREATE DATABASE nextcloud OWNER nc_user;"

# 6. 启动服务
docker compose up -d

# 7. 查看日志
docker compose logs -f
```

## Nextcloud 配置说明

### 首次安装

访问 `https://cloud.${DOMAIN}`，使用 `.env` 中的管理员账号登录，Nextcloud 会自动完成初始化。

### config.php 推荐配置

在 `${STORAGE_ROOT}/nextcloud/config/config.php` 中添加：

```php
<?php
$CONFIG = array(
  // 信任代理
  'trusted_proxies' => ['traefik', 'homelab-nextcloud-nginx'],

  // 协议
  'overwriteprotocol' => 'https',

  // 时区
  'default_phone_region' => 'CN',

  // Redis 缓存
  'memcache.local' => '\\OC\\Memcache\\APCu',
  'memcache.distributed' => '\\OC\\Memcache\\Redis',
  'memcache.locking' => '\\OC\\Memcache\\Redis',
  'redis' => array(
    'host' => 'homelab-redis',
    'port' => 6379,
    'password' => 'your_redis_password',
  ),

  // 数据库
  'dbtype' => 'pgsql',
  'dbhost' => 'homelab-postgres',
  'dbname' => 'nextcloud',
  'dbuser' => 'nc_user',
  'dbpassword' => 'your_db_password',
);
```

### Authentik OIDC 登录

1. 在 Authentik 中创建 OAuth2/OpenID Provider
2. 在 Nextcloud 中安装 `user_oidc` 应用
3. 登录 Nextcloud 管理面板 → Social Login → 添加 OpenID Connect 提供者

## MinIO S3 配置

### 客户端配置

```bash
# 安装 mc 客户端
wget https://dl.min.io/client/mc/release/linux-amd64/mc -O /usr/local/bin/mc
chmod +x /usr/local/bin/mc

# 配置别名
mc alias set homelab https://s3.${DOMAIN} ${MINIO_ROOT_USER} ${MINIO_ROOT_PASSWORD}

# 创建默认 bucket
mc mb homelab/data
mc mb homelab/backups

# 验证连接
mc admin info homelab
```

### 作为 Nextcloud 外部存储

1. Nextcloud 管理面板 → External Storage → 添加 S3 存储
2. 配置信息：
   - Bucket: `data`
   - Hostname: `s3.${DOMAIN}`
   - Port: `443`
   - Region: `us-east-1`
   - Access Key: `${MINIO_ROOT_USER}`
   - Secret Key: `${MINIO_ROOT_PASSWORD}`
   - Use SSL: ✅

## 验证清单

- [ ] Nextcloud 首次访问自动完成安装
- [ ] Nextcloud 管理员账号可登录
- [ ] Nextcloud Redis 缓存生效（管理面板概览无警告）
- [ ] Nextcloud 可选配置 Authentik OIDC 登录
- [ ] MinIO Console 可访问（`https://minio.${DOMAIN}`）
- [ ] MinIO API 可用 `mc` 客户端连接
- [ ] FileBrowser 管理员可登录，可浏览 `${STORAGE_ROOT}`
- [ ] Syncthing Web UI 可访问，可与外部设备配对
- [ ] 所有服务 HTTPS 生效，证书无错误
- [ ] Traefik 路由正常，无 502/503 错误
