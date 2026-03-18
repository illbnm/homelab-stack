# Productivity Stack

自托管生产力工具套件。

## 服务列表

| 服务 | 子域名 | 说明 |
|------|--------|------|
| **Gitea** | `git.${DOMAIN}` | Git 代码托管，共享 PostgreSQL |
| **Vaultwarden** | `vault.${DOMAIN}` | Bitwarden 兼容密码管理器 |
| **Outline** | `docs.${DOMAIN}` | 团队知识库，需 PostgreSQL + Redis |
| **BookStack** | `wiki.${DOMAIN}` | 文档管理，需 MariaDB |
| **Stirling PDF** | `pdf.${DOMAIN}` | PDF 处理工具（合并/拆分/转换等） |
| **Excalidraw** | `draw.${DOMAIN}` | 在线白板绘图 |

## 快速启动

```bash
cp .env.example .env
# 编辑 .env 填写所有必填值
docker compose up -d
```

## 前置条件

- **Databases Stack** 已启动（PostgreSQL, Redis, MariaDB）
- **Base Stack** 已启动（Traefik 反向代理 + proxy 网络）
- `.env` 中数据库密码必须与 databases stack 一致

## 环境变量

参见 `.env.example`，关键变量：

| 变量 | 说明 |
|------|------|
| `DOMAIN` | 主域名 |
| `GITEA_DB_PASSWORD` | Gitea 数据库密码 |
| `VAULTWARDEN_ADMIN_TOKEN` | Vaultwarden 管理令牌 |
| `OUTLINE_SECRET_KEY` | Outline 密钥 |
| `REDIS_PASSWORD` | Redis 密码（与 databases stack 一致） |

## 注意事项

- **Vaultwarden 必须配置 HTTPS**（Traefik 自动处理），否则浏览器扩展无法连接
- **Vaultwarden 禁用了公开注册**，通过管理员邀请创建账号
- **Gitea** 已锁定安装，禁用自助注册，建议通过 Authentik OIDC 登录
- **Outline** 需要配置 OIDC（Authentik）才能登录
- **Stirling PDF** 默认禁用登录（内网使用），如需安全可启用 `DOCKER_ENABLE_SECURITY`
