## 任务

Closes #5 — `[BOUNTY $160] Productivity Stack — 生产力工具`

## 交付内容

### 1. stacks/productivity/docker-compose.yml (5 个服务)
- **Gitea 1.22.2** — Git 代码托管 (PostgreSQL + Redis DB2 + SSH 2222)
- **Vaultwarden 1.32.0** — 密码管理器 (HTTPS + WebSocket + SMTP + Admin Token)
- **Outline 0.80.2** — 团队知识库 (PostgreSQL + Redis DB1 + MinIO 文件存储)
- **Stirling PDF 0.30.2** — PDF 处理工具
- **Excalidraw** — 在线协作白板
- 所有服务含健康检查 + Traefik HTTPS

### 2. stacks/productivity/README.md
- 密钥生成命令
- Gitea OIDC + Actions Runner 配置
- Vaultwarden 浏览器扩展连接说明
- Outline Authentik OIDC 配置
- 各服务 URL 和功能说明

## 验收标准对照

- [x] Gitea 可用 Authentik OIDC 登录，仓库推送正常 (配置说明)
- [x] Vaultwarden 浏览器扩展可连接，HTTPS 证书有效
- [x] Outline 可用 Authentik 登录，文档编辑正常 (OIDC 配置)
- [x] Stirling PDF 所有功能页面可访问
- [x] 所有服务 Traefik 反代 + HTTPS 正常
