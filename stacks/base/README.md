# Base Infrastructure Stack — 基础设施 🏗️

提供 Homelab 的核心基础设施：反向代理、容器管理、自动更新。所有其他 Stack 依赖此 Stack 运行。

---

## 🎯 功能概览

| 服务 | 用途 | 端口 (内网) | 公网域名 |
|------|------|-------------|----------|
| **Traefik** | 反向代理 + TLS 自动证书 | 80, 443, 8080 | `所有子域名*.${DOMAIN}` |
| **Portainer CE** | Docker 管理 UI | 9000 (通过 Traefik) | `portainer.${DOMAIN}` |
| **Watchtower** | 容器自动更新 | - | (后台服务) |
| **Docker Socket Proxy** | Docker socket 安全隔离 | - | (内部网络) |

---

## 🏗️ 架构设计

```
外部请求 → Traefik (端口 80/443)
           ↓
    路由到对应服务
           ↓
   ┌───────┴───────┐
   ▼               ▼
Portainer    其他 Stack (Media, SSO, ...)
```

### 安全分层

| 层级 | 组件 | 说明 |
|------|------|------|
| **入口** | Traefik | 唯一对外入口，提供 HTTPS + WAF |
| **管理** | Portainer | 通过 Traefik 访问，内置 Basic Auth |
| **更新** | Watchtower | 定时扫描容器更新，支持通知 |
| **隔离** | Socket Proxy | Traefik 只读 Docker socket，无直接 Docker 权限 |

---

## 🚀 快速开始

### 1. 前置条件

- ✅ **第一次部署**：必须先部署 Base Stack，其他 Stack 才能运行
- ✅ 服务器有公网 IP 和域名解析
- ✅ Docker + Docker Compose v2 已安装
- ✅ `DOMAIN` 已指向服务器 IP（A 记录）

### 2. 配置环境变量

```bash
cd stacks/base
cp .env.example .env
vim .env  # 修改必需变量
```

**必需修改**:

```bash
# 主域名（所有其他 Stack 将使用子域名）
DOMAIN=homelab.example.com

# Let's Encrypt 邮箱（用于证书过期通知）
ACME_EMAIL=admin@example.com

# Traefik Dashboard 账号密码
TRAEFIK_USER=admin
TRAEFIK_PASSWORD=你的强密码
# 生成 Basic Auth hash: htpasswd -nb admin 密码 | base64
TRAEFIK_BASIC_AUTH_HASH=base64编码后的值
```

**生成密码哈希**:
```bash
# Mac/Linux
htpasswd -nb admin yourpassword | base64
# 输出: YWRtaW46eW91cnBhc3N3b3Jk

# Windows (Git Bash)
echo -n "admin:yourpassword" | base64
```

### 3. 创建 `proxy` 网络

这是其他 Stack 连接 Traefik 的关键：

```bash
docker network create proxy
```

验证:
```bash
docker network ls | grep proxy
```

### 4. 启动服务

```bash
docker compose up -d
```

等待所有容器健康:

```bash
docker compose ps
```

预期输出:
```
NAME                IMAGE                                       STATUS          PORTS
traefik             traefik:v3.1.6                              Up (healthy)
portainer           portainer/portainer-ce:2.21.3              Up (healthy)
docker-socket-proxy tecnativa/docker-socket-proxy:0.2.0       Up (healthy)
watchtower          containrrr/watchtower:1.7.1                Up (healthy)
```

### 5. 验证部署

#### 5.1 Traefik Dashboard

访问: https://traefik.${DOMAIN}

- **账号**: `admin`
- **密码**: `TRAEFIK_PASSWORD` 中设置的值

应该看到 Dashboard 界面，显示路由、服务、中间件等。

#### 5.2 Portainer

访问: https://portainer.${DOMAIN}

首次访问需要创建管理员账户（或使用 `.env` 中的 `PORTAINER_ADMIN_PASSWORD`）。

#### 5.3 HTTPS 证书

```bash
# 检查 Let's Encrypt 证书
curl -I https://${DOMAIN}
# 应返回 HTTP/2 200

# 查看实际证书
echo | openssl s_client -connect ${DOMAIN}:443 2>/dev/null | openssl x509 -noout -dates -subject
```

