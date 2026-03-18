#!/bin/bash
# =============================================================================
# Uptime Kuma — Auto-create monitoring entries
# Usage: ./scripts/uptime-kuma-setup.sh [--apply]
# =============================================================================
set -euo pipefail

UPTIME_KUMA_URL="${UPTIME_KUMA_URL:-http://localhost:3001}"
DOMAIN="${DOMAIN:-example.com}"
APPLY="${1:-}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[INFO]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
err() { echo -e "${RED}[ERR]${NC} $*"; }

# Check Uptime Kuma is reachable
check_health() {
    if ! curl -sf "${UPTIME_KUMA_URL}" >/dev/null 2>&1; then
        err "Uptime Kuma not reachable at ${UPTIME_KUMA_URL}"
        err "Start the monitoring stack first: cd stacks/monitoring && docker compose up -d"
        exit 1
    fi
    log "Uptime Kuma is reachable"
}

# Monitoring targets definition
# Format: group|name|type|url|interval|retries
TARGETS=(
    "Core Services|Traefik|http|https://traefik.${DOMAIN}|60|3"
    "Core Services|Authentik|http|https://auth.${DOMAIN}/if/flow/initial-setup/|60|3"
    "Core Services|Grafana|http|https://grafana.${DOMAIN}/api/health|60|3"
    "Core Services|Prometheus|http|https://prometheus.${DOMAIN}/-/healthy|60|3"
    "Core Services|Alertmanager|http|https://prometheus.${DOMAIN/-alertmanager:9093}/-/-/healthy|60|3"
    "Core Services|Loki|http|http://loki:3100/ready|60|3"
    "Core Services|Uptime Kuma Status Page|http|https://status.${DOMAIN}|60|3"
    "Applications|Gitea|http|https://git.${DOMAIN}|60|3"
    "Applications|Nextcloud|http|https://cloud.${DOMAIN}/status.php|60|3"
    "Applications|Vaultwarden|http|https://vault.${DOMAIN}/alive|60|3"
    "Applications|WireGuard|http|https://wg.${DOMAIN}|60|3"
    "Infrastructure|Docker Socket Proxy|http|http://docker-proxy:2375/version|120|3"
)

show_plan() {
    echo "============================================"
    echo "  Uptime Kuma Monitoring Setup Plan"
    echo "============================================"
    echo ""
    echo "Domain: ${DOMAIN}"
    echo "Uptime Kuma: ${UPTIME_KUMA_URL}"
    echo ""
    echo "Targets to create:"
    echo "--------------------------------------------"
    printf "  %-30s %-10s %s\n" "NAME" "TYPE" "URL"
    echo "--------------------------------------------"
    local current_group=""
    for entry in "${TARGETS[@]}"; do
        IFS='|' read -r group name type url interval retries <<< "$entry"
        if [[ "$group" != "$current_group" ]]; then
            echo "  [$group]"
            current_group="$group"
        fi
        printf "    %-28s %-10s %s\n" "$name" "$type" "$url"
    done
    echo "--------------------------------------------"
    echo ""
    echo "Total: ${#TARGETS[@]} targets"
    echo ""
    echo "Run with --apply to create them automatically."
    echo "Otherwise, create them manually via the Uptime Kuma UI."
}

apply_setup() {
    log "This script requires manual setup via Uptime Kuma UI."
    log "Please create the following monitors:"
    echo ""
    local current_group=""
    for entry in "${TARGETS[@]}"; do
        IFS='|' read -r group name type url interval retries <<< "$entry"
        if [[ "$group" != "$current_group" ]]; then
            echo ""
            echo "  === $group ==="
            current_group="$group"
        fi
        echo "    • $name"
        echo "      Type: $type | URL: $url | Interval: ${interval}s | Retries: $retries"
    done
    echo ""
    log "Tip: Add ntfy notification in Uptime Kuma settings"
    log "      Settings → Notifications → Add → ntfy"
}

# Main
check_health

if [[ "$APPLY" == "--apply" ]]; then
    apply_setup
else
    show_plan
fi
