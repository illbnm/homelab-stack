#!/usr/bin/env bash
# =============================================================================
# authentik-setup.sh — 自动创建 Authentik OIDC Providers + Applications
#
# Usage:
#   ./scripts/authentik-setup.sh [--dry-run]
#
# Prerequisites:
#   - Authentik server running at AUTHENTIK_URL
#   - AUTHENTIK_TOKEN (API token from admin panel)
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/../.env"
[[ -f "$ENV_FILE" ]] && { set -a; source "$ENV_FILE"; set +a; }

AUTHENTIK_URL="${AUTHENTIK_URL:-https://auth.${DOMAIN}}"
AUTHENTIK_TOKEN="${AUTHENTIK_TOKEN:?AUTHENTIK_TOKEN required - create at ${AUTHENTIK_URL}/if/admin/#/core/tokens}"
DRY_RUN=false
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

# ── Helpers ──────────────────────────────────────────────────────────────────

api() {
  local method="$1" endpoint="$2"
  shift 2
  curl -sf -X "$method" \
    -H "Authorization: Bearer ${AUTHENTIK_TOKEN}" \
    -H "Content-Type: application/json" \
    "${AUTHENTIK_URL}/api/v3${endpoint}" \
    "$@"
}

log()  { echo "[authentik-setup] $*"; }
ok()   { echo "[authentik-setup] ✅ $*"; }
fail() { echo "[authentik-setup] ❌ $*"; }

generate_secret() {
  openssl rand -hex 32
}

# ── Service Definitions ─────────────────────────────────────────────────────

declare -A SERVICES
SERVICES=(
  ["grafana"]="Grafana|https://grafana.${DOMAIN}/login/generic_oauth"
  ["gitea"]="Gitea|https://git.${DOMAIN}/user/oauth2/authentik/callback"
  ["nextcloud"]="Nextcloud|https://cloud.${DOMAIN}/apps/user_oidc/code"
  ["outline"]="Outline|https://wiki.${DOMAIN}/auth/oidc.callback"
  ["openwebui"]="Open WebUI|https://ai.${DOMAIN}/oauth/oidc/callback"
  ["portainer"]="Portainer|https://portainer.${DOMAIN}"
)

# ── Create Provider + Application ────────────────────────────────────────────

create_oidc_provider() {
  local slug="$1"
  local name="${2%%|*}"
  local redirect_uri="${2##*|}"
  local client_id="${slug}-$(openssl rand -hex 4)"
  local client_secret="$(generate_secret)"

  log "Creating provider: ${name} (${slug})"

  if $DRY_RUN; then
    log "[DRY-RUN] Would create:"
    log "  Provider: ${name}"
    log "  Client ID: ${client_id}"
    log "  Redirect URI: ${redirect_uri}"
    echo ""
    return 0
  fi

  # Create OAuth2 Provider
  local provider_id
  provider_id=$(api POST "/providers/oauth2/" -d "{
    \"name\": \"${name}\",
    \"authorization_flow\": \"default-provider-authorization-implicit-consent\",
    \"client_type\": \"confidential\",
    \"client_id\": \"${client_id}\",
    \"client_secret\": \"${client_secret}\",
    \"redirect_uris\": \"${redirect_uri}\",
    \"property_mappings\": [],
    \"signing_key\": null
  }" | python3 -c "import sys,json; print(json.load(sys.stdin)['pk'])" 2>/dev/null)

  if [[ -z "$provider_id" ]]; then
    fail "Failed to create provider: ${name}"
    return 1
  fi

  # Create Application
  api POST "/core/applications/" -d "{
    \"name\": \"${name}\",
    \"slug\": \"${slug}\",
    \"provider\": ${provider_id},
    \"meta_launch_url\": \"${redirect_uri%%/callback*}\"
  }" >/dev/null 2>&1

  ok "Created provider: ${name}"
  echo "   Client ID:     ${client_id}"
  echo "   Client Secret:  ${client_secret}"
  echo "   Redirect URI:   ${redirect_uri}"
  echo ""
}

# ── Create Groups ────────────────────────────────────────────────────────────

create_groups() {
  log "Creating user groups..."

  for group in "homelab-admins" "homelab-users" "media-users"; do
    if $DRY_RUN; then
      log "[DRY-RUN] Would create group: ${group}"
      continue
    fi
    api POST "/core/groups/" -d "{\"name\": \"${group}\"}" >/dev/null 2>&1 \
      && ok "Group: ${group}" \
      || log "Group ${group} may already exist"
  done
  echo ""
}

# ── Main ─────────────────────────────────────────────────────────────────────

echo "=============================================="
echo "[authentik-setup] Authentik OIDC Auto-Setup"
echo "=============================================="
echo "Server: ${AUTHENTIK_URL}"
$DRY_RUN && echo "Mode: DRY-RUN (no changes)"
echo ""

# Create groups
create_groups

# Create providers + applications
for slug in "${!SERVICES[@]}"; do
  create_oidc_provider "$slug" "${SERVICES[$slug]}"
done

echo "=============================================="
echo "[authentik-setup] Complete!"
echo ""
echo "Next steps:"
echo "1. Copy Client ID/Secret to each service's .env"
echo "2. Restart affected services"
echo "3. Test login at each service"
echo "=============================================="
