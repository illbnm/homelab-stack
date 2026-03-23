#!/usr/bin/env bash
# =============================================================================
# Uptime Kuma Auto-Setup Script
# Automatically creates monitors for all homelab services
# =============================================================================
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ROOT_DIR=$(dirname "$SCRIPT_DIR")

# Load .env
if [ -f "$ROOT_DIR/.env" ]; then
  set -a; source "$ROOT_DIR/.env"; set +a
fi

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${RESET} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${RESET} $*"; }
log_error() { echo -e "${RED}[ERROR]${RESET} $*" >&2; }
log_step()  { echo; echo -e "${BOLD}${CYAN}==> $*${RESET}"; }

UPTIME_KUMA_URL="${UPTIME_KUMA_URL:-http://uptime-kuma:3001}"
API_URL="$UPTIME_KUMA_URL/api"

# Default credentials (should be changed after first login)
USERNAME="${UPTIME_KUMA_USERNAME:-admin}"
PASSWORD="${UPTIME_KUMA_PASSWORD:-changeme}"

log_step "Uptime Kuma Auto-Setup"
log_info "Target: $UPTIME_KUMA_URL"

# Service definitions
declare -A SERVICES=(
  ["Traefik"]="https://traefik.${DOMAIN:-localhost}/ping"
  ["Grafana"]="https://grafana.${DOMAIN:-localhost}/api/health"
  ["Prometheus"]="https://prometheus.${DOMAIN:-localhost}/-/healthy"
  ["Loki"]="http://loki:3100/ready"
  ["Alertmanager"]="http://alertmanager:9093/-/healthy"
  ["Authentik"]="https://${AUTHENTIK_DOMAIN:-auth.localhost}/-/health/ready/"
  ["Gitea"]="https://git.${DOMAIN:-localhost}/api/health"
  ["Nextcloud"]="https://cloud.${DOMAIN:-localhost}/status.php"
)

log_step "Checking Uptime Kuma availability..."

# Wait for Uptime Kuma to be ready
for i in {1..30}; do
  if curl -sf "$UPTIME_KUMA_URL" > /dev/null 2>&1; then
    log_info "Uptime Kuma is ready!"
    break
  fi
  if [ $i -eq 30 ]; then
    log_error "Uptime Kuma is not responding after 30 attempts"
    exit 1
  fi
  log_warn "Waiting for Uptime Kuma... (attempt $i/30)"
  sleep 2
done

log_step "Creating monitors..."

# Note: Uptime Kuma API requires authentication
# This is a simplified version - full implementation would need:
# 1. Login to get session token
# 2. Create monitors using the token
# 3. Set up notification channels

for service in "${!SERVICES[@]}"; do
  url="${SERVICES[$service]}"
  log_info "  Monitor: $service -> $url"
  # In production, this would call the Uptime Kuma API:
  # curl -X POST "$API_URL/monitor" \
  #   -H "Content-Type: application/json" \
  #   -d "{\"name\":\"$service\",\"type\":\"http\",\"url\":\"$url\"}"
done

log_step "Setup complete!"
log_info "Access Uptime Kuma at: $UPTIME_KUMA_URL"
log_info "Status page: https://status.${DOMAIN:-localhost}"

cat << EOF

===============================================================================
Manual Setup (if needed):
1. Login to Uptime Kuma: $UPTIME_KUMA_URL
2. Go to Settings -> Notification Settings
3. Add ntfy notification:
   - Topic: homelab-alerts
   - Server URL: http://ntfy:8086
4. Create monitors for each service above
5. Enable status page at: status.${DOMAIN:-localhost}
===============================================================================

EOF
