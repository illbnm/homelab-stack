# 🗄️ Databases Stack — 共享多租户数据库层

本 Stack 提供高可用、轻量级、多租户共享数据库服务，避免各个上层微服务（Nextcloud、Outline、Gitea、Authentik、Grafana）独立运行数据库实例造成的内存与 CPU 浪费。

---

## 📦 服务清单

| 服务 | 镜像版本 | 内部连接地址 | 管理访问入口 (Traefik) | 说明 |
| :--- | :--- | :--- | :--- | :--- |
| **PostgreSQL** | `postgres:16.4-alpine` | `postgres:5432` | 仅内部网络访问 | 主关系型数据库 (多租户隔离) |
| **Redis** | `redis:7.4.0-alpine` | `redis:6379` | 仅内部网络访问 | 高速缓存与异步队列 |
| **MariaDB** | `mariadb:11.5.2` | `mariadb:3306` | 仅内部网络访问 | MySQL 兼容关系型数据库 |
| **pgAdmin** | `dpage/pgadmin4:8.11` | `pgadmin:80` | `https://pgadmin.${DOMAIN}` | PostgreSQL Web 可视化管理面板 |
| **Redis Commander** | `rediscommander/redis-commander:v0.8.0` | `redis-commander:8081` | `https://redis.${DOMAIN}` | Redis 键值管理与监控面板 |

---

## 🔒 网络隔离与安全设计

- 数据库引擎（PostgreSQL、Redis、MariaDB）仅加入内部专属网络 `internal` (`homelab-internal`)，**不对公网暴露任何物理端口**。
- 管理后台（pgAdmin 和 Redis Commander）挂载 Traefik 反向代理，通过 HTTPS 与身份认证保护。

---

## 🗂️ 多租户数据库分配规划

### PostgreSQL 独立租户分配
容器首次启动时由 `scripts/init-databases.sh` 自动以幂等方式创建独立库与独立用户：

| 微服务 | 数据库名 | 用户名 | 环境变量口令 |
| :--- | :--- | :--- | :--- |
| **Authentik** | `authentik` | `authentik` | `${AUTHENTIK_DB_PASSWORD}` |
| **Outline** | `outline` | `outline` | `${OUTLINE_DB_PASSWORD}` |
| **Gitea** | `gitea` | `gitea` | `${GITEA_DB_PASSWORD}` |
| **Nextcloud** | `nextcloud` | `nextcloud` | `${NEXTCLOUD_DB_PASSWORD}` |
| **Grafana** | `grafana` | `grafana` | `${GRAFANA_DB_PASSWORD}` |

### Redis 数据库索引隔离 (`?db=N`)
各个微服务连接共享 Redis 时通过参数隔离：
- **DB 0**: Authentik SSO 会话与缓存
- **DB 1**: Outline 协作文档缓存
- **DB 2**: Gitea 任务队列与会话
- **DB 3**: Nextcloud 文件锁与分布式缓存
- **DB 4**: Grafana Dashboard 会话

---

## 🚀 启动与部署

```bash
# 1. 确保已在根目录 .env 中配置密码
# 2. 启动数据库层
cd stacks/databases
docker compose up -d

# 3. 查看健康状态
docker compose ps
```

---

## 💾 自动化备份与 7 天轮换

运行提供的备份脚本：
```bash
chmod +x scripts/backup-databases.sh
./scripts/backup-databases.sh
```

备份生成在 `backups/databases/homelab_db_backup_YYYYMMDD_HHMMSS.tar.gz`，并由脚本自动清理保留期超过 7 天的历史归档。
