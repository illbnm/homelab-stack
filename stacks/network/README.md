# Network Stack — 网络服务栈

完整的家庭网络基础设施，包括 DNS 过滤、VPN 接入、动态域名解析。

## 📦 服务清单

| 服务 | 镜像 | 用途 | 访问地址 | 端口 |
|------|------|------|----------|------|
| AdGuard Home | adguard/adguardhome:v0.107.55 | DNS 过滤 + 广告屏蔽 | https://dns.${DOMAIN} | 53/TCP, 53/UDP |
| WireGuard Easy | ghcr.io/wg-easy/wg-easy:14 | VPN 服务端 | https://vpn.${DOMAIN} | 51820/UDP |
| Cloudflare DDNS | ghcr.io/favonia/cloudflare-ddns:1.14.0 | 动态 DNS 更新 | - | - |
| Unbound | mvance/unbound:1.21.1 | 递归 DNS 解析器 | - | 54/TCP, 54/UDP |

## 🚀 快速开始

### 1. 配置环境变量

```bash
cd stacks/network
cp .env.example .env
nano .env
```

**必需配置**:
```bash
# WireGuard
WG_HOST=yourdomain.com         # 你的公网 IP 或域名
WG_PASSWORD=your-secure-password

# Cloudflare DDNS
CF_API_TOKEN=your-cloudflare-api-token
CF_ZONE_ID=your-zone-id
CF_RECORD_NAME=home            # 将更新 home.yourdomain.com
```

### 2. 解决 DNS 端口冲突（如果需要）

如果系统上 systemd-resolved 占用了 53 端口：

```bash
# 检查端口占用
sudo ./scripts/fix-dns-port.sh --check

# 应用修复
sudo ./scripts/fix-dns-port.sh --apply

# 验证修复
sudo ./scripts/fix-dns-port.sh --status
```

### 3. 启动服务

```bash
docker compose up -d
```

### 4. 验证服务

```bash
docker compose ps
# 所有服务应显示为 healthy
```

## 📋 服务配置

### AdGuard Home

**首次设置**:
1. 访问 https://dns.${DOMAIN}
2. 完成初始化向导
3. 配置上游 DNS 为 Unbound (127.0.0.1:54)
4. 添加过滤列表：
   - AdGuard DNS filter
   - AdGuard Tracking Protection
   - EasyList
   - EasyPrivacy
   - 中文过滤规则（可选）

**推荐配置**:
```yaml
上游 DNS 服务器:
  - 127.0.0.1:54  # Unbound
  - tls://dns.quad9.net  # 备用

DNS 设置:
  - 启用 DNSSEC
  - 禁用 IPv6（如不需要）
  - 启用客户端子网（ECS）

访问控制:
  - 允许内网网段：192.168.0.0/16, 10.0.0.0/8
  - 阻止特定设备（可选）
```

### WireGuard Easy

**客户端配置**:
1. 访问 https://vpn.${DOMAIN}
2. 使用配置的密码登录
3. 点击 "Create" 创建新客户端
4. 扫描二维码或下载配置文件

**客户端配置文件示例**:
```ini
[Interface]
PrivateKey = <client-private-key>
Address = 10.8.0.2/24
DNS = 10.8.0.2  # AdGuard Home IP

[Peer]
PublicKey = <server-public-key>
Endpoint = yourdomain.com:51820
AllowedIPs = 0.0.0.0/0
```

**Split Tunneling（分流）**:
只路由特定流量通过 VPN：
```ini
# 仅路由内网流量
AllowedIPs = 192.168.0.0/16, 10.0.0.0/8

# 或仅路由特定网站
AllowedIPs = 192.168.0.0/16, 10.0.0.0/8, <specific-IPs>
```

### Cloudflare DDNS

**获取 API Token**:
1. 登录 Cloudflare Dashboard
2. 进入 My Profile → API Tokens
3. 创建新 Token，权限：
   - Zone → DNS → Edit
   - Zone → Zone → Read
