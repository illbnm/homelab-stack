# Storage Stack — 存储服务栈

Nextcloud (FPM+Nginx) + MinIO + FileBrowser + Syncthing

## 目录结构

```
stacks/storage/
├── docker-compose.yml       # 服务编排
├── .env.example             # 环境变量模板
├── nginx/
│   └── nextcloud.conf       # Nextcloud Nginx 配置 (FPM 代理)
├── scripts/
│   └── minio-init.sh        # MinIO 初始化脚本 (bucket 创建)
└── README.md
```

## 快速开始

```bash
cp .env.example .env
# 编辑 .env，填入域名、密码等

docker compose up -d
docker compose ps
```

## 服务说明

| 服务 | 访问地址 | 用途 |
|------|---------|------|
| **Nextcloud** | `https://nextcloud.${DOMAIN}` | 个人云盘 (FPM + Nginx) |
| **MinIO Console** | `https://minio.${DOMAIN}` | 对象存储管理面板 |
| **MinIO API** | `https://s3.${DOMAIN}` | S3 兼容 API 端点 |
| **FileBrowser** | `https://files.${DOMAIN}` | 轻量文件管理 |
| **Syncthing** | `https://sync.${DOMAIN}` | P2P 文件同步 |

## Authentik OIDC 集成

Nextcloud 支持 Authentik 单点登录。安装后：

1. 在 Authentik 中创建 OIDC Provider:
   - Redirect URI: `https://nextcloud.${DOMAIN}/apps/user_oidc/code`
   - Client type: Confidential

2. 在 Nextcloud 启用 `user_oidc` 应用：
   ```bash
   docker exec nextcloud php occ app:enable user_oidc
   ```

3. 在 Nextcloud 配置 OIDC Provider:
   - 名称: Authentik
   - Client ID/Secret: 从 Authentik 获取
   - Discovery endpoint: `https://auth.${DOMAIN}/application/o/nextcloud/.well-known/openid-configuration`

## MinIO 初始化

`docker compose up -d` 时会自动运行 `minio-init` 服务创建默认 bucket。
也可以手动初始化：

```bash
docker compose run --rm minio-init
```

## 验证

```bash
# Nextcloud 状态
curl -sf https://nextcloud.${DOMAIN}/status.php

# MinIO 健康
curl -sf https://s3.${DOMAIN}/minio/health/live

# FileBrowser
curl -sf https://files.${DOMAIN}/

# Syncthing
curl -sf https://sync.${DOMAIN}/
```

## 依赖

- [Databases Stack](../databases/) — PostgreSQL + Redis (需先启动)
- [Network Stack](../network/) — Traefik 反向代理
- [SSO Stack](../sso/) — Authentik (可选，用于 OIDC)
