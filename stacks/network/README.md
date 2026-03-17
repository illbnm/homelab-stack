# Network Stack

> DNS过滤、VPN接入、动态域名服务

## 服务清单

| 服务 | 镜像 | 端口 | 用途 |
|------|------|------|------|
| AdGuard Home | adguard/adguardhome:v0.107.52 | 53, 3000 | DNS过滤 + 广告屏蔽 |
| WireGuard Easy | ghcr.io/wg-easy/wg-easy:14 | 51820/udp, 51821 | VPN服务 |
| Cloudflare DDNS | ghcr.io/favonia/cloudflare-ddns:1.14.0 | - | 动态DNS |
| Unbound | mvance/unbound:1.21.1 | 53 | 递归DNS解析 |

## 快速开始

### 1. 环境变量

在 `.env` 中添加以下变量：

```bash
# AdGuard Home
ADGUARD_DOMAIN=adguard.yourdomain.com
ADGUARD_PASSWORD=your_secure_password
ADGUARD_IP=10.13.13.1

# WireGuard
WG_HOST=yourdomain.com
WG_PASSWORD=your_wg_password

# Cloudflare DDNS
CF_DDNS_TOKEN=your_cloudflare_token
CF_API_TOKEN=your_api_token
CF_API_EMAIL=your_email@example.com
CF_ZONE=yourdomain.com
CF_RECORD=yourdomain.com
```

### 2. 启动服务

```bash
# 启动网络栈
docker compose -f stacks/network/docker-compose.yml up -d
```

### 3. 访问

- **AdGuard Home**: http://adguard.yourdomain.com (或 localhost:3000)
- **WireGuard Web UI**: http://localhost:51821

## 服务配置

### AdGuard Home

#### 基本配置

首次登录后，在 "设置" → "DNS" 中配置：

1. **上游DNS服务器**:
   - `10.13.13.2:53` (Unbound)
   - `1.1.1.1`
   - `1.0.0.1`

2. **过滤规则**: 启用内置的广告过滤

#### 路由器DNS配置

在路由器设置中，将DNS服务器指向运行AdGuard主机的IP:

```
主DNS: <AdGuard主机IP>:53
```

#### 与其他服务集成

**Traefik集成** (使用AdGuard作为DNS解析):
```yaml
# 在docker-compose中
extra_hosts:
  - "host.docker.internal:host-gateway"
```

### WireGuard Easy

#### 客户端配置

1. 访问 Web UI (端口51821)
2. 使用设置的密码登录
3. 创建新客户端
4. 扫描生成的二维码或下载配置文件

#### 客户端下载

- **iOS**: App Store → WireGuard
- **Android**: Google Play → WireGuard
- **Windows/Mac/Linux**: https://www.wireguard.com/install/

#### Split Tunneling

在 "高级" 中配置只转发内网流量:

```bash
AllowedIPs: 10.13.13.0/24, 192.168.0.0/16
```

### Cloudflare DDNS

#### 配置

确保在Cloudflare创建API令牌:

1. 登录 Cloudflare Dashboard
2. 个人资料 → API令牌
3. 创建自定义令牌，权限:
   - Zone → DNS → Edit
   - Zone → Zone → Read

#### 多域名配置

如需更新多个域名，创建多个容器实例或使用自定义配置。

### Unbound

#### 作为上游DNS

AdGuard Home可将DNS请求转发到Unbound进行本地解析:

```
上游DNS: 10.13.13.2:53
```

#### 验证

```bash
# 测试DNS解析
dig @10.13.13.2 google.com

# 测试缓存
dig @10.13.13.2 google.com
# 第二次查询应该更快
```

## 网络架构

```
Internet
   │
   ├── WireGuard VPN (51820/udp)
   │
   ├── Cloudflare DDNS (后台任务)
   │
   ▼
[AdGuard Home:53] ──► [Unbound:53] ──► 1.1.1.1 (上游)
   │
   ├── 广告过滤
   ├── DNS重写
   └── DHCP (可选)
```

## 故障排除

### AdGuard无法启动 (端口53被占用)

```bash
# 检查哪个进程占用了53端口
sudo lsof -i :53

# 如果是systemd-resolved
sudo systemctl disable --now systemd-resolved
sudo rm /etc/resolv.conf
echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf

# 或者使用项目提供的脚本
./scripts/fix-dns-port.sh --apply
```

### WireGuard无法连接

```bash
# 检查内核模块
sudo modprobe wireguard

# 检查端口是否开放
sudo ufw allow 51820/udp

# 查看日志
docker logs homelab-wg-easy
```

### Cloudflare DDNS更新失败

```bash
# 检查日志
docker logs homelab-cloudflare-ddns

# 验证API令牌
curl -X GET "https://api.cloudflare.com/client/v4/zones" \
  -H "Authorization: Bearer $CF_API_TOKEN"
```

## 验收标准

- [ ] AdGuard Home Web UI 可访问
- [ ] AdGuard 可解析DNS请求
- [ ] 广告过滤正常工作
- [ ] WireGuard Web UI 可访问
- [ ] WireGuard 客户端可连接
- [ ] 客户端可访问内网服务
- [ ] DDNS 成功更新DNS记录
- [ ] Unbound 可递归解析
- [ ] README 配置说明完整可操作
