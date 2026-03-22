# 🎬 Media Stack - 媒体服务栈

完整的自动化媒体管理解决方案，包含 Jellyfin、Sonarr、Radarr、Prowlarr、qBittorrent 和 Jellyseerr。

## 📋 服务概览

| 服务 | 端口 | 功能 |
|------|------|------|
| **Jellyfin** | 8096 | 媒体服务器，播放电影和剧集 |
| **Sonarr** | 8989 | 自动追剧管理 |
| **Radarr** | 7878 | 自动电影管理 |
| **Prowlarr** | 9696 | 索引器管理，同步到 Sonarr/Radarr |
| **qBittorrent** | 8080 | BT 下载器 |
| **Jellyseerr** | 5055 | 媒体请求管理界面 |

## 🚀 快速开始

### 1. 克隆仓库

```bash
git clone https://github.com/illbnm/homelab-stack.git
cd homelab-stack/stacks/media
```

### 2. 配置环境变量

```bash
# 复制示例配置
cp .env.example .env

# 编辑配置
nano .env
```

**必须修改的配置：**
- `DOMAIN` - 你的域名
- `QB_PASSWORD` - qBittorrent 密码
- `JELLYFIN_PASSWORD` - Jellyfin 密码
- `MEDIA_ROOT` - 媒体库路径
- `DOWNLOADS_ROOT` - 下载目录路径

### 3. 创建目录结构

```bash
# 创建必要的目录
mkdir -p /data/media/movies
mkdir -p /data/media/tv
mkdir -p /data/downloads/movies
mkdir -p /data/downloads/tv
mkdir -p ./config
mkdir -p ./cache

# 设置权限 (如果使用非 root 用户)
sudo chown -R 1000:1000 /data/media
sudo chown -R 1000:1000 /data/downloads
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

启动成功后，通过以下地址访问（需配置 Traefik）：

- Jellyfin: `https://jellyfin.yourdomain.com`
- Sonarr: `https://sonarr.yourdomain.com`
- Radarr: `https://radarr.yourdomain.com`
- Prowlarr: `https://prowlarr.yourdomain.com`
- qBittorrent: `https://qbittorrent.yourdomain.com`
- Jellyseerr: `https://jellyseerr.yourdomain.com`

**无域名本地访问：**
```bash
# 使用 localhost + 端口
http://localhost:8096  # Jellyfin
http://localhost:8989  # Sonarr
http://localhost:7878  # Radarr
http://localhost:9696  # Prowlarr
http://localhost:8080  # qBittorrent
http://localhost:5055  # Jellyseerr
```

## 📁 目录结构

```
/data/
├── downloads/          # qBittorrent 下载目录
│   ├── movies/        # 电影下载 (临时)
│   └── tv/            # 剧集下载 (临时)
└── media/             # Jellyfin 媒体库
    ├── movies/        # 电影库 (硬链接)
    └── tv/            # 剧集库 (硬链接)

./config/              # 各服务配置文件
├── qbittorrent/
├── prowlarr/
├── sonarr/
├── radarr/
├── jellyseerr/
└── jellyfin/

./cache/               # Jellyfin 转码缓存
└── jellyfin/
```

### 硬链接工作原理

```
下载完成 → /data/downloads/movies/movie.mp4
    ↓ (硬链接，不复制数据)
媒体库 → /data/media/movies/movie.mp4
```

**优势：**
- ✅ 不占用额外磁盘空间
- ✅ 移动文件瞬间完成
- ✅ 删除种子不影响媒体库

## 🔧 服务配置指南

### 1. qBittorrent 配置

1. 访问 `http://localhost:8080`
2. 使用 `.env` 中的用户名密码登录
3. **设置下载路径：**
   - 默认保存位置：`/data/downloads`
   - 完成后复制：关闭
   - 保持种子：是

### 2. Prowlarr 配置

