# Homelab Stack #8 - Robustness (国内网络适配 + 环境鲁棒性)

> 🇨🇳 专为中国大陆网络环境设计的 Homelab 增强组件，提供镜像加速、DNS 缓存、网络监控和自动重试机制。

## 📋 功能特性

### 核心功能

| 功能 | 说明 | 状态 |
|------|------|------|
| **Docker 镜像加速** | 自动切换国内镜像源，支持多源重试 | ✅ |
| **DNS 缓存服务** | Dnsmasq DNS 缓存，加速域名解析 | ✅ |
| **网络健康监控** | 持续检测网络连通性，及时告警 | ✅ |
| **自动重试机制** | 镜像拉取失败自动重试，最多 3 次 | ✅ |
| **NTP 时间同步** | 使用国内 NTP 服务器，确保时间准确 | ✅ |
| **配置中心** | 统一配置文件服务，便于管理 | ✅ |

### 国内镜像源支持

- 🐳 **Docker Hub**: 阿里云、中科大、网易、腾讯云等
- 🌐 **GitHub**: ghproxy.com 代理支持
- 📦 **GCR**: Google Container Registry 镜像

## 🚀 快速部署

### 前置要求

- Docker 20.10+
- Docker Compose v2.0+
- 已配置的 Traefik 反向代理 (proxy 网络)

### 部署步骤

```bash
# 1. 进入项目目录
cd homelab-robustness

# 2. 复制环境变量配置
cp .env.example .env

# 3. 编辑配置文件
vim .env  # 修改 DOMAIN 等必要变量

# 4. 启动服务
docker compose up -d

# 5. 验证服务状态
docker compose ps
```

### 验证部署

```bash
# 检查所有服务健康状态
docker compose ps

# 查看网络监控日志
docker logs network-monitor

# 运行网络健康检查
docker compose exec network-monitor sh -c "
  nslookup www.baidu.com 223.5.5.5 && \
  curl -sf https://hub.docker.com > /dev/null && \
  echo '网络检查通过'
"
```

## ⚙️ 配置说明

### 环境变量 (.env)

| 变量 | 说明 | 默认值 | 示例 |
|------|------|--------|------|
| `DOMAIN` | 主域名 | - | `homelab.example.com` |
| `TZ` | 时区 | `Asia/Shanghai` | `Asia/Shanghai` |
| `DOCKER_MIRROR_URL` | Docker 镜像加速 URL | 中科大 | `https://docker.m.daocloud.io` |
| `DNS_PRIMARY` | 主 DNS 服务器 | `223.5.5.5` | `223.5.5.5` |
| `DNS_SECONDARY` | 备用 DNS | `223.6.6.6` | `223.6.6.6` |
| `NTP_SERVER1` | 主 NTP 服务器 | `ntp.aliyun.com` | `ntp.aliyun.com` |

### 服务端口

| 服务 | 端口 | 说明 |
|------|------|------|
| dnsmasq | 5353 | DNS 缓存服务 |
| config-server | 80 (内部) | 配置中心 (通过 Traefik 暴露) |
| registry-mirror | 5000 (内部) | Docker 镜像仓库 (可选) |

## 🛠️ 使用指南

### 1. 使用镜像拉取重试脚本

```bash
# 赋予执行权限
chmod +x scripts/pull-retry.sh

# 拉取单个镜像 (自动重试)
./scripts/pull-retry.sh pull nginx:1.25.4

# 批量拉取镜像
./scripts/pull-retry.sh batch alpine:3.19 redis:7.2 postgres:16

# 检查镜像是否存在
./scripts/pull-retry.sh check nginx:1.25.4

# 列出配置的镜像源
./scripts/pull-retry.sh list-mirrors
```

### 2. 运行网络健康检查

```bash
# 赋予执行权限
chmod +x scripts/network-health.sh

# 运行所有检查
./scripts/network-health.sh check

# 检查 DNS 解析
./scripts/network-health.sh dns www.baidu.com

# 检查 Docker Hub 连通性
./scripts/network-health.sh docker-hub

# 检查镜像源可用性
./scripts/network-health.sh mirror docker.m.daocloud.io

# 持续监控模式 (每 60 秒检查一次)
./scripts/network-health.sh monitor 60
```

### 3. 配置 Docker 使用国内镜像

编辑 `/etc/docker/daemon.json`:

```json
{
  "registry-mirrors": [
    "https://docker.m.daocloud.io",
    "https://docker.mirrors.ustc.edu.cn",
    "https://registry.docker-cn.com"
  ]
}
```

重启 Docker:

```bash
sudo systemctl daemon-reload
sudo systemctl restart docker
```

### 4. 使用 Dnsmasq DNS 缓存

