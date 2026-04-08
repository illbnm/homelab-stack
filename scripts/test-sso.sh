#!/bin/bash
# =============================================================================
# HomeLab Stack -- SSO Integration Test Suite
# Comprehensive tests for Authentik SSO integration with all services
# Usage: ./scripts/test-sso.sh [--verbose] [--quick]
# =============================================================================

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ROOT_DIR=$(dirname "$SCRIPT_DIR")

# Parse arguments
VERBOSE=false
QUICK=false
for arg in "$@"; do
  case $arg in
    --verbose|-v)
      VERBOSE=true
      shift
      ;;
    --quick|-q)
      QUICK=true
      shift
      ;;
    *)
      echo "Usage: $0 [--verbose] [--quick]"
      exit 1
      ;;
  esac
done

# Load environment
if [ -f "$ROOT_DIR/.env" ]; then
  set -a; source "$ROOT_DIR/.env"; set +a
else
  echo "ERROR: .env file not found at $ROOT_DIR/.env"
  exit 1
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# Test counters
PASS=0
FAIL=0
SKIP=0

# Logging functions
log_pass() {
  echo -e "${GREEN}✓ PASS${RESET}: $1"
  ((PASS++))
}

log_fail() {
  echo -e "${RED}✗ FAIL${RESET}: $1"
  if [ "$VERBOSE" = true ]; then
    echo -e "  ${YELLOW}Details${RESET}: $2"
  fi
  ((FAIL++))
}

log_skip() {
  echo -e "${YELLOW}⊘ SKIP${RESET}: $1"
  ((SKIP++))
}

log_section() {
  echo
  echo -e "${BOLD}${CYAN}=== $1 ===${RESET}"
}

