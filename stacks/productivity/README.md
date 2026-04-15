# Productivity Stack

完整的生产力工具栈，提供代码托管、密码管理、知识库、PDF处理和对象存储。

## 服务列表

| 服务 | 端口 | 子域名 | 说明 |
|------|------|--------|------|
| Gitea | 3000 | git.DOMAIN | Git代码托管 |
| Vaultwarden | 80 | vault.DOMAIN | 密码管理器 (Bitwarden兼容) |
| Outline | 3000 | docs.DOMAIN | 团队知识库 |
| BookStack | 80 | wiki.DOMAIN | 文档/Wiki |
| MinIO | 9000/9001 | minio.DOMAIN | S3兼容对象存储 |
| Stirling PDF | 8080 | pdf.DOMAIN | PDF处理工具 |

## 快速开始

```bash
cd stacks/productivity

# 1. 配置环境变量
cp .env.example .env
# 编辑 .env，填入必要值

# 2. 生成密钥
openssl rand -hex 32  # OUTLINE_SECRET_KEY
openssl rand -hex 32  # GITEA_OAUTH_JWT_SECRET
openssl rand -hex 32  # VAULTWARDEN_ADMIN_TOKEN
echo "base64:$(openssl rand -base64 32)"  # BOOKSTACK_APP_KEY

# 3. 启动服务
docker compose up -d
```

## 服务配置

### Gitea
- 禁用公开注册
- OIDC登录 (Authentik集成)
- PostgreSQL数据库
- 健康检查: `http://localhost:3000`

### Vaultwarden
- 管理面板: `https://vault.DOMAIN/admin`
- 禁用公开注册（管理员邀请）
- 必须HTTPS（浏览器扩展要求）
- 健康检查: `http://localhost:80/alive`

### Outline
- OIDC登录 (Authentik)
- MinIO S3存储后端
- Redis DB 1
- 健康检查: `http://localhost:3000/_health`

### BookStack
- 支持OIDC或本地认证
- MariaDB数据库
- 健康检查: `http://localhost:80/login`

### MinIO
- S3兼容API
- 控制台: `https://minio-console.DOMAIN`
- Outline bucket自动创建
- 健康检查: `http://localhost:9000/minio/health/live`

### Stirling PDF
- 50+ PDF操作
- 无需登录
- 中文+英文界面
- 健康检查: `http://localhost:8080/api/v1/info`

## 依赖关系

```
Traefik (HTTPS)
    ├── git.DOMAIN      → Gitea
    ├── vault.DOMAIN    → Vaultwarden
    ├── docs.DOMAIN     → Outline ──→ MinIO (S3存储)
    ├── wiki.DOMAIN     → BookStack
    ├── pdf.DOMAIN      → Stirling PDF
    ├── minio.DOMAIN    → MinIO API
    └── minio-console.DOMAIN → MinIO Console

PostgreSQL (databases stack)
    ├── gitea
    ├── vaultwarden
    └── outline

Redis (databases stack)
    └── outline (DB 1)

MariaDB (databases stack)
    └── bookstack

MinIO (本栈)
    └── outline (S3存储)
```

## 连接字符串

### PostgreSQL
```
gitea:       postgresql://gitea:${GITEA_DB_PASSWORD}@homelab-postgres:5432/gitea
vaultwarden: postgresql://vaultwarden:${VAULTWARDEN_DB_PASSWORD}@homelab-postgres:5432/vaultwarden
outline:     postgresql://outline:${OUTLINE_DB_PASSWORD}@homelab-postgres:5432/outline
```

### Redis
```
outline: redis://:${REDIS_PASSWORD}@homelab-redis:6379/1
```

### MariaDB
```
bookstack: mysql://bookstack:${BOOKSTACK_DB_PASSWORD}@homelab-mariadb:3306/bookstack
```

### MinIO (S3)
```
Endpoint: http://minio:9000
Access Key: ${MINIO_ACCESS_KEY}
Secret Key: ${MINIO_SECRET_KEY}
Bucket: outline
```

## 故障排查

### Outline无法连接MinIO
```bash
# 检查MinIO状态
docker logs minio

# 检查bucket是否存在
docker exec minio-init mc ls myminio/

# 手动创建bucket
docker exec minio-init mc mb myminio/outline
```

### Vaultwarden浏览器扩展无法连接
- 确认使用HTTPS
- 检查DOMAIN环境变量设置正确

### OIDC登录失败
```bash
# 检查Authentik中OIDC应用配置
# 确认client_id和client_secret正确
# 检查回调URL设置
```

## 性能调优

- Gitea: 默认配置适合中小规模团队
- Vaultwarden: SQLite可选（小规模）或PostgreSQL（大规模）
- Outline: 确保Redis有足够内存
- MinIO: 根据存储需求调整volume大小
