---
name: 💰 Bounty - Base Stack
about: 实现基础设施栈 (Traefik, Portainer, Watchtower)
title: '[BOUNTY $150] Base Stack — 基础设施'
labels: bounty, medium
assignees: ''
---

## 赏金金额

**$150 USDT**

## 任务描述

实现整个项目的基础设施层，所有其他 Stack 依赖此 Stack 运行。

## 服务清单

| 服务 | 镜像 | 用途 |
|------|------|------|
| Traefik | `traefik:v3.1.6` | 反向代理 + 自动 HTTPS |
| Portainer CE | `portainer/portainer-ce:2.21.3` | Docker 管理 UI |
| Watchtower | `containrrr/watchtower:1.7.1` | 容器自动更新 |
| Socket Proxy | `tecnativa/docker-socket-proxy:0.2.0` | 安全隔离 Docker socket |

## 文件结构

```
stacks/base/
├── docker-compose.yml
├── .env.example
└── README.md

config/traefik/
├── traefik.yml           # 静态配置
└── dynamic/
    ├── tls.yml           # TLS 选项
    └── middlewares.yml   # 通用中间件
```

## 核心要求

### 1. 共享网络

创建名为 `proxy` 的外部网络，所有其他 Stack 通过此网络接入 Traefik。

### 2. Traefik 配置

- 80 → 自动重定向 HTTPS
- 443 → TLS 终止
- Let's Encrypt 自动证书 (DNS Challenge 或 HTTP Challenge，可配置)
- Dashboard 通过 `traefik.${DOMAIN}` 访问，需 Basic Auth 保护
- Docker provider：仅读取有 `traefik.enable=true` 标签的容器

### 3. Docker Socket 安全

使用 `docker-socket-proxy` 隔离 Docker socket，Traefik 只读取必要 API。

### 4. Watchtower

- 每天凌晨 3 点扫描更新
- 仅更新有 `com.centurylinklabs.watchtower.enable=true` 标签的容器
- 更新完成后通过 Gotify/ntfy 发通知（与 Notifications Stack 集成）

### 5. 环境变量

```bash
DOMAIN=example.com
ACME_EMAIL=admin@example.com
TRAEFIK_AUTH=         # htpasswd 生成的用户名:密码
TZ=Asia/Shanghai
```

## 验收标准

- [ ] `docker compose up -d` 启动所有 4 个容器
- [ ] 所有容器健康检查通过
- [ ] `http://任意IP:80` 自动重定向到 HTTPS
- [ ] `traefik.${DOMAIN}` 可访问 Dashboard，需密码
- [ ] `portainer.${DOMAIN}` 可访问 Portainer
- [ ] 其他 Stack 容器可通过 `proxy` 网络被 Traefik 发现
- [ ] README 包含 DNS 配置说明、证书配置说明

## 认领方式

评论 "我来认领"。
