# ============================================================
#  Homelab Stack — Database Layer
#  PostgreSQL + Redis + MariaDB 共享实例部署说明
#  赏金任务: https://github.com/illbnm/homelab-stack
# ============================================================

## 概述

为 Homelab Stack 提供一个可一键部署的数据库层，包含三个数据库服务：

| 服务 | 用途 | 默认端口 |
|------|------|---------|
| **PostgreSQL 16** | 关系型数据库主存储 | 5432 |
| **Redis 7** | 缓存 / 消息队列 / 会话存储 | 6379 |
| **MariaDB 11** | MySQL兼容层 | 3306 |

## 快速开始

### 前置条件

- Docker 24+
- Docker Compose v2.20+

### 1. 克隆仓库

```bash
git clone https://github.com/illbnm/homelab-stack.git
cd homelab-stack/database
```

### 2. 配置环境变量

```bash
cp .env.example .env
# 编辑 .env，填入安全密码
vim .env
```

所有密码**必须修改**，不能使用默认值。

### 3. 启动服务

```bash
docker compose up -d
```

### 4. 验证部署

```bash
chmod +x healthcheck.sh
./healthcheck.sh
```

正常输出：
```
==========================================
  Homelab DB Layer — Health Check
  2026-06-29 18:30:00
==========================================
PostgreSQL ... ✅ OK
Redis ........ ✅ OK
MariaDB ...... ✅ OK
==========================================
✅ 所有数据库服务运行正常
```

### 5. 连接测试

**PostgreSQL:**
```bash
docker exec -it homelab-postgres psql -U homelab -d homelab -c "SELECT version();"
```

**Redis:**
```bash
docker exec -it homelab-redis redis-cli -a "$REDIS_PASSWORD" ping
```

**MariaDB:**
```bash
docker exec -it homelab-mariadb mysql -u homelab -p"$MARIADB_PASSWORD" -e "SHOW DATABASES;"
```

## 自定义配置

所有配置通过环境变量管理，完整变量列表见 `.env.example`：

| 变量 | 说明 | 默认值 |
|------|------|--------|
| `PG_PORT` | PostgreSQL 端口 | 5432 |
| `PG_MEM_LIMIT` | PostgreSQL 内存上限 | 512m |
| `REDIS_PORT` | Redis 端口 | 6379 |
| `REDIS_MAX_MEMORY` | Redis 最大内存 | 256mb |
| `MARIADB_PORT` | MariaDB 端口 | 3306 |
| `MARIADB_MEM_LIMIT` | MariaDB 内存上限 | 512m |

## 初始化脚本

- `init/postgres/` — PostgreSQL 启动时执行的 SQL 脚本
- `init/mariadb/` — MariaDB 启动时执行的 SQL 脚本
- `conf/redis/` — Redis 自定义配置
- `conf/mariadb/` — MariaDB 自定义配置

## 持久化

所有数据存储在 Docker volumes 中：
- `homelab-pgdata` — PostgreSQL 数据
- `homelab-redisdata` — Redis 数据 (AOF持久化)
- `homelab-mariadbdata` — MariaDB 数据

## 管理工具

启动管理工具 Adminer（仅供开发环境）：
```bash
docker compose --profile admin up -d adminer
```
访问 http://localhost:8080

## 数据备份

```bash
# 导出 PostgreSQL
docker exec homelab-postgres pg_dump -U homelab homelab > backup_pg_$(date +%Y%m%d).sql

# 导出 MariaDB
docker exec homelab-mariadb mysqldump -u homelab -p"$MARIADB_PASSWORD" homelab > backup_mariadb_$(date +%Y%m%d).sql

# 备份 Redis RDB
docker cp homelab-redis:/data/dump.rdb ./redis_backup_$(date +%Y%m%d).rdb
```

## 安全注意事项

1. **必须修改所有默认密码**
2. 生产环境请不要暴露端口到公网
3. 建议使用 Docker 内部网络而非 host 模式
4. 定期更新镜像版本

## 目录结构

```
database/
├── docker-compose.yml    # 核心编排文件
├── .env.example          # 环境变量模板
├── healthcheck.sh        # 健康检查脚本
├── README.md             # 本文件
├── init/
│   ├── postgres/         # PostgreSQL 初始化脚本
│   └── mariadb/          # MariaDB 初始化脚本
└── conf/
    ├── redis/            # Redis 自定义配置
    └── mariadb/          # MariaDB 自定义配置
```
