# 数据库服务栈

共享数据库层，为所有 HomeLab 服务提供 PostgreSQL、Redis、MariaDB 实例。

**Issue**: #11
**赏金**: $130 USDT

---

## 📋 服务清单

| 服务 | 镜像 | 端口 | 用途 |
|------|------|------|------|
| **PostgreSQL** | `postgres:16-alpine` | 5432 | 主数据库（多租户） |
| **Redis** | `redis:7-alpine` | 6379 | 缓存/队列 |
| **MariaDB** | `mariadb:11.4` | 3306 | MySQL 兼容数据库 |
| **pgAdmin** | `dpage/pgadmin4:8.11` | 80 | PostgreSQL 管理界面 |
| **Redis Commander** | `rediscommander/redis-commander:latest` | 8081 | Redis 管理界面 |

---

## 🚀 快速启动

### 1. 配置环境变量

```bash
cp .env.example .env
vim .env

# 必须修改的变量：
# - POSTGRES_ROOT_PASSWORD
# - REDIS_PASSWORD
# - MARIADB_ROOT_PASSWORD
# - PGADMIN_PASSWORD
# - 各服务的数据库密码
```

### 2. 启动服务

```bash
cd stacks/databases
docker compose up -d
```

### 3. 验证服务

```bash
# PostgreSQL
docker exec homelab-postgres psql -U postgres -c "SELECT version();"

# Redis
docker exec homelab-redis redis-cli -a ${REDIS_PASSWORD} ping

# MariaDB
docker exec homelab-mariadb mysql -u root -p${MARIADB_ROOT_PASSWORD} -e "SELECT version();"
```

---

## 🔧 多租户 PostgreSQL

### 数据库分配

| 数据库 | 用途 | 用户 |
|--------|------|------|
| `nextcloud` | Nextcloud | nextcloud |
| `gitea` | Gitea | gitea |
| `outline` | Outline | outline |
| `vaultwarden` | Vaultwarden | vaultwarden |
| `bookstack` | BookStack | bookstack |
| `grafana` | Grafana | grafana |
| `authentik` | Authentik | authentik |

### 初始化脚本

首次启动时，`initdb/01-init-databases.sh` 会自动创建所有数据库和用户。

**幂等性保证**: 脚本可以重复执行，不会重置已有数据。

---

## 📊 Redis 多数据库分配

Redis 使用 `?db=N` 参数隔离不同服务：

```
DB 0 — Authentik
DB 1 — Outline
DB 2 — Gitea
DB 3 — Nextcloud
DB 4 — Grafana sessions
DB 5 — Cache
DB 6 — Queue
```

### 服务连接示例

```yaml
# Authentik
redis://:${REDIS_PASSWORD}@redis:6379/0

# Outline
redis://:${REDIS_PASSWORD}@redis:6379/1

# Gitea
redis://:${REDIS_PASSWORD}@redis:6379/2
```

---

## 🔒 安全配置

### 网络隔离

- ✅ 数据库服务**不加入** `proxy` 网络
- ✅ 仅通过 `databases` 内部网络访问
- ✅ 管理界面（pgAdmin、Redis Commander）通过 Traefik 对外暴露

### 健康检查

所有数据库容器配置了严格的健康检查：

```yaml
healthcheck:
  test: ["CMD-SHELL", "pg_isready -U postgres"]
  interval: 10s
  timeout: 5s
  retries: 5
  start_period: 30s
```

其他 Stack 通过 `depends_on: condition: service_healthy` 等待数据库就绪。

---

## 💾 备份策略

### 自动备份

```bash
# 手动备份
./scripts/backup-databases.sh

# Cron 定时任务（每天凌晨 2:00）
0 2 * * * /opt/homelab/stacks/databases/scripts/backup-databases.sh
```

### 备份内容

- **PostgreSQL**: `pg_dumpall` 备份所有数据库
- **Redis**: `BGSAVE` 触发持久化
- **MariaDB**: `mysqldump` 备份所有数据库

