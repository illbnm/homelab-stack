#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Dashboard Tests
# Tests: Homarr + Homepage
# =============================================================================
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/docker.sh"

should_run_stack "dashboard" || { begin_suite "Dashboard"; assert_skip "not selected"; exit 0; }

begin_suite "Dashboard — Homarr + Homepage"

# ---- Homarr ----
assert_container_running "homarr"
assert_container_healthy "homarr"
assert_container_not_latest "homarr"
assert_http_200 "${BASE_URL:-http://localhost}:7575" "homarr:ui"

# ---- Homepage ----
assert_container_running "homepage"
assert_container_healthy "homepage"
assert_container_not_latest "homepage"
assert_http_200 "${BASE_URL:-http://localhost}:3001" "homepage:ui"

# ---- Compose validation ----
assert_compose_valid "${SCRIPT_DIR}/../../stacks/dashboard/docker-compose.yml" "dashboard"
