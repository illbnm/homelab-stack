---
name: 💰 Bounty - Productivity Stack
about: 实现生产力工具栈 (Gitea, Vaultwarden, Outline, Stirling PDF)
title: '[BOUNTY $160] Productivity Stack — 生产力工具'
labels: bounty, medium
assignees: ''
---

## 赏金金额

**$160 USDT**

## 任务描述

实现自托管生产力套件，覆盖代码托管、密码管理、团队知识库、PDF 工具。

## 服务清单

| 服务 | 镜像 | 用途 |
|------|------|------|
| Gitea | `gitea/gitea:1.22.2` | Git 代码托管 |
| Vaultwarden | `vaultwarden/server:1.32.0` | 密码管理器 (Bitwarden 兼容) |
| Outline | `outlinewiki/outline:0.80.2` | 团队知识库 |
| Stirling PDF | `frooodle/s-pdf:0.30.2` | PDF 处理工具 |
| Excalidraw | `excalidraw/excalidraw:latest-sha` | 在线白板 |

## 核心要求

### 1. Gitea

- 使用共享 PostgreSQL
- 配置 Authentik OIDC 登录
- 禁用注册（仅管理员创建账号）
- 配置 Gitea Actions runner

### 2. Vaultwarden

- **必须** HTTPS（浏览器扩展要求）
- 禁用公开注册，仅 admin 可邀请
- 配置 `ADMIN_TOKEN` 保护管理界面
- 配置 SMTP 邮件通知

### 3. Outline

- 使用共享 PostgreSQL + Redis
- 配置 Authentik OIDC
- MinIO 作为文件存储后端

### 4. 环境变量

```bash
GITEA_DB_PASSWORD=
VAULTWARDEN_ADMIN_TOKEN=
OUTLINE_SECRET_KEY=
OUTLINE_UTILS_SECRET=
SMTP_HOST=
SMTP_PORT=
SMTP_USER=
SMTP_PASS=
```

## 验收标准

- [ ] Gitea 可用 Authentik OIDC 登录，仓库推送正常
- [ ] Vaultwarden 浏览器扩展可连接，HTTPS 证书有效
- [ ] Outline 可用 Authentik 登录，文档编辑正常
- [ ] Stirling PDF 所有功能页面可访问
- [ ] 所有服务 Traefik 反代 + HTTPS 正常

## 认领方式

评论 "我来认领"。
