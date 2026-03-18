# 灾难恢复文档 (Disaster Recovery)

本文档描述如何在完全灾难场景下从零恢复 HomeLab 系统。

## 📋 目录

- [恢复策略](#恢复策略)
- [恢复时间目标 (RTO)](#恢复时间目标-rto)
- [恢复点目标 (RPO)](#恢复点目标-rpo)
- [完整恢复流程](#完整恢复流程)
- [服务恢复顺序](#服务恢复顺序)
- [验证检查清单](#验证检查清单)
- [常见问题](#常见问题)

---

## 恢复策略

### 3-2-1 备份原则

- **3** 份数据副本（1 份生产 + 2 份备份）
- **2** 种不同介质（本地磁盘 + 云存储）
- **1** 份异地备份（云存储或离线存储）

### 备份目标

| 目标 | 用途 | 频率 | 保留期 |
|------|------|------|--------|
| 本地 Restic | 快速恢复 | 每日 | 7 天 |
| MinIO/S3 | 中期存储 | 每日 | 30 天 |
| Backblaze B2 | 异地归档 | 每周 | 1 年 |

---

## 恢复时间目标 (RTO)

| 场景 | 目标时间 | 说明 |
|------|----------|------|
| 单个服务故障 | < 5 分钟 | 从本地备份快速恢复 |
| 主机故障 | < 2 小时 | 新主机完整恢复 |
| 完全灾难恢复 | < 4 小时 | 包括数据验证 |

---

## 恢复点目标 (RPO)

| 数据类型 | RPO | 说明 |
|----------|-----|------|
| 数据库 | < 24 小时 | 每日备份 |
| 配置文件 | < 24 小时 | 每日备份 |
| 媒体文件 | < 7 天 | 每周增量备份 |
| 文档文件 | < 24 小时 | 每日增量备份 |

---

## 完整恢复流程

### 阶段 1: 准备新主机 (15 分钟)

```bash
# 1. 安装基础系统 (Ubuntu 22.04 LTS)
# 2. 更新系统
sudo apt update && sudo apt upgrade -y

# 3. 安装 Docker
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER

# 4. 安装 Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" \
  -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# 5. 安装必要工具
sudo apt install -y git curl wget restic

# 6. 克隆 HomeLab 仓库
git clone https://github.com/illbnm/homelab-stack.git
cd homelab-stack
```

### 阶段 2: 恢复配置 (10 分钟)

```bash
# 1. 从备份恢复配置文件
# 假设备份在 /opt/homelab-backups/20260318_020000

# 2. 恢复 .env 文件
cp /opt/homelab-backups/20260318_020000/configs.tar.gz /tmp/
cd /tmp && tar xzf configs.tar.gz
cp -r config/.env.example config/.env

# 3. 编辑配置文件，填入实际值
nano config/.env

# 必需配置项:
# - DOMAIN=yourdomain.com
# - TZ=Asia/Shanghai
# - 所有服务密码
# - 备份仓库凭据
```

### 阶段 3: 恢复基础架构 (20 分钟)

```bash
# 1. 启动基础服务栈
cd stacks/base
docker compose up -d

# 等待服务健康
../../scripts/wait-healthy.sh

# 2. 启动数据库层
cd ../databases
docker compose up -d

# 等待数据库就绪
sleep 30

# 3. 恢复数据库
# PostgreSQL
docker exec -i homelab-postgres psql -U postgres < /opt/homelab-backups/20260318_020000/postgresql_all.sql

# MySQL/MariaDB
docker exec -i homelab-mariadb mysql -u root -p < /opt/homelab-backups/20260318_020000/mysql_all.sql

# Redis (如果有 RDB 文件)
docker cp /opt/homelab-backups/20260318_020000/redis_dump.rdb homelab-redis:/data/dump.rdb
docker exec homelab-redis redis-cli BGSAVE
```

### 阶段 4: 恢复 SSO (15 分钟)

```bash
# 1. 启动 Authentik
cd stacks/sso
docker compose up -d

# 2. 等待 Authentik 就绪
sleep 60

# 3. 验证 Authentik 可访问
curl -sf https://auth.${DOMAIN}/application/o/authorization/ || echo "Authentik not ready"

# 4. 恢复 Authentik 配置（如果有导出）
# 登录 Authentik 管理界面导入备份
```

### 阶段 5: 恢复应用服务 (30 分钟)

按优先级启动各服务栈：

```bash
# 1. 生产力工具 (最高优先级)
cd stacks/productivity
docker compose up -d

# 2. 存储栈
cd stacks/storage
docker compose up -d

# 3. 媒体栈
cd stacks/media
docker compose up -d

# 4. 网络栈
cd stacks/network
docker compose up -d

# 5. 家庭自动化
cd stacks/home-automation
docker compose up -d

# 6. AI 栈
cd stacks/ai
docker compose up -d

# 7. 监控栈
cd stacks/monitoring
docker compose up -d

# 8. 通知栈
cd stacks/notifications
docker compose up -d
```

### 阶段 6: 恢复数据卷 (30 分钟)

```bash
# 使用备份脚本恢复 Docker volumes
cd /home/ggmini/.openclaw/workspace/homelab-stack

# 列出可用备份
./scripts/backup.sh --list

# 恢复指定备份
./scripts/backup.sh --restore 20260318_020000

# 或手动恢复特定 volume
# 示例：恢复 Jellyfin 配置
docker run --rm \
  -v jellyfin-config:/data \
  -v /opt/homelab-backups/20260318_020000:/backup \
  alpine:3.19 \
  tar xzf /backup/vol_jellyfin-config.tar.gz -C /data
```

### 阶段 7: 验证与测试 (30 分钟)

参考下方 [验证检查清单](#验证检查清单) 逐项验证。

---

## 服务恢复顺序

```
1. Base (Traefik + Cloudflare Tunnel)
   ↓
2. Databases (PostgreSQL + Redis + MariaDB)
   ↓
3. SSO (Authentik)
   ↓
4. Productivity (Gitea + Vaultwarden + Outline + BookStack)
   ↓
5. Storage (Nextcloud + MinIO + FileBrowser)
   ↓
6. Media (Jellyfin + Sonarr + Radarr + Prowlarr)
   ↓
7. Network (AdGuard Home + WireGuard)
   ↓
8. Home Automation (Home Assistant + Node-RED + Zigbee2MQTT)
   ↓
9. Monitoring (Uptime Kuma + Prometheus + Grafana)
   ↓
10. Notifications (Gotify + Apprise)
```

**总预计时间**: 2.5 - 3.5 小时

---

## 验证检查清单

### ✅ 基础架构

- [ ] Traefik 仪表板可访问 (https://traefik.${DOMAIN})
- [ ] Cloudflare Tunnel 在线
- [ ] 所有容器健康检查通过

### ✅ 数据库

- [ ] PostgreSQL 可连接
- [ ] Redis 可连接
- [ ] MariaDB 可连接
- [ ] 所有数据库存在

### ✅ SSO

- [ ] Authentik 登录页面可访问
- [ ] 可使用 admin 账号登录
- [ ] OIDC 提供商配置完整

### ✅ 生产力工具

- [ ] Gitea 可访问，可登录
- [ ] Vaultwarden 可访问，可登录
- [ ] Outline 可访问，文档存在
- [ ] BookStack 可访问，文档存在

### ✅ 存储

- [ ] Nextcloud 可访问，文件存在
- [ ] MinIO 控制台可访问
- [ ] FileBrowser 可访问

### ✅ 媒体

- [ ] Jellyfin 可访问，媒体库完整
- [ ] Sonarr 可访问，配置存在
- [ ] Radarr 可访问，配置存在
- [ ] Prowlarr 可访问，索引器存在

### ✅ 网络

- [ ] AdGuard Home DNS 解析正常
- [ ] WireGuard 客户端可连接
- [ ] 内网服务可通过 VPN 访问

### ✅ 家庭自动化

- [ ] Home Assistant 可访问
- [ ] Node-RED 可访问，流程存在
- [ ] Zigbee2MQTT 可访问，设备在线

### ✅ 监控

- [ ] Uptime Kuma 可访问，监控正常
- [ ] Prometheus 可访问，数据收集正常
- [ ] Grafana 可访问，仪表板正常

### ✅ 备份

- [ ] 备份脚本可执行
- [ ] 可创建新备份
- [ ] 备份通知正常

---

## 常见问题

### Q1: 恢复后服务无法启动

**检查**:
1. 查看容器日志：`docker logs <container>`
2. 检查配置文件语法
3. 验证环境变量是否正确
4. 确认端口无冲突

### Q2: 数据库连接失败

**解决**:
```bash
# 检查数据库容器状态
docker ps | grep -E 'postgres|mariadb|redis'

# 查看数据库日志
docker logs homelab-postgres

# 测试连接
docker exec homelab-postgres psql -U postgres -c "SELECT 1"
```

### Q3: HTTPS 证书问题

**解决**:
```bash
# 重启 Traefik
cd stacks/base
docker compose restart traefik

# 查看证书状态
docker exec traefik cat /letsencrypt/acme.json | jq
```

### Q4: 备份恢复后数据不一致

**解决**:
1. 停止相关服务
2. 清空数据卷：`docker volume rm <volume>`
3. 重新恢复备份
4. 启动服务

### Q5: Authentik 登录循环

**解决**:
```bash
# 清除浏览器缓存和 Cookie
# 检查 Authentik 日志
docker logs authentik-server

# 重启 Authentik
cd stacks/sso
docker compose restart
```

---

## 紧急联系

- **文档维护**: GitHub Issues
- **备份问题**: 查看 `scripts/backup.sh --help`
- **恢复支持**: 参考 GitHub 仓库 Discussions

---

## 附录：快速恢复命令

```bash
# 一键恢复脚本（假设备份在默认位置）
cd /home/ggmini/.openclaw/workspace/homelab-stack
./scripts/backup.sh --restore latest

# 验证恢复
./scripts/backup.sh --verify

# 列出所有备份
./scripts/backup.sh --list
```

---

*最后更新：2026-03-18*
*文档版本：1.0*