将系统 DNS 设置为 dnsmasq 服务:

```bash
# 编辑 resolv.conf (或使用 NetworkManager)
echo "nameserver 127.0.0.1" | sudo tee /etc/resolv.conf

# 或者指定容器 IP
echo "nameserver $(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' dnsmasq)" | sudo tee /etc/resolv.conf
```

## 📊 监控与告警

### 查看服务状态

```bash
# 所有服务状态
docker compose ps

# 查看特定服务日志
docker logs network-monitor
docker logs ntp-sync
docker logs dnsmasq
```

### 健康检查端点

- **Config Server**: `https://config.${DOMAIN}/health`
- **Registry Mirror**: `http://localhost:5000/v2/_catalog`

### 集成到监控系统

```yaml
# Prometheus 抓取配置示例
scrape_configs:
  - job_name: 'homelab-robustness'
    static_configs:
      - targets:
        - 'dnsmasq:9153'  # 如启用 metrics
```

## 🧪 测试

运行集成测试:

```bash
# 运行所有测试
chmod +x tests/robustness.test.sh
./tests/robustness.test.sh

# 运行单个测试
./tests/robustness.test.sh config_files
./tests/robustness.test.sh compose_syntax
./tests/robustness.test.sh documentation
```

## 🔧 故障排除

### 问题 1: 镜像拉取失败

```bash
# 检查 Docker 镜像源配置
docker info | grep -A 5 "Registry Mirrors"

# 手动测试镜像源连通性
curl -I https://docker.m.daocloud.io/v2/_catalog

# 使用重试脚本拉取
./scripts/pull-retry.sh pull <image>
```

### 问题 2: DNS 解析慢

```bash
# 检查 dnsmasq 状态
docker compose ps dnsmasq

# 查看 dnsmasq 日志
docker logs dnsmasq

# 测试 DNS 解析速度
time nslookup www.baidu.com 127.0.0.1
```

### 问题 3: NTP 同步失败

```bash
# 手动同步时间
docker compose exec ntp-sync ntpdate ntp.aliyun.com

# 检查系统时间
date

# 检查 NTP 服务器连通性
ping -c 3 ntp.aliyun.com
```

## 📁 文件结构

```
homelab-robustness/
├── docker-compose.yml      # 主配置文件
├── .env.example            # 环境变量模板
├── README.md               # 本文档
├── config/
│   ├── dnsmasq.conf        # DNS 缓存配置
│   ├── nginx.conf          # 配置中心 Nginx 配置
│   └── registry.yml        # Docker Registry 配置
├── scripts/
│   ├── pull-retry.sh       # 镜像拉取重试脚本
│   └── network-health.sh   # 网络健康检查脚本
└── tests/
    └── robustness.test.sh  # 集成测试脚本
```

## 🔒 安全建议

1. **限制 Registry 访问**: 如需公开 Docker Registry，请配置认证
2. **防火墙规则**: 仅开放必要端口 (5353 DNS)
3. **定期更新**: 保持镜像和配置最新
4. **日志审计**: 定期检查网络监控日志

## 📈 性能优化

### DNS 缓存优化

```conf
# config/dnsmasq.conf
cache-size=10000      # 增加缓存大小
min-cache-ttl=300     # 最小 TTL 5 分钟
max-cache-ttl=86400   # 最大 TTL 24 小时
```

### 镜像预拉取

在低峰期预拉取常用镜像:

```bash
./scripts/pull-retry.sh batch \
  nginx:1.25.4 \
  alpine:3.19 \
  redis:7.2 \
  postgres:16 \
  node:20-alpine
```

## 🎯 验收标准

- [x] Docker 镜像加速配置完成
- [x] DNS 缓存服务正常运行
- [x] 网络健康监控持续运行
- [x] 自动重试机制工作正常
- [x] NTP 时间同步配置完成
- [x] 配置中心可访问
- [x] 所有服务健康检查通过
- [x] 完整文档和测试脚本

## 💰 赏金信息

- **Issue**: [#8 Robustness](https://github.com/illbnm/homelab-stack/issues/8)
- **金额**: $250 USDT
- **难度**: Hard
- **钱包**: `TMLkvEDrjvHEUbWYU1jfqyUKmbLNZkx6T1` (USDT TRC20)

## 📝 更新日志

### v1.0.0 (2026-03-24)
- ✅ 初始版本发布
- ✅ Docker 镜像加速支持
- ✅ DNS 缓存服务 (Dnsmasq)
- ✅ 网络健康监控
- ✅ 自动重试机制
- ✅ NTP 时间同步
- ✅ 配置中心服务
- ✅ 完整文档和测试

---

**作者**: 牛马 🐴  
**许可**: MIT License
