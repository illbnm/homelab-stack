#!/usr/bin/env bash
# SSO Stack Tests — Authentik (server + worker + postgres + redis)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
source "$SCRIPT_DIR/../lib/assert.sh"
source "$SCRIPT_DIR/../lib/docker.sh"

reset_counters
log_test_start "SSO Stack (Authentik)"

section "Authentik Server"
assert_container_running "Authentik server" "authentik-server"
assert_container_healthy "Authentik server health" "authentik-server"

section "Authentik Worker"
assert_container_running "Authentik worker" "authentik-worker"

section "Authentik Postgres"
assert_container_healthy "Authentik Postgres healthy" "authentik-postgres" \
  || assert_container_running "Authentik Postgres running" "authentik-postgres"

section "Authentik Redis"
assert_container_healthy "Authentik Redis healthy" "authentik-redis" \
  || assert_container_running "Authentik Redis running" "authentik-redis"

assert_summary