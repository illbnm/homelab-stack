# 📦 Storage Stack — Nextcloud + MinIO + FileBrowser + Syncthing

> 完整自托管存储栈：个人云盘、S3 对象存储、文件管理、P2P 同步。

## 服务清单

| 服务 | 镜像 | URL | 用途 |
|------|------|-----|------|
| **Nextcloud** | `nextcloud:29.0.7-fpm-alpine` | `cloud.${DOMAIN}` | 个人云盘 |
| **MinIO** | `minio/minio:RELEASE.2024-09-22` | `minio.${DOMAIN}` / `s3.${DOMAIN}` | 对象存储 |
| **FileBrowser** | `filebrowser/filebrowser:v2.31.1` | `files.${DOMAIN}` | 轻量文件管理 |
| **Syncthing** | `linuxserver/syncthing:1.27.11` | `sync.${DOMAIN}` | P2P 文件同步 |

## 前置依赖

- **Base Stack** (Traefik + 网络)
- **Databases Stack** (PostgreSQL + Redis)

## 快速启动

```bash
# 1. 配置 .env
NEXTCLOUD_ADMIN_USER=admin
NEXTCLOUD_ADMIN_PASSWORD=your_secure_password
NEXTCLOUD_DOMAIN=cloud.example.com
NEXTCLOUD_DB_PASSWORD=nextcloud_pass  # 需与 Databases Stack 一致
REDIS_PASSWORD=your_redis_pass        # 需与 Databases Stack 一致
MINIO_ROOT_USER=minioadmin
MINIO_ROOT_PASSWORD=your_minio_password
STORAGE_ROOT=/data/storage

# 2. 启动
docker compose -f stacks/storage/docker-compose.yml up -d

# 3. 验证
curl -sI https://cloud.example.com | head -5
```

## Nextcloud 配置

### 数据库连接
使用共享 PostgreSQL (Databases Stack):
- Host: `postgres`
- Database: `nextcloud`
- User: `nextcloud`
- Password: `${NEXTCLOUD_DB_PASSWORD}`

### Redis 缓存
使用共享 Redis DB 3:
- Host: `redis:6379`
- DB: `3`
- Password: `${REDIS_PASSWORD}`

### Authentik OIDC 登录
在 Authentik 中创建 OAuth2 Provider，然后在 Nextcloud 安装 `user_oidc` 应用并配置。

### 推荐 config.php 补充
```php
'trusted_proxies' => ['172.16.0.0/12'],
'overwriteprotocol' => 'https',
'default_phone_region' => 'CN',
'maintenance_window_start' => 1,  // UTC 1:00 AM
```

## MinIO

### 访问地址
- Console: `https://minio.${DOMAIN}` (端口 9001)
- API: `https://s3.${DOMAIN}` (端口 9000)

### 初始化
`minio-init` 容器自动创建默认 bucket:
- `backups` — 备份存储
- `nextcloud` — Nextcloud 外部存储
- `media` — 媒体文件
- `documents` — 文档

### mc 客户端连接
```bash
mc alias set homelab https://s3.example.com minioadmin your_password
mc ls homelab/
```

## FileBrowser

访问 `https://files.${DOMAIN}`，默认账号 `admin` / `admin`。

浏览 `${STORAGE_ROOT}` 目录下所有文件。

## Syncthing

访问 `https://sync.${DOMAIN}` 管理同步。

同步端口:
- `22000/tcp` — 同步协议
- `22000/udp` — QUIC
- `21027/udp` — 发现协议

### 添加外部设备
1. 打开 Syncthing Web UI
2. 添加远程设备 (输入 Device ID)
3. 共享文件夹 (`/data/syncthing/`)
