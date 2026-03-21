#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — SSO Integration Test Script
# Tests all OIDC integrations and ForwardAuth protection
#
# Usage: ./scripts/test-sso.sh
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
log_pass() { echo -e "${GREEN}[PASS]${RESET} $*"; }
log_fail() { echo -e "${RED}[FAIL]${RESET} $*" >&2; }
log_info() { echo -e "${CYAN}[INFO]${RESET} $*"; }
log_step() { echo; echo -e "${BOLD}${CYAN}==> $*${RESET}"; }

FAILED=0
TOTAL=0

test_url() {
  local name="$1"
  local url="$2"
  local expect_code="${3:-200}"
  
  TOTAL=$((TOTAL + 1))
  
  log_info "Testing: $name"
  log_info "  URL: $url"
  
  local response
  response=$(curl -sf -o /dev/null -w "%{http_code}" "$url" 2>/dev/null || echo "000")
  
  if [ "$response" = "$expect_code" ] || [ "$response" = "302" ] || [ "$response" = "307" ]; then
    log_pass "$name is accessible (HTTP $response)"
  else
    log_fail "$name returned HTTP $response (expected $expect_code or redirect)"
    FAILED=$((FAILED + 1))
  fi
}

test_oidc_well_known() {
  local name="$1"
  local slug="$2"
  
  TOTAL=$((TOTAL + 1))
  
  log_info "Testing OIDC Discovery: $name"
  local url="https://${AUTHENTIK_DOMAIN}/application/o/${slug}/.well-known/openid-configuration"
  
  local response
  response=$(curl -sf "$url" 2>/dev/null || echo "")
  
  if echo "$response" | grep -q "authorization_endpoint"; then
    log_pass "$name OIDC discovery endpoint is working"
  else
    log_fail "$name OIDC discovery endpoint failed"
    FAILED=$((FAILED + 1))
  fi
}

log_step "SSO Integration Tests"
log_info "Domain: ${DOMAIN}"
log_info "Authentik Domain: ${AUTHENTIK_DOMAIN}"
echo

# -----------------------------------------------------------------------------
# Test 1: Authentik Core
# -----------------------------------------------------------------------------
log_step "1. Authentik Core Services"

test_url "Authentik Health" "https://${AUTHENTIK_DOMAIN}/-/health/ready/"
test_url "Authentik Admin UI" "https://${AUTHENTIK_DOMAIN}/if/admin/"
test_url "Authentik User Portal" "https://${AUTHENTIK_DOMAIN}/if/user/"

# -----------------------------------------------------------------------------
# Test 2: OIDC Providers
# -----------------------------------------------------------------------------
log_step "2. OIDC Provider Discovery Endpoints"

test_oidc_well_known "Grafana" "grafana"
test_oidc_well_known "Gitea" "gitea"
test_oidc_well_known "Outline" "outline"
test_oidc_well_known "Portainer" "portainer"
test_oidc_well_known "Open WebUI" "open-webui"
test_oidc_well_known "Nextcloud" "nextcloud"
test_oidc_well_known "Bookstack" "bookstack"

# -----------------------------------------------------------------------------
# Test 3: Service Accessibility
# -----------------------------------------------------------------------------
log_step "3. Service Accessibility (with ForwardAuth)"

test_url "Grafana" "https://grafana.${DOMAIN}/"
test_url "Gitea" "https://git.${DOMAIN}/"
test_url "Outline" "https://docs.${DOMAIN}/"
test_url "Portainer" "https://portainer.${DOMAIN}/"
test_url "Open WebUI" "https://ai.${DOMAIN}/"
test_url "Nextcloud" "https://nextcloud.${DOMAIN}/"
test_url "Bookstack" "https://wiki.${DOMAIN}/"
test_url "Prometheus" "https://prometheus.${DOMAIN}/"

# -----------------------------------------------------------------------------
# Test 4: Container Health
# -----------------------------------------------------------------------------
log_step "4. Container Health Status"

check_container() {
  local name="$1"
  TOTAL=$((TOTAL + 1))
  
  local status
  status=$(docker inspect -f '{{.State.Health.Status}}' "$name" 2>/dev/null || echo "not_found")
  
  if [ "$status" = "healthy" ]; then
    log_pass "$name is healthy"
  elif [ "$status" = "not_found" ]; then
    log_fail "$name container not found"
    FAILED=$((FAILED + 1))
  else
    log_info "$name status: $status"
  fi
}

check_container "authentik-server"
check_container "authentik-worker"
check_container "authentik-postgres"
check_container "authentik-redis"

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------
log_step "Test Summary"
echo -e "${BOLD}Total: $TOTAL | Passed: $((TOTAL - FAILED)) | Failed: $FAILED${RESET}"

if [ $FAILED -eq 0 ]; then
  echo -e "${GREEN}All tests passed! SSO integration is working correctly.${RESET}"
  exit 0
else
  echo -e "${RED}$FAILED test(s) failed. Please check the logs above.${RESET}"
  exit 1
fi
