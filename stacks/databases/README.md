# Databases Stack

共享数据库层，为所有 homelab 服务提供 PostgreSQL、Redis 和 MariaDB 支持。

## 服务架构

```
┌─────────────────────────────────────────────────────────┐
│                     Databases Stack                       │
├─────────────────────────────────────────────────────────┤
│                                                          │
│   PostgreSQL (主数据库)                                  │
│   ├── 多租户架构：每个服务独立数据库                     │
│   ├── pgAdmin Web管理界面                               │
│   └── 服务：Nextcloud, Gitea, Outline, Authentik, etc. │
│                                                          │
│   Redis (缓存/队列)                                      │
│   ├── Redis Commander Web管理界面                       │
│   ├── 多数据库隔离（DB 0-4）                           │
│   └── 服务：Authentik, Outline, Gitea, Grafana         │
│                                                          │
│   MariaDB (MySQL兼容)                                    │
│   ├── Nextcloud可选数据库                               │
│   └── 服务：Nextcloud (可选)                            │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

## Redis 多数据库分配

| DB | 服务 | 用途 |
|----|------|------|
| 0 | Authentik | SSO会话存储 |
| 1 | Outline | 缓存 |
| 2 | Gitea | Session/Cache |
| 3 | Nextcloud | 缓存 |
| 4 | Grafana | Sessions |

## 快速开始

### 1. 配置环境变量

在 `.env` 中添加：

```env
# PostgreSQL
POSTGRES_ROOT_PASSWORD=your_secure_password
POSTGRES_ROOT_USER=postgres

# Redis
REDIS_PASSWORD=your_redis_password

# MariaDB (可选)
MARIADB_ROOT_PASSWORD=your_mariadb_password

# pgAdmin
PGADMIN_EMAIL=admin@example.com
PGADMIN_PASSWORD=pgadmin_password

# 各服务数据库密码
NEXTCLOUD_DB_PASSWORD=nextcloud_secret
GITEA_DB_PASSWORD=gitea_secret
OUTLINE_DB_PASSWORD=outline_secret
AUTHENTIK_DB_PASSWORD=authentik_secret
GRAFANA_DB_PASSWORD=grafana_secret
```

### 2. 启动服务

```bash
cd homelab-stack
docker compose -f stacks/databases/docker-compose.yml up -d
```

### 3. 初始化数据库

```bash
# 创建所有服务数据库和用户
./scripts/init-databases.sh

# 或在数据库容器内直接执行
docker exec -it homelab-postgres psql -U postgres -c "CREATE DATABASE myservice;"
```

### 4. 验证服务

```bash
# 检查所有容器状态
docker compose -f stacks/databases/docker-compose.yml ps

# 测试 PostgreSQL 连接
docker exec -it homelab-postgres psql -U postgres -l

# 测试 Redis 连接
docker exec -it homelab-redis redis-cli -a "${REDIS_PASSWORD}" ping
```

## 管理界面

| 服务 | 地址 | 凭据 |
|------|------|------|
| pgAdmin | https://pgadmin.${DOMAIN} | PGADMIN_EMAIL / PGADMIN_PASSWORD |
| Redis Commander | https://redis.${DOMAIN} | 无需登录，直接访问 |

## 服务连接字符串

各服务连接数据库时使用以下连接字符串：

### PostgreSQL

```env
# Nextcloud
DATABASE_HOST=homelab-postgres
DATABASE_PORT=5432
DATABASE_NAME=nextcloud
DATABASE_USER=nextcloud
DATABASE_PASSWORD=${NEXTCLOUD_DB_PASSWORD}

# Gitea
DATABASE_HOST=homelab-postgres
DATABASE_PORT=5432
DATABASE_NAME=gitea
DATABASE_USER=gitea
DATABASE_PASSWORD=${GITEA_DB_PASSWORD}

# Outline
DATABASE_URL=postgresql://outline:${OUTLINE_DB_PASSWORD}@homelab-postgres:5432/outline

# Authentik
AUTHENTIK_POSTGREQL_HOST=homelab-postgres
AUTHENTIK_POSTGREQL_PORT=5432
AUTHENTIK_POSTGREQL_NAME=authentik
AUTHENTIK_POSTGREQL_USER=authentik
AUTHENTIK_POSTGREQL_PASSWORD=${AUTHENTIK_DB_PASSWORD}

