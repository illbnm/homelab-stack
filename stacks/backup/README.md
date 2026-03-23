# Homelab Backup & DR — 备份与灾难恢复

[BOUNTY $150] 实现完整的 3-2-1 备份策略与灾难恢复方案

## 📋 功能概述

本 Stack 提供完整的备份与灾难恢复解决方案，实现 **3-2-1 备份策略**：
- **3** 份数据副本
- **2** 种不同介质
- **1** 份异地备份

## 🏗️ 架构设计

```
┌─────────────────────────────────────────────────────────┐
│                    Homelab Stack                        │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐ │
│  │  Duplicati  │    │ Restic      │    │   Backup    │ │
│  │  (云备份)   │    │ Server      │    │  Scheduler  │ │
│  │  8200       │    │  8000       │    │  (Cron)     │ │
│  └──────┬──────┘    └──────┬──────┘    └──────┬──────┘ │
│         │                  │                  │         │
│         └──────────────────┼──────────────────┘         │
│                            │                            │
│                   ┌────────▼────────┐                   │
│                   │   Backup        │                   │
│                   │   Scripts       │                   │
│                   └────────┬────────┘                   │
│                            │                            │
│         ┌──────────────────┼──────────────────┐         │
│         │                  │                  │         │
│    ┌────▼────┐      ┌─────▼─────┐     ┌─────▼─────┐    │
│    │  Local  │      │  S3/R2    │     │  Backblaze│    │
│    │  Backup │      │  Storage  │     │    B2     │    │
│    └─────────┘      └───────────┘     └───────────┘    │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

## 📦 服务清单

| 服务 | 镜像 | 端口 | 用途 |
|------|------|------|------|
| **restic-server** | `restic/rest-server:0.13.0` | 8000 | 本地备份仓库 |
| **duplicati** | `lscr.io/linuxserver/duplicati:2.0.8` | 8200 | 加密云备份管理 |
| **backup-scheduler** | `alpine:3.19.1` | - | 定时备份调度器 |

## 🚀 快速开始

### 1. 克隆仓库

```bash
cd /path/to/homelab-stack
git clone https://github.com/zhuzhushiwojia/homelab-backup.git stacks/backup
cd stacks/backup
```

### 2. 配置环境变量

```bash
cp .env.example .env
nano .env
```

**必须配置**:
```bash
DOMAIN=your-domain.com
RESTIC_PASSWORD=your-secure-password  # 至少 16 位
BACKUP_TARGET=local  # 或 restic/s3/b2/sftp
```

### 3. 启动服务

```bash
docker compose up -d
```

### 4. 验证服务

```bash
docker compose ps
curl http://localhost:8000/  # Restic Server
curl http://localhost:8200/  # Duplicati
```

## 🔧 备份脚本使用

### 基本用法

```bash
# 备份所有内容
./scripts/backup.sh --target all

# 仅备份媒体栈
./scripts/backup.sh --target media

# 预览备份 (不实际执行)
./scripts/backup.sh --target all --dry-run

# 列出所有备份
./scripts/backup.sh --list

# 验证备份完整性
./scripts/backup.sh --verify

# 从备份恢复
./scripts/backup.sh --restore 2026-03-24_020000
```

### 备份目标选项

| 选项 | 说明 |
|------|------|
| `all` | 备份所有 stack 数据卷 |
| `media` | 仅备份媒体栈 (Jellyfin/Immich) |
| `base` | 仅备份基础栈 (网络/存储) |
| `db` | 仅备份数据库栈 (PostgreSQL/MySQL) |
| `sso` | 仅备份 SSO 栈 (Authentik) |
| `ai` | 仅备份 AI 栈 (Ollama/Open WebUI) |
| `notifications` | 仅备份通知栈 (ntfy/Gotify) |

### 备份类型配置

通过 `.env` 中的 `BACKUP_TARGET` 设置:

| 类型 | 说明 | 适用场景 |
|------|------|----------|
| `local` | 本地目录备份 | 快速备份，本地恢复 |
| `restic` | Restic 加密备份 | 去重压缩，节省空间 |
| `s3` | AWS S3 兼容存储 | 云端备份，异地容灾 |
| `b2` | Backblaze B2 | 低成本云存储 |
| `sftp` | SFTP 服务器 | 自有服务器备份 |
| `r2` | Cloudflare R2 | 零出口费用云存储 |

## 📅 定时备份

### 方式 1: Docker 内置调度器 (默认)

`backup-scheduler` 容器每天 2:00 AM 自动执行备份。

### 方式 2: 系统 Crontab

```bash
# 编辑 crontab
crontab -e

