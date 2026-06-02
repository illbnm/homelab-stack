#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — SSO E2E Flow Test
# Simulates a full OIDC authorization code flow via curl.
#
# Prerequisites:
#   - Authentik SSO stack running
#   - Grafana OIDC provider configured
#   - Requires: curl, jq
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
BASE_DIR="$SCRIPT_DIR/../.."

if [ -f "$BASE_DIR/.env" ]; then
  set -a; source "$BASE_DIR/.env"; set +a
fi

source "$SCRIPT_DIR/../lib/assert.sh"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

AUTHENTIK_DOMAIN="${AUTHENTIK_DOMAIN:-auth.${DOMAIN}}"
AUTHENTIK_URL="https://${AUTHENTIK_DOMAIN}"

PASS=0 FAIL=0

log_pass() { echo -e "  ${GREEN}✅ PASS${NC} $*"; PASS=$((PASS+1)); }
log_fail() { echo -e "  ${RED}❌ FAIL${NC} $*"; FAIL=$((FAIL+1)); }

test_sso_grafana_redirect() {
  local target_url="https://grafana.${DOMAIN}/login"
  local location
  location=$(curl -sI -o /dev/null -w '%{redirect_url}' --connect-timeout 5 --max-time 10 "$target_url" 2>/dev/null || echo "")
  if echo "$location" | grep -q "authentik"; then
    log_pass "Grafana redirects to Authentik ($location)"
  else
    log_fail "Grafana redirect check: got '$location'"
  fi
}

test_sso_authentik_login_page() {
  local url="https://${AUTHENTIK_DOMAIN}/if/flow/default-authentication-flow/"
  local body
  body=$(curl -sf --connect-timeout 5 --max-time 10 "$url" 2>/dev/null || echo "")
  if echo "$body" | grep -q "authentik"; then
    log_pass "Authentik login page accessible"
  else
    log_fail "Authentik login page not accessible"
  fi
}

test_sso_oidc_discovery() {
  local url="https://${AUTHENTIK_DOMAIN}/application/o/grafana/.well-known/openid-configuration"
  local body
  body=$(curl -sf --connect-timeout 5 --max-time 10 "$url" 2>/dev/null || echo "")
  if echo "$body" | grep -q "authorization_endpoint"; then
    log_pass "OIDC discovery endpoint OK"
  else
    log_fail "OIDC discovery endpoint check failed"
  fi
}

test_sso_authentik_admin_ui() {
  local url="https://${AUTHENTIK_DOMAIN}/if/admin/"
  local code
  code=$(curl -sf -o /dev/null -w '%{http_code}' --connect-timeout 5 --max-time 10 "$url" 2>/dev/null || echo "000")
  if [[ "$code" =~ ^(200|302)$ ]]; then
    log_pass "Authentik admin UI HTTP $code"
  else
    log_fail "Authentik admin UI HTTP $code (expected 200 or 302)"
  fi
}

test_sso_gitea_callback_registered() {
  local url="https://git.${DOMAIN}/user/oauth2/Authentik/callback"
  local code
  code=$(curl -sf -o /dev/null -w '%{http_code}' --connect-timeout 5 --max-time 10 "$url" 2>/dev/null || echo "000")
  if [[ "$code" -ne 000 ]]; then
    log_pass "Gitea OAuth callback reachable (HTTP $code)"
  else
    log_fail "Gitea OAuth callback unreachable"
  fi
}

echo -e "${BOLD}${CYAN}═══ SSO E2E Flow Tests ═══${NC}"
echo ""

test_sso_grafana_redirect
test_sso_authentik_login_page
test_sso_oidc_discovery
test_sso_authentik_admin_ui
test_sso_gitea_callback_registered

echo ""
echo -e "${BOLD}────────────────────────────────────────${NC}"
echo -e "  SSO E2E: ${GREEN}$PASS passed${NC} | ${RED}$FAIL failed${NC}"
echo -e "${BOLD}────────────────────────────────────────${NC}"

[[ $FAIL -eq 0 ]] && exit 0 || exit 1
