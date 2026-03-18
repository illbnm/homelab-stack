#!/usr/bin/env bash

# Uptime Kuma 自动监控配置脚本
# 用法: ./scripts/uptime-kuma-setup.sh

set -euo pipefail

# ═══════════════════════════════════════════════════════════════════════════
# 配置
# ═══════════════════════════════════════════════════════════════════════════
DOMAIN=${DOMAIN:-example.com}
API_URL="http://localhost:3001/api"
STATUS_PAGE_PATH="/status-page"  # 公开状态页路径

# 服务列表 (根据实际部署情况调整)
SERVICES=(
  "Traefik|https://${DOMAIN}|HTTPS 代理|5m"
  "Portainer|https://portainer.${DOMAIN}|Docker 管理|5m"
  "Grafana|https://grafana.${DOMAIN}|可视化面板|5m"
  "Prometheus|http://prometheus.internal:9090|指标服务|2m"
  "Loki|http://loki.internal:3100|日志服务|2m"
  "Tempo|http://tempo.internal:3200|链路追踪|2m"
  "Alertmanager|http://alertmanager.internal:9093|告警服务|2m"
  "Uptime Kuma|http://localhost:3001|自身健康|1m"
)

# ═══════════════════════════════════════════════════════════════════════════
# 工具函数
# ═══════════════════════════════════════════════════════════════════════════
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

error() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] ❌ ERROR: $*" >&2
  exit 1
}

wait_for_uptime_kuma() {
  log "等待 Uptime Kuma API 就绪..."
  for i in {1..30}; do
    if curl -sf "${API_URL}/status" > /dev/null 2>&1; then
      log "✅ Uptime Kuma API 已就绪"
      return 0
    fi
    sleep 2
  done
  error "Uptime Kuma API 响应超时，请检查服务是否启动"
}

get_auth_token() {
  # 注意: Uptime Kuma 默认不需要认证，但如果启用了认证，需要先登录
  # 这里假设使用默认 setup 完成后的 token（如果有）
  # 实际使用中，如果启用了认证，请先登录获取 token
  echo ""
}

# ═══════════════════════════════════════════════════════════════════════════
# 主逻辑
# ═══════════════════════════════════════════════════════════════════════════
main() {
  log "开始配置 Uptime Kuma 监控项..."

  # 等待 API 就绪
  wait_for_uptime_kuma

  # 注意: Uptime Kuma API 默认无需认证即可创建 monitor (如果启用了认证需要调整)
  # 参考: https://github.com/louislam/uptime-kuma/wiki/API

  for service in "${SERVICES[@]}"; do
    IFS='|' read -r name url description interval <<< "$service"

    log "添加监控: ${name} (${url})"

    # 检查是否已存在
    existing_id=$(curl -s "${API_URL}/monitors?name=${name}" | jq -r '.[0].id // empty' 2>/dev/null || echo "")

    if [[ -n "$existing_id" ]]; then
      log "  监控已存在 (ID: ${existing_id})，跳过"
      continue
    fi

    # 创建监控
    response=$(curl -s -X POST "${API_URL}/monitors" \
      -H "Content-Type: application/json" \
      -d "{
        \"name\": \"${name}\",
        \"url\": \"${url}\",
        \"type\": \"http\",
        \"interval\": \"${interval}\",
        \"status\": 1,
        \"maxRetries\": 3,
        \"accepted_status_codes\": \"200,301,302\",
        \"ignoreTls\": false,
        \"upsideDown\": false,
        \"forceSSL\": true,
        \"tags\": [\"homelab\"],
        \"httpBodyContains\": null,
        \"httpMethod\": \"GET\"
      }")

    monitor_id=$(echo "$response" | jq -r '.id // empty' 2>/dev/null || echo "")

    if [[ -n "$monitor_id" ]]; then
      log "  ✅ 创建成功 (ID: ${monitor_id})"

      # 设置描述 (需额外 API 调用)
      curl -s -X PATCH "${API_URL}/monitors/${monitor_id}" \
        -H "Content-Type: application/json" \
        -d "{\"description\":\"${description}\"}" > /dev/null || true
    else
      log "  ⚠️  创建失败，响应: $response"
    fi
  done

  # 创建公开状态页
  log "创建公开状态页..."
  status_page_response=$(curl -s -X POST "${API_URL}/status-pages" \
    -H "Content-Type: application/json" \
    -d "{
      \"slug\": \"homelab\",
      \"title\": \"Homelab Status\",
      \"description\": \"Homelab 服务状态监控\",
      \"theme\": \"auto\",
      \"public\": true,
      \"monitor\": true
    }")

  status_page_id=$(echo "$status_page_response" | jq -r '.id // empty' 2>/dev/null || echo "")

  if [[ -n "$status_page_id" ]]; then
    # 获取状态页 URL
    status_url=$(curl -s "${API_URL}/status-pages/${status_page_id}" | jq -r '.slug // empty')
    log "✅ 公开状态页已创建: https://${DOMAIN}/${STATUS_PAGE_PATH:-status-page}/${status_url}"
  else
    log "⚠️  状态页创建失败"
  fi

  log "✅ 配置完成！"
  log ""
  log "访问地址:"
  log "  - Uptime Kuma: https://status.${DOMAIN}"
  log "  - 状态页: https://${DOMAIN}/status-page/homelab (如果配置了)"
  log ""
  log "下一步:"
  log "  1. 检查所有监控项状态 (绿色=正常)"
  log "  2. 配置通知通道 (Settings → Notification)"
  log "  3. 集成 ntfy (如果已部署 Notifications Stack)"
}

# ═══════════════════════════════════════════════════════════════════════════
# 执行
# ═══════════════════════════════════════════════════════════════════════════
main "$@"