# Network Stack — AdGuard Home + WireGuard + Nginx Proxy Manager

家庭网络基础设施栈，提供 DNS 过滤、VPN 接入、动态域名和反向代理服务。

## 📦 服务清单

| 服务 | 版本 | URL | 端口 | 用途 |
|------|------|-----|------|------|
| **AdGuard Home** | v0.107.52 | `adguard.<DOMAIN>` | 53 (DNS), 3000 (Web) | DNS 过滤 + 广告拦截 |
| **WireGuard Easy** | 14 | `wireguard.<DOMAIN>` | 51820 (VPN), 51821 (Web) | VPN 服务端 |
| **Cloudflare DDNS** | 1.14.0 | — | — | 动态 DNS 更新 |
| **Unbound** | 1.21.1 | — | 5335 (DNS) | 递归 DNS 解析器 |
| **Nginx Proxy Manager** | 2.11.3 | `npm.<DOMAIN>` | 8181 (Web) | 反向代理管理 UI |

## 🏗️ 架构图

```
Internet
    │
    ├──► [Cloudflare DDNS] ──► 自动更新 DNS 记录
    │
    └──► [Traefik :443]
             │
             ├──► adguard.<DOMAIN>  → AdGuard Home (DNS 过滤)
             ├──► wireguard.<DOMAIN> → WireGuard Web UI
             ├──► npm.<DOMAIN>      → Nginx Proxy Manager
             │
             └──► [Unbound :5335] ──► 递归 DNS 解析
                       │
                       └──► AdGuard Home 上游 DNS

WireGuard Clients (10.8.0.x)
    │
    └──► DNS: 10.8.0.1 (AdGuard Home)
         └──► 广告拦截 + 隐私保护
```

## ⚡ 快速开始

### 前置条件

1. **Base Stack 已部署** — 必须先运行 `stacks/base`
2. **Docker 网络** — `proxy` 网络已创建
3. **域名配置** — 域名指向服务器 IP
4. **Cloudflare 账户** — 用于 DDNS 服务

### 步骤 1: 准备环境

```bash
# 进入网络栈目录
cd stacks/network

# 复制环境变量配置
cp .env.example .env

# 编辑 .env 文件，填入你的配置
nano .env
```

### 步骤 2: 获取 Cloudflare API Token

