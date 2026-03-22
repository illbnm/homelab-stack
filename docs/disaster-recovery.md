# 灾难恢复指南 — HomeLab Stack

> 完整恢复流程：从全新主机到全部服务上线。

---

## 恢复前提

### 所需条件

- 全新 Ubuntu 22.04+ 主机（或重装后的原主机）
- 备份文件已同步到本地（从 S3/B2/SFTP 下载）
- 域名 DNS 可修改
- `root` 或 `sudo` 权限

### 备份文件清单

```
backups/<backup_id>/
├── manifest.json                 # 备份元数据
├── configs.tar.gz                # 配置文件
├── databases/
│   ├── postgresql_all.sql        # PostgreSQL 全量
│   ├── mysql_all.sql             # MariaDB/MySQL 全量
│   └── redis_dump.rdb            # Redis 快照
└── volumes/
    ├── vol_homelab_traefik.tar.gz
    ├── vol_homelab_grafana.tar.gz
    └── ...
```

---

## 恢复流程

### Phase 0: 系统准备 (预计 15 分钟)

```bash
# 1. 安装 Docker
curl -fsSL https://get.docker.com | sh
systemctl enable docker

# 2. 安装依赖
apt update && apt install -y git curl rsync awscli

# 3. 克隆仓库
git clone https://github.com/illbnm/homelab-stack.git /opt/homelab
cd /opt/homelab

# 4. 从远程下载备份（选择对应方式）
# S3:
aws s3 sync s3://homelab-backups/<backup_id> ./backups/<backup_id>
# B2:
b2 sync b2://homelab-backups/<backup_id> ./backups/<backup_id>
# SFTP:
rsync -avz user@host:/backups/<backup_id> ./backups/
```

### Phase 1: 基础设施 (预计 10 分钟)

恢复顺序：**Traefik → Portainer → Watchtower**

```bash
# 1. 恢复配置文件
tar xzf backups/<backup_id>/configs.tar.gz -C /opt/homelab

# 2. 编辑 .env（IP/域名可能变了）
vim config/.env

# 3. 启动基础服务
./install.sh

# 4. 验证
docker ps | grep -E 'traefik|portainer|watchtower'
curl -s http://localhost:8080/api/version  # Traefik
```

**检查点：** Traefik dashboard 可访问，HTTPS 证书自动续签

### Phase 2: 数据库层 (预计 10 分钟)

恢复顺序：**PostgreSQL → Redis → MariaDB**

```bash
# 1. 启动数据库 stack
./scripts/stack-manager.sh start databases

# 2. 等待容器就绪
sleep 10

# 3. 恢复 PostgreSQL
PG_CONTAINER=$(docker ps --format '{{.Names}}' | grep postgres | head -1)
docker exec -i $PG_CONTAINER psql -U postgres < backups/<backup_id>/databases/postgresql_all.sql

# 4. 恢复 MariaDB
MYSQL_CONTAINER=$(docker ps --format '{{.Names}}' | grep -E 'mariadb|mysql' | head -1)
docker exec -i $MYSQL_CONTAINER mysql -u root -p"$MARIADB_ROOT_PASSWORD" < backups/<backup_id>/databases/mysql_all.sql

# 5. 恢复 Redis（如果有）
REDIS_CONTAINER=$(docker ps --format '{{.Names}}' | grep redis | head -1)
if [[ -n "$REDIS_CONTAINER" ]]; then
  docker cp backups/<backup_id>/databases/redis_dump.rdb $REDIS_CONTAINER:/data/dump.rdb
  docker restart $REDIS_CONTAINER
fi

# 6. 验证
docker exec $PG_CONTAINER psql -U postgres -c "\l"
docker exec $MYSQL_CONTAINER mysql -u root -p"$MARIADB_ROOT_PASSWORD" -e "SHOW DATABASES;"
```

**检查点：** 所有数据库恢复，表数据完整

### Phase 3: SSO 认证 (预计 15 分钟)

恢复顺序：**Authentik**

```bash
# 1. 启动 SSO stack
./scripts/stack-manager.sh start sso

# 2. 等待 Authentik 初始化（首次启动需要 2-3 分钟）
sleep 120

# 3. 数据已在 Phase 2 从 PostgreSQL 恢复
# 4. 验证
curl -s https://auth.${DOMAIN}/if/flow/default-authentication-flow/ | head -5
```

**检查点：** Authentik 管理界面可登录，用户数据完整

### Phase 4: 核心服务 (预计 30 分钟)