# Grafana
GF_DATABASE_HOST=homelab-postgres:5432
GF_DATABASE_NAME=grafana
GF_DATABASE_USER=grafana
GF_DATABASE_PASSWORD=${GRAFANA_DB_PASSWORD}
```

### Redis

```env
# Authentik (DB 0)
AUTHENTIK_REDIS_HOST=homelab-redis
AUTHENTIK_REDIS_PORT=6379
AUTHENTIK_REDIS_DB=0

# Outline (DB 1)
REDIS_URL=redis://:${REDIS_PASSWORD}@homelab-redis:6379/1

# Gitea (DB 2)
REDIS_HOST=homelab-redis
REDIS_PORT=6379
REDIS_DB=2
REDIS_PASSWORD=${REDIS_PASSWORD}

# Nextcloud (DB 3)
REDIS_HOST=homelab-redis
REDIS_PORT=6379
REDIS_DB=3
REDIS_PASSWORD=${REDIS_PASSWORD}

# Grafana (DB 4)
GF_REDIS_URL=redis://:${REDIS_PASSWORD}@homelab-redis:6379/4
```

### MariaDB (可选，Nextcloud)

```env
MYSQL_HOST=homelab-mariadb
MYSQL_PORT=3306
MYSQL_DATABASE=nextcloud
MYSQL_USER=nextcloud
MYSQL_PASSWORD=${NEXTCLOUD_DB_PASSWORD}
```

## 备份

### 自动备份

```bash
# 备份所有数据库
./scripts/backup-databases.sh

# 备份保存位置: ./backups/databases_YYYYMMDD_HHMMSS/
```

### 备份内容

- `postgresql_all.gz` - 所有PostgreSQL数据库
- `redis.rdb.gz` - Redis数据
- `mariadb.tar.gz` - MariaDB数据（如启用）
- `manifest.txt` - 备份元信息

### 备份保留策略

默认保留最近7天备份，可通过 `RETENTION_DAYS` 环境变量修改。

### 可选：上传到MinIO

```env
MINIO_ENDPOINT=https://minio.example.com
MINIO_ACCESS_KEY=your_access_key
MINIO_SECRET_KEY=your_secret_key
```

## 健康检查

所有数据库容器配置了健康检查，其他服务可以通过 `depends_on: condition: service_healthy` 确保数据库就绪后再启动。

```yaml
services:
  myapp:
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
```

## 网络隔离

数据库服务仅加入 `internal` 网络，不暴露到公网。管理界面（pgAdmin、Redis Commander）通过 `proxy` 网络暴露，可通过 Traefik 访问。

## 故障排除

### 数据库连接失败

1. 检查容器状态：`docker compose -f stacks/databases/docker-compose.yml ps`
2. 检查日志：`docker compose logs postgres`
3. 确认网络配置正确

### pgAdmin 无法连接 PostgreSQL

1. 确认 `config/pgadmin/servers.json` 配置正确
2. 检查 PostgreSQL 是否允许连接：`grep listen_addresses /var/lib/postgresql/data/postgresql.conf`

### Redis 连接失败

1. 确认密码正确
2. 检查 Redis 日志：`docker compose logs redis`

## 环境变量

| 变量 | 默认值 | 说明 |
|------|--------|------|
| POSTGRES_ROOT_PASSWORD | (必填) | PostgreSQL root密码 |
| POSTGRES_ROOT_USER | postgres | PostgreSQL用户名 |
| REDIS_PASSWORD | (必填) | Redis密码 |
| MARIADB_ROOT_PASSWORD | - | MariaDB root密码（可选） |
| PGADMIN_EMAIL | (必填) | pgAdmin登录邮箱 |
| PGADMIN_PASSWORD | (必填) | pgAdmin密码 |
| DOMAIN | (必填) | 域名 |
| NEXTCLOUD_DB_PASSWORD | - | Nextcloud数据库密码 |
| GITEA_DB_PASSWORD | - | Gitea数据库密码 |
| OUTLINE_DB_PASSWORD | - | Outline数据库密码 |
| AUTHENTIK_DB_PASSWORD | - | Authentik数据库密码 |
| GRAFANA_DB_PASSWORD | - | Grafana数据库密码 |

## 相关文档

- [PostgreSQL 文档](https://www.postgresql.org/docs/)
- [Redis 文档](https://redis.io/documentation)
- [MariaDB 文档](https://mariadb.com/kb/en/documentation/)
- [pgAdmin 文档](https://www.pgadmin.org/docs/)
- [Redis Commander](https://github.com/joeferner/redis-commander)
