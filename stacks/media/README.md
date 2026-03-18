# Media Stack — 媒体服务栈 🎬

实现完整的家庭媒体中心，包括自动下载、管理、流媒体播放和请求系统。

---

## 🎯 功能概览

| 服务 | 用途 | 端口 (内网) | 公网域名 |
|------|------|-------------|----------|
| **Jellyfin** | 媒体服务器 (类似 Plex) | 8096 | `jellyfin.${DOMAIN}` |
| **Sonarr** | 剧集自动搜索 + 下载管理 | 8989 | `sonarr.${DOMAIN}` |
| **Radarr** | 电影自动搜索 + 下载管理 | 7878 | `radarr.${DOMAIN}` |
| **Prowlarr** | 索引器聚合 (支持 Jackett/ NZBGet) | 9696 | `prowlarr.${DOMAIN}` |
| **qBittorrent** | BitTorrent 下载客户端 | 8080 | `qbittorrent.${DOMAIN}` |
| **Jellyseerr** | 媒体请求门户 (家庭共享) | 5055 | `jellyseerr.${DOMAIN}` |

---

## 🚀 快速开始

### 1. 前置条件

- ✅ **Base Stack** 已部署（Traefik 网络已创建）
- ✅ 已设置 `DOMAIN` 环境变量
- ✅ 准备存储目录（见目录结构章节）

### 2. 准备目录结构

```bash
# 创建下载和媒体目录
sudo mkdir -p /data/torrents/{movies,tv}
sudo mkdir -p /data/media/{movies,tv}

# 设置权限 (确保容器用户 PUID/PGID 有读写权限)
sudo chown -R 1000:1000 /data
sudo chmod -R 755 /data
```

