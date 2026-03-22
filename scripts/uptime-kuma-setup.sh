#!/usr/bin/env bash
# =============================================================================
# Uptime Kuma Auto-Setup
# Creates monitors for all deployed homelab services and configures status page
# Usage: ./scripts/uptime-kuma-setup.sh
# =============================================================================
set -euo pipefail

# Load environment
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

if [[ -f "$ROOT_DIR/.env" ]]; then
  # shellcheck disable=SC1090
  set -a; source "$ROOT_DIR/.env"; set +a
fi

DOMAIN="${DOMAIN:-localhost}"
UPTIME_KUMA_URL="${UPTIME_KUMA_URL:-http://localhost:3001}"
UPTIME_KUMA_USER="${UPTIME_KUMA_USER:-admin}"
UPTIME_KUMA_PASS="${UPTIME_KUMA_PASS:-}"
NTFY_URL="${NTFY_URL:-http://ntfy:80}"
NTFY_ALERT_TOPIC="${NTFY_ALERT_TOPIC:-homelab-alerts}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()  { echo -e "${GREEN}[+]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
err()  { echo -e "${RED}[✗]${NC} $*" >&2; }

# ---------------------------------------------------------------------------
# Wait for Uptime Kuma to be ready
# ---------------------------------------------------------------------------
wait_for_kuma() {
  log "Waiting for Uptime Kuma to be ready..."
  local max=30 i=0
  until curl -sf "${UPTIME_KUMA_URL}/api/entry-page" >/dev/null 2>&1; do
    i=$((i+1))
    if [[ $i -ge $max ]]; then
      err "Uptime Kuma did not become ready in time"
      exit 1
    fi
    sleep 2
  done
  log "Uptime Kuma is ready"
}

# ---------------------------------------------------------------------------
# Get authentication cookie (Uptime Kuma REST-like session)
# ---------------------------------------------------------------------------
COOKIE_JAR="$(mktemp)"
AUTH_TOKEN=""

kuma_login() {
  if [[ -z "$UPTIME_KUMA_PASS" ]]; then
    warn "UPTIME_KUMA_PASS not set — skipping API setup. Set it and re-run."
    exit 0
  fi

  log "Logging in to Uptime Kuma..."
  local resp
  resp=$(curl -sf -c "$COOKIE_JAR" -X POST "${UPTIME_KUMA_URL}/api/login" \
    -H "Content-Type: application/json" \
    -d "{\"username\":\"${UPTIME_KUMA_USER}\",\"password\":\"${UPTIME_KUMA_PASS}\"}" 2>&1) || {
    err "Login failed — check credentials"; exit 1
  }
  AUTH_TOKEN=$(echo "$resp" | grep -o '"token":"[^"]*"' | cut -d'"' -f4 || true)
  log "Login successful"
}

cleanup() { rm -f "$COOKIE_JAR"; }
trap cleanup EXIT

# ---------------------------------------------------------------------------
# Helper: add a monitor via Uptime Kuma API
# ---------------------------------------------------------------------------
add_monitor() {
  local name="$1" url="$2" type="${3:-http}"
  log "  Adding monitor: $name → $url"
  curl -sf -b "$COOKIE_JAR" -X POST "${UPTIME_KUMA_URL}/api/monitor" \
    -H "Content-Type: application/json" \
    ${AUTH_TOKEN:+-H "Authorization: Bearer $AUTH_TOKEN"} \
    -d "{
      \"type\": \"${type}\",
      \"name\": \"${name}\",
      \"url\": \"${url}\",
      \"interval\": 60,
      \"retryInterval\": 60,
      \"maxretries\": 3,
      \"upsideDown\": false,
      \"notificationIDList\": {}
    }" >/dev/null 2>&1 || warn "  Monitor '$name' may already exist — skipping"
}