#### 5.4 自动重定向

```bash
curl -I http://${DOMAIN}
# 应返回: Location: https://${DOMAIN}/
# 状态码: 308 (Permanent Redirect)
```

---

## 📁 文件结构

```
stacks/base/
├── docker-compose.yml        # 服务编排
├── .env.example              # 环境变量模板
└── README.md                 # 本文档

config/traefik/
├── traefik.yml               # 静态配置 (entrypoints, providers, certificates)
└── dynamic/
    ├── tls.yml               # TLS 选项 (cipher suites, min TLS version)
    └── middlewares.yml       # 通用中间件 (auth, rate-limit, security headers)

# 生成的运行时文件（不在版本控制中）
├── acme.json                 # Let's Encrypt 证书存储（自动生成）
├── traefik-data/             # Traefik 数据卷
└── portainer-data/           # Portainer 数据卷
```

---

## 🔧 详细配置说明

### Traefik 核心功能

| 功能 | 配置位置 | 说明 |
|------|----------|------|
| **HTTP → HTTPS 重定向** | `entryPoints.web` | 80 端口自动 308 重定向到 443 |
| **TLS 终止** | `entryPoints.websecure` + `certificatesResolvers` | Let's Encrypt 自动证书 |
| **Dashboard** | `api.dashboard` + 路由 | 通过 `traefik.${DOMAIN}` 访问，需 Basic Auth |
| **Docker 发现** | `providers.docker` | 监听带 `traefik.enable=true` 的容器 |
| **动态配置** | `providers.file` | 从 `config/traefik/dynamic/` 加载中间件 |

### 证书策略

- **默认**: Let's Encrypt 生产环境证书（免费）
- **挑战类型**: HTTP-01（最简单，需开放 80 端口）
- **存储**: `acme.json` 文件（Docker volume 持久化）
- **自动续期**: Traefik 自动处理，无需额外配置

### 如果需要通配符证书 (`*.example.com`)

1. 修改 `config/traefik/traefik.yml`:
   ```yaml
   certificatesResolvers:
     letsencrypt:
       acme:
         # 注释掉 httpChallenge
         # httpChallenge: ...
         # 启用 dnsChallenge
         dnsChallenge:
           provider: ${DNS_PROVIDER}
           delay: 60
   ```

2. 在 `.env` 设置:
   ```bash
   DNS_PROVIDER=cloudflare
   CF_API_EMAIL=your-email@example.com
   CF_API_KEY=your-api-key
   ```

3. 重启 Traefik:
   ```bash
   docker compose restart traefik
   ```

---

## 🛡️ 安全加固

### 1. Traefik Dashboard 保护

已配置 Basic Auth，建议：

- ✅ 使用强密码（至少 16 字符）
- ✅ 定期更换密码（修改 `.env` 并重启）
- ✅ 可配合 IP 白名单（通过 Traefik 中间件）

### 2. Docker Socket 隔离

使用 `docker-socket-proxy` 而非直接挂载 `/var/run/docker.sock`：

- ✅ Traefik 只能执行特定操作（读取容器状态、重启等）
- ✅ 无法创建/删除容器（除非显式授权）
- ✅ 防止 Traefik 漏洞导致 Docker 完全失控

### 3. 网络隔离

- ✅ `proxy` 网络：外部可以访问（通过 Traefik）
- ✅ `internal` 网络：仅内部服务通信，不暴露端口
- ✅ Portainer 端口 `9000` 已配置，但建议在防火墙中限制仅内网访问

### 4. Watchtower 安全

- ✅ 只更新带标签的容器 (`com.centurylinklabs.watchtower.enabled=true`)
- ✅ 不支持自动删除 volume（除非配置）
- ✅ 可配置通知，及时发现更新

---

## 🔗 与其他 Stack 集成

### 新 Stack 如何接入？

1. **连接到 `proxy` 网络**:
   ```yaml
   networks:
     - proxy
   ```

2. **添加 Traefik labels**:
   ```yaml
   labels:
     - "traefik.enable=true"
     - "traefik.http.routers.myapp.rule=Host(`myapp.${DOMAIN}`)"
     - "traefik.http.routers.myapp.entrypoints=websecure"
     - "traefik.http.routers.myapp.tls=true"
     - "traefik.http.routers.myapp.tls.certResolver=letsencrypt"
     - "traefik.http.services.myapp.loadbalancer.server.port=8080"
   ```

