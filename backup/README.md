# 🗂️ 3-2-1 Backup System

基于 3-2-1 备份策略的自动化备份解决方案。

## 📋 策略说明

**3-2-1 原则：**
- 📦 **3 份数据副本** - 原始数据 + 2 份备份
- 💾 **2 种不同介质** - 本地存储 + 云端存储
- ☁️ **1 份异地副本** - 云端（不同区域）

## 🚀 快速开始

### 1. 配置环境

```bash
# 复制配置模板
cp .env.example .env

# 编辑配置
nano .env
```

### 2. 必填配置

```env
# 备份源目录
BACKUP_SOURCE=/path/to/your/data

# 加密密码（必须设置！）
RESTIC_PASSWORD=your_secure_password_min_20_chars

# 选择云存储之一：
# 方案 A: S3 兼容存储
S3_BUCKET=your-bucket
AWS_ACCESS_KEY_ID=xxx
AWS_SECRET_ACCESS_KEY=xxx
S3_ENDPOINT=https://s3.amazonaws.com

# 方案 B: Backblaze B2
B2_ACCOUNT_ID=xxx
B2_ACCOUNT_KEY=xxx
B2_BUCKET=your-bucket

# 方案 C: Cloudflare R2
R2_ACCOUNT_ID=xxx
R2_ACCESS_KEY_ID=xxx
R2_SECRET_ACCESS_KEY=xxx
R2_BUCKET=your-bucket
R2_ENDPOINT=https://xxx.r2.cloudflarestorage.com
```

### 3. 启动备份

```bash
# 启动容器
docker-compose up -d

# 执行首次备份
docker exec backup-restic /scripts/backup.sh init
docker exec backup-restic /scripts/backup.sh backup
```

## 🔄 备份计划

| 类型 | 时间 | 说明 |
|------|------|------|
| 增量备份 | 每日 02:00 | 只备份变更内容 |
| 全量备份 | 每周日 03:00 | 完整备份 |

## 📊 常用命令

```bash
# 查看快照
docker exec backup-restic restic -r /backups/local snapshots

# 恢复最新备份
docker exec backup-restic /scripts/backup.sh restore /backups/local ./restore

# 手动触发备份
docker exec backup-restic /scripts/backup.sh backup
```

## 🧪 验证备份

```bash
# 检查本地仓库
docker exec backup-restic restic -r /backups/local check

# 检查云端仓库
docker exec backup-restic restic -r s3:xxx/xxx check --password-env RESTIC_PASSWORD
```

## 🔐 安全建议

1. **使用强密码** - 至少 20 位随机字符
2. **使用密钥管理器** - 存储 `RESTIC_PASSWORD`
3. **启用传输加密** - S3/R2 使用 HTTPS
4. **限制访问权限** - 使用 IAM 策略

## 📁 项目结构

```
backup/
├── docker-compose.yml    # 容器编排
├── .env.example          # 配置模板
├── .env                  # 实际配置 (不提交)
├── README.md             # 使用文档
├── RECOVERY.md           # 灾难恢复指南
├── scripts/
│   ├── backup.sh         # 备份脚本
│   └── schedule.sh       # 定时任务
└── data/                 # 挂载的源数据 (可选)
```

## ☁️ 支持的云存储

- ✅ AWS S3
- ✅ Cloudflare R2
- ✅ Backblaze B2
- ✅ MinIO
- ✅ 任何 S3 兼容存储

## 📈 监控

设置 webhook 通知：

```env
WEBHOOK_URL=https://your-webhook.com/notify
```

## 🔧 维护

```bash
# 清理旧快照
docker exec backup-restic restic -r /backups/local forget --prune --keep-daily 7

# 重新打包仓库
docker exec backup-restic restic -r /backups/local rebuild-index
```