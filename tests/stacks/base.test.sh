#!/usr/bin/env bash
# =============================================================================
# Base Stack Tests — Traefik, Portainer, Watchtower
# Levels: L1 (health), L2 (HTTP), L5 (config integrity)
# =============================================================================
set -euo pipefail

STACK="base"

test_base() {
  report_suite "${STACK}"

  # ── L1: Container health ──────────────────────────────────────────────────
  run_test "${STACK}" "L1: traefik is running" \
    assert_container_running traefik

  run_test "${STACK}" "L1: portainer is running" \
    assert_container_running portainer

  run_test "${STACK}" "L1: watchtower is running" \
    assert_container_running watchtower

  run_test "${STACK}" "L1: traefik is healthy" \
    assert_container_healthy traefik || true

  run_test "${STACK}" "L1: portainer is healthy" \
    assert_container_healthy portainer || true

  # ── L2: HTTP endpoints ────────────────────────────────────────────────────
  local traefik_ip
  traefik_ip=$(container_ip traefik)

  if [[ -n "${traefik_ip}" ]]; then
    run_test "${STACK}" "L2: traefik /api/version -> 200" \
      assert_http_200 "http://${traefik_ip}:8080/api/version" || true
  else
    skip_test "${STACK}" "L2: traefik /api/version -> 200" "cannot resolve traefik IP"
  fi

  local portainer_ip
  portainer_ip=$(container_ip portainer)

  if [[ -n "${portainer_ip}" ]]; then
    run_test "${STACK}" "L2: portainer /api/status -> 200" \
      assert_http_200 "http://${portainer_ip}:9000/api/status" || true
  else
    skip_test "${STACK}" "L2: portainer /api/status -> 200" "cannot resolve portainer IP"
  fi

  # ── L5: Config integrity ──────────────────────────────────────────────────
  run_test "${STACK}" "L5: compose config valid" \
    compose_config_valid "${STACK}" || true

  run_test "${STACK}" "L5: no :latest image tags" \
    assert_no_latest_images "${REPO_ROOT}/stacks/${STACK}" || true
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  test_base
fi
