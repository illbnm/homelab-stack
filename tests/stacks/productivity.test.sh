#!/usr/bin/env bash
# Productivity Stack Tests — Gitea, Vaultwarden, Outline, BookStack
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
source "$SCRIPT_DIR/../lib/assert.sh"
source "$SCRIPT_DIR/../lib/docker.sh"

reset_counters
log_test_start "Productivity Stack"

section "Gitea"
assert_container_running "Gitea container" "homelab-gitea"
assert_http_2xx "Gitea HTTP" "http://localhost:3002/" || true

section "Vaultwarden"
assert_container_running "Vaultwarden container" "homelab-vaultwarden"
assert_http_2xx "Vaultwarden alive" "http://localhost:8081/alive" || true

section "Outline"
if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^homelab-outline$"; then
  assert_container_running "Outline running" "homelab-outline"
  assert_http_2xx "Outline HTTP" "http://localhost:3003/" || true
else
  skip "Outline not deployed"
fi

section "BookStack"
if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^homelab-bookstack$"; then
  assert_container_running "BookStack running" "homelab-bookstack"
  assert_http_2xx "BookStack HTTP" "localhost" "6875" || true
else
  skip "BookStack not deployed"
fi

assert_summary