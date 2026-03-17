---
name: 💰 Bounty - Storage Stack
about: 实现存储服务栈 (Nextcloud, MinIO, FileBrowser, Syncthing)
title: '[BOUNTY $150] Storage Stack — 存储服务'
labels: bounty, medium
assignees: ''
---

## 赏金金额

**$150 USDT**

## 任务描述

实现完整的自托管存储栈，覆盖个人云盘、对象存储、文件浏览、多设备同步。

## 服务清单

| 服务 | 镜像 | 用途 |
|------|------|------|
| Nextcloud | `nextcloud:29.0.7-fpm-alpine` | 个人云盘 |
| Nextcloud Nginx | `nginx:1.27-alpine` | Nextcloud FPM 前端 |
| MinIO | `minio/minio:RELEASE.2024-09-22T00-33-43Z` | 对象存储 (S3 兼容) |
| FileBrowser | `filebrowser/filebrowser:v2.31.1` | 轻量文件管理 |
| Syncthing | `lscr.io/linuxserver/syncthing:1.27.11` | P2P 文件同步 |

## 核心要求

### 1. Nextcloud

- 使用 FPM 模式 + Nginx
- 数据库使用共享 PostgreSQL (Databases Stack)
- Redis 用于缓存和锁 (共享 Redis)
- 支持 Authentik OIDC 登录
- 配置 `config.php`：`trusted_proxies`, `overwriteprotocol`, `default_phone_region`

### 2. MinIO

- Console 通过 `minio.${DOMAIN}` 访问
- API 通过 `s3.${DOMAIN}` 访问
- 配置初始化脚本：创建默认 bucket
- 可配置为 Nextcloud 的外部存储后端

### 3. 环境变量

```bash
NEXTCLOUD_ADMIN_USER=
NEXTCLOUD_ADMIN_PASSWORD=
NEXTCLOUD_DOMAIN=cloud.example.com
MINIO_ROOT_USER=
MINIO_ROOT_PASSWORD=
STORAGE_ROOT=/data/storage
```

## 验收标准

- [ ] Nextcloud 首次访问自动完成安装
- [ ] Nextcloud 可用 Authentik 账号登录
- [ ] MinIO Console 可访问，API 可用 `mc` 客户端连接
- [ ] FileBrowser 可浏览 `${STORAGE_ROOT}` 目录
- [ ] Syncthing 可与外部设备同步
- [ ] 所有服务通过 Traefik 反代，HTTPS 生效

## 认领方式

评论 "我来认领"。
