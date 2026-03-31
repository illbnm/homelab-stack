# 灾难恢复文档 (Disaster Recovery)

> 本文档描述了完整的灾难恢复流程，包括从全新主机从零恢复整个 HomeLab Stack 的步骤。

---

## 📋 概述

### 恢复策略
- **RTO (恢复时间目标)**: < 4 小时
- **RPO (恢复点目标)**: < 1 小时
- **完整恢复时间**: 4-6 小时

### 恢复顺序

恢复必须按照以下顺序进行，以确保依赖关系正确：

1. **基础服务** (Base) - Traefik, Portainer, Watchtower
2. **数据库层** (Data) - PostgreSQL, Redis, MariaDB
3. **SSO/认证** (SSO) - Authentik
4. **监控** (Monitoring) - Prometheus, Grafana, Loki
5. **其他服务** - Media, Storage, AI 等

---

## 🔧 先决条件

### 硬件要求
- Linux 服务器 (推荐 Ubuntu 22.04+ 或 Debian 12+)
- 最低 4GB RAM, 2 CPU cores
- 足够的存储空间 (至少 100GB)
- 可靠的网络连接

### 软件要求
- Docker 24.0+
- Docker Compose v2+
- Git
- curl / wget

### 备份文件要求
确保你拥有以下备份文件：
- `configs.tar.gz` - 配置文件
- `vol_*.tar.gz` - Docker volumes
- `postgresql_all.sql` - PostgreSQL 数据库
- `mysql_all.sql` - MySQL/MariaDB 数据库

---

## 🚀 恢复步骤

### 1. 准备阶段 (30 分钟)

#### 1.1 安装 Docker

```bash
# 安装 Docker
curl -fsSL https://get.docker.com | sh

# 添加当前用户到 docker 组
sudo usermod -aG docker $USER

# 重新登录或运行
newgrp docker

# 验证安装
docker --version
docker compose version
```

#### 1.2 克隆仓库

```bash
# 克隆 HomeLab Stack 仓库
git clone https://github.com/YOUR_USERNAME/homelab-stack.git
cd homelab-stack

# 配置环境变量
cp .env.example .env
nano .env  # 填写必要的配置
```

#### 1.3 准备备份文件

```bash
# 创建备份目录
mkdir -p /opt/homelab-backups

# 下载或复制备份文件到这个目录
# 如果使用 S3/B2/SFTP，使用相应的工具下载
# 示例 (S3):
# rclone copy s3:your-bucket/homelab-backup/LATEST /opt/homelab-backups/LATEST

# 验证备份完整性
./scripts/backup.sh --verify
```

---

### 2. 基础服务恢复 (15 分钟)

#### 2.1 恢复配置文件

```bash
# 解压配置文件 (会覆盖当前配置)
cd /opt/homelab-backups/LATEST
tar xzf configs.tar.gz -C /path/to/homelab-stack/

# 检查 .env 文件
cat /path/to/homelab-stack/.env
```

#### 2.2 启动基础服务

```bash
cd /path/to/homelab-stack

# 启动基础栈
docker compose -f docker-compose.base.yml up -d

# 验证服务状态
docker ps | grep -E 'traefik|portainer|watchtower'

# 检查 Traefik
curl -k https://traefik.yourdomain.com/api/rawdata
```

---

### 3. 数据库层恢复 (30 分钟)

#### 3.1 启动数据库容器

```bash
# 启动数据库栈
./scripts/stack-manager.sh start databases

# 等待数据库启动
sleep 30

# 验证数据库运行
docker ps | grep -E 'postgres|redis|mariadb'
```

#### 3.2 恢复 PostgreSQL

```bash
# 找到 PostgreSQL 容器
PG_CONTAINER=$(docker ps --format '{{.Names}}' | grep postgres | head -1)

# 恢复数据库
cat /opt/homelab-backups/LATEST/postgresql_all.sql | \
  docker exec -i $PG_CONTAINER psql -U postgres

# 验证恢复
docker exec $PG_CONTAINER psql -U postgres -c "\l"
```

#### 3.3 恢复 MariaDB/MySQL

```bash
# 找到 MySQL 容器
MYSQL_CONTAINER=$(docker ps --format '{{.Names}}' | grep -E 'mariadb|mysql' | head -1)

# 获取 root 密码
MYSQL_PASS=$(grep MYSQL_ROOT_PASSWORD .env | cut -d= -f2)

# 恢复数据库
cat /opt/homelab-backups/LATEST/mysql_all.sql | \
  docker exec -i $MYSQL_CONTAINER mysql -u root -p$MYSQL_PASS

# 验证恢复
docker exec $MYSQL_CONTAINER mysql -u root -p$MYSQL_PASS -e "SHOW DATABASES;"
```

#### 3.4 恢复 Redis

```bash
# Redis 通常不需要恢复，数据在 volume 中
# 如果需要，可以恢复 volume:

REDIS_VOLUME="homelab_redis_data"
docker volume create $REDIS_VOLUME

docker run --rm \
  -v ${REDIS_VOLUME}:/data \
  -v /opt/homelab-backups/LATEST:/backup \
  alpine:3.19 \
  sh -c "cd /data && tar xzf /backup/vol_${REDIS_VOLUME}.tar.gz"
```

---

### 4. SSO 恢复 (10 分钟)

#### 4.1 恢复 Authentik

```bash
# 启动 SSO 栈
./scripts/stack-manager.sh start sso

# 等待服务启动
sleep 20

# 检查 Authentik 状态
docker logs authentik-server-1 --tail 50
```

