#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Productivity Stack Tests
# Tests: Gitea + Vaultwarden + Outline + BookStack
# =============================================================================
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/docker.sh"

should_run_stack "productivity" || { begin_suite "Productivity Stack"; assert_skip "not selected"; exit 0; }

begin_suite "Productivity Stack — Gitea + Vaultwarden + Outline + BookStack"

# ---- Gitea ----
assert_container_running "gitea"
assert_container_healthy "gitea"
assert_container_not_latest "gitea"
assert_http_200 "${BASE_URL:-http://localhost}:3000/api/v1/version" "gitea:version"

# ---- Vaultwarden ----
assert_container_running "vaultwarden"
assert_container_healthy "vaultwarden"
assert_container_not_latest "vaultwarden"
assert_http_200 "${BASE_URL:-http://localhost}:8222/alive" "vaultwarden:alive"

# ---- Outline ----
assert_container_running "outline"
assert_container_healthy "outline"
assert_container_not_latest "outline"
assert_http_200 "${BASE_URL:-http://localhost}:3100/_health" "outline:health"

# ---- BookStack ----
assert_container_running "bookstack"
assert_container_healthy "bookstack"
assert_container_not_latest "bookstack"
assert_http_200 "${BASE_URL:-http://localhost}:6875/api/ping" "bookstack:ping"

# ---- Compose validation ----
assert_compose_valid "${SCRIPT_DIR}/../../stacks/productivity/docker-compose.yml" "productivity"
