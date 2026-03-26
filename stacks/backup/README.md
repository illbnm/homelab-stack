# 💾 Backup & Disaster Recovery Stack

> 实现 3-2-1 备份策略：3 份数据，2 种介质，1 份异地

## 🏗️ 架构概览

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        3-2-1 Backup Strategy                             │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│   [源数据]                                                               │
│       │                                                                 │
│       ├──► [Duplicati] ──────► AES-256 加密 ──────► 云存储 (R2/B2/S3)  │
│       │         Web UI 管理                                              │
│       │                                                                 │
│       ├──► [Restic/Resticker] ──► 本地仓库 ───► [Rclone] ──► 云存储    │
│       │         增量快照                                                │
│       │                                                                 │
│       └──► [pg_dump/mysqldump] ──► SQL 文件 ──► 备份存储                │
│                                                                          │
│   备份介质:                                                              │
│     介质1: 本地磁盘 (/opt/homelab-backups)                                │
│     介质2: Restic 仓库 + S3/R2/B2 云存储                                 │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

## 📦 服务清单

| 服务 | 镜像 | 用途 |
|------|------|------|
| Duplicati | lscr.io/linuxserver/duplicati:2.0.8 | 备份管理 Web UI |
| Restic REST Server | restic/rest-server:0.13.0 | 本地备份仓库 |
| Resticker | registry.opensuse.org/home_ckornely/containers/restic/resticker:0.6.0 | 定时增量备份 |
| Rclone | rclone/rclone:1.68.0 | 云存储同步 |

## 🚀 快速开始

### 1. 配置环境变量

```bash
# 在项目根目录编辑 .env，添加以下配置：
BACKUP_ENABLED=true
BACKUP_SCHEDULE="0 2 * * *"
RESTIC_PASSWORD=<生成强密码: openssl rand -base64 32>
BACKUP_LOCAL_PATH=/opt/homelab-backups

# Rclone 云存储配置
RCLONE_DESTINATION=backup
# 创建 rclone.conf (见下方配置示例)
```

### 2. 生成 Restic 密码

```bash
# 生成强密码
openssl rand -base64 32

# 将密码添加到 .env
RESTIC_PASSWORD=<生成的密码>
```

### 3. 配置 Rclone 云存储

```bash
# 创建配置文件
mkdir -p config/rclone
cat > config/rclone/rclone.conf << 'EOF'
[backup]
type = s3
provider = Cloudflare
endpoint = https://<account_id>.r2.cloudflarestorage.com
bucket = homelab-backups
access_key_id = <your_access_key>
secret_access_key = <your_secret_key>
EOF
```

### 4. 启动服务

```bash
# 创建必要的目录
mkdir -p /opt/homelab-backups/restic

# 启动备份栈
cd stacks/backup
ln -sf ../../.env .env
docker compose up -d

# 验证服务运行
docker compose ps
```

### 5. 访问 Web UI

- **Duplicati**: https://backup.${DOMAIN}
  - 首次登录设置管理员密码
  - 添加备份目标（S3/R2/B2/SFTP/本地）
  - 创建备份任务

## 🔧 核心功能

### 备份目标

| 目标 | 配置 | 说明 |
|------|------|------|
| 本地目录 | `BACKUP_TARGET=local` | 存储在 `${BACKUP_LOCAL_PATH}` |
| MinIO/S3 | `BACKUP_TARGET=s3` | S3 兼容存储 |
| Backblaze B2 | `BACKUP_TARGET=b2` | B2 云存储 |
| Cloudflare R2 | `BACKUP_TARGET=r2` | R2 对象存储 |
| SFTP | `BACKUP_TARGET=sftp` | SFTP 服务器 |

### 备份内容

- **PostgreSQL**: `pg_dumpall` 全量备份
- **MariaDB**: `mysqldump` 全量备份
- **Redis**: `BGSAVE` + RDB 文件
- **Docker 卷**: 通过 `docker run --rm -v ... alpine tar` 打包
- **配置文件**: `.env`, `config/`, `stacks/`
- **应用数据**: `/opt/homelab/data`

### 保留策略

```
每日快照  ──── 保留 30 天
每周快照  ──── 保留 12 周
每月快照  ──── 保留 12 月
```

## 📁 目录结构

```
stacks/backup/
├── docker-compose.yml
├── .env.example
└── README.md

scripts/
├── backup.sh              # 主备份脚本
├── restore.sh             # 恢复脚本
├── pre-backup.sh          # Resticker 备份前钩子
└── post-backup.sh         # Resticker 备份后钩子

/opt/homelab-backups/       # 本地备份存储
├── restic/                 # Restic 仓库
│   └── (restic data)
├── duplicati/              # Duplicati 备份文件
│   └── (duplicati backups)
└── sql/                    # 数据库 SQL 导出
    ├── postgres/
    └── mariadb/
```

## 🛠️ 使用指南

### 手动执行备份

