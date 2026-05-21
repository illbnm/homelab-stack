#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Runtime Health Check Verification
# Tests that all running containers are healthy
# Usage: ./scripts/test-health.sh [stack_name]
# =============================================================================
set -uo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
PASSED=0; FAILED=0; SKIPPED=0

pass() { echo -e "  ${GREEN}✓${NC} $1"; ((PASSED++)); }
fail() { echo -e "  ${RED}✗${NC} $1"; ((FAILED++)); }
skip() { echo -e "  ${YELLOW}~${NC} $1"; ((SKIPPED++)); }

TARGET_STACK="${1:-all}"

echo "============================================"
echo "  HomeLab Stack — Health Check Tests"
echo "============================================"

check_container() {
    local name=$1
    if ! docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${name}$"; then
        skip "$name (not running)"
        return
    fi

    local health
    health=$(docker inspect --format '{{.State.Health.Status}}' "$name" 2>/dev/null || echo "none")

    case "$health" in
        healthy) pass "$name: healthy" ;;
        unhealthy) fail "$name: UNHEALTHY — $(docker inspect --format '{{range .State.Health.Log}}{{.ExitCode}} {{end}}' "$name" 2>/dev/null)" ;;
        none|starting) skip "$name: $health (no healthcheck defined or starting)" ;;
    esac
}

# Base stack
if [[ "$TARGET_STACK" == "all" || "$TARGET_STACK" == "base" ]]; then
    echo ""
    echo "[Base Infrastructure]"
    check_container traefik
    check_container portainer
    check_container watchtower
fi

# Databases
if [[ "$TARGET_STACK" == "all" || "$TARGET_STACK" == "databases" ]]; then
    echo ""
    echo "[Database Layer]"
    check_container homelab-postgres
    check_container homelab-redis
    check_container homelab-mariadb
    check_container homelab-pgadmin
fi

# Notifications
if [[ "$TARGET_STACK" == "all" || "$TARGET_STACK" == "notifications" ]]; then
    echo ""
    echo "[Notifications]"
    check_container ntfy
    check_container gotify
    check_container apprise
fi

# Network
if [[ "$TARGET_STACK" == "all" || "$TARGET_STACK" == "network" ]]; then
    echo ""
    echo "[Network]"
    check_container adguardhome
    check_container wireguard
    check_container nginx-proxy-manager
fi

# SSO
if [[ "$TARGET_STACK" == "all" || "$TARGET_STACK" == "sso" ]]; then
    echo ""
    echo "[SSO]"
    check_container authentik-server
    check_container authentik-worker
fi

# Storage
if [[ "$TARGET_STACK" == "all" || "$TARGET_STACK" == "storage" ]]; then
    echo ""
    echo "[Storage]"
    check_container nextcloud
    check_container minio
    check_container filebrowser
fi

# Productivity
if [[ "$TARGET_STACK" == "all" || "$TARGET_STACK" == "productivity" ]]; then
    echo ""
    echo "[Productivity]"
    check_container gitea
    check_container vaultwarden
    check_container outline
    check_container bookstack
fi

# Media
if [[ "$TARGET_STACK" == "all" || "$TARGET_STACK" == "media" ]]; then
    echo ""
    echo "[Media]"
    check_container jellyfin
    check_container sonarr
    check_container radarr
    check_container prowlarr
    check_container qbittorrent
    check_container jellyseerr
fi

# Monitoring
if [[ "$TARGET_STACK" == "all" || "$TARGET_STACK" == "monitoring" ]]; then
    echo ""
    echo "[Observability]"
    check_container prometheus
    check_container grafana
    check_container loki
    check_container promtail
    check_container alertmanager
fi

# Home Automation
if [[ "$TARGET_STACK" == "all" || "$TARGET_STACK" == "home-automation" ]]; then
    echo ""
    echo "[Home Automation]"
    check_container homeassistant
    check_container node-red
    check_container mosquitto
    check_container zigbee2mqtt
fi

echo ""
echo "============================================"
echo "  Results: $PASSED healthy, $FAILED unhealthy, $SKIPPED not running"
echo "============================================"

if [[ $FAILED -gt 0 ]]; then
    echo ""
    echo "Unhealthy containers detected. Check logs:"
    echo "  docker compose -f stacks/<stack>/docker-compose.yml logs <service>"
    exit 1
fi
exit 0
