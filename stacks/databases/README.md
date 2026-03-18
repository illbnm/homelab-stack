# 🗄️ Database Stack — 共享数据库层

> PostgreSQL (多租户) + Redis (多DB) + MariaDB + 管理界面 — 所有服务共用一套数据库，节省资源。

## 服务清单

| 服务 | 镜像 | 网络 | 用途 |
|------|------|------|------|
| **PostgreSQL** | `postgres:16.4-alpine` | internal | 主数据库 (多租户) |
| **Redis** | `redis:7.4.0-alpine` | internal | 缓存/队列 |
| **MariaDB** | `mariadb:11.5.2` | internal | MySQL 兼容 |
| **pgAdmin** | `dpage/pgadmin4:8.11` | internal + proxy | PostgreSQL 管理界面 |
| **Redis Commander** | `rediscommander/redis-commander` | internal + proxy | Redis 管理界面 |

## 快速启动

```bash
# 1. 确保 base infrastructure 和 internal 网络已运行
docker network create internal 2>/dev/null || true

# 2. 配置 .env
POSTGRES_ROOT_PASSWORD=your_secure_password
REDIS_PASSWORD=your_redis_password
MARIADB_ROOT_PASSWORD=your_mariadb_password
PGADMIN_EMAIL=admin@homelab.local
PGADMIN_PASSWORD=your_pgadmin_password
NEXTCLOUD_DB_PASSWORD=nextcloud_pass
GITEA_DB_PASSWORD=gitea_pass
OUTLINE_DB_PASSWORD=outline_pass
AUTHENTIK_DB_PASSWORD=authentik_pass
GRAFANA_DB_PASSWORD=grafana_pass

# 3. 启动数据库栈
docker compose -f stacks/databases/docker-compose.yml up -d

# 4. 验证初始化
docker exec postgres psql -U postgres -c "\l"
```

## 多租户 PostgreSQL

`scripts/init-databases.sh` 在 PostgreSQL 首次启动时自动执行，为每个服务创建独立的 database + user：

| 服务 | 数据库名 | 用户名 | 密码变量 |
|------|---------|--------|---------|
| Nextcloud | nextcloud | nextcloud | `NEXTCLOUD_DB_PASSWORD` |
| Gitea | gitea | gitea | `GITEA_DB_PASSWORD` |
| Outline | outline | outline | `OUTLINE_DB_PASSWORD` |
| Authentik | authentik | authentik | `AUTHENTIK_DB_PASSWORD` |
| Grafana | grafana | grafana | `GRAFANA_DB_PASSWORD` |

脚本是幂等的 — 重复执行不报错，不重置已有数据。

手动重新执行：
```bash
docker exec postgres bash /docker-entrypoint-initdb.d/init-databases.sh
```

## Redis 多数据库分配

通过连接字符串中的 `?db=N` 参数隔离各服务：

| DB | 服务 | 连接字符串 |
|----|------|-----------|
| 0 | Authentik | `redis://:${REDIS_PASSWORD}@redis:6379/0` |
| 1 | Outline | `redis://:${REDIS_PASSWORD}@redis:6379/1` |
| 2 | Gitea | `redis://:${REDIS_PASSWORD}@redis:6379/2` |
| 3 | Nextcloud | `redis://:${REDIS_PASSWORD}@redis:6379/3` |
| 4 | Grafana | `redis://:${REDIS_PASSWORD}@redis:6379/4` |

## 各服务连接字符串

### PostgreSQL
```
# Nextcloud
POSTGRES_HOST=postgres
POSTGRES_DB=nextcloud
POSTGRES_USER=nextcloud
POSTGRES_PASSWORD=${NEXTCLOUD_DB_PASSWORD}

# Gitea
DATABASE_URL=postgres://gitea:${GITEA_DB_PASSWORD}@postgres:5432/gitea?sslmode=disable

# Outline
DATABASE_URL=postgres://outline:${OUTLINE_DB_PASSWORD}@postgres:5432/outline

# Authentik
AUTHENTIK_POSTGRESQL__HOST=postgres
AUTHENTIK_POSTGRESQL__NAME=authentik
AUTHENTIK_POSTGRESQL__USER=authentik
AUTHENTIK_POSTGRESQL__PASSWORD=${AUTHENTIK_DB_PASSWORD}

# Grafana
GF_DATABASE_TYPE=postgres
GF_DATABASE_HOST=postgres:5432
GF_DATABASE_NAME=grafana
GF_DATABASE_USER=grafana
GF_DATABASE_PASSWORD=${GRAFANA_DB_PASSWORD}
```

### MariaDB (Nextcloud 可选)
```
MYSQL_HOST=mariadb
MYSQL_DATABASE=nextcloud
MYSQL_USER=root
MYSQL_PASSWORD=${MARIADB_ROOT_PASSWORD}
```

## 管理界面

| 服务 | URL |
|------|-----|
| pgAdmin | `https://pgadmin.${DOMAIN}` |
| Redis Commander | `https://redis.${DOMAIN}` |

## 网络隔离

数据库服务仅在 `internal` 网络中，不通过 Traefik 对外暴露：
- PostgreSQL: `postgres:5432` (仅 internal)
- Redis: `redis:6379` (仅 internal)
- MariaDB: `mariadb:3306` (仅 internal)
- pgAdmin/Redis Commander: 通过 Traefik 暴露管理界面

其他 Stack 通过 `depends_on: condition: service_healthy` 等待数据库就绪。

## 备份

```bash
# 手动备份
./scripts/backup-databases.sh

# 上传到 MinIO
./scripts/backup-databases.sh --upload-minio
```

备份内容：
- `pg_dumpall.sql` — 所有 PostgreSQL 数据库
- `redis-dump.rdb` — Redis 持久化快照
- 压缩为 `.tar.gz`，保留最近 7 天

### 定时备份

```bash
# 每日 2:00 AM 自动备份
echo "0 2 * * * /opt/homelab/scripts/backup-databases.sh" | crontab -
```

## 常见问题

### init-databases.sh 报错？
确保 PostgreSQL 容器已完全启动：
```bash
docker compose -f stacks/databases/docker-compose.yml ps
docker logs postgres
```

### 其他服务连不上数据库？
1. 确认服务在同一个 `internal` 网络
2. 确认 `depends_on: condition: service_healthy`
3. 检查密码是否匹配 `.env` 配置

### pgAdmin 无法连接？
首次登录后需手动添加服务器：
- Host: `postgres`
- Port: `5432`
- Username: `postgres`
- Password: `${POSTGRES_ROOT_PASSWORD}`
