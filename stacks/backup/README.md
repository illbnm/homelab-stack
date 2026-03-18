# 💾 Backup & DR Stack — 自动备份 + 灾难恢复

> 3-2-1 备份策略：3 份数据，2 种介质，1 份异地。

## 服务清单

| 服务 | 镜像 | 用途 |
|------|------|------|
| **Duplicati** | `lscr.io/linuxserver/duplicati:2.0.8` | 加密云备份 (Web UI) |
| **Restic REST Server** | `restic/rest-server:0.13.0` | 本地备份仓库 |

## 快速启动

```bash
# 1. 配置 .env
BACKUP_TARGET=local          # local|s3|b2|sftp|r2
BACKUP_DIR=/opt/homelab/backups
BACKUP_RETENTION_DAYS=7

# S3/MinIO (可选)
# S3_ENDPOINT=https://minio.example.com
# S3_BUCKET=homelab-backups

# B2 (可选)
# B2_BUCKET=homelab-backups

# SFTP (可选)
# SFTP_TARGET=backup@remote:/backups

# R2 (可选)
# R2_ENDPOINT=https://xxx.r2.cloudflarestorage.com
# R2_BUCKET=homelab-backups

# 2. 启动备份服务
docker compose -f stacks/backup/docker-compose.yml up -d

# 3. 执行首次备份
./scripts/backup.sh --target all
```

## 备份脚本 (scripts/backup.sh)

```bash
# 备份所有 stack
./scripts/backup.sh --target all

# 仅备份数据库
./scripts/backup.sh --target databases

# 仅备份媒体
./scripts/backup.sh --target media

# 预览（不实际执行）
./scripts/backup.sh --target all --dry-run

# 列出所有备份
./scripts/backup.sh --list

# 验证备份完整性
./scripts/backup.sh --verify

# 从备份恢复
./scripts/backup.sh --restore backup-all-20260318_020000
```

## 备份目标

通过 `.env` 中 `BACKUP_TARGET` 切换：

| 目标 | 变量 | 说明 |
|------|------|------|
| `local` | `BACKUP_DIR` | 本地目录 (默认) |
| `s3` | `S3_ENDPOINT`, `S3_BUCKET` | MinIO / AWS S3 |
| `b2` | `B2_BUCKET` | Backblaze B2 |
| `sftp` | `SFTP_TARGET` | SFTP 远程服务器 |
| `r2` | `R2_ENDPOINT`, `R2_BUCKET` | Cloudflare R2 |

## 定时备份

```bash
# 每日 2:00 AM 自动备份
echo "0 2 * * * /opt/homelab/scripts/backup.sh --target all" | crontab -

# 或使用 systemd timer
sudo cp config/backup.timer /etc/systemd/system/
sudo systemctl enable --now backup.timer
```

## 备份通知

备份完成/失败后自动通过 `notify.sh` 推送通知到 ntfy。

## 灾难恢复

完整恢复流程见 [docs/disaster-recovery.md](../../docs/disaster-recovery.md)。

恢复顺序：Base → Databases → SSO → Core → Monitoring → Media → Notifications

预计全量恢复时间 (RTO): **~2 小时**

## Duplicati Web UI

访问 `https://duplicati.${DOMAIN}` 配置加密云备份：
- 支持 AES-256 加密
- 增量备份
- 可视化调度
- 支持 30+ 云存储后端
