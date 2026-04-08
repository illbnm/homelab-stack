# Storage Stack - 存储服务栈

完整的存储解决方案，包括网络文件系统、同步工具和对象存储。

## 🚀 服务列表

| 服务 | 端口 | 功能 | 访问地址 |
|------|------|------|----------|
| **NFS Server** | 2049 | 网络文件系统 | 内部服务 |
| **Syncthing** | 8384 | 文件同步 | https://syncthing.${DOMAIN} |
| **MinIO** | 9000/9001 | 对象存储 | https://minio.${DOMAIN} |

## 📋 前置要求

1. **Traefik** 运行正常（见 `stacks/base/`）
2. **域名 DNS** 已解析到服务器 IP
3. **存储目录** 已创建并配置权限

## 🔧 目录结构

```bash
/data/
├── nfs/       # NFS 共享目录
├── sync/      # Syncthing 同步目录
└── minio/     # MinIO 对象存储
```

**创建目录**：
```bash
sudo mkdir -p /data/{nfs,sync,minio}
sudo chown -R 1000:1000 /data
```

## 🚀 快速开始

### 1. 配置环境变量
```bash
cp .env.example .env
```

编辑 `.env`，设置：
- `DOMAIN` - 你的域名
- `MINIO_ROOT_PASSWORD` - MinIO 管理员密码（强密码）

### 2. 创建目录
```bash
sudo mkdir -p /data/{nfs,sync,minio}
sudo chown -R ${PUID:-1000}:${PGID:-1000} /data
```

### 3. 启动服务
```bash
docker compose up -d
```

### 4. 检查服务状态
```bash
docker compose ps
```

## 📊 服务配置详解

### NFS Server

**特点**：
- 高性能网络文件系统
- 适用于 Docker volumes
- 支持多客户端并发

**挂载 NFS 到其他容器**：
```yaml
volumes:
  - nfs-data:/data
  # 或使用 nfs driver
  nfs-share:
    driver: local
    driver_opts:
      type: nfs
      o: addr=192.168.1.100,nolock,soft,rw
      device: ":/data/nfs"
```

### Syncthing

**特点**：
- P2P 文件同步
- 跨平台支持
- Web UI 管理

**首次配置**：
1. 访问 https://syncthing.${DOMAIN}
2. 完成初始设置向导
3. **添加同步文件夹**：
   - Add Folder
   - Folder Path: `/data/sync`
   - Folder Label: Sync
4. **分享设备 ID**：
   - Actions → Show ID
   - 在其他设备上添加此 ID
5. **接受连接**：
   - 在其他设备上请求连接
   - 在此设备上批准

**配置同步**：
- 选择同步模式（Send & Receive / Send Only / Receive Only）
- 配置文件类型（Ignore/Delete/Keep）
- 设置同步间隔

### MinIO
**特点**：
- S3 兼容对象存储
- Web Console 管理
- 支持 bucket 策略

**首次配置**：
1. 访问 https://minio-console.${DOMAIN}
2. 登录（用户名: `minioadmin`，密码: `MINIO_ROOT_PASSWORD`）
3. **创建 Bucket**：
   - Buckets → Create Bucket
   - Bucket Name: `my-bucket`
   - Access Policy: `Private` 或 `Public`
4. **创建 Access Key**：
   - Access Keys → Create Access Key
   - 生成 Access Key 和 Secret Key
   - 下载并保存（仅显示一次）

**S3 API 访问**：
```bash
# 配置 AWS CLI
aws configure --profile minio
  # AWS Access Key ID: <access-key>
  # AWS Secret Access Key: <secret-key>
  # Default region name: us-east-1
  # Default output format: json

# 使用 S3 API
aws --endpoint-url https://minio.${DOMAIN} s3 ls
aws --endpoint-url https://minio.${DOMAIN} s3 mb my-bucket
aws --endpoint-url https://minio.${DOMAIN} s3 cp file.txt s3://my-bucket/
```

## 🔒 安全配置

### 1. 访问控制

**NFS**:
```bash
# 限制 NFS 访问范围
# 编辑 /etc/exports
/data/nfs 192.168.1.0/24(rw,sync,no_subtree_check)
```

**Syncthing**:
- Settings → GUI → Authentication
- 设置用户名和密码

**MinIO**:
- 使用强密码（`MINIO_ROOT_PASSWORD`）
- 定期轮换 Access Keys
- 配置 bucket 策略（IAM）

### 2. 备份

**NFS**:
```bash
# 备份 NFS 数据
rsync -av /data/nfs/ /backup/nfs/
```

**Syncthing**:
- 配置版本控制（File Versioning）
- 启用 Staggered Versioning

**MinIO**:
```bash
# 备份 MinIO bucket
mc mirror myminio/my-bucket /backup/minio/my-bucket/
```

## 🛠️ 故障排查

### NFS 挂载失败

```bash
# 检查 NFS 服务
docker logs nfs-server

# 常见问题：
# 1. 权限错误 → chown -R 1000:1000 /data/nfs
# 2. 网络不通 → 检查防火墙
# 3. exports 配置错误 → 编辑 /etc/exports
```

### Syncthing 无法连接

```bash
# 检查 Syncthing 日志
docker logs syncthing

# 常见问题：
# 1. 设备 ID 错误 → 重新分享
# 2. 端口未开放 → 检查防火墙（22000/TCP, 21027/UDP）
# 3. 文件权限错误 → chown -R 1000:1000 /data/sync
```

### MinIO 无法访问

```bash
# 检查 MinIO 日志
docker logs storage-minio

# 常见问题：
# 1. 密码错误 → 检查 .env
# 2. 域名未解析 → 检查 DNS
# 3. 证书未签发 → 检查 Traefik logs
```

## 📚 相关文档

- [NFS Server 文档](https://github.com/estrelark/nfs-server)
- [Syncthing 文档](https://docs.syncthing.net/)
- [MinIO 文档](https://min.io/docs/minio/linux/)

## 🔄 更新

```bash
# 拉取最新镜像
docker compose pull

# 重新创建容器
docker compose up -d

# 清理旧镜像
docker image prune -f
```

## 🗑️ 卸载

```bash
# 停止并删除容器
docker compose down

# 删除数据卷（⚠️ 不可恢复）
docker compose down -v

# 删除镜像
docker rmi $(docker images 'estrelark/*' 'syncthing/*' 'minio/*' -q)
```

## 📝 许可证

- NFS Server: Apache-2.0
- Syncthing: MPL-2.0
- MinIO: AGPL-3.0
