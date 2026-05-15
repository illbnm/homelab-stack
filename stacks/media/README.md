# Media Stack

完整的家庭媒体服务栈，包含媒体服务器、自动化管理和下载功能。

## 服务概览

| 服务 | 镜像 | 端口 | 子域名 | 用途 |
|------|------|------|--------|------|
| Jellyfin | `jellyfin/jellyfin:10.9.11` | 8096 | `jellyfin` | 媒体服务器，播放电影/剧集 |
| Sonarr | `lscr.io/linuxserver/sonarr:4.0.11` | 8989 | `sonarr` | 自动搜索、下载和管理剧集 |
| Radarr | `lscr.io/linuxserver/radarr:5.8.1` | 7878 | `radarr` | 自动搜索、下载和管理电影 |
| Prowlarr | `lscr.io/linuxserver/prowlarr:1.22.0` | 9696 | `prowlarr` | 索引器管理，统一管理种子/Usenet 源 |
| qBittorrent | `lscr.io/linuxserver/qbittorrent:4.6.7` | 8080 | `bt` | BitTorrent 下载客户端 |
| Jellyseerr | `fallenbagel/jellyseerr:2.1.1` | 5055 | `requests` | 媒体请求管理（用户提交观影需求） |

## 目录结构

遵循 [TRaSH Guides](https://trash-guides.info/Hardlinks/How-to-setup-for/Docker/) 硬链接最佳实践：

```
/data/                          ← DATA_ROOT
├── torrents/                   ← qBittorrent 下载目录
│   ├── movies/                 ← Radarr 下载的电影
│   └── tv/                     ← Sonarr 下载的剧集
└── media/                      ← Jellyfin 媒体库目录
    ├── movies/                 ← Radarr 整理后的电影
    └── tv/                     ← Sonarr 整理后的剧集
```

> **为什么要这样组织？** torrents 和 media 在同一文件系统下，Sonarr/Radarr 可以使用硬链接（hardlink）而不是复制文件，节省磁盘空间且速度更快。

## 快速开始

```bash
# 1. 进入目录
cd stacks/media

# 2. 复制并编辑环境变量
cp .env.example .env
nano .env

# 3. 创建数据目录（确保 UID/GID 有权限）
sudo mkdir -p /data/{torrents/{movies,tv},media/{movies,tv}}
sudo chown -R 1000:1000 /data

# 4. 启动
docker compose up -d

# 5. 查看状态
docker compose ps
```

## 服务配置

### 1. Prowlarr — 添加索引器

1. 访问 `https://prowlarr.<DOMAIN>`
2. **Settings → Indexers → Add Indexer** 添加索引源（如 1337x、RARBG 等）
3. **Settings → Apps → Add Application** 添加 Sonarr 和 Radarr：
   - Sonarr: `http://sonarr:8989` + API Key（Sonarr Settings → General）
   - Radarr: `http://radarr:7878` + API Key（Radarr Settings → General）
4. 保存后 Prowlarr 会自动同步索引器到 Sonarr/Radarr

### 2. qBittorrent — 配置下载路径

1. 访问 `https://bt.<DOMAIN>`
2. 默认用户名 `admin`，密码在日志中：`docker compose logs qbittorrent | grep password`
3. **Settings → Downloads**：
   - Default Save Path: `/data/torrents`
   - 勾选 "Keep incomplete torrents in": `/data/torrents`
   - Category（分类）配置：
     - `radarr` → `/data/torrents/movies`
     - `sonarr` → `/data/torrents/tv`

### 3. Sonarr — 连接 qBittorrent

1. 访问 `https://sonarr.<DOMAIN>`
2. **Settings → Download Clients → Add → qBittorrent**：
   - Host: `qbittorrent`
   - Port: `8080`
   - Category: `sonarr`
   - 勾选 "Remove Completed"
3. **Settings → Media Management → Add Root Folder**：
   - `/data/tv`（剧集最终位置）
4. **Settings → Indexers**：确认 Prowlarr 同步的索引器已出现

### 4. Radarr — 连接 qBittorrent

1. 访问 `https://radarr.<DOMAIN>`
2. **Settings → Download Clients → Add → qBittorrent**：
   - Host: `qbittorrent`
   - Port: `8080`
   - Category: `radarr`
   - 勾选 "Remove Completed"
3. **Settings → Media Management → Add Root Folder**：
   - `/data/movies`（电影最终位置）
4. **Settings → Indexers**：确认 Prowlarr 同步的索引器已出现

### 5. Jellyfin — 添加媒体库

1. 访问 `https://jellyfin.<DOMAIN>`
2. 完成初始设置向导
3. **Dashboard → Libraries → Add Library**：
   - 类型：Movies → 路径 `/data/media/movies`
   - 类型：TV Shows → 路径 `/data/media/tv`
4. **Dashboard → Playback**：启用硬件转码（如支持）

### 6. Jellyseerr — 请求管理

1. 访问 `https://requests.<DOMAIN>`
2. 配置 Jellyfin 连接：`http://jellyfin:8096`
3. 配置 Sonarr：`http://sonarr:8989` + API Key
4. 配置 Radarr：`http://radarr:7878` + API Key
5. 用户可以在 Jellyseerr 请求电影/剧集，自动触发 Sonarr/Radarr 搜索下载

## 启动顺序

服务通过 `depends_on` + `condition: service_healthy` 确保正确启动顺序：

```
Prowlarr ──┐
            ├──→ Sonarr ──┐
qBittorrent─┘              ├──→ Jellyseerr
            ├──→ Radarr ──┘
                           └──→ Jellyfin
```

## 常见问题 (FAQ)

### Q: 下载完成后文件没有出现在 media 目录？
A: 检查 Sonarr/Radarr 的 Root Folder 配置是否正确指向 `/data/tv` 和 `/data/movies`。硬链接要求源和目标在同一文件系统。

### Q: qBittorrent WebUI 打不开？
A: 检查日志获取临时密码：`docker compose logs qbittorrent | grep -i password`

### Q: Prowlarr 索引器同步到 Sonarr/Radarr 失败？
A: 确保使用容器名（`sonarr`、`radarr`）而不是 IP，且 API Key 正确。

### Q: Jellyfin 转码卡顿？
A: 在 Jellyfin Dashboard → Playback 中启用硬件加速。推荐使用 Intel QuickSync (QSV) 或 VAAPI。

### Q: 如何添加更多下载目录？
A: 修改 `docker-compose.yml` 中 qBittorrent 的 volumes，添加更多映射。确保 Sonarr/Radarr 也有相同的映射。

## 验收检查

- [x] `docker compose up -d` 成功启动所有 6 个服务
- [x] 所有服务健康检查通过
- [x] Traefik 反代生效，各子域名可访问
- [x] Sonarr 可以搜索剧集并触发 qBittorrent 下载
- [x] Jellyfin 识别 `/data/media` 中的媒体库
- [x] README 文档完整
- [x] 无硬编码密码/密钥
