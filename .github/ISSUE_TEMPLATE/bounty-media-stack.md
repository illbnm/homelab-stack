---
name: 💰 Bounty - Media Stack
about: 实现媒体服务栈 (Jellyfin, Sonarr, Radarr, Prowlarr, qBittorrent, Jellyseerr)
title: '[BOUNTY $200] Media Stack — 媒体服务栈'
labels: bounty, medium
assignees: ''
---

## 赏金金额

**$200 USDT** (或等值法币)

## 任务描述

实现完整的媒体服务栈，包含以下服务：

| 服务 | 镜像 | 用途 |
|------|------|------|
| Jellyfin | `jellyfin/jellyfin:10.9.11` | 媒体服务器 |
| Sonarr | `lscr.io/linuxserver/sonarr:4.0.11` | 剧集管理 |
| Radarr | `lscr.io/linuxserver/radarr:5.8.1` | 电影管理 |
| Prowlarr | `lscr.io/linuxserver/prowlarr:1.22.0` | 索引器管理 |
| qBittorrent | `lscr.io/linuxserver/qbittorrent:4.6.7` | 下载器 |
| Jellyseerr | `fallenbagel/jellyseerr:2.1.1` | 请求管理 |

## 文件结构

```
stacks/media/
├── docker-compose.yml
├── .env.example
└── README.md
```

## 要求

### 1. 目录结构

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

### 2. 环境变量

通过 `.env` 管理：

- `MEDIA_ROOT` — 媒体目录
- `DOWNLOADS_ROOT` — 下载目录
- `PUID` / `PGID` / `TZ`
- 各服务密码

### 3. Traefik 配置

- 每个服务暴露子域名：`jellyfin.${DOMAIN}`, `sonarr.${DOMAIN}`, ...
- HTTPS 自动证书
- 可选：Authentik Forward Auth 保护

### 4. 健康检查

每个容器必须有 `healthcheck` 配置。

### 5. 启动顺序

`depends_on` + `condition: service_healthy` 确保正确启动顺序。

### 6. README 内容

- 服务功能说明
- 启动命令
- 目录结构说明
- Sonarr/Radarr 连接 qBittorrent 的配置步骤
- Jellyfin 媒体库添加步骤
- 常见问题 (FAQ)

## 验收标准

- [ ] `docker compose up -d` 成功启动所有 6 个服务
- [ ] 所有服务健康检查通过 (`docker compose ps` 显示 healthy)
- [ ] Traefik 反代生效，各子域名可访问
- [ ] Sonarr 可以搜索剧集并触发 qBittorrent 下载
- [ ] Jellyfin 识别 `/data/media` 中的媒体库
- [ ] README 文档完整
- [ ] 无硬编码密码/密钥

## 认领方式

在下方评论 "我来认领"，确认后开始开发。

## 支付

验收通过后 3 个工作日内支付 USDT (TRC20) 或等值法币。
