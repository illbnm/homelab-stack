#!/usr/bin/env bash
# =============================================================================
# Productivity Stack Tests — Gitea, Vaultwarden, Outline, BookStack
# Levels: L1, L2, L5
# =============================================================================
set -euo pipefail

STACK="productivity"

test_productivity() {
  report_suite "${STACK}"

  # ── L1: Container health ──────────────────────────────────────────────────
  local services=(gitea vaultwarden outline bookstack)
  for svc in "${services[@]}"; do
    run_test "${STACK}" "L1: ${svc} is running" \
      assert_container_running "${svc}" || true
  done

  run_test "${STACK}" "L1: gitea is healthy" \
    assert_container_healthy gitea || true

  # ── L2: HTTP endpoints ────────────────────────────────────────────────────
  local gitea_ip
  gitea_ip=$(container_ip gitea)

  if [[ -n "${gitea_ip}" ]]; then
    run_test "${STACK}" "L2: gitea /api/v1/version -> 200" \
      assert_http_200 "http://${gitea_ip}:3000/api/v1/version" || true
  else
    skip_test "${STACK}" "L2: gitea /api/v1/version -> 200" "cannot resolve gitea IP"
  fi

  local vw_ip
  vw_ip=$(container_ip vaultwarden)

  if [[ -n "${vw_ip}" ]]; then
    run_test "${STACK}" "L2: vaultwarden /alive -> 200" \
      assert_http_200 "http://${vw_ip}:80/alive" || true
  else
    skip_test "${STACK}" "L2: vaultwarden /alive -> 200" "cannot resolve vaultwarden IP"
  fi

  # ── L5: Config integrity ──────────────────────────────────────────────────
  run_test "${STACK}" "L5: compose config valid" \
    compose_config_valid "${STACK}" || true

  run_test "${STACK}" "L5: no :latest image tags" \
    assert_no_latest_images "${REPO_ROOT}/stacks/${STACK}" || true
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  test_productivity
fi
