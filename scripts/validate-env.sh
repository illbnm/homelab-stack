#!/usr/bin/env bash
# =============================================================================
# Environment Validator — Validate .env file before deployment
# =============================================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

log_info()  { echo -e "${GREEN}[✓]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[!]${NC} $*"; }
log_error() { echo -e "${RED}[✗]${NC} $*" >&2; }
log_step()  { echo -e "\n${BLUE}==>${NC} $*"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.."; pwd)"
ENV_FILE="$PROJECT_ROOT/.env"
ENV_EXAMPLE="$PROJECT_ROOT/.env.example"

PASS=0
FAIL=0
WARN=0

# ---------------------------------------------------------------------------
# Load environment file
# ---------------------------------------------------------------------------
load_env() {
  if [[ ! -f "$ENV_FILE" ]]; then
    log_error ".env file not found at $ENV_FILE"
    log_info "Run: cp .env.example .env && ./scripts/setup-env.sh"
    exit 1
  fi
  
  # Source the env file (safely)
  set -a
  source "$ENV_FILE" 2>/dev/null || true
  set +a
}

# ---------------------------------------------------------------------------
# Check required variables
# ---------------------------------------------------------------------------
check_required_vars() {
  log_step "Checking required variables"
  
  local required=(
    "DOMAIN"
    "ACME_EMAIL"
    "TRAEFIK_DASHBOARD_USER"
    "TRAEFIK_DASHBOARD_PASSWORD_HASH"
    "TZ"
  )
  
  for var in "${required[@]}"; do
    local value="${!var:-}"
    if [[ -z "$value" ]]; then
      log_error "$var is not set"
      ((FAIL++))
    elif [[ "$value" == "yourdomain.com" || "$value" == "you@example.com" ]]; then
      log_error "$var has placeholder value: $value"
      ((FAIL++))
    else
      log_info "$var is set"
      ((PASS++))
    fi
  done
}

# ---------------------------------------------------------------------------
# Validate variable formats
# ---------------------------------------------------------------------------
validate_formats() {
  log_step "Validating variable formats"
  
  # DOMAIN - should be a valid domain
  if [[ -n "${DOMAIN:-}" ]]; then
    if [[ "$DOMAIN" =~ ^[a-zA-Z0-9][a-zA-Z0-9-]*[a-zA-Z0-9](\.[a-zA-Z0-9][a-zA-Z0-9-]*[a-zA-Z0-9])+$ ]]; then
      log_info "DOMAIN format is valid: $DOMAIN"
      ((PASS++))
    else
      log_error "DOMAIN format is invalid: $DOMAIN"
      log_info "  Expected format: example.com or sub.example.com"
      ((FAIL++))
    fi
  fi
  
  # ACME_EMAIL - should be a valid email
  if [[ -n "${ACME_EMAIL:-}" ]]; then
    if [[ "$ACME_EMAIL" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
      log_info "ACME_EMAIL format is valid: $ACME_EMAIL"
      ((PASS++))
    else
      log_error "ACME_EMAIL format is invalid: $ACME_EMAIL"
      log_info "  Expected format: user@example.com"
      ((FAIL++))
    fi
  fi
  
  # TZ - should be a valid timezone
  if [[ -n "${TZ:-}" ]]; then
    if timedatectl list-timezones 2>/dev/null | grep -q "^${TZ}$"; then
      log_info "TZ is valid: $TZ"
      ((PASS++))
    else
      log_warn "TZ might be invalid: $TZ"
      log_info "  Check valid timezones with: timedatectl list-timezones"
      ((WARN++))
    fi
  fi
  
  # TRAEFIK_DASHBOARD_PASSWORD_HASH - should be a bcrypt hash
  if [[ -n "${TRAEFIK_DASHBOARD_PASSWORD_HASH:-}" ]]; then
    if [[ "$TRAEFIK_DASHBOARD_PASSWORD_HASH" =~ ^\$2[ayb]\$.{56}$ ]]; then
      log_info "TRAEFIK_DASHBOARD_PASSWORD_HASH looks like a valid bcrypt hash"
      ((PASS++))
    else
      log_warn "TRAEFIK_DASHBOARD_PASSWORD_HASH does not look like a bcrypt hash"
      log_info "  Generate with: htpasswd -nbB admin password | cut -d: -f2"
      ((WARN++))
    fi
  fi
}

# ---------------------------------------------------------------------------
# Check optional but recommended variables
# ---------------------------------------------------------------------------
check_optional_vars() {
  log_step "Checking optional variables"
  
  local optional=(
    "CLOUDFLARE_API_TOKEN"
    "CLOUDFLARE_EMAIL"
    "SMTP_HOST"
    "SMTP_USER"
    "ALERT_EMAIL"
    "GITEA__mailer__PASSWD"
    "NEXTCLOUD_TRUSTED_DOMAINS"
  )
  
  for var in "${optional[@]}"; do
    local value="${!var:-}"
    if [[ -n "$value" && "$value" != "" ]]; then
      log_info "$var is set"
      ((PASS++))
    else
      log_warn "$var is not set (optional)"
      ((WARN++))
    fi
  done
}

# ---------------------------------------------------------------------------
# Check for insecure defaults
# ---------------------------------------------------------------------------
check_security() {
  log_step "Checking for security issues"
  
  # Check for weak passwords
  if [[ -n "${TRAEFIK_DASHBOARD_USER:-}" && "$TRAEFIK_DASHBOARD_USER" == "admin" ]]; then
    log_warn "TRAEFIK_DASHBOARD_USER is 'admin' - consider using a less common username"
    ((WARN++))
  fi
  
  # Check if secrets are placeholder values
  local secrets=(
    "POSTGRES_PASSWORD"
    "REDIS_PASSWORD"
    "AUTHENTIK_SECRET_KEY"
    "GITEA__security__SECRET_KEY"
    "NEXTCLOUD_ADMIN_PASSWORD"
  )
  
  for secret in "${secrets[@]}"; do
    local value="${!secret:-}"
    if [[ -n "$value" ]]; then
      if [[ "$value" == "changeme" || "$value" == "password" || "$value" == "secret" ]]; then
        log_error "$secret has insecure default value"
        ((FAIL++))
      else
        log_info "$secret is set"
        ((PASS++))
      fi
    fi
  done
  
  # Check for exposed ports (optional, depends on use case)
  if grep -q "127.0.0.1" "$ENV_FILE"; then
    log_info "Some services are bound to localhost (good for security)"
    ((PASS++))
  fi
}

# ---------------------------------------------------------------------------
# Compare with .env.example for missing variables
# ---------------------------------------------------------------------------
check_completeness() {
  log_step "Checking .env completeness against .env.example"
  
  if [[ ! -f "$ENV_EXAMPLE" ]]; then
    log_warn ".env.example not found - skipping completeness check"
    return
  fi
  
  local example_vars
  example_vars=$(grep -oE '^[A-Z_]+=' "$ENV_EXAMPLE" | cut -d= -f1 | sort)
  
  local missing=()
  while IFS= read -r var; do
    if ! grep -q "^${var}=" "$ENV_FILE"; then
      missing+=("$var")
    fi
  done <<< "$example_vars"
  
  if [[ ${#missing[@]} -gt 0 ]]; then
    log_warn "Missing variables from .env.example:"
    for var in "${missing[@]}"; do
      log_warn "  - $var"
    done
    log_info "Consider adding these to your .env file"
    ((WARN++))
  else
    log_info "All variables from .env.example are present"
    ((PASS++))
  fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
  echo -e "${BLUE}=== HomeLab Stack — Environment Validator ===${NC}\n"
  
  load_env
  
  check_required_vars
  validate_formats
  check_optional_vars
  check_security
  check_completeness
  
  # Summary
  echo ""
  echo -e "${BLUE}=== Summary ===${NC}"
  echo -e "  ${GREEN}PASS: $PASS${NC}  ${YELLOW}WARN: $WARN${NC}  ${RED}FAIL: $FAIL${NC}"
  echo
  
  if [[ "$FAIL" -gt 0 ]]; then
    echo -e "${RED}Environment validation failed. Fix the above errors before deployment.${NC}"
    exit 1
  elif [[ "$WARN" -gt 0 ]]; then
    echo -e "${YELLOW}Environment validation passed with warnings. Review above.${NC}"
    exit 0
  else
    echo -e "${GREEN}Environment validation passed. Ready for deployment.${NC}"
    exit 0
  fi
}

main "$@"
