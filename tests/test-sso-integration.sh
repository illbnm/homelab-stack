#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — SSO Integration Test Suite
# Tests Authentik SSO integration with all services
# Usage: ./tests/test-sso-integration.sh
# =============================================================================

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ROOT_DIR=$(dirname "$SCRIPT_DIR")

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Load .env
if [ -f "$ROOT_DIR/.env" ]; then
  set -a; source "$ROOT_DIR/.env"; set +a
else
  echo -e "${RED}ERROR: .env file not found${RESET}"
  echo "Please run: cp .env.example .env && nano .env"
  exit 1
fi

log_info()  { echo -e "${GREEN}[INFO]${RESET} $*"; }
log_error() { echo -e "${RED}[ERROR]${RESET} $*" >&2; }
log_skip()  { echo -e "${YELLOW}[SKIP]${RESET} $*"; }
log_test()  { echo -e "\n${BOLD}${CYAN}[TEST]${RESET} $*"; }

# Helper functions
check_container_healthy() {
  local container=$1
  local max_wait=10
  local count=0
  
  while [ $count -lt $max_wait ]; do
    if docker ps --filter "name=$container" --filter "health=healthy" | grep -q "$container"; then
      return 0
    fi
    sleep 3
    count=$((count + 1))
  done
  
  return 1
}

check_http_endpoint() {
  local url=$1
  local expected_status=${2:-200}
  
  if curl -sf -o /dev/null -w "%{http_code}" "$url" | grep -q "$expected_status"; then
    return 0
  else
    return 1
  fi
}

