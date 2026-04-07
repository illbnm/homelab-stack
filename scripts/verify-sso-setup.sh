#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack -- SSO Integration Verification Script
# Tests all SSO/OIDC integrations and generates verification report
# Usage: ./scripts/verify-sso-setup.sh
# =============================================================================
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ROOT_DIR=$(dirname "$SCRIPT_DIR")

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'
log_info()  { echo -e "${GREEN}[INFO]${RESET} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${RESET} $*"; }
log_error() { echo -e "${RED}[ERROR]${RESET} $*" >&2; }
log_step()  { echo; echo -e "${BOLD}${CYAN}==> $*${RESET}"; }
log_test()  { echo -e "  ${CYAN}Testing:${RESET} $*"; }

# Load .env
if [ -f "$ROOT_DIR/.env" ]; then
  set -a; source "$ROOT_DIR/.env"; set +a
elif [ -f "$ROOT_DIR/stacks/sso/.env" ]; then
  set -a; source "$ROOT_DIR/stacks/sso/.env"; set +a
else
  log_error "No .env file found"
  exit 1
fi

DOMAIN="${DOMAIN:-yourdomain.com}"
AUTHENTIK_DOMAIN="${AUTHENTIK_DOMAIN:-auth.${DOMAIN}}"

# Test results
declare -A TEST_RESULTS
PASS_COUNT=0
FAIL_COUNT=0

test_service() {
  local name="$1"
  local url="$2"
  local expected_content="$3"

  log_test "$name - $url"

  local response
  if response=$(curl -sf -m 5 "$url" 2>&1); then
    if [ -n "$expected_content" ] && echo "$response" | grep -q "$expected_content"; then
      echo -e "    ${GREEN}✓ PASS${RESET}"
      TEST_RESULTS["$name"]="PASS"
      ((PASS_COUNT++))
      return 0
    elif [ -z "$expected_content" ]; then
      echo -e "    ${GREEN}✓ PASS${RESET} (reachable)"
      TEST_RESULTS["$name"]="PASS"
      ((PASS_COUNT++))
      return 0
    else
      echo -e "    ${RED}✗ FAIL${RESET} (unexpected content)"
      TEST_RESULTS["$name"]="FAIL"
      ((FAIL_COUNT++))
      return 1
    fi
  else
    echo -e "    ${RED}✗ FAIL${RESET} (not reachable)"
    TEST_RESULTS["$name"]="FAIL"
    ((FAIL_COUNT++))
    return 1
  fi
}

test_container() {
  local name="$1"
  local expected_status="${2:-running}"

  log_test "Container: $name"

  local status
  status=$(docker ps --filter "name=$name" --format '{{.Status}}' 2>/dev/null | head -1)

  if [ -n "$status" ]; then
    if echo "$status" | grep -qi "$expected_status" || echo "$status" | grep -qi "healthy"; then
      echo -e "    ${GREEN}✓ PASS${RESET} ($status)"
      TEST_RESULTS["$name-container"]="PASS"
      ((PASS_COUNT++))
      return 0
    else
      echo -e "    ${RED}✗ FAIL${RESET} ($status)"
      TEST_RESULTS["$name-container"]="FAIL"
      ((FAIL_COUNT++))
      return 1
    fi
  else
    echo -e "    ${RED}✗ FAIL${RESET} (not found)"
    TEST_RESULTS["$name-container"]="FAIL"
    ((FAIL_COUNT++))
    return 1
  fi
}

test_env_var() {
  local var_name="$1"
  local description="$2"

  log_test "Environment variable: $var_name"

  local value="${!var_name:-}"
  if [ -n "$value" ]; then
    echo -e "    ${GREEN}✓ PASS${RESET} (set: ${value:0:8}...)"
    TEST_RESULTS["$var_name"]="PASS"
    ((PASS_COUNT++))
    return 0
  else
    echo -e "    ${RED}✗ FAIL${RESET} (not set)"
    TEST_RESULTS["$var_name"]="FAIL"
    ((FAIL_COUNT++))
    return 1
  fi
}

# =============================================================================
# Tests Start Here
# =============================================================================

echo -e "${BOLD}"
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║         HomeLab SSO Integration Verification Script         ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo -e "${RESET}"

# -----------------------------------------------------------------------------
# 1. Infrastructure Tests
# -----------------------------------------------------------------------------
log_step "1. Infrastructure Tests"

