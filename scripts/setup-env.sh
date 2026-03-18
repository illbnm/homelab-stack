#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack -- Interactive .env Setup
# =============================================================================
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR=$(dirname "$SCRIPT_DIR")
ENV_FILE="$ROOT_DIR/.env"
EXAMPLE_FILE="$ROOT_DIR/.env.example"

RED='[0;31m'; YELLOW='[1;33m'; GREEN='[0;32m'
CYAN='[0;36m'; BOLD='[1m'; RESET='[0m'

log_info()  { echo -e "${GREEN}[INFO]${RESET} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${RESET} $*"; }
log_error() { echo -e "${RED}[ERROR]${RESET} $*" >&2; }
log_step()  { echo; echo -e "${BOLD}${CYAN}==> $*${RESET}"; }
log_ask()   { printf '%s' "${BOLD}${YELLOW}[?]${RESET} $* "; }

ask() {
  local prompt="$1" default="${2:-}" val
  log_ask "$prompt${default:+ [$default]}:"
  read -r val
  printf '%s' "${val:-$default}"
}

ask_secret() {
  local prompt="$1" val
  log_ask "$prompt (hidden):"
  read -rs val; echo
  printf '%s' "$val"
}

set_env() {
  local key="$1" val="$2"
  if grep -q "^${key}=" "$ENV_FILE" 2>/dev/null; then
    sed -i "s|^${key}=.*|${key}=${val}|" "$ENV_FILE"
  else
    printf '%s=%s
' "$key" "$val" >> "$ENV_FILE"
  fi
}

get_env() { grep -m1 "^${1}=" "$ENV_FILE" 2>/dev/null | cut -d= -f2- || true; }
gen_secret() { LC_ALL=C tr -dc 'A-Za-z0-9!@#%^&*' </dev/urandom | head -c "${1:-32}" || true; }

main() {
  echo; echo "HomeLab Stack -- Environment Setup"
  [[ "${1:-}" == "--reset" ]] && { rm -f "$ENV_FILE"; log_info "Reset .env"; }
  [[ ! -f "$ENV_FILE" ]] && { cp "$EXAMPLE_FILE" "$ENV_FILE"; log_info "Created .env from example"; }

  log_step "General Settings"
  set_env DOMAIN    "$(ask 'Base domain' "$(get_env DOMAIN)")"
  set_env ACME_EMAIL "$(ask "Let's Encrypt email" "$(get_env ACME_EMAIL)")"
  set_env TZ        "$(ask 'Timezone' "$(get_env TZ)")"

  log_step "Traefik Dashboard"
  local user; user=$(ask 'Dashboard username' "$(get_env TRAEFIK_DASHBOARD_USER)")
  set_env TRAEFIK_DASHBOARD_USER "$user"
  if [[ -z "$(get_env TRAEFIK_DASHBOARD_PASSWORD_HASH)" ]]; then
    local pass; pass=$(ask_secret 'Dashboard password')
    if command -v htpasswd &>/dev/null; then
      set_env TRAEFIK_DASHBOARD_PASSWORD_HASH "$(htpasswd -nbB "$user" "$pass" | sed 's/\$/\$\$/g')"
    else
      log_warn 'htpasswd not found — set TRAEFIK_DASHBOARD_PASSWORD_HASH manually'
    fi
  fi

  log_step "CN Mirror (Optional)"
  local cn; cn=$(ask 'Enable CN mirrors? (true/false)' "$(get_env CN_MODE)")
  set_env CN_MODE "$cn"

  echo; log_info "Done. Next: cd stacks/base && docker compose up -d"; echo
}

main "${@:-}"
