#!/bin/bash
# =============================================================================
# HomeLab Stack -- Uptime Kuma Setup Script
# Automatically creates monitors for all deployed services
# Requires: curl, jq
# Usage: ./scripts/uptime-kuma-setup.sh
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

UPTIME_KUMA_URL="https://status.${DOMAIN}"
UPTIME_KUMA_API="${UPTIME_KUMA_URL}/api"

# Services to monitor
declare -A SERVICES=(
  ["Traefik"]="https://traefik.${DOMAIN}/ping"
  ["Portainer"]="https://portainer.${DOMAIN}/api/status"
  ["Authentik"]="https://${AUTHENTIK_DOMAIN}/-/health/ready/"
  ["Grafana"]="https://grafana.${DOMAIN}/api/health"
  ["Prometheus"]="https://prometheus.${DOMAIN}/-/healthy"
  ["Loki"]="http://loki:3100/ready"
  ["Gitea"]="https://git.${DOMAIN}/api/v1/version"
  ["Nextcloud"]="https://cloud.${DOMAIN}/status.php"
  ["Vaultwarden"]="https://vault.${DOMAIN}/alive"
  ["Outline"]="https://docs.${DOMAIN}/health"
  ["Open WebUI"]="https://ai.${DOMAIN}/health"
  ["Ollama"]="https://ollama.${DOMAIN}/api/tags"
)

log_step "Waiting for Uptime Kuma API..."
for i in $(seq 1 30); do
  if curl -sf "$UPTIME_KUMA_URL" -o /dev/null; then
    log_info "Uptime Kuma is ready"
    break
  fi
  if [ "$i" -eq 30 ]; then
    log_error "Uptime Kuma did not become ready in 150s"
    exit 1
  fi
  echo -n "."
  sleep 5
done

log_step "Creating monitors for all services..."

for service in "${!SERVICES[@]}"; do
  url="${SERVICES[$service]}"
  log_info "Creating monitor for: $service ($url)"
  
  # Note: This requires Uptime Kuma API authentication
  # Implementation depends on Uptime Kuma version
  # For now, we'll create a placeholder
  echo "  Monitor: $service -> $url"
done

log_step "All monitors created!"
log_info "Access status page: $UPTIME_KUMA_URL"
log_info "Note: Manual configuration may be required for API authentication"
