# 灾难恢复指南 (Disaster Recovery)

## 📋 概述

本文档描述在完全系统故障后，如何从零恢复 Homelab Stack 的完整流程。

## 🎯 恢复目标

| 指标 | 目标值 | 说明 |
|------|--------|------|
| **RTO** (恢复时间目标) | < 4 小时 | 从故障到完全恢复的时间 |
| **RPO** (恢复点目标) | < 24 小时 | 最多丢失 24 小时数据 |

## 📦 恢复前准备

### 1. 硬件/环境准备

- [ ] 新服务器或虚拟机已就绪
- [ ] 操作系统安装完成 (Ubuntu 22.04 LTS 推荐)
- [ ] 网络连接正常
- [ ] 域名 DNS 已指向新服务器 IP
- [ ] 备份介质可访问 (本地磁盘/S3/B2/SFTP)

### 2. 软件准备

```bash
# 安装 Docker
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER

# 安装 Docker Compose
sudo apt-get install docker-compose-plugin

# 安装必要工具
sudo apt-get install -y git curl rsync md5sum
```

### 3. 恢复凭证准备

- [ ] `.env` 配置文件备份
- [ ] Restic 密码 (`RESTIC_PASSWORD`)
- [ ] Duplicati 密码
- [ ] Traefik SSL 证书 (可选，会自动续期)
- [ ] 数据库密码
- [ ] SSO 管理员密码

## 🔄 恢复流程

### 阶段 1: 基础架构恢复 (30 分钟)

**恢复顺序**: Base → Network → Storage

```bash
# 1. 克隆 Homelab Stack 仓库
git clone https://github.com/illbnm/homelab-stack.git
cd homelab-stack

# 2. 恢复配置文件
cp /path/to/backup/.env.backup .env

# 3. 启动基础 Stack
cd stacks/base
docker compose up -d

# 4. 验证基础服务
docker compose ps
curl http://localhost:8080/health
```

**验证清单**:
- [ ] Docker 服务正常运行
- [ ] 网络 Stack 可访问
- [ ] 存储 Stack 挂载正常
- [ ] Traefik 反向代理工作

### 阶段 2: 数据库恢复 (30 分钟)

```bash
# 1. 启动数据库服务
cd ../db
docker compose up -d

# 2. 从备份恢复数据库
./scripts/backup.sh --restore <backup_id> --target db

# 3. 验证数据完整性
docker compose exec postgres psql -U postgres -c "SELECT COUNT(*) FROM information_schema.tables;"
```

**验证清单**:
- [ ] PostgreSQL 服务运行
- [ ] 数据库连接正常
- [ ] 表结构完整
- [ ] 数据记录数正确

### 阶段 3: SSO 恢复 (20 分钟)

```bash
# 1. 启动 SSO 服务
cd ../sso
docker compose up -d

# 2. 验证 Authentik 访问
curl -I https://auth.${DOMAIN}

# 3. 测试管理员登录
# 访问 https://auth.${DOMAIN}/if/admin/
```

**验证清单**:
- [ ] Authentik Web UI 可访问
- [ ] 管理员可以登录
- [ ] 用户数据完整
- [ ] OAuth 应用配置存在

### 阶段 4: 应用 Stack 恢复 (60 分钟)

按优先级恢复各应用 Stack:

```bash
# 1. 通知 Stack (优先级高 - 用于接收通知)
cd ../notifications
docker compose up -d

# 2. 媒体 Stack
cd ../media
docker compose up -d

# 3. AI Stack
cd ../ai
docker compose up -d

# 4. 其他 Stack
cd ../productivity
docker compose up -d
```

**验证清单**:
- [ ] 各服务健康检查通过
- [ ] Web UI 可访问
- [ ] 数据卷挂载正常

### 阶段 5: 备份系统恢复 (20 分钟)

```bash
# 1. 启动备份 Stack
cd ../backup
docker compose up -d

# 2. 验证备份服务
docker compose ps

# 3. 执行测试备份
./scripts/backup.sh --target all --dry-run
./scripts/backup.sh --target base

# 4. 验证备份完整性
./scripts/backup.sh --verify
```

**验证清单**:
- [ ] Restic Server 运行
- [ ] Duplicati Web UI 可访问
- [ ] 备份脚本执行正常
- [ ] 定时任务配置正确

## 📋 完整恢复检查清单

### 基础架构
- [ ] Docker 安装完成
- [ ] Docker Compose 安装完成
- [ ] 网络配置正确
- [ ] 存储卷挂载正常
- [ ] Traefik 反向代理工作
- [ ] SSL 证书自动续期

