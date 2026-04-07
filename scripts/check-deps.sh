#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Dependency Checker
# Verifies all required tools and system conditions before stack launch.
# =============================================================================
set -euo pipefail

# ---------------------------------------------------------------------------
# Colors
# ---------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0

log_pass() { echo -e "  ${GREEN}[PASS]${NC} $*"; ((PASS++)); }
log_fail() { echo -e "  ${RED}[FAIL]${NC} $*"; ((FAIL++)); }
log_warn() { echo -e "  ${YELLOW}[WARN]${NC} $*"; ((WARN++)); }
log_info() { echo -e "  ${BLUE}[INFO]${NC} $*"; }

# ---------------------------------------------------------------------------
# Check: command exists
# ---------------------------------------------------------------------------
check_cmd() {
  local cmd="$1"
  local min_ver="${2:-}"
  if command -v "$cmd" &>/dev/null; then
    local ver
    ver=$("$cmd" --version 2>&1 | head -1)
    log_pass "$cmd found: $ver"
  else
    log_fail "$cmd not found — install it first"
  fi
}

# ---------------------------------------------------------------------------
# Check: Docker version >= 24.0
# ---------------------------------------------------------------------------
check_docker() {
  if ! command -v docker &>/dev/null; then
    log_fail "docker not found — https://docs.docker.com/get-docker/"
    return
  fi

  local ver
  ver=$(docker version --format '{{.Server.Version}}' 2>/dev/null || echo '0.0.0')
  local major
  major=$(echo "$ver" | cut -d. -f1)

  if [[ "$major" -ge 24 ]]; then
    log_pass "docker $ver (>= 24.0 required)"
  else
    log_warn "docker $ver is old — recommend >= 24.0"
  fi

  # Docker daemon running?
  if docker info &>/dev/null; then
    log_pass "docker daemon is running"
  else
    log_fail "docker daemon is not running — start it first"
  fi
}

# ---------------------------------------------------------------------------
# Check: Docker Compose v2 (plugin, not standalone)
# ---------------------------------------------------------------------------
check_compose() {
  if docker compose version &>/dev/null; then
    local ver
    ver=$(docker compose version --short 2>/dev/null || echo 'unknown')
    log_pass "docker compose v2 found: $ver"
  elif command -v docker-compose &>/dev/null; then
    log_warn "docker-compose v1 found — please upgrade to Docker Compose v2 plugin"
    log_info "  https://docs.docker.com/compose/migrate/"
  else
    log_fail "docker compose not found"
  fi
}

# ---------------------------------------------------------------------------
# Check: proxy network exists
# ---------------------------------------------------------------------------
check_proxy_network() {
  if docker network inspect proxy &>/dev/null; then
    log_pass "docker network 'proxy' exists"
  else
    log_warn "docker network 'proxy' not found — run: docker network create proxy"
  fi
}

# ---------------------------------------------------------------------------
# Check: acme.json exists and has correct permissions
# ---------------------------------------------------------------------------
check_acme_json() {
  local acme_path="$(cd "$(dirname "$0")/.."; pwd)/config/traefik/acme.json"
  if [[ ! -f "$acme_path" ]]; then
    log_warn "acme.json not found — run: touch $acme_path && chmod 600 $acme_path"
    return
  fi

  local perms
  perms=$(stat -c '%a' "$acme_path" 2>/dev/null || stat -f '%A' "$acme_path" 2>/dev/null || echo 'unknown')
  if [[ "$perms" == "600" ]]; then
    log_pass "acme.json exists with correct permissions (600)"
  else
    log_fail "acme.json has permissions $perms — must be 600: chmod 600 $acme_path"
  fi
}

# ---------------------------------------------------------------------------
# Check: .env file exists
# ---------------------------------------------------------------------------
check_env_file() {
  local env_path="$(cd "$(dirname "$0")/.."; pwd)/.env"
  if [[ -f "$env_path" ]]; then
    log_pass ".env file exists"
    # Check required vars
    local required=(DOMAIN ACME_EMAIL TRAEFIK_DASHBOARD_USER TRAEFIK_DASHBOARD_PASSWORD_HASH TZ)
    for var in "${required[@]}"; do
      local val
      val=$(grep -E "^${var}=" "$env_path" | cut -d= -f2- | tr -d '\"' || true)
      if [[ -n "$val" && "$val" != "yourdomain.com" && "$val" != "you@example.com" ]]; then
        log_pass "  $var is set"
      else
        log_fail "  $var is not set or still has placeholder value"
      fi
    done
  else
    log_fail ".env not found — run: cp .env.example .env && ./scripts/setup-env.sh"
  fi
}

# ---------------------------------------------------------------------------
# Check: available ports 80 and 443
# ---------------------------------------------------------------------------
check_ports() {
  for port in 80 443; do
    if ss -tlnp 2>/dev/null | grep -q ":${port} " || \
       netstat -tlnp 2>/dev/null | grep -q ":${port} "; then
      log_warn "Port $port is already in use — Traefik will fail to bind"
    else
      log_pass "Port $port is available"
    fi
  done
}

# ---------------------------------------------------------------------------
# Check: disk space (warn if < 10GB free)
# ---------------------------------------------------------------------------
check_disk() {
  local free_gb
  free_gb=$(df -BG / | awk 'NR==2 {gsub(/G/,"",$4); print $4}')
  if [[ "$free_gb" -ge 10 ]]; then
    log_pass "Disk space: ${free_gb}GB free"
  else
    log_warn "Low disk space: ${free_gb}GB free (recommend >= 10GB)"
  fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
echo
echo -e "${BLUE}=== HomeLab Stack — Dependency Check ===${NC}"
echo

echo "[1/7] Docker"
check_docker
echo

echo "[2/7] Docker Compose"
check_compose
echo

echo "[3/7] Required commands"
check_cmd curl
check_cmd openssl
check_cmd htpasswd || log_warn "htpasswd not found — install apache2-utils (Debian) or httpd-tools (RHEL)"
echo

echo "[4/7] Proxy network"
check_proxy_network
echo

echo "[5/7] ACME / TLS config"
check_acme_json
echo

echo "[6/7] Environment file"
check_env_file
echo

echo "[7/7] Ports & disk"
check_ports
check_disk
echo

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo -e "${BLUE}=== Summary ===${NC}"
echo -e "  ${GREEN}PASS: $PASS${NC}  ${YELLOW}WARN: $WARN${NC}  ${RED}FAIL: $FAIL${NC}"
echo

if [[ "$FAIL" -gt 0 ]]; then
  echo -e "${RED}Fix the above FAIL items before proceeding.${NC}"
  exit 1
elif [[ "$WARN" -gt 0 ]]; then
  echo -e "${YELLOW}Review WARN items. Continuing may cause issues.${NC}"
  exit 0
else
  echo -e "${GREEN}All checks passed. Ready to launch.${NC}"
  exit 0
fi
