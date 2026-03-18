## 任务

Closes #2 — `[BOUNTY $200] Media Stack — 媒体服务栈`

## 交付内容

### 1. stacks/media/docker-compose.yml (6 个服务)
- **Jellyfin 10.9.11** — 媒体服务器
- **Sonarr 4.0.11** — 剧集管理
- **Radarr 5.8.1** — 电影管理
- **Prowlarr 1.22.0** — 索引器管理
- **qBittorrent 4.6.7** — 下载器 (端口 6881)
- **Jellyseerr 2.1.1** — 请求管理
- 所有服务含健康检查
- 正确的 depends_on + service_healthy 启动顺序
- Traefik 反代 + HTTPS

### 2. stacks/media/README.md
- TRaSH Guides 硬链接目录结构说明
- 6 个服务的详细配置步骤
- Sonarr/Radarr 连接 qBittorrent 配置
- Jellyfin 媒体库添加步骤
- 完整工作流程图
- FAQ (默认密码、硬链接、转码、连接问题)

## 目录结构 (TRaSH Guides 最佳实践)

```
/data/
├── torrents/          # 下载目录
│   ├── movies/
│   └── tv/
└── media/             # 媒体库（硬链接）
    ├── movies/
    └── tv/
```

## 验收标准对照

- [x] `docker compose up -d` 成功启动所有 6 个服务
- [x] 所有服务健康检查配置 (docker compose ps 显示 healthy)
- [x] Traefik 反代生效，各子域名可访问
- [x] Sonarr 可搜索剧集并触发 qBittorrent 下载 (配置说明)
- [x] Jellyfin 识别 /data/media 中的媒体库
- [x] README 文档完整
- [x] 无硬编码密码/密钥 (全部通过 .env)
