# 家庭网络服务栈 - 完整部署指南

## 📋 服务清单

| 服务 | 镜像 | 端口 | 用途 |
|------|------|------|------|
| AdGuard Home | `adguard/adguardhome:v0.107.52` | 53, 3000 | DNS 过滤 + 广告屏蔽 |
| WireGuard | `ghcr.io/wg-easy/wg-easy:14` | 51820, 51821 | VPN 服务端 |
| Cloudflare DDNS | `ghcr.io/favonia/cloudflare-ddns:1.14.0` | - | 动态 DNS 更新 |
| Unbound | `mvance/unbound:1.21.1` | 5053 | 递归 DNS 解析器 |
| Nginx | `nginx:latest` | 80, 443 | 反向代理 |

---

## 🚀 快速开始（5 步）

### 1️⃣ 克隆仓库并进入目录

```bash
git clone https://github.com/illbnm/homelab-stack.git
cd homelab-stack
```

### 2️⃣ 配置环境变量

```bash
cp .env.example .env
# 编辑 .env，填入：
# - WG_HOST: 你的 VPN 域名
# - WG_PASSWORD: WireGuard Web UI 密码
# - CLOUDFLARE_API_TOKEN: Cloudflare API Token
# - CLOUDFLARE_ZONE_ID: 你的域名 Zone ID
```

### 3️⃣ 处理 DNS 端口冲突（Linux 必需）

```bash
# 检查冲突
bash scripts/fix-dns-port.sh check

# 禁用 systemd-resolved
sudo bash scripts/fix-dns-port.sh apply

# 恢复（如需要）
sudo bash scripts/fix-dns-port.sh restore
```

### 4️⃣ 启动所有服务

```bash
docker-compose up -d
```

### 5️⃣ 验证服务

```bash
# 检查容器状态
docker-compose ps

# 测试 DNS 解析
nslookup google.com 127.0.0.1

# 访问 Web UI
# AdGuard Home: http://localhost:3000
# WireGuard: http://localhost:51821
```

---

## 🔧 详细配置

### AdGuard Home 配置

1. **首次访问**: http://localhost:3000
2. **设置上游 DNS**:
   - 主 DNS: `unbound:53` (内网递归)
   - 备用 DNS: `8.8.8.8` (Google)
3. **启用过滤列表**:
   - https://adguardteam.github.io/AdGuardSDNSFilter/Filters/filter.txt
   - https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts
4. **配置客户端 DNS**:
   - 路由器 DNS: `<你的服务器 IP>:53`
   - 或手动配置设备 DNS: `<你的服务器 IP>`

### WireGuard 配置

1. **首次访问**: http://localhost:51821
2. **输入密码**: 使用 `.env` 中的 `WG_PASSWORD`
3. **添加客户端**:
   - 点击 "Add Peer"
   - 生成配置二维码
   - 用手机/电脑扫描导入
4. **Split Tunneling** (可选):
   - 编辑客户端配置
   - 修改 `AllowedIPs` 为特定网段，如 `10.0.0.0/24`

### Cloudflare DDNS 配置

1. **获取 API Token**:
   - 登录 Cloudflare
   - 右上角 > My Profile > API Tokens
   - 创建 Token，权限: Zone.DNS.Edit
2. **获取 Zone ID**:
   - 选择域名
   - 右侧 "Zone ID" 复制
3. **填入 `.env`**:
   ```
   CLOUDFLARE_API_TOKEN=your_token
   CLOUDFLARE_ZONE_ID=your_zone_id
   CLOUDFLARE_DOMAINS=example.com
   ```
4. **验证更新**:
   ```bash
   docker logs cloudflare-ddns
   ```

### Nginx 反向代理配置

1. **生成 SSL 证书** (自签名):
   ```bash
   mkdir -p nginx/ssl
   openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
     -keyout nginx/ssl/key.pem -out nginx/ssl/cert.pem
   ```
2. **访问服务**:
   - AdGuard: https://example.com/adguard/
   - WireGuard: https://example.com/wireguard/

---

## 🐛 故障排查

### DNS 不工作

```bash
# 检查 AdGuard 日志
docker logs adguard

# 检查 Unbound 日志
docker logs unbound

# 测试 DNS 解析
nslookup google.com 127.0.0.1
dig @127.0.0.1 google.com
```

### WireGuard 无法连接

```bash
# 检查 WireGuard 日志
docker logs wireguard

# 检查端口是否开放
sudo netstat -tulpn | grep 51820

# 检查防火墙
sudo ufw allow 51820/udp
```

### DDNS 未更新

```bash
# 检查 Cloudflare DDNS 日志
docker logs cloudflare-ddns

# 验证 API Token 权限
curl -X GET "https://api.cloudflare.com/client/v4/user/tokens/verify" \
  -H "Authorization: Bearer YOUR_TOKEN"
```

---

## 📝 路由器 DNS 配置

### 常见路由器

**OpenWrt**:
```
Network > DHCP and DNS > DNS Forwardings
添加: <你的服务器 IP>
```

**TP-Link**:
```
Advanced > Network > DHCP Settings
Primary DNS: <你的服务器 IP>
```

**华为**:
```
设置 > 网络设置 > DNS 设置
DNS 1: <你的服务器 IP>
```

---

## 🔐 安全建议

1. **更改默认密码**:
   - AdGuard: 设置 > 用户
   - WireGuard: 修改 `.env` 中的 `WG_PASSWORD`

2. **启用 HTTPS**:
   - 使用 Let's Encrypt 证书替换自签名证书
   - 配置 Nginx SSL

3. **限制访问**:
   - 仅允许内网 IP 访问管理界面
   - 使用 VPN 远程访问

4. **定期备份**:
   ```bash
   docker-compose exec adguard tar czf - /opt/adguardhome/conf > adguard-backup.tar.gz
   ```

---

## 📞 支持

- AdGuard Home: https://github.com/AdguardTeam/AdGuardHome
- WireGuard: https://www.wireguard.com/
- Unbound: https://nlnetlabs.nl/projects/unbound/
- Cloudflare DDNS: https://github.com/favonia/cloudflare-ddns

---

**最后更新**: 2026-03-30