# 添加定时任务 (每天 2:00 AM)
0 2 * * * /path/to/homelab-stack/stacks/backup/scripts/backup.sh --target all >> /var/log/homelab-backup.log 2>&1
```

### 方式 3: Systemd Timer

创建 `/etc/systemd/system/homelab-backup.timer`:

```ini
[Unit]
Description=Homelab Backup Timer

[Timer]
OnCalendar=*-*-* 02:00:00
Persistent=true

[Install]
WantedBy=timers.target
```

创建 `/etc/systemd/system/homelab-backup.service`:

```ini
[Unit]
Description=Homelab Backup Service
After=docker.service

[Service]
Type=oneshot
ExecStart=/path/to/homelab-stack/stacks/backup/scripts/backup.sh --target all
```

启用定时器:

```bash
sudo systemctl enable --now homelab-backup.timer
```

## 🔔 通知集成

备份完成/失败后自动发送通知到 ntfy:

```bash
# 配置 .env
NOTIFICATION_TOPIC=backup
NOTIFICATION_SERVER=ntfy:8080

# 订阅通知 (手机/桌面)
ntfy sub backup
```

## 📊 监控与日志

### 查看备份日志

```bash
# 实时日志
docker compose logs -f backup-scheduler

# 查看备份历史
cat /backups/backup.log
```

### 备份统计

```bash
# 查看备份大小
du -sh /backups/*

# 查看备份数量
find /backups -name "checksums.md5" | wc -l
```

## 🔐 安全配置

### 1. 访问控制

所有 Web UI 均通过 Traefik 反向代理保护:

```bash
# 生成 htpasswd 密码
htpasswd -nb admin your-password

# 配置 .env
RESTIC_AUTH_USERS=admin:$$apr1$$xxx$$xxx
DUPLICATI_AUTH_USERS=admin:$$apr1$$xxx$$xxx
```

### 2. 加密配置

- Restic: AES-256 加密 (通过 `RESTIC_PASSWORD`)
- Duplicati: AES-256 加密 (Web UI 配置)
- 传输加密: HTTPS (Traefik Let's Encrypt)

### 3. 网络隔离

所有备份服务运行在内部网络 `backup_internal`，不直接暴露到公网。

## 📁 目录结构

```
stacks/backup/
├── docker-compose.yml      # Docker 配置
├── .env.example            # 环境变量模板
├── README.md               # 本文档
├── docs/
│   └── disaster-recovery.md  # 灾难恢复指南
├── scripts/
│   ├── backup.sh           # 备份脚本
│   └── restore.sh          # 恢复脚本
├── config/
│   └── restic-auth         # Restic 认证配置
└── tests/
    └── backup.test.sh      # 集成测试
```

## ✅ 验收标准

- [x] `backup.sh` 脚本支持所有目标类型
- [x] 本地备份功能正常
- [x] Restic 备份功能正常
- [x] 定时备份配置完成
- [x] 通知集成正常
- [x] 灾难恢复文档完整
- [x] 集成测试通过
- [x] 无硬编码密码/密钥
- [x] 镜像锁定具体版本
- [x] YAML 语法验证通过

## 🧪 测试

运行集成测试:

```bash
./tests/backup.test.sh
```

测试内容:
- 服务健康检查
- 备份脚本执行
- 备份完整性验证
- 恢复流程测试

## 🆘 故障排除

### 问题 1: Restic 认证失败

```bash
# 检查认证文件
cat config/restic-auth

# 重新生成密码
htpasswd -nb user password > config/restic-auth
docker compose restart restic-server
```

### 问题 2: 备份空间不足

```bash
# 查看空间使用
df -h /backups

# 清理旧备份
./scripts/backup.sh --cleanup --retention 7
```

### 问题 3: 通知未发送

```bash
# 检查 ntfy 服务
docker compose ps ntfy

# 测试通知
curl -X POST http://ntfy:8080/backup -d "Test message"
```

## 📚 相关文档

- [灾难恢复指南](docs/disaster-recovery.md)
- [Restic 官方文档](https://restic.readthedocs.io/)
- [Duplicati 官方文档](https://www.duplicati.com/)

## 💰 收款信息

**USDT TRC20**: `TMLkvEDrjvHEUbWYU1jfqyUKmbLNZkx6T1`

## 🔗 相关链接

- Issue: [#12](https://github.com/illbnm/homelab-stack/issues/12)
- PR: [待提交](https://github.com/illbnm/homelab-stack/pulls)

---

*版本：1.0.0 | 最后更新：2026-03-24*
