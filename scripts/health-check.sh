#!/usr/bin/env bash
# =============================================================================
# health-check.sh — Check health of all running HomeLab services
# =============================================================================
set -euo pipefail

PASS=0
FAIL=0
WARN=0

check_container() {
  local name=$1
  local expected_status=${2:-running}

  if ! docker inspect "$name" &>/dev/null; then
    echo "  ⚠️  $name — NOT FOUND (not deployed?)"
    ((WARN++))
    return
  fi

  local status
  status=$(docker inspect --format='{{.State.Status}}' "$name" 2>/dev/null)
  local health
  health=$(docker inspect --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$name" 2>/dev/null)

  if [[ "$status" == "$expected_status" ]]; then
    if [[ "$health" == "healthy" || "$health" == "none" ]]; then
      echo "  ✅ $name — $status"
      ((PASS++))
    elif [[ "$health" == "starting" ]]; then
      echo "  ⏳ $name — $status (health: starting)"
      ((WARN++))
    else
      echo "  ❌ $name — $status (health: $health)"
      ((FAIL++))
    fi
  else
    echo "  ❌ $name — $status (expected: $expected_status)"
    ((FAIL++))
  fi
}

echo "=============================================="
echo "  HomeLab Stack — Health Check"
echo "  $(date '+%Y-%m-%d %H:%M:%S')"
echo "=============================================="
echo ""

echo "[ Base ]"
check_container traefik
check_container portainer
check_container watchtower
echo ""

echo "[ Monitoring ]"
check_container prometheus
check_container grafana
check_container loki
check_container alertmanager
check_container node-exporter
check_container uptime-kuma
echo ""

echo "[ SSO ]"
check_container authentik-server
check_container authentik-worker
check_container authentik-db
check_container authentik-redis
echo ""

echo "[ AI ]"
check_container ollama
check_container open-webui
echo ""

echo "=============================================="
echo "  ✅ $PASS healthy  ⚠️  $WARN warnings  ❌ $FAIL failed"
if [[ $FAIL -gt 0 ]]; then
  echo "  Run: docker logs <container_name> for details"
  exit 1
fi