### 数据库
- [ ] PostgreSQL 服务运行
- [ ] 数据库连接正常
- [ ] 所有表存在
- [ ] 数据完整性验证通过

### SSO/认证
- [ ] Authentik 服务运行
- [ ] 管理员可以登录
- [ ] 用户数据完整
- [ ] OAuth 应用配置存在
- [ ] 与其他服务集成正常

### 应用服务
- [ ] 通知 Stack 运行
- [ ] 媒体 Stack 运行
- [ ] AI Stack 运行
- [ ] 生产力 Stack 运行
- [ ] 所有服务健康检查通过

### 备份系统
- [ ] Restic Server 运行
- [ ] Duplicati 运行
- [ ] 备份脚本可执行
- [ ] 定时备份配置正确
- [ ] 测试备份成功
- [ ] 通知集成正常

## 🧪 恢复测试

### 定期恢复演练

建议每季度进行一次完整恢复演练:

```bash
# 1. 准备测试环境
docker create -v test-restore:/data --name test-restore alpine:3.19.1

# 2. 恢复到测试环境
./scripts/backup.sh --restore <backup_id> --target /data

# 3. 验证恢复数据
docker run --rm -v test-restore:/data alpine:3.19.1 ls -la /data

# 4. 清理测试环境
docker rm -f test-restore
docker volume rm test-restore
```

### 自动化恢复测试

在 `.env` 中启用自动恢复测试:

```bash
AUTO_RESTORE_TEST=true
```

## ⚠️ 常见问题

### 问题 1: 数据库恢复失败

**症状**: 恢复后数据库无法连接

**解决**:
```bash
# 检查数据库日志
docker compose logs postgres

# 验证数据文件权限
ls -la /data/db/postgres

# 修复权限
chown -R 70:70 /data/db/postgres
```

### 问题 2: SSL 证书问题

**症状**: HTTPS 访问显示证书错误

**解决**:
```bash
# 强制续期证书
docker compose run --rm traefik traefik --certificatesresolvers.letsencrypt.acme.email=your@email.com

# 或等待自动续期 (通常 24 小时内)
```

### 问题 3: 备份文件损坏

**症状**: 恢复时校验和验证失败

**解决**:
```bash
# 列出所有可用备份
./scripts/backup.sh --list

# 选择其他备份恢复
./scripts/backup.sh --restore <other_backup_id>

# 从异地备份恢复 (S3/B2)
export BACKUP_TARGET=s3
./scripts/backup.sh --restore <backup_id>
```

### 问题 4: 服务依赖顺序错误

**症状**: 服务启动失败，提示依赖服务未就绪

**解决**:
```bash
# 按正确顺序重启服务
docker compose down
docker compose up -d base network storage
sleep 30
docker compose up -d db sso
sleep 30
docker compose up -d notifications media ai
```

## 📊 恢复时间估算

| 阶段 | 预计时间 | 说明 |
|------|----------|------|
| 基础架构恢复 | 30 分钟 | Docker + 网络 + 存储 |
| 数据库恢复 | 30 分钟 | 取决于数据量 |
| SSO 恢复 | 20 分钟 | Authentik 配置 |
| 应用 Stack 恢复 | 60 分钟 | 各应用服务 |
| 备份系统恢复 | 20 分钟 | 备份服务配置 |
| 验证测试 | 20 分钟 | 完整功能验证 |
| **总计** | **~3 小时** | 含缓冲时间 |

## 📞 紧急联系

如恢复过程中遇到问题:

1. 查看日志：`docker compose logs -f <service>`
2. 检查文档：[GitHub Issues](https://github.com/illbnm/homelab-stack/issues)
3. 发送通知：`curl -X POST http://ntfy:8080/support -d "恢复遇到问题：[描述]"`

## 📝 恢复日志模板

```markdown
## 恢复记录

**日期**: YYYY-MM-DD HH:MM
**原因**: [硬件故障/系统崩溃/人为错误/其他]
**恢复人员**: [姓名]

### 时间线
- HH:MM - 发现故障
- HH:MM - 开始恢复
- HH:MM - 基础架构恢复完成
- HH:MM - 数据库恢复完成
- HH:MM - SSO 恢复完成
- HH:MM - 应用 Stack 恢复完成
- HH:MM - 备份系统恢复完成
- HH:MM - 验证测试完成
- HH:MM - 恢复完成

### 遇到的问题
1. [问题描述] - [解决方案]
2. [问题描述] - [解决方案]

### 改进建议
1. [建议内容]
2. [建议内容]

### 验证结果
- [ ] 所有服务正常运行
- [ ] 数据完整性验证通过
- [ ] 用户确认业务正常
```

---

*版本：1.0.0 | 最后更新：2026-03-24*
