# CN Network Robustness — 国内网络适配指南

HomeLab Stack 针对中国大陆网络环境的完整适配方案。

## 问题描述

在中国大陆使用 HomeLab Stack 可能遇到以下问题：

| 问题 | 原因 |
|------|------|
| Docker Hub 拉取超时 | GFW 限速/阻断 |
| ghcr.io / gcr.io 无法访问 | 被完全阻断 |
| npm install 失败 | npmmirror 同步不完整 |
| GitHub API 超时 | 连接不稳定 |
| Let's Encrypt 验证失败 | HTTP-01 挑战超时 |

## 快速配置

```bash
# 一键配置所有镜像源
./scripts/setup-cn-mirrors.sh --all

# 拉取镜像（自动使用国内镜像）
./scripts/cn-pull.sh

# 启用 CN 模式
echo 'CN_MODE=true' >> .env
```

## 详细配置

### 1. Docker 镜像加速

```bash
# 运行配置脚本
./scripts/setup-cn-mirrors.sh --docker
```

或手动配置 `/etc/docker/daemon.json`：

```json
{
  "registry-mirrors": [
    "https://docker.m.daocloud.io",
    "https://mirror.ccs.tencentyun.com"
  ]
}
```

```bash
sudo systemctl restart docker
```

### 2. ghcr.io / gcr.io 镜像替换

`cn-pull.sh` 自动将以下镜像源替换为 DaoCloud 镜像：

| 原始源 | 替换源 |
|--------|--------|
| gcr.io | gcr.m.daocloud.io |
| ghcr.io | ghcr.m.daocloud.io |
| k8s.gcr.io | k8s-gcr.m.daocloud.io |
| quay.io | quay.m.daocloud.io |

使用方式：
```bash
# 拉取单个镜像
./scripts/cn-pull.sh pull ghcr.io/goauthentik/server:2024.8.3

# 拉取某个 stack 的所有镜像
./scripts/cn-pull.sh stack sso

# 拉取所有 stack 的镜像
./scripts/cn-pull.sh all
```

### 3. npm 镜像

```bash
npm config set registry https://registry.npmmirror.com
```

如果 npmmirror 缺少某个包：
```bash
npm install --registry=https://registry.npmjs.org
```

### 4. pip 镜像

```bash
mkdir -p ~/pip
cat > ~/pip/pip.conf << 'EOF'
[global]
index-url = https://mirrors.aliyun.com/pypi/simple/
trusted-host = mirrors.aliyun.com
EOF
```

### 5. DNS 配置

推荐使用国内 DNS：
- 阿里 DNS: `223.5.5.5`, `223.6.6.6`
- 腾讯 DNS: `119.29.29.29`
- 114 DNS: `114.114.114.114`

在 AdGuard Home 上游 DNS 中配置：
```
https://dns.alidns.com/dns-query
https://doh.pub/dns-query
```

### 6. Let's Encrypt 替代方案

如果 HTTP-01 验证超时，使用 DNS-01 验证：

在 Traefik 配置中（`config/traefik/traefik.yml`）：

```yaml
certificatesResolvers:
  letsencrypt:
    acme:
      dnsChallenge:
        provider: cloudflare
        delayBeforeCheck: 30
```

### 7. 代理配置（如有）

如果使用代理，在 `.env` 中设置：

```env
HTTP_PROXY=http://proxy:port
HTTPS_PROXY=http://proxy:port
NO_PROXY=localhost,127.0.0.1,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16
```

## 每个 Stack 的 CN 注意事项

| Stack | CN 问题 | 解决方案 |
|-------|---------|---------|
| Base | 无 | Docker Hub 镜像加速 |
| SSO | ghcr.io 阻断 | `cn-pull.sh` 或使用 compose 中的 CN mirror 行 |
| AI | ghcr.io 阻断 | `cn-pull.sh` 拉取 open-webui 和 sd |
| Monitoring | gcr.io 阻断 | `cn-pull.sh` 拉取 cAdvisor |
| Productivity | lscr.io 阻断 | `cn-pull.sh` 拉取 bookstack |
| Media | lscr.io 阻断 | `cn-pull.sh` 拉取 *arr + qbittorrent |
| Database | 无 | Docker Hub 镜像加速 |
| Network | ghcr.io 阻断 | `cn-pull.sh` 拉取 wireguard, cloudflare-ddns |
| Storage | 无 | Docker Hub 镜像加速 |

## 验证

```bash
# 测试网络连接
./scripts/setup-cn-mirrors.sh

# 测试 Docker 镜像拉取
docker pull alpine:3.19 --quiet && echo "Docker Hub OK"

# 测试 ghcr.io 镜像
docker pull ghcr.m.daocloud.io/open-webui/open-webui:v0.3.35 --quiet && echo "ghcr.io mirror OK"
```