按以下顺序启动各 stack：

```bash
# 监控（Prometheus + Grafana + Loki）
./scripts/stack-manager.sh start monitoring

# 网络（AdGuard + WireGuard + NPM）
./scripts/stack-manager.sh start network

# 存储（Nextcloud + MinIO）
./scripts/stack-manager.sh start storage

# 恢复存储卷
for archive in backups/<backup_id>/volumes/vol_*nextcloud*.tar.gz; do
  vol_name=$(basename "$archive" .tar.gz | sed 's/^vol_//')
  docker volume create "$vol_name"
  docker run --rm -v "${vol_name}:/data" -v "$(dirname $archive):/backup:ro" \
    alpine:3.19 tar xzf "/backup/$(basename $archive)" -C /data
done

# 生产力工具
./scripts/stack-manager.sh start productivity

# 媒体服务
./scripts/stack-manager.sh start media

# AI 服务
./scripts/stack-manager.sh start ai

# 家庭自动化
./scripts/stack-manager.sh start home-automation

# 通知
./scripts/stack-manager.sh start notifications

# Dashboard
./scripts/stack-manager.sh start dashboard
```

### Phase 5: 验证 (预计 15 分钟)

```bash
# 运行集成测试（如果已实现）
./scripts/test-stacks.sh --all

# 手动检查每个服务
./scripts/stack-manager.sh status base
./scripts/stack-manager.sh status databases
./scripts/stack-manager.sh status sso
# ... 逐个检查
```

---

## 恢复时间目标 (RTO)

| 阶段 | 服务 | 预计时间 | 累计 |
|------|------|---------|------|
| 0 | 系统准备 | 15 min | 15 min |
| 1 | 基础设施 | 10 min | 25 min |
| 2 | 数据库 | 10 min | 35 min |
| 3 | SSO | 15 min | 50 min |
| 4 | 核心服务 | 30 min | 80 min |
| 5 | 验证 | 15 min | **95 min** |

**总 RTO：约 1.5 小时**（从全新主机到全部上线）

---

## 恢复验证清单

### 基础设施
- [ ] Traefik dashboard 可访问
- [ ] HTTPS 证书有效
- [ ] Portainer 可登录

### 数据库
- [ ] PostgreSQL：`psql -c "\l"` 显示所有数据库
- [ ] MariaDB：`mysql -e "SHOW DATABASES;"` 显示所有数据库
- [ ] Redis：`redis-cli PING` 返回 PONG

### SSO
- [ ] Authentik 管理界面可访问
- [ ] 已有用户可登录
- [ ] OAuth2 客户端配置正确

### 核心服务
- [ ] Grafana dashboard 数据完整
- [ ] Nextcloud 文件可访问
- [ ] Gitea 仓库可克隆
- [ ] Vaultwarden vault 可解锁
- [ ] Jellyfin 媒体库可播放

### 网络
- [ ] AdGuard DNS 解析正常
- [ ] WireGuard VPN 可连接
- [ ] 所有服务通过域名 HTTPS 访问

---

## 恢复演练建议

**每季度执行一次完整恢复演练：**

1. 在测试环境（VPS/虚拟机）执行完整恢复
2. 记录实际 RTO
3. 记录遇到的问题
4. 更新本文档
5. 更新 `backup.sh` 以修复发现的问题

### 演练记录

| 日期 | 环境 | 实际 RTO | 问题 | 修复 |
|------|------|---------|------|------|
| _待填写_ | | | | |

---

## 常见问题

### Q: 恢复后 HTTPS 证书报错？

A: Let's Encrypt 有速率限制。在 `.env` 中设置 `ACME_CA_SERVER=https://acme-staging-v02.api.letsencrypt.org/directory` 先用 staging 证书测试，确认一切正常后改回生产地址并删除 `data/traefik/certs/` 下的旧证书。

### Q: 数据库恢复后服务连不上？

A: 检查 `.env` 中的数据库密码是否与备份时一致。Authentik 等服务的数据库连接字符串存于 PostgreSQL 中，密码不一致会导致连接失败。

### Q: Docker volume 恢复失败？

A: 确认目标 volume 不存在同名冲突。用 `docker volume ls` 检查，必要时先 `docker volume rm <name>`。

### Q: 备份文件损坏怎么办？

A: 1) 用 `backup.sh --verify` 检查；2) 从远程存储（S3/B2）下载其他备份副本；3) 如果所有副本都损坏，检查 `backup.log` 定位问题。
