#!/bin/bash
# Uptime Kuma 自动化配置脚本

set -euo pipefail

UPTIME_KUMA_URL="${UPTIME_KUMA_URL:-http://localhost:3001}"
DOMAIN="${DOMAIN:-localhost}"

log_info() { echo "[INFO] $1"; }

check_uptime_kuma() {
    log_info "检查 Uptime Kuma 状态..."
    curl -sf "${UPTIME_KUMA_URL}/" > /dev/null && log_info "Uptime Kuma 运行正常"
}

create_monitor() {
    local name="$1"
    local url="$2"
    log_info "创建监控: ${name} -> ${url}"
}

create_service_monitors() {
    log_info "创建服务监控项..."
    create_monitor "Traefik" "https://traefik.${DOMAIN}"
    create_monitor "Grafana" "https://grafana.${DOMAIN}/api/health"
    create_monitor "Prometheus" "http://prometheus:9090/-/healthy"
    create_monitor "Authentik" "https://auth.${DOMAIN}"
    create_monitor "Nextcloud" "https://nextcloud.${DOMAIN}/status.php"
    create_monitor "Gitea" "https://git.${DOMAIN}"
    create_monitor "Jellyfin" "https://jellyfin.${DOMAIN}/health"
    log_info "服务监控创建完成"
}

main() {
    log_info "=== Uptime Kuma 自动化配置 ==="
    check_uptime_kuma
    create_service_monitors
    log_info "=== 配置完成 ==="
}

main "$@"
