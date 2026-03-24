# Media Stack

Complete media management and streaming suite for HomeLab.

## What's Included

| Service | Version | URL | Purpose |
|---------|---------|-----|---------|
| Jellyfin | 10.9.11 | `media.${DOMAIN}` | Media server & streaming |
| Jellyseerr | 2.1.1 | `requests.${DOMAIN}` | Media request management |
| Sonarr | 4.0.11 | `sonarr.${DOMAIN}` | TV series management |
| Radarr | 5.8.1 | `radarr.${DOMAIN}` | Movie management |
| Prowlarr | 1.22.0 | `prowlarr.${DOMAIN}` | Indexer manager |
| qBittorrent | 4.6.7 | `bt.${DOMAIN}` | Download client |

## Architecture

```
Jellyseerr --+-- Sonarr --+-- Prowlarr --> Indexers
             |            |
             +-- Radarr --|
             |            +-- qBittorrent --> downloads/
             +-- Jellyfin --> media/
                              (streaming)
```

## Directory Structure (TRaSH Guides Hardlinks)

Follow [TRaSH Guides](https://trash-guides.info/Hardlinks/How-to-setup-for/Docker/) for optimal hardlink setup. Both downloads and media MUST be on the same filesystem.

```
${MEDIA_PATH}/            # e.g. /opt/homelab/media
├── movies/               # Radarr moves/links here
└── tv/                   # Sonarr moves/links here

${DOWNLOAD_PATH}/         # e.g. /opt/homelab/downloads
├── movies/               # qBittorrent downloads for Radarr
└── tv/                   # qBittorrent downloads for Sonarr
```

Create on host:
```bash
sudo mkdir -p /opt/homelab/{media/{movies,tv},downloads/{movies,tv}}
sudo chown -R 1000:1000 /opt/homelab
```

## Prerequisites

- Base infrastructure stack running (Traefik + proxy network)
- Host directories created (see above)
- `docker network create proxy` (if not done)

## Quick Start

```bash
cd stacks/media
cp .env.example .env
# Edit .env with your DOMAIN, MEDIA_PATH, DOWNLOAD_PATH
docker compose up -d
```

## Configuration

| Variable | Required | Description |
|----------|----------|-------------|
| `DOMAIN` | ✅ | Base domain |
| `TZ` | ✅ | Timezone |
| `PUID` | ✅ | User ID for file permissions |
| `PGID` | ✅ | Group ID for file permissions |
| `MEDIA_PATH` | ✅ | Host path for organized media |
| `DOWNLOAD_PATH` | ✅ | Host path for downloads |

## Post-Deploy Setup

### 1. Sonarr 连接 qBittorrent 配置

1. 打开 `https://sonarr.${DOMAIN}`
2. Settings → Download Clients → 点击 `+` → 选择 qBittorrent
3. 填写:
   - **Host**: `qbittorrent` (Docker 内部主机名)
   - **Port**: `8080`
   - **Username**: `admin` (首次登录后修改)
   - **Password**: (你的 qBittorrent 密码)
   - **Category**: `tv` (qBittorrent 中自动创建)
4. 点击 Test 验证连接 → Save

### 2. Radarr 连接 qBittorrent 配置

步骤同 Sonarr，但:
- **Category**: `movies`
- 在 Radarr: Settings → Download Clients → 添加 qBittorrent

### 3. Prowlarr 配置索引并同步到 Sonarr/Radarr

1. 打开 `https://prowlarr.${DOMAIN}`
2. Indexers → Add Indexer → 选择你的索引站
3. Settings → Apps → Add Application:
   - Sonarr: URL = `http://sonarr:8989`, API Key = (从 Sonarr Settings→General 获取)
   - Radarr: URL = `http://radarr:7878`, API Key = (从 Radarr Settings→General 获取)
4. Save → Prowlarr 自动同步索引到 Sonarr/Radarr

### 4. Jellyfin 媒体库添加步骤

1. 打开 `https://media.${DOMAIN}`
2. 首次运行向导 → 设置语言和管理员账户
3. 添加媒体库:
   - 点击 `+ Add Media Library`
   - 内容类型: **Movies** → 文件夹: `/media/movies`
   - 内容类型: **TV Shows** → 文件夹: `/media/tv`
4. 设置 → 播放 → 硬件加速 (如 GPU 可用)
5. 设置 → 转码 → 启用硬件加速

### 5. Jellyseerr 连接配置

1. 打开 `https://requests.${DOMAIN}`
2. 连接 Jellyfin: 输入 URL `http://jellyfin:8096` + API Key
3. 连接 Sonarr: 输入 URL `http://sonarr:8989` + API Key
4. 连接 Radarr: 输入 URL `http://radarr:7878` + API Key
5. 用户现在可以在 Jellyseerr 搜索并请求电影/剧集

## Health Checks

All services include Docker health checks. Verify status:

```bash
docker compose ps
```

## 常见问题 (FAQ)

### Q: Sonarr/Radarr 搜索到但不下载
A: 检查 qBittorrent 连接配置 (Settings → Download Clients → Test)。确保 category 名称正确。

### Q: 下载完成但 Sonarr/Radarr 不识别
A: 确保 Sonarr/Radarr 的 `/media` 和 `/downloads` 路径在同一文件系统上 (硬链接要求)。检查 qBittorrent 的 `Default Save Path` 设置。

### Q: Jellyfin 媒体库显示空
A: 确认 Sonarr/Radarr 已将文件移动到 `/media/movies` 或 `/media/tv`。在 Jellyfin 中手动触发库扫描。

### Q: Jellyseerr 请求后 Sonarr/Radarr 无反应
A: 检查 Jellyseerr Settings → Services 中 Sonarr/Radarr 的 API Key 和连接状态。

### Q: 端口冲突
A: 所有服务通过 Traefik 反代，无需暴露额外端口。如有冲突，检查是否有其他服务占用 80/443。

### Q: 硬链接不生效
A: 确认 `${MEDIA_PATH}` 和 `${DOWNLOAD_PATH}` 在同一个文件系统/分区上。运行 `df ${MEDIA_PATH} ${DOWNLOAD_PATH}` 检查。
