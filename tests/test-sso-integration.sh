#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — SSO Integration Test Script
# Verifies that all services are properly integrated with Authentik OIDC
#
# Usage: ./tests/test-sso-integration.sh
# =============================================================================

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ROOT_DIR=$(dirname "$SCRIPT_DIR")

# Load environment
if [ -f "$ROOT_DIR/.env" ]; then
  set -a; source "$ROOT_DIR/.env"; set +a
fi

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'
log_info()  { echo -e "${GREEN}[INFO]${RESET} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${RESET} $*"; }
log_error() { echo -e "${RED}[ERROR]${RESET} $*" >&2; }
log_step()  { echo; echo -e "${BOLD}${CYAN}==> $*${RESET}"; }

DOMAIN="${DOMAIN:-yourdomain.com}"
AUTHENTIK_DOMAIN="${AUTHENTIK_DOMAIN:-auth.${DOMAIN}}"

PASSED=0
FAILED=0

test_oidc_endpoint() {
  local name="$1"
  local url="$2"
  
  if curl -sf -o /dev/null "$url"; then
    log_info "✅ $name: OK"
    PASSED=$((PASSED + 1))
  else
    log_error "❌ $name: FAILED"
    FAILED=$((FAILED + 1))
  fi
}

test_container_health() {
  local name="$1"
  
  if docker ps --filter "name=$name" --format "{{.Status}}" | grep -q "healthy"; then
    log_info "✅ $name: healthy"
    PASSED=$((PASSED + 1))
  else
    log_error "❌ $name: not healthy"
    FAILED=$((FAILED + 1))
  fi
}

log_step "Testing Authentik health..."

test_oidc_endpoint "Authentik Health" "https://${AUTHENTIK_DOMAIN}/-/health/ready/"
test_container_health "authentik-server"
test_container_health "authentik-worker"

log_step "Testing OIDC Provider endpoints..."

test_oidc_endpoint "Grafana OIDC" "https://${AUTHENTIK_DOMAIN}/application/o/grafana/"
test_oidc_endpoint "Gitea OIDC" "https://${AUTHENTIK_DOMAIN}/application/o/gitea/"
test_oidc_endpoint "Outline OIDC" "https://${AUTHENTIK_DOMAIN}/application/o/outline/"
test_oidc_endpoint "Portainer OIDC" "https://${AUTHENTIK_DOMAIN}/application/o/portainer/"

log_step "Testing service health..."

test_container_health "grafana"
test_container_health "gitea"
test_container_health "outline"
test_container_health "portainer"
test_container_health "nextcloud"

log_step "Testing service accessibility..."

test_oidc_endpoint "Grafana Web" "https://grafana.${DOMAIN}/"
test_oidc_endpoint "Gitea Web" "https://git.${DOMAIN}/"
test_oidc_endpoint "Outline Web" "https://docs.${DOMAIN}/"
test_oidc_endpoint "Portainer Web" "https://portainer.${DOMAIN}/"
test_oidc_endpoint "Nextcloud Web" "https://nextcloud.${DOMAIN}/"

log_step "Test results..."

echo
log_info "Tests passed: $PASSED"
if [ $FAILED -gt 0 ]; then
  log_error "Tests failed: $FAILED"
  log_error ""
  log_error "Please check the failed services and verify OIDC configuration"
  exit 1
else
  log_info "All tests passed! ✅"
fi

exit 0
