# 🎬 HomeLab Media Stack

完整的媒体服务栈，包含 Jellyfin、Sonarr、Radarr、Prowlarr、qBittorrent 和 Jellyseerr。

## 📦 服务清单

| 服务 | 镜像 | 端口 | 用途 |
|------|------|------|------|
| Jellyfin | `jellyfin/jellyfin:10.9.11` | 8096 | 媒体服务器 |
| Sonarr | `linuxserver/sonarr:4.0.9` | 8989 | 剧集管理 |
| Radarr | `linuxserver/radarr:5.11.0` | 7878 | 电影管理 |
| Prowlarr | `linuxserver/prowlarr:1.24.3` | 9696 | 索引器管理 |
| qBittorrent | `linuxserver/qbittorrent:4.6.7` | 8080 | 下载器 |
| Jellyseerr | `fallenbagel/jellyseerr:2.1.1` | 5055 | 请求管理 |

## 🚀 快速启动

### 1. 配置环境变量

```bash
cd stacks/media
cp .env.example .env
```

编辑 `.env` 文件：

```bash
# 媒体存储路径
MEDIA_PATH=/data/media
DOWNLOAD_PATH=/data/downloads

# 时区
TZ=Asia/Shanghai

# 域名配置
DOMAIN=yourdomain.com
```

### 2. 创建目录结构

```bash
mkdir -p /data/media/movies /data/media/tv
mkdir -p /data/downloads/movies /data/downloads/tv
```

### 3. 启动服务

```bash
docker compose up -d
```

### 4. 访问服务

| 服务 | URL |
|------|-----|
| Jellyfin | https://jellyfin.${DOMAIN} |
| Sonarr | https://sonarr.${DOMAIN} |
| Radarr | https://radarr.${DOMAIN} |
| Prowlarr | https://prowlarr.${DOMAIN} |
| qBittorrent | https://bt.${DOMAIN} |
| Jellyseerr | https://request.${DOMAIN} |

## 📁 目录结构

遵循 [TRaSH Guides](https://trash-guides.info/Hardlinks/How-to-setup-for/Docker/) 硬链接最佳实践：

```
/data/
├── torrents/
│   ├── movies/
│   └── tv/
└── media/
    ├── movies/
    └── tv/
```

## ⚙️ 配置指南

### Sonarr 配置

1. 访问 https://sonarr.${DOMAIN}
2. 添加 qBittorrent 下载客户端：
   - Host: `qbittorrent`
   - Port: `8080`
   - 启用分类
3. 添加媒体库根目录：`/media/tv`

### Radarr 配置

1. 访问 https://radarr.${DOMAIN}
2. 添加 qBittorrent 下载客户端：
   - Host: `qbittorrent`
   - Port: `8080`
   - 启用分类
3. 添加媒体库根目录：`/media/movies`

### Jellyfin 配置

1. 访问 https://jellyfin.${DOMAIN}
2. 添加媒体库：
   - 电影：`/media/movies`
   - 剧集：`/media/tv`

### Prowlarr 配置

1. 访问 https://prowlarr.${DOMAIN}
2. 添加索引器（Torrent trackers）
3. 同步到 Sonarr/Radarr

### Jellyseerr 配置

1. 访问 https://request.${DOMAIN}
2. 配置媒体服务器（Jellyfin）
3. 配置 Radarr/Sonarr
4. 用户可提交观看请求

## 🔒 安全配置

### Authentik SSO 集成

在 Traefik 配置中添加 Forward Auth：

```yaml
labels:
  - traefik.http.middlewares.authentik.forwardauth.address=http://authentik:9000/outpost.goauthentik.io/auth/traefik
  - traefik.http.routers.sonarr.middlewares=authentik@docker
```

### 环境变量安全

- 所有密码通过 `.env` 管理
- 无硬编码凭证
- 使用 Docker secrets 管理敏感信息

## 🏥 健康检查

所有服务配置了健康检查：

```bash
docker compose ps
```

状态应为 `healthy`。

## 📊 监控

### Prometheus 指标

- Jellyfin: `http://jellyfin:8096/metrics`
- qBittorrent: 通过 exporter

### Grafana Dashboard

导入以下 Dashboard：
- Jellyfin Stats
- Download Client Status

## 🐛 故障排查

### 容器无法启动

```bash
docker compose logs <service>
```

### 健康检查失败

```bash
docker inspect <container> | grep -A 20 Health
```

### 权限问题

```bash
chown -R 1000:1000 /data/media /data/downloads
```

## 📝 常见问题

### Q: 如何配置硬链接？

A: 确保 Sonarr/Radarr 和 qBittorrent 使用相同的目录结构，启用硬链接选项。

### Q: Jellyfin 无法识别媒体？

A: 检查 `/media` 挂载路径，确保文件权限正确。

### Q: 如何启用 HTTPS？

A: Traefik 自动配置，确保域名 DNS 解析正确。

## 🔗 相关链接

- [TRaSH Guides](https://trash-guides.info/)
- [Jellyfin 文档](https://jellyfin.org/docs/)
- [Sonarr 文档](https://sonarr.tv/docs/)
- [Radarr 文档](https://radarr.video/docs/)

---

**赏金**: $200 USDT  
**Issue**: https://github.com/illbnm/homelab-stack/issues/2
