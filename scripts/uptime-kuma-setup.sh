#!/bin/bash
# Uptime Kuma 自动配置脚本
# 自动创建所有服务的监控项

set -e

UPTIME_KUMA_URL="${UPTIME_KUMA_URL:-http://localhost:3001}"
API_KEY="${UPTIME_KUMA_API_KEY:-}"

if [ -z "$API_KEY" ]; then
    echo "错误：请设置 UPTIME_KUMA_API_KEY 环境变量"
    echo "可以在 Uptime Kuma 设置页面生成 API Key"
    exit 1
fi

# 服务列表 (从 docker-compose 中获取)
SERVICES=(
    "prometheus:${PROMETHEUS_URL:-http://prometheus:9090}/-/healthy"
    "grafana:${GRAFANA_URL:-http://grafana:3000}/api/health"
    "loki:${LOKI_URL:-http://loki:3100}/ready"
    "tempo:${TEMPO_URL:-http://tempo:3200}/ready"
    "alertmanager:${ALERTMANAGER_URL:-http://alertmanager:9093}/-/healthy"
    "traefik:${TRAEFIK_URL:-http://traefik:8080}/ping"
    "authentik:${AUTHENTIK_URL:-http://authentik:8000}/-/health/"
    "nextcloud:${NEXTCLOUD_URL:-http://nextcloud:8080}/status.php"
    "gitea:${GITEA_URL:-http://gitea:3000}/healthz"
)

echo "开始配置 Uptime Kuma 监控项..."

for service in "${SERVICES[@]}"; do
    NAME="${service%%:*}"
    URL="${service#*:}"
    
    echo "添加监控：$NAME -> $URL"
    
    # 使用 Uptime Kuma API 创建监控项
    curl -s -X POST "${UPTIME_KUMA_URL}/api/monitor" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer ${API_KEY}" \
        -d "{
            \"name\": \"$NAME\",
            \"type\": \"http\",
            \"url\": \"$URL\",
            \"interval\": 60,
            \"retryInterval\": 30,
            \"resendInterval\": 0,
            \"maxretries\": 3,
            \"expiration\": 0,
            \"accepted_statuscodes\": [\"200-399\"],
            \"method\": \"GET\",
            \"timeout\": 30,
            \"active\": true
        }" || echo "警告：添加 $NAME 失败"
    
    sleep 1
done

echo ""
echo "✅ Uptime Kuma 配置完成!"
echo "状态页访问地址：http://status.${DOMAIN:-your-domain.com}"
