# Network Stack — AdGuard Home + Unbound + WireGuard (wg-easy)

## 网络架构图 / Network Diagram

```
                        ┌─────────────────────────────────────────────┐
                        │              Internet / WAN                  │
                        └──────────┬──────────────┬───────────────────┘
                                   │              │
                              port 443       port 51820/udp
                                   │              │
                        ┌──────────▼──────┐  ┌────▼──────────────────┐
                        │    Traefik      │  │   WireGuard (wg-easy) │
                        │  (base stack)   │  │   VPN 隧道 / tunnel   │
                        │  HTTPS终端      │  │   10.8.0.0/24 subnet  │
                        └──┬────┬────┬────┘  └────┬──────────────────┘
                           │    │    │             │
            ┌──────────────┘    │    └──────┐      │
            ▼                   ▼           ▼      │
  ┌─────────────────┐ ┌──────────────┐ ┌────────────────┐
  │ adguard.DOMAIN  │ │ wg.DOMAIN    │ │  LAN clients   │
  │ AdGuard Home    │ │ wg-easy UI   │ │  via VPN       │
  │ DNS 过滤/管理   │ │ VPN 客户端管理│ │                │
  │ port 53 (DNS)   │ │              │ │                │
  └────────┬────────┘ └──────────────┘ └────────────────┘
           │
           │  DNS upstream (network-internal)
           ▼
  ┌─────────────────┐
  │    Unbound       │
  │  递归DNS解析器   │
  │  隐私优先,无日志 │
  │  直连根域名服务器│
  └─────────────────┘
```

### DNS 解析链路 / DNS Resolution Chain

```
  LAN Client / VPN Client
         │
         ▼ port 53
  ┌──────────────┐
  │ AdGuard Home │  ← 广告过滤 + 家长控制 + DNS 查询日志
  │              │     Ad filtering + parental controls + query log
  └──────┬───────┘
         │ upstream: unbound:53
         ▼
  ┌──────────────┐
  │   Unbound    │  ← 递归解析,直接查询根/TLD/权威DNS
  │              │     Recursive resolution, queries root/TLD/auth NS directly
  └──────┬───────┘
         │
         ▼
  Root DNS Servers (a.root-servers.net, ...)
```

---

## 中文说明

### 服务概览

| 服务 | 说明 | 访问地址 |
|------|------|----------|
| **AdGuard Home** | DNS 过滤与广告屏蔽 | `https://adguard.${DOMAIN}` / LAN DNS `:53` |
| **Unbound** | 递归 DNS 解析器 (AdGuard 上游) | 内部网络,无外部端口 |
| **wg-easy** | WireGuard VPN + Web 管理界面 | `https://wg.${DOMAIN}` / UDP `:51820` |

### 快速开始

```bash
# 1. 确保 base stack 已运行 (Traefik)
cd stacks/base && docker compose up -d

# 2. 复制并编辑环境变量 (如果还没有)
cp .env.example .env
# 编辑 .env 填入: WG_HOST, WG_PASSWORD_HASH, DOMAIN 等

# 3. 创建 proxy 网络 (如尚未创建)
docker network create proxy

# 4. 启动网络堆栈
cd stacks/network && docker compose up -d

# 5. 首次访问 AdGuard Home 进行初始设置
#    打开 https://adguard.yourdomain.com
#    设置管理员密码
#    设置 upstream DNS 为: unbound:53
```

### 生成 wg-easy 密码哈希

wg-easy v14+ 需要 bcrypt 密码哈希:

```bash
# 方法1: 使用 wg-easy 自带工具
docker run -it ghcr.io/wg-easy/wg-easy wgpw 'YOUR_PASSWORD'

# 方法2: 使用 htpasswd
htpasswd -nbBC 12 "" 'YOUR_PASSWORD' | cut -d: -f2

# 将输出的哈希值填入 .env 的 WG_PASSWORD_HASH
```

### AdGuard Home 配置 Unbound 上游

首次设置后,进入 AdGuard Home -> 设置 -> DNS 设置:

- **上游 DNS 服务器**: `unbound:53`
- **Bootstrap DNS 服务器**: `1.1.1.1` (仅用于解析 unbound 容器名)
- 勾选 "并行请求" 提升速度

### WireGuard VPN 客户端配置

1. 访问 `https://wg.${DOMAIN}` 登录 wg-easy 管理界面
2. 点击 "New Client" 创建客户端
3. 扫描二维码或下载配置文件
4. 在手机/电脑安装 WireGuard 客户端并导入配置

### 让 VPN 客户端使用 AdGuard DNS

推荐方式: 在 `.env` 设置 `WG_DEFAULT_DNS` 为 AdGuard Home 的容器 IP:

```bash
# 查看 AdGuard Home 容器 IP
docker inspect adguardhome | grep IPAddress

# 在 .env 中设置 (示例)
WG_DEFAULT_DNS=172.20.0.3
```

或者在 wg-easy 启动后,所有新建客户端都会自动使用该 DNS。

