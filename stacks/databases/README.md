# Database Stack - PostgreSQL + Redis + MariaDB

共享数据库层，为 HomeLab 所有服务提供统一的数据存储。

## 📦 服务列表

| 服务 | 版本 | 用途 | 访问 |
|------|------|------|------|
| **PostgreSQL** | 16.4-alpine | 主数据库（多租户） | 内部网络 |
| **Redis** | 7.4.0-alpine | 缓存/队列 | 内部网络 |
| **MariaDB** | 11.5.2 | MySQL 兼容 | 内部网络 |
| **pgAdmin** | 8.11 | PostgreSQL 管理界面 | https://pgadmin.yourdomain.com |
| **Redis Commander** | latest | Redis 管理界面 | https://redis.yourdomain.com |

## 🚀 快速开始

### 1. 配置环境变量

```bash
cp .env.example .env
# 编辑 .env 文件，设置所有密码
nano .env
```

### 2. 启动服务

```bash
docker-compose up -d
```

### 3. 验证健康状态

```bash
docker-compose ps
docker-compose logs postgres
```

## 🔗 连接字符串示例

### PostgreSQL

各服务使用以下连接字符串：

| 服务 | 连接字符串 |
|------|-----------|
| **Nextcloud** | `postgres://nextcloud:PASSWORD@postgres:5432/nextcloud` |
| **Gitea** | `postgres://gitea:PASSWORD@postgres:5432/gitea` |
| **Outline** | `postgres://outline:PASSWORD@postgres:5432/outline` |
| **Vaultwarden** | `postgres://vaultwarden:PASSWORD@postgres:5432/vaultwarden` |
| **BookStack** | `postgres://bookstack:PASSWORD@postgres:5432/bookstack` |
| **Authentik** | `postgres://authentik:PASSWORD@postgres:5432/authentik` |
| **Grafana** | `postgres://grafana:PASSWORD@postgres:5432/grafana` |

### Redis

Redis 使用数据库编号隔离各服务：

| 服务 | 数据库编号 | 连接字符串 |
|------|-----------|-----------|
| **Authentik** | DB 0 | `redis://:PASSWORD@redis:6379/0` |
| **Outline** | DB 1 | `redis://:PASSWORD@redis:6379/1` |
| **Gitea** | DB 2 | `redis://:PASSWORD@redis:6379/2` |
| **Nextcloud** | DB 3 | `redis://:PASSWORD@redis:6379/3` |
| **Grafana** | DB 4 | `redis://:PASSWORD@redis:6379/4` |

### MariaDB

MariaDB 可用于需要 MySQL 兼容性的服务（如 Nextcloud）：

```bash
# 连接字符串示例
mysql://root:PASSWORD@mariadb:3306/nextcloud
```

## 🔐 安全配置

### 网络隔离

- ✅ 数据库容器**不**暴露到宿主机端口
- ✅ 仅通过 `databases` 内部网络访问
- ✅ 管理界面通过 Traefik 反向代理（带身份验证）

### 密码要求

- PostgreSQL root 密码：至少 32 位随机字符
- Redis 密码：至少 32 位随机字符
- MariaDB root 密码：至少 32 位随机字符
- 各服务数据库密码：至少 16 位随机字符

**生成随机密码**：

```bash
# 生成 32 位随机密码
openssl rand -base64 32

# 生成 htpasswd 哈希（用于管理界面认证）
htpasswd -nB admin | sed -e 's/\$/\$\$/g'
```

## 💾 备份

### 手动备份

```bash
cd /home/zhaog/.openclaw/workspace/homelab-stack/scripts
./backup-databases.sh
```

### 自动备份（Cron）

```bash
# 每天凌晨 2:00 自动备份
0 2 * * * /home/zhaog/.openclaw/workspace/homelab-stack/scripts/backup-databases.sh >> /var/log/db-backup.log 2>&1
```

### 恢复备份

```bash
# 解压备份文件
tar -xzf db_backup_20260408_020000.tar.gz

# 恢复 PostgreSQL
cat postgres_dump.sql | docker exec -i homelab-postgres psql -U postgres

# 恢复 Redis
docker cp redis_dump.rdb homelab-redis:/data/dump.rdb
docker restart homelab-redis

# 恢复 MariaDB
cat mariadb_dump.sql | docker exec -i homelab-mariadb mysql -u root -p"${MARIADB_ROOT_PASSWORD}"
```

## 🛠️ 管理界面

### pgAdmin

1. 访问：https://pgadmin.yourdomain.com
2. 登录：使用 `PGADMIN_EMAIL` 和 `PGADMIN_PASSWORD`
3. 添加服务器：
   - Host: `postgres`
   - Port: `5432`
   - Username: `postgres`
   - Password: `POSTGRES_ROOT_PASSWORD`

### Redis Commander

1. 访问：https://redis.yourdomain.com
2. 自动连接到 Redis（无需额外配置）
3. 可视化管理所有 16 个数据库

## 📊 性能调优

### PostgreSQL

已自动配置以下优化：
- ✅ 共享缓冲区：自动（Docker 默认）
- ✅ 工作内存：自动（Docker 默认）
- ✅ 维护工作内存：自动（Docker 默认）

### Redis

已配置以下优化：
- ✅ 最大内存：512MB
- ✅ 淘汰策略：allkeys-lru
- ✅ 持久化：AOF（appendonly）
- ✅ 数据库数量：16 个

### MariaDB

已配置以下优化：
- ✅ 自动升级：启用
- ✅ InnoDB 缓冲池：自动（Docker 默认）

## 🔍 故障排查

### 数据库连接失败

```bash
# 检查容器状态
docker-compose ps

# 检查日志
docker-compose logs postgres
docker-compose logs redis
docker-compose logs mariadb

# 测试 PostgreSQL 连接
docker exec -it homelab-postgres psql -U postgres -c "SELECT version();"

# 测试 Redis 连接
docker exec -it homelab-redis redis-cli -a "${REDIS_PASSWORD}" ping
```

### 初始化脚本失败

```bash
# 查看初始化日志
docker-compose logs postgres | grep "init-postgres"

# 手动运行初始化脚本（仅测试）
docker exec -it homelab-postgres bash
cd /docker-entrypoint-initdb.d
./01-init-databases.sh
```

### 备份失败

```bash
# 检查备份目录权限
ls -la /mnt/backups/databases

# 检查磁盘空间
df -h /mnt/backups

# 手动测试备份
BACKUP_DIR=/tmp/test-backup ./scripts/backup-databases.sh
```

## 📚 相关文档

- [PostgreSQL 官方文档](https://www.postgresql.org/docs/16/index.html)
- [Redis 官方文档](https://redis.io/docs/latest/)
- [MariaDB 官方文档](https://mariadb.com/kb/)
- [pgAdmin 文档](https://www.pgadmin.org/docs/pgadmin4/latest/index.html)
- [Redis Commander 文档](https://github.com/joeferner/redis-commander)

## 📝 维护

### 更新镜像

```bash
# 拉取最新镜像
docker-compose pull

# 重启服务
docker-compose up -d
```

### 清理旧数据

```bash
# ⚠️ 警告：这将删除所有数据！
docker-compose down -v
docker volume rm homelab_postgres-data homelab_redis-data homelab_mariadb-data
```

### 监控

建议使用 Prometheus + Grafana 监控数据库性能（见 `monitoring` 栈）。

---

_最后更新: 2026-04-08_
