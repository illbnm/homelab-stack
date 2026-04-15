# Storage Stack / 存储服务栈

Self-hosted file storage, sync, and S3-compatible object storage.

自托管文件存储、同步与 S3 兼容的对象存储服务。

## What's Included / 包含服务

| Service | Version | URL | Purpose |
|---------|---------|-----|---------|
| Nextcloud | 29.0.9 | `nextcloud.<DOMAIN>` | File sync & share platform / 文件同步与共享 |
| PostgreSQL | 16.4 | — (internal) | Nextcloud database backend / 数据库 |
| Redis | 7.4 | — (internal) | Nextcloud cache & sessions / 缓存加速 |
| MinIO | 2024-11-07 | `minio.<DOMAIN>` (console) `s3.<DOMAIN>` (API) | S3-compatible object storage / 对象存储 |
| MinIO Init | — | — (one-shot) | Auto-create buckets / 自动创建存储桶 |
| FileBrowser | 2.31.2 | `files.<DOMAIN>` | Simple file management UI / 文件管理器 |
| Nextcloud Cron | — | — (background) | Scheduled background jobs / 定时任务 |

## Architecture / 架构

```
Internet
    |
    v
[Traefik :443]  (from base stack)
    |  TLS termination (Let's Encrypt)
    |
    +---> nextcloud.<DOMAIN>  --> Nextcloud (Apache)
    |                                |
    |                      +---------+---------+
    |                      |                   |
    |                  [PostgreSQL]         [Redis]
    |                   (storage)          (storage)
    |
    +---> minio.<DOMAIN>      --> MinIO Console (:9001)
    +---> s3.<DOMAIN>         --> MinIO S3 API  (:9000)
    |
    +---> files.<DOMAIN>      --> FileBrowser

[proxy]   = shared Docker network (Traefik-accessible)
[storage] = internal network (DB/Redis isolated)
```

## Prerequisites / 前置条件

- Base stack running (`stacks/base`) / 基础栈已运行
- Docker >= 24.0 with Compose v2 plugin
- Ports 80/443 open (handled by Traefik)
- Domain DNS records configured / DNS 已配置:
  - `nextcloud.<DOMAIN>` -> server IP
  - `minio.<DOMAIN>` -> server IP
  - `s3.<DOMAIN>` -> server IP
  - `files.<DOMAIN>` -> server IP

## Quick Start / 快速开始

```bash
# 1. Ensure base stack is running / 确保基础栈已运行
cd stacks/base && docker compose up -d && cd ../..

# 2. Create proxy network (if not exists) / 创建网络
docker network create proxy 2>/dev/null || true

# 3. Link root .env / 链接配置文件
cd stacks/storage
ln -sf ../../.env .env

# 4. Launch storage stack / 启动存储栈
docker compose up -d

# 5. Verify all services are healthy / 验证服务健康状态
docker compose ps
```

## Configuration / 配置说明

### Environment Variables (`.env`)

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `DOMAIN` | Yes | — | Base domain / 基础域名 |
| `TZ` | Yes | `Asia/Shanghai` | Timezone / 时区 |
| `NEXTCLOUD_ADMIN_USER` | Yes | `admin` | Nextcloud admin username / 管理员用户名 |
| `NEXTCLOUD_ADMIN_PASSWORD` | Yes | — | Nextcloud admin password / 管理员密码 |
| `NEXTCLOUD_DB_NAME` | — | `nextcloud` | PostgreSQL database name |
| `NEXTCLOUD_DB_USER` | — | `nextcloud` | PostgreSQL username |
| `NEXTCLOUD_DB_PASSWORD` | Yes | — | PostgreSQL password / 数据库密码 |
| `NEXTCLOUD_REDIS_PASSWORD` | Yes | — | Redis password / Redis 密码 |
| `NEXTCLOUD_PHP_MEMORY_LIMIT` | — | `512M` | PHP memory limit |
| `NEXTCLOUD_PHP_UPLOAD_LIMIT` | — | `10G` | Max upload size |
| `MINIO_ROOT_USER` | — | `minioadmin` | MinIO root username |
| `MINIO_ROOT_PASSWORD` | Yes | — | MinIO root password / MinIO 密码 |
| `MINIO_DEFAULT_BUCKETS` | — | `backups,documents,media,nextcloud` | Auto-created buckets / 自动创建的桶 |
| `FILEBROWSER_ROOT` | — | `/data` | Host path for FileBrowser / 文件路径 |
| `PUID` | — | `1000` | User ID for file permissions |
| `PGID` | — | `1000` | Group ID for file permissions |

