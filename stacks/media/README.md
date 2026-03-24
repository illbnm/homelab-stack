# 🍿 Media Stack — Jellyfin, Sonarr, Radarr, Prowlarr, qBittorrent, Jellyseerr

完整的媒体服务栈，遵循 [TRaSH Guides](https://trash-guides.info/Hardlinks/How-to-setup-for/Docker/) 硬链接最佳实践。

## 📦 服务列表

| 服务 | 镜像 | 内部端口 | 用途 | 访问地址 |
|------|------|---------|------|----------|
| Jellyfin | `jellyfin/jellyfin:10.9.11` | 8096 | 媒体服务器 | `jellyfin.${DOMAIN}` |
| Sonarr | `lscr.io/linuxserver/sonarr:4.0.11` | 8989 | 剧集管理 | `sonarr.${DOMAIN}` |
| Radarr | `lscr.io/linuxserver/radarr:5.8.1` | 7878 | 电影管理 | `radarr.${DOMAIN}` |
| Prowlarr | `lscr.io/linuxserver/prowlarr:1.22.0` | 9696 | 索引器管理 | `prowlarr.${DOMAIN}` |
| qBittorrent | `lscr.io/linuxserver/qbittorrent:4.6.7` | 8080 | 下载器 | `qbittorrent.${DOMAIN}` |
| Jellyseerr | `fallenbagel/jellyseerr:2.1.1` | 5055 | 请求管理 | `jellyseerr.${DOMAIN}` |

## 🏗️ 架构图

```
                    ┌─────────────────┐
                    │   Jellyseerr    │
                    │  (请求管理)      │
                    └────────┬────────┘
                             │
           ┌─────────────────┼─────────────────┐
           │                 │                 │
           ▼                 ▼                 ▼
    ┌──────────────┐  ┌──────────────┐  ┌──────────────┐
    │   Jellyfin   │  │    Sonarr    │  │    Radarr    │
    │ (媒体服务器)  │  │  (剧集管理)   │  │  (电影管理)   │
    └──────────────┘  └──────┬───────┘  └──────┬───────┘
                             │                 │
                             └────────┬────────┘
                                      │
                    ┌─────────────────┼─────────────────┐
                    │                 │                 │
                    ▼                 ▼                 ▼
             ┌──────────────┐  ┌──────────────┐  ┌──────────────┐
             │  Prowlarr    │  │ qBittorrent  │  │   Storage    │
             │ (索引器管理)  │  │   (下载器)    │  │ /data/media  │
             └──────────────┘  └──────────────┘  │ /data/torrents│
                                                 └──────────────┘
```

## 🗂️ 目录结构 (TRaSH Guides 硬链接)

此配置遵循 TRaSH Guides 最佳实践，启用硬链接功能，避免文件复制占用双倍空间。

```
/data/                           (主机挂载点)
├── torrents/                    (DOWNLOADS_ROOT)
│   ├── movies/                  (qBittorrent 电影下载目录)
│   └── tv/                      (qBittorrent 剧集下载目录)
└── media/                       (MEDIA_ROOT)
    ├── movies/                  (Jellyfin/Radarr 电影媒体库)
    └── tv/                      (Jellyfin/Sonarr 剧集媒体库)
```

**重要说明**: `MEDIA_ROOT` 和 `DOWNLOADS_ROOT` **必须在同一文件系统**，硬链接才能正常工作！

## 🚀 快速开始

### 1. 创建目录

```bash
# 创建下载和媒体目录
mkdir -p /data/torrents/movies /data/torrents/tv
mkdir -p /data/media/movies /data/media/tv

# 设置权限 (使用与 PUID/PGID 相同的用户)
chown -R 1000:1000 /data
```

### 2. 配置环境变量

```bash
cd stacks/media
cp .env.example .env
nano .env  # 编辑配置
```

**必填配置项**:
- `DOMAIN` — 你的域名 (如 `home.example.com`)
- `PUID`/`PGID` — 用户/组ID (运行 `id -u` 和 `id -g` 查看)
- `TZ` — 时区 (如 `Asia/Shanghai`)
- `MEDIA_ROOT` — 媒体库路径
- `DOWNLOADS_ROOT` — 下载路径

### 3. 启动服务

```bash
docker compose up -d
```

### 4. 验证服务状态

```bash
docker compose ps
```

所有服务应显示 `healthy` 状态。

## ⚙️ 初始配置步骤

### 1. qBittorrent (`https://qbittorrent.${DOMAIN}`)

1. 默认用户名: `admin`
2. 默认密码: `adminadmin` (首次登录后立即修改!)
3. 设置 → 下载:
   - 默认保存路径: `/downloads`
4. 设置 → Web UI:
   - 修改密码

### 2. Prowlarr (`https://prowlarr.${DOMAIN}`)

1. 完成初始设置向导
2. 设置 → 索引器:
   - 添加你的 Tracker (如 1337x, RARBG 等)
3. 设置 → 应用程序:
   - 添加 Sonarr (主机: `http://sonarr:8989`)
   - 添加 Radarr (主机: `http://radarr:7878`)
4. 点击"同步索引器"

### 3. Sonarr (`https://sonarr.${DOMAIN}`)

**媒体管理**:
1. 设置 → 媒体管理 → 根文件夹:
   - 添加 `/data/media/tv`
2. 启用"使用硬链接而不是复制"

**下载客户端**:
1. 设置 → 下载客户端 → 添加 → qBittorrent:
   - 主机: `qbittorrent`
   - 端口: `8080`
   - 用户名: `admin`
   - 密码: (你设置的密码)
   - 分类: `sonarr`
2. 远程路径映射:
   - 主机: `qbittorrent`
   - 远程路径: `/downloads`
   - 本地路径: `/data/torrents`

**索引器**:
1. 设置 → 索引器 → 添加 → Prowlarr:
   - 主机: `prowlarr`
   - 端口: `9696`
   - API 密钥: (从 Prowlarr 设置获取)

### 4. Radarr (`https://radarr.${DOMAIN}`)

**与 Sonarr 配置类似**:
1. 根文件夹: `/data/media/movies`
2. 下载客户端: qBittorrent (分类: `radarr`)
3. 远程路径映射: 同 Sonarr
4. 索引器: Prowlarr

### 5. Jellyfin (`https://jellyfin.${DOMAIN}`)

1. 完成初始设置向导
2. 添加媒体库:
   - 电影: `/data/media/movies`
   - 剧集: `/data/media/tv`
3. 设置 → API 密钥:
   - 创建新密钥 (供 Jellyseerr 使用)

### 6. Jellyseerr (`https://jellyseerr.${DOMAIN}`)

1. 使用 Jellyfin 账户登录
2. 配置 Jellyfin:
   - 服务器 URL: `http://jellyfin:8096`
   - API 密钥: (从 Jellyfin 获取)
3. 配置 Sonarr:
   - 服务器 URL: `http://sonarr:8989`
   - API 密钥: (从 Sonarr 获取)
4. 配置 Radarr:
   - 服务器 URL: `http://radarr:7878`
   - API 密钥: (从 Radarr 获取)

## 🔧 环境变量说明

| 变量 | 必填 | 默认值 | 说明 |
|------|------|--------|------|
| `DOMAIN` | ✅ | - | 基础域名 |
| `PUID` | ✅ | 1000 | 用户ID |
| `PGID` | ✅ | 1000 | 组ID |
| `TZ` | ✅ | Asia/Shanghai | 时区 |
| `MEDIA_ROOT` | ✅ | /data/media | 媒体库路径 |
| `DOWNLOADS_ROOT` | ✅ | /data/torrents | 下载路径 |
| `QBT_WEBUI_PORT` | ❌ | 8080 | qBittorrent WebUI 端口 |
| `QBT_TORRENTING_PORT` | ❌ | 6881 | qBittorrent 下载端口 |
| `TRAEFIK_MIDDLEWARES_DEFAULT` | ❌ | traefik-secured-headers@docker | 默认安全中间件 |
| `TRAEFIK_MIDDLEWARES_AUTH` | ❌ | - | Authentik 认证中间件 |

## ❓ 常见问题

### 权限问题

如果容器无法写入目录:
```bash
# 检查 PUID/PGID
id -u  # PUID
id -g  # PGID

# 修复权限
chown -R 1000:1000 /data
```

### 硬链接不工作

确保 `MEDIA_ROOT` 和 `DOWNLOADS_ROOT` 在同一文件系统:
```bash
df -h /data/media /data/torrents
# 应该显示相同的 Filesystem
```

### Traefik 无法访问

1. 确认 `proxy` 网络存在: `docker network ls | grep proxy`
2. 确认 DNS 解析正确指向服务器
3. 检查 Traefik 日志: `docker logs traefik`

### 服务启动失败

检查服务依赖和健康状态:
```bash
docker compose ps
docker compose logs <service-name>
```

## 🔒 安全建议

1. **修改默认密码**: qBittorrent 默认密码必须修改
2. **启用 HTTPS**: Traefik 自动处理 Let's Encrypt 证书
3. **网络隔离**: 所有服务仅通过 Traefik 暴露
4. **可选认证**: 配置 `TRAEFIK_MIDDLEWARES_AUTH` 启用 Authentik 保护

## 📚 相关链接

- [TRaSH Guides](https://trash-guides.info/) — 硬链接和媒体管理最佳实践
- [Jellyfin 文档](https://jellyfin.org/docs/)
- [Sonarr Wiki](https://wiki.servarr.com/sonarr)
- [Radarr Wiki](https://wiki.servarr.com/radarr)
- [Prowlarr Wiki](https://wiki.servarr.com/prowlarr)
- [Jellyseerr 文档](https://docs.jellyseerr.dev/)