```bash
# 备份所有
./scripts/backup.sh --target all

# 仅备份媒体栈
./scripts/backup.sh --target media

# 仅备份数据库
./scripts/backup.sh --target databases

# 预览要备份的内容（不实际执行）
./scripts/backup.sh --target all --dry-run

# 列出所有备份
./scripts/backup.sh --list

# 验证备份完整性
./scripts/backup.sh --verify
```

### 恢复数据

```bash
# 交互式恢复
./scripts/restore.sh

# 指定备份ID恢复
./scripts/restore.sh --backup-id <snapshot_id>

# 仅恢复数据库
./scripts/restore.sh --target databases --backup-id <snapshot_id>

# 列出可用的备份快照
./scripts/restore.sh --list
```

### Restic 手动操作

```bash
# 进入 resticker 容器
docker compose -f stacks/backup/docker-compose.yml exec resticker sh

# 手动执行备份
restic backup /data --repo /repo

# 查看快照
restic snapshots --repo /repo

# 恢复文件
restic restore latest --repo /repo --target /restore

# 验证备份
restic check --repo /repo

# 清理旧快照
restic forget --repo /repo --keep-daily 30 --keep-weekly 12 --keep-monthly 12 --prune
```

### Rclone 手动同步

```bash
# 同步本地备份到云存储
docker run --rm \
  -v /opt/homelab-backups:/data:ro \
  -v $(pwd)/config/rclone:/config:ro \
  rclone/rclone:1.68.0 \
  sync /data backup:/homelab-backups \
  --config /config/rclone.conf \
  --progress \
  --drive-chunk-size 64M

# 查看同步状态
docker run --rm \
  -v $(pwd)/config/rclone:/config:ro \
  rclone/rclone:1.68.0 \
  lsjson backup: --config /config/rclone.conf
```

## 🔐 安全配置

### Duplicati 加密

Duplicati 默认使用 AES-256 加密备份数据：
1. 登录 Duplicati Web UI
2. 创建备份任务时设置加密密码
3. 建议使用与 `RESTIC_PASSWORD` 不同的密码

### Restic 仓库保护

```bash
# 设置只读权限
chmod 700 /opt/homelab-backups/restic

# 备份 rclone.conf（不含敏感信息）
# 或使用 rclone crypt
```

## 📊 监控与通知

### Ntfy 通知

备份完成后会向配置的 Ntfy 主题发送通知：

```bash
# 订阅通知
curl -N ntfy.sh/${NTFY_TOPIC:-homelab-backups}

# 或使用 ntfy CLI
ntfy subscribe ntfy.sh/homelab-backups
```

### Duplicati 内置通知

在 Duplicati Web UI 中配置：
- Email 通知
- Webhook 通知
- Ntfy 集成

## 🔄 定时备份

### Crontab 配置

```bash
# 编辑 crontab
crontab -e

# 添加备份任务（每天凌晨 2:00）
0 2 * * * /path/to/homelab-stack/scripts/backup.sh --target all >> /var/log/homelab-backup.log 2>&1

# Restic 同步到云存储（每天凌晨 3:00）
0 3 * * * /path/to/homelab-stack/scripts/rclone-sync.sh >> /var/log/homelab-rclone.log 2>&1
```

### Resticker Watchdog 模式

```bash
# 启用自动调度
echo "AUTO_RESTICKER=true" >> .env
docker compose -f stacks/backup/docker-compose.yml up -d resticker
```

## 🆘 灾难恢复

详见 [docs/disaster-recovery.md](../../docs/disaster-recovery.md)

### 快速恢复步骤

1. **重建基础设施**
   ```bash
   ./install.sh
   docker compose -f stacks/base/docker-compose.yml up -d
   ```

2. **恢复数据库**
   ```bash
   ./scripts/restore.sh --target databases --backup-id <latest>
   ```

3. **恢复应用数据**
   ```bash
   ./scripts/restore.sh --target all --backup-id <latest>
   ```

4. **验证完整性**
   ```bash
   ./scripts/backup.sh --verify
   ```

## ⚠️ 注意事项

1. **Restic 密码丢失 = 数据丢失**：请安全保管 `RESTIC_PASSWORD`
2. **云存储费用**：确保设置合理的生命周期策略
3. **网络带宽**：首次全量备份可能需要较长时间
4. **备份验证**：定期执行 `--verify` 验证备份完整性

## 📝 常见问题

### Q: 备份失败怎么办？
A: 检查日志 `docker compose -f stacks/backup/docker-compose.yml logs`

### Q: 如何增加备份频率？
A: 修改 `BACKUP_SCHEDULE`，如 `"0 */6 * * *"` 表示每 6 小时

### Q: Restic 仓库满了怎么办？
A: 使用 `restic check --read-data` 检查，然后 `restic prune` 清理孤立数据块

### Q: 如何迁移到新服务器？
A: 1. 在新服务器部署相同配置
   2. 复制 Restic 仓库到新服务器
   3. 恢复时指定新的 Restic 仓库路径
