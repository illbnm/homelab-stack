# 🛡️ Backup & Disaster Recovery Stack

**Issue**: [#12 - Backup & DR — 自动备份 + 灾难恢复](https://github.com/illbnm/homelab-stack/issues/12)  
**Bounty**: $150 USDT  
**状态**: ✅ 已完成

---

## 📋 功能概览

本 Stack 提供完整的备份与灾难恢复解决方案，包括：

| 组件 | 用途 | 端口 |
|------|------|------|
| **Proxmox Backup Server** | 企业级备份后端 | 8007 |
| **Restic** | 增量备份 (去重/加密) | - |
| **Duplicati** | Web UI 备份管理 | 8200 |
| **BorgBackup** | 高效去重备份 | - |
| **Uptime Kuma** | 备份服务监控 | 3002 |

---

## 🚀 快速开始

### 1. 环境变量配置

```bash
# 复制环境变量模板
cp stacks/backup/.env.example .env

# 编辑配置
vim .env
```

**必需配置**:
```bash
# 备份存储路径
BACKUP_DIR=/backup

# Restic 配置
RESTIC_PASSWORD=你的强密码
RESTIC_REPOSITORY=/backup/restic

# Proxmox Backup Server
PBS_PASSWORD=你的强密码

# 备份计划 (cron 格式)
BACKUP_CRON=0 2 * * *  # 每天凌晨 2 点
```

### 2. 启动服务

```bash
# 启动 Backup Stack
docker-compose -f stacks/backup/docker-compose.yml up -d

# 查看状态
docker-compose -f stacks/backup/docker-compose.yml ps
```

### 3. 访问 Web 界面

- **Proxmox Backup Server**: https://backup.your-domain.com:8007
- **Duplicati**: https://duplicati.your-domain.com
- **Uptime Kuma**: https://backup-monitor.your-domain.com

---

## 📦 备份脚本

### 全量备份

```bash
# 执行全量备份
bash stacks/backup/scripts/backup-all.sh

# 查看备份报告
cat /backup/daily/backup_report_*.md
```

### 灾难恢复

```bash
# 列出可用备份
bash stacks/backup/scripts/disaster-recovery.sh list

# 从 Restic 恢复
bash stacks/backup/scripts/disaster-recovery.sh restore-restic latest

# 完整系统恢复
bash stacks/backup/scripts/disaster-recovery.sh full-restore

# 创建紧急备份
bash stacks/backup/scripts/disaster-recovery.sh emergency

# 验证备份完整性
bash stacks/backup/scripts/disaster-recovery.sh verify
```

---

## 📊 备份策略

### 3-2-1 规则

- ✅ **3** 份数据副本 (生产 + 本地备份 + 异地备份)
- ✅ **2** 种不同介质 (磁盘 + 云存储)
- ✅ **1** 个异地备份 (可选配置 S3/WebDAV)

### 保留策略

| 类型 | 保留周期 | 清理策略 |
|------|----------|----------|
| 日常备份 | 7 天 | 自动清理 |
| 周备份 | 4 周 | 自动清理 |
| 月备份 | 12 月 | 自动清理 |
| 紧急备份 | 永久 | 手动清理 |

---

## 🔧 高级配置

### 1. 配置云存储后端

```yaml
# 修改 docker-compose.yml 添加 S3 支持
environment:
  - RESTIC_REPOSITORY=s3:s3.amazonaws.com/bucket-name/path
  - AWS_ACCESS_KEY_ID=your-key
  - AWS_SECRET_ACCESS_KEY=your-secret
```

### 2. 配置备份通知

```bash
# 在 backup-all.sh 中配置
export NOTIFY_URL=https://your-webhook-url/notify
```

### 3. 配置数据库自动备份

```bash
# 在 .env 中配置数据库连接
POSTGRES_HOST=postgres
POSTGRES_USER=postgres
POSTGRES_PASSWORD=your-password
POSTGRES_DB=homelab

MYSQL_HOST=mysql
MYSQL_USER=root
MYSQL_PASSWORD=your-password
```

---

## 📈 监控与告警

### Uptime Kuma 监控项

1. Proxmox Backup Server (HTTP 检查)
2. Restic 备份状态 (脚本检查)
3. 磁盘空间使用率
4. 备份任务执行时间

### 告警配置

```yaml
# 告警规则示例
- 备份失败 > 0 次 → 立即通知
- 磁盘使用率 > 80% → 警告
- 备份时间 > 2 小时 → 警告
```

---

## 🛠️ 故障排查

### 问题：备份失败

```bash
# 检查日志
docker logs restic
docker logs duplicati

# 检查磁盘空间
df -h /backup

# 手动执行备份测试
bash stacks/backup/scripts/backup-all.sh
```

### 问题：恢复失败

```bash
# 验证备份完整性
bash stacks/backup/scripts/disaster-recovery.sh verify

# 查看可用备份
bash stacks/backup/scripts/disaster-recovery.sh list

# 检查权限
ls -la /backup/
```

---

## 💰 赏金信息

**钱包地址**: `TMLkvEDrjvHEUbWYU1jfqyUKmbLNZkx6T1` (USDT TRC20)  
**金额**: $150 USDT

---

## ✅ 验收清单

- [x] Proxmox Backup Server 部署
- [x] Restic 增量备份配置
- [x] Duplicati Web UI 部署
- [x] BorgBackup 配置
- [x] 全量备份脚本 (`backup-all.sh`)
- [x] 灾难恢复脚本 (`disaster-recovery.sh`)
- [x] 3-2-1 备份策略文档
- [x] 监控与告警配置
- [x] 故障排查文档
- [x] Uptime Kuma 监控集成

---

## 📝 更新日志

**2026-03-22** - 初始版本
- ✅ 完成所有组件部署
- ✅ 实现备份/恢复脚本
- ✅ 添加监控集成
- ✅ 编写完整文档

---

**开发者**: 牛马  
**提交日期**: 2026-03-22
