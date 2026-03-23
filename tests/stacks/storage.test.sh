#!/usr/bin/env bash
# =============================================================================
# Storage Stack Tests — Nextcloud, MinIO, FileBrowser
# Levels: L1, L2, L5
# =============================================================================
set -euo pipefail

STACK="storage"

test_storage() {
  report_suite "${STACK}"

  # ── L1: Container health ──────────────────────────────────────────────────
  local services=(nextcloud minio filebrowser)
  for svc in "${services[@]}"; do
    run_test "${STACK}" "L1: ${svc} is running" \
      assert_container_running "${svc}" || true
  done

  run_test "${STACK}" "L1: nextcloud is healthy" \
    assert_container_healthy nextcloud || true

  # ── L2: HTTP endpoints ────────────────────────────────────────────────────
  local nextcloud_ip
  nextcloud_ip=$(container_ip nextcloud)

  if [[ -n "${nextcloud_ip}" ]]; then
    run_test "${STACK}" "L2: nextcloud /status.php -> 200" \
      assert_http_200 "http://${nextcloud_ip}:80/status.php" || true

    # Verify JSON response contains installed:true
    local nc_response
    nc_response=$(curl -fsSL --max-time 15 -k \
      "http://${nextcloud_ip}:80/status.php" 2>/dev/null || echo "{}")
    run_test "${STACK}" "L2: nextcloud installed == true" \
      assert_json_value "${nc_response}" ".installed" "true" || true
  else
    skip_test "${STACK}" "L2: nextcloud /status.php -> 200" "cannot resolve nextcloud IP"
    skip_test "${STACK}" "L2: nextcloud installed == true" "cannot resolve nextcloud IP"
  fi

  local minio_ip
  minio_ip=$(container_ip minio)

  if [[ -n "${minio_ip}" ]]; then
    run_test "${STACK}" "L2: minio /minio/health/live -> 200" \
      assert_http_200 "http://${minio_ip}:9000/minio/health/live" || true
  else
    skip_test "${STACK}" "L2: minio /minio/health/live -> 200" "cannot resolve minio IP"
  fi

  # ── L5: Config integrity ──────────────────────────────────────────────────
  run_test "${STACK}" "L5: compose config valid" \
    compose_config_valid "${STACK}" || true

  run_test "${STACK}" "L5: no :latest image tags" \
    assert_no_latest_images "${REPO_ROOT}/stacks/${STACK}" || true
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  test_storage
fi
