# Media Stack (媒体服务栈)

此目录包含了完整的家庭媒体中心解决方案，集成了影视下载、刮削、索引和媒体播放等功能。

## 服务功能说明

本栈包含以下服务：

- **Jellyfin** (`jellyfin.${DOMAIN}`): 开源的媒体服务器，负责管理和播放视频资源。
- **Sonarr** (`sonarr.${DOMAIN}`): 剧集管理工具，自动监控、搜索和下载美剧、动漫等剧集。
- **Radarr** (`radarr.${DOMAIN}`): 电影管理工具，自动监控、搜索和下载电影。
- **Prowlarr** (`prowlarr.${DOMAIN}`): 索引器管理器，可以为 Sonarr 和 Radarr 等提供统一的 Tracker 支持。
- **qBittorrent** (`qbittorrent.${DOMAIN}`): 强大的 BT/PT 下载器。
- **Jellyseerr** (`jellyseerr.${DOMAIN}`): 统一的媒体请求面板，对接 Jellyfin 和 Sonarr/Radarr。

## 目录结构说明

为了充分利用硬盘空间并支持快速硬链接 (Hardlinks)，我们遵循 [TRaSH Guides](https://trash-guides.info/Hardlinks/How-to-setup-for/Docker/) 的目录最佳实践。

在主机的 `MEDIA_ROOT` 和 `DOWNLOADS_ROOT` 中推荐维护以下结构（它们会映射到容器内的 `/data/media` 和 `/data/torrents`）：

```text
# 宿主机上，建议将 MEDIA_ROOT 设为某硬盘的 /data/media，DOWNLOADS_ROOT 设为同一硬盘的 /data/torrents
/data/
├── torrents/
│   ├── movies/
│   └── tv/
└── media/
    ├── movies/
    └── tv/
```

这样，当从 `torrents` 中完成下载后，Sonarr / Radarr 可以直接将文件硬链接到 `media` 目录下供 Jellyfin 读取，而无需消耗额外的存储空间。

## 启动命令

1. 复制环境变量示例文件：
   ```bash
   cp .env.example .env
   ```
2. 编辑 `.env` 文件，根据实际情况修改 `DOMAIN`、`PUID`、`PGID` 以及目录映射 (`MEDIA_ROOT`, `DOWNLOADS_ROOT`)。
3. 启动服务栈：
   ```bash
   docker compose up -d
   ```

## 常见配置步骤

### Sonarr / Radarr 连接 qBittorrent 的配置步骤

1. 打开 **Sonarr** 或 **Radarr** 面板。
2. 进入 `Settings` -> `Download Clients` -> 点击 `+` (Add)。
3. 选择 `qBittorrent`。
4. 填写以下信息：
   - Name: `qBittorrent`
   - Host: `qbittorrent` (因为在同一个 Docker 网络下，可直接使用服务名)
   - Port: `8080`
5. 点击 `Test` 测试连通性，通过后点击 `Save`。

### Jellyfin 媒体库添加步骤

1. 打开 **Jellyfin** 控制面板，并完成初始向导。
2. 进入 `控制台` -> `媒体库` -> 点击 `添加媒体库`。
3. 内容类型选择 `电影`（如果是 Sonarr 的内容则选 `电视节目`）。
4. 文件夹添加时，选择 `/data/media/movies` （或 `/data/media/tv`）。
5. 保存并等待媒体库扫描。

## 常见问题 (FAQ)

**Q: 为什么下载的文件无法硬链接到媒体库？**
A: 请确保 `MEDIA_ROOT` 和 `DOWNLOADS_ROOT` 位于主机的同一个底层文件系统/分区上。同时在 Docker 挂载中确保内部路径统一（我们在配置中使用的是 `/data/media` 和 `/data/torrents`，对 Sonarr/Radarr 而言都是挂载的对应路径）。如果跨盘或跨分区，硬链接会失效并降级为复制。

**Q: 如何接入 Prowlarr 索引器？**
A: 进入 Prowlarr 后，在 `Settings` -> `Apps` 中，分别添加 Sonarr 和 Radarr。使用它们的对应服务名（如 `sonarr` 或 `radarr`）以及相应的 API Key（在各个软件的 Settings -> General 中获取），然后 Prowlarr 会自动同步 Tracker 索引到它们中。

**Q: qBittorrent 默认账号密码是什么？**
A: v4.6.1 之后版本默认随机生成密码并打印在日志中。您可以使用 `docker logs qbittorrent` 查找临时密码，登录后在 WebUI 中自行更改。
