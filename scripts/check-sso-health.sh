#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — SSO Health Check Script
# Verifies Authentik deployment and OIDC integrations
# Usage: ./scripts/check-sso-health.sh [--verbose]
# =============================================================================
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ROOT_DIR=$(dirname "$SCRIPT_DIR")

# Parse arguments
VERBOSE=false
for arg in "$@"; do
  case $arg in
    --verbose|-v)
      VERBOSE=true
      shift
      ;;
  esac
done

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# Counters
PASS=0
FAIL=0
WARN=0

check_pass() { echo -e "${GREEN}✓${RESET} $*"; ((PASS++)); }
check_fail() { echo -e "${RED}✗${RESET} $*"; ((FAIL++)); }
check_warn() { echo -e "${YELLOW}⚠${RESET} $*"; ((WARN++)); }
check_info() { if [ "$VERBOSE" = true ]; then echo -e "${CYAN}ℹ${RESET} $*"; fi; }

# Load .env
if [ -f "$ROOT_DIR/.env" ]; then
  set -a; source "$ROOT_DIR/.env"; set +a
else
  echo -e "${RED}Error: .env file not found${RESET}"
  exit 1
fi

echo -e "${BOLD}${CYAN}=== Authentik SSO Health Check ===${RESET}"
echo

# -----------------------------------------------------------------------------
# 1. Check Docker Services
# -----------------------------------------------------------------------------
echo -e "${BOLD}[1/6] Checking Docker Services...${RESET}"

# Check if containers are running
for container in authentik-server authentik-worker authentik-postgres authentik-redis; do
  if docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
    check_pass "$container is running"
  else
    check_fail "$container is NOT running"
  fi
done

# Check container health
for container in authentik-server authentik-postgres authentik-redis; do
  health=$(docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null || echo "unknown")
  if [ "$health" = "healthy" ]; then
    check_pass "$container health: $health"
  elif [ "$health" = "unknown" ]; then
    check_warn "$container health check not defined"
  else
    check_fail "$container health: $health"
  fi
done

echo

# -----------------------------------------------------------------------------
# 2. Check Environment Variables
# -----------------------------------------------------------------------------
echo -e "${BOLD}[2/6] Checking Environment Variables...${RESET}"

# Required variables
required_vars=(
  "AUTHENTIK_SECRET_KEY"
  "AUTHENTIK_POSTGRES_PASSWORD"
  "AUTHENTIK_REDIS_PASSWORD"
  "AUTHENTIK_BOOTSTRAP_TOKEN"
  "AUTHENTIK_DOMAIN"
)

for var in "${required_vars[@]}"; do
  if [ -n "${!var:-}" ]; then
    check_pass "$var is set"
    check_info "$var = ${!var:0:10}..."
  else
    check_fail "$var is NOT set"
  fi
done

# OAuth client variables
oauth_vars=(
  "GRAFANA_OAUTH_CLIENT_ID:GRAFANA_OAUTH_CLIENT_SECRET"
  "GITEA_OAUTH_CLIENT_ID:GITEA_OAUTH_CLIENT_SECRET"
  "OUTLINE_OAUTH_CLIENT_ID:OUTLINE_OAUTH_CLIENT_SECRET"
  "OPENWEBUI_OAUTH_CLIENT_ID:OPENWEBUI_OAUTH_CLIENT_SECRET"
  "NEXTCLOUD_OAUTH_CLIENT_ID:NEXTCLOUD_OAUTH_CLIENT_SECRET"
  "PORTAINER_OAUTH_CLIENT_ID:PORTAINER_OAUTH_CLIENT_SECRET"
)

for pair in "${oauth_vars[@]}"; do
  IFS=':' read -r id_var secret_var <<< "$pair"
  if [ -n "${!id_var:-}" ] && [ -n "${!secret_var:-}" ]; then
    check_pass "${id_var%_ID} configured"
  else
    check_warn "${id_var%_ID} not configured (run authentik-setup.sh)"
  fi
done

echo

# -----------------------------------------------------------------------------
# 3. Check Network Connectivity
# -----------------------------------------------------------------------------
echo -e "${BOLD}[3/6] Checking Network Connectivity...${RESET}"

