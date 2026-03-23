#!/usr/bin/env bash
# =============================================================================
# AI Stack Tests — Ollama, Open-WebUI, Stable-Diffusion
# Levels: L1, L2, L5
# =============================================================================
set -euo pipefail

STACK="ai"

test_ai() {
  report_suite "${STACK}"

  # ── L1: Container health ──────────────────────────────────────────────────
  local services=(ollama open-webui stable-diffusion)
  for svc in "${services[@]}"; do
    run_test "${STACK}" "L1: ${svc} is running" \
      assert_container_running "${svc}" || true
  done

  run_test "${STACK}" "L1: ollama is healthy" \
    assert_container_healthy ollama || true

  # ── L2: HTTP endpoints ────────────────────────────────────────────────────
  local ollama_ip
  ollama_ip=$(container_ip ollama)

  if [[ -n "${ollama_ip}" ]]; then
    run_test "${STACK}" "L2: ollama /api/version -> 200" \
      assert_http_200 "http://${ollama_ip}:11434/api/version" || true
  else
    skip_test "${STACK}" "L2: ollama /api/version -> 200" "cannot resolve ollama IP"
  fi

  local webui_ip
  webui_ip=$(container_ip open-webui)

  if [[ -n "${webui_ip}" ]]; then
    run_test "${STACK}" "L2: open-webui / -> 200" \
      assert_http_200 "http://${webui_ip}:8080/" || true
  else
    skip_test "${STACK}" "L2: open-webui / -> 200" "cannot resolve open-webui IP"
  fi

  # ── L5: Config integrity ──────────────────────────────────────────────────
  run_test "${STACK}" "L5: compose config valid" \
    compose_config_valid "${STACK}" || true

  run_test "${STACK}" "L5: no :latest image tags" \
    assert_no_latest_images "${REPO_ROOT}/stacks/${STACK}" || true
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  test_ai
fi
