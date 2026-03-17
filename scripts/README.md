# Database Layer — PostgreSQL + Redis + MariaDB 共享实例

## 服务清单

| 服务 | 镜像 | 用途 |
|------|------|------|
| PostgreSQL | `postgres:16.4-alpine` | 主数据库 (多租户) |
| Redis | `redis:7.4.0-alpine` | 缓存/队列 |
| MariaDB | `mariadb:11.5.2` | MySQL 兼容 (Nextcloud 可选) |
| pgAdmin | `dpage/pgadmin4:8.11` | PostgreSQL 管理界面 |
| Redis Commander | `rediscommander/redis-commander:latest-sha` | Redis 管理界面 |

## 连接字符串示例

### PostgreSQL
