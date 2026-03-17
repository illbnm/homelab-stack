#!/usr/bin/env bash
# =============================================================================
# Base Stack — one-time setup helper
# Run this once before `docker compose up -d`
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
DYNAMIC_DIR="${REPO_ROOT}/config/traefik/dynamic"

# ── Colours ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()    { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# ── Check dependencies ────────────────────────────────────────────────────────
check_deps() {
  local missing=0
  for cmd in docker htpasswd; do
    if ! command -v "$cmd" &>/dev/null; then
      error "Missing dependency: $cmd"
      missing=1
    fi
  done
  if [[ $missing -eq 1 ]]; then
    echo
    echo "Install missing tools:"
    echo "  sudo apt-get install -y docker.io apache2-utils"
    exit 1
  fi
}

# ── Create proxy network ──────────────────────────────────────────────────────
create_network() {
  if docker network inspect proxy &>/dev/null; then
    info "Network 'proxy' already exists — skipping."
  else
    docker network create proxy
    info "Network 'proxy' created."
  fi
}

# ── Copy .env ─────────────────────────────────────────────────────────────────
setup_env() {
  local env_file="${SCRIPT_DIR}/.env"
  if [[ -f "$env_file" ]]; then
    warn ".env already exists — skipping copy."
  else
    cp "${SCRIPT_DIR}/.env.example" "$env_file"
    info ".env created from .env.example — please edit it now."
  fi
}

# ── Generate .htpasswd ────────────────────────────────────────────────────────
generate_htpasswd() {
  local htpasswd_file="${DYNAMIC_DIR}/.htpasswd"
  if [[ -f "$htpasswd_file" ]]; then
    warn ".htpasswd already exists — skipping."
    return
  fi

  echo
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo " Create Traefik dashboard credentials"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  read -rp "Username [admin]: " username
  username="${username:-admin}"
  htpasswd -cB "$htpasswd_file" "$username"
  info ".htpasswd written to ${htpasswd_file}"
}

# ── Summary ───────────────────────────────────────────────────────────────────
summary() {
  echo
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo -e " ${GREEN}Setup complete!${NC}"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo
  echo " Next steps:"
  echo "   1. Edit stacks/base/.env (set DOMAIN, ACME_EMAIL, TZ)"
  echo "   2. Configure DNS A records pointing to this server"
  echo "   3. Run:  docker compose up -d"
  echo
}

# ── Main ──────────────────────────────────────────────────────────────────────
main() {
  info "Starting base stack setup…"
  check_deps
  create_network
  setup_env
  generate_htpasswd
  summary
}

main "$@"
