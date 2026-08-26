#!/usr/bin/env bash
# Base Infrastructure Stack Tests
# Tests: Traefik, Portainer, Watchtower
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
source "$SCRIPT_DIR/../lib/assert.sh"
source "$SCRIPT_DIR/../lib/docker.sh"
source "$SCRIPT_DIR/../lib/report.sh"

reset_counters
log_test_start "Base Infrastructure"

# Load env
ENV_FILE="$ROOT_DIR/.env"
[[ -f "$ENV_FILE" ]] && export $(grep -v '^#' "$ENV_FILE" | xargs)

DOMAIN="${DOMAIN:-localhost}"

# ── Traefik ───────────────────────────────────────────────────────────────────
section "Traefik"
assert_container_running "Traefik running" "traefik"
assert_http_200 "Traefik dashboard HTTP 200" "http://localhost:8080/api/overview" || true
# Try health endpoint
assert_http_2xx "Traefik HTTP accessible" "http://traefik:8080/api/overview" || true

# ── Portainer ────────────────────────────────────────────────────────────────
section "Portainer"
assert_container_running "Portainer running" "portainer"
assert_http_2xx "Portainer API accessible" "http://localhost:9000/api/system/status" || true

# ── Watchtower ───────────────────────────────────────────────────────────────
section "Watchtower"
assert_container_running "Watchtower running" "watchtower"

# ── Config validation ────────────────────────────────────────────────────────
section "Config validation"
[[ -f "$ROOT_DIR/config/traefik/dynamic/middlewares.yml" ]] && pass "Traefik middlewares config exists" || fail "Traefik middlewares config missing"
[[ -f "$ENV_FILE" ]] && pass ".env exists" || fail ".env missing"

assert_summary