### 防火墙规则 / Firewall Rules

服务器防火墙需开放以下端口:

```bash
# UFW 示例
sudo ufw allow 53/tcp comment 'AdGuard DNS (TCP)'
sudo ufw allow 53/udp comment 'AdGuard DNS (UDP)'
sudo ufw allow 51820/udp comment 'WireGuard VPN'
sudo ufw allow 853/tcp comment 'DNS-over-TLS (optional)'
sudo ufw allow 80/tcp comment 'Traefik HTTP -> HTTPS redirect'
sudo ufw allow 443/tcp comment 'Traefik HTTPS'

# iptables 示例
iptables -A INPUT -p udp --dport 51820 -j ACCEPT
iptables -A INPUT -p tcp --dport 53 -j ACCEPT
iptables -A INPUT -p udp --dport 53 -j ACCEPT
iptables -A INPUT -p tcp --dport 853 -j ACCEPT
```

> **安全提示**: 如果 DNS 仅供 LAN 和 VPN 客户端使用,建议限制 53 端口的源 IP:
> ```bash
> sudo ufw allow from 10.8.0.0/24 to any port 53 comment 'DNS from VPN subnet'
> sudo ufw allow from 192.168.1.0/24 to any port 53 comment 'DNS from LAN subnet'
> sudo ufw deny 53 comment 'Block external DNS'
> ```

### 本地开发 (无 Traefik)

```bash
docker compose -f docker-compose.yml -f docker-compose.local.yml up -d
# AdGuard Home: http://localhost:3000 (初始设置) / http://localhost:8080 (设置后)
# wg-easy:      http://localhost:51821
# Unbound DNS:  localhost:5353
```

### 环境变量说明

| 变量 | 必填 | 默认值 | 说明 |
|------|------|--------|------|
| `DOMAIN` | 是 | - | 基础域名 |
| `TZ` | 否 | `Asia/Shanghai` | 时区 |
| `WG_HOST` | 是 | - | 公网 IP 或域名 (客户端连接地址) |
| `WG_PASSWORD_HASH` | 是 | - | wg-easy Web UI 密码 bcrypt 哈希 |
| `WG_PORT` | 否 | `51820` | WireGuard 监听端口 |
| `WG_DEFAULT_DNS` | 否 | (空) | VPN 客户端默认 DNS |
| `WG_DEFAULT_ADDRESS` | 否 | `10.8.0.x` | VPN 客户端 IP 段 |
| `WG_ALLOWED_IPS` | 否 | `0.0.0.0/0, ::/0` | 允许的 IP 范围 |
| `WG_PERSISTENT_KEEPALIVE` | 否 | `25` | NAT keepalive (秒) |
| `WG_MTU` | 否 | `1420` | MTU 值 |
| `ADGUARD_DNS_PORT` | 否 | `53` | DNS 监听端口 |
| `ADGUARD_DOT_PORT` | 否 | `853` | DNS-over-TLS 端口 |
| `ADGUARD_WEB_PORT` | 否 | `3000` | AdGuard Web UI 端口 (设置后改为 80) |

### 常见问题 (FAQ)

**Q: AdGuard Home 初始设置后 Web UI 端口从 3000 变为 80 怎么办?**
A: 修改 `.env` 中的 `ADGUARD_WEB_PORT=80` 然后重新启动:
```bash
# 编辑 .env: ADGUARD_WEB_PORT=80
docker compose up -d
```

**Q: WireGuard 客户端连接后无法访问内网?**
A: 检查以下项:
1. 服务器 `net.ipv4.ip_forward=1` 是否生效 (wg-easy 容器内已设置)
2. 防火墙是否允许 51820/udp
3. `WG_ALLOWED_IPS` 是否包含内网网段
4. 宿主机防火墙是否允许转发: `sudo sysctl net.ipv4.ip_forward=1`

**Q: Unbound 解析慢?**
A: 首次查询需要递归解析,会比较慢 (200-500ms)。后续查询会被缓存加速 (<5ms)。如果持续慢:
1. 检查服务器是否能访问外网 UDP/53
2. `docker logs unbound` 查看错误日志
3. 考虑增大 Unbound 缓存: 编辑 unbound.conf 增加 `msg-cache-size` 和 `rrset-cache-size`

**Q: 国内拉取 ghcr.io 镜像失败?**
A: 使用 CN 镜像替代:
```bash
# wg-easy
docker pull ghcr.m.daocloud.io/wg-easy/wg-easy:14
docker tag ghcr.m.daocloud.io/wg-easy/wg-easy:14 ghcr.io/wg-easy/wg-easy:14

# 或者修改 docker-compose.yml 中的 image 行
```

**Q: 端口 53 被 systemd-resolved 占用?**
A: Ubuntu/Debian 默认的 systemd-resolved 会占用 53 端口:
```bash
# 检查占用
sudo ss -tlnp | grep :53

# 禁用 systemd-resolved 的 DNS stub listener
sudo sed -i 's/#DNSStubListener=yes/DNSStubListener=no/' /etc/systemd/resolved.conf
sudo systemctl restart systemd-resolved
sudo ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf
```

