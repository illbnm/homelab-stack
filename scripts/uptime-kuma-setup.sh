#!/bin/bash
# Uptime Kuma 自动化配置脚本

set -euo pipefail

UPTIME_KUMA_URL="${UPTIME_KUMA_URL:-http://localhost:3001}"
DOMAIN="${DOMAIN:-localhost}"

log_info() { echo "[INFO] $1"; }
log_error() { echo "[ERROR] $1"; }

check_uptime_kuma() {
    log_info "检查 Uptime Kuma 状态..."
    if curl -sf "${UPTIME_KUMA_URL}/" > /dev/null; then
        log_info "Uptime Kuma 运行正常"
        return 0
    else
        log_error "Uptime Kuma 未运行"
        return 1
    fi
}

create_monitor() {
    local name="$1"
    local url="$2"
    local type="${3:-http}"
    log_info "创建监控: ${name} -> ${url}"
    curl -sf -X POST "${UPTIME_KUMA_URL}/api/status-page/monitor" \
        -H "Content-Type: application/json" \
        -d "{\"name\": \"${name}\", \"type\": \"${type}\", \"url\": \"${url}\", \"interval\": 60}" || true
}

create_service_monitors() {
    log_info "创建服务监控项..."
    create_monitor "Traefik" "https://traefik.${DOMAIN}" "http"
    create_monitor "Authentik" "https://auth.${DOMAIN}" "http"
    create_monitor "Prometheus" "http://prometheus:9090/-/healthy" "http"
    create_monitor "Grafana" "https://grafana.${DOMAIN}/api/health" "http"
    create_monitor "Nextcloud" "https://nextcloud.${DOMAIN}/status.php" "http"
    create_monitor "Gitea" "https://git.${DOMAIN}" "http"
    create_monitor "Jellyfin" "https://jellyfin.${DOMAIN}/health" "http"
    log_info "服务监控创建完成"
}

create_status_page() {
    log_info "创建状态页..."
    curl -sf -X POST "${UPTIME_KUMA_URL}/api/status-page" \
        -H "Content-Type: application/json" \
        -d '{"title": "HomeLab Status", "published": true}' || true
    log_info "状态页创建完成"
}

main() {
    log_info "=== Uptime Kuma 自动化配置 ==="
    check_uptime_kuma || exit 1
    create_service_monitors
    create_status_page
    log_info "=== 配置完成 ==="
}

main "$@"
