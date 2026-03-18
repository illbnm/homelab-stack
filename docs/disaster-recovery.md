# 🔥 灾难恢复手册 (Disaster Recovery Runbook)

> 从全新主机零恢复整个 homelab-stack 的完整流程。

## 前提条件

- 全新 Linux 主机 (Ubuntu 22.04+ / Debian 12+)
- Docker + Docker Compose 已安装
- 可访问备份存储 (本地/S3/B2/SFTP/R2)
- `.env` 文件备份 (或记录的环境变量)

## 恢复顺序

严格按以下顺序恢复，因为服务间存在依赖关系：

```
1. Base Infrastructure (Traefik + 网络)
   ↓
2. Databases (PostgreSQL + Redis + MariaDB)
   ↓
3. SSO (Authentik)
   ↓
4. Core Services (Gitea, Nextcloud, Outline...)
   ↓
5. Monitoring (Prometheus, Grafana, Loki)
   ↓
6. Media (Jellyfin, *arr stack)
   ↓
7. Notifications (ntfy, Apprise)
```

## 预计恢复时间 (RTO)

| 阶段 | 预计时间 | 累计 |
|------|---------|------|
| 系统准备 (Docker, 网络) | 15 min | 15 min |
| 下载备份 | 10-30 min | 45 min |
| Base Infrastructure | 5 min | 50 min |
| Databases 恢复 | 10 min | 60 min |
| SSO 恢复 | 5 min | 65 min |
| Core Services | 15 min | 80 min |
| Monitoring | 10 min | 90 min |
| Media + Notifications | 10 min | 100 min |
| 验证 | 15 min | **~2 hours** |

## 详细恢复步骤

### Step 0: 准备环境

```bash
# 安装 Docker
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER

# 克隆仓库
git clone https://github.com/illbnm/homelab-stack.git /opt/homelab
cd /opt/homelab

# 恢复 .env
cp /path/to/backup/.env .env
# 或手动创建，确保所有密码变量正确

# 创建网络
docker network create proxy
docker network create internal
```

### Step 1: 获取备份

```bash
# 从本地
cp /mnt/backup-drive/backup-all-*.tar.gz /opt/homelab/backups/

# 从 S3/MinIO
mc cp minio/backups/backup-all-latest.tar.gz /opt/homelab/backups/

# 从 B2
b2 download-file-by-name homelab-backups backup-all-latest.tar.gz /opt/homelab/backups/

# 从 SFTP
scp backup@remote:/backups/backup-all-latest.tar.gz /opt/homelab/backups/

# 列出可用备份
./scripts/backup.sh --list
```

### Step 2: Base Infrastructure

```bash
docker compose -f stacks/base/docker-compose.yml up -d
# 等待 Traefik 就绪
docker compose -f stacks/base/docker-compose.yml ps
```

### Step 3: Databases

```bash
# 启动数据库容器
docker compose -f stacks/databases/docker-compose.yml up -d

# 等待健康检查通过
docker compose -f stacks/databases/docker-compose.yml ps

# 恢复数据
./scripts/backup.sh --restore backup-all-YYYYMMDD_HHMMSS
```

### Step 4: 验证数据库

```bash
# PostgreSQL — 检查所有数据库存在
docker exec postgres psql -U postgres -c "\l"

# 检查各服务用户
docker exec postgres psql -U postgres -c "\du"

# Redis — 检查连接
docker exec redis redis-cli -a ${REDIS_PASSWORD} ping

# MariaDB — 检查连接
docker exec mariadb mariadb -u root -p${MARIADB_ROOT_PASSWORD} -e "SHOW DATABASES;"
```

### Step 5: 按顺序启动其他服务

```bash
# SSO
docker compose -f stacks/sso/docker-compose.yml up -d

# Core Services (按需)
docker compose -f stacks/gitea/docker-compose.yml up -d
docker compose -f stacks/nextcloud/docker-compose.yml up -d

# Monitoring
docker compose -f stacks/monitoring/docker-compose.yml up -d

# Media
docker compose -f stacks/media/docker-compose.yml up -d

# Notifications
docker compose -f stacks/notifications/docker-compose.yml up -d
```

### Step 6: 全面验证

```bash
# 检查所有容器状态
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# 检查健康状态
docker ps --filter "health=unhealthy" --format "{{.Names}}: {{.Status}}"

# 测试 Traefik 路由
curl -sI https://gitea.${DOMAIN} | head -5
curl -sI https://pgadmin.${DOMAIN} | head -5

# 测试通知
./scripts/notify.sh homelab-alerts "DR Test" "Recovery verification complete" 3
```

## 验证清单

恢复后逐项检查：

- [ ] Traefik dashboard 可访问
- [ ] SSL 证书有效
- [ ] PostgreSQL 所有数据库存在且可连接
- [ ] Redis 响应 PONG
- [ ] MariaDB 可连接
- [ ] pgAdmin 可登录并查看数据
- [ ] Authentik SSO 登录正常
- [ ] Gitea 仓库数据完整
- [ ] Nextcloud 文件可访问
- [ ] Grafana dashboard 数据正常
- [ ] ntfy 通知推送正常
- [ ] 备份定时任务已恢复

## 部分恢复

如果只需恢复特定服务：

```bash
# 仅恢复数据库
./scripts/backup.sh --target databases --restore backup-databases-YYYYMMDD_HHMMSS

# 仅恢复媒体
./scripts/backup.sh --target media --restore backup-media-YYYYMMDD_HHMMSS
```

## 备份验证 (定期执行)

建议每月执行一次恢复演练：

```bash
# 验证备份完整性
./scripts/backup.sh --verify

# 在测试环境恢复验证
./scripts/backup.sh --dry-run --target all
```

## 紧急联系

如果自动恢复失败：
1. 检查 Docker 日志: `docker logs <container>`
2. 检查磁盘空间: `df -h`
3. 检查网络: `docker network ls`
4. 手动恢复 PostgreSQL: `docker exec -i postgres psql -U postgres < pg_dumpall.sql`
