# Media Stack

完整的家庭媒体服务栈，提供自动化下载、整理和播放功能。

## 服务列表

| 服务 | 端口 | 子域名 | 说明 |
|------|------|--------|------|
| Jellyfin | 8096 | media.DOMAIN | 媒体服务器 |
| Sonarr | 8989 | sonarr.DOMAIN | 剧集自动管理 |
| Radarr | 7878 | radarr.DOMAIN | 电影自动管理 |
| Prowlarr | 9696 | prowlarr.DOMAIN | 索引器管理 |
| qBittorrent | 8080 | bt.DOMAIN | 下载器 |
| Jellyseerr | 5055 | request.DOMAIN | 用户请求管理 |

## 目录结构

遵循 [TRaSH Guides](https://trash-guides.info/Hardlinks/How-to-setup-for/Docker/) 硬链接最佳实践：

```
/data/
├── torrents/           # 下载临时目录
│   ├── movies/         # qBittorrent 电影下载目录
│   └── tv/             # qBittorrent 剧集下载目录
└── media/              # 最终媒体库
    ├── movies/         # Radarr 整理后目录
    └── tv/             # Sonarr 整理后目录
```

**关键**: torrents 和 media 必须在同一父目录下，硬链接才能生效。

## 数据流程

```
用户请求 (Jellyseerr)
    ↓
触发搜索 (Sonarr/Radarr)
    ↓
查询索引器 (Prowlarr)
    ↓
发送种子 (qBittorrent)
    ↓
下载到 /data/torrents/
    ↓
自动整理 (Sonarr/Radarr)
    ↓
硬链接到 /data/media/
    ↓
Jellyfin 扫描并播放
```

## 快速开始

```bash
cd stacks/media

# 1. 配置环境变量
cp .env.example .env
# 编辑 .env，设置 MEDIA_PATH 和 DOWNLOAD_PATH

# 2. 创建目录 (必须在同一父目录)
sudo mkdir -p /data/{torrents,media}/{movies,tv}
sudo chown -R 1000:1000 /data

# 3. 启动服务
docker compose up -d
```

## 服务配置

### Jellyfin
- 访问: https://media.DOMAIN
- 媒体库: /media (只读挂载)
- 支持硬件转码 (可选)

### Sonarr
- 访问: https://sonarr.DOMAIN
- 下载客户端: 添加 qBittorrent (qbittorrent:8080)
- 索引器: 通过 Prowlarr 自动添加
- 路径映射:
  - 下载: /data/torrents/tv
  - 媒体: /data/media/tv

### Radarr
- 访问: https://radarr.DOMAIN
- 下载客户端: 添加 qBittorrent (qbittorrent:8080)
- 索引器: 通过 Prowlarr 自动添加
- 路径映射:
  - 下载: /data/torrents/movies
  - 媒体: /data/media/movies

### Prowlarr
- 访问: https://prowlarr.DOMAIN
- 添加索引器后会自动同步到 Sonarr/Radarr
- Apps 设置: 添加 Sonarr 和 Radarr 连接

### qBittorrent
- 访问: https://bt.DOMAIN
- 默认用户名: admin
- 默认密码: adminadmin (首次登录后请修改)
- 下载目录: /data/torrents

### Jellyseerr
- 访问: https://request.DOMAIN
- 首次访问进行初始配置
- 连接 Jellyfin + Sonarr + Radarr
- 用户可自行请求媒体

## 硬链接验证

```bash
# 检查是否支持硬链接
echo "test" > /data/torrents/test.txt
ln /data/torrents/test.txt /data/media/test.txt
ls -li /data/torrents/test.txt /data/media/test.txt
# 如果 inode 号相同，说明硬链接成功
```

## 故障排查

### Sonarr/Radarr 无法连接 qBittorrent
```bash
# 检查网络
docker exec sonarr curl -sf http://qbittorrent:8080

# 检查 qBittorrent 日志
docker logs qbittorrent
```

### 硬链接失败
- 确保 torrents 和 media 在同一文件系统
- 检查目录权限: `ls -la /data/`
- NFS 挂载不支持硬链接

### Jellyfin 无法识别媒体
- 检查目录结构是否正确
- 触发库扫描: Jellyfin 设置 → 库 → 扫描所有库
- 检查文件名是否符合命名规范

## 性能调优

- Jellyfin: 如需硬件转码，添加 `/dev/dri` 设备映射
- qBittorrent: 根据带宽调整连接数限制
- Sonarr/Radarr: 建议启用硬链接而非复制
