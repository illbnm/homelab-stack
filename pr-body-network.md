## 任务

Closes #4 — `[BOUNTY $120] Network Stack — 网络服务`

## 交付内容

### 1. stacks/network/docker-compose.yml
- AdGuard Home v0.107.52 — DNS 过滤 + 广告屏蔽 (端口 53)
- Unbound 1.21.1 — 递归 DNS 解析器 (DNSSEC)
- WireGuard Easy 14 — VPN 服务端 + Web UI (端口 51820/udp)
- Cloudflare DDNS 1.14.0 — IPv4/IPv6 动态 DNS
- 所有服务含健康检查

### 2. config/unbound/unbound.conf
- DNSSEC 验证
- QNAME 最小化 (隐私保护)
- 64MB 消息缓存 + 128MB RRset 缓存
- 预取热门域名
- 仅允许内网访问

### 3. scripts/fix-dns-port.sh
- `--check` 检测 53 端口状态
- `--apply` 禁用 systemd-resolved stub listener
- `--restore` 恢复默认配置
- 自动备份原配置

### 4. stacks/network/README.md
- 路由器 DNS 配置说明
- 推荐过滤列表 (AdGuard, OISD, Steven Black)
- WireGuard 客户端配置 + Split Tunneling
- Cloudflare API Token 获取指南
- DNS 解析链路说明

## 验收标准对照

- [x] AdGuard Home DNS 解析正常，可过滤广告
- [x] WireGuard 客户端可接入并访问内网服务
- [x] DDNS 成功更新 Cloudflare DNS 记录
- [x] fix-dns-port.sh 正确处理 systemd-resolved 冲突
- [x] README 包含路由器 DNS 配置说明
