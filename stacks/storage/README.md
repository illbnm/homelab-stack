# 💾 Storage Stack - 存储服务栈

完整的自托管存储解决方案，包含 Nextcloud 云盘、MinIO 对象存储、FileBrowser 文件管理器和 Syncthing 同步工具。

## 📋 服务概览

| 服务 | 域名 | 功能 |
|------|------|------|
| **Nextcloud** | nextcloud.yourdomain.com | 个人云盘，支持文件同步、分享、协作 |
| **MinIO Console** | minio.yourdomain.com | MinIO 管理控制台 |
| **MinIO API** | s3.yourdomain.com | S3 兼容对象存储 API |
| **FileBrowser** | files.yourdomain.com | 轻量级 Web 文件管理器 |
| **Syncthing** | syncthing.yourdomain.com | P2P 文件同步工具 |

### 共享基础设施

| 服务 | 功能 |
|------|------|
| **PostgreSQL** | 共享数据库 (Nextcloud 元数据) |
| **Redis** | 共享缓存 (Nextcloud 文件锁/缓存) |

## 🚀 快速开始

### 前提条件

1. 已部署 Base Infrastructure (Traefik)
2. 已部署 Databases Stack (PostgreSQL + Redis)

### 1. 克隆仓库

```bash
git clone https://github.com/illbnm/homelab-stack.git
cd homelab-stack/stacks/storage
```

### 2. 配置环境变量

```bash
# 复制示例配置
cp .env.example .env

# 编辑配置
nano .env
```

**必须修改的配置：**
- `DOMAIN` - 你的主域名
- `NEXTCLOUD_DOMAIN` - Nextcloud 访问域名
- `NEXTCLOUD_ADMIN_PASSWORD` - Nextcloud 管理员密码（使用强密码！）
- `MINIO_ROOT_PASSWORD` - MinIO 访问密码（使用强密码！）
- `POSTGRES_PASSWORD` - PostgreSQL 密码（必须与 databases stack 一致）
- `REDIS_PASSWORD` - Redis 密码（必须与 databases stack 一致）
- `STORAGE_PATH` - 共享存储目录路径

### 3. 创建目录结构

```bash
# 创建共享存储目录
mkdir -p /data/storage/minio
mkdir -p /data/storage/syncthing

# 设置权限
sudo chown -R 1000:1000 /data/storage
```

### 4. 启动服务

```bash
# 启动所有服务
docker compose up -d

# 查看状态
docker compose ps

# 查看日志
docker compose logs -f
```

### 5. 访问服务

启动成功后，通过以下地址访问：

- **Nextcloud**: `https://nextcloud.yourdomain.com`
- **MinIO Console**: `https://minio.yourdomain.com`
- **MinIO API**: `https://s3.yourdomain.com`
- **FileBrowser**: `https://files.yourdomain.com`
- **Syncthing**: `https://syncthing.yourdomain.com`

## 📁 目录结构

```
/data/storage/
├── minio/              # MinIO 数据
├── syncthing/          # Syncthing 同步目录
└── nextcloud/          # Nextcloud 外部存储挂载点

./config/nginx/         # Nginx 配置
├── nginx.conf         # 主配置文件
└── upstream.conf      # Upstream 配置
```

## 🔧 服务配置指南

### 1. Nextcloud 配置

#### 首次访问
1. 访问 `https://nextcloud.yourdomain.com`
2. 使用 `.env` 中配置的管理员账号登录
3. 完成初始化设置

#### 推荐应用
- **Deck** - 看板任务管理
- **Calendar** - 日历
- **Contacts** - 联系人
- **Talk** - 视频会议

#### 配置 MinIO 为外部存储
1. 登录 Nextcloud 管理员界面
2. 应用商店安装 **External storage support**
3. 管理 → 外部存储
4. 添加存储：
   - 名称：MinIO Object Storage
   - 类型：Amazon S3
   - 认证：Access Key / Secret Key
   - Bucket：nextcloud
   - 主机：s3.yourdomain.com
   - 端口：443
   - 启用 SSL
   - 启用 Path style

### 2. MinIO 配置

#### 访问 Console
1. 访问 `https://minio.yourdomain.com`
2. 使用 `MINIO_ROOT_USER` 和 `MINIO_ROOT_PASSWORD` 登录

#### 默认 Bucket
初始化脚本已自动创建以下 bucket：
- `nextcloud` - Nextcloud 外部存储
- `backups` - 备份存储（公开读取）
- `filebrowser` - FileBrowser 存储

