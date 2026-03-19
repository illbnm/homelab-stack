# Productivity Stack — 生产力工具套件

> 自托管生产力套件：代码托管、密码管理、团队知识库、文档 Wiki、PDF 工具、在线白板

## 服务清单

| 服务 | 镜像 | 访问地址 | 用途 |
|------|------|----------|------|
| Gitea | `gitea/gitea:1.22.3` | `https://git.${DOMAIN}` | Git 代码托管 + Actions |
| Gitea Runner | `gitea/act_runner:0.1.0` | 内部服务 | CI/CD 执行器 |
| Vaultwarden | `vaultwarden/server:1.32.0` | `https://vault.${DOMAIN}` | 密码管理器 |
| Outline | `outlinewiki/outline:0.80.2` | `https://docs.${DOMAIN}` | 团队知识库 |
| BookStack | `lscr.io/linuxserver/bookstack:24.10.20241031` | `https://wiki.${DOMAIN}` | 文档 Wiki |
| Stirling PDF | `frooodle/s-pdf:0.30.2` | `https://pdf.${DOMAIN}` | PDF 处理工具 |
| Excalidraw | `excalidraw/excalidraw:latest-sha` | `https://whiteboard.${DOMAIN}` | 在线白板 |

## 部署步骤

### 1. 配置环境变量

```bash
cd stacks/productivity
cp .env.example .env
nano .env
```

**必须配置的变量：**

```bash
# 通用
DOMAIN=yourdomain.com
TZ=Asia/Shanghai

# Gitea
GITEA_DB_PASSWORD=<强密码>
GITEA_OAUTH2_JWT_SECRET=<openssl rand -base64 32>

# Vaultwarden
VAULTWARDEN_ADMIN_TOKEN=<openssl rand -base64 48>
VAULTWARDEN_DB_PASSWORD=<强密码>

# Outline
OUTLINE_SECRET_KEY=<openssl rand -base64 32>
OUTLINE_UTILS_SECRET=<openssl rand -base64 32>
OUTLINE_DB_PASSWORD=<强密码>

# BookStack
BOOKSTACK_APP_KEY=<base64 随机 32 字符>
BOOKSTACK_DB_PASSWORD=<强密码>

# MinIO (Outline 存储)
MINIO_ROOT_PASSWORD=<强密码，至少 8 字符>

# SMTP (邮件通知)
SMTP_HOST=smtp.example.com
SMTP_PORT=587
SMTP_USER=user@example.com
SMTP_PASS=<密码>
```

### 2. 启动服务

```bash
# 确保共享数据库和 Redis 已启动
cd ../databases && docker compose up -d
cd ../storage && docker compose up -d   # MinIO

# 启动生产力套件
cd ../productivity
docker compose up -d
```

### 3. 配置 Authentik OIDC

```bash
# 获取 Authentik bootstrap token
export AUTHENTIK_BOOTSTRAP_TOKEN=<从 Authentik 初始设置获取>

# 运行配置脚本
../../scripts/setup-authentik.sh
```

脚本会自动创建以下 OIDC 提供商：
- Grafana
- Gitea
- Outline
- Portainer
- BookStack

### 4. 配置 Gitea Actions Runner

1. 首次登录 Gitea (使用 Authentik SSO)
2. 进入 **站点管理 → Runner**
3. 添加新 Runner，复制注册令牌
4. 更新 `.env` 中的 `GITEA_RUNNER_REGISTRATION_TOKEN`
5. 重启 Runner: `docker compose restart gitea-runner`

### 5. 配置 MinIO Bucket (Outline 存储)

```bash
# 访问 MinIO 控制台：https://minio.${DOMAIN}
# 登录 (使用 MINIO_ROOT_USER / MINIO_ROOT_PASSWORD)
# 创建 Bucket: outline
# 确保 Gitea/Outline 有读写权限
```

## 验收标准

- [ ] Gitea 可用 Authentik OIDC 登录，仓库推送正常
- [ ] Gitea Actions Runner 在线，可执行 CI/CD 任务
- [ ] Vaultwarden 浏览器扩展可连接，HTTPS 证书有效
- [ ] Vaultwarden 管理员可发送邀请邮件
- [ ] Outline 可用 Authentik 登录，文档编辑正常
- [ ] Outline 文件存储使用 MinIO (非本地)
- [ ] BookStack 可用 Authentik 登录，文档创建正常
- [ ] Stirling PDF 所有功能页面可访问
- [ ] Excalidraw 白板可创建和编辑
- [ ] 所有服务 Traefik 反代 + HTTPS 正常

## 国内镜像加速

如果 Docker Hub 拉取缓慢，可使用国内镜像：

```bash
# 在 .env 中启用 CN 模式
CN_MODE=true

# 或手动替换镜像
# Gitea: swr.cn-north-4.myhuaweicloud.com/ddn-k8s/docker.io/gitea/gitea:1.22.3
# Vaultwarden: swr.cn-north-4.myhuaweicloud.com/ddn-k8s/docker.io/vaultwarden/server:1.32.0
# Outline: swr.cn-north-4.myhuaweicloud.com/ddn-k8s/docker.io/outlinewiki/outline:0.80.2
# BookStack: swr.cn-north-4.myhuaweicloud.com/ddn-k8s/docker.io/linuxserver/bookstack:24.10.20241031
# Stirling PDF: swr.cn-north-4.myhuaweicloud.com/ddn-k8s/docker.io/frooodle/s-pdf:0.30.2
```

## 常见问题

### Vaultwarden 浏览器扩展无法连接

确保：
1. HTTPS 证书有效（检查 `https://vault.${DOMAIN}`）
2. `DOMAIN` 环境变量与实际访问地址一致
3. 浏览器扩展设置中填写完整的 `https://vault.${DOMAIN}`

### Outline 无法上传附件

检查：
1. MinIO 服务是否运行
2. Bucket `outline` 是否创建
3. `AWS_ACCESS_KEY_ID` 和 `AWS_SECRET_ACCESS_KEY` 是否正确
4. Outline 容器能否访问 MinIO 网络

### Gitea Runner 离线

1. 检查 `GITEA_RUNNER_REGISTRATION_TOKEN` 是否正确
2. 确认 Docker Socket 挂载：`/var/run/docker.sock:/var/run/docker.sock`
3. 查看日志：`docker logs gitea-runner`

### SMTP 邮件发送失败

1. 检查 SMTP 服务器地址和端口
2. 确认 `SMTP_SECURITY` 设置（starttls/tls/none）
3. 查看 Vaultwarden 日志：`docker logs vaultwarden | grep -i smtp`

## 服务依赖

```
productivity/
├── Gitea ────────┬──→ PostgreSQL (databases)
│                 └──→ Docker Socket (Actions)
├── Gitea Runner ─┴──→ Gitea
├── Vaultwarden ───────→ PostgreSQL (databases)
├── Outline ──────┬──→ PostgreSQL (databases)
│                 ├──→ Redis (databases)
│                 └──→ MinIO (storage)
├── BookStack ────────→ MariaDB (databases)
├── Stirling PDF ─────→ (独立)
└── Excalidraw ───────→ (独立)
```

## 相关文档

- [Gitea 文档](https://docs.gitea.com/)
- [Vaultwarden Wiki](https://github.com/dani-garcia/vaultwarden/wiki)
- [Outline 文档](https://docs.getoutline.com/)
- [BookStack 文档](https://www.bookstackapp.com/docs/)
- [Stirling PDF GitHub](https://github.com/Stirling-Tools/Stirling-PDF)
- [Excalidraw GitHub](https://github.com/excalidraw/excalidraw)
