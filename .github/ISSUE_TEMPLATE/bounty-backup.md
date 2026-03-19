---
name: 💰 Bounty - Backup & Recovery
about: 实现完整的备份与灾难恢复方案
title: '[BOUNTY $150] Backup & Recovery — 备份与恢复'
labels: bounty, medium
assignees: ''
---

## 赏金金额

**$150 USDT**

## 任务描述

实现 3-2-1 备份策略：3 份数据，2 种介质，1 份异地。

## 服务清单

| 服务 | 镜像 | 用途 |
|------|------|------|
| Duplicati | `lscr.io/linuxserver/duplicati:2.0.8` | 加密云备份 |
| Restic REST Server | `restic/rest-server:0.13.0` | 本地备份仓库 |

## 核心要求

### 1. 备份脚本 `scripts/backup.sh`

```
用法:
  backup.sh --target <stack|all> [选项]

选项:
  --target all          备份所有 stack 数据卷
  --target media        仅备份媒体栈
  --dry-run             显示将备份的内容，不实际执行
  --restore <backup_id> 从指定备份恢复
  --list                列出所有备份
  --verify              验证备份完整性
```

### 2. 备份目标支持

- 本地目录
- MinIO (S3 兼容)
- Backblaze B2
- SFTP
- Cloudflare R2

通过 `.env` 中 `BACKUP_TARGET=s3|b2|sftp|local` 切换。

### 3. 定时备份

通过 crontab 或 systemd timer 每日 2:00 AM 自动执行。

### 4. 恢复演练文档

`docs/disaster-recovery.md`：
- 完整恢复流程（全新主机从零恢复）
- 各服务恢复顺序（Base → DB → SSO → 其他）
- 预计恢复时间（RTO）
- 验证恢复完整性的检查清单

### 5. 备份通知

备份完成/失败后通过 ntfy 推送通知。

## 验收标准

- [ ] `backup.sh