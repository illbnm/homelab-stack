# Backup Stack

自动备份与灾难恢复方案，支持 3-2-1 备份策略。

## 服务架构

```
┌─────────────────────────────────────────────────────────┐
│                      Backup Stack                        │
├─────────────────────────────────────────────────────────┤
│                                                          │
│   Duplicati (加密云备份)                                 │
│   ├── Web UI 管理界面                                   │
│   ├── 加密备份到 S3/B2/R2/Local                        │
│   └── 自动调度备份任务                                  │
│                                                          │
│   Restic REST Server (本地备份仓库)                      │
│   ├── REST API 接口                                     │
│   ├── 增量备份支持                                     │
│   └── 追加模式（append-only）                          │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

## 快速开始

### 1. 配置环境变量

```env
BACKUP_TARGET=local  # local, s3, b2, sftp, r2
BACKUP_DIR=./backups
RETENTION_DAYS=7
RESTIC_PASSWORD=your_secure_password
NTFY_HOST=ntfy
DOMAIN=homelab.local
```

### 2. 启动备份服务

```bash
docker compose -f stacks/backup/docker-compose.yml up -d
```

### 3. 访问 Web UI

- **Duplicati**: https://duplicati.${DOMAIN}
- **Restic Server**: http://rest-server:8000

## 使用方法

### 备份命令

```bash
# 备份所有
./scripts/backup.sh --target all

# 备份媒体栈
./scripts/backup.sh --target media

# 备份数据库栈
./scripts/backup.sh --target databases

# 模拟运行（不实际备份）
./scripts/backup.sh --target all --dry-run
```

### 查看备份

```bash
./scripts/backup.sh --list
```

### 验证备份

```bash
./scripts/backup.sh --verify
```

### 恢复备份

```bash
# 查看可用备份
./scripts/backup.sh --list

# 恢复指定备份
./scripts/backup.sh --restore backup_20240101_020000
```

## 备份目标

### 本地存储 (默认)

```env
BACKUP_TARGET=local
BACKUP_DIR=./backups
```

### S3 / R2 / MinIO

```env
BACKUP_TARGET=s3
AWS_ACCESS_KEY_ID=your_key
AWS_SECRET_ACCESS_KEY=your_secret
S3_BUCKET=homelab-backups
S3_ENDPOINT=https://s3.example.com  # 可选，用于R2/MinIO
```

### Backblaze B2

```env
BACKUP_TARGET=b2
B2_KEY_ID=your_key_id
B2_KEY=your_key
B2_BUCKET=homelab-backups
```

### SFTP

```env
BACKUP_TARGET=sftp
SFTP_HOST=sftp.example.com
SFTP_USER=backup
SFTP_PASSWORD=your_password
SFTP_PATH=/backups
```

## 定时备份

### Crontab 方式

```bash
# 编辑 crontab
crontab -e

# 添加定时任务（每日凌晨2点）
0 2 * * * /path/to/homelab-stack/scripts/backup.sh --target all >> /var/log/backup.log 2>&1
```

### Systemd Timer 方式

```bash
# 创建 service
cat > ~/.config/systemd/user/backup.service << EOF
[Unit]
Description=Homelab Backup

[Service]
Type=oneshot
WorkingDirectory=/path/to/homelab-stack
ExecStart=/path/to/homelab-stack/scripts/backup.sh --target all

[Install]
WantedBy=default.target
EOF

# 创建 timer
cat > ~/.config/systemd/user/backup.timer << EOF
[Unit]
Description=Backup Timer

[Timer]
OnCalendar=*-*-02 00:00:00
Persistent=true

[Install]
WantedBy=default.target
EOF

# 启用 timer
systemctl --user enable backup.timer
systemctl --user start backup.timer
```

## 3-2-1 备份策略

遵循 3-2-1 原则：

- **3 份数据副本**
  - 原始数据
  - 本地备份
  - 远程备份

- **2 种不同介质**
  - Docker volumes（原始）
  - 本地文件系统（备份）
  - 云存储（异地）

- **1 份异地副本**
  - S3/R2/B2 云存储
  - SFTP 远程服务器

## 灾难恢复

详见 [docs/disaster-recovery.md](/docs/disaster-recovery.md)

快速恢复：

```bash
# 1. 克隆仓库到新系统
git clone https://github.com/illbnm/homelab-stack.git

# 2. 恢复环境配置
cp backups/latest/.env .env

# 3. 启动基础服务
docker compose -f docker-compose.base.yml up -d

# 4. 恢复数据库
./scripts/init-databases.sh
./scripts/backup.sh --restore backup_latest

# 5. 启动其他服务
docker compose -f stacks/databases/docker-compose.yml up -d
docker compose -f stacks/media/docker-compose.yml up -d
```

## 通知设置

备份结果会通过 ntfy 发送通知：

```env
NTFY_HOST=ntfy
NTFY_PORT=80
```

通知会发送到 `homelab-backups` topic。

## 环境变量

| 变量 | 默认值 | 说明 |
|------|--------|------|
| BACKUP_TARGET | local | 备份目标 |
| BACKUP_DIR | ./backups | 备份目录 |
| RETENTION_DAYS | 7 | 备份保留天数 |
| RESTIC_PASSWORD | - | Restic 密码 |
| NTFY_HOST | ntfy | ntfy 服务地址 |
| TZ | Asia/Shanghai | 时区 |

## 相关文档

- [Duplicati 文档](https://duplicati.readthedocs.io/)
- [Restic 文档](https://restic.readthedocs.io/)
- [Restic REST Server](https://github.com/restic/rest-server)
