#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Uptime Kuma Setup Script
# Automatically creates monitoring items for all deployed services
#
# Prerequisites:
#   - Uptime Kuma container running
#   - UPTIME_KUMA_URL and UPTIME_KUMA_TOKEN set in .env
#
# Usage: ./scripts/uptime-kuma-setup.sh [--dry-run]
# =============================================================================

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ROOT_DIR=$(dirname "$SCRIPT_DIR")

# Load environment
if [ -f "$ROOT_DIR/.env" ]; then
  set -a; source "$ROOT_DIR/.env"; set +a
fi

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'
log_info()  { echo -e "${GREEN}[INFO]${RESET} $*"; }
log_error() { echo -e "${RED}[ERROR]${RESET} $*" >&2; }
log_step()  { echo; echo -e "${BOLD}${CYAN}==> $*${RESET}"; }

DRY_RUN="${1:-}"
DOMAIN="${DOMAIN:-yourdomain.com}"
UPTIME_KUMA_URL="${UPTIME_KUMA_URL:-http://uptime-kuma:3001}"

# Service list to monitor
SERVICES=(
  "traefik:Traefik Dashboard:https://traefik.${DOMAIN}"
  "grafana:Grafana Monitoring:https://grafana.${DOMAIN}/api/health"
  "prometheus:Prometheus:https://prometheus.${DOMAIN}/-/healthy"
  "alertmanager:Alertmanager:https://alertmanager.${DOMAIN}/-/healthy"
  "loki:Loki Logs:https://loki.${DOMAIN}/ready"
  "portainer:Portainer:https://portainer.${DOMAIN}/api/status"
  "gitea:Gitea:https://git.${DOMAIN}/api/v1/version"
  "outline:Outline:https://docs.${DOMAIN}/_health"
  "nextcloud:Nextcloud:https://nextcloud.${DOMAIN}/status.php"
  "vaultwarden:Vaultwarden:https://vault.${DOMAIN}/alive"
  "uptime-kuma:Uptime Kuma:https://status.${DOMAIN}/"
  "authentik:Authentik SSO:https://auth.${DOMAIN}/-/health/ready/"
  "ollama:Ollama AI:https://ollama.${DOMAIN}/api/tags"
  "open-webui:Open WebUI:https://ai.${DOMAIN}/health"
  "minio:MinIO S3:https://minio.${DOMAIN}/minio/health/live"
  "filebrowser:File Browser:https://files.${DOMAIN}/"
)

# Create status page
log_step "Creating public status page..."

STATUS_PAGE_NAME="${STATUS_PAGE_NAME:-HomeLab Status}"
STATUS_PAGE_SLUG="${STATUS_PAGE_SLUG:-status}"

if [ "$DRY_RUN" != "true" ]; then
  # Create status page via Uptime Kuma API
  curl -sf -X POST "${UPTIME_KUMA_URL}/api/status-page" \
    -H "Content-Type: application/json" \
    -d "{
      \"name\": \"${STATUS_PAGE_NAME}\",
      \"slug\": \"${STATUS_PAGE_SLUG}\",
      \"public\": true,
      \"description\": \"HomeLab services status monitoring\"
    }" > /dev/null || log_error "Failed to create status page"
  
  log_info "✓ Status page created: https://status.${DOMAIN}"
else
  log_info "[DRY-RUN] Would create status page: ${STATUS_PAGE_NAME}"
fi

# Create monitoring items
log_step "Creating monitoring items..."

for service in "${SERVICES[@]}"; do
  IFS=':' read -r name display_name url <<< "$service"
  
  log_info "Creating monitor: ${display_name} (${url})"
  
  if [ "$DRY_RUN" != "true" ]; then
    curl -sf -X POST "${UPTIME_KUMA_URL}/api/monitor" \
      -H "Content-Type: application/json" \
      -d "{
        \"name\": \"${display_name}\",
        \"type\": \"http\",
        \"url\": \"${url}\",
        \"interval\": 60,
        \"max_retries\": 3,
        \"accepted_statuscodes\": [200, 301, 302],
        \"notificationIDList\": {}
      }" > /dev/null || log_error "Failed to create monitor: ${name}"
    
    log_info "  ✓ Monitor created: ${display_name}"
  else
    log_info "  [DRY-RUN] Would create monitor: ${display_name}"
  fi
done

log_step "Setup complete!"
log_info ""
log_info "Public status page: https://status.${DOMAIN}"
log_info "Uptime Kuma dashboard: https://status.${DOMAIN}/dashboard"
log_info ""
log_info "Next steps:"
log_info "  1. Configure ntfy notifications in Uptime Kuma settings"
log_info "  2. Add status page to Authentik forward auth (optional)"
log_info "  3. Configure custom domain (optional)"

exit 0