1. 登录 [Cloudflare Dashboard](https://dash.cloudflare.com/)
2. 进入 **My Profile** → **API Tokens**
3. 创建新 Token，选择 **Edit zone DNS** 模板
4. 选择你的 Zone（域名）
5. 复制 API Token 到 `.env` 的 `CF_API_TOKEN`

### 步骤 3: 获取 Zone ID

```bash
# 使用 curl 获取 Zone ID
curl -X GET "https://api.cloudflare.com/v4/zones" \
  -H "Authorization: Bearer YOUR_API_TOKEN" \
  -H "Content-Type: application/json"

# 或在 Cloudflare Dashboard 右侧边栏找到 Zone ID
```

### 步骤 4: 释放端口 53（重要！）

AdGuard Home 需要占用 53 端口，但 systemd-resolved 可能已占用：

```bash
# 检查端口 53 状态
sudo ./scripts/fix-dns-port.sh --status

# 应用修复（移动 systemd-resolved 到 5353 端口）
sudo ./scripts/fix-dns-port.sh --apply

# 验证端口 53 已释放
sudo ./scripts/fix-dns-port.sh --check
```

### 步骤 5: 启动服务

```bash
# 创建外部网络（如果不存在）
docker network create proxy

# 启动所有服务
docker compose up -d

# 查看日志
docker compose logs -f

# 检查健康状态
docker compose ps
```

## ⚙️ 配置说明

### 环境变量 (.env)

| 变量 | 必填 | 说明 | 示例 |
|------|------|------|------|
| `DOMAIN` | ✅ | 基础域名 | `home.example.com` |
| `WG_HOST` | ✅ | WireGuard 服务器地址（公网 IP 或域名） | `vpn.example.com` |
| `WG_PASSWORD` | ✅ | WireGuard Web UI 登录密码 | `StrongPass123!` |
| `CF_API_TOKEN` | ✅ | Cloudflare API Token | `见上方获取步骤` |
| `CF_ZONE_ID` | ✅ | Cloudflare Zone ID | `abc123xyz456` |
| `CF_RECORD_NAME` | ✅ | 要更新的 DNS 记录 | `home.example.com` |
| `TZ` | ✅ | 时区 | `Asia/Shanghai` |

### AdGuard Home 配置

**首次访问**: `http://adguard.<DOMAIN>`

1. 设置管理员账号密码
2. 配置上游 DNS 服务器：
   - 主 DNS: `unbound:53` (容器内)
   - 备用 DNS: `1.1.1.1` 或 `8.8.8.8`
3. 添加过滤列表（推荐）：
   - AdGuard DNS filter
   - AdAway Default Blocklist
   - EasyList
   - EasyPrivacy
4. 配置 DHCP 服务器（可选）

**在路由器中配置 DNS**:
- 将路由器 DNS 服务器指向服务器 IP
- 所有局域网设备自动享受广告拦截

### WireGuard 配置

**访问 Web UI**: `https://wireguard.<DOMAIN>`

1. 使用 `.env` 中设置的 `WG_PASSWORD` 登录
2. 点击 **+** 创建新客户端
3. 扫描 QR 码或下载配置文件
4. 在客户端设备导入配置并连接

**客户端配置示例** (自动填充):
```ini
[Interface]
PrivateKey = <自动生成>
Address = 10.8.0.2/24
DNS = 10.8.0.1  # AdGuard Home - 享受广告拦截

[Peer]
PublicKey = <服务器公钥>
Endpoint = <WG_HOST>:51820
AllowedIPs = 0.0.0.0/0  # 全流量走 VPN
```

**Split Tunneling** (仅特定流量走 VPN):
```ini
# 只让内网流量走 VPN
AllowedIPs = 192.168.0.0/16, 10.0.0.0/8

# 或只访问特定服务
AllowedIPs = 192.168.1.0/24
```

### Nginx Proxy Manager 配置

**访问**: `https://npm.<DOMAIN>`

- 默认账号：`admin@example.com`
- 默认密码：`changeme`

**用途**:
- 为不支持 Traefik 的服务提供反向代理
- 管理 SSL 证书
- 配置访问控制

### Cloudflare DDNS 配置

服务自动运行，无需手动干预。日志查看：

```bash
docker compose logs cloudflare-ddns
```

成功时看到类似输出：
```
Updating A record for home.example.com to 123.45.67.89
Success!
```

## 🔍 验证与测试

### 1. 验证 AdGuard Home DNS 解析

```bash
# 测试 DNS 解析（替换为服务器 IP）
dig @<SERVER_IP> example.com

# 测试广告域名拦截
dig @<SERVER_IP> doubleclick.net
# 应该返回 0.0.0.0 或 NXDOMAIN
```

### 2. 验证 WireGuard 连接

```bash
# 在客户端连接后，测试内网访问
ping 192.168.1.1  # 路由器
curl http://adguard.home  # 内网服务

# 验证 DNS 走 AdGuard
curl https://dns.adguard-dns.com/dns-query
```

### 3. 验证 DDNS 更新

```bash
# 查看当前公网 IP
curl https://api.ipify.org

# 检查 Cloudflare DNS 记录
curl -X GET "https://api.cloudflare.com/v4/zones/ZONE_ID/dns/records" \
  -H "Authorization: Bearer TOKEN" \
  -H "Content-Type: application/json"
```

### 4. 健康检查

```bash
# 所有服务状态
docker compose ps

# 预期输出：
# NAME                  STATUS
# adguardhome           Up (healthy)
# wireguard             Up (healthy)
# cloudflare-ddns       Up (healthy)
# unbound               Up (healthy)
# nginx-proxy-manager   Up (healthy)
```

## 🛠️ 故障排除

### 端口 53 冲突

**症状**: AdGuard Home 无法启动，日志显示 `address already in use`

```bash
# 检查谁占用了 53 端口
sudo ss -tulnp | grep ':53'

# 如果是 systemd-resolved
sudo ./scripts/fix-dns-port.sh --apply

# 或临时停止 systemd-resolved
sudo systemctl stop systemd-resolved
sudo systemctl disable systemd-resolved
```

### WireGuard 无法连接

**检查项**:
1. 确认 `WG_HOST` 是公网可达的 IP 或域名
2. 防火墙开放 UDP 51820 端口
3. 检查客户端配置中的 PublicKey 和 Endpoint

```bash
# 防火墙开放端口 (UFW)
sudo ufw allow 51820/udp

# 防火墙开放端口 (firewalld)
sudo firewall-cmd --add-port=51820/udp --permanent
sudo firewall-cmd --reload
```

### DDNS 更新失败

**检查项**:
1. API Token 权限是否正确（需要 Zone DNS Edit）
2. Zone ID 是否正确
3. 域名是否在 Cloudflare 管理

```bash
# 查看 DDNS 日志
docker compose logs cloudflare-ddns

# 测试 API Token
curl -X GET "https://api.cloudflare.com/v4/zones" \
  -H "Authorization: Bearer YOUR_TOKEN"
```

### AdGuard Home 无法访问

**检查项**:
1. Traefik 配置是否正确
2. DNS 记录是否指向服务器
3. SSL 证书是否签发成功

```bash
# 查看 Traefik 日志
docker compose logs traefik

# 检查证书
docker compose exec traefik ls -la /acme.json
```

## 🔄 备份与恢复

### 备份配置

```bash
# 备份所有卷数据
docker compose run --rm -v $(pwd)/backup:/backup \
  alpine tar czf /backup/network-stack-backup.tar.gz \
  /var/lib/docker/volumes/network_*

# 或使用备份脚本
./scripts/backup.sh network
```

### 恢复配置

```bash
# 停止服务
docker compose down

# 恢复数据
docker compose run --rm -v $(pwd)/backup:/backup \
  alpine tar xzf /backup/network-stack-backup.tar.gz -C /

# 重启服务
docker compose up -d
```

## 📝 路由器 DNS 配置说明

为了让所有局域网设备享受 AdGuard Home 的广告拦截功能，需要在路由器中配置 DNS：

### 常见路由器配置

**TP-Link**:
1. 登录路由器管理页面 (通常 192.168.1.1)
2. 网络参数 → LAN 口设置
3. DNS 服务器：填写服务器 IP
4. 保存并重启路由器

**ASUS**:
1. 登录路由器管理页面
2. 内部网络 (LAN) → DHCP 服务器
3. DNS 和 WINS 服务器设置 → 手动设置
4. DNS Server 1: 服务器 IP
5. 应用设置

**OpenWrt**:
1. SSH 登录路由器
2. 编辑 `/etc/config/dhcp`
3. 添加/修改：
   ```
   config dhcp 'lan'
     option dns '192.168.1.100'  # 服务器 IP
   ```
4. 重启服务：`/etc/init.d/dnsmasq restart`

**验证配置生效**:
```bash
# 在任意局域网设备执行
nslookup example.com
# Server 应该显示为你的服务器 IP
```

## 🔒 安全建议

1. **强密码**: 为所有服务设置强密码
2. **防火墙**: 仅开放必要端口（80, 443, 51820）
3. **定期更新**: 使用 Watchtower 自动更新容器
4. **备份配置**: 定期备份重要配置和数据
5. **WireGuard**: 仅分享 QR 码给信任设备
6. **API Token**: 定期轮换 Cloudflare API Token

## 📚 参考链接

- [AdGuard Home 官方文档](https://adguard.com/en/adguard-home/overview.html)
- [WireGuard Easy GitHub](https://github.com/wg-easy/wg-easy)
- [Cloudflare DDNS GitHub](https://github.com/favonia/cloudflare-ddns)
- [Unbound DNS GitHub](https://github.com/MvanceVideo/docker-unbound)
- [Nginx Proxy Manager](https://nginxproxymanager.com/)
