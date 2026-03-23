#!/usr/bin/env bash
# =============================================================================
# Notifications Stack Tests — ntfy, Apprise
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

STACK="notifications"

test_notifications() {
  report_suite "${STACK}"

  # ── L1: Container health ──────────────────────────────────────────────────
  local services=(ntfy apprise)
  for svc in "${services[@]}"; do
    run_test "${STACK}" "L1: ${svc} is running" \
      assert_container_running "${svc}" || true
  done

  run_test "${STACK}" "L1: ntfy is healthy" \
    assert_container_healthy ntfy || true

  # ── L2: HTTP endpoints ────────────────────────────────────────────────────
  local ntfy_ip
  ntfy_ip=$(container_ip ntfy)

  if [[ -n "${ntfy_ip}" ]]; then
    run_test "${STACK}" "L2: ntfy /v1/health -> 200" \
      assert_http_200 "http://${ntfy_ip}:80/v1/health" || true
  else
    skip_test "${STACK}" "L2: ntfy /v1/health -> 200" "cannot resolve ntfy IP"
  fi

  local apprise_ip
  apprise_ip=$(container_ip apprise)

  if [[ -n "${apprise_ip}" ]]; then
    run_test "${STACK}" "L2: apprise /status -> 200" \
      assert_http_200 "http://${apprise_ip}:8000/status" || true
  else
    skip_test "${STACK}" "L2: apprise /status -> 200" "cannot resolve apprise IP"
  fi

  # ── L5: Config integrity ──────────────────────────────────────────────────
  run_test "${STACK}" "L5: compose config valid" \
    compose_config_valid "${STACK}" || true

  run_test "${STACK}" "L5: no :latest image tags" \
    assert_no_latest_images "${REPO_ROOT}/stacks/${STACK}" || true
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  test_notifications
fi
