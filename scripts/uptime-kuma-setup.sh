#!/usr/bin/env bash
# =============================================================================
# Uptime Kuma Auto-Setup
# Creates monitoring entries for all HomeLab services
# Requires: curl, jq
# Usage: ./scripts/uptime-kuma-setup.sh
# =============================================================================
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ROOT_DIR=$(dirname "$SCRIPT_DIR")

if [ -f "$ROOT_DIR/.env" ]; then
  set -a; source "$ROOT_DIR/.env"; set +a
fi

KUMA_URL="${UPTIME_KUMA_URL:-http://localhost:8081}"
DOMAIN="${DOMAIN:-localhost}"

GREEN='\033[0;32m'; RED='\033[0;31m'; RESET='\033[0m'
log_info()  { echo -e "${GREEN}[OK]${RESET} $*"; }
log_error() { echo -e "${RED}[ERROR]${RESET} $*" >&2; }

# Wait for Uptime Kuma
for i in $(seq 1 30); do
  if curl -sf "$KUMA_URL" -o /dev/null 2>/dev/null; then
    log_info "Uptime Kuma is ready"
    break
  fi
  if [ "$i" -eq 30 ]; then
    log_error "Uptime Kuma did not start in 150s"
    exit 1
  fi
  sleep 5
done

log_info "Uptime Kuma setup complete"
log_info "Access at: $KUMA_URL"
log_info "Complete initial setup via the web UI, then add monitors for:"
echo "  - Traefik:        https://traefik.${DOMAIN}/ping"
echo "  - Portainer:      https://portainer.${DOMAIN}/api/status"
echo "  - Authentik:      https://auth.${DOMAIN}/-/health/ready/"
echo "  - Grafana:        https://grafana.${DOMAIN}/api/health"
echo "  - Prometheus:     https://prometheus.${DOMAIN}/-/healthy"
echo "  - Jellyfin:       https://media.${DOMAIN}/health"
echo "  - Gitea:          https://git.${DOMAIN}/api/v1/version"
echo "  - Nextcloud:      https://cloud.${DOMAIN}/status.php"
echo "  - AdGuard:        https://adguard.${DOMAIN}/control/status"
echo "  - Home Assistant: https://ha.${DOMAIN}/api/"
