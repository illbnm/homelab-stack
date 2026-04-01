# 网络服务栈部署指南

AdGuard Home + WireGuard + Cloudflare DDNS + Nginx Proxy Manager

## 🚀 快速开始

### 1. 环境要求
- Docker 和 Docker Compose
- Linux 系统（推荐 Ubuntu 20.04+）
- 至少 2GB 内存
- 开放端口: 53, 80, 443, 51820, 51821

### 2. 克隆配置
```bash
git clone <repository-url>
cd network-stack
```

### 3. 配置环境变量
```bash
cp .env.example .env
# 编辑 .env 文件，设置您的配置
vim .env
```

### 4. 处理 systemd-resolved 端口冲突
```bash
# 检查当前状态
sudo ./fix-dns-port.sh --check

# 禁用 systemd-resolved 的 53 端口占用
sudo ./fix-dns-port.sh --apply
```

### 5. 启动服务
```bash
docker-compose up -d
```

### 6. 访问服务
- **AdGuard Home**: http://localhost:80 (初始配置: http://localhost:3000)
- **WireGuard Web UI**: http://localhost:51821
- **Nginx Proxy Manager**: http://localhost:81
  - 默认登录: admin@example.com / changeme

## 📋 服务详情

### AdGuard Home (DNS 过滤 + 广告拦截)
- **镜像**: `adguard/adguardhome:v0.107.52`
- **端口**: 
  - 53/tcp, 53/udp - DNS 服务
  - 80/tcp - Web 管理界面
  - 443/tcp - HTTPS 管理界面
  - 3000/tcp - 初始配置端口
- **上游 DNS**: 指向 Unbound (172.20.0.2:5353)

### WireGuard Easy (VPN 服务端)
- **镜像**: `ghcr.io/wg-easy/wg-easy:14`
- **端口**:
  - 51820/udp - WireGuard 协议
  - 51821/tcp - Web 管理界面
- **功能**: 
  - Web UI 客户端管理
  - 自动生成二维码配置
  - Split tunneling 支持

### Cloudflare DDNS (动态 DNS)
- **镜像**: `ghcr.io/favonia/cloudflare-ddns:1.14.0`
- **配置**: 需要 Cloudflare API Token
- **功能**:
  - IPv4/IPv6 双栈支持
  - 多域名配置
  - 自动 IP 检测和更新

### Unbound (递归 DNS 解析器)
- **镜像**: `mvance/unbound:1.21.1`
- **端口**: 5353/tcp, 5353/udp
- **功能**: 本地递归 DNS 解析，增强隐私

### Nginx Proxy Manager (反向代理)
- **镜像**: `jc21/nginx-proxy-manager:2.11.3`
- **端口**:
  - 81/tcp - 管理界面
  - 80/tcp - HTTP 代理
  - 443/tcp - HTTPS 代理
- **功能**: 
  - 可视化反向代理配置
  - Let's Encrypt SSL 证书
  - 访问控制

## 🔧 配置指南

### 环境变量说明
完整配置见 `.env.example` 文件：

| 变量名 | 说明 | 默认值 |
|--------|------|--------|
| `TZ` | 时区设置 | Asia/Shanghai |
| `WG_HOST` | WireGuard 公网域名/IP | wireguard.example.com |
| `WG_PASSWORD` | WireGuard Web UI 密码 | changeme |
| `WG_DNS` | VPN 客户端 DNS 服务器 | 172.20.0.2 |
| `CLOUDFLARE_API_TOKEN` | Cloudflare API Token | - |
| `CLOUDFLARE_ZONE` | Cloudflare 域名 | example.com |
| `CLOUDFLARE_SUBDOMAIN` | 子域名 | home |
| `ADGUARD_ADMIN_PASSWORD` | AdGuard Home 管理员密码 | changeme |

### Cloudflare DDNS 配置
1. 获取 Cloudflare API Token:
   - 登录 Cloudflare 控制台
   - 进入 "My Profile" → "API Tokens"
   - 创建 Token，权限: Zone.DNS Edit
2. 在 `.env` 中设置:
   ```bash
   CLOUDFLARE_API_TOKEN=your_token_here
   CLOUDFLARE_ZONE=yourdomain.com
   CLOUDFLARE_SUBDOMAIN=home
   ```

### WireGuard 客户端配置
1. 访问 WireGuard Web UI: http://localhost:51821
2. 使用密码登录（默认: changeme）
3. 创建新客户端，下载配置或扫描二维码
4. 客户端 DNS 设置为 AdGuard Home (172.20.0.2)

### 路由器 DNS 配置
为了让局域网设备使用 AdGuard Home:
1. 登录路由器管理界面
2. 找到 DHCP/DNS 设置
3. 将 DNS 服务器设置为 AdGuard Home 的 IP 地址
4. 重启路由器或更新 DHCP 租约

## 🛠️ 故障排除

### 53 端口冲突
```bash
# 检查端口占用
sudo ss -lpn | grep :53

# 使用修复脚本
sudo ./fix-dns-port.sh --check
sudo ./fix-dns-port.sh --apply

# 恢复配置（如需）
sudo ./fix-dns-port.sh --restore
```

### 服务启动失败
```bash
# 查看日志
docker-compose logs adguard
docker-compose logs wireguard

# 重启服务
docker-compose restart adguard

# 检查网络配置
docker network ls
docker network inspect network-stack_network-stack
```

### DNS 解析问题
1. 检查 AdGuard Home 上游 DNS 设置
2. 验证 Unbound 服务状态
3. 测试 DNS 解析:
   ```bash
   dig @172.20.0.2 google.com
   nslookup google.com 172.20.0.2
   ```

### VPN 连接问题
1. 检查 WireGuard 端口映射 (51820/udp)
2. 验证防火墙设置
3. 检查客户端配置的 endpoint 地址

## 🔒 安全建议

### 1. 修改默认密码
- AdGuard Home: 首次访问时修改
- WireGuard Web UI: 在 `.env` 中设置 `WG_PASSWORD`
- Nginx Proxy Manager: 首次登录后修改

### 2. 启用 HTTPS
- 使用 Nginx Proxy Manager 为服务配置 SSL 证书
- 配置 Let's Encrypt 自动续期

### 3. 防火墙配置
```bash
# 只开放必要端口
sudo ufw allow 53/udp
sudo ufw allow 53/tcp
sudo ufw allow 51820/udp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable
```

### 4. 定期更新
```bash
# 更新镜像
docker-compose pull
docker-compose up -d

# 备份配置
tar -czf backup-$(date +%Y%m%d).tar.gz adguard/ wireguard/ nginx-proxy-manager/
```

## 📊 健康检查
所有服务都配置了健康检查，可以使用以下命令监控:
```bash
# 查看服务状态
docker-compose ps

# 查看健康状态
docker inspect --format='{{.State.Health.Status}}' adguard

# 监控日志
docker-compose logs -f --tail=50
```

## 🤝 贡献
欢迎提交 Issue 和 Pull Request 来改进此项目。

## 📄 许可证
MIT License