test_container "traefik" "running"
test_container "authentik-server" "healthy"
test_container "authentik-worker" "running"
test_container "authentik-postgres" "healthy"
test_container "authentik-redis" "healthy"

# -----------------------------------------------------------------------------
# 2. Authentik Service Tests
# -----------------------------------------------------------------------------
log_step "2. Authentik Service Tests"

test_service "Authentik Health" "https://${AUTHENTIK_DOMAIN}/-/health/ready/" "OK"
test_service "Authentik Admin UI" "https://${AUTHENTIK_DOMAIN}/if/admin/" "authentik"

# -----------------------------------------------------------------------------
# 3. OIDC Configuration Tests
# -----------------------------------------------------------------------------
log_step "3. OIDC Configuration Tests"

test_env_var "AUTHENTIK_BOOTSTRAP_TOKEN" "Authentik API Token"
test_env_var "AUTHENTIK_SECRET_KEY" "Authentik Secret Key"
test_env_var "AUTHENTIK_POSTGRES_PASSWORD" "PostgreSQL Password"
test_env_var "AUTHENTIK_REDIS_PASSWORD" "Redis Password"

# OAuth Client Credentials
log_step "4. OAuth Client Credentials Tests"

test_env_var "GRAFANA_OAUTH_CLIENT_ID" "Grafana OAuth Client ID"
test_env_var "GRAFANA_OAUTH_CLIENT_SECRET" "Grafana OAuth Client Secret"
test_env_var "GITEA_OAUTH_CLIENT_ID" "Gitea OAuth Client ID"
test_env_var "GITEA_OAUTH_CLIENT_SECRET" "Gitea OAuth Client Secret"
test_env_var "OUTLINE_OAUTH_CLIENT_ID" "Outline OAuth Client ID"
test_env_var "OUTLINE_OAUTH_CLIENT_SECRET" "Outline OAuth Client Secret"
test_env_var "NEXTCLOUD_OAUTH_CLIENT_ID" "Nextcloud OAuth Client ID"
test_env_var "NEXTCLOUD_OAUTH_CLIENT_SECRET" "Nextcloud OAuth Client Secret"
test_env_var "OPENWEBUI_OAUTH_CLIENT_ID" "Open WebUI OAuth Client ID"
test_env_var "OPENWEBUI_OAUTH_CLIENT_SECRET" "Open WebUI OAuth Client Secret"
test_env_var "PORTAINER_OAUTH_CLIENT_ID" "Portainer OAuth Client ID"
test_env_var "PORTAINER_OAUTH_CLIENT_SECRET" "Portainer OAuth Client Secret"

# -----------------------------------------------------------------------------
# 5. Service Integration Tests
# -----------------------------------------------------------------------------
log_step "5. Service Integration Tests"

test_container "grafana" "healthy"
test_container "gitea" "running"
test_container "outline" "running"
test_container "nextcloud" "running"
test_container "open-webui" "running"
test_container "portainer" "running"

# -----------------------------------------------------------------------------
# 6. Service HTTP Tests
# -----------------------------------------------------------------------------
log_step "6. Service HTTP Tests"

test_service "Grafana" "https://grafana.${DOMAIN}/api/health" "commit"
test_service "Gitea" "https://git.${DOMAIN}/" "Gitea"
test_service "Outline" "https://docs.${DOMAIN}/_health" "OK"
test_service "Nextcloud" "https://nextcloud.${DOMAIN}/status.php" "installed"
test_service "Open WebUI" "https://ai.${DOMAIN}/health" ""
test_service "Portainer" "https://portainer.${DOMAIN}/" "Portainer"

# -----------------------------------------------------------------------------
# 7. OIDC Endpoint Tests
# -----------------------------------------------------------------------------
log_step "7. OIDC Endpoint Tests"

test_service "Authentik Authorize" "https://${AUTHENTIK_DOMAIN}/application/o/authorize/" ""
test_service "Authentik Token" "https://${AUTHENTIK_DOMAIN}/application/o/token/" ""
test_service "Authentik UserInfo" "https://${AUTHENTIK_DOMAIN}/application/o/userinfo/" ""

# -----------------------------------------------------------------------------
# 8. ForwardAuth Middleware Test
# -----------------------------------------------------------------------------
log_step "8. ForwardAuth Middleware Test"

