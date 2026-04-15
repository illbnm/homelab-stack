# Database Stack

统一数据库服务层，提供 PostgreSQL、Redis 和 MariaDB，以及管理界面。

## 服务列表

| 服务 | 端口 | 内部主机名 | 说明 |
|------|------|-----------|------|
| PostgreSQL | 5432 | postgres | 主数据库 (7个服务库) |
| Redis | 6379 | redis | 缓存/会话 (16个DB) |
| MariaDB | 3306 | mariadb | MySQL兼容数据库 |
| pgAdmin | 80 | pgadmin.homelab.local | PostgreSQL管理界面 |
| Redis Commander | 8081 | redis.homelab.local | Redis管理界面 |

## 数据库分配

### PostgreSQL (7个服务库)
- `nextcloud` - Nextcloud 文件存储
- `gitea` - Gitea Git托管
- `outline` - Outline 知识库
- `vaultwarden` - Vaultwarden 密码管理
- `bookstack` - BookStack 文档
- `authentik` - Authentik SSO
- `grafana` - Grafana 监控面板

### Redis (16个DB)
| DB | 服务 |
|----|------|
| 0 | Authentik |
| 1 | Outline |
| 2 | Gitea |
| 3 | Nextcloud |
| 4 | Grafana |
| 5-15 | 预留 |

## 连接字符串

### PostgreSQL
```
# 格式
postgresql://<user>:<password>@postgres:5432/<database>

# 示例
postgresql://nextcloud:${NEXTCLOUD_DB_PASSWORD}@postgres:5432/nextcloud
postgresql://gitea:${GITEA_DB_PASSWORD}@postgres:5432/gitea
postgresql://outline:${OUTLINE_DB_PASSWORD}@postgres:5432/outline
postgresql://vaultwarden:${VAULTWARDEN_DB_PASSWORD}@postgres:5432/vaultwarden
postgresql://bookstack:${BOOKSTACK_DB_PASSWORD}@postgres:5432/bookstack
postgresql://authentik:${AUTHENTIK_DB_PASSWORD}@postgres:5432/authentik
postgresql://grafana:${GRAFANA_DB_PASSWORD}@postgres:5432/grafana
```

### Redis
```
# 格式
redis://:<password>@redis:6379/<db_number>

# 示例
redis://:${REDIS_PASSWORD}@redis:6379/0  # Authentik
redis://:${REDIS_PASSWORD}@redis:6379/1  # Outline
redis://:${REDIS_PASSWORD}@redis:6379/2  # Gitea
redis://:${REDIS_PASSWORD}@redis:6379/3  # Nextcloud
redis://:${REDIS_PASSWORD}@redis:6379/4  # Grafana
```

### MariaDB
```
# 格式
mysql://<user>:<password>@mariadb:3306/<database>

# 示例
mysql://bookstack:${BOOKSTACK_DB_PASSWORD}@mariadb:3306/bookstack
mysql://nextcloud:${NEXTCLOUD_DB_PASSWORD}@mariadb:3306/nextcloud_mysql
```

## 备份

```bash
# 完整备份
./scripts/backup-databases.sh --all

# 仅 PostgreSQL
./scripts/backup-databases.sh --postgres

# 备份并上传到 MinIO
./scripts/backup-databases.sh --all --minio
```

备份文件保存在 `backups/databases/` 目录。

## 安全配置

- ✅ 数据库容器不暴露宿主机端口（仅内部网络）
- ✅ 强密码要求（32位随机字符）
- ✅ pgAdmin/Redis Commander 需通过 Authelia 认证
- ✅ 资源限制防止内存溢出
- ✅ 日志限制防止磁盘占满

## 故障排查

### 数据库连接失败
```bash
# 检查容器状态
docker ps | grep homelab-

# 检查 PostgreSQL 日志
docker logs homelab-postgres

# 测试连接
docker exec -it homelab-postgres psql -U postgres -c "\\l"
```

### 初始化脚本未执行
```bash
# 检查 init 脚本
docker exec homelab-postgres ls /docker-entrypoint-initdb.d/

# 手动执行
docker exec -it homelab-postgres bash /docker-entrypoint-initdb.d/01-init-databases.sh
```

## 性能调优

### PostgreSQL
- 默认连接池: 100 (适合中小规模)
- 建议: 按需调整 `max_connections` 和 `shared_buffers`

### Redis
- 最大内存: 512MB
- 淘汰策略: allkeys-lru
- 持久化: AOF 已启用

### MariaDB
- 默认配置适合中小规模
- 建议: 按需调整 `innodb_buffer_pool_size`
