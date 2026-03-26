# 🆘 灾难恢复文档

> 本文档描述如何在全新服务器上从零恢复整个 HomeLab 环境

## 📋 恢复检查清单

### 恢复前准备

- [ ] 确认硬件/VM 规格满足要求
- [ ] 准备空白磁盘或确认数据盘可格式化
- [ ] 下载所有备份文件（配置、Restic 仓库、数据库备份）
- [ ] 准备网络环境（域名解析、端口映射）
- [ ] 获取所有密码和密钥

### 恢复顺序

```
1. 操作系统 + Docker (第1层)
2. 网络基础设施 (第2层)
3. 基础服务 (第3层)
4. 数据库 (第4层)
5. SSO/身份认证 (第5层)
6. 数据服务 (第6层)
7. 应用服务 (第7层)
8. 备份验证 (第8层)
```

---

## 🖥️ 第1层：操作系统 + Docker

### 1.1 安装 Ubuntu 22.04 LTS

```bash
# 更新系统
sudo apt update && sudo apt upgrade -y

# 安装必要工具
sudo apt install -y curl wget git vim htop net-tools
```

### 1.2 安装 Docker

```bash
# 安装 Docker
curl -fsSL https://get.docker.com | sh

# 安装 Docker Compose plugin
sudo apt install -y docker-compose-plugin

# 验证安装
docker version
docker compose version
```

### 1.3 创建网络

```bash
# 创建 Docker 网络
docker network create proxy
docker network create databases
```

---

## 🌐 第2层：网络基础设施

### 2.1 克隆代码仓库

```bash
# 克隆仓库
git clone https://github.com/your-username/homelab-stack.git
cd homelab-stack

# 切换到稳定版本
git checkout master
```

### 2.2 配置环境变量

```bash
# 复制并编辑环境变量
cp .env.example .env
vim .env

# 必须配置:
# - DOMAIN=yourdomain.com
# - ACME_EMAIL=you@example.com
# - POSTGRES_ROOT_PASSWORD=xxx
# - REDIS_PASSWORD=xxx
# - MARIADB_ROOT_PASSWORD=xxx
# - 其他密码类变量
```

### 2.3 恢复备份的配置

```bash
# 从备份恢复配置文件
./scripts/restore.sh --target configs

# 或手动解压
tar xzf backups/configs_<timestamp>.tar.gz
```

### 2.4 创建 Traefik 证书目录

```bash
# 创建 Traefik ACME 目录
mkdir -p config/traefik
touch config/traefik/acme.json
chmod 600 config/traefik/acme.json
```

---

## 🔧 第3层：基础服务

### 3.1 启动基础架构

```bash
# 启动基础栈 (Traefik + Portainer + Watchtower)
docker compose -f stacks/base/docker-compose.yml up -d

# 验证
docker compose -f stacks/base/docker-compose.yml ps
curl -sf https://traefik.$DOMAIN/health || echo "检查 Traefik 日志"
```

### 3.2 验证反向代理

```bash
# 访问 Traefik Dashboard
# https://traefik.$DOMAIN

# 验证端口
ss -tlnp | grep -E ':(80|443)'
```

---

## 💾 第4层：数据库

### 4.1 启动数据库栈

```bash
# 启动数据库栈
docker compose -f stacks/databases/docker-compose.yml up -d

# 验证
docker compose -f stacks/databases/docker-compose.yml ps
```

### 4.2 恢复数据库

```bash
# 列出可用的数据库备份
./scripts/restore.sh --list | grep postgres

# 恢复 PostgreSQL
./scripts/restore.sh --target databases

# 或指定备份
./scripts/restore.sh --target databases --backup-id 20260326_020000
```

### 4.3 验证数据库

```bash
# 连接测试
docker exec homelab-postgres psql -U postgres -c "SELECT version();"
docker exec homelab-mariadb mariadb -u root -p"$MARIADB_ROOT_PASSWORD" -e "SELECT VERSION();"
docker exec homelab-redis redis-cli -a "$REDIS_PASSWORD" ping
```

---

## 🔐 第5层：SSO/身份认证

### 5.1 启动 Authentik

```bash
# 启动 SSO 栈
docker compose -f stacks/sso/docker-compose.yml up -d

# 等待启动完成（约 2-3 分钟）
docker compose -f stacks/sso/docker-compose.yml logs -f
```

### 5.2 配置 Authentik

1. 访问 https://auth.$DOMAIN/if/flow/initial/
2. 设置管理员账户
3. 创建 Outpost
4. 配置 OAuth2/OIDC 提供商

---

## 📦 第6层：数据服务

### 6.1 启动存储栈

```bash
# 启动存储栈 (MinIO, Nextcloud, FileBrowser)
docker compose -f stacks/storage/docker-compose.yml up -d
```

### 6.2 恢复存储数据

