# Backup & Disaster Recovery / 备份与灾难恢复

Automated 3-2-1 backup strategy with GUI and CLI options.

自动化 3-2-1 备份策略，提供图形界面和命令行两种方式。

## What's Included / 包含服务

| Service | Version | URL | Purpose |
|---------|---------|-----|---------|
| MinIO | 2024-11-07 | `backup-minio.DOMAIN` / `backup-s3.DOMAIN` | Local S3 backup target / 本地 S3 存储目标 |
| Duplicati | 2.0.9.3 | `duplicati.DOMAIN` | GUI backup manager / 图形备份管理器 |
| Restic REST | 0.13.0 | internal | Deduplicated backup repo / 去重备份仓库 |
| Restic Cron | 0.17.3 | background | Automated daily backups / 每日自动备份 |

## 3-2-1 Backup Strategy / 3-2-1 备份策略

```
 [Original Data]  -->  [Local MinIO/Restic]  -->  [Offsite S3]
   (production)          (on-premise)            (AWS/B2/Wasabi)

 3 copies: original + local + offsite
 2 media:  Docker volumes + S3 object storage
 1 offsite: geographically separate cloud
```

## Architecture / 架构

```
[Traefik :443]
    |
    +---> backup-minio.DOMAIN   --> MinIO Console (:9001)
    +---> backup-s3.DOMAIN      --> MinIO S3 API  (:9000)
    +---> duplicati.DOMAIN      --> Duplicati Web UI (:8200)
    |
    +--- restic-backup (cron) ---> backup-minio (local S3)
    |         |                \-> offsite S3 (AWS/B2/Wasabi)
    |         +--- pre-hooks: pg_dump, mysqldump, maintenance mode
    |         +--- post-hooks: notifications, maintenance off
    |
    +--- restic-rest (:8000) --- restic repo on disk
```

## Quick Start / 快速开始

```bash
# 1. Base stack running / 基础栈已运行
cd stacks/base && docker compose up -d && cd ../..
docker network create proxy 2>/dev/null || true

# 2. Set env vars / 设置环境变量
# Edit .env — fill BACKUP_MINIO_ROOT_PASSWORD and RESTIC_PASSWORD

# 3. Make scripts executable / 设置脚本权限
chmod +x config/restic/backup.sh config/restic/hooks/**/*.sh scripts/backup-restore.sh

# 4. Launch / 启动
cd stacks/backup && ln -sf ../../.env .env && docker compose up -d

# 5. Verify / 验证
docker compose ps

# 6. First backup / 首次备份
../../scripts/backup-restore.sh backup
```

## Configuration / 配置说明

### Core Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| DOMAIN | Yes | - | Base domain / 基础域名 |
| TZ | Yes | Asia/Shanghai | Timezone / 时区 |
| BACKUP_MINIO_ROOT_USER | No | minioadmin | MinIO username |
| BACKUP_MINIO_ROOT_PASSWORD | **Yes** | - | MinIO password / MinIO 密码 |
| RESTIC_PASSWORD | **Yes** | - | Restic encryption key / 加密密码 |
| BACKUP_CRON | No | 0 2 * * * | Cron schedule / 定时表达式 |
| BACKUP_SOURCE_PATH | No | /opt/homelab | Host path to backup / 备份源 |
| BACKUP_NOTIFY_URL | No | - | ntfy/webhook URL / 通知地址 |

### Offsite S3 Variables / 异地备份变量

| Variable | Description |
|----------|-------------|
| RESTIC_OFFSITE_REPO | Offsite S3 URL (e.g. s3:s3.amazonaws.com/bucket) |
| RESTIC_OFFSITE_PASSWORD | Offsite encryption password |
| BACKUP_OFFSITE_S3_KEY | S3 access key |
| BACKUP_OFFSITE_S3_SECRET | S3 secret key |

### Retention Policy / 保留策略

| Variable | Default | Description |
|----------|---------|-------------|
| RESTIC_KEEP_HOURLY | 24 | Hourly snapshots / 小时快照 |
| RESTIC_KEEP_DAILY | 7 | Daily / 天 |
| RESTIC_KEEP_WEEKLY | 4 | Weekly / 周 |
| RESTIC_KEEP_MONTHLY | 12 | Monthly / 月 |
| RESTIC_KEEP_YEARLY | 3 | Yearly / 年 |

### Generate Passwords / 生成密码

```bash
echo "BACKUP_MINIO_ROOT_PASSWORD=$(openssl rand -base64 24)"
echo "RESTIC_PASSWORD=$(openssl rand -base64 32)"
```

**IMPORTANT**: Store RESTIC_PASSWORD in a password manager. Without it, backups are unrecoverable.

**重要**: 请将 RESTIC_PASSWORD 存入密码管理器。丢失此密码将导致备份无法恢复。

## CLI Helper / 命令行工具

