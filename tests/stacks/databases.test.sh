#!/usr/bin/env bash
# =============================================================================
# Databases Stack Tests — PostgreSQL, Redis, MariaDB
# Levels: L1, L5
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

STACK="databases"

test_databases() {
  report_suite "${STACK}"

  # ── L1: Container health ──────────────────────────────────────────────────
  local services=(homelab-postgres homelab-redis homelab-mariadb)
  for svc in "${services[@]}"; do
    run_test "${STACK}" "L1: ${svc} is running" \
      assert_container_running "${svc}" || true
  done

  run_test "${STACK}" "L1: homelab-postgres is healthy" \
    assert_container_healthy homelab-postgres || true

  run_test "${STACK}" "L1: homelab-redis is healthy" \
    assert_container_healthy homelab-redis || true

  # ── L1: Database connectivity ─────────────────────────────────────────────
  run_test "${STACK}" "L1: postgres accepts connections" \
    docker exec homelab-postgres pg_isready -U postgres || true

  run_test "${STACK}" "L1: redis responds to PING" \
    docker exec homelab-redis redis-cli ping || true

  run_test "${STACK}" "L1: mariadb accepts connections" \
    docker exec homelab-mariadb mariadb-admin ping \
      --user=root --password="${MARIADB_ROOT_PASSWORD:-changeme}" || true

  # ── L5: Config integrity ──────────────────────────────────────────────────
  run_test "${STACK}" "L5: compose config valid" \
    compose_config_valid "${STACK}" || true

  run_test "${STACK}" "L5: no :latest image tags" \
    assert_no_latest_images "${REPO_ROOT}/stacks/${STACK}" || true
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  test_databases
fi
