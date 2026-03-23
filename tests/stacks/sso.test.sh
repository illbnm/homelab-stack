#!/usr/bin/env bash
# =============================================================================
# SSO Stack Tests — Authentik Server, Worker, PostgreSQL, Redis
# Levels: L1, L2, L5
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/../lib"

# shellcheck source=tests/lib/assert.sh
source "${LIB_DIR}/assert.sh"
# shellcheck source=tests/lib/docker.sh
source "${LIB_DIR}/docker.sh"
# shellcheck source=tests/lib/report.sh
source "${LIB_DIR}/report.sh"

STACK="sso"

test_sso() {
  report_suite "${STACK}"

  # ── L1: Container health ──────────────────────────────────────────────────
  # SSO stack has its own postgres/redis separate from shared databases
  local services=(authentik-server authentik-worker authentik-postgres authentik-redis)
  for svc in "${services[@]}"; do
    run_test "${STACK}" "L1: ${svc} is running" \
      assert_container_running "${svc}" || true
  done

  run_test "${STACK}" "L1: authentik-server is healthy" \
    assert_container_healthy authentik-server || true

  run_test "${STACK}" "L1: authentik-postgres is healthy" \
    assert_container_healthy authentik-postgres || true

  # ── L2: HTTP endpoints ────────────────────────────────────────────────────
  local authentik_ip
  authentik_ip=$(container_ip authentik-server)

  if [[ -n "${authentik_ip}" ]]; then
    run_test "${STACK}" "L2: authentik /api/v3/core/users/?page_size=1 -> 200" \
      assert_http_200 "http://${authentik_ip}:9000/api/v3/core/users/?page_size=1" || true
  else
    skip_test "${STACK}" "L2: authentik /api/v3/core/users/?page_size=1 -> 200" \
      "cannot resolve authentik-server IP"
  fi

  # ── L5: Config integrity ──────────────────────────────────────────────────
  run_test "${STACK}" "L5: compose config valid" \
    compose_config_valid "${STACK}" || true

  run_test "${STACK}" "L5: no :latest image tags" \
    assert_no_latest_images "${REPO_ROOT}/stacks/${STACK}" || true
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  test_sso
fi
