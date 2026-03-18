# Media Stack

完整的家庭媒体服务栈：自动搜索、下载、整理和播放影视内容。

## 服务概览

| 服务 | 子域名 | 端口 | 用途 |
|------|--------|------|------|
| Jellyfin | `jellyfin.{DOMAIN}` | 8096 | 媒体服务器（播放） |
| Sonarr | `sonarr.{DOMAIN}` | 8989 | 剧集搜索与管理 |
| Radarr | `radarr.{DOMAIN}` | 7878 | 电影搜索与管理 |
| Prowlarr | `prowlarr.{DOMAIN}` | 9696 | 索引器聚合管理 |
| qBittorrent | `qbittorrent.{DOMAIN}` | 8080 | BT 下载客户端 |
| Jellyseerr | `jellyseerr.{DOMAIN}` | 5055 | 影视请求管理 |

## 架构图

```
用户请求 → Jellyseerr → Sonarr/Radarr → Prowlarr → 索引器
                                          ↓
                                    qBittorrent → 下载到 /data/downloads
                                          ↓
                                   Sonarr/Radarr → 整理到 /data/media
                                          ↓
                                     Jellyfin → 用户播放
```

## 前置条件

- Docker + Docker Compose
- Traefik 反向代理（`proxy` 网络已创建）
- DNS 记录指向服务器（泛域名 `*.{DOMAIN}`）

## Quick Start

```bash
cd stacks/media
cp .env.example .env
# 编辑 .env 填入实际值
vim .env
# 创建数据目录
mkdir -p /data/media/{movies,tv} /data/downloads/{movies,tv}
# 启动
docker compose up -d
```

## 目录结构

```
/data/
├── downloads/          # qBittorrent 下载目录
│   ├── movies/         # 电影下载
│   └── tv/             # 剧集下载
└── media/              # Jellyfin 媒体库
    ├── movies/         # 电影（Sonarr/Radarr 自动整理）
    └── tv/             # 剧集（Sonarr/Radarr 自动整理）
```

> 💡 建议按 [TRaSH Guides](https://trash-guides.info/Hardlinks/How-to-setup-for/Docker/) 配置硬链接，节省磁盘空间。

## 配置步骤

### 1. 配置 Prowlarr（索引器）

1. 访问 `https://prowlarr.{DOMAIN}`
2. Settings → Indexers → 添加索引器（推荐：PT 站、公共 Tracker）
3. Settings → Apps → Sonarr/Radarr → 添加连接

### 2. 配置 qBittorrent

1. 访问 `https://qbittorrent.{DOMAIN}`
2. 默认密码：`adminadmin`，首次登录后修改
3. Tools → Options → Downloads → 设置默认保存路径为 `/data/downloads`

### 3. 连接 Sonarr ↔ qBittorrent

1. 访问 `https://sonarr.{DOMAIN}`
2. Settings → Download Clients → 添加 → qBittorrent
3. Host: `qbittorrent`, Port: `8080`
4. Settings → Media Management → Root Folders → 添加 `/data/media/tv`

### 4. 连接 Radarr ↔ qBittorrent

1. 访问 `https://radarr.{DOMAIN}`
2. 同上步骤，Root Folder 设为 `/data/media/movies`

### 5. 配置 Jellyfin 媒体库

1. 访问 `https://jellyfin.{DOMAIN}`
2. 设置向导 → 添加媒体库
3. 电影库：`/data/media/movies`
4. 电视剧集：`/data/media/tv`

### 6. 配置 Jellyseerr

1. 访问 `https://jellyseerr.{DOMAIN}`
2. 设置向导 → 连接 Jellyfin
3. 连接 Sonarr + Radarr → 自动处理用户请求

## 验证清单

- [ ] `docker compose ps` — 所有服务显示 healthy
- [ ] `https://jellyfin.{DOMAIN}` — 可访问
- [ ] `https://sonarr.{DOMAIN}` — 可访问
- [ ] `https://radarr.{DOMAIN}` — 可访问
- [ ] `https://prowlarr.{DOMAIN}` — 可访问
- [ ] `https://qbittorrent.{DOMAIN}` — 可访问
- [ ] `https://jellyseerr.{DOMAIN}` — 可访问
- [ ] Sonarr 能搜索剧集并触发 qBittorrent 下载
- [ ] Radarr 能搜索电影并触发 qBittorrent 下载
- [ ] Jellyfin 能识别 `/data/media` 中的媒体文件

## 常见问题

**Q: 硬链接不生效？**
A: 确保 downloads 和 media 在同一分区，使用 `ls -li` 验证 inode 相同。

**Q: qBittorrent 无法连接？**
A: 确认端口 6881 已开放（TCP+UDP），防火墙放行。

**Q: Sonarr/Radarr 找不到下载路径？**
A: 检查容器内路径映射：`/data/downloads` 和 `/data/media` 是否一致。