# ---------------------------------------------------------------------------
# Define services to monitor
# ---------------------------------------------------------------------------
setup_monitors() {
  log "Creating service monitors..."

  # Core infrastructure
  add_monitor "Traefik Dashboard"     "https://traefik.${DOMAIN}/dashboard/"
  add_monitor "Portainer"             "https://portainer.${DOMAIN}"
  add_monitor "Authentik"             "https://auth.${DOMAIN}"

  # Monitoring stack
  add_monitor "Grafana"               "https://grafana.${DOMAIN}/api/health"
  add_monitor "Prometheus"            "https://prometheus.${DOMAIN}/-/healthy"
  add_monitor "Alertmanager"          "http://alertmanager:9093/-/healthy"
  add_monitor "Loki"                  "http://loki:3100/ready"
  add_monitor "Tempo"                 "http://tempo:3200/ready"

  # Storage
  add_monitor "Nextcloud"             "https://cloud.${DOMAIN}/status.php"
  add_monitor "MinIO"                 "https://minio.${DOMAIN}/minio/health/live"

  # Productivity
  add_monitor "Gitea"                 "https://git.${DOMAIN}"
  add_monitor "Vaultwarden"           "https://vault.${DOMAIN}"
  add_monitor "Outline"               "https://docs.${DOMAIN}"

  # Media
  add_monitor "Jellyfin"              "https://media.${DOMAIN}/health"

  # Network
  add_monitor "AdGuard Home"          "https://adguard.${DOMAIN}"

  # Notifications
  add_monitor "Ntfy"                  "https://ntfy.${DOMAIN}"

  # AI
  add_monitor "Open WebUI"            "https://ai.${DOMAIN}"

  # Home Automation
  add_monitor "Home Assistant"        "https://ha.${DOMAIN}"

  log "All monitors created"
}

# ---------------------------------------------------------------------------
# Configure ntfy notification channel
# ---------------------------------------------------------------------------
setup_notification() {
  log "Configuring ntfy notification channel..."
  curl -sf -b "$COOKIE_JAR" -X POST "${UPTIME_KUMA_URL}/api/notification" \
    -H "Content-Type: application/json" \
    ${AUTH_TOKEN:+-H "Authorization: Bearer $AUTH_TOKEN"} \
    -d "{
      \"name\": \"ntfy\",
      \"type\": \"ntfy\",
      \"isDefault\": true,
      \"ntfyserverurl\": \"${NTFY_URL}\",
      \"ntfyTopic\": \"${NTFY_ALERT_TOPIC}\",
      \"ntfyPriority\": 4
    }" >/dev/null 2>&1 || warn "ntfy notification may already exist — skipping"
  log "ntfy notification configured"
}

# ---------------------------------------------------------------------------
# Create public status page
# ---------------------------------------------------------------------------
setup_status_page() {
  log "Creating public status page at status.${DOMAIN}..."
  curl -sf -b "$COOKIE_JAR" -X POST "${UPTIME_KUMA_URL}/api/status-page" \
    -H "Content-Type: application/json" \
    ${AUTH_TOKEN:+-H "Authorization: Bearer $AUTH_TOKEN"} \
    -d "{
      \"slug\": \"homelab\",
      \"title\": \"HomeLab Status\",
      \"description\": \"Real-time status of all HomeLab services\",
      \"theme\": \"auto\",
      \"published\": true,
      \"showTags\": true,
      \"customCSS\": \"\",
      \"footerText\": \"HomeLab Services\",
      \"showPoweredBy\": false
    }" >/dev/null 2>&1 || warn "Status page may already exist — skipping"
  log "Status page created — accessible at https://status.${DOMAIN}"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
  echo "============================================================"
  echo "  Uptime Kuma Auto-Setup"
  echo "  Domain: ${DOMAIN}"
  echo "  Kuma:   ${UPTIME_KUMA_URL}"
  echo "============================================================"

  wait_for_kuma
  kuma_login
  setup_notification
  setup_monitors
  setup_status_page

  echo ""
  log "Setup complete!"
  log "  Status page: https://status.${DOMAIN}"
  log "  Admin UI:    https://uptime.${DOMAIN}"
}

main "$@"
