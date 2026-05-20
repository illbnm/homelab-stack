#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
REPORT_DIR=${REPORT_DIR:-$ROOT_DIR/diagnostics}
REPORT_FILE="$REPORT_DIR/homelab-diagnostic-$(date +%Y%m%d-%H%M%S).txt"

section() {
  printf '\n## %s\n\n' "$1"
}

run_cmd() {
  local title=$1
  shift
  printf '$ %s\n' "$*"
  "$@" 2>&1 || true
  printf '\n'
}

mkdir -p "$REPORT_DIR"
{
  printf 'HomeLab diagnostic report\nGenerated: %s\nRoot: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$ROOT_DIR"

  section "System"
  run_cmd "OS" uname -a
  [[ -f /etc/os-release ]] && run_cmd "os-release" cat /etc/os-release
  run_cmd "Memory" free -h
  run_cmd "Disk" df -h

  section "Docker"
  run_cmd "Docker version" docker version
  run_cmd "Docker info" docker info
  run_cmd "Docker compose" docker compose version
  run_cmd "Containers" docker ps -a
  run_cmd "Networks" docker network ls

  section "Compose validation"
  while IFS= read -r compose_file; do
    printf '### %s\n' "${compose_file#$ROOT_DIR/}"
    docker compose -f "$compose_file" config >/dev/null && printf 'OK\n\n' || docker compose -f "$compose_file" config || true
  done < <(find "$ROOT_DIR/stacks" -name 'docker-compose.yml' -print | sort)

  section "Recent container errors"
  while IFS= read -r container; do
    printf '### %s\n' "$container"
    docker logs --tail=100 "$container" 2>&1 | grep -Ei 'error|fail|panic|fatal|oom|denied|refused' || true
    printf '\n'
  done < <(docker ps -a --format '{{.Names}}' 2>/dev/null || true)

  section "Connectivity"
  "$ROOT_DIR/scripts/check-connectivity.sh" || true

  section "Config validation"
  "$ROOT_DIR/scripts/check-deps.sh" || true
} > "$REPORT_FILE"

printf 'Diagnostic report written to %s\n' "$REPORT_FILE"