### Generate Strong Passwords / 生成强密码

```bash
# Generate all required passwords at once / 一次性生成所有密码
echo "NEXTCLOUD_ADMIN_PASSWORD=$(openssl rand -base64 24)"
echo "NEXTCLOUD_DB_PASSWORD=$(openssl rand -base64 24)"
echo "NEXTCLOUD_REDIS_PASSWORD=$(openssl rand -base64 24)"
echo "MINIO_ROOT_PASSWORD=$(openssl rand -base64 24)"
```

## CN Mirror Images / 国内镜像

For users in mainland China, replace image names in `docker-compose.yml`:

中国大陆用户可替换以下镜像源：

| Original | CN Mirror |
|----------|-----------|
| `nextcloud:29.0.9-apache` | `docker.m.daocloud.io/library/nextcloud:29.0.9-apache` |
| `postgres:16.4-alpine` | `docker.m.daocloud.io/library/postgres:16.4-alpine` |
| `redis:7.4-alpine` | `docker.m.daocloud.io/library/redis:7.4-alpine` |
| `minio/minio:RELEASE.2024-11-07T00-52-20Z` | `docker.m.daocloud.io/minio/minio:RELEASE.2024-11-07T00-52-20Z` |
| `minio/mc:RELEASE.2024-11-17T19-35-25Z` | `docker.m.daocloud.io/minio/mc:RELEASE.2024-11-17T19-35-25Z` |
| `filebrowser/filebrowser:v2.31.2` | `docker.m.daocloud.io/filebrowser/filebrowser:v2.31.2` |

Or configure Docker daemon mirror globally / 或全局配置 Docker 镜像加速：

```bash
./scripts/setup-cn-mirrors.sh
```

## Local Development / 本地开发

```bash
# Start with local overrides (no HTTPS, exposed ports)
# 使用本地覆盖启动（无 HTTPS，暴露端口）
docker compose -f docker-compose.yml -f docker-compose.local.yml up -d

# Access services locally / 本地访问
# Nextcloud:   http://nextcloud.localhost  or  http://localhost:80
# MinIO API:   http://localhost:9000
# MinIO UI:    http://localhost:9001
# FileBrowser: http://localhost:8085
# PostgreSQL:  localhost:15432
# Redis:       localhost:16379
```

## MinIO Usage / MinIO 使用

### S3 API Access

```bash
# Install mc (MinIO Client)
# 安装 MinIO 客户端
brew install minio/stable/mc   # macOS
# or download: https://min.io/download

# Configure alias
mc alias set homelab https://s3.<DOMAIN> minioadmin <YOUR_PASSWORD>

# List buckets / 列出所有桶
mc ls homelab

# Upload file / 上传文件
mc cp myfile.pdf homelab/documents/

# Download file / 下载文件
mc cp homelab/documents/myfile.pdf ./
```

### S3 Lifecycle Policy Examples / 生命周期策略示例

```bash
# Delete incomplete multipart uploads after 7 days
# 7 天后删除未完成的分片上传
mc ilm rule add --expire-delete-marker local/backups

# Keep only last 30 days of noncurrent versions
# 仅保留 30 天内的非当前版本
mc ilm rule add --noncurrent-expire-days 30 local/backups

# Auto-transition to infrequent access after 90 days (requires tiered storage)
# 90 天后自动转为低频访问（需配置分层存储）
mc ilm rule add --transition-days 90 --storage-class WARM local/media

# View current policies / 查看当前策略
mc ilm rule ls local/backups
```

### Connect Nextcloud to MinIO (S3 External Storage)

1. Enable the **External storage support** app in Nextcloud
2. Go to **Settings > External storage**
3. Add S3 storage with:
   - Bucket: `nextcloud`
   - Hostname: `minio` (internal Docker hostname)
   - Port: `9000`
   - Region: `us-east-1`
   - Enable SSL: No (internal network)
   - Enable path-style: Yes
   - Access key: your `MINIO_ROOT_USER`
   - Secret key: your `MINIO_ROOT_PASSWORD`

## Backup / 备份

### Critical Volumes / 关键数据卷

| Volume | Content | Priority |
|--------|---------|----------|
| `nextcloud-data` | User files, apps | **Critical** |
| `nextcloud-db-data` | PostgreSQL database | **Critical** |
| `nextcloud-config` | Nextcloud config | **High** |
| `minio-data` | All S3 objects | **Critical** |
| `filebrowser-db` | FileBrowser settings | Low |
| `nextcloud-redis-data` | Cache (regenerable) | Low |
| `nextcloud-custom-apps` | Installed apps (regenerable) | Low |

