#!/usr/bin/env bash
# =============================================================================
# Network Stack Tests — AdGuard Home, Nginx Proxy Manager
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

STACK="network"

test_network() {
  report_suite "${STACK}"

  # ── L1: Container health ──────────────────────────────────────────────────
  local services=(adguardhome nginx-proxy-manager)
  for svc in "${services[@]}"; do
    run_test "${STACK}" "L1: ${svc} is running" \
      assert_container_running "${svc}" || true
  done

  run_test "${STACK}" "L1: adguardhome is healthy" \
    assert_container_healthy adguardhome || true

  # ── L2: HTTP endpoints ────────────────────────────────────────────────────
  local adguard_ip
  adguard_ip=$(container_ip adguardhome)

  if [[ -n "${adguard_ip}" ]]; then
    run_test "${STACK}" "L2: adguard /control/status -> 200" \
      assert_http_200 "http://${adguard_ip}:3000/control/status" || true
  else
    skip_test "${STACK}" "L2: adguard /control/status -> 200" "cannot resolve adguardhome IP"
  fi

  local npm_ip
  npm_ip=$(container_ip nginx-proxy-manager)

  if [[ -n "${npm_ip}" ]]; then
    run_test "${STACK}" "L2: nginx-proxy-manager /api -> 200" \
      assert_http_200 "http://${npm_ip}:81/api" || true
  else
    skip_test "${STACK}" "L2: nginx-proxy-manager /api -> 200" "cannot resolve npm IP"
  fi

  # ── L5: Config integrity ──────────────────────────────────────────────────
  run_test "${STACK}" "L5: compose config valid" \
    compose_config_valid "${STACK}" || true

  run_test "${STACK}" "L5: no :latest image tags" \
    assert_no_latest_images "${REPO_ROOT}/stacks/${STACK}" || true
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  test_network
fi