**Q: 如何备份配置?**
A: 备份 Docker volumes:
```bash
# AdGuard Home 配置
docker run --rm -v adguard-conf:/data -v $(pwd):/backup alpine tar czf /backup/adguard-conf.tar.gz /data

# WireGuard 配置 (包含私钥!)
docker run --rm -v wg-easy-data:/data -v $(pwd):/backup alpine tar czf /backup/wg-easy-data.tar.gz /data
```

---

## English

### Service Overview

| Service | Description | Access |
|---------|-------------|--------|
| **AdGuard Home** | DNS filtering & ad blocking | `https://adguard.${DOMAIN}` / LAN DNS `:53` |
| **Unbound** | Recursive DNS resolver (AdGuard upstream) | Internal only, no exposed ports |
| **wg-easy** | WireGuard VPN + Web UI | `https://wg.${DOMAIN}` / UDP `:51820` |

### Quick Start

```bash
# 1. Ensure base stack is running (Traefik)
cd stacks/base && docker compose up -d

# 2. Copy and edit environment variables
cp .env.example .env
# Edit .env: set WG_HOST, WG_PASSWORD_HASH, DOMAIN, etc.

# 3. Create proxy network (if not already created)
docker network create proxy

# 4. Start network stack
cd stacks/network && docker compose up -d

# 5. Access AdGuard Home for initial setup
#    Open https://adguard.yourdomain.com
#    Set upstream DNS to: unbound:53
```

### Generating wg-easy Password Hash

wg-easy v14+ requires a bcrypt password hash:

```bash
# Method 1: using wg-easy built-in tool
docker run -it ghcr.io/wg-easy/wg-easy wgpw 'YOUR_PASSWORD'

# Method 2: using htpasswd
htpasswd -nbBC 12 "" 'YOUR_PASSWORD' | cut -d: -f2

# Paste the output into WG_PASSWORD_HASH in .env
```

### Configuring AdGuard Home with Unbound

After initial setup, go to AdGuard Home -> Settings -> DNS Settings:

- **Upstream DNS servers**: `unbound:53`
- **Bootstrap DNS servers**: `1.1.1.1` (only used to resolve container names)
- Enable "Parallel requests" for speed

### WireGuard Client Setup

1. Visit `https://wg.${DOMAIN}` and log in to wg-easy
2. Click "New Client" to create a peer
3. Scan QR code or download config file
4. Install WireGuard client on your device and import config

### Firewall Rules

Required open ports on the host:

| Port | Protocol | Service | Required |
|------|----------|---------|----------|
| 53 | TCP+UDP | AdGuard DNS | Yes (for LAN DNS) |
| 51820 | UDP | WireGuard VPN | Yes |
| 853 | TCP | DNS-over-TLS | Optional |
| 80 | TCP | Traefik HTTP redirect | Yes |
| 443 | TCP | Traefik HTTPS | Yes |

> **Security tip**: Restrict DNS port 53 to LAN/VPN subnets only if not running a public resolver.

### Local Development (without Traefik)

```bash
docker compose -f docker-compose.yml -f docker-compose.local.yml up -d
# AdGuard Home: http://localhost:3000 (initial setup) / http://localhost:8080 (after setup)
# wg-easy:      http://localhost:51821
# Unbound DNS:  localhost:5353
```

### Environment Variables

See the Chinese section above for the full variable table.

### FAQ

**Q: AdGuard Home initial setup changes the web UI port from 3000 to 80?**
A: Update `ADGUARD_WEB_PORT=80` in `.env` and restart: `docker compose up -d`

**Q: WireGuard clients can't access the LAN?**
A: Check: (1) `net.ipv4.ip_forward=1` on host, (2) firewall allows 51820/udp, (3) `WG_ALLOWED_IPS` includes LAN subnet.

**Q: Unbound is slow on first query?**
A: This is expected -- recursive resolution requires querying root servers (200-500ms first time). Subsequent queries are cached (<5ms).

**Q: Cannot pull ghcr.io images in China?**
A: Use CN mirror alternatives -- see CN mirror comments in docker-compose.yml for each image.

**Q: Port 53 already in use by systemd-resolved?**
A: See Chinese FAQ above for the fix (disable DNSStubListener in systemd-resolved).

### CN Mirror Alternatives

| Original Image | CN Mirror |
|----------------|-----------|
| `adguard/adguardhome:v0.107.55` | `registry.cn-hangzhou.aliyuncs.com/adguard/adguardhome:v0.107.55` |
| `mvance/unbound:1.20.0` | `registry.cn-hangzhou.aliyuncs.com/mvance/unbound:1.20.0` |
| `ghcr.io/wg-easy/wg-easy:14` | `ghcr.m.daocloud.io/wg-easy/wg-easy:14` |