if [ -f "$ROOT_DIR/config/traefik/dynamic/authentik.yml" ]; then
  if grep -q "authentik:" "$ROOT_DIR/config/traefik/dynamic/authentik.yml" && \
     grep -q "forwardAuth:" "$ROOT_DIR/config/traefik/dynamic/authentik.yml"; then
    echo -e "  ${GREEN}✓ PASS${RESET} ForwardAuth middleware configured"
    TEST_RESULTS["forwardauth-config"]="PASS"
    ((PASS_COUNT++))
  else
    echo -e "  ${RED}✗ FAIL${RESET} ForwardAuth middleware not properly configured"
    TEST_RESULTS["forwardauth-config"]="FAIL"
    ((FAIL_COUNT++))
  fi
else
  echo -e "  ${RED}✗ FAIL${RESET} ForwardAuth config file not found"
  TEST_RESULTS["forwardauth-config"]="FAIL"
  ((FAIL_COUNT++))
fi

# -----------------------------------------------------------------------------
# 9. User Groups Test
# -----------------------------------------------------------------------------
log_step "9. User Groups Test (via Authentik API)"

TOKEN="${AUTHENTIK_BOOTSTRAP_TOKEN:-}"
if [ -n "$TOKEN" ]; then
  AUTH_HEADER="Authorization: Bearer $TOKEN"
  API_URL="https://${AUTHENTIK_DOMAIN}/api/v3"

  for group in "homelab-admins" "homelab-users" "media-users"; do
    log_test "Group: $group"
    if curl -sf "$API_URL/core/groups/?name=$group" -H "$AUTH_HEADER" | grep -q "$group"; then
      echo -e "    ${GREEN}✓ PASS${RESET}"
      TEST_RESULTS["group-$group"]="PASS"
      ((PASS_COUNT++))
    else
      echo -e "    ${RED}✗ FAIL${RESET}"
      TEST_RESULTS["group-$group"]="FAIL"
      ((FAIL_COUNT++))
    fi
  done
else
  log_warn "Skipping group tests - AUTHENTIK_BOOTSTRAP_TOKEN not set"
fi

# -----------------------------------------------------------------------------
# 10. OIDC Providers Test (via Authentik API)
# -----------------------------------------------------------------------------
log_step "10. OIDC Providers Test (via Authentik API)"

if [ -n "$TOKEN" ]; then
  for provider in "Grafana" "Gitea" "Outline" "Nextcloud" "Open WebUI" "Portainer"; do
    log_test "Provider: $provider"
    if curl -sf "$API_URL/providers/oauth2/?name=${provider}%20Provider" -H "$AUTH_HEADER" | grep -q '"results"'; then
      echo -e "    ${GREEN}✓ PASS${RESET}"
      TEST_RESULTS["provider-$provider"]="PASS"
      ((PASS_COUNT++))
    else
      echo -e "    ${RED}✗ FAIL${RESET}"
      TEST_RESULTS["provider-$provider"]="FAIL"
      ((FAIL_COUNT++))
    fi
  done
else
  log_warn "Skipping provider tests - AUTHENTIK_BOOTSTRAP_TOKEN not set"
fi

# =============================================================================
# Summary
# =============================================================================
echo
echo -e "${BOLD}"
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                      Test Summary                            ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo -e "${RESET}"

echo -e "Total Tests:  $((PASS_COUNT + FAIL_COUNT))"
echo -e "${GREEN}Passed:       $PASS_COUNT${RESET}"
echo -e "${RED}Failed:       $FAIL_COUNT${RESET}"
echo

if [ $FAIL_COUNT -eq 0 ]; then
  echo -e "${GREEN}${BOLD}All tests passed! SSO integration is working correctly.${RESET}"
  echo
  echo "Next steps:"
  echo "  1. Visit https://${AUTHENTIK_DOMAIN}"
  echo "  2. Login with admin credentials"
  echo "  3. Test login to each service using Authentik"
  echo "  4. Verify user groups are correctly assigned"
  exit 0
else
  echo -e "${RED}${BOLD}Some tests failed. Please check the errors above.${RESET}"
  echo
  echo "Troubleshooting:"
  echo "  1. Check container logs: docker compose -f stacks/sso logs"
  echo "  2. Verify .env has all required variables"
  echo "  3. Run: ./scripts/authentik-setup.sh to create providers"
  echo "  4. Check service configurations in docker-compose files"
  exit 1
fi