### 备份文件

- 压缩格式: `.tar.gz`
- 保留策略: 最近 7 天
- 存储位置: `${BACKUP_DIR}/databases_YYYYMMDD_HHMMSS.tar.gz`
- 可选: 上传到 MinIO

---

## 🌐 管理界面

### pgAdmin

- **URL**: `https://pgadmin.${DOMAIN}`
- **登录**: `${PGADMIN_EMAIL}` / `${PGADMIN_PASSWORD}`

#### 添加服务器

1. 右键 "Servers" → "Register" → "Server"
2. **General**: Name = "HomeLab"
3. **Connection**:
   - Host: `postgres`
   - Port: `5432`
   - Username: `postgres`
   - Password: `${POSTGRES_ROOT_PASSWORD}`

### Redis Commander

- **URL**: `https://redis.${DOMAIN}`
- 自动连接到 Redis 服务器

---

## 🔗 服务集成

### Nextcloud

```yaml
# stacks/productivity/docker-compose.yml
services:
  nextcloud:
    environment:
      POSTGRES_DB: nextcloud
      POSTGRES_USER: nextcloud
      POSTGRES_PASSWORD: ${NEXTCLOUD_DB_PASSWORD}
      POSTGRES_HOST: postgres
      REDIS_HOST: redis
      REDIS_HOST_PORT: 6379
      REDIS_HOST_PASSWORD: ${REDIS_PASSWORD}
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    networks:
      - databases
```

### Gitea

```yaml
# stacks/productivity/docker-compose.yml
services:
  gitea:
    environment:
      GITEA__database__DB_TYPE: postgres
      GITEA__database__HOST: postgres:5432
      GITEA__database__NAME: gitea
      GITEA__database__USER: gitea
      GITEA__database__PASSWD: ${GITEA_DB_PASSWORD}
    depends_on:
      postgres:
        condition: service_healthy
    networks:
      - databases
```

### Outline

```yaml
# stacks/productivity/docker-compose.yml
services:
  outline:
    environment:
      DATABASE_URL: postgres://outline:${OUTLINE_DB_PASSWORD}@postgres:5432/outline
      REDIS_URL: redis://:${REDIS_PASSWORD}@redis:6379/1
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    networks:
      - databases
```

---

## 📝 验收标准

- [x] PostgreSQL Web UI 可访问（pgAdmin）
- [x] Redis Web UI 可访问（Redis Commander）
- [x] `scripts/init-databases.sh` 创建所有必需的数据库
- [x] `scripts/backup-databases.sh` 生成 `.tar.gz` 备份文件
- [x] 所有服务通过 `depends_on: condition: service_healthy` 等待数据库就绪
- [x] 数据库服务**不加入** `proxy` 网络
- [x] README 包含所有服务的连接示例
- [x] 环境变量文档完整（`.env.example`）

---

## 🛠️ 故障排查

### PostgreSQL 连接失败

```bash
# 检查日志
docker logs homelab-postgres

# 检查健康状态
docker inspect homelab-postgres | jq '.[0].State.Health'

# 手动连接
docker exec -it homelab-postgres psql -U postgres
```

### Redis 连接失败

```bash
# 检查日志
docker logs homelab-redis

# 测试连接
docker exec homelab-redis redis-cli -a ${REDIS_PASSWORD} ping
```

### MariaDB 连接失败

```bash
# 检查日志
docker logs homelab-mariadb

# 手动连接
docker exec -it homelab-mariadb mysql -u root -p${MARIADB_ROOT_PASSWORD}
```

---

## 📚 相关文档

- [PostgreSQL 官方文档](https://www.postgresql.org/docs/16/index.html)
- [Redis 官方文档](https://redis.io/docs/latest/)
- [MariaDB 官方文档](https://mariadb.com/kb/en/)
- [pgAdmin 文档](https://www.pgadmin.org/docs/pgadmin4/8.11/index.html)

---

**维护者**: HomeLab Stack Team
**最后更新**: 2026-04-07