1. 访问 `http://localhost:9696`
2. **添加索引器：**
   - Settings → Indexers → Add Indexer
   - 搜索并添加喜欢的 PT/BT 站点
   - 配置 API Key 等认证信息
3. **同步到 Sonarr/Radarr：**
   - Settings → Apps → Add App
   - 添加 Sonarr (URL: `http://sonarr:8989`)
   - 添加 Radarr (URL: `http://radarr:7878`)
   - 勾选 "Sync Prowlarr Indexers"

### 3. Sonarr 配置（追剧）

1. 访问 `http://localhost:8989`
2. **连接 Prowlarr：**
   - Settings → Download Clients → Add → Prowlarr
   - Host: `prowlarr`
   - Port: `9696`
   - API Key: 从 Prowlarr 获取 (Settings → General)
3. **连接 qBittorrent：**
   - Settings → Download Clients → Add → qBittorrent
   - Host: `qbittorrent`
   - Port: `8080`
   - 用户名/密码：从 `.env` 获取
   - 分类：`tv`
   - 目录：`/data/downloads/tv`
4. **添加剧集：**
   - Series → Add New
   - 搜索剧集 → 选择质量配置
   - 根文件夹：`/data/media/tv`
5. **设置自动搜索：**
   - Settings → General → Automatic Search → 启用

### 4. Radarr 配置（电影）

1. 访问 `http://localhost:7878`
2. **连接 Prowlarr：**
   - Settings → Download Clients → Add → Prowlarr
   - Host: `prowlarr`
   - Port: `9696`
3. **连接 qBittorrent：**
   - Settings → Download Clients → Add → qBittorrent
   - Host: `qbittorrent`
   - Port: `8080`
   - 分类：`movies`
   - 目录：`/data/downloads/movies`
4. **添加电影：**
   - Movies → Add Movie
   - 搜索电影 → 选择质量配置
   - 根文件夹：`/data/media/movies`
5. **设置自动搜索：**
   - Settings → General → Automatic Search → 启用

### 5. Jellyfin 配置

1. 访问 `http://localhost:8096`
2. **初始设置：**
   - 创建管理员账户
   - 设置语言为中文
3. **添加媒体库：**
   - 控制台 → 媒体库 → 添加媒体库
   - 内容类型：电影
   - 文件夹：`/data/media/movies`
   - 再次添加媒体库
   - 内容类型：剧集
   - 文件夹：`/data/media/tv`
4. **配置元数据：**
   - 控制台 → 元数据 → 启用 TheMovieDb
   - 启用 TheTVDb（剧集）

### 6. Jellyseerr 配置

1. 访问 `http://localhost:5055`
2. **初始化：**
   - 创建管理员账户
   - 连接 Jellyfin (URL: `http://jellyfin:8096`)
   - 连接 Sonarr (URL: `http://sonarr:8989`)
   - 连接 Radarr (URL: `http://radarr:7878`)
3. **配置服务：**
   - 设置默认质量配置
   - 启用自动批准（可选）

## 🔄 自动化工作流程

```
用户请求 (Jellyseerr)
    ↓
自动搜索 (Sonarr/Radarr)
    ↓
索引查询 (Prowlarr)
    ↓
下载种子 (qBittorrent)
    ↓
下载完成 → 硬链接到媒体库
    ↓
Jellyfin 自动扫描 → 可播放
```

## 🔍 健康检查

```bash
# 检查所有服务状态
docker compose ps

# 预期输出：所有服务显示 (healthy)
NAME            STATUS
jellyfin        Up (healthy)
sonarr          Up (healthy)
radarr          Up (healthy)
prowlarr        Up (healthy)
qbittorrent     Up (healthy)
jellyseerr      Up (healthy)

# 查看特定服务日志
docker compose logs jellyfin
docker compose logs sonarr
```

## ❓ 常见问题 (FAQ)

### Q1: 服务启动失败，显示 "permission denied"

