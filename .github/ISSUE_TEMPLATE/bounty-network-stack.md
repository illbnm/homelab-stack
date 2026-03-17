---
name: 💰 Bounty - Network Stack
about: 实现网络服务栈 (AdGuard Home, WireGuard, Cloudflare DDNS, Nginx Proxy Manager)
title: '[BOUNTY $120] Network Stack — 网络服务'
labels: bounty, medium
assignees: ''
---

## 赏金金额

**$120 USDT**

## 任务描述

实现家庭网络基础设施，覆盖 DNS 过滤、VPN 接入、动态域名。

## 服务清单

| 服务 | 镜像 | 用途 |
|------|------|------|
| AdGuard Home | `adguard/adguardhome:v0.107.52` | DNS 过滤 + 广告屏蔽 |
| WireGuard Easy | `ghcr.io/wg-easy/wg-easy:14` | VPN 服务端 |
| Cloudflare DDNS | `ghcr.io/favonia/cloudflare-ddns:1.14.0` | 动态 DNS |
| Unbound | `mvance/unbound:1.21.1` | 递归 DNS 解析器 |

## 核心要求

### 1. AdGuard Home

- 监听 53/UDP 端口（需处理 systemd-resolved 冲突）
- 上游 DNS 指向 Unbound (本地递归) 或 DoH/DoT
- 提供常用过滤列表配置示例
- 脚本自动禁用 `systemd-resolved` 的 53 端口占用

### 2. WireGuard

- Web UI 管理客户端
- 自动生成客户端配置二维码
- DNS 指向内网 AdGuard Home
- 支持 split tunneling 配置说明

### 3. Cloudflare DDNS

- 支持 IPv4 + IPv6 双栈
- 支持多域名配置
- 配置示例文档

### 4. 特殊处理

```bash
# scripts/fix-dns-port.sh
# 检测并禁用 systemd-resolved 的 53 端口
# 支持 --check, --apply, --restore
```

## 验收标准

- [ ] AdGuard Home DNS 解析正常，可过滤广告
- [ ] WireGuard 客户端可接入并访问内网服务
- [ ] DDNS 成功更新 Cloudflare DNS 记录
- [ ] `fix-dns-port.sh` 正确处理 systemd-resolved 冲突
- [ ] README 包含路由器 DNS 配置说明

## 认领方式

评论 "我来认领"。
