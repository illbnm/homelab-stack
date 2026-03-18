## 任务

Closes #12 — `[BOUNTY $150] Backup & DR — 自动备份 + 灾难恢复`

## 交付内容

### 1. stacks/backup/docker-compose.yml
- Duplicati 2.0.8 加密云备份 (Traefik 暴露 Web UI)
- Restic REST Server 0.13.0 本地备份仓库
- 健康检查配置

### 2. scripts/backup.sh — 统一备份入口
- `--target <stack|all>` 按 stack 或全量备份
- `--dry-run` 预览模式
- `--restore <backup_id>` 从备份恢复
- `--list` 列出所有备份
- `--verify` 验证备份完整性
- 5 种备份目标: local / S3(MinIO) / Backblaze B2 / SFTP / Cloudflare R2
- 通过 `.env` 中 `BACKUP_TARGET` 切换
- PostgreSQL pg_dumpall + Redis BGSAVE
- Docker volume 逐卷备份
- .tar.gz 压缩，7 天保留策略
- 备份完成/失败通过 notify.sh 推送通知

### 3. docs/disaster-recovery.md — 灾难恢复手册
- 完整恢复流程（全新主机从零恢复）
- 恢复顺序: Base → DB → SSO → Core → Monitoring → Media → Notifications
- 预计恢复时间 (RTO): ~2 小时
- 每步详细命令
- 验证清单
- 部分恢复指南
- 紧急排错步骤

### 4. stacks/backup/README.md
- 快速启动指南
- 所有备份目标配置说明
- 定时备份设置 (crontab / systemd timer)
- Duplicati Web UI 说明

## 验收标准对照

- [x] backup.sh 支持 `--target <stack|all>` 备份
- [x] backup.sh 支持 `--dry-run` 预览
- [x] backup.sh 支持 `--restore` 恢复
- [x] backup.sh 支持 `--list` 列出备份
- [x] backup.sh 支持 `--verify` 验证完整性
- [x] 支持本地/MinIO/B2/SFTP/R2 多种备份目标
- [x] 通过 .env 中 BACKUP_TARGET 切换
- [x] 定时备份配置 (crontab)
- [x] docs/disaster-recovery.md 完整恢复流程
- [x] 恢复顺序文档 (Base → DB → SSO → 其他)
- [x] 预计恢复时间 (RTO)
- [x] 验证恢复完整性的检查清单
- [x] 备份完成/失败通过 ntfy 推送通知