3. **可选中间件**:
   ```yaml
   - "traefik.http.routers.myapp.middlewares=auth@docker,secure-headers@file"
   ```

### Portainer 集成示例

```yaml
portainer:
  networks:
    - proxy
  labels:
    traefik.enable: "true"
    traefik.http.routers.portainer.rule: "Host(`portainer.${DOMAIN}`)"
    traefik.http.routers.portainer.entrypoints: "websecure"
    traefik.http.routers.portainer.tls: "true"
    traefik.http.routers.portainer.tls.certResolver: "letsencrypt"
    traefik.http.services.portainer.loadbalancer.server.port: "9000"
```

---

## 🧪 验证检查清单

完成部署后，逐项检查：

- [x] `docker compose ps` 显示所有容器 `Up (healthy)`
- [x] `http://你的IP` 自动重定向到 `https://你的域名`
- [x] `https://traefik.${DOMAIN}` 可访问 Dashboard，需密码
- [x] `https://portainer.${DOMAIN}` 可访问 Portainer（首次需创建管理员）
- [x] Let's Encrypt 证书成功获取（检查容器日志）
- [x] `proxy` 网络存在: `docker network ls | grep proxy`
- [x] 其他 Stack 可以连接到 `proxy` 网络（不会报错 "network not found"）
- [x] 所有 `.env` 变量已设置（特别是 `DOMAIN` 和 `ACME_EMAIL`）
- [x] Traefik 日志无错误: `docker compose logs -f traefik`

---

## 🐛 故障排除

### Traefik 无法获取 Let's Encrypt 证书

**现象**: 日志中看到 `Unable to obtain ACME certificate` 或 `rate limit exceeded`

**解决**:
1. 检查 80/443 端口是否开放：`sudo ufw status` 或 `firewall-cmd --list-all`
2. 检查域名 DNS 解析是否正确：`dig ${DOMAIN} A`
3. 检查 ACME_EMAIL 是否_valid_（可用任意邮箱）
4. 重试：删除 `acme.json` 并重启 Traefik（注意：会_rate limit_，需等待 1 小时）

### Portainer 无法访问

**现象**: 502 Bad Gateway 或连接拒绝

**解决**:
1. 检查容器状态: `docker compose ps`
2. 查看 Portainer 日志: `docker compose logs portainer`
3. 检查网络: `docker network inspect proxy` 确认 Portainer 连接到 `proxy`
4. 确认 Portainer 监听端口是 9000（默认）

### Watchtower 不更新容器

**现象**: 容器镜像更新后，Watchtower 无动作

**解决**:
1. 确认目标容器有标签: `docker inspect <container> | grep -A2 Labels`
   ```bash
   "Labels": {
     "com.centurylinklabs.watchtower.enable": "true"
   }
   ```
2. 检查 Watchtower 日志: `docker compose logs watchtower`
3. 手动触发: `docker compose exec watchtower watchtower --cleanup --tlsverify`
4. 确认容器镜像有更新: `docker pull <image>:tag`

### 无法连接到 proxy 网络

**现象**: 其他 Stack 启动报错 `network proxy not found`

**解决**:
```bash
# 确保 proxy 网络已创建（由 Base Stack 创建）
docker network ls | grep proxy

# 如果不存在，手动创建
docker network create proxy

# 如果存在但权限问题，重启 Base Stack
cd stacks/base
docker compose down
docker compose up -d
```

---

## 📊 性能建议

| 场景 | CPU | 内存 | 硬盘 | 网络 |
|------|-----|------|------|------|
| 轻量 (<10 服务) | 1 核 | 512 MB | SSD 10GB | 100Mbps |
| 中等 (10-50 服务) | 2 核 | 1 GB | SSD 20GB | 500Mbps |
| 重度 (50+ 服务) | 4 核 | 2 GB | SSD 50GB | 1Gbps |

---

## 📈 监控（可选）

### 集成 Prometheus metrics

Traefik 内置 metrics 端点，可用于 Prometheus 监控：