#### 使用 mc 客户端连接
```bash
# 安装 mc
wget https://dl.min.io/client/mc/release/linux-amd64/mc
chmod +x mc
sudo mv mc /usr/local/bin/

# 配置别名
mc alias set myminio https://s3.yourdomain.com $MINIO_ROOT_USER $MINIO_ROOT_PASSWORD

# 列出 bucket
mc ls myminio

# 上传文件
mc cp file.txt myminio/backups/
```

### 3. FileBrowser 配置

#### 首次访问
1. 访问 `https://files.yourdomain.com`
2. 默认用户名：`admin`
3. 默认密码：`admin`
4. **立即修改密码！**

#### 功能特性
- 浏览 `/srv` 目录（映射到 `STORAGE_PATH`）
- 上传/下载文件
- 创建/编辑文件
- 分享文件链接
- 多用户管理

### 4. Syncthing 配置

#### 首次访问
1. 访问 `https://syncthing.yourdomain.com`
2. 创建管理员账户
3. 获取设备 ID（用于配对）

#### 添加远程设备
1. 在另一台设备安装 Syncthing
2. 交换设备 ID
3. 添加共享文件夹
4. 设置同步目录：`/data/syncthing`

## 🔍 健康检查

```bash
# 检查所有服务状态
docker compose ps

# 预期输出：所有服务显示 (healthy)
NAME                STATUS
nextcloud-fpm       Up (healthy)
nextcloud-nginx     Up (healthy)
minio               Up (healthy)
minio-init          Exited (0)
filebrowser         Up (healthy)
syncthing           Up (healthy)

# 测试 Nextcloud 连接
curl -k https://nextcloud.yourdomain.com/status.php

# 测试 MinIO API
curl -k https://s3.yourdomain.com/minio/health/live
```

## ❓ 常见问题

### Q1: Nextcloud 无法连接数据库

**解决方案：**
```bash
# 检查 databases stack 是否运行
docker compose -f docker-compose.base.yml ps

# 检查 PostgreSQL 连接
docker exec nextcloud-fpm pg_isready -h homelab-postgres -U nextcloud
```

### Q2: MinIO Console 无法访问

**检查清单：**
1. 确认域名 DNS 解析正确
2. 检查 Traefik 证书状态
3. 确认 MinIO 服务健康

```bash
# 查看 Traefik 日志
docker compose logs traefik

# 查看 MinIO 日志
docker compose logs minio
```

### Q3: FileBrowser 无法写入文件

**解决方案：**
```bash
# 修复权限
sudo chown -R 1000:1000 /data/storage

# 重启服务
docker compose restart filebrowser
```

## 🛡️ 安全建议

1. **修改默认密码** - 所有服务使用强密码
2. **启用 HTTPS** - Traefik 自动配置 Let's Encrypt
3. **添加 Authentik SSO** - 统一管理认证
4. **配置防火墙** - 仅开放必要端口
5. **定期更新** - 保持镜像最新版本
6. **启用 2FA** - Nextcloud 管理员启用双因素认证

```bash
# 更新所有服务
docker compose pull
docker compose up -d
```

## 📊 资源占用参考

| 服务 | CPU | 内存 | 磁盘 |
|------|-----|------|------|
| Nextcloud (FPM+Nginx) | 低 | 500MB | 取决于文件 |
| MinIO | 低 | 300MB | 取决于对象 |
| FileBrowser | 极低 | 50MB | <50MB |
| Syncthing | 中 | 200MB | 取决于同步 |

**总计：** ~1GB 内存，低 CPU 占用

## 📝 环境变量说明

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `DOMAIN` | - | 主域名 |
| `NEXTCLOUD_DOMAIN` | nextcloud.${DOMAIN} | Nextcloud 域名 |
| `NEXTCLOUD_ADMIN_USER` | admin | Nextcloud 管理员 |
| `NEXTCLOUD_ADMIN_PASSWORD` | - | Nextcloud 密码 |
| `MINIO_ROOT_USER` | minioadmin | MinIO 访问密钥 |
| `MINIO_ROOT_PASSWORD` | - | MinIO 密码 |
| `STORAGE_PATH` | /data/storage | 共享存储目录 |
| `POSTGRES_PASSWORD` | - | PostgreSQL 密码 |
| `REDIS_PASSWORD` | - | Redis 密码 |

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

## 📄 许可证

MIT License