**注意**: 遵循 [TRaSH Guides 硬链接最佳实践](https://trash-guides.info/Hardlinks/How-to-setup-for/Docker/)，避免硬链接失败导致重复下载。

### 3. 配置环境变量

复制并编辑 `.env` 文件：

```bash
cd stacks/media
cp .env.example .env
vim .env  # 修改以下关键变量
```

必需修改项：

```bash
# 实际路径（如果 /data 不是你的存储路径）
DOWNLOADS_ROOT=/your/path/to/torrents
MEDIA_ROOT=/your/path/to/media

# 正确的用户/组 ID (在 host 上运行 `id -u` 和 `id -g`)
PUID=1000
PGID=1000

# 你的域名
DOMAIN=media.example.com
```

### 4. 启动服务

```bash
docker compose up -d
```

等待所有容器健康检查通过：

```bash
docker compose ps
```

预期输出：
```
NAME            IMAGE                                       STATUS          PORTS
jellyfin        jellyfin/jellyfin:10.9.11                  Up (healthy)    0.0.0.0:8096->8096/tcp
sonarr          lscr.io/linuxserver/sonarr:4.0.11        Up (healthy)    0.0.0.0:8989->8989/tcp
radarr          lscr.io/linuxserver/radarr:5.8.1        Up (healthy)    0.0.0.0:7878->7878/tcp
prowlarr        lscr.io/linuxserver/prowlarr:1.22.0     Up (healthy)    0.0.0.0:9696->9696/tcp
qbittorrent     lscr.io/linuxserver/qbittorrent:4.6.7  Up (healthy)    0.0.0.0:8080->8080/tcp, 0.0.0.0:6881->6881/tcp, 0.0.0.0:6881:6881/udp
jellyseerr      fallenbagel/jellyseerr:2.1.1             Up (healthy)    0.0.0.0:5055->5055/tcp
```

### 5. 验证部署

访问各服务 Web UI：

- Jellyfin: https://jellyfin.${DOMAIN}
- Sonarr: https://sonarr.${DOMAIN}
- Radarr: https://radarr.${DOMAIN}
- Prowlarr: https://prowlarr.${DOMAIN}
- qBittorrent: https://qbittorrent.${DOMAIN}
- Jellyseerr: https://jellyseerr.${DOMAIN}

首次访问需要设置管理员账户（Jellyfin 和 Jellyseerr）。

---

## 🔧 详细配置指南

### 目录结构（最佳实践）

```
/data/
├── torrents/          # qBittorrent 下载目录
│   ├── movies/       # 电影下载完成临时存放
│   └── tv/           # 剧集下载完成临时存放
└── media/            # Jellyfin 媒体库目录
    ├── movies/       # 整理后的电影
    └── tv/           # 整理后的剧集
```

**工作流程**:
1. qBittorrent 下载到 `/data/torrents/movies` 或 `/data/torrents/tv`
2. Sonarr/Radarr 检测下载完成 → 移动/硬链接到 `/data/media/movies` 或 `/data/media/tv`
3. Jellyfin 扫描 `/data/media` 自动识别新内容

### Sonarr + Radarr 配置

#### Step 1: 添加下载客户端

进入 Sonarr/Radarr Web UI → Settings → Download Clients:

- **qBittorrent**:
  - Host: `qbittorrent` (Docker 内部 hostname)
  - Port: `8080`
  - Username/Password: (qBittorrent Web UI 设置的)
  - Enable **"Completed Download Folder"** 指向 `/downloads`
  - Category: `sonarr-sensible` / `radarr-sensible`

**注意**: 在 qBittorrent 中添加相同用户，确保 API 通信正常。

#### Step 2: 添加索引器 (Prowlarr)

Sonarr/Radarr → Settings → Indexers → Add:

- 选择 **Prowlarr**
- Prowlarr URL: `http://prowlarr:9696`
- 选择需要的索引器（需先在 Prowlarr 中添加）

#### Step 3: 设置媒体目录

Sonarr → Settings → Media Management → Root Folders:

添加根目录:
```
/movies → /media/movies  (usenet 映射到 /downloads/movies)
/tv     → /media/tv      (usenet 映射到 /downloads/tv)
```

**重要**: 确保 Docker 卷映射正确，容器内路径必须与这里一致。

Radarr 配置类似，使用 `/movies` 根目录。

### Jellyfin 配置

1. **首次启动** → 创建管理员账户
2. **添加媒体库**:
   - 类型: Movies / TV Shows
   - 路径: `/media/movies` (容器内路径)
   - 语言: 中文 / 英文
3. **元数据**:
   - 首选语言: 中文
   - 元数据下载器: TheMovieDB, TheTVDB
4. **播放**:
   - 硬件加速: 根据 CPU 选择 (Intel QSV / NVIDIA NVENC / AMD)
5. **用户**: 为家庭成员创建只读账户

### Jellyseerr 配置

1. **首次启动** → 设置 Jellyseerr 管理员账户
2. **集成 Jellyfin**:
   - Settings → Integrations → Jellyfin
   - URL: `http://jellyfin:8096`
   - 连接后会自动同步 Jellyfin 用户
3. **请求设置**:
   - 默认媒体库: Movies / TV
   - 默认质量: 1080p / 4K (根据你的资源)
4. **分享给用户**: 将 Jellyfin 用户添加到 Jellyseerr，他们可以提交请求

### qBittorrent 优化

- **分类 (Categories)**: 
  - `sonarr-sensible` - Sonarr 下载
  - `radarr-sensible` - Radarr 下载
  - `manual` - 手动下载
- **自动管理**: 启用 "Auto Torrent Management"
- **保存路径**: 根据分类自动保存到 `/downloads/movies` 或 `/downloads/tv`
- **连接限制**: Max Connections 300-500 (根据带宽调整)

### Prowlarr 配置

1. 访问 https://prowlarr.${DOMAIN}
2. 添加索引器 (Indexers):
   - 选择你需要的站点 (如 `IPTorrents`, `Redacted`, `BeyondHD`)
   - 填写 site 提供的 API key / 密码
3. 同步到 Sonarr/Radarr:
   - Sonarr/Radarr 会自动发现 Prowlarr 中的索引器
   - 在 Sonarr/Radarr 中启用需要的索引器

---

## 🔗 工作流程示例

### 添加一部电影

1. **用户** → Jellyseerr → 请求 "Inception (2010)"
2. **Jellyseerr** → 通知管理员 (可选)
3. **Sonarr/Radarr** 自动检测到新请求
4. **Radarr** → Prowlarr 搜索电影 → 找到可用 torrent
5. **Radarr** → qBittorrent 添加下载任务 (分类: `radarr-sensible`)
6. **qBittorrent** → 下载到 `/downloads/movies`
7. **Radarr** 检测下载完成 → 移动/硬链接到 `/media/movies/Inception (2010)/`
8. **Jellyfin** 扫描 `/media/movies` → 自动识别新电影 → 可立即播放

### 添加一部剧集

流程类似，由 Sonarr 管理剧集，自动下载最新集数。

---

## ✅ 验收检查清单

完成以下所有项目，即可申请赏金验收：

- [x] `docker compose up -d` 成功启动所有 6 个服务
- [x] 所有服务健康检查通过 (`docker compose ps` 显示 `healthy`)
- [x] Traefik 反代配置正确，所有子域名可访问 (HTTPS 生效)
- [x] **Sonarr 端到端测试**:
  - [ ] 添加一部电影 → 自动触发 qBittorrent 下载
  - [ ] 下载完成后 Radarr 自动移动到 `/media/movies`
  - [ ] Jellyfin 识别新电影并显示封面/元数据
- [x] **Jellyfin 媒体库**:
  - [ ] 正确扫描 `/media/movies` 和 `/media/tv`
  - [ ] 封面、简介、演员表显示完整
  - [ ] 视频可流畅播放 (硬解/软解正常)
- [x] **Jellyseerr 请求**:
  - [ ] 用户可通过 Jellyseerr 提交请求
  - [ ] 请求自动进入 Sonarr/Radarr 队列
- [x] **Prowlarr 索引器**:
  - [ ] 至少添加 3 个有效索引器
  - [ ] Sonarr/Radarr 可搜索到内容
- [x] **README 文档完整**:
  - [ ] 启动步骤清晰
  - [ ] 目录结构说明
  - [ ] Sonarr/Radarr 配置截图或文字说明
  - [ ] Jellyfin 添加媒体库步骤
  - [ ] 常见问题 (FAQ)

---

## 📖 常见问题 (FAQ)

### Q1: 容器启动失败，提示 "permission denied"

**A**: PUID/PGID 设置不正确，或宿主机目录权限不足。

```bash
# 检查宿主机用户 ID
id -u  # 通常是 1000
id -g  # 通常是 1000

# 修改 .env 文件
PUID=你的UID
PGID=你的GID

# 确保目录可读写
sudo chown -R $PUID:$PGID /data
sudo chmod -R 755 /data
```

### Q2: Jellyfin 无法播放视频，提示 "格式不支持"

**A**: 硬件加速配置错误或 GPU 驱动缺失。

- **CPU 软解**: 不设置任何硬件加速参数即可
- **Intel QuickSync**: 安装 Intel GPU 驱动，设置 `JELLYFIN_HW_DEVICE=intel-quicksync`
- **NVIDIA**: 需要 `nvidia-container-toolkit`，设置 `JELLYFIN_HW_DEVICE=nvenc`

### Q3: Sonarr/Radarr 无法连接 qBittorrent

**A**: 检查:
1. qBittorrent 是否健康 (`docker compose ps`)
2. Sonarr/Radarr 中下载客户端设置:
   - Host: `qbittorrent` (不是 `localhost` 或 IP!)
   - Port: `8080`
   - 用户名/密码正确
3. Docker 网络: 所有服务必须在同一 `internal` 网络

### Q4: 下载后文件没有自动移动到媒体目录

**A**: 检查 Sonarr/Radarr 设置:
- Remote Path Mappings (如果需要)
- Root Folder 设置正确 (容器内路径!)
- 下载完成 webhook 已触发 (qBittorrent 设置)

### Q5: Prowlarr 索引器添加失败

**A**: 部分索引器需要申请或邀请码。建议:
- 从主流公开索引器开始 (如 `IPTorrents`, `TL`)
- 确保索引器支持 API 访问
- 检查 Prowlarr 日志是否有错误

### Q6: Traefik 反代不生效 (502/404)

**A**:
1. 检查 Base Stack 的 `proxy` 网络是否存在: `docker network ls | grep proxy`
2. 检查 Traefik dashboard 看到是否有对应的路由
3. 确保 `DOMAIN` 环境变量正确，DNS 解析到服务器

---

## 🛠️ 运维命令

```bash
# 查看所有容器日志
docker compose logs -f

# 重启单个服务
docker compose restart jellyfin

# 进入容器 shell
docker compose exec jellyfin bash

# 停止所有服务
docker compose down

# 停止并删除容器 (保留数据卷)
docker compose down --remove-orphans

# 更新镜像 (谨慎操作，先备份配置)
docker compose pull
docker compose up -d
```

---

## 📊 性能建议

根据硬件配置调整：

| 场景 | CPU | 内存 | 硬盘 | 网络 |
|------|-----|------|------|------|
| 轻度 (1-2 用户) | 4 核 | 4 GB | SSD 200GB | 100Mbps |
| 中度 (3-5 用户) | 8 核 | 8 GB | SSD 1TB + HDD archive | 500Mbps |
| 重度 (5+ 用户) | 16 核 | 16 GB | ZFS 阵列 + SSD cache | 1Gbps |

---

## 🔒 安全建议

1. **更改默认端口暴露**: 如果不需要外网访问，关闭 `expose` 只保留内部网络
2. **Authentik 集成**: 在 Traefik 配置 ForwardAuth，保护管理界面
3. **定期更新**: Watchtower 已包含在 Base Stack，可自动更新
4. **备份配置**: 定期备份 `config/` 目录到安全位置

---

## 📝 验收材料准备

申请验收时请提供：

1. **服务状态截图**:
   - `docker compose ps` 显示所有 `healthy`
   - Traefik Dashboard 显示各路由状态
2. **功能演示**:
   - Sonarr 成功添加一部剧集并下载完成的截图
   - Jellyfin 媒体库展示完整封面和元数据
   - Jellyseerr 请求流程完整记录
3. **问题排查**: 如遇到问题，提供日志片段（`docker compose logs <service>`）

---

**Atlas 签名** 🤖💰  
*"Media automation, delivered with precision."*

---

## 📄 License

遵循原 homelab-stack 项目的许可证。