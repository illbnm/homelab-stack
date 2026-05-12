# Network Stack — 网络服务栈

AdGuard Home + Unbound + WireGuard + Cloudflare DDNS + Nginx Proxy Manager

## 目录结构

```
stacks/network/
├── docker-compose.yml      # 服务编排
├── .env.example            # 环境变量模板
├── scripts/
│   └── fix-dns-port.sh     # systemd-resolved 冲突修复
└── README.md               # 本文档
```

## 快速开始

```bash
# 1. 配置环境变量
cp .env.example .env
# 编辑 .env，填入域名、API Token 等

# 2. 修复 systemd-resolved 53 端口占用
sudo ./scripts/fix-dns-port.sh --check
sudo ./scripts/fix-dns-port.sh --apply   # 如需修复

# 3. 启动网络栈
docker compose up -d

# 4. 检查服务状态
docker compose ps
```

## 服务说明

| 服务 | 端口 | 用途 | 管理面板 |
|------|------|------|---------|
| **AdGuard Home** | 53/UDP, 3000 | DNS 过滤 + 广告屏蔽 | `http://adguard.${DOMAIN}` |
| **Unbound** | 5053/UDP | 递归 DNS 解析器 | — |
| **WireGuard** | 51820/UDP, 51821 | VPN 服务端 | `http://wg.${DOMAIN}` |
| **Cloudflare DDNS** | — | 动态 DNS 更新 | — |
| **Nginx Proxy Manager** | 81 | 反向代理管理 | `http://npm.${DOMAIN}` |

## 路由器 DNS 配置

为使局域网设备自动使用 AdGuard Home 过滤广告，需在路由器中设置 DNS：

1. 登录路由器管理后台
2. 找到 DHCP 设置 → DNS 服务器
3. 将主 DNS 设为运行 AdGuard Home 的服务器 IP
4. （可选）备用 DNS 设为 `1.1.1.1` 或 `8.8.8.8`
5. 保存并重启路由器 / 刷新 DHCP 租约

> 部分路由器（如 OpenWrt）也可通过 SSH 修改 `/etc/config/dhcp`：
> ```
> list dns '192.168.1.2'
> ```

## 验证方法

```bash
# DNS 解析测试
dig @localhost google.com

# 广告过滤测试
dig @localhost doubleclick.net

# WireGuard 客户端连通性
ping 10.8.0.1

# DDNS 更新检查
# 登录 Cloudflare Dashboard 查看 DNS 记录是否更新
```

## 常见问题

### AdGuard Home 无法绑定 53 端口

运行 `sudo ./scripts/fix-dns-port.sh --apply` 禁用 systemd-resolved 的 DNS 缓存。

### WireGuard 客户端无法连接

- 确认服务器 51820/UDP 端口已开放
- 检查 `WG_HOST` 是否设为正确的公网 IP 或域名
- 确保内核支持 IP 转发：`sysctl net.ipv4.ip_forward`

### 国内镜像加速

```bash
# 如使用国内服务器，可替换镜像源
sed -i 's|ghcr.io/wg-easy/wg-easy|ghcr.dockerproxy.com/wg-easy/wg-easy|g' docker-compose.yml
```
