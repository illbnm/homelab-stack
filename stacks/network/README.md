# 🌐 Network Stack — 网络服务栈

> DNS 过滤 + VPN 接入 + 动态域名 + 递归 DNS 解析

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Docker](https://img.shields.io/badge/docker-required-blue.svg)](https://docs.docker.com/get-docker/)

---

## 📦 包含服务

| 服务 | 镜像 | 用途 | 端口 |
|------|------|------|------|
| **AdGuard Home** | `adguard/adguardhome:v0.107.52` | DNS 过滤 + 广告屏蔽 | 53 (TCP/UDP), 3053 |
| **Unbound** | `mvance/unbound:1.21.1` | 递归 DNS 解析器 | 127.0.0.1:5053 |
| **WireGuard Easy** | `ghcr.io/wg-easy/wg-easy:14` | VPN 服务端（Web UI） | 51820 (UDP), 51821 |
| **Cloudflare DDNS** | `ghcr.io/favonia/cloudflare-ddns:1.14.0` | 动态 DNS 更新 | - |

---

## 🚀 快速开始

### 1. 前置检查 — 53 端口冲突

AdGuard Home 需要监听 53 端口，可能与 `systemd-resolved` 冲突。**首次使用前必须运行**：

```bash
# 检测 53 端口占用
sudo ./scripts/fix-dns-port.sh --check

# 如果检测到冲突，应用修复
sudo ./scripts/fix-dns-port.sh --apply

# 还原配置（如需）
sudo ./scripts/fix-dns-port.sh --restore
```

### 2. 配置环境变量

```bash
# 编辑 .env 文件
nano .env

# 关键配置项：
# DOMAIN=yourdomain.com
# WG_HOST=vpn.yourdomain.com
# WG_PASSWORD=your_vpn_password
# CF_API_TOKEN=your_cloudflare_token
# CF_ZONE_ID=your_zone_id
# CF_RECORD_NAME=home.yourdomain.com
```

### 3. 启动服务

```bash
# 确保 base stack 已运行
docker compose -f stacks/base/docker-compose.yml up -d

# 启动网络栈
docker compose -f stacks/network/docker-compose.yml up -d
```

### 4. 访问服务

| 服务 | URL | 默认凭证 |
|------|-----|---------|
| AdGuard Home | https://adguard.`${DOMAIN}` | 首次启动设置 |
| WireGuard Web UI | https://wg.`${DOMAIN}` | `WG_PASSWORD` |

---

## ⚙️ 服务配置详解

### AdGuard Home — DNS 过滤

#### 过滤列表配置

在 `config/adguard/adguard.yaml` 中预配置了以下过滤列表：

| 列表名称 | 用途 | 默认状态 |
|---------|------|---------|
| AdGuard DNS filter | 广告屏蔽 | ✅ 已启用 |
| EasyList China | 中文网站广告 | ✅ 已启用 |
| Malware Domain List | 恶意软件域名 | ✅ 已启用 |
| EasyList | 国际广告列表 | ❌ 未启用 |
| EasyPrivacy | 隐私保护 | ❌ 未启用 |

#### 添加自定义过滤列表

1. 访问 AdGuard Home Web UI
2. 进入 **过滤器** → **DNS 封锁清单**
3. 点击 **添加自定义列表**
4. 粘贴过滤规则 URL

常用过滤列表：
```
# AdGuard 基础广告过滤
https://adguardteam.github.io/AdGuardSDNSFilter/Filters/filter.txt

# 中文广告过滤
https://easylist-downloads.adblockplus.org/easylistchina+easylist.txt

# 跟踪器屏蔽
https://adaway.org/hosts.txt

# 恶意软件屏蔽
https://www.malwaredomainlist.com/hostslist/hosts.txt
```

#### 推荐的上游 DNS 设置

```
主上游：127.0.0.1:5053（Unbound 本地递归解析）
备用上游：
  - https://1.1.1.1/dns-query
  - https://dns.google/dns-query
  - tls://1.1.1.1
```

---

### Unbound — 递归 DNS 解析器

Unbound 作为本地递归 DNS 解析器，为 AdGuard Home 提供隐私保护的 DNS 解析。

#### 配置文件

- 路径：`config/unbound/unbound.conf`
- 缓存大小：512MB
- DNSSEC：已启用
- IPv6：已启用

#### 添加本地域名解析

编辑 `config/unbound/unbound.conf` 添加本地域名记录：

```bash
# 例如添加内网服务的域名
local-zone: "lan." static
local-data: "adguard.lan. IN A 10.0.0.2"
local-data: "wireguard.lan. IN A 10.0.0.3"
local-data: "nas.lan. IN A 10.0.0.4"
```

---

### WireGuard Easy — VPN 服务端

#### Split Tunneling 配置

**全流量 VPN（默认）**：所有流量通过 VPN 隧道

**Split Tunneling（推荐内网访问场景）**：只有内网 IP 段走 VPN

在 `.env` 中添加：
```bash
WG_ALLOWED=10.0.0.0/8,172.16.0.0/12,192.168.0.0/16
```

或通过 Web UI 为每个客户端单独配置 `AllowedIPs`。

#### 客户端连接步骤

1. 访问 WireGuard Web UI：https://wg.`${DOMAIN}`
2. 登录（使用 `WG_PASSWORD`）
3. 点击 **New Client** 创建新客户端
4. 下载配置文件或扫描二维码
5. 使用 WireGuard 客户端导入配置

#### 内网 DNS 配置

VPN 客户端 DNS 默认指向 `10.8.0.1`（WireGuard 容器内 AdGuard Home）。

如需解析内网域名：
1. 在 AdGuard Home 中添加自定义 DNS 规则
2. 或在 Unbound 中添加本地域名解析

---

### Cloudflare DDNS — 动态域名

#### 获取 Cloudflare API Token

1. 登录 [Cloudflare Dashboard](https://dash.cloudflare.com)
2. 进入 **My Profile** → **API Tokens**
3. 点击 **Create Token** → 选择 **Edit zone DNS** 模板
4. 设置权限：`Zone > DNS > Edit`
5. 创建并复制 Token

#### 多域名配置

```bash
# .env 配置示例
CF_RECORD_NAME=home.yourdomain.com
CF_RECORD_NAME_2=vpn.yourdomain.com
CF_RECORD_NAME_3=nas.yourdomain.com
```

#### IPv4 + IPv6 双栈

镜像默认同时支持 IPv4 (A 记录) 和 IPv6 (AAAA 记录)：
1. 在 Cloudflare DNS 设置中为每个域名创建 AAAA 记录（值为 `::`）
2. 镜像会自动检测并更新

---

## 📡 路由器 DNS 配置

将路由器 DNS 设置为 AdGuard Home 的 IP，以实现全屋广告屏蔽：

### 路由器 DNS 设置步骤

1. **登录路由器管理界面**（通常是 `192.168.1.1` 或 `192.168.0.1`）

2. **找到 DNS 设置**
   - 路径通常为：`LAN 设置` → `DHCP 服务器` → `DNS 服务器`
   - 或：`网络设置` → `本地 DNS`

3. **设置为主 DNS 服务器**
   ```
   主 DNS：AdGuard Home 的 IP（如 192.168.1.100）
   备用 DNS：1.1.1.1 或 8.8.8.8
   ```

4. **保存并重启路由器**

### 推荐 DNS 配置方案

| 设备 | 主 DNS | 备用 DNS |
|------|--------|---------|
| 路由器 DHCP | `${ADGUARD_IP}` | `1.1.1.1` |
| 内网 AdGuard Home | `127.0.0.1:5053` (Unbound) | `1.1.1.1` |
| VPN 客户端 | `10.8.0.1` (容器内 AdGuard) | `1.1.1.1` |

### AdGuard Home 内网 IP 查询

```bash
# 查看 AdGuard Home 容器 IP
docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' adguardhome
```

### 验证 DNS 解析

```bash
# 直接查询 AdGuard Home
dig @192.168.1.100 example.com

# 查看 AdGuard Home 查询日志
docker logs adguardhome | grep query
```

---

## 🔧 常用操作

### 查看服务状态

```bash
docker compose -f stacks/network/docker-compose.yml ps
```

### 查看日志

```bash
# 所有服务
docker compose -f stacks/network/docker-compose.yml logs -f

# 单个服务
docker compose -f stacks/network/docker-compose.yml logs -f adguardhome
docker compose -f stacks/network/docker-compose.yml logs -f wg-easy
docker compose -f stacks/network/docker-compose.yml logs -f cloudflare-ddns
```

### 重启服务

```bash
docker compose -f stacks/network/docker-compose.yml restart
```

### 停止服务

```bash
docker compose -f stacks/network/docker-compose.yml down
```

---

## 🛠️ 故障排查

### 53 端口被占用

```bash
# 检查占用情况
sudo ss -tulnp | grep :53

# 应用修复
sudo ./scripts/fix-dns-port.sh --apply
```

### AdGuard Home 无法解析 DNS

1. 检查 Unbound 是否正常运行：`docker compose logs unbound`
2. 检查 AdGuard 上游 DNS 配置是否正确
3. 尝试在 AdGuard Web UI 中使用备用上游 DNS

### WireGuard 客户端无法连接

1. 检查端口是否开放：`sudo ss -ulnp | grep 51820`
2. 检查防火墙规则
3. 确认 `WG_HOST` 配置为公网可访问的地址

### Cloudflare DDNS 更新失败

```bash
# 查看详细日志
docker compose -f stacks/network/docker-compose.yml logs cloudflare-ddns

# 检查 API Token 是否正确
docker exec cloudflare-ddns env | grep CF_
```

---

## 📄 配置参考

| 配置文件 | 路径 |
|---------|------|
| AdGuard Home | `config/adguard/adguard.yaml` |
| Unbound | `config/unbound/unbound.conf` |
| WireGuard Easy | `config/wg-easy/README.md` |
| Cloudflare DDNS | `config/cloudflare-ddns/README.md` |
| DNS 端口修复脚本 | `scripts/fix-dns-port.sh` |
