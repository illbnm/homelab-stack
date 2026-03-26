# WireGuard Easy 配置说明
# 路径：config/wg-easy/
# 
# WireGuard Easy (wg-easy) 的配置文件主要是通过环境变量在 docker-compose.yml 中设置。
# 客户端配置（wg0.conf）会在容器启动后自动生成在 /etc/wireguard/ 目录下。
#
# ============================================================
# Split Tunneling 配置说明
# ============================================================
# 
# 默认情况下，WireGuard 客户端会将所有流量通过 VPN 隧道转发（full tunnel）。
# 如果需要只让特定流量走 VPN（split tunneling），可以通过以下方式配置：
#
# 方法 1：环境变量配置（推荐）
# ------------------------------------------
# 在 docker-compose.yml 中设置 WG_ALLOWED 环境变量：
#   environment:
#     - WG_ALLOWED=10.0.0.0/8,172.16.0.0/12,192.168.0.0/16
# 这表示只有目标地址在这些网段的流量才走 VPN 隧道，其他流量走本地网络。
#
# 方法 2：手动修改 wg0.conf
# ------------------------------------------
# 在 /etc/wireguard/wg0.conf 中添加：
#   [Peer]
#   AllowedIPs = 10.0.0.0/8,172.16.0.0/12,192.168.0.0/16
#
# 方法 3：通过 Web UI 配置
# ------------------------------------------
# 访问 http://wg.${DOMAIN}:51821，进入客户端配置页面，
# 为每个客户端设置特定的 AllowedIPs。
#
# ============================================================
# 推荐的内网 DNS 配置
# ============================================================
#
# WireGuard Easy 默认使用 WG_DEFAULT_DNS 环境变量设置客户端 DNS。
# 配置示例（指向内网 AdGuard Home）：
#   WG_DEFAULT_DNS=10.0.0.2   # AdGuard Home 的容器 IP
#
# 如果 AdGuard Home 需要通过域名访问，可以在 Unbound 中添加本地解析记录。
#
# ============================================================
# 常用配置参数说明
# ============================================================
#
# WG_HOST          - 你的公网 IP 或域名（必填）
# WG_PORT          - WireGuard UDP 端口（默认 51820）
# WG_PASSWORD      - Web UI 管理密码（必填）
# WG_DEFAULT_DNS  - 客户端默认 DNS（默认 1.1.1.1）
# WG_MTU           - MTU 值（默认 1420）
# WG_PERSISTENCE_KEEPALIVE - 保活间隔（秒）
# WG_ALLOWED       - Split tunneling 网段（逗号分隔）
#
# ============================================================
# 客户端配置示例
# ============================================================
#
# 客户端配置文件内容示例（在 Web UI 中生成或通过二维码扫描）：
#
# [Interface]
# PrivateKey = <客户端私钥>
# Address = 10.8.0.2/24
# DNS = 10.8.0.1
# MTU = 1420
#
# [Peer]
# PublicKey = <服务器公钥>
# PresharedKey = <可选的预共享密钥>
# Endpoint = your-public-ip-or-domain:51820
# AllowedIPs = 0.0.0.0/0, ::/0   # 全流量 VPN
# # 或只走内网流量：
# # AllowedIPs = 10.0.0.0/8,172.16.0.0/12,192.168.0.0/16
# PersistentKeepalive = 25
#
# ============================================================
# 生成新的服务器密钥
# ============================================================
# 如果需要重新生成 WireGuard 密钥：
#   docker compose -f stacks/network/docker-compose.yml exec wg-easy wg genkey
#   docker compose -f stacks/network/docker-compose.yml exec wg-easy wg pubkey