### Backup Commands / 备份命令

```bash
# Nextcloud: enable maintenance mode before backup
# 备份前启用维护模式
docker exec -u www-data nextcloud php occ maintenance:mode --on

# Backup Nextcloud data / 备份数据
docker run --rm -v nextcloud-data:/source -v /backup:/target \
  alpine tar czf /target/nextcloud-data-$(date +%Y%m%d).tar.gz -C /source .

# Backup PostgreSQL / 备份数据库
docker exec nextcloud-db pg_dump -U nextcloud nextcloud | \
  gzip > /backup/nextcloud-db-$(date +%Y%m%d).sql.gz

# Backup MinIO / 备份对象存储
mc mirror homelab/ /backup/minio-$(date +%Y%m%d)/

# Disable maintenance mode / 关闭维护模式
docker exec -u www-data nextcloud php occ maintenance:mode --off
```

### Restore / 恢复

```bash
# Restore PostgreSQL / 恢复数据库
gunzip -c /backup/nextcloud-db-20240101.sql.gz | \
  docker exec -i nextcloud-db psql -U nextcloud nextcloud

# Restore Nextcloud data / 恢复数据
docker run --rm -v nextcloud-data:/target -v /backup:/source \
  alpine tar xzf /source/nextcloud-data-20240101.tar.gz -C /target

# Restore MinIO / 恢复对象存储
mc mirror /backup/minio-20240101/ homelab/
```

## Nextcloud Performance Tuning / 性能调优

After first login, run these `occ` commands to optimize:

首次登录后执行以下命令优化性能：

```bash
# Set background job mode to cron (already handled by nextcloud-cron container)
# 设置后台任务模式为 cron
docker exec -u www-data nextcloud php occ background:cron

# Add missing indices / 添加缺失索引
docker exec -u www-data nextcloud php occ db:add-missing-indices

# Convert filecache bigint / 转换文件缓存大整数
docker exec -u www-data nextcloud php occ db:convert-filecache-bigint

# Scan files (if you added files outside Nextcloud) / 扫描文件
docker exec -u www-data nextcloud php occ files:scan --all
```

## FAQ / 常见问题

### Q: Nextcloud shows "access through untrusted domain" / 提示不受信任的域名

Add the domain to trusted_domains:

```bash
docker exec -u www-data nextcloud php occ config:system:set \
  trusted_domains 1 --value=nextcloud.<DOMAIN>
```

### Q: Large file uploads fail / 大文件上传失败

Adjust these environment variables in `.env`:

```env
NEXTCLOUD_PHP_UPLOAD_LIMIT=10G
NEXTCLOUD_PHP_MEMORY_LIMIT=1024M
```

Also ensure your Traefik has a large enough buffer. Add to Traefik's dynamic config:

```yaml
http:
  middlewares:
    large-upload:
      buffering:
        maxRequestBodyBytes: 10737418240  # 10GB
```

### Q: MinIO console shows "connection refused" / MinIO 控制台连接被拒绝

Ensure `MINIO_BROWSER_REDIRECT_URL` matches your domain exactly:

```env
MINIO_BROWSER_REDIRECT_URL=https://minio.yourdomain.com
```

### Q: Redis connection error in Nextcloud / Nextcloud 报 Redis 连接错误

Verify the Redis password matches between services:

```bash
# Check redis is reachable / 检查 Redis 是否可达
docker exec nextcloud-redis redis-cli -a <YOUR_REDIS_PASSWORD> ping
# Should return: PONG
```

### Q: How to update Nextcloud version? / 如何更新 Nextcloud 版本？

1. Update the image tag in `docker-compose.yml`
2. Run `docker compose pull nextcloud nextcloud-cron`
3. Run `docker compose up -d`
4. Run `docker exec -u www-data nextcloud php occ upgrade`
5. Run `docker exec -u www-data nextcloud php occ db:add-missing-indices`

### Q: FileBrowser default credentials / FileBrowser 默认密码

Default login is `admin` / `admin`. Change it immediately after first login.

默认用户名密码为 `admin` / `admin`，首次登录后请立即修改。

### Q: How to mount additional directories in FileBrowser? / 如何挂载额外目录？

Add volumes to the `filebrowser` service in `docker-compose.yml`:

```yaml
volumes:
  - filebrowser-db:/database
  - /data:/srv
  - /mnt/nas:/srv/nas:ro        # Read-only NAS mount
  - /home/user/docs:/srv/docs   # User documents
```