# =============================================================================
# Test 1: Authentik Core Services
# =============================================================================
test_authentik_core() {
  log_test "Authentik Core Services"
  
  # Test 1.1: Authentik Server healthy
  log_info "Checking Authentik Server health..."
  if check_container_healthy "authentik-server"; then
    log_info "✅ Authentik Server is healthy"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    log_error "❌ Authentik Server is not healthy"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
  
  # Test 1.2: Authentik Worker healthy
  log_info "Checking Authentik Worker health..."
  if check_container_healthy "authentik-worker"; then
    log_info "✅ Authentik Worker is healthy"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    log_error "❌ Authentik Worker is not healthy"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
  
  # Test 1.3: Authentik PostgreSQL healthy
  log_info "Checking Authentik PostgreSQL health..."
  if check_container_healthy "authentik-postgres"; then
    log_info "✅ Authentik PostgreSQL is healthy"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    log_error "❌ Authentik PostgreSQL is not healthy"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
  
  # Test 1.4: Authentik Redis healthy
  log_info "Checking Authentik Redis health..."
  if check_container_healthy "authentik-redis"; then
    log_info "✅ Authentik Redis is healthy"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    log_error "❌ Authentik Redis is not healthy"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
  
  # Test 1.5: Authentik Web UI accessible
  log_info "Checking Authentik Web UI accessibility..."
  if check_http_endpoint "https://${AUTHENTIK_DOMAIN}/-/health/ready/"; then
    log_info "✅ Authentik Web UI is accessible"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    log_error "❌ Authentik Web UI is not accessible"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
  
  # Test 1.6: Authentik Admin UI accessible
  log_info "Checking Authentik Admin UI accessibility..."
  if check_http_endpoint "https://${AUTHENTIK_DOMAIN}/if/admin/"; then
    log_info "✅ Authentik Admin UI is accessible"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    log_error "❌ Authentik Admin UI is not accessible"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

# =============================================================================
# Test 2: OIDC Provider Configuration
# =============================================================================
test_oidc_providers() {
  log_test "OIDC Provider Configuration"
  
  # Check if setup script has been run
  if [ ! -f "$ROOT_DIR/.env" ]; then
    log_skip "OIDC providers test skipped - .env not found"
    TESTS_SKIPPED=$((TESTS_SKIPPED + 1))
    return
  fi
  
  # Check required OAuth variables
  local providers=(
    "GRAFANA_OAUTH_CLIENT_ID"
    "GITEA_OAUTH_CLIENT_ID"
    "OUTLINE_OAUTH_CLIENT_ID"
    "PORTAINER_OAUTH_CLIENT_ID"
    "NEXTCLOUD_OAUTH_CLIENT_ID"
    "OPENWEBUI_OAUTH_CLIENT_ID"
    "BOOKSTACK_OIDC_CLIENT_ID"
  )
  
  for provider in "${providers[@]}"; do
    log_info "Checking $provider..."
    if grep -q "^${provider}=.\+" "$ROOT_DIR/.env" && ! grep -q "^${provider}=$" "$ROOT_DIR/.env"; then
      log_info "✅ $provider is configured"
      TESTS_PASSED=$((TESTS_PASSED + 1))
    else
      log_error "❌ $provider is not configured"
      TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
  done
}

# =============================================================================
# Test 3: Grafana SSO Integration
# =============================================================================
test_grafana_sso() {
  log_test "Grafana SSO Integration"
  
  # Test 3.1: Grafana container healthy
  log_info "Checking Grafana health..."
  if check_container_healthy "grafana"; then
    log_info "✅ Grafana is healthy"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    log_error "❌ Grafana is not healthy"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
  
  # Test 3.2: Grafana Web UI accessible
  log_info "Checking Grafana Web UI accessibility..."
  if check_http_endpoint "https://grafana.${DOMAIN}/api/health"; then
    log_info "✅ Grafana Web UI is accessible"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    log_error "❌ Grafana Web UI is not accessible"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
  
  # Test 3.3: Grafana OAuth configuration in environment
  log_info "Checking Grafana OAuth configuration..."
  if docker inspect grafana | jq -e '.[0].Config.Env | contains(["GF_AUTH_GENERIC_OAUTH_ENABLED=true"])' > /dev/null 2>&1; then
    log_info "✅ Grafana OAuth is enabled"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    log_error "❌ Grafana OAuth is not enabled"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

# =============================================================================
# Test 4: Gitea SSO Integration
# =============================================================================
test_gitea_sso() {
  log_test "Gitea SSO Integration"
  
  # Test 4.1: Gitea container healthy
  log_info "Checking Gitea health..."
  if check_container_healthy "gitea"; then
    log_info "✅ Gitea is healthy"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    log_error "❌ Gitea is not healthy"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
  
  # Test 4.2: Gitea Web UI accessible
  log_info "Checking Gitea Web UI accessibility..."
  if check_http_endpoint "https://git.${DOMAIN}/"; then
    log_info "✅ Gitea Web UI is accessible"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    log_error "❌ Gitea Web UI is not accessible"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
  
  # Test 4.3: Gitea OAuth configuration in environment
  log_info "Checking Gitea OAuth configuration..."
  if docker inspect gitea | jq -e '.[0].Config.Env | contains(["GITEA__oauth2__ENABLE=true"])' > /dev/null 2>&1; then
    log_info "✅ Gitea OAuth is enabled"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    log_error "❌ Gitea OAuth is not enabled"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

# =============================================================================
# Test 5: Outline SSO Integration
# =============================================================================
test_outline_sso() {
  log_test "Outline SSO Integration"
  
  # Test 5.1: Outline container healthy
  log_info "Checking Outline health..."
  if check_container_healthy "outline"; then
    log_info "✅ Outline is healthy"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    log_error "❌ Outline is not healthy"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
  
  # Test 5.2: Outline Web UI accessible
  log_info "Checking Outline Web UI accessibility..."
  if check_http_endpoint "https://docs.${DOMAIN}/_health"; then
    log_info "✅ Outline Web UI is accessible"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    log_error "❌ Outline Web UI is not accessible"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

# =============================================================================
# Test 6: Open WebUI SSO Integration
# =============================================================================
test_open_webui_sso() {
  log_test "Open WebUI SSO Integration"
  
  # Test 6.1: Open WebUI container healthy
  log_info "Checking Open WebUI health..."
  if check_container_healthy "open-webui"; then
    log_info "✅ Open WebUI is healthy"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    log_error "❌ Open WebUI is not healthy"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
  
  # Test 6.2: Open WebUI Web UI accessible
  log_info "Checking Open WebUI Web UI accessibility..."
  if check_http_endpoint "https://ai.${DOMAIN}/health"; then
    log_info "✅ Open WebUI Web UI is accessible"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    log_error "❌ Open WebUI Web UI is not accessible"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
  
  # Test 6.3: Open WebUI OAuth configuration in environment
  log_info "Checking Open WebUI OAuth configuration..."
  if docker inspect open-webui | jq -e '.[0].Config.Env | contains(["ENABLE_OAUTH_SIGNUP=true"])' > /dev/null 2>&1; then
    log_info "✅ Open WebUI OAuth is enabled"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    log_error "❌ Open WebUI OAuth is not enabled"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

# =============================================================================
# Test 7: ForwardAuth Middleware
# =============================================================================
test_forwardauth() {
  log_test "Traefik ForwardAuth Middleware"
  
  # Test 7.1: ForwardAuth middleware configuration exists
  log_info "Checking ForwardAuth middleware configuration..."
  if [ -f "$ROOT_DIR/config/traefik/dynamic/authentik.yml" ]; then
    log_info "✅ ForwardAuth middleware configuration exists"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    log_error "❌ ForwardAuth middleware configuration not found"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
  
  # Test 7.2: ForwardAuth middleware is properly configured
  log_info "Checking ForwardAuth middleware settings..."
  if grep -q "outpost.goauthentik.io/auth/traefik" "$ROOT_DIR/config/traefik/dynamic/authentik.yml"; then
    log_info "✅ ForwardAuth middleware is properly configured"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    log_error "❌ ForwardAuth middleware is not properly configured"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

# =============================================================================
# Test 8: User Groups Setup
# =============================================================================
test_user_groups() {
  log_test "User Groups Setup"
  
  # Test 8.1: Groups setup script exists
  log_info "Checking groups setup script..."
  if [ -f "$ROOT_DIR/scripts/setup-authentik-groups.sh" ]; then
    log_info "✅ Groups setup script exists"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    log_error "❌ Groups setup script not found"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
  
  # Test 8.2: Groups are defined in script
  log_info "Checking group definitions..."
  if grep -q "homelab-admins" "$ROOT_DIR/scripts/setup-authentik-groups.sh" && \
     grep -q "homelab-users" "$ROOT_DIR/scripts/setup-authentik-groups.sh" && \
     grep -q "media-users" "$ROOT_DIR/scripts/setup-authentik-groups.sh"; then
    log_info "✅ All required groups are defined"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    log_error "❌ Some groups are missing"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

# =============================================================================
# Main Test Runner
# =============================================================================
main() {
  echo -e "\n${BOLD}${CYAN}========================================${RESET}"
  echo -e "${BOLD}${CYAN}  HomeLab SSO Integration Test Suite${RESET}"
  echo -e "${BOLD}${CYAN}========================================${RESET}\n"
  
  log_info "Starting SSO integration tests..."
  log_info "Domain: ${DOMAIN}"
  log_info "Authentik Domain: ${AUTHENTIK_DOMAIN}"
  
  # Run all tests
  test_authentik_core
  test_oidc_providers
  test_grafana_sso
  test_gitea_sso
  test_outline_sso
  test_open_webui_sso
  test_forwardauth
  test_user_groups
  
  # Print summary
  echo -e "\n${BOLD}${CYAN}========================================${RESET}"
  echo -e "${BOLD}${CYAN}  Test Summary${RESET}"
  echo -e "${BOLD}${CYAN}========================================${RESET}\n"
  
  echo -e "${GREEN}✅ Tests Passed:${RESET}  $TESTS_PASSED"
  echo -e "${RED}❌ Tests Failed:${RESET}  $TESTS_FAILED"
  echo -e "${YELLOW}⚠️  Tests Skipped:${RESET} $TESTS_SKIPPED"
  
  local total=$((TESTS_PASSED + TESTS_FAILED + TESTS_SKIPPED))
  local pass_rate=0
  if [ $total -gt 0 ]; then
    pass_rate=$((TESTS_PASSED * 100 / total))
  fi
  
  echo -e "\n${BOLD}Pass Rate: ${pass_rate}%${RESET}\n"
  
  if [ $TESTS_FAILED -gt 0 ]; then
    echo -e "${RED}Some tests failed. Please check the output above.${RESET}\n"
    exit 1
  else
    echo -e "${GREEN}All tests passed! SSO integration is working correctly.${RESET}\n"
    exit 0
  fi
}

# Run main function
main "$@"
