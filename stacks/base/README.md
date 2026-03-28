# Base Infrastructure Stack

基础基础设施栈，为所有其他服务栈提供反向代理、SSL证书自动签发、Docker 管理和自动更新功能。

## 📋 服务清单

| 服务 | 镜像 | 用途 |
|------|------|------|
| Traefik | traefik:v3.1.6 | 反向代理 + 自动 HTTPS |
| Socket Proxy | tecnativa/docker-socket-proxy:0.2.0 | Docker socket 安全隔离 |
| Portainer CE | portainer/portainer-ce:2.21.3 | Docker 容器管理 UI |
| Watchtower | containrrr/watchtower:1.7.1 | 容器自动更新 |

## 🚀 前置准备

### 1. 创建共享网络

所有其他 Stack 需要通过 `proxy` 外部网络接入 Traefik，先创建网络：

```bash
docker network create proxy
```

### 2. 配置 DNS

将以下域名解析到你的 homelab 服务器 IP：
- `traefik.${DOMAIN}` - Traefik 控制面板
- `portainer.${DOMAIN}` - Portainer 管理界面

如果你使用 DNS Challenge 签发证书，需要配置相应的 API 密钥。

### 3. 创建目录和配置环境

```bash
# 创建 ACME 证书存储目录
mkdir -p /path/to/homelab-stack/acme
chmod 600 /path/to/homelab-stack/acme

# 复制环境变量文件
cp stacks/base/.env.example stacks/base/.env
nano stacks/base/.env  # 编辑配置
```

### 4. 生成 Traefik 控制面板密码

使用 `htpasswd` 生成 Basic Auth 凭据：

```bash
# Install htpasswd if needed (Debian/Ubuntu)
apt install apache2-utils

# Generate credentials
htpasswd -nb username yourpassword
```

将输出复制到 `.env` 文件中的 `TRAEFIK_AUTH` 变量。

## ⚙️ 配置说明

### Traefik 配置

- **自动重定向：** 所有 HTTP (80) 流量自动重定向到 HTTPS (443)
- **Let's Encrypt：** 默认使用 HTTP Challenge 签发证书
- **证书存储：** 证书存储在 `./acme` 目录
- **Dashboard：** 通过 `traefik.${DOMAIN}` 访问，受 Basic Auth 保护
- **Docker Provider：** 默认只暴露有 `traefik.enable=true` 标签的容器

### DNS Challenge 配置（可选）

如果你想使用 DNS Challenge，编辑 `config/traefik/traefik.yml`：

```yaml
certificatesResolvers:
  letsencrypt:
    acme:
      email: "{{ .Env.ACME_EMAIL }}"
      storage: "/acme/acme.json"
#      httpChallenge:
#        entryPoint: http
      dnsChallenge:
        provider: cloudflare  # 更改为你的 DNS 提供商
        delayBeforeChecking: 60
        propagationTimeout: 600
```

然后在 `docker-compose.yml` 的 Traefik 服务中添加相应的环境变量，例如 Cloudflare：

```yaml
environment:
  - CLOUDFLARE_EMAIL=your@email.com
  - CLOUDFLARE_API_KEY=your_api_key
```

更多 DNS 提供商配置请参考 [Traefik 文档](https://doc.traefik.io/traefik/https/acme/#providers)

### Docker Socket 安全

使用 `docker-socket-proxy` 对 Docker socket 进行安全隔离，只允许 Traefik 访问必要的 API：
- ✅ 允许读取容器、服务、网络信息
- ❌ 禁止访问插件、节点、Swarm 管理

### Watchtower 配置

- **更新时间：** 每天凌晨 3 点扫描更新
- **选择性更新：** 只更新有 `com.centurylinklabs.watchtower.enable=true` 标签的容器
- **通知：** 可配置 Gotify/ntfy 通知，与 Notifications 栈集成
- **轮询间隔：** 默认 24 小时检查一次

## 🚀 启动服务

```bash
cd stacks/base
docker compose up -d
```

检查容器状态：

```bash
docker compose ps
```

所有容器状态应该显示 `Up (healthy)`。

## ✅ 验收检查

1. ✅ 访问 `http://your-server-ip` 应该自动重定向到 `https://traefik.${DOMAIN}`
2. ✅ `traefik.${DOMAIN}` 弹出密码框，输入正确用户名密码后能看到 Traefik 控制面板
3. ✅ `portainer.${DOMAIN}` 能访问 Portainer 初始化界面
4. ✅ 所有容器健康检查通过

## 🔧 使用指南

### 添加新服务到 Traefik

在新服务的 `docker-compose.yml` 中添加以下配置：

```yaml
networks:
  default:
  proxy:
    external: true

services:
  your-service:
    # ... other configuration
    networks:
      - default
      - proxy
    labels:
      - traefik.enable=true
      - traefik.http.routers.your-service.rule=Host(`service.${DOMAIN}`)
      - traefik.http.routers.your-service.entrypoints=https
      - traefik.http.routers.your-service.tls=true
      - traefik.http.routers.your-service.tls.certresolver=letsencrypt
      - traefik.http.services.your-service.loadbalancer.server.port=80
      - traefik.http.routers.your-service.middlewares=security-headers@file
```

### 启用自动更新

给需要自动更新的容器添加标签：

```yaml
labels:
  - com.centurylinklabs.watchtower.enable=true
```

### 手动触发更新

```bash
docker compose --project-name base run --rm watchtower --run-once
```

## 📝 文件结构

```
stacks/base/
├── docker-compose.yml    # Docker Compose 配置
├── .env.example          # 环境变量示例
└── README.md             # 本文件

config/traefik/
├── traefik.yml           # Traefik 静态配置
└── dynamic/
    ├── tls.yml           # TLS 安全配置
    └── middlewares.yml   # 通用中间件配置
```

## 🔒 安全特性

- TLS 1.2+ 最低要求
- 安全响应头默认启用
- Docker socket 权限隔离
- 仅暴露显式启用的服务
- 密码保护管理界面

## 📚 依赖

- Docker 20.10+
- Docker Compose v2+
