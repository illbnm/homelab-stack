# Databases Stack — 共享数据库层

统一的数据库服务栈，为所有HomeLab服务提供PostgreSQL、Redis和MariaDB支持。

## 服务概览

| 服务 | 用途 | 端口 | Web UI |
|------|------|------|--------|
| **PostgreSQL 16** | 主数据库 (多租户) | 5432 (内部) | pgAdmin |
| **Redis 7** | 缓存/队列/会话 | 6379 (内部) | Redis Commander |
| **MariaDB 11** | MySQL兼容数据库 | 3306 (内部) | - |
| **pgAdmin 8** | PostgreSQL管理 | 80 (Traefik) | https://pgadmin.${DOMAIN} |
| **Redis Commander** | Redis管理 | 8081 (Traefik) | https://redis.${DOMAIN} |

## 快速开始

```bash
# 1. 配置环境变量
./scripts/setup-env.sh

# 2. 启动数据库栈
./scripts/stack-manager.sh start databases

# 3. 验证服务
docker ps | grep homelab
docker exec homelab-postgres psql -U postgres -c '\l'
```

## 数据库分配

### PostgreSQL 数据库

| 数据库 | 用户 | 用途 |
|--------|------|------|
| nextcloud | nextcloud | Nextcloud存储 |
| gitea | gitea | Gitea代码仓库 |
| outline | outline | Outline知识库 |
| authentik | authentik | Authentik SSO |
| grafana | grafana | Grafana仪表板 |
| vaultwarden | vaultwarden | Vaultwarden密码管理 |
| bookstack | bookstack | BookStack文档 |

### Redis 数据库

| DB编号 | 用途 | 连接参数 |
|--------|------|----------|
| 0 | Authentik | `redis://:password@redis:6379/0` |
| 1 | Outline | `redis://:password@redis:6379/1` |
| 2 | Gitea | `redis://:password@redis:6379/2` |
| 3 | Nextcloud | `redis://:password@redis:6379/3` |
| 4 | Grafana sessions | `redis://:password@redis:6379/4` |

### MariaDB 数据库

| 数据库 | 用户 | 用途 |
|--------|------|------|
| nextcloud_mysql | nextcloud | Nextcloud (MySQL模式) |
| bookstack | bookstack | BookStack文档 |

## 服务连接示例

### PostgreSQL

```yaml
# 在其他服务的 docker-compose.yml 中
services:
  myapp:
    environment:
      DATABASE_URL: postgres://nextcloud:password@postgres:5432/nextcloud
    networks:
      - databases

networks:
  databases:
    external: true
```

**连接字符串格式:**
```
postgres://用户名:密码@postgres:5432/数据库名
```

### Redis

```yaml
# 在其他服务的 docker-compose.yml 中
services:
  myapp:
    environment:
      REDIS_URL: redis://:password@redis:6379/0
    networks:
      - databases
```

**连接字符串格式:**
```
redis://:密码@redis:6379/数据库编号
```

### MariaDB

```yaml
# 在其他服务的 docker-compose.yml 中
services:
  myapp:
    environment:
      MYSQL_HOST: mariadb
      MYSQL_DATABASE: bookstack
      MYSQL_USER: bookstack
      MYSQL_PASSWORD: password
    networks:
      - databases
```

## 管理界面

### pgAdmin

1. 访问 `https://pgadmin.${DOMAIN}`
2. 登录: `${PGADMIN_EMAIL}` / `${PGADMIN_PASSWORD}`
3. 添加服务器:
   - 主机: `postgres`
   - 端口: `5432`
   - 用户: `postgres`
   - 密码: `${POSTGRES_ROOT_PASSWORD}`

### Redis Commander

1. 访问 `https://redis.${DOMAIN}`
2. 登录: `admin` / `${REDIS_COMMANDER_PASSWORD}`
3. 自动连接到Redis实例

## 备份与恢复

### 自动备份

```bash
# 手动备份
./scripts/backup-databases.sh

# 设置定时备份 (每天凌晨2点)
echo "0 2 * * * /opt/homelab/scripts/backup-databases.sh" | crontab -
```

### 恢复

```bash
# PostgreSQL 恢复
gunzip -c backup.sql.gz | docker exec -i homelab-postgres psql -U postgres

# Redis 恢复
gunzip -c backup_redis.rdb.gz > dump.rdb
docker cp dump.rdb homelab-redis:/data/dump.rdb
docker restart homelab-redis

# MariaDB 恢复
gunzip -c backup_mariadb.sql.gz | docker exec -i homelab-mariadb mariadb -u root -p
```

## 健康检查

所有数据库服务都配置了健康检查，其他服务可以通过以下方式等待数据库就绪：

```yaml
services:
  myapp:
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
```

## 环境变量

| 变量 | 说明 | 必需 |
|------|------|------|
| `POSTGRES_ROOT_PASSWORD` | PostgreSQL root密码 | ✅ |
| `REDIS_PASSWORD` | Redis密码 | ✅ |
| `MARIADB_ROOT_PASSWORD` | MariaDB root密码 | ✅ |
| `PGADMIN_EMAIL` | pgAdmin登录邮箱 | ✅ |
| `PGADMIN_PASSWORD` | pgAdmin密码 | ✅ |
| `NEXTCLOUD_DB_PASSWORD` | Nextcloud数据库密码 | |
| `GITEA_DB_PASSWORD` | Gitea数据库密码 | |
| `OUTLINE_DB_PASSWORD` | Outline数据库密码 | |
| `AUTHENTIK_DB_PASSWORD` | Authentik数据库密码 | |
| `GRAFANA_DB_PASSWORD` | Grafana数据库密码 | |

## 安全配置

1. **网络隔离**: 数据库服务仅暴露在内部网络，不通过Traefik对外暴露
2. **密码保护**: 所有服务都需要强密码
3. **持久化**: 数据存储在Docker volumes中，重启不丢失

## 故障排除

### PostgreSQL 连接失败

```bash
# 检查容器状态
docker logs homelab-postgres --tail 50

# 测试连接
docker exec -it homelab-postgres psql -U postgres -c 'SELECT 1'
```

### Redis 认证失败

```bash
# 检查密码
docker exec -it homelab-redis redis-cli -a "${REDIS_PASSWORD}" ping
```

### pgAdmin 无法连接

```bash
# 确认网络连接
docker exec homelab-pgadmin ping postgres

# 检查pgAdmin日志
docker logs homelab-pgadmin --tail 50
```

## 参考资料

- [PostgreSQL Documentation](https://www.postgresql.org/docs/16/)
- [Redis Documentation](https://redis.io/docs/)
- [MariaDB Documentation](https://mariadb.com/kb/)
- [pgAdmin Documentation](https://www.pgadmin.org/docs/pgadmin4/latest/)