# Base Infrastructure Stack

整个项目的基础设施层，所有其他 Stack 依赖此 Stack 运行。

## 服务架构

```
┌─────────────────────────────────────────────────────────┐
│                  Base Infrastructure Stack                    │
├─────────────────────────────────────────────────────────┤
│                                                          │
│   Traefik                                               │
│   ├── 反向代理                                          │
│   ├── 自动 HTTPS 证书                                   │
│   └── Docker 服务发现                                   │
│                                                          │
│   Portainer CE                                          │
│   ├── Docker 容器管理 UI                               │
│   └── 环境/配置可视化                                  │
│                                                          │
│   Watchtower                                            │
│   ├── 容器自动更新                                     │
│   └── 凌晨 4 点扫描更新                               │
│                                                          │
│   Docker Socket Proxy                                   │
│   ├── Docker Socket 安全隔离                           │
│   └── Traefik 仅读取必要 API                          │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

## 服务列表

| 服务 | 地址 | 用途 |
|------|------|------|
| Traefik Dashboard | https://traefik.${DOMAIN} | 反向代理管理 |
| Portainer | https://portainer.${DOMAIN} | 容器管理 UI |

## 快速开始

### 1. 前置条件

```bash
# 创建共享网络
docker network create proxy

# 创建 Traefik ACME 文件
mkdir -p config/traefik
touch config/traefik/acme.json
chmod 600 config/traefik/acme.json
```

### 2. 配置环境变量

```bash
cd homelab-stack/stacks/base
cp .env.example .env
nano .env
```

必须配置：
```env
DOMAIN=yourdomain.com
ACME_EMAIL=admin@yourdomain.com
TZ=Asia/Shanghai
```

### 3. 生成 Dashboard 认证密码

```bash
# 安装 apache2-utils (Debian/Ubuntu)
sudo apt install apache2-utils

# 生成密码
htpasswd -nb admin yourpassword | tr -d ':\n' | sed 's/$/$/'
```

将生成的字符串填入 `config/traefik/dynamic/middlewares.yml` 的 `users` 部分。

### 4. 启动

```bash
docker compose up -d
```

### 5. 验证

```bash
# 检查容器状态
docker compose ps

# 访问 Traefik Dashboard
open https://traefik.yourdomain.com

# 访问 Portainer
open https://portainer.yourdomain.com
```

## 网络架构

所有其他 Stack 通过加入 `proxy` 网络来被 Traefik 发现：

```yaml
# 在其他 stack 的 docker-compose.yml 中
services:
  my-service:
    networks:
      - proxy  # 添加到 proxy 网络
    labels:
      - traefik.enable=true
      - "traefik.http.routers.my-service.rule=Host(`my-service.${DOMAIN}`)"
      - traefik.http.routers.my-service.entrypoints=websecure
      - traefik.http.routers.my-service.tls=true
```

## Traefik 配置

### 静态配置 (config/traefik/traefik.yml)

定义证书解析器、提供者等。

### 动态配置 (config/traefik/dynamic/)

- `middlewares.yml` — 中间件（认证、安全头等）
- `tls.yml` — TLS 选项

### 自动 HTTPS

Traefik 自动为所有带有 `traefik.enable=true` 标签的服务申请 Let's Encrypt 证书。

## Watchtower

### 功能

- 每天凌晨 4:00 检查更新
- 自动拉取新镜像
- 重启容器应用更新
- 清理旧镜像

### 通知配置

配置 `WATCHTOWER_NOTIFICATION_URL` 环境变量发送到 ntfy：

```yaml
environment:
  - WATCHTOWER_NOTIFICATION_URL=ntfy://ntfy:80/watchtower-updates
```

### 标记要更新的容器

只有带有 `com.centurylinklabs.watchtower.enable=true` 标签的容器才会被更新：

```yaml
services:
  my-service:
    labels:
      - "com.centurylinklabs.watchtower.enable=true"
```

### 排除特定容器

```yaml
services:
  my-service:
    labels:
      - "com.centurylinklabs.watchtower.enable=false"
```

## Docker Socket Proxy

### 安全架构

```
Without Socket Proxy:
  Traefik -> /var/run/docker.sock (full access)

With Socket Proxy:
  Traefik -> Docker Socket Proxy -> /var/run/docker.sock (limited API)
```

### API 权限

- ✅ CONTAINERS=1 — 容器列表和状态
- ✅ POST=1 — 创建/启动/停止容器
- ✅ VERSION=1 — Docker 版本
- ✅ INFO=1 — Docker 信息
- ✅ NETWORKS=1 — 网络列表
- ❌ SWARM=0 — Swarm 模式禁用
- ❌ EXEC=0 — 执行命令禁用

## 故障排除

### Traefik 无法启动

```bash
# 检查 ACME 文件权限
ls -la config/traefik/acme.json
# 应该是: -rw------- (600)

# 查看日志
docker logs traefik
```

### 服务无法被 Traefik 发现

1. 确认容器在 `proxy` 网络中
2. 确认有 `traefik.enable=true` 标签
3. 检查 Traefik 日志查看服务发现状态

### Portainer 首次登录

1. 访问 https://portainer.${DOMAIN}
2. 5分钟内创建管理员账户
3. 连接 Docker 环境（本地 Socket）

## 相关文档

- [Traefik 文档](https://doc.traefik.io/traefik/)
- [Portainer 文档](https://docs.portainer.io/)
- [Watchtower 文档](https://containrrr.dev/watchtower/)
- [Docker Socket Proxy](https://github.com/Tecnativa/docker-socket-proxy)