#### 4.2 验证 SSO

```bash
# 访问 Authentik
curl -k https://auth.yourdomain.com

# 测试登录
# (使用之前备份的管理员凭据)
```

---

### 5. 监控恢复 (5 分钟)

```bash
# 启动监控栈
./scripts/stack-manager.sh start monitoring

# 等待服务启动
sleep 30

# 验证 Prometheus
curl http://localhost:9090/-/healthy

# 验证 Grafana
curl http://localhost:3000/api/health
```

---

### 6. 其他服务恢复 (60+ 分钟)

```bash
# 恢复所有其他服务
for stack in media storage productivity ai home-automation; do
    echo "恢复 $stack 栈..."
    ./scripts/stack-manager.sh start $stack
    sleep 30
done

# 验证所有服务
docker ps --format "table {{.Names}}\t{{.Status}}"
```

---

### 7. 最终检查 (10 分钟)

#### 7.1 服务健康检查

```bash
# 检查所有容器状态
docker ps -a

# 检查 Traefik 路由
curl -k https://traefik.yourdomain.com/api/http/routers

# 检查日志错误
docker compose logs --tail=100 | grep -i error
```

#### 7.2 功能测试

- [ ] 访问 Traefik Dashboard
- [ ] 登录 Authentik
- [ ] 访问 Grafana Dashboard
- [ ] 检查 Nextcloud 文件
- [ ] 验证 Jellyfin 媒体库
- [ ] 测试 Home Assistant

#### 7.3 数据完整性验证

```bash
# 验证备份完整性
./scripts/backup.sh --verify

# 检查数据库一致性
docker exec $PG_CONTAINER psql -U postgres -c "SELECT count(*) FROM users;"
```

---

## 🔄 自动化恢复脚本

为了简化恢复流程，提供了一个自动化恢复脚本：

```bash
#!/bin/bash
# 恢复脚本示例

BACKUP_PATH="/opt/homelab-backups/LATEST"
PROJECT_DIR="/path/to/homelab-stack"

echo "=== 开始自动化恢复 ==="

# 1. 恢复配置
cd $BACKUP_PATH
tar xzf configs.tar.gz -C $PROJECT_DIR/

# 2. 启动基础服务
cd $PROJECT_DIR
docker compose -f docker-compose.base.yml up -d

# 3. 启动数据库
./scripts/stack-manager.sh start databases
sleep 30

# 4. 恢复数据库
cat $BACKUP_PATH/postgresql_all.sql | docker exec -i postgres psql -U postgres
cat $BACKUP_PATH/mysql_all.sql | docker exec -i mariadb mysql -u root -p$MYSQL_ROOT_PASSWORD

# 5. 恢复 volumes
for vol_file in $BACKUP_PATH/vol_*.tar.gz; do
    vol_name=$(basename $vol_file .tar.gz | sed 's/^vol_//')
    docker volume create $vol_name 2>/dev/null || true
    docker run --rm \
        -v ${vol_name}:/data \
        -v $BACKUP_PATH:/backup \
        alpine:3.19 \
        sh -c "cd /data && tar xzf /backup/$(basename $vol_file)"
done

# 6. 启动所有服务
for stack in sso monitoring media storage productivity ai; do
    ./scripts/stack-manager.sh start $stack
    sleep 20
done

echo "=== 恢复完成 ==="
docker ps
```

---

## 🆘 故障排除

### 常见问题

#### 1. 备份文件损坏
```bash
# 验证 tar.gz 文件
tar tzf configs.tar.gz

# 如果损坏，尝试从其他备份恢复
./scripts/backup.sh --list
```

#### 2. 数据库恢复失败
```bash
# 检查 SQL 文件
head -n 50 postgresql_all.sql

# 尝试手动恢复
docker exec -i postgres psql -U postgres < postgresql_all.sql
```

#### 3. Volume 恢复失败
```bash
# 手动创建 volume
docker volume create my_volume

# 手动恢复数据
docker run --rm \
    -v my_volume:/data \
    -v /backup/path:/backup \
    alpine tar xzf /backup/vol_my_volume.tar.gz -C /data
```

#### 4. Traefik 路由问题
```bash
# 重启 Traefik
docker compose -f docker-compose.base.yml restart traefik

# 检查配置
docker exec traefik traefik version
```

#### 5. 权限问题
```bash
# 修复文件权限
sudo chown -R $USER:$USER /path/to/homelab-stack

# 修复 Docker volumes
docker run --rm \
    -v my_volume:/data \
    alpine sh -c "chown -R 1000:1000 /data"
```

---

## 📞 支持与联系

- **文档**: [README.md](../README.md)
- **Issues**: [GitHub Issues](https://github.com/YOUR_USERNAME/homelab-stack/issues)
- **备份配置**: [scripts/backup.sh](../scripts/backup.sh)

---

## 📝 检查清单

使用此清单确保恢复过程完整：

- [ ] 所有备份文件已下载并验证
- [ ] Docker 和 Docker Compose 已安装
- [ ] 基础服务 (Traefik, Portainer) 已启动
- [ ] 数据库已恢复 (PostgreSQL, MySQL)
- [ ] SSO 已恢复 (Authentik)
- [ ] 监控已恢复 (Prometheus, Grafana)
- [ ] 所有其他服务已启动
- [ ] 所有服务健康检查通过
- [ ] 功能测试完成
- [ ] 数据完整性验证通过

---

_最后更新: 2026-03-31_
_作者: 思捷娅科技 (SJYKJ)_
