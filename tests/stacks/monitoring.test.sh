#!/usr/bin/env bash
# =============================================================================
# Monitoring Stack Tests — Prometheus, Grafana, Loki, Promtail,
#                          Alertmanager, cAdvisor, Node-Exporter
# Levels: L1, L2, L3, L5
# =============================================================================
set -euo pipefail

STACK="monitoring"

test_monitoring() {
  report_suite "${STACK}"

  # ── L1: Container health ──────────────────────────────────────────────────
  local services=(prometheus grafana loki promtail alertmanager cadvisor node-exporter)
  for svc in "${services[@]}"; do
    run_test "${STACK}" "L1: ${svc} is running" \
      assert_container_running "${svc}" || true
  done

  run_test "${STACK}" "L1: prometheus is healthy" \
    assert_container_healthy prometheus || true

  run_test "${STACK}" "L1: grafana is healthy" \
    assert_container_healthy grafana || true

  # ── L2: HTTP endpoints ────────────────────────────────────────────────────
  local prom_ip
  prom_ip=$(container_ip prometheus)

  if [[ -n "${prom_ip}" ]]; then
    run_test "${STACK}" "L2: prometheus /-/healthy -> 200" \
      assert_http_200 "http://${prom_ip}:9090/-/healthy" || true
  else
    skip_test "${STACK}" "L2: prometheus /-/healthy -> 200" "cannot resolve prometheus IP"
  fi

  local grafana_ip
  grafana_ip=$(container_ip grafana)

  if [[ -n "${grafana_ip}" ]]; then
    run_test "${STACK}" "L2: grafana /api/health -> 200" \
      assert_http_200 "http://${grafana_ip}:3000/api/health" || true
  else
    skip_test "${STACK}" "L2: grafana /api/health -> 200" "cannot resolve grafana IP"
  fi

  local am_ip
  am_ip=$(container_ip alertmanager)

  if [[ -n "${am_ip}" ]]; then
    run_test "${STACK}" "L2: alertmanager /-/healthy -> 200" \
      assert_http_200 "http://${am_ip}:9093/-/healthy" || true
  else
    skip_test "${STACK}" "L2: alertmanager /-/healthy -> 200" "cannot resolve alertmanager IP"
  fi

  # ── L3: Inter-service connectivity ────────────────────────────────────────
  if [[ -n "${prom_ip}" ]]; then
    # Prometheus -> cAdvisor
    local cadvisor_ip
    cadvisor_ip=$(container_ip cadvisor)
    if [[ -n "${cadvisor_ip}" ]]; then
      run_test "${STACK}" "L3: prometheus -> cadvisor targets" \
        docker exec prometheus wget -qO- --timeout=10 \
          "http://${cadvisor_ip}:8080/metrics" || true
    else
      skip_test "${STACK}" "L3: prometheus -> cadvisor targets" "cadvisor not reachable"
    fi
  fi

  if [[ -n "${grafana_ip}" ]] && [[ -n "${prom_ip}" ]]; then
    # Grafana -> Prometheus datasource
    run_test "${STACK}" "L3: grafana -> prometheus datasource" \
      docker exec grafana wget -qO- --timeout=10 \
        "http://${prom_ip}:9090/-/healthy" || true
  else
    skip_test "${STACK}" "L3: grafana -> prometheus datasource" "containers not reachable"
  fi

  # ── L5: Config integrity ──────────────────────────────────────────────────
  run_test "${STACK}" "L5: compose config valid" \
    compose_config_valid "${STACK}" || true

  run_test "${STACK}" "L5: no :latest image tags" \
    assert_no_latest_images "${REPO_ROOT}/stacks/${STACK}" || true
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  test_monitoring
fi
