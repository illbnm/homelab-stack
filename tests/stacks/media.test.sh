#!/usr/bin/env bash
# =============================================================================
# Media Stack Tests — Jellyfin, Sonarr, Radarr, Prowlarr, qBittorrent
# Levels: L1, L2, L3, L5
# =============================================================================
set -euo pipefail

STACK="media"

test_media() {
  report_suite "${STACK}"

  # ── L1: Container health ──────────────────────────────────────────────────
  local services=(jellyfin sonarr radarr prowlarr qbittorrent)
  for svc in "${services[@]}"; do
    run_test "${STACK}" "L1: ${svc} is running" \
      assert_container_running "${svc}" || true
  done

  run_test "${STACK}" "L1: jellyfin is healthy" \
    assert_container_healthy jellyfin || true

  # ── L2: HTTP endpoints ────────────────────────────────────────────────────
  local jellyfin_ip
  jellyfin_ip=$(container_ip jellyfin)

  if [[ -n "${jellyfin_ip}" ]]; then
    run_test "${STACK}" "L2: jellyfin /health -> 200" \
      assert_http_200 "http://${jellyfin_ip}:8096/health" || true
  else
    skip_test "${STACK}" "L2: jellyfin /health -> 200" "cannot resolve jellyfin IP"
  fi

  local sonarr_ip
  sonarr_ip=$(container_ip sonarr)

  if [[ -n "${sonarr_ip}" ]]; then
    run_test "${STACK}" "L2: sonarr /ping -> 200" \
      assert_http_200 "http://${sonarr_ip}:8989/ping" || true
  else
    skip_test "${STACK}" "L2: sonarr /ping -> 200" "cannot resolve sonarr IP"
  fi

  local radarr_ip
  radarr_ip=$(container_ip radarr)

  if [[ -n "${radarr_ip}" ]]; then
    run_test "${STACK}" "L2: radarr /ping -> 200" \
      assert_http_200 "http://${radarr_ip}:7878/ping" || true
  else
    skip_test "${STACK}" "L2: radarr /ping -> 200" "cannot resolve radarr IP"
  fi

  # ── L3: Inter-service connectivity ────────────────────────────────────────
  if [[ -n "${sonarr_ip}" ]]; then
    local qbt_ip
    qbt_ip=$(container_ip qbittorrent)
    if [[ -n "${qbt_ip}" ]]; then
      run_test "${STACK}" "L3: sonarr -> qbittorrent connectivity" \
        docker exec sonarr wget -q -O /dev/null --timeout=10 \
          "http://${qbt_ip}:8080/api/v2/app/version" || true
    else
      skip_test "${STACK}" "L3: sonarr -> qbittorrent connectivity" "qbittorrent not reachable"
    fi
  fi

  # ── L5: Config integrity ──────────────────────────────────────────────────
  run_test "${STACK}" "L5: compose config valid" \
    compose_config_valid "${STACK}" || true

  run_test "${STACK}" "L5: no :latest image tags" \
    assert_no_latest_images "${REPO_ROOT}/stacks/${STACK}" || true
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  test_media
fi
