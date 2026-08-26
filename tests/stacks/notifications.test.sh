#!/usr/bin/env bash
# Notifications Stack Tests — ntfy, Gotify
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
source "$SCRIPT_DIR/../lib/assert.sh"
source "$SCRIPT_DIR/../lib/docker.sh"

reset_counters
log_test_start "Notifications Stack"

section "ntfy"
assert_container_running "ntfy running" "ntfy"
assert_http_2xx "ntfy health" "http://localhost:80/v1/health" || true

section "Gotify"
assert_container_running "Gotify running" "gotify"
assert_http_2xx "Gotify health" "http://localhost:80/health" || true

section "Config validation"
[[ -f "$ROOT_DIR/stacks/notifications/server.yml" ]] \
  && pass "ntfy server.yml exists" \
  || fail "ntfy server.yml missing"
[[ -f "$ROOT_DIR/stacks/notifications/.env.example" ]] \
  && pass ".env.example exists" \
  || fail ".env.example missing"
[[ -f "$ROOT_DIR/stacks/notifications/scripts/notify.sh" ]] \
  && pass "notify.sh exists" \
  || fail "notify.sh missing"

assert_summary