# Check if Authentik is reachable
AUTHENTIK_URL="https://${AUTHENTIK_DOMAIN:-auth.${DOMAIN}}"

if curl -sf "${AUTHENTIK_URL}/-/health/ready/" -o /dev/null 2>&1; then
  check_pass "Authentik API is reachable"
else
  check_fail "Authentik API is NOT reachable"
  check_info "URL: ${AUTHENTIK_URL}"
fi

# Check OIDC discovery endpoint
if curl -sf "${AUTHENTIK_URL}/application/o/.well-known/openid-configuration" -o /dev/null 2>&1; then
  check_pass "OIDC discovery endpoint accessible"
else
  check_fail "OIDC discovery endpoint NOT accessible"
fi

# Check from inside Docker network
if docker exec authentik-server curl -sf http://localhost:9000/-/health/ready/ -o /dev/null 2>&1; then
  check_pass "Authentik internal health check OK"
else
  check_fail "Authentik internal health check FAILED"
fi

echo

# -----------------------------------------------------------------------------
# 4. Check Database Connectivity
# -----------------------------------------------------------------------------
echo -e "${BOLD}[4/6] Checking Database Connectivity...${RESET}"

# PostgreSQL
if docker exec authentik-postgres pg_isready -U authentik -d authentik -q 2>&1; then
  check_pass "PostgreSQL is ready"

  # Check database size
  db_size=$(docker exec authentik-postgres psql -U authentik -d authentik -t -c "SELECT pg_size_pretty(pg_database_size('authentik'));" 2>&1 | tr -d ' ')
  check_info "Database size: $db_size"
else
  check_fail "PostgreSQL is NOT ready"
fi

# Redis
if docker exec authentik-redis redis-cli -a "${AUTHENTIK_REDIS_PASSWORD}" ping 2>&1 | grep -q PONG; then
  check_pass "Redis is responding"

  # Check Redis memory usage
  redis_info=$(docker exec authentik-redis redis-cli -a "${AUTHENTIK_REDIS_PASSWORD}" info memory 2>&1 | grep used_memory_human)
  check_info "Redis memory: $(echo $redis_info | cut -d: -f2 | tr -d '\r')"
else
  check_fail "Redis is NOT responding"
fi

echo

# -----------------------------------------------------------------------------
# 5. Check OIDC Providers
# -----------------------------------------------------------------------------
echo -e "${BOLD}[5/6] Checking OIDC Providers...${RESET}"

API_URL="${AUTHENTIK_URL}/api/v3"
TOKEN="${AUTHENTIK_BOOTSTRAP_TOKEN:-}"

if [ -z "$TOKEN" ]; then
  check_warn "AUTHENTIK_BOOTSTRAP_TOKEN not set, skipping API checks"
else
  AUTH_HEADER="Authorization: Bearer $TOKEN"

  # Check providers
  provider_count=$(curl -sf "${API_URL}/providers/oauth2/" -H "$AUTH_HEADER" 2>&1 | jq -r '.pagination.count' 2>/dev/null || echo "0")

  if [ "$provider_count" -gt 0 ]; then
    check_pass "$provider_count OIDC providers configured"

    # List providers
    if [ "$VERBOSE" = true ]; then
      providers=$(curl -sf "${API_URL}/providers/oauth2/" -H "$AUTH_HEADER" 2>&1 | jq -r '.results[].name' 2>/dev/null)
      check_info "Providers: $(echo $providers | tr '\n' ', ' | sed 's/,$//')"
    fi
  else
    check_warn "No OIDC providers configured (run authentik-setup.sh)"
  fi

  # Check applications
  app_count=$(curl -sf "${API_URL}/core/applications/" -H "$AUTH_HEADER" 2>&1 | jq -r '.pagination.count' 2>/dev/null || echo "0")

  if [ "$app_count" -gt 0 ]; then
    check_pass "$app_count applications configured"
  else
    check_warn "No applications configured"
  fi

  # Check user groups
  group_count=$(curl -sf "${API_URL}/core/groups/" -H "$AUTH_HEADER" 2>&1 | jq -r '.pagination.count' 2>/dev/null || echo "0")

  if [ "$group_count" -gt 0 ]; then
    check_pass "$group_count user groups configured"

    # Check for expected groups
    expected_groups=("homelab-admins" "homelab-users" "media-users")
    for group in "${expected_groups[@]}"; do
      if curl -sf "${API_URL}/core/groups/?name=${group}" -H "$AUTH_HEADER" 2>&1 | jq -e '.results[0]' > /dev/null 2>&1; then
        check_pass "Group '$group' exists"
      else
        check_warn "Group '$group' not found"
      fi
    done
  else
    check_warn "No user groups configured"
  fi
