#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Notifications Setup Script
# Sets up ntfy users, tokens, Gotify app tokens, and sends test notifications.
#
# Usage: scripts/notify-setup.sh [--test-only]
#
# Options:
#   --test-only  - Skip setup, only send test notifications
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
ENV_FILE="$BASE_DIR/.env"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

log_ok()   { echo -e "${GREEN}[OK]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_err()  { echo -e "${RED}[ERR]${NC} $*" >&2; }
log_step() { echo -e "\n${BLUE}${BOLD}==> $*${NC}"; }
log_info() { echo -e "${GREEN}[INFO]${NC} $*"; }

# Source environment
if [[ -f "$ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$ENV_FILE"
fi

STACK_ENV="$BASE_DIR/stacks/notifications/.env"
if [[ -f "$STACK_ENV" ]]; then
  # shellcheck disable=SC1090
  source "$STACK_ENV"
fi

DOMAIN="${DOMAIN:-localhost}"
NTFY_SERVER="${NTFY_SERVER:-https://ntfy.${DOMAIN}}"
GOTIFY_SERVER="${GOTIFY_SERVER:-https://gotify.${DOMAIN}}"

# Wait for a service to be ready
wait_for_service() {
  local name=$1 url=$2
  local tries=0 max_tries=30

  log_info "Waiting for $name to be ready..."
  while [[ $tries -lt $max_tries ]]; do
    if curl -sf --connect-timeout 3 --max-time 5 "$url" >/dev/null 2>&1; then
      log_ok "$name is ready"
      return 0
    fi
    tries=$((tries + 1))
    sleep 2
  done
  log_err "$name not ready after $((max_tries * 2))s"
  return 1
}

# Create ntfy user and token
setup_ntfy() {
  log_step "Setting up ntfy"

  # Check if ntfy container is running
  if ! docker ps --format '{{.Names}}' 2>/dev/null | grep -q '^ntfy$'; then
    log_err "ntfy container is not running. Start it first:"
    log_err "  cd stacks/notifications && docker compose up -d ntfy"
    return 1
  fi

  local ntfy_user="${NTFY_USER:-homelab}"
  local ntfy_pass="${NTFY_PASSWORD:-}"

  if [[ -z "$ntfy_pass" ]]; then
    ntfy_pass=$(LC_ALL=C tr -dc 'A-Za-z0-9!@#%^&*' </dev/urandom | head -c 24)
    log_info "Generated ntfy password (save this): $ntfy_pass"
  fi

  # Create user (ignore if exists)
  docker exec ntfy ntfy user add "$ntfy_user" "$ntfy_pass" 2>/dev/null \
    && log_ok "Created ntfy user: $ntfy_user" \
    || log_warn "ntfy user '$ntfy_user' may already exist"

  # Grant access
  docker exec ntfy ntfy user grant "$ntfy_user" '*' read-write 2>/dev/null \
    && log_ok "Granted read-write access to all topics" \
    || log_warn "Could not grant access (user may already have permissions)"

  # Generate token
  local token
  token=$(docker exec ntfy ntfy token create "$ntfy_user" 2>/dev/null || echo "")

  if [[ -n "$token" ]]; then
    log_ok "Created ntfy token: ${token:0:12}..."

    # Save token to stack .env
    if [[ -f "$STACK_ENV" ]]; then
      if grep -q "^NTFY_TOKEN=" "$STACK_ENV" 2>/dev/null; then
        sed -i.bak "s|^NTFY_TOKEN=.*|NTFY_TOKEN=$token|" "$STACK_ENV"
        rm -f "$STACK_ENV.bak"
      else
        echo "NTFY_TOKEN=$token" >> "$STACK_ENV"
      fi
      log_ok "Saved NTFY_TOKEN to stacks/notifications/.env"
    fi
  else
    log_warn "Could not create ntfy token — you may need to create it manually"
  fi

  # Create default topics
  for topic in homelab-alerts backups updates test; do
    log_info "Creating ntfy topic: $topic"
    curl -sf --connect-timeout 3 --max-time 5 \
      -X POST "$NTFY_SERVER/$topic" -d "Topic $topic created" 2>/dev/null || true
  done
  log_ok "Created default topics: homelab-alerts, backups, updates, test"
}

# Create Gotify app token
setup_gotify() {
  log_step "Setting up Gotify"

  if ! docker ps --format '{{.Names}}' 2>/dev/null | grep -q '^gotify$'; then
    log_warn "Gotify container is not running, skipping setup"
    return 0
  fi

  wait_for_service "Gotify" "$GOTIFY_SERVER/"

  # Login to get JWT token
  local admin_pass="${GOTIFY_PASSWORD:-}"
  if [[ -z "$admin_pass" ]]; then
    log_err "GOTIFY_PASSWORD not set. Set it in stacks/notifications/.env"
    return 1
  fi

  local admin_user="${GOTIFY_DEFAULTUSER:-admin}"

  local jwt
  jwt=$(curl -sf --connect-timeout 5 --max-time 10 \
    "$GOTIFY_SERVER/token" \
    -d "client_name=setup-script&username=$admin_user&password=$admin_pass" 2>/dev/null \
    | python3 -c "import json,sys; print(json.load(sys.stdin)['token'])" 2>/dev/null || echo "")

  if [[ -z "$jwt" ]]; then
    log_warn "Could not authenticate with Gotify"
    return 1
  fi

  log_ok "Authenticated with Gotify"

  # Create application for notifications
  local app_response
  app_response=$(curl -sf --connect-timeout 5 --max-time 10 \
    -X POST "$GOTIFY_SERVER/application" \
    -H "X-Gotify-Key: $jwt" \
    -H "Content-Type: application/json" \
    -d '{"name":"homelab-notifications","description":"Unified homelab notification channel"}' 2>/dev/null || echo "")

  local gotify_token
  gotify_token=$(echo "$app_response" | python3 -c "import json,sys; print(json.load(sys.stdin)['token'])" 2>/dev/null || echo "")

  if [[ -n "$gotify_token" ]]; then
    log_ok "Created Gotify app 'homelab-notifications'"
    log_info "Gotify app token: ${gotify_token:0:12}..."

    # Save to stack .env
    if [[ -f "$STACK_ENV" ]]; then
      if grep -q "^GOTIFY_TOKEN=" "$STACK_ENV" 2>/dev/null; then
        sed -i.bak "s|^GOTIFY_TOKEN=.*|GOTIFY_TOKEN=$gotify_token|" "$STACK_ENV"
        rm -f "$STACK_ENV.bak"
      else
        echo "GOTIFY_TOKEN=$gotify_token" >> "$STACK_ENV"
      fi
      log_ok "Saved GOTIFY_TOKEN to stacks/notifications/.env"
    fi
  else
    log_warn "Could not create Gotify application"
  fi
}

# Send test notifications
send_test() {
  log_step "Sending test notifications"

  # Test ntfy
  log_info "Testing ntfy..."
  if curl -sf --connect-timeout 5 --max-time 10 \
    -X POST "$NTFY_SERVER/homelab-test" \
    -H "Title: HomeLab Test" \
    -H "Priority: 3" \
    -d "Notification stack is working! Sent at $(date -u +%Y-%m-%dT%H:%M:%SZ)" 2>/dev/null; then
    log_ok "ntfy: test notification sent to topic 'homelab-test'"
  else
    log_err "ntfy: test notification failed"
  fi

  # Test Gotify
  if [[ -n "${GOTIFY_TOKEN:-}" ]]; then
    log_info "Testing Gotify..."
    if curl -sf --connect-timeout 5 --max-time 10 \
      -X POST "$GOTIFY_SERVER/message" \
      -H "X-Gotify-Key: $GOTIFY_TOKEN" \
      -F "title=HomeLab Test" \
      -F "message=Notification stack is working!" \
      -F "priority=5" 2>/dev/null; then
      log_ok "Gotify: test notification sent"
    else
      log_err "Gotify: test notification failed"
    fi
  else
    log_warn "GOTIFY_TOKEN not set, skipping Gotify test"
  fi

  # Test notify.sh script
  log_info "Testing scripts/notify.sh..."
  if "$SCRIPT_DIR/notify.sh" homelab-test "Script Test" \
    "Unified notify.sh script is working! $(date -u +%Y-%m-%dT%H:%M:%SZ)"; then
    log_ok "notify.sh: test sent successfully"
  else
    log_err "notify.sh: test failed"
  fi
}

# ---- Main ----
TEST_ONLY=false
[[ "${1:-}" == "--test-only" ]] && TEST_ONLY=true

echo -e "\n${BOLD}  HomeLab Notifications Setup${NC}\n"

if [[ "$TEST_ONLY" == "false" ]]; then
  setup_ntfy
  setup_gotify
fi

send_test

echo ""
log_ok "Notifications setup complete!"
echo ""
echo "Quick reference:"
echo "  Gotify:  https://gotify.${DOMAIN}"
echo "  ntfy:    https://ntfy.${DOMAIN}"
echo "  Apprise: https://apprise.${DOMAIN}"
echo ""
echo "Send a test notification:"
echo "  ./scripts/notify.sh test 'Hello' 'World'"
echo ""
echo "Subscribe on your phone:"
echo "  1. Install ntfy app (iOS / Android)"
echo "  2. Add server: https://ntfy.${DOMAIN}"
echo "  3. Subscribe to topic: homelab-alerts"
