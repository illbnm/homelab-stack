## 任务

Closes #3 — `[BOUNTY $150] Storage Stack — Nextcloud + MinIO + FileBrowser`

## 交付内容

### 1. stacks/storage/docker-compose.yml
- **Nextcloud 29.0.7 FPM** + Nginx 前端
  - 共享 PostgreSQL (database: nextcloud)
  - 共享 Redis DB 3 (缓存+锁)
  - Traefik HTTPS + CalDAV/CardDAV 重定向
- **MinIO** S3 兼容对象存储
  - Console: `minio.${DOMAIN}`
  - API: `s3.${DOMAIN}`
  - 自动初始化 bucket (backups/nextcloud/media/documents)
- **FileBrowser** 轻量文件管理
  - 浏览 `${STORAGE_ROOT}` 目录
- **Syncthing** P2P 文件同步
  - 同步端口: 22000/tcp, 22000/udp, 21027/udp
- 所有服务含健康检查

### 2. config/nextcloud/nginx.conf
- FPM upstream 配置
- 安全 headers (Referrer-Policy, X-Content-Type-Options 等)
- .well-known 重定向 (CalDAV/CardDAV/WebFinger)
- 10G 上传限制
- 静态资源缓存

### 3. stacks/storage/README.md
- 快速启动指南
- Nextcloud 数据库/Redis/OIDC 配置说明
- MinIO mc 客户端连接示例
- FileBrowser/Syncthing 使用说明

## 验收标准对照

- [x] Nextcloud 首次访问自动完成安装
- [x] Nextcloud 可用 Authentik 账号登录 (OIDC 配置说明)
- [x] MinIO Console 可访问，API 可用 mc 客户端连接
- [x] FileBrowser 可浏览 ${STORAGE_ROOT} 目录
- [x] Syncthing 可与外部设备同步
- [x] 所有服务通过 Traefik 反代，HTTPS 生效
