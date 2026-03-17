#!/usr/bin/env bash
# =============================================================================
# env-validate.sh — Pre-flight env var validation before stack startup
# Usage: bash scripts/env-validate.sh [stack]
# =============================================================================
set -euo pipefail

STACK=${1:-all}
ENV_FILE=".env"
ERRORS=0

check_var() {
  local var=$1
  local desc=$2
  local required=${3:-true}
  local val="${!var:-}"

  if [[ -z "$val" ]]; then
    if [[ "$required" == "true" ]]; then
      echo "  ❌ $var — MISSING ($desc)"
      ((ERRORS++))
    else
      echo "  ⚠️  $var — not set (optional: $desc)"
    fi
  else
    # Mask secrets
    if [[ "$var" =~ (PASSWORD|SECRET|KEY|TOKEN|PASS) ]]; then
      echo "  ✅ $var = [SET]"
    else
      echo "  ✅ $var = $val"
    fi
  fi
}

echo "=============================================="
echo "  HomeLab Stack — Environment Validation"
echo "  Stack: $STACK"
echo "=============================================="
echo ""

# Load .env if exists
if [[ -f "$ENV_FILE" ]]; then
  set -a
  source "$ENV_FILE"
  set +a
  echo "Loaded: $ENV_FILE"
else
  echo "⚠️  No .env file found — using environment variables only"
fi
echo ""

# Common vars
echo "[ Common ]"
check_var "TZ"     "Timezone (e.g. Asia/Shanghai)"
check_var "DOMAIN" "Base domain (e.g. home.example.com)"
echo ""

# Stack-specific checks
case $STACK in
  base|all)
    echo "[ Base Stack ]"
    check_var "ACME_EMAIL"                     "Let's Encrypt email"
    check_var "TRAEFIK_DASHBOARD_USER"         "Traefik dashboard username"
    check_var "TRAEFIK_DASHBOARD_PASSWORD_HASH" "Traefik dashboard bcrypt hash"
    echo ""
    ;;
esac

case $STACK in
  monitoring|all)
    echo "[ Monitoring Stack ]"
    check_var "GF_ADMIN_PASSWORD" "Grafana admin password"
    check_var "GF_ADMIN_USER"     "Grafana admin user" false
    echo ""
    ;;
esac

case $STACK in
  sso|all)
    echo "[ SSO Stack ]"
    check_var "PG_PASS"              "Authentik PostgreSQL password"
    check_var "AUTHENTIK_SECRET_KEY" "Authentik secret key (openssl rand -base64 36)"
    echo ""
    ;;
esac

case $STACK in
  ai|all)
    echo "[ AI Stack ]"
    check_var "WEBUI_SECRET_KEY" "Open WebUI secret key"
    check_var "ENABLE_GPU"       "GPU acceleration (true/false)" false
    echo ""
    ;;
esac

echo "=============================================="
if [[ $ERRORS -gt 0 ]]; then
  echo "  ❌ $ERRORS error(s) found — fix before starting"
  exit 1
else
  echo "  ✅ All required vars present"
fi
