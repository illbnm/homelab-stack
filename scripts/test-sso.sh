#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — SSO Health Check Script
# Validates Authentik SSO stack and all service integrations.
#
# Usage: ./scripts/test-sso.sh
# Requires: curl, jq
# =============================================================================
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ROOT_DIR=$(dirname "$SCRIPT_DIR")

# Load .env
if [ -f "$ROOT_DIR/.env" ]; then
  set -a; source "$ROOT_DIR/.env"; set +a
fi
if [ -f "$ROOT_DIR/stacks/sso/.env" ]; then
  set -a; source "$ROOT_DIR/stacks/sso/.env"; set +a
fi

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'
PASS=0; FAIL=0; WARN=0

check_pass() { echo -e "  ${GREEN}✓${RESET} $*"; ((PASS++)); }
check_fail() { echo -e "  ${RED}✗${RESET} $*"; ((FAIL++)); }
check_warn() { echo -e "  ${YELLOW}⚠${RESET} $*"; ((WARN++)); }
section()    { echo; echo -e "${BOLD}${CYAN}$*${RESET}"; }

DOMAIN="${DOMAIN:-yourdomain.com}"
AUTHENTIK_URL="https://${AUTHENTIK_DOMAIN:-auth.${DOMAIN}}"

# ---------------------------------------------------------------------------
# 1. Authentik Health
# ---------------------------------------------------------------------------
section "1. Authentik Health"

if curl -sf "${AUTHENTIK_URL}/-/health/ready/" -o /dev/null 2>/dev/null; then
  check_pass "Authentik ready endpoint responding"
else
  check_fail "Authentik ready endpoint not responding at ${AUTHENTIK_URL}/-/health/ready/"
fi

if curl -sf "${AUTHENTIK_URL}/-/health/live/" -o /dev/null 2>/dev/null; then
  check_pass "Authentik live endpoint responding"
else
  check_warn "Authentik live endpoint not responding"
fi

if curl -sf "${AUTHENTIK_URL}/if/admin/" -o /dev/null 2>/dev/null; then
  check_pass "Authentik admin UI accessible"
else
  check_warn "Authentik admin UI not accessible (may require login)"
fi

# ---------------------------------------------------------------------------
# 2. Docker Containers
# ---------------------------------------------------------------------------
section "2. Docker Containers"

for container in authentik-server authentik-worker authentik-postgres authentik-redis; do
  status=$(docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null || echo "not_found")
  if [ "$status" = "healthy" ]; then
    check_pass "$container is healthy"
  elif [ "$status" = "not_found" ]; then
    check_fail "$container not found (is the SSO stack running?)"
  else
    check_warn "$container status: $status"
  fi
done

# ---------------------------------------------------------------------------
# 3. Network Connectivity
# ---------------------------------------------------------------------------
section "3. Network Connectivity"

# Check authentik-server is reachable from proxy network
if docker network inspect proxy --format='{{range .Containers}}{{.Name}} {{end}}' 2>/dev/null | grep -q "authentik-server"; then
  check_pass "authentik-server is on the proxy network"
else
  check_fail "authentik-server is NOT on the proxy network"
fi

# Check Traefik can reach authentik
if docker exec traefik wget -q --spider "http://authentik-server:9000/-/health/ready/" 2>/dev/null; then
  check_pass "Traefik can reach authentik-server:9000"
else
  check_warn "Traefik cannot reach authentik-server:9000 (check network)"
fi

# ---------------------------------------------------------------------------
# 4. ForwardAuth Middleware
# ---------------------------------------------------------------------------
section "4. ForwardAuth Middleware"

MIDDLEWARE_FILE="$ROOT_DIR/config/traefik/dynamic/middlewares.yml"
if [ -f "$MIDDLEWARE_FILE" ]; then
  if grep -q "authentik:" "$MIDDLEWARE_FILE"; then
    check_pass "authentik middleware defined in middlewares.yml"
  else
    check_fail "authentik middleware NOT found in middlewares.yml"
  fi

  if grep -q "forwardAuth" "$MIDDLEWARE_FILE"; then
    check_pass "forwardAuth configuration present"
  else
    check_fail "forwardAuth configuration missing"
  fi