**解决方案：**
```bash
# 检查目录权限
ls -la /data/media
ls -la /data/downloads

# 修复权限
sudo chown -R 1000:1000 /data/media
sudo chown -R 1000:1000 /data/downloads

# 或修改 .env 中的 PUID/PGID
PUID=$(id -u)
PGID=$(id -g)
```

### Q2: Sonarr/Radarr 无法连接 qBittorrent

**检查清单：**
1. 确认 qBittorrent 已启动并健康
2. 检查用户名密码是否正确
3. 确认网络可达（同一 Docker 网络）
4. 在 qBittorrent 中启用 Web UI 认证

**测试连接：**
```bash
# 从 Sonarr 容器测试
docker exec sonarr curl http://qbittorrent:8080
```

### Q3: 下载完成但媒体库没有更新

**可能原因：**
1. 硬链接失败（不同文件系统）
2. 目录路径配置错误
3. 权限问题

**解决方案：**
```bash
# 检查下载目录和媒体目录是否在同一分区
df /data/downloads
df /data/media

# 检查 Sonarr/Radarr 的下载客户端配置
# 确保 "Complete Download Folder" 正确设置
```

### Q4: Jellyfin 无法扫描到媒体

**解决方案：**
1. 检查媒体目录挂载：`docker exec jellyfin ls /data/media`
2. 手动触发库扫描：Jellyfin 控制台 → 媒体库 → 扫描
3. 检查文件命名是否符合规范：
   - 电影：`/data/media/movies/电影名 (年份)/电影名.mp4`
   - 剧集：`/data/media/tv/剧名/Season 01/剧名 S01E01.mp4`

### Q5: Traefik 证书申请失败

**检查清单：**
1. 域名 DNS 解析正确指向服务器 IP
2. 80/443 端口开放
3. Let's Encrypt 邮箱配置正确
4. 查看 Traefik 日志：`docker compose logs traefik`

### Q6: 如何重置服务配置

```bash
# 停止服务
docker compose down

# 删除配置（谨慎操作！）
rm -rf ./config/*

# 重新启动
docker compose up -d
```

## 🛡️ 安全建议

1. **修改默认密码** - 所有服务使用强密码
2. **启用 HTTPS** - 配置 Traefik + Let's Encrypt
3. **添加认证** - 使用 Authentik 保护服务
4. **防火墙配置** - 仅开放必要端口
5. **定期更新** - 保持镜像最新版本

```bash
# 更新所有服务
docker compose pull
docker compose up -d
```

## 📊 资源占用参考

| 服务 | CPU | 内存 | 磁盘 |
|------|-----|------|------|
| Jellyfin | 低 | 500MB | 取决于库大小 |
| Sonarr | 极低 | 200MB | <100MB |
| Radarr | 极低 | 200MB | <100MB |
| Prowlarr | 极低 | 150MB | <50MB |
| qBittorrent | 中 | 300MB | 取决于下载 |
| Jellyseerr | 低 | 200MB | <100MB |

**总计：** ~1.5GB 内存，低 CPU 占用

## 📝 环境变量说明

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `PUID` | 1000 | 运行用户 ID |
| `PGID` | 1000 | 运行组 ID |
| `TZ` | Asia/Shanghai | 时区 |
| `DOMAIN` | - | 你的域名 |
| `CONFIG_ROOT` | ./config | 配置目录 |
| `CACHE_ROOT` | ./cache | 缓存目录 |
| `MEDIA_ROOT` | /data/media | 媒体库根目录 |
| `DOWNLOADS_ROOT` | /data/downloads | 下载根目录 |

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

## 📄 许可证

MIT License

---

**开发者备注：**
- 本项目遵循 [TRaSH Guides](https://trash-guides.info/) 最佳实践
- 所有服务使用官方或 LinuxServer.io 镜像
- 支持硬链接，节省磁盘空间
- 完整的健康检查和启动顺序控制