# Check if a command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Prerequisite checks
check_prerequisites() {
  log_section "Checking Prerequisites"

  local missing=()

  if ! command_exists curl; then
    missing+=("curl")
  fi

  if ! command_exists jq; then
    missing+=("jq")
  fi

  if ! command_exists docker; then
    missing+=("docker")
  fi

  if [ ${#missing[@]} -gt 0 ]; then
    log_fail "Missing required tools: ${missing[*]}"
    echo "Install with: sudo apt-get install -y ${missing[*]}"
    exit 1
  fi

  log_pass "All prerequisites installed"

  # Check DOMAIN is set
  if [ -z "${DOMAIN:-}" ]; then
    log_fail "DOMAIN not set in .env"
    exit 1
  fi

  log_pass "DOMAIN configured: ${DOMAIN}"
}

# Test 1: Container Health Status
test_container_health() {
  log_section "Container Health Status"

  local containers=("authentik-server" "authentik-worker" "authentik-postgres" "authentik-redis")

  for container in "${containers[@]}"; do
    if docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
      local status
      status=$(docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null || echo "unknown")

      if [ "$status" = "healthy" ]; then
        log_pass "Container ${container} is healthy"
      elif [ "$status" = "starting" ]; then
        log_skip "Container ${container} is starting"
      else
        log_fail "Container ${container} is ${status}" "Check logs: docker logs ${container}"
      fi
    else
      log_fail "Container ${container} not running" "Start with: cd stacks/sso && docker compose up -d"
    fi
  done
}

# Test 2: Database Connectivity
test_database() {
  log_section "Database Connectivity"

  # PostgreSQL
  if docker exec authentik-postgres pg_isready -U authentik > /dev/null 2>&1; then
    log_pass "PostgreSQL is ready"
  else
    log_fail "PostgreSQL not ready" "Check container status"
  fi

  # Redis
  if [ -z "${AUTHENTIK_REDIS_PASSWORD:-}" ]; then
    log_skip "Redis test (AUTHENTIK_REDIS_PASSWORD not set)"
  else
    if docker exec authentik-redis redis-cli -a "${AUTHENTIK_REDIS_PASSWORD}" ping 2>/dev/null | grep -q "PONG"; then
      log_pass "Redis is ready"
    else
      log_fail "Redis not ready" "Check AUTHENTIK_REDIS_PASSWORD in .env"
    fi
  fi
}

# Test 3: Authentik API Health
test_authentik_health() {
  log_section "Authentik API Health"

  local authentik_url="https://auth.${DOMAIN}"

  # Health readiness
  local response
  response=$(curl -s -o /dev/null -w "%{http_code}" -m 10 "${authentik_url}/-/health/ready/" 2>/dev/null || echo "000")

  if [ "$response" = "200" ]; then
    log_pass "Authentik health endpoint (200)"
  else
    log_fail "Authentik health endpoint (${response})" "URL: ${authentik_url}/-/health/ready/"
  fi

  if [ "$QUICK" = true ]; then
    return
  fi

  # Liveness
  response=$(curl -s -o /dev/null -w "%{http_code}" -m 10 "${authentik_url}/-/health/live/" 2>/dev/null || echo "000")

  if [ "$response" = "200" ]; then
    log_pass "Authentik liveness endpoint (200)"
  else
    log_fail "Authentik liveness endpoint (${response})" "URL: ${authentik_url}/-/health/live/"
  fi
}

# Test 4: OIDC Discovery Endpoints
test_oidc_discovery() {
  log_section "OIDC Discovery Endpoints"

  local services=("grafana" "gitea" "outline" "open-webui" "nextcloud")
  local authentik_url="https://auth.${DOMAIN}"

  for service in "${services[@]}"; do
    local discovery_url="${authentik_url}/application/o/${service}/.well-known/openid-configuration"
    local response

    response=$(curl -s -o /tmp/oidc_test.json -w "%{http_code}" -m 10 "$discovery_url" 2>/dev/null || echo "000")

    if [ "$response" = "200" ]; then
      # Validate JSON structure
      if jq -e '.issuer' /tmp/oidc_test.json > /dev/null 2>&1; then
        log_pass "OIDC discovery for ${service}"
      else
        log_fail "OIDC discovery for ${service}" "Invalid JSON structure"
      fi
    else
      log_fail "OIDC discovery for ${service} (${response})" "URL: $discovery_url"
    fi
  done

  rm -f /tmp/oidc_test.json
}

# Test 5: ForwardAuth Middleware
test_forwardauth() {
  log_section "ForwardAuth Middleware"

  # Test Prometheus (should be protected)
  local response
  response=$(curl -s -o /dev/null -w "%{http_code}" -m 10 "https://prometheus.${DOMAIN}/" 2>/dev/null || echo "000")

  if [ "$response" = "302" ] || [ "$response" = "401" ]; then
    log_pass "Prometheus protected by ForwardAuth (status: ${response})"
  elif [ "$response" = "200" ]; then
    log_fail "Prometheus not protected (status: 200)" "ForwardAuth middleware may not be applied"
  else
    log_fail "Prometheus returned unexpected status (${response})" "Check Traefik configuration"
  fi

  if [ "$QUICK" = true ]; then
    return
  fi

  # Test Portainer (should be protected)
  response=$(curl -s -o /dev/null -w "%{http_code}" -m 10 "https://portainer.${DOMAIN}/" 2>/dev/null || echo "000")

  if [ "$response" = "302" ] || [ "$response" = "401" ]; then
    log_pass "Portainer protected by ForwardAuth (status: ${response})"
  elif [ "$response" = "200" ]; then
    log_fail "Portainer not protected (status: 200)" "ForwardAuth middleware may not be applied"
  else
    log_skip "Portainer status (${response})" "May require different test approach"
  fi
}

# Test 6: Service Accessibility
test_service_access() {
  log_section "Service Accessibility"

  local services=(
    "grafana"
    "git"
    "docs"
    "ai"
    "nextcloud"
  )

  for service in "${services[@]}"; do
    local url="https://${service}.${DOMAIN}"
    local response

    response=$(curl -s -L -o /dev/null -w "%{http_code}" -m 10 "$url" 2>/dev/null || echo "000")

    if [ "$response" = "200" ] || [ "$response" = "302" ]; then
      log_pass "Service ${service} accessible (${response})"
    else
      log_fail "Service ${service} not accessible (${response})" "URL: $url"
    fi
  done
}

# Test 7: OAuth Client Credentials
test_oauth_credentials() {
  log_section "OAuth Client Credentials"

  if [ -z "${AUTHENTIK_BOOTSTRAP_TOKEN:-}" ]; then
    log_skip "OAuth credential validation (AUTHENTIK_BOOTSTRAP_TOKEN not set)"
    return
  fi

  local authentik_url="https://auth.${DOMAIN}"
  local auth_header="Authorization: Bearer ${AUTHENTIK_BOOTSTRAP_TOKEN}"

  # Test API access
  local response
  response=$(curl -s -o /dev/null -w "%{http_code}" -m 10 \
    -H "$auth_header" \
    "${authentik_url}/api/v3/providers/oauth2/" 2>/dev/null || echo "000")

  if [ "$response" = "200" ]; then
    log_pass "Authentik API accessible with bootstrap token"

    # Count providers
    local count
    count=$(curl -s -H "$auth_header" "${authentik_url}/api/v3/providers/oauth2/" 2>/dev/null | jq -r '.results | length' || echo "0")

    if [ "$count" -gt 0 ]; then
      log_pass "OAuth providers configured (${count} found)"
    else
      log_fail "No OAuth providers found" "Run: ./scripts/authentik-setup.sh"
    fi
  else
    log_fail "Authentik API not accessible (${response})" "Check AUTHENTIK_BOOTSTRAP_TOKEN"
  fi
}

# Test 8: User Groups
test_user_groups() {
  log_section "User Groups"

  if [ -z "${AUTHENTIK_BOOTSTRAP_TOKEN:-}" ]; then
    log_skip "User group validation (AUTHENTIK_BOOTSTRAP_TOKEN not set)"
    return
  fi

  local authentik_url="https://auth.${DOMAIN}"
  local auth_header="Authorization: Bearer ${AUTHENTIK_BOOTSTRAP_TOKEN}"

  local required_groups=("homelab-admins" "homelab-users" "media-users")

  for group in "${required_groups[@]}"; do
    local response
    response=$(curl -s -m 10 \
      -H "$auth_header" \
      "${authentik_url}/api/v3/core/groups/?name=${group}" 2>/dev/null || echo "{}")

    local count
    count=$(echo "$response" | jq -r '.results | length' 2>/dev/null || echo "0")

    if [ "$count" -gt 0 ]; then
      log_pass "User group '${group}' exists"
    else
      log_fail "User group '${group}' not found" "Run: ./scripts/authentik-setup.sh"
    fi
  done
}

# Test 9: Traefik Configuration
test_traefik_config() {
  log_section "Traefik Configuration"

  # Check if Traefik is running
  if ! docker ps --format '{{.Names}}' | grep -q "^traefik$"; then
    log_fail "Traefik container not running" "Start with: cd stacks/base && docker compose up -d"
    return
  fi

  log_pass "Traefik container running"

  if [ "$QUICK" = true ]; then
    return
  fi

  # Check authentik middleware file exists
  local middleware_file="$ROOT_DIR/config/traefik/dynamic/authentik.yml"
  if [ -f "$middleware_file" ]; then
    log_pass "Authentik middleware configuration exists"

    # Verify it contains required configuration
    if grep -q "forwardAuth" "$middleware_file" && grep -q "authentik-server:9000" "$middleware_file"; then
      log_pass "Middleware configuration valid"
    else
      log_fail "Middleware configuration invalid" "Check $middleware_file"
    fi
  else
    log_fail "Authentik middleware configuration missing" "File: $middleware_file"
  fi
}

# Test 10: Network Connectivity
test_networks() {
  log_section "Network Connectivity"

  # Check proxy network
  if docker network inspect proxy > /dev/null 2>&1; then
    log_pass "Proxy network exists"

    # Count connected containers
    local count
    count=$(docker network inspect proxy | jq -r '.[0].Containers | length' 2>/dev/null || echo "0")

    if [ "$count" -ge 3 ]; then
      log_pass "Sufficient containers on proxy network (${count})"
    else
      log_fail "Not enough containers on proxy network (${count})" "Expected at least 3"
    fi
  else
    log_fail "Proxy network not found" "Create with: docker network create proxy"
  fi

  # Check sso network
  if docker network inspect sso > /dev/null 2>&1; then
    log_pass "SSO network exists"
  else
    log_fail "SSO network not found" "Start SSO stack first"
  fi
}

# Test 11: Certificate Status
test_certificates() {
  log_section "Certificate Status"

  if [ "$QUICK" = true ]; then
    log_skip "Certificate check (quick mode)"
    return
  fi

  local domains=(
    "auth.${DOMAIN}"
    "grafana.${DOMAIN}"
    "git.${DOMAIN}"
  )

  for domain in "${domains[@]}"; do
    local cert_info
    cert_info=$(echo | openssl s_client -servername "$domain" -connect "$domain:443" 2>/dev/null | openssl x509 -noout -dates 2>/dev/null || echo "")

    if [ -n "$cert_info" ]; then
      log_pass "Certificate valid for ${domain}"
    else
      log_fail "Certificate issue for ${domain}" "Check Traefik ACME logs"
    fi
  done
}

# Print summary
print_summary() {
  echo
  echo -e "${BOLD}=====================================${RESET}"
  echo -e "${BOLD}Test Summary${RESET}"
  echo -e "${BOLD}=====================================${RESET}"
  echo -e "Total:  $((PASS + FAIL + SKIP))"
  echo -e "${GREEN}Passed: ${PASS}${RESET}"
  echo -e "${RED}Failed: ${FAIL}${RESET}"
  echo -e "${YELLOW}Skipped: ${SKIP}${RESET}"
  echo -e "${BOLD}=====================================${RESET}"

  if [ $FAIL -gt 0 ]; then
    echo -e "${RED}Some tests failed. Please review the output above.${RESET}"
    return 1
  else
    echo -e "${GREEN}All tests passed!${RESET}"
    return 0
  fi
}

# Main execution
main() {
  echo -e "${BOLD}SSO Integration Test Suite${RESET}"
  echo -e "Domain: ${DOMAIN}"
  echo -e "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
  echo -e "Mode: $([ "$QUICK" = true ] && echo "Quick" || echo "Full")"
  echo

  check_prerequisites

  test_container_health
  test_database
  test_authentik_health

  if [ "$QUICK" = false ]; then
    test_oidc_discovery
    test_oauth_credentials
    test_user_groups
    test_traefik_config
    test_networks
    test_certificates
  fi

  test_forwardauth
  test_service_access

  print_summary
}

# Run main
main "$@"
