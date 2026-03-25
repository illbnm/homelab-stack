# Media Stack

完整的媒体服务栈，实现自动化下载、管理和播放。

## 服务架构

```
┌─────────────────────────────────────────────────────────┐
│                    Media Stack                              │
├─────────────────────────────────────────────────────────┤
│                                                          │
│   Jellyfin                                               │
│   ├── 媒体服务器                                        │
│   └── 视频播放/封面管理                                 │
│                                                          │
│   Sonarr                                                │
│   ├── 剧集管理                                          │
│   └── 自动追剧/下载触发                                 │
│                                                          │
│   Radarr                                                │
│   ├── 电影管理                                          │
│   └── 自动电影下载触发                                  │
│                                                          │
│   Prowlarr                                              │
│   ├── 索引器管理                                        │
│   └── 统一搜索/Tracker支持                            │
│                                                          │
│   qBittorrent                                           │
│   ├── 下载器                                            │
│   └── 种子/私有Tracker支持                             │
│                                                          │
│   Jellyseerr                                            │
│   ├── 请求管理                                          │
│   └── Jellyfin集成/用户请求                            │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

## 目录结构

遵循 [TRaSH Guides](https://trash-guides.info/Hardlinks/How-to-setup-for/Docker/) 最佳实践：

```
/data/
├── torrents/
│   ├── movies/       # Radarr 电影下载
│   └── tv/           # Sonarr 剧集下载
└── media/
    ├── movies/       # 电影库
    └── tv/           # 剧集库
```

**重要**：torrents 和 media 必须在同一文件系统，使用硬链接实现"同时做种"。

## 服务列表

| 服务 | 地址 | 用途 |
|------|------|------|
| Jellyfin | https://jellyfin.${DOMAIN} | 媒体播放 |
| Sonarr | https://sonarr.${DOMAIN} | 剧集管理 |
| Radarr | https://radarr.${DOMAIN} | 电影管理 |
| Prowlarr | https://prowlarr.${DOMAIN} | 索引器管理 |
| qBittorrent | https://qbittorrent.${DOMAIN} | 下载器 |
| Jellyseerr | https://requests.${DOMAIN} | 请求管理 |

## 快速开始

### 1. 配置环境变量

```bash
cd homelab-stack
cp stacks/media/.env.example stacks/media/.env
nano stacks/media/.env
```

### 2. 创建目录结构

```bash
mkdir -p /data/torrents/{movies,tv}
mkdir -p /data/media/{movies,tv}
```

### 3. 启动服务

```bash
docker compose -f stacks/media/docker-compose.yml up -d
```

### 4. 初始化配置

#### Prowlarr

1. 访问 https://prowlarr.${DOMAIN}
2. 添加索引器（Jackett, Torrentio 等）
3. 配置连接 Sonarr/Radarr

#### Sonarr

1. 访问 https://sonarr.${DOMAIN}
2. Settings -> Download Client -> 添加 qBittorrent
3. Settings -> Media Management -> 添加剧集库路径
4. 添加剧集监控

#### Radarr

1. 访问 https://radarr.${DOMAIN}
2. Settings -> Download Client -> 添加 qBittorrent
3. Settings -> Media Management -> 添加电影库路径
4. 添加电影监控

#### Jellyseerr

1. 访问 https://requests.${DOMAIN}
2. 连接 Jellyfin
3. 用户通过 Jellyseerr 请求新内容

## Sonarr/Radarr 连接 qBittorrent

### Sonarr

```
Settings -> Download Clients -> Add ->
Type: qBittorrent
Host: qbittorrent
Port: 8080
Username: admin
Password: (qbittorrent webui password)
Category: tv
```

### Radarr

```
Settings -> Download Clients -> Add ->
Type: qBittorrent
Host: qbittorrent
Port: 8080
Username: admin
Password: (qbittorrent webui password)
Category: movies
```

## qBittorrent 配置

### WebUI 访问

- URL: https://qbittorrent.${DOMAIN}
- 默认用户名: admin
- 默认密码: adminadmin

### 分类配置

在 qBittorrent 中创建分类：
- `tv` -> /data/torrents/tv
- `movies` -> /data/torrents/movies

## Jellyfin 配置

### 添加媒体库

1. 管理后台 -> 媒体库 -> 添加媒体库
2. 选择内容类型（电影/剧集）
3. 选择文件夹：
   - 电影: /media/movies
   - 剧集: /media/tv

### 连接 Sonarr/Radarr

在 Jellyfin 安装 "Sonarr/Radarr" 插件实现自动元数据刷新。

## Jellyseerr 配置

### 连接 Jellyfin

1. 首次访问 https://requests.${DOMAIN}
2. 登录 Jellyseerr（使用 Jellyfin 账户）
3. 连接 Jellyfin 服务器
4. 配置通知

## 健康检查

所有服务都配置了健康检查：

```bash
# 查看服务状态
docker compose -f stacks/media/docker-compose.yml ps

# 所有应该是 healthy 状态
```

## 故障排除

### Sonarr/Radarr 无法下载

1. 确认 qBittorrent 正在运行
2. 检查分类是否正确配置
3. 检查 Sonarr/Radarr -> qBittorrent 连接凭据

### Jellyfin 无法识别媒体

1. 确认媒体文件路径正确
2. 检查是否在同一文件系统（硬链接要求）
3. 重新扫描媒体库

### 无法连接 Prowlarr

1. 检查 Prowlarr 日志: `docker logs prowlarr`
2. 确认索引器配置正确

## 相关文档

- [Jellyfin 文档](https://jellyfin.org/docs/)
- [Sonarr 文档](https://sonarr.tv/docs/)
- [Radarr 文档](https://radarr.video/docs/)
- [Prowlarr 文档](https://wiki.servarr.com/prowlarr)
- [qBittorrent](https://www.qbittorrent.org/)
- [Jellyseerr 文档](https://github.com/Fallenbagel/jellyseerr)
- [TRaSH Guides](https://trash-guides.info/)