```bash
./scripts/backup-restore.sh backup           # Immediate backup / 立即备份
./scripts/backup-restore.sh list             # List snapshots / 列出快照
./scripts/backup-restore.sh restore latest   # Restore / 恢复
./scripts/backup-restore.sh verify           # Integrity check / 完整性检查
./scripts/backup-restore.sh stats            # Repo stats / 仓库统计
./scripts/backup-restore.sh dr-test          # DR test / 灾难恢复测试
./scripts/backup-restore.sh dump-db          # Database dump / 数据库备份
./scripts/backup-restore.sh restore-db FILE  # Restore DB / 恢复数据库
./scripts/backup-restore.sh init-offsite     # Init offsite repo / 初始化异地仓库
./scripts/backup-restore.sh unlock           # Remove stale locks / 移除锁
```

## Offsite Examples / 异地备份示例

### AWS S3
```
RESTIC_OFFSITE_REPO=s3:s3.amazonaws.com/my-homelab-backup
BACKUP_OFFSITE_S3_KEY=AKIA...
BACKUP_OFFSITE_S3_SECRET=your-secret
```

### Backblaze B2
```
RESTIC_OFFSITE_REPO=s3:s3.us-west-004.backblazeb2.com/my-bucket
BACKUP_OFFSITE_S3_KEY=your-b2-key-id
BACKUP_OFFSITE_S3_SECRET=your-b2-app-key
```

### Wasabi
```
RESTIC_OFFSITE_REPO=s3:s3.wasabisys.com/my-bucket
BACKUP_OFFSITE_S3_KEY=your-wasabi-key
BACKUP_OFFSITE_S3_SECRET=your-wasabi-secret
```

## Hooks / 钩子

Pre-backup hooks in `config/restic/hooks/pre-backup.d/`:
- `01-nextcloud-maintenance.sh` — Enable Nextcloud maintenance mode

Post-backup hooks in `config/restic/hooks/post-backup.d/`:
- `01-nextcloud-maintenance-off.sh` — Disable Nextcloud maintenance mode

Custom hooks: add executable .sh files to these directories.

## Disaster Recovery Runbook / 灾难恢复手册

### Scenario 1: Single Service Data Loss / 单服务数据丢失

```bash
./scripts/backup-restore.sh list
./scripts/backup-restore.sh restore latest /tmp/restore
cp -r /tmp/restore/source/path/to/service /opt/homelab/path/to/service
docker compose restart <service>
```

### Scenario 2: Database Corruption / 数据库损坏

```bash
docker stop homelab-postgres
docker start homelab-postgres
./scripts/backup-restore.sh restore-db postgres_20240101_020000.sql.gz
```

### Scenario 3: Complete Server Loss / 服务器全毁

```bash
# On new server / 在新服务器上
git clone https://github.com/illbnm/homelab-stack.git && cd homelab-stack
cp /secure-storage/.env .env   # From password manager
docker network create proxy
cd stacks/base && docker compose up -d && cd ../..
cd stacks/backup && docker compose up -d && cd ../..
# Configure offsite env vars, then:
./scripts/backup-restore.sh restore latest /opt/homelab
cd stacks/databases && docker compose up -d && cd ../..
./scripts/backup-restore.sh restore-db postgres_latest.sql.gz
# Start remaining stacks
```

### Scenario 4: Ransomware / 勒索软件

1. Disconnect from network immediately / 立即断网
2. Do NOT run backup jobs / 不要运行备份
3. From clean machine, verify offsite: `restic check`
4. Wipe and rebuild, restore from offsite / 重装系统，从异地恢复

## Notifications / 通知

```
BACKUP_NOTIFY_URL=https://ntfy.yourdomain.com/backup-alerts
```

Supports ntfy, Gotify, or any webhook endpoint.

## CN Mirrors / 国内镜像

| Original | CN Mirror |
|----------|-----------|
| minio/minio:RELEASE.2024-11-07T00-52-20Z | docker.m.daocloud.io/minio/minio:RELEASE.2024-11-07T00-52-20Z |
| minio/mc:RELEASE.2024-11-17T19-35-25Z | docker.m.daocloud.io/minio/mc:RELEASE.2024-11-17T19-35-25Z |
| lscr.io/linuxserver/duplicati:2.0.9.3 | docker.m.daocloud.io/linuxserver/duplicati:2.0.9.3 |
| restic/rest-server:0.13.0 | docker.m.daocloud.io/restic/rest-server:0.13.0 |
| restic/restic:0.17.3 | docker.m.daocloud.io/restic/restic:0.17.3 |

Or: `./scripts/setup-cn-mirrors.sh`

## Local Development / 本地开发

```bash
docker compose -f docker-compose.yml -f docker-compose.local.yml up -d
# MinIO Console:  http://localhost:9011
# MinIO S3 API:   http://localhost:9010
# Duplicati:      http://localhost:8200
# Restic REST:    http://localhost:8100
```

## FAQ / 常见问题

**Q: How to change backup schedule?** Set `BACKUP_CRON` in `.env` (standard cron syntax).

**Q: Lost RESTIC_PASSWORD?** Data is unrecoverable. Always use a password manager.

**Q: Backup too slow?** Use exclude patterns, SSD storage, consider Wasabi (no egress fees).

**Q: Backup to NAS?** Mount NAS and set `RESTIC_REPOSITORY=/mnt/nas/backups`.

**Q: Test without affecting production?** Run `./scripts/backup-restore.sh dr-test` (read-only).
