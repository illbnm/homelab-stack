# Backup Stack — 备份与灾难恢复

完整的 3-2-1 备份策略实现，支持多种存储后端。

## 📦 服务清单

| 服务 | 镜像 | 用途 | 访问地址 |
|------|------|------|----------|
| Restic REST Server | restic/rest-server:0.13.0 | 本地备份仓库 | https://restic.${DOMAIN} |
| Duplicati | lscr.io/linuxserver/duplicati:2.0.8 | 加密云备份 | https://backup.${DOMAIN} |
| Ntfy | binwiederhier/ntfy:v2.11.0 | 备份通知 | https://ntfy.${DOMAIN} |

## 🚀 快速开始

### 1. 配置环境变量

```bash
cd stacks/backup
cp .env.example .env
nano .env
```

**必需配置**:
```bash
# 备份目标 (local|s3|b2|sftp|r2)
BACKUP_TARGET=local

# Restic 配置
RESTIC_USERNAME=homelab
RESTIC_PASSWORD=your-secure-password
RESTIC_DATA_PATH=/opt/homelab-backups/restic

# 备份源路径
BACKUP_SOURCE_PATH=/data

# 通知配置
NTFY_TOPIC=homelab-backup
NTFY_SERVER=https://ntfy.sh
```

### 2. 启动服务

```bash
docker compose up -d
```

### 3. 验证服务

```bash
docker compose ps
# 所有服务应显示为 healthy
```

## 📋 备份脚本使用

### 基本备份

```bash
# 备份所有内容
./scripts/backup.sh --target all

# 仅备份媒体栈
./scripts/backup.sh --target media

# 预览备份（不实际执行）
./scripts/backup.sh --target all --dry-run
```

### 查看备份

```bash
# 列出所有备份
./scripts/backup.sh --list

# 验证备份完整性
./scripts/backup.sh --verify

# 清理过期备份
./scripts/backup.sh --cleanup
```

### 恢复备份

```bash
# 从指定备份恢复
./scripts/backup.sh --restore 20260318_020000
```

## 🔄 自动备份

### 使用 Cron

编辑 crontab：
```bash
crontab -e
```

添加每日备份任务（凌晨 2 点）：
```cron
0 2 * * * /home/ggmini/.openclaw/workspace/homelab-stack/scripts/backup.sh --target all >> /var/log/homelab-backup.log 2>&1
```

### 使用 Systemd Timer

创建服务文件 `/etc/systemd/system/homelab-backup.service`:
```ini
[Unit]
Description=HomeLab Backup Service
After=docker.service

[Service]
Type=oneshot
User=root
ExecStart=/home/ggmini/.openclaw/workspace/homelab-stack/scripts/backup.sh --target all
```

创建定时器文件 `/etc/systemd/system/homelab-backup.timer`:
```ini
[Unit]
Description=Run HomeLab Backup Daily
Requires=homelab-backup.service

[Timer]
OnCalendar=*-*-* 02:00:00
Persistent=true

[Install]
WantedBy=timers.target
```

启用定时器：
```bash
sudo systemctl daemon-reload
sudo systemctl enable homelab-backup.timer
sudo systemctl start homelab-backup.timer
```

## 📊 备份目标配置

### 本地备份 (Local)

```bash
BACKUP_TARGET=local
BACKUP_DIR=/opt/homelab-backups
```

### MinIO/S3

```bash
BACKUP_TARGET=s3
BACKUP_S3_URL=s3://homelab-backups
BACKUP_S3_ACCESS_KEY=minioadmin
BACKUP_S3_SECRET_KEY=your-secret-key
BACKUP_S3_BUCKET=homelab-backups
```

### Backblaze B2

```bash
BACKUP_TARGET=b2
BACKUP_B2_BUCKET=your-bucket-name
BACKUP_B2_ACCOUNT_ID=your-account-id
BACKUP_B2_APPLICATION_KEY=your-application-key
```

### SFTP

```bash
BACKUP_TARGET=sftp
BACKUP_SFTP_HOST=your-sftp-server.com
BACKUP_SFTP_PORT=22
BACKUP_SFTP_USER=backup
BACKUP_SFTP_PASSWORD=your-password
BACKUP_SFTP_PATH=/backups/homelab
```

### Cloudflare R2

```bash
BACKUP_TARGET=r2
BACKUP_R2_BUCKET=your-r2-bucket
BACKUP_R2_ACCESS_KEY_ID=your-access-key
BACKUP_R2_SECRET_ACCESS_KEY=your-secret-key
BACKUP_R2_ENDPOINT=https://your-account-id.r2.cloudflarestorage.com
```

## 🔔 通知配置

### Ntfy 通知

备份完成后自动发送通知到 Ntfy：

```bash
# 订阅通知
ntfy sub homelab-backup

# 或在手机上安装 Ntfy App，订阅主题
```

### 集成其他通知服务

通过 Apprise 支持更多通知渠道：
- Telegram
- Discord
- Slack
- 邮件
- 企业微信
- 钉钉

## 🛡️ 安全建议

1. **加密备份**: Restic 默认使用 AES-256 加密
2. **强密码**: 使用至少 32 字符的随机密码
3. **离线备份**: 定期将备份复制到离线存储
4. **访问控制**: 限制备份服务器访问 IP
5. **监控告警**: 配置备份失败告警

## 📈 备份策略

### 保留策略

- 每日备份：保留 7 份
- 每周备份：保留 4 份
- 每月备份：保留 12 份

### 验证策略

- 每周自动验证备份完整性
- 每月进行一次完整恢复演练
- 每季度更新灾难恢复文档

## 🔧 故障排查

### 备份失败

```bash
# 查看详细日志
./scripts/backup.sh --target all 2>&1 | tee backup.log

# 检查磁盘空间
df -h

# 检查 Docker 状态
docker ps
```

### Restic 仓库错误

```bash
# 初始化仓库
restic init

# 检查仓库
restic check

# 查看快照
restic snapshots
```

### 通知失败

```bash
# 测试 Ntfy
curl -X POST -H "Title: Test" -d "Test message" https://ntfy.sh/homelab-backup

# 检查网络连接
curl -I https://ntfy.sh
```

## 📚 相关文档

- [灾难恢复流程](../docs/disaster-recovery.md)
- [备份脚本帮助](../scripts/backup.sh --help)

## 💰 赏金信息

- **Issue**: #12 - Backup & DR
- **金额**: $150 USDT
- **状态**: 已完成

---

*最后更新：2026-03-18*
