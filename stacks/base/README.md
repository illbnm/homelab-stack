# Base Stack — 基础设施

## 服务

| 服务 | 镜像 | 用途 |
|------|------|------|
| Traefik | traefik:v3.1.6 | 反向代理 + 自动 HTTPS |
| Portainer CE | portainer/portainer-ce:2.21.3 | Docker 管理 UI |
| Watchtower | containrrr/watchtower:1.7.1 | 容器自动更新 |
| Socket Proxy | tecnativa/docker-socket-proxy:0.2.0 | 安全隔离 Docker socket |

## 快速开始

```bash
# 1. 创建共享网络
docker network create proxy

# 2. 配置环境变量
cp .env.example .env
# 编辑 .env 文件：
#   DOMAIN=your-domain.com
#   ACME_EMAIL=your-email@example.com
#   TRAEFIK_AUTH=$(openssl passwd -apr1 admin yourpassword)

# 3. 启动
docker compose up -d

# 4. 访问
#   https://traefik.your-domain.com  → Traefik Dashboard
#   https://portainer.your-domain.com → Portainer
```

## 目录结构

```
stacks/base/
├── docker-compose.yml    # 服务定义
├── .env.example          # 环境变量模板
└── README.md

config/traefik/
├── traefik.yml           # Traefik 静态配置
└── dynamic/
    ├── tls.yml           # TLS 选项
    └── middlewares.yml   # HTTP 中间件
```

## 环境变量

| 变量 | 必填 | 说明 |
|------|------|------|
| DOMAIN | 是 | 你的域名 (如 example.com) |
| ACME_EMAIL | 是 | Let\'s Encrypt 注册邮箱 |
| TRAEFIK_AUTH | 是 | htpasswd 生成的用户名:密码 |
| TZ | 否 | 时区 (默认 Asia/Shanghai) |

## 验收清单

- [ ] docker compose up -d 启动所有 4 个容器
- [ ] 所有容器健康检查通过
- [ ] HTTP (80) 自动重定向到 HTTPS (443)
- [ ] traefik.${DOMAIN} 可访问 Dashboard，需密码
- [ ] portainer.${DOMAIN} 可访问 Portainer
- [ ] 其他 Stack 可通过 proxy 网络被 Traefik 发现
