# Cloudflare DDNS 配置说明
# 路径：config/cloudflare-ddns/
#
# ============================================================
# Cloudflare API Token 获取步骤
# ============================================================
#
# 1. 登录 Cloudflare Dashboard (https://dash.cloudflare.com)
# 2. 进入 "My Profile" > "API Tokens"
# 3. 点击 "Create Token"
# 4. 选择 "Edit zone DNS" 模板（或自定义权限）
# 5. 设置以下权限：
#    - Zone > DNS > Edit
#    - Include > Specific zone > 选择你的域名
# 6. 点击 "Continue to Summary" > "Create Token"
# 7. 复制生成的 API Token（只显示一次，请妥善保管）
#
# ============================================================
# Zone ID 获取步骤
# ============================================================
#
# 1. 登录 Cloudflare Dashboard
# 2. 进入你的域名网站
# 3. 在 "Overview" 页面右侧找到 "Zone ID"
# 4. 复制并保存
#
# ============================================================
# 所需环境变量
# ============================================================
#
# CF_API_TOKEN      - Cloudflare API Token（必需）
# CF_ZONE_ID        - Cloudflare Zone ID（必需）
# CF_RECORD_NAME    - 主域名，如：home.yourdomain.com
# CF_RECORD_NAME_2  - 第二个域名（可选）
# CF_RECORD_NAME_3  - 第三个域名（可选）
# CF_RECORD_NAME_4  - 第四个域名（可选）
#
# ============================================================
# 多域名配置示例
# ============================================================
#
# 假设你有以下域名需要更新：
#   - home.yourdomain.com
#   - vpn.yourdomain.com
#   - media.yourdomain.com
#
# 在 .env 文件中配置：
#   CF_RECORD_NAME=home.yourdomain.com
#   CF_RECORD_NAME_2=vpn.yourdomain.com
#   CF_RECORD_NAME_3=media.yourdomain.com
#
# ============================================================
# IPv4 + IPv6 双栈配置
# ============================================================
#
# Cloudflare DDNS 镜像默认支持 IPv4。
# 要启用 IPv6 支持，需要创建 AAAA 记录：
#
# 1. 在 Cloudflare DNS 设置中，为每个域名添加 AAAA 记录
#    - Name: home
#    - IPv6 address: :: (临时值，稍后会被自动更新)
#    - Proxy status: DNS only (灰色云朵)
#    - TTL: Auto
#
# 2. 镜像会自动检测 IPv6 地址并更新 AAAA 记录
#    不需要额外的环境变量配置
#
# ============================================================
# 验证配置
# ============================================================
#
# 检查日志：
#   docker compose -f stacks/network/docker-compose.yml logs cloudflare-ddns
#
# 手动触发更新：
#   docker compose -f stacks/network/docker-compose.yml exec cloudflare-ddns \
#     /usr/local/bin/cloudflare-ddns-updater
#
# 查看最后更新状态：
#   docker exec cloudflare-ddns cat /data/last-update
#
# ============================================================
# 故障排查
# ============================================================
#
# 常见问题：
# 1. "Zone ID not found" - 检查 CF_ZONE_ID 是否正确
# 2. "API Token invalid" - 重新生成 API Token
# 3. "Record not found" - 确保 DNS 记录已存在（只需 A 记录）
# 4. IPv6 不更新 - 确认路由器/光猫已开启 IPv6 并分配前缀
