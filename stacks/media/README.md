# Media Stack — 媒体服务栈

这个 `docker-compose.yml` 文件定义了一个完整的媒体服务栈，旨在提供媒体内容的自动化下载、管理、索引和播放功能。它遵循 TRaSH Guides 的硬链接最佳实践，以优化存储和性能。

## 包含服务

| 服务 | 镜像 | 用途 | 端口 | WebUI URL (示例) |
|------|------|------|------|------------------|
| **Jellyfin** | `jellyfin/jellyfin:10.9.11` | 媒体服务器，用于流式传输和管理您的媒体库。 | 8096 | `https://jellyfin.yourdomain.com` |
| **Sonarr** | `lscr.io/linuxserver/sonarr:4.0.11` | 剧集管理，自动化剧集下载、重命名和整理。 | 8989 | `https://sonarr.yourdomain.com` |
| **Radarr** | `lscr.io/linuxserver/radarr:5.8.1` | 电影管理，自动化电影下载、重命名和整理。 | 7878 | `https://radarr.yourdomain.com` |
| **Prowlarr** | `lscr.io/linuxserver/prowlarr:1.22.0` | 索引器管理，聚合和管理多个索引器（如 Torrent 站点、Usenet 提供商）。 | 9696 | `https://prowlarr.yourdomain.com` |
| **qBittorrent** | `lscr.io/linuxserver/qbittorrent:4.6.7` | 下载器，用于下载 Torrent 文件。 | 8080 | `https://qbittorrent.yourdomain.com` |
| **Jellyseerr** | `fallenbagel/jellyseerr:2.1.1` | 请求管理，允许用户请求电影和剧集，并与 Sonarr/Radarr/Jellyfin 集成。 | 5055 | `https://jellyseerr.yourdomain.com` |

## 文件结构