fi

echo

# -----------------------------------------------------------------------------
# 6. Check Service Integrations
# -----------------------------------------------------------------------------
echo -e "${BOLD}[6/6] Checking Service Integrations...${RESET}"

# Check Grafana
if docker ps --format '{{.Names}}' | grep -q "^grafana$"; then
  if [ -n "${GRAFANA_OAUTH_CLIENT_ID:-}" ]; then
    check_pass "Grafana OIDC configured"
  else
    check_warn "Grafana OIDC NOT configured"
  fi
else
  check_info "Grafana not deployed"
fi

# Check Gitea
if docker ps --format '{{.Names}}' | grep -q "^gitea$"; then
  if [ -n "${GITEA_OAUTH_CLIENT_ID:-}" ]; then
    check_pass "Gitea OIDC configured"
  else
    check_warn "Gitea OIDC NOT configured"
  fi
else
  check_info "Gitea not deployed"
fi

# Check Outline
if docker ps --format '{{.Names}}' | grep -q "^outline$"; then
  if [ -n "${OUTLINE_OAUTH_CLIENT_ID:-}" ]; then
    check_pass "Outline OIDC configured"
  else
    check_warn "Outline OIDC NOT configured"
  fi
else
  check_info "Outline not deployed"
fi

# Check Open WebUI
if docker ps --format '{{.Names}}' | grep -q "^open-webui$"; then
  if [ -n "${OPENWEBUI_OAUTH_CLIENT_ID:-}" ]; then
    check_pass "Open WebUI OIDC configured"
  else
    check_warn "Open WebUI OIDC NOT configured"
  fi
else
  check_info "Open WebUI not deployed"
fi

# Check Nextcloud
if docker ps --format '{{.Names}}' | grep -q "^nextcloud$"; then
  if [ -n "${NEXTCLOUD_OAUTH_CLIENT_ID:-}" ]; then
    check_pass "Nextcloud OIDC configured"
  else
    check_warn "Nextcloud OIDC NOT configured"
  fi
else
  check_info "Nextcloud not deployed"
fi

# Check Portainer
if docker ps --format '{{.Names}}' | grep -q "^portainer$"; then
  if [ -n "${PORTAINER_OAUTH_CLIENT_ID:-}" ]; then
    check_pass "Portainer OIDC configured (Business Edition)"
  else
    check_info "Portainer using ForwardAuth (CE Edition)"
  fi
else
  check_info "Portainer not deployed"
fi

# Check Traefik ForwardAuth middleware
if [ -f "$ROOT_DIR/config/traefik/dynamic/authentik.yml" ]; then
  check_pass "Traefik ForwardAuth middleware configured"
else
  check_warn "Traefik ForwardAuth middleware NOT configured"
fi

echo

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------
echo -e "${BOLD}=== Summary ===${RESET}"
echo -e "Passed: ${GREEN}$PASS${RESET}"
echo -e "Failed: ${RED}$FAIL${RESET}"
echo -e "Warnings: ${YELLOW}$WARN${RESET}"
echo

if [ "$FAIL" -gt 0 ]; then
  echo -e "${RED}✗ SSO stack has critical issues${RESET}"
  exit 1
elif [ "$WARN" -gt 0 ]; then
  echo -e "${YELLOW}⚠ SSO stack is operational but has warnings${RESET}"
  exit 0
else
  echo -e "${GREEN}✓ SSO stack is healthy${RESET}"
  exit 0
fi