```bash
# 从 Restic 恢复
./scripts/restore.sh --target restic --backup-id latest --restore-path /opt/homelab/data

# 或从卷备份恢复
./scripts/restore.sh --target volumes --restore-path /opt/homelab/data
```

---

## 🚀 第7层：应用服务

### 7.1 按依赖顺序启动

```bash
# 1. 媒体栈
docker compose -f stacks/media/docker-compose.yml up -d

# 2. 生产力栈
docker compose -f stacks/productivity/docker-compose.yml up -d

# 3. AI 栈
docker compose -f stacks/ai/docker-compose.yml up -d

# 4. 家庭自动化
docker compose -f stacks/home-automation/docker-compose.yml up -d

# 5. 其他栈
docker compose -f stacks/notifications/docker-compose.yml up -d
docker compose -f stacks/dashboard/docker-compose.yml up -d
```

### 7.2 验证服务

```bash
# 查看所有运行中的容器
docker compose -f stacks/*/docker-compose.yml ps

# 检查健康状态
docker ps --format "table {{.Names}}\t{{.Status}}"
```

---

## ✅ 第8层：备份验证

### 8.1 验证备份完整性

```bash
# 运行备份验证
./scripts/backup.sh --verify

# 执行测试备份
./scripts/backup.sh --target all --dry-run
```

### 8.2 验证 Restic 仓库

```bash
# 检查 Restic 仓库
restic -r /opt/homelab-backups/restic check --read-data

# 列出快照
restic -r /opt/homelab-backups/restic snapshots
```

### 8.3 验证云存储同步

```bash
# 检查 Rclone 同步状态
rclone lsl backup:homelab-backups --max-age 24h
```

---

## 📊 恢复后检查清单

### 服务可用性

- [ ] Traefik 反向代理正常
- [ ] Portainer 容器管理正常
- [ ] 所有服务 HTTP 端点可访问
- [ ] SSO 登录正常
- [ ] 数据库连接正常

### 数据完整性

- [ ] 文件内容可正常读取
- [ ] 数据库数据完整
- [ ] 用户上传文件存在
- [ ] 配置设置正确

### 备份功能

- [ ] 定时备份正常执行
- [ ] Restic 快照创建成功
- [ ] 云存储同步正常
- [ ] 通知发送正常

---

## ⏱️ 恢复时间估算 (RTO)

| 组件 | 预计时间 | 说明 |
|------|----------|------|
| 操作系统 + Docker | 30-60 分钟 | 取决于下载速度 |
| 网络基础设施 | 10-20 分钟 | Traefik, DNS |
| 数据库 | 10-30 分钟 | 取决于数据量 |
| SSO/Auth | 15-30 分钟 | 初始化和配置 |
| 存储数据 | 30-60 分钟 | 取决于备份大小 |
| 应用服务 | 20-40 分钟 | 全部启动 |
| **总计** | **2-4 小时** | 全新服务器 |

---

## 🚨 紧急恢复场景

### 场景1：仅数据库损坏

```bash
# 停止数据库容器
docker compose -f stacks/databases/docker-compose.yml stop postgres

# 删除损坏的数据卷
docker volume rm homelab-postgres

# 重新创建卷
docker volume create homelab-postgres

# 启动数据库
docker compose -f stacks/databases/docker-compose.yml up -d postgres

# 恢复数据
./scripts/restore.sh --target databases
```

### 场景2：单个服务故障

```bash
# 查看服务日志
docker compose -f stacks/storage/docker-compose.yml logs nextcloud

# 重启服务
docker compose -f stacks/storage/docker-compose.yml restart nextcloud

# 或重建
docker compose -f stacks/storage/docker-compose.yml up -d --force-recreate nextcloud
```

### 场景3：整个服务器迁移

```bash
# 1. 在新服务器执行第1-3层
# 2. 恢复完整备份
./scripts/restore.sh --target all

# 3. 启动所有栈
for stack in bases databases sso storage media productivity ai home-automation notifications dashboard; do
  docker compose -f stacks/$stack/docker-compose.yml up -d
done
```

---

## 📞 故障排除

### Docker 网络问题

```bash
# 重建网络
docker network rm proxy databases
docker network create proxy
docker network create databases
```

### 卷权限问题

```bash
# 修复卷权限
docker run --rm -v <volume_name>:/data alpine chown -R 1000:1000 /data
```

### 服务无法启动

```bash
# 清理重启
docker compose -f stacks/<stack>/docker-compose.yml down
docker compose -f stacks/<stack>/docker-compose.yml up -d
```

---

## 📝 恢复后必做事项

1. **更新 DNS 记录** — 新服务器 IP
2. **更新证书** — Let's Encrypt 重新签发
3. **检查防火墙** — 开放必要端口
4. **测试备份** — 执行一次完整备份
5. **更新监控** — 检查 Alertmanager 告警
6. **通知用户** — 告知服务恢复
