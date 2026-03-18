# 🎬 Media Stack — Jellyfin + Sonarr + Radarr + qBittorrent

> 完整媒体自动化栈：媒体服务器、剧集/电影管理、索引器、下载器、请求管理。

## 服务清单

| 服务 | 镜像 | URL | 用途 |
|------|------|-----|------|
| **Jellyfin** | `jellyfin/jellyfin:10.9.11` | `jellyfin.${DOMAIN}` | 媒体服务器 |
| **Sonarr** | `linuxserver/sonarr:4.0.11` | `sonarr.${DOMAIN}` | 剧集管理 |
| **Radarr** | `linuxserver/radarr:5.8.1` | `radarr.${DOMAIN}` | 电影管理 |
| **Prowlarr** | `linuxserver/prowlarr:1.22.0` | `prowlarr.${DOMAIN}` | 索引器管理 |
| **qBittorrent** | `linuxserver/qbittorrent:4.6.7` | `qbt.${DOMAIN}` | 下载器 |
| **Jellyseerr** | `fallenbagel/jellyseerr:2.1.1` | `request.${DOMAIN}` | 请求管理 |

## 目录结构

遵循 [TRaSH Guides](https://trash-guides.info/Hardlinks/How-to-setup-for/Docker/) 硬链接最佳实践：

```
/data/
├── torrents/          # 下载目录
│   ├── movies/        # 电影下载
│   └── tv/            # 剧集下载
└── media/             # 媒体库（硬链接）
    ├── movies/        # 电影
    └── tv/            # 剧集
```

关键：`torrents/` 和 `media/` 在同一文件系统下，Sonarr/Radarr 使用硬链接移动文件，零额外磁盘占用。

## 快速启动

```bash
# 1. 创建目录结构
mkdir -p /data/{torrents/{movies,tv},media/{movies,tv}}
chown -R 1000:1000 /data

# 2. 配置 .env
DATA_ROOT=/data
MEDIA_ROOT=/data/media
PUID=1000
PGID=1000

# 3. 启动
docker compose -f stacks/media/docker-compose.yml up -d

# 4. 验证
docker compose -f stacks/media/docker-compose.yml ps
```

## 配置步骤

### 1. qBittorrent

1. 访问 `https://qbt.${DOMAIN}`
2. 默认密码在日志中: `docker logs qbittorrent`
3. Settings → Downloads:
   - Default Save Path: `/data/torrents`
   - Keep incomplete in: `/data/torrents/incomplete`
4. Settings → Web UI → 修改密码

### 2. Prowlarr

1. 访问 `https://prowlarr.${DOMAIN}`
2. Settings → Indexers → 添加索引器
3. Settings → Apps → 添加 Sonarr + Radarr:
   - Prowlarr Server: `http://prowlarr:9696`
   - Sonarr: `http://sonarr:8989`
   - Radarr: `http://radarr:7878`
   - API Key: 从各服务 Settings → General 获取

### 3. Sonarr

1. 访问 `https://sonarr.${DOMAIN}`
2. Settings → Media Management:
   - Root Folder: `/data/media/tv`
   - 启用 Hardlinks
3. Settings → Download Clients → 添加 qBittorrent:
   - Host: `qbittorrent`
   - Port: `8080`
   - Category: `tv`

### 4. Radarr

1. 访问 `https://radarr.${DOMAIN}`
2. Settings → Media Management:
   - Root Folder: `/data/media/movies`
   - 启用 Hardlinks
3. Settings → Download Clients → 添加 qBittorrent:
   - Host: `qbittorrent`
   - Port: `8080`
   - Category: `movies`

### 5. Jellyfin

1. 访问 `https://jellyfin.${DOMAIN}`
2. 完成设置向导
3. 添加媒体库:
   - Movies: `/data/media/movies`
   - TV Shows: `/data/media/tv`
4. 启用硬件转码（如有 GPU）

### 6. Jellyseerr

1. 访问 `https://request.${DOMAIN}`
2. 连接 Jellyfin:
   - URL: `http://jellyfin:8096`
3. 连接 Sonarr + Radarr（使用 API Key）

## 工作流程

```
用户请求 (Jellyseerr)
    ↓
Sonarr/Radarr 搜索
    ↓
Prowlarr 查询索引器
    ↓
qBittorrent 下载
    ↓
Sonarr/Radarr 硬链接到媒体库
    ↓
Jellyfin 自动扫描
```

## FAQ

### qBittorrent 默认密码？
查看日志: `docker logs qbittorrent 2>&1 | grep password`

### 硬链接不工作？
确保 `torrents/` 和 `media/` 在同一 Docker volume 或 bind mount 下。本配置使用 `${DATA_ROOT}:/data` 统一挂载。

### Jellyfin 转码慢？
启用硬件加速: Dashboard → Playback → Transcoding → 选择 VAAPI/NVENC。
需要额外挂载 `/dev/dri` (Intel) 或 NVIDIA runtime。

### Sonarr/Radarr 连不上 qBittorrent？
确认使用容器名 `qbittorrent` 而非 `localhost`，端口 `8080`。