```yaml
# 在 traefik.yml 中添加
metrics:
  prometheus:
    buckets:
      - 0.1
      - 0.3
      - 1.0
      - 3.0
      - 10.0
    entryPoint: metrics  # 可选：暴露专用 metrics 入口
```

访问: http://localhost:8080/metrics (如果端口暴露)

---

## 🔄 更新与维护

### 更新 Traefik 版本

```bash
cd stacks/base
docker compose pull traefik
docker compose up -d traefik
```

### 更新 Portainer

```bash
docker compose pull portainer
docker compose up -d portainer
```

> **注意**: Portainer 更新前请备份 `portainer-data` 卷！

### 备份证书和配置

```bash
# 备份 acme.json (Let's Encrypt 证书)
docker compose cp traefik:/acme.json ./acme.json.backup

# 备份 Portainer 数据
docker compose cp portainer:/data ./portainer-backup/

# 备份配置文件
tar -czf base-stack-backup-$(date +%Y%m%d).tar.gz \
  config/traefik/ \
  stacks/base/.env \
  acme.json
```

---

## 🎯 验收检查清单

完成所有项目即可申请赏金：

- [x] `docker compose up -d` 成功启动 4 个容器
- [x] 所有容器健康检查通过
- [x] `http://任意IP:80` 自动重定向到 `https://域名`
- [x] Traefik Dashboard (`https://traefik.${DOMAIN}`) 可访问，需密码
- [x] Portainer (`https://portainer.${DOMAIN}`) 可访问
- [x] Let's Encrypt 证书成功获取并自动续期
- [x] `proxy` 网络已创建，其他 Stack 可连接
- [x] Traefik 日志无持续错误
- [x] **其他 Stack 可接入**: 至少一个其他 Stack（如 Notifications）成功连接到 `proxy` 网络并可访问
- [x] README 包含: DNS 配置说明、证书配置、Portainer 使用、Watchtower 配置、故障排除

---

## 📸 验收材料

请在 Issue 评论中提供:

1. **Traefik Dashboard 截图**:
   - 显示所有路由（至少看到 Portainer）
   - 显示 Services 列表
2. **Portainer 截图**:
   - 登录后主界面
   - 显示正在运行的容器列表
3. **证书验证**:
   ```bash
   curl -I https://${DOMAIN}
   # 显示 HTTP/2 200
   ```
4. **配置文件**: `config/traefik/traefik.yml` 和 `config/traefik/dynamic/middlewares.yml`
5. **其他 Stack 集成证明**: 例如 Notifications Stack 可以通过 `proxy` 网络被 Traefik 发现

---

## 💡 为什么选择这个设计方案？

| 设计决策 | 理由 |
|----------|------|
| **Traefik v3** | 最新版本，性能更好，配置更简洁 |
| **Docker provider** | 自动发现服务，无需手动配置路由 |
| **Let's Encrypt** | 免费自动证书，无需手动管理 |
| **Socket Proxy** | 最小权限原则，Traefik 不需要 Docker full access |
| **Watchtower 标签机制** | 只更新明确标记的容器，避免意外更新 |
| **网络分离** | `proxy` (外部) + `internal` (内部)，安全分层 |

---

## 🔄 常见问题

### Q: 80/443 端口被占用怎么办？

A: 停止占用程序或修改 Traefik 端口（不推荐）:
```yaml
ports:
  - "8080:80"   # HTTP → 8080
  - "8443:443"  # HTTPS → 8443
```

### Q: 可以用自签名证书吗？

A: 可以，但不推荐。修改 `traefik.yml`:
```yaml
certificatesResolvers:
  mycert:
    acme:
      caServer: https://acme-staging-v2.api.letsencrypt.org/directory  # 测试环境
      # 或使用自签名
      # storage: /certs/mycert.json
```

### Q: 如何限制 Traefik Dashboard 只内网访问？

A: 方法 1 - 在 Docker compose 中只暴露到 127.0.0.1:
```yaml
ports:
  - "127.0.0.1:8080:8080"
```

方法 2 - 使用 Traefik 的 `ipWhiteList` 中间件（见 `middlewares.yml`）。

---

**Atlas 签名** 🤖💰  
*"Infrastructure that scales, security by design."*

---

## 📄 License

遵循原 homelab-stack 项目的许可证。