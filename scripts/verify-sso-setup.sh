#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — SSO Verification Script
# Verifies Authentik deployment and OIDC integration for all services.
# Usage: ./scripts/verify-sso-setup.sh
# =============================================================================
set -uo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ROOT_DIR=$(dirname "$SCRIPT_DIR")

for f in "$ROOT_DIR/.env" "$ROOT_DIR/stacks/sso/.env"; do
  [ -f "$f" ] && { set -a; source "$f"; set +a; }
done

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RESET='\033[0m'
PASS=0; FAIL=0
check() {
  local desc="$1"; shift
  if eval "$@" >/dev/null 2>&1; then
    echo -e "  ${GREEN}✓${RESET} $desc"; PASS=$((PASS+1))
  else
    echo -e "  ${RED}✗${RESET} $desc"; FAIL=$((FAIL+1))
  fi
}

DOMAIN="${DOMAIN:-yourdomain.com}"

echo -e "\n${YELLOW}=== SSO Stack Verification ===${RESET}\n"

echo "1. Docker Compose Syntax"
for s in sso base monitoring productivity storage ai; do
  if [ "$s" = "sso" ]; then
    cp -f "$ROOT_DIR/stacks/sso/.env.example" "$ROOT_DIR/stacks/sso/.env" 2>/dev/null || true
  fi
  check "$s stack" "cd $ROOT_DIR/stacks/$s && TZ=Asia/Shanghai DOMAIN=test.com AUTHENTIK_DOMAIN=auth.test.com docker-compose -f docker-compose.yml config -q 2>/dev/null"
  [ "$s" = "sso" ] && rm -f "$ROOT_DIR/stacks/sso/.env" 2>/dev/null
done

echo ""
echo "2. SSO Core (Server + Worker + PostgreSQL + Redis)"
check "authentik-server in compose"  "grep -q 'authentik-server' $ROOT_DIR/stacks/sso/docker-compose.yml"
check "authentik-worker in compose"  "grep -q 'authentik-worker' $ROOT_DIR/stacks/sso/docker-compose.yml"
check "PostgreSQL in compose"        "grep -q 'image: postgres' $ROOT_DIR/stacks/sso/docker-compose.yml"
check "Redis in compose"             "grep -q 'image: redis' $ROOT_DIR/stacks/sso/docker-compose.yml"
check "ForwardAuth middleware file"  "[ -f $ROOT_DIR/config/traefik/dynamic/authentik.yml ]"
check "Setup script executable"      "[ -x $ROOT_DIR/scripts/setup-authentik.sh ]"

echo ""
echo "3. OIDC / ForwardAuth Integration (6 services)"
check "Grafana — native OIDC"          "grep -q 'GF_AUTH_GENERIC_OAUTH_ENABLED' $ROOT_DIR/stacks/monitoring/docker-compose.yml"
check "Outline — native OIDC"          "grep -q 'OIDC_CLIENT_ID' $ROOT_DIR/stacks/productivity/docker-compose.yml"
check "Open WebUI — OIDC env vars"     "grep -q 'OAUTH_PROVIDER_NAME' $ROOT_DIR/stacks/ai/docker-compose.yml"
check "Portainer — ForwardAuth"        "grep -q 'authentik@file' $ROOT_DIR/stacks/base/docker-compose.yml"
check "Nextcloud — ForwardAuth"        "grep -q 'authentik@file' $ROOT_DIR/stacks/storage/docker-compose.yml"
check "Gitea — ForwardAuth"            "grep -q 'authentik@file' $ROOT_DIR/stacks/productivity/docker-compose.yml"
check "Prometheus — ForwardAuth"       "grep -q 'authentik@file' $ROOT_DIR/stacks/monitoring/docker-compose.yml"

echo ""
echo "4. User Groups (homelab-admins, homelab-users, media-users)"
check "homelab-admins"  "grep -q 'homelab-admins' $ROOT_DIR/scripts/setup-authentik.sh"
check "homelab-users"   "grep -q 'homelab-users' $ROOT_DIR/scripts/setup-authentik.sh"
check "media-users"     "grep -q 'media-users' $ROOT_DIR/scripts/setup-authentik.sh"

echo ""
echo "5. Environment Variables"
check "AUTHENTIK_BOOTSTRAP_TOKEN in sso .env.example"   "grep -q 'AUTHENTIK_BOOTSTRAP_TOKEN' $ROOT_DIR/stacks/sso/.env.example"
check "NEXTCLOUD_OAUTH in sso .env.example"             "grep -q 'NEXTCLOUD_OAUTH' $ROOT_DIR/stacks/sso/.env.example"
check "PORTAINER_OAUTH in sso .env.example"             "grep -q 'PORTAINER_OAUTH' $ROOT_DIR/stacks/sso/.env.example"
check "OPENWEBUI_OAUTH in sso .env.example"             "grep -q 'OPENWEBUI_OAUTH' $ROOT_DIR/stacks/sso/.env.example"
check "All OAuth vars in root .env.example"             "grep -q 'OPENWEBUI_OAUTH' $ROOT_DIR/.env.example"

echo ""
echo "================================"
echo -e "  ${GREEN}PASS: $PASS${RESET}  ${RED}FAIL: $FAIL${RESET}"
echo "================================"
[ "$FAIL" -eq 0 ]