4. 复制 Token 到 `.env` 文件的 `CF_API_TOKEN`

**获取 Zone ID**:
1. 在 Cloudflare Dashboard 选择域名
2. 右侧栏找到 "API" 部分
3. 复制 "Zone ID"

**验证 DDNS**:
```bash
# 查看 DDNS 日志
docker logs cloudflare-ddns

# 检查 DNS 记录
dig home.yourdomain.com
```

### Unbound

**默认配置**已优化：
- 启用 DNSSEC 验证
- 启用缓存
- 隐私保护（隐藏客户端信息）
- 自动更新根提示

**自定义配置**（可选）:
```bash
# 编辑 Unbound 配置
docker exec -it unbound vi /opt/unbound/etc/unbound/unbound.conf

# 重启服务
docker compose restart unbound
```

## 🔧 故障排查

### AdGuard Home 无法启动

```bash
# 检查端口占用
sudo ss -tulnp | grep ':53'

# 查看日志
docker logs adguardhome

# 如果 systemd-resolved 占用 53 端口
sudo ./scripts/fix-dns-port.sh --apply
```

### WireGuard 客户端无法连接

```bash
# 检查服务器状态
docker logs wireguard-easy

# 验证端口开放
sudo ss -ulnp | grep 51820

# 检查防火墙
sudo ufw allow 51820/udp
```

### DDNS 更新失败

```bash
# 查看详细日志
docker logs cloudflare-ddns

# 验证 API Token
curl -X GET "https://api.cloudflare.com/client/v4/user" \
  -H "Authorization: Bearer $CF_API_TOKEN"

# 检查 Zone ID
curl -X GET "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID" \
  -H "Authorization: Bearer $CF_API_TOKEN"
```

### DNS 解析慢

```bash
# 测试 Unbound
dig @127.0.0.1 -p 54 example.com

# 测试 AdGuard Home
dig @127.0.0.1 example.com

# 查看 Unbound 统计
docker exec unbound unbound-control stats
```

## 📊 路由器配置

### 将 AdGuard Home 设为默认 DNS

**常见路由器配置**:

1. **登录路由器管理界面** (通常 192.168.1.1 或 192.168.0.1)

2. **找到 DNS 设置** (通常在 LAN 或 DHCP 设置中)

3. **设置 DNS 服务器**:
   ```
   主 DNS: <homelab-server-IP>  # AdGuard Home 所在服务器 IP
   次 DNS: 1.1.1.1  # 备用
   ```

4. **保存并重启 DHCP**

**验证**:
```bash
# 在客户端设备上
nslookup example.com
# 应显示 AdGuard Home IP 作为服务器
```

## 🔒 安全建议

1. **WireGuard**:
   - 使用强密码
   - 定期轮换密钥
   - 限制 AllowedIPs

2. **AdGuard Home**:
   - 启用管理界面认证
   - 限制访问 IP 范围
   - 定期更新过滤列表

3. **DDNS**:
   - 使用 API Token 而非全局 API Key
   - 限制 Token 权限
   - 定期轮换 Token

## 📈 监控

### AdGuard Home 指标

- 查询总数
- 广告拦截率
-  Top 查询域名
- Top 客户端

访问：https://dns.${DOMAIN} → 仪表板

### WireGuard 指标

- 活跃客户端数
- 数据传输量
- 连接状态

访问：https://vpn.${DOMAIN} → 仪表板

### Unbound 指标

```bash
# 查看缓存统计
docker exec unbound unbound-control status

# 查看缓存命中率
docker exec unbound unbound-control stats | grep cache
```

## 📚 相关文档

- [灾难恢复](../docs/disaster-recovery.md)
- [DNS 端口修复](../scripts/fix-dns-port.sh --help)

## 💰 赏金信息

- **Issue**: #4 - Network Stack
- **金额**: $140 USDT
- **状态**: 已完成

---

*最后更新：2026-03-18*
