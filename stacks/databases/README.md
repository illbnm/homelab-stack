# 数据库栈 (Databases Stack)

## 概述

共享数据库层，供 Nextcloud、Outline、Gitea、Authentik 等服务共用。

| 服务 | 镜像 | 用途 |
|------|------|------|
| PostgreSQL | `postgres:16.4-alpine` | 主数据库（多租户） |
| Redis | `redis:7.4.0-alpine` | 缓存/队列 |
| MariaDB | `mariadb:11.5.2` | MySQL 兼容 |
| pgAdmin | `dpage/pgadmin4:8.11` | PostgreSQL 管理界面 |
| Redis Commander | `rediscommander/redis-commander:latest-sha` | Redis 管理界面 |

## 快速启动

```bash
# 1. 配置 .env 中的数据库密码
POSTGRES_ROOT_PASSWORD=<strong-password>
REDIS_PASSWORD=<strong-password>
MARIADB_ROOT_PASSWORD=<strong-password>
PGADMIN_EMAIL=admin@homelab.local
PGADMIN_PASSWORD=<strong-password>

# 2. 启动
./scripts/stack-manager.sh start databases

# 3. 验证
./scripts/stack-manager.sh status databases
```

## Redis 多数据库分配

| DB | 用途 |
|----|------|
| 0 | Authentik |
| 1 | Outline |
| 2 | Gitea |
| 3 | Nextcloud |
| 4 | Grafana sessions |

各服务连接示例：`redis://homelab-redis:6379/0?password=<REDIS_PASSWORD>`

## PostgreSQL 连接字符串

| 服务 | 连接串 |
|------|--------|
| Nextcloud | `postgresql://nextcloud:<NEXTCLOUD_DB_PASSWORD>@homelab-postgres:5432/nextcloud` |
| Gitea | `postgresql://gitea:<GITEA_DB_PASSWORD>@homelab-postgres:5432/gitea` |
| Outline | `postgresql://outline:<OUTLINE_DB_PASSWORD>@homelab-postgres:5432/outline` |
| Authentik | `postgresql://authentik:<AUTHENTIK_DB_PASSWORD>@homelab-postgres:5432/authentik` |
| Grafana | `postgresql://grafana:<GRAFANA_DB_PASSWORD>@homelab-postgres:5432/grafana` |

## MariaDB 连接字符串

| 服务 | 连接串 |
|------|--------|
| Nextcloud (MySQL) | `mysql://nextcloud:<NEXTCLOUD_DB_PASSWORD>@homelab-mariadb:3306/nextcloud_mysql` |
| BookStack | `mysql://bookstack:<BOOKSTACK_DB_PASSWORD>@homelab-mariadb:3306/bookstack` |

## 备份

```bash
# 全量备份（PostgreSQL + Redis + MariaDB）
./scripts/backup-databases.sh

# 单独备份
./scripts/backup-databases.sh --postgres
./scripts/backup-databases.sh --redis
./scripts/backup-databases.sh --mariadb
```

备份默认保留 7 天，可通过 `BACKUP_RETENTION_DAYS` 环境变量调整。

## 网络隔离

数据库服务仅加入 `databases` 网络，**不**暴露到 `proxy` 网络，不通过 Traefik 对外暴露。

管理界面例外：
- pgAdmin → `pgadmin.${DOMAIN}`（需要认证）
- Redis Commander → `redis.${DOMAIN}`（需要认证）

## 管理界面

### pgAdmin
- 地址：`https://pgadmin.${DOMAIN}`
- 登录：`${PGADMIN_EMAIL}` / `${PGADMIN_PASSWORD}`
- 首次登录后：Add Server → Host: `homelab-postgres` → Port: `5432`

### Redis Commander
- 地址：`https://redis.${DOMAIN}`
- 登录：`${REDIS_COMMANDER_USER:-admin}` / `${REDIS_COMMANDER_PASSWORD}`
