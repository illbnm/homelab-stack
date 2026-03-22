#!/usr/bin/env bash
# =============================================================================
# Download Grafana Community Dashboards
# Fetches official dashboard JSON from grafana.com and saves to config/grafana/dashboards/
# Usage: ./scripts/download-dashboards.sh
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DASHBOARD_DIR="$(dirname "$SCRIPT_DIR")/config/grafana/dashboards"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log()  { echo -e "${GREEN}[+]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
err()  { echo -e "${RED}[✗]${NC} $*" >&2; }

mkdir -p "$DASHBOARD_DIR"

# ---------------------------------------------------------------------------
# Dashboard definitions: "filename|grafana_dashboard_id|revision"
# ---------------------------------------------------------------------------
DASHBOARDS=(
  "node-exporter-full.json|1860|37"
  "docker-containers.json|179|45"
  "traefik.json|17346|9"
  "loki.json|13639|2"
  "uptime-kuma.json|18278|1"
)

download_dashboard() {
  local filename="$1"
  local dashboard_id="$2"
  local revision="${3:-latest}"
  local output="$DASHBOARD_DIR/$filename"
  local url="https://grafana.com/api/dashboards/${dashboard_id}/revisions/${revision}/download"

  log "Downloading dashboard ID ${dashboard_id} → ${filename}..."
  if curl -fsSL --connect-timeout 15 --max-time 60 \
      -H "Accept: application/json" \
      "$url" \
      -o "$output"; then
    # Validate it's valid JSON
    if command -v python3 >/dev/null 2>&1; then
      python3 -c "import json,sys; json.load(open('$output'))" 2>/dev/null || {
        err "  Downloaded file is not valid JSON — keeping placeholder"
        return 1
      }
    fi
    log "  Saved to ${output}"
  else
    warn "  Failed to download dashboard ${dashboard_id} — keeping placeholder"
    return 1
  fi
}

main() {
  echo "============================================================"
  echo "  Grafana Dashboard Downloader"
  echo "  Target: ${DASHBOARD_DIR}"
  echo "============================================================"
  echo ""

  local success=0 fail=0

  for entry in "${DASHBOARDS[@]}"; do
    IFS='|' read -r filename dashboard_id revision <<< "$entry"
    if download_dashboard "$filename" "$dashboard_id" "$revision"; then
      success=$((success+1))
    else
      fail=$((fail+1))
    fi
  done

  echo ""
  log "Done: ${success} downloaded, ${fail} failed (placeholders kept)"

  if [[ $success -gt 0 ]]; then
    echo ""
    log "Reload Grafana provisioning to pick up new dashboards:"
    log "  curl -X POST http://admin:password@grafana:3000/api/admin/provisioning/dashboards/reload"
  fi
}

main "$@"
