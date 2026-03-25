# Network Stack

家庭网络基础设施服务栈，包含 DNS 过滤、VPN、动态域名等功能。

## 服务架构

```
┌─────────────────────────────────────────────────────────┐
│                    Network Stack                         │
├─────────────────────────────────────────────────────────┤
│                                                          │
│   AdGuard Home                                          │
│   ├── DNS 过滤 + 广告屏蔽                               │
│   ├── 家庭网络 DNS 服务器                              │
│   └── 端口: 53 (TCP/UDP)                              │
│                                                          │
│   WireGuard Easy                                        │
│   ├── VPN 服务器                                        │
│   ├── Web UI 管理                                       │
│   └── 端口: 51820/UDP                                  │
│                                                          │
│   Cloudflare DDNS                                       │
│   ├── 动态域名更新                                      │
│   └── 自动更新 DNS 记录                                 │
│                                                          │
│   Unbound                                               │
│   ├── 递归 DNS 解析器                                   │
│   └── 隐私保护 DNS 查询                                 │
│                                                          │
│   Nginx Proxy Manager (可选)                             │
│   ├── 反向代理管理                                      │
│   └── SSL 证书管理                                      │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

## 服务列表

| 服务 | 端口 | 说明 |
|------|------|------|
| AdGuard Home | 53 (TCP/UDP) | DNS 过滤 |
| WireGuard | 51820/UDP | VPN |
| WireGuard Web UI | 51821/TCP | VPN 管理界面 |
| Cloudflare DDNS | 8080/TCP | DDNS 客户端 |
| Unbound | 53 (TCP/UDP) | 递归 DNS |
| Nginx Proxy Manager | 8181/TCP, 3443/TCP | 反向代理 |

## 快速开始

### 1. 配置环境变量

```bash
cd homelab-stack
cp stacks/network/.env.example stacks/network/.env
nano stacks/network/.env
```

必须配置：
```env
# WireGuard VPN
WG_HOST=vpn.yourdomain.com
WG_EASY_PASSWORD=your_secure_password

# Cloudflare DDNS
CF_API_KEY=your_cloudflare_api_key
CF_API_EMAIL=your@email.com
CF_ZONE_ID=your_zone_id
CF_RECORD_NAME=ddns.yourdomain.com
```

### 2. 修复 DNS 端口冲突

如果使用 AdGuard Home，需要先修复 systemd-resolved 的端口 53 冲突：

```bash
# 检查冲突
sudo ./scripts/fix-dns-port.sh --check

# 应用修复
sudo ./scripts/fix-dns-port.sh --apply
```

### 3. 启动服务

```bash
docker compose -f stacks/network/docker-compose.yml up -d
```

### 4. 配置 Cloudflare DDNS

获取 Cloudflare API Key：
1. 登录 Cloudflare Dashboard
2. 进入 My Profile -> API Tokens
3. 创建新的 API Token 或使用 Global API Key

获取 Zone ID：
1. 登录 Cloudflare Dashboard
2. 选择你的域名
3. 在 Overview 页面底部找到 Zone ID

## AdGuard Home

### 功能

- DNS 过滤：屏蔽广告和恶意域名
- 家长控制：过滤成人内容
- DNS-over-HTTPS/TLS：加密 DNS 查询
- 查询日志：查看 DNS 查询记录

### 访问

- URL: `http://adguard.${DOMAIN}`
- 默认用户名: `admin`
- 默认密码: `admin` (首次登录后修改)

### 上游 DNS

推荐配置上游 DNS 为：
- 本地 Unbound: `10.8.0.x:53`
- Cloudflare: `1.1.1.1`
- Google: `8.8.8.8`

### 推荐的过滤列表

```
https://adguardteam.github.io/AdGuardSDNSFilter/Filters/filter.txt
https://raw.githubusercontent.com/AdAway/adaway.github.io/master/hosts.txt
https://adablock.com/blacklist.txt
```

## WireGuard Easy VPN

### 功能

- 安全的 VPN 隧道
- Web UI 生成客户端配置
- 二维码分享配置

### 访问

- Web UI: `http://vpn.${DOMAIN}:51821`
- 用户名: `admin`
- 密码: `WG_EASY_PASSWORD`

### 客户端配置

1. 访问 WireGuard Web UI
2. 点击 "New Client" 创建客户端
3. 下载配置文件或扫描二维码
4. 在 WireGuard 客户端导入配置

### 路由配置

默认配置下，VPN 客户端只能访问内网：
- VPN 网段: `10.8.0.0/24`
- VPN DNS: `10.8.0.1` (指向 AdGuard Home)

如需 VPN 客户端访问外网，需设置 `WG_ALLOWED_IPS=0.0.0.0/0`

## Cloudflare DDNS

### 功能

- 自动更新 Cloudflare DNS 记录
- 支持 IPv4 和 IPv6
- 多域名支持

### 配置说明

```env
CF_API_KEY=your_api_key
CF_API_EMAIL=your@email.com
CF_ZONE_ID=your_zone_id
CF_RECORD_NAME=ddns.yourdomain.com
CF_RECORD_TYPE=A  # 或 AAAA
```

### 验证

```bash
docker logs cloudflare-ddns
```

## Unbound 递归 DNS

### 功能

- 本地递归 DNS 解析
- 隐私保护（不记录查询日志）
- 加速 DNS 查询（缓存）

### 作为 AdGuard Home 上游

在 AdGuard Home 设置上游 DNS 为：
- `http://unbound:53/dns-query` (DoH)
- 或直接 `10.8.0.x:53` (普通 DNS)

## Nginx Proxy Manager (可选)

### 功能

- 反向代理管理界面
- 免费 SSL 证书申请
- 域名托管

### 访问

- URL: `http://npm.${DOMAIN}:8181`
- 默认邮箱: `admin@example.com`
- 默认密码: `changeme`

## 故障排除

### AdGuard Home 无法启动

```bash
# 检查端口占用
sudo ss -tulpn | grep ':53'

# 修复 DNS 端口冲突
sudo ./scripts/fix-dns-port.sh --check
sudo ./scripts/fix-dns-port.sh --apply
```

### WireGuard 客户端无法连接

1. 检查防火墙允许 UDP 51820
2. 确认 `WG_HOST` 配置正确（必须是公网可访问的域名）
3. 检查端口映射是否正确

### Cloudflare DDNS 更新失败

```bash
# 查看日志
docker logs cloudflare-ddns

# 检查配置
docker exec cloudflare-ddns env | grep CF_
```

## 相关文档

- [AdGuard Home](https://adguard-dns.io/)
- [WireGuard Easy](https://github.com/wg-easy/wg-easy)
- [Cloudflare DDNS](https://github.com/favonia/cloudflare-ddns)
- [Unbound](https://www.unbound.net/)
- [Nginx Proxy Manager](https://nginxproxymanager.com/)