else
  check_fail "middlewares.yml not found at $MIDDLEWARE_FILE"
fi

AUTHENTIK_FILE="$ROOT_DIR/config/traefik/dynamic/authentik.yml"
if [ -f "$AUTHENTIK_FILE" ]; then
  check_pass "authentik.yml dynamic config exists"
else
  check_warn "authentik.yml not found (using middlewares.yml instead)"
fi

# ---------------------------------------------------------------------------
# 5. OIDC Providers
# ---------------------------------------------------------------------------
section "5. OIDC Provider Configuration"

TOKEN="${AUTHENTIK_BOOTSTRAP_TOKEN:-}"
if [ -z "$TOKEN" ]; then
  check_warn "AUTHENTIK_BOOTSTRAP_TOKEN not set — skipping API provider check"
else
  providers=$(curl -sf "${AUTHENTIK_URL}/api/v3/providers/oauth2/" \
    -H "Authorization: Bearer $TOKEN" 2>/dev/null | jq -r '.results[].name' 2>/dev/null || echo "")

  if [ -n "$providers" ]; then
    while IFS= read -r name; do
      check_pass "OIDC provider exists: $name"
    done <<< "$providers"
  else
    check_warn "No OIDC providers found (run setup-authentik.sh first)"
  fi
fi

# Check .env for OAuth credentials
for var in GRAFANA_OAUTH_CLIENT_ID GITEA_OAUTH_CLIENT_ID OUTLINE_OAUTH_CLIENT_ID \
           PORTAINER_OAUTH_CLIENT_ID NEXTCLOUD_OAUTH_CLIENT_ID OPENWEBUI_OAUTH_CLIENT_ID \
           BOOKSTACK_OIDC_CLIENT_ID; do
  val="${!var:-}"
  if [ -n "$val" ]; then
    check_pass "$var is set"
  else
    check_warn "$var is empty (run setup-authentik.sh to populate)"
  fi
done

# ---------------------------------------------------------------------------
# 6. Service ForwardAuth Labels
# ---------------------------------------------------------------------------
section "6. ForwardAuth Labels on Services"

for stack_dir in "$ROOT_DIR"/stacks/*/; do
  compose_file="${stack_dir}docker-compose.yml"
  if [ ! -f "$compose_file" ]; then
    continue
  fi

  stack_name=$(basename "$stack_dir")
  if [ "$stack_name" = "sso" ]; then
    continue
  fi

  if grep -q "authentik@file" "$compose_file" 2>/dev/null; then
    check_pass "$stack_name: has authentik@file middleware"
  else
    check_warn "$stack_name: no authentik@file middleware found"
  fi
done

# ---------------------------------------------------------------------------
# 7. SSO Login Flow (manual)
# ---------------------------------------------------------------------------
section "7. SSO Login Flow"

echo -e "  ${CYAN}Manual verification:${RESET}"
echo "    1. Visit https://${AUTHENTIK_DOMAIN}/if/admin/"
echo "    2. Login with bootstrap admin credentials"
echo "    3. Check Applications → ensure all apps are listed"
echo "    4. Check Outposts → ensure embedded outpost is active"
echo "    5. Visit a protected service (e.g., https://grafana.${DOMAIN})"
echo "    6. Should redirect to Authentik login → after login → back to service"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${BOLD}Results: ${GREEN}${PASS} passed${RESET}, ${YELLOW}${WARN} warnings${RESET}, ${RED}${FAIL} failed${RESET}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

if [ "$FAIL" -gt 0 ]; then
  echo -e "\n${RED}Some checks failed. Review the output above.${RESET}"
  exit 1
elif [ "$WARN" -gt 0 ]; then
  echo -e "\n${YELLOW}Some warnings. SSO may work but check the items above.${RESET}"
  exit 0
else
  echo -e "\n${GREEN}All checks passed! SSO is fully operational.${RESET}"
  exit 0
fi
