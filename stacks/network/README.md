# 🌐 Network Stack — AdGuard Home + WireGuard + Cloudflare DDNS

> 家庭网络基础设施：DNS 过滤、VPN 接入、递归解析、动态域名。

## 服务清单

| 服务 | 镜像 | URL/端口 | 用途 |
|------|------|---------|------|
| **AdGuard Home** | `adguard/adguardhome:v0.107.52` | `dns.${DOMAIN}` / `:53` | DNS 过滤 + 广告屏蔽 |
| **Unbound** | `mvance/unbound:1.21.1` | internal `:5335` | 递归 DNS 解析器 |
| **WireGuard Easy** | `ghcr.io/wg-easy/wg-easy:14` | `vpn.${DOMAIN}` / `:51820/udp` | VPN 服务端 |
| **Cloudflare DDNS** | `ghcr.io/favonia/cloudflare-ddns:1.14.0` | — | 动态 DNS 更新 |

## 前置准备

### 处理 systemd-resolved 端口冲突

大多数 Ubuntu/Debian 系统的 systemd-resolved 占用 53 端口：

```bash
# 检查端口状态
sudo ./scripts/fix-dns-port.sh --check

# 禁用 systemd-resolved 的 53 端口
sudo ./scripts/fix-dns-port.sh --apply

# 如需恢复
sudo ./scripts/fix-dns-port.sh --restore
```

## 快速启动

```bash
# 1. 配置 .env
CF_API_TOKEN=your_cloudflare_api_token
CF_DOMAINS=example.com,*.example.com
WG_HOST=vpn.example.com

# 2. 修复 DNS 端口
sudo ./scripts/fix-dns-port.sh --apply

# 3. 启动
docker compose -f stacks/network/docker-compose.yml up -d
```

## AdGuard Home

### 首次设置
1. 访问 `https://dns.${DOMAIN}` (或 `http://<server-ip>:3000`)
2. 完成设置向导
3. 设置上游 DNS 为 Unbound: `127.0.0.1:5335`

### 推荐过滤列表
在 AdGuard Home → Filters → DNS blocklists 添加：

| 列表 | URL |
|------|-----|
| AdGuard DNS filter | `https://adguardteam.github.io/HostlistsRegistry/assets/filter_1.txt` |
| OISD Big | `https://big.oisd.nl` |
| Steven Black | `https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts` |
| 1Hosts Lite | `https://o0.pages.dev/Lite/adblock.txt` |

### 路由器 DNS 配置
将路由器的 DNS 服务器指向运行 AdGuard Home 的主机 IP：
```
Primary DNS:   <server-ip>
Secondary DNS: 1.1.1.1  (fallback)
```

## WireGuard VPN

### 访问管理界面
`https://vpn.${DOMAIN}` — 创建/管理客户端

### 添加客户端
1. 打开 Web UI
2. 点击 "New Client"
3. 扫描二维码或下载配置文件

### Split Tunneling
默认 `WG_ALLOWED_IPS=0.0.0.0/0` 路由所有流量。

仅路由内网流量：
```env
WG_ALLOWED_IPS=10.8.0.0/24, 192.168.1.0/24
```

### DNS 配置
VPN 客户端 DNS 默认指向 AdGuard Home (`10.8.0.1`)，享受广告过滤。

## Cloudflare DDNS

### 获取 API Token
1. 登录 [Cloudflare Dashboard](https://dash.cloudflare.com/profile/api-tokens)
2. Create Token → Edit zone DNS
3. Zone Resources: 选择你的域名
4. 复制 token 到 `.env` 的 `CF_API_TOKEN`

### 多域名配置
```env
CF_DOMAINS=example.com,*.example.com,vpn.example.com
```

### IPv6 支持
```env
CF_IP6_PROVIDER=cloudflare  # 启用 IPv6 DDNS
```

## Unbound 递归解析

Unbound 作为 AdGuard Home 的上游 DNS，直接向根服务器递归查询，不依赖第三方 DNS：

```
客户端 → AdGuard Home (过滤) → Unbound (递归) → 根服务器
```

配置文件: `config/unbound/unbound.conf`
- DNSSEC 验证
- QNAME 最小化 (隐私)
- 64MB 缓存
- 预取热门域名
