# Media Stack - 媒体服务栈

完整的自动化媒体管理和流媒体解决方案。

## 🚀 服务列表

| 服务 | 端口 | 功能 | 访问地址 |
|------|------|------|----------|
| **Jellyfin** | 8096 | 媒体服务器 | https://jellyfin.${DOMAIN} |
| **Sonarr** | 8989 | 剧集管理 | https://sonarr.${DOMAIN} |
| **Radarr** | 7878 | 电影管理 | https://radarr.${DOMAIN} |
| **Prowlarr** | 9696 | 索引器管理 | https://prowlarr.${DOMAIN} |
| **qBittorrent** | 8080 | 下载器 | https://qbittorrent.${DOMAIN} |
| **Jellyseerr** | 5055 | 请求管理 | https://jellyseerr.${DOMAIN} |

## 📋 前置要求

1. **Traefik** 运行正常（见 `stacks/base/`）
2. **域名 DNS** 已解析到服务器 IP
3. **存储目录** 已创建并配置权限

## 🔧 目录结构

遵循 [TRaSH Guides](https://trash-guides.info/Hardlinks/How-to-setup-for/Docker/) 硬链接最佳实践：

```bash
/data/
├── torrents/           # 临时下载目录
│   ├── movies/
│   └── tv/
└── media/              # 最终媒体库
    ├── movies/
    └── tv/
```

**创建目录**：
```bash
# 创建目录
sudo mkdir -p /data/{torrents,media}/{movies,tv}

# 设置权限（PUID:PGID = 1000:1000）
sudo chown -R 1000:1000 /data

# 验证
ls -la /data/
```

## 🚀 快速开始

### 1. 配置环境变量

```bash
cp .env.example .env
```

编辑 `.env`，设置：
- `DOMAIN` - 你的域名
- `PUID` / `PGID` - 用户/组 ID（默认 1000:1000）

### 2. 创建目录

```bash
sudo mkdir -p /data/{torrents,media}/{movies,tv}
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

所有服务应显示 `healthy`。

## 🔗 服务配置流程

### 1. Prowlarr（索引器）

**首次配置**：
1. 访问 https://prowlarr.${DOMAIN}
2. 完成初始设置向导
3. 添加索引器（TorrentIndexers）
4. 连接到 Sonarr/Radarr：
   - Settings → Apps → Add Application
   - 选择 Sonarr/Radarr
   - 填入 Prowlarr Server: `http://prowlarr:9696`
   - 填入 Sonarr/Radarr Server: `http://sonarr:8989` 或 `http://radarr:7878`
   - 填入 API Key（从 Sonarr/Radarr Settings → General）

### 2. qBittorrent（下载器）

**首次配置**：
1. 访问 https://qbittorrent.${DOMAIN}
2. 默认用户名: `admin`
3. 默认密码: `adminadmin`（首次登录后强制修改）
4. **重要**: 修改密码后，在 Sonarr/Radarr 中配置连接

**Sonarr 连接 qBittorrent**：
1. Settings → Download Clients → Add
2. 选择 qBittorrent
3. Host: `qbittorrent`
4. Port: `8080`
5. Username: 你的用户名
6. Password: 你的密码
7. Test Connection → 应显示成功

### 3. Sonarr（剧集管理）

**首次配置**：
1. 访问 https://sonarr.${DOMAIN}
2. 完成初始设置向导
3. **连接 Prowlarr**: Settings → Indexers → Add Indexer → Custom → Prowlarr
4. **连接 qBittorrent**: 见上方配置
5. **添加根目录**: Settings → Media Management → Root Folders
   - Path: `/data/media/tv`

**搜索剧集**：
1. Series → Add New
2. 搜索剧集名称
3. 选择质量配置（Quality Profile）
4. 根目录: `/data/media/tv`
5. 开始搜索 → 自动触发下载

### 4. Radarr（电影管理）

**配置步骤同 Sonarr**：
- 访问 https://radarr.${DOMAIN}
- 连接 Prowlarr 和 qBittorrent
- 根目录: `/data/media/movies`

### 5. Jellyfin（媒体服务器）

**首次配置**：
1. 访问 https://jellyfin.${DOMAIN}
2. 完成初始设置向导（创建管理员账号）
3. **添加媒体库**：
   - Dashboard → Libraries → Add Media Library
   - 类型: Movies
     - Name: Movies
     - Folder: `/data/media/movies`
   - 类型: Shows
     - Name: TV Shows
     - Folder: `/data/media/tv`
4. **启用硬件转码**（可选）：
   - Dashboard → Playback
   - Transcoding → Hardware Acceleration
   - 选择你的 GPU（如果有）

### 6. Jellyseerr（请求管理）

**首次配置**：
1. 访问 https://jellyseerr.${DOMAIN}
2. 登录方式: 选择 Jellyfin
3. Jellyfin URL: `http://jellyfin:8096`
4. 填入 Jellyfin 用户名和密码
5. 同步媒体库
6. 配置 Radarr/Sonarr 连接

**用户请求媒体**：
1. 用户登录 Jellyseerr
2. 搜索电影/剧集
3. 点击 "Request"
4. 自动推送到 Radarr/Sonarr
5. 自动下载并整理到媒体库
6. Jellyfin 自动识别

## 📊 数据流程

```
用户请求 (Jellyseerr)
    ↓
自动触发 (Radarr/Sonarr)
    ↓
搜索索引器 (Prowlarr)
    ↓
找到种子 (TorrentIndexers)
    ↓
发送到下载器 (qBittorrent)
    ↓
下载到临时目录 (/data/torrents/)
    ↓
自动整理 (Radarr/Sonarr)
    ↓
移动到媒体库 (/data/media/)
    ↓
Jellyfin 识别并播放
```

## 🔒 安全配置

### 1. 修改默认密码

**qBittorrent**:
```bash
# 首次登录后强制修改
# Settings → Web UI → Authentication
```

**Jellyfin**:
```bash
# Dashboard → Users → 选择用户 → Password
```

### 2. 访问控制

**推荐**: 使用 Authentik SSO（见 `stacks/sso/`）：
- 所有服务通过 Authentik 登录
- 统一身份管理
- 支持家庭共享

### 3. VPN（可选）

```yaml
# 在 docker-compose.yml 中添加 Gluetun 容器
gluetun:
  image: qmcgaw/gluetun
  cap_add:
    - NET_ADMIN
  devices:
    - /dev/net/tun:/dev/net/tun
  environment:
    - VPN_SERVICE_PROVIDER=your_provider
    - OPENVPN_USER=your_user
    - OPENVPN_PASSWORD=your_pass
  # 让 qbittorrent 通过 VPN
```

## 🛠️ 故障排查

### qBittorrent 连接失败

```bash
# 检查 qBittorrent 日志
docker logs qbittorrent

# 常见问题：
# 1. 密码错误 → 重置密码
# 2. 端口未开放 → 检查防火墙
# 3. 网络不通 → 检查 media-internal 网络
```

### Sonarr 无法找到剧集

```bash
# 检查 Prowlarr 连接
# Settings → Indexers → Test All

# 检查日志
docker logs sonarr

# 常见问题：
# 1. Prowlarr 未连接 → 重新配置
# 2. 索引器未添加 → 在 Prowlarr 中添加
# 3. 搜索权限不足 → 检查 API Key
```

### Jellyfin 无法识别媒体

```bash
# 检查权限
ls -la /data/media/

# 检查 Jellyfin 日志
docker logs jellyfin

# 常见问题：
# 1. 权限错误 → chown -R 1000:1000 /data/media
# 2. 路径错误 → 检查根目录配置
# 3. 媒体库未添加 → Dashboard → Libraries
```

## 📚 相关文档

- [Jellyfin 文档](https://jellyfin.org/docs/)
- [Sonarr Wiki](https://wiki.servarr.com/sonarr)
- [Radarr Wiki](https://wiki.servarr.com/radarr)
- [TRaSH Guides](https://trash-guides.info/)
- [Prowlarr Wiki](https://wiki.servarr.com/prowlarr)

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
docker rmi $(docker images 'jellyfin/*' 'linuxserver/*' 'fallenbagel/*' -q)
```

## 📝 许可证

- Jellyfin: GPL-2.0
- Sonarr/Radarr/Prowlarr: GPL-3.0
- qBittorrent: GPL-2.0
- Jellyseerr: MIT
