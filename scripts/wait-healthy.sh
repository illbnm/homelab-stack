#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
STACK=''
TIMEOUT=300
INTERVAL=5

usage() {
  cat <<'USAGE'
Usage: scripts/wait-healthy.sh --stack <name> [--timeout 300]

Waits until all containers in a stack are running and healthy. Exit codes:
  0  all containers are running and healthy, or running with no healthcheck
  1  timeout waiting for health
  2  at least one stack container exited
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --stack) STACK=${2:-}; shift 2 ;;
    --timeout) TIMEOUT=${2:-}; shift 2 ;;
    --help|-h) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
done

[[ -n "$STACK" ]] || { usage >&2; exit 2; }
COMPOSE_FILE="$ROOT_DIR/stacks/$STACK/docker-compose.yml"
[[ -f "$COMPOSE_FILE" ]] || { printf 'Stack not found: %s\n' "$STACK" >&2; exit 2; }

container_ids() {
  docker compose -f "$COMPOSE_FILE" ps -q
}

print_unhealthy_logs() {
  local id name
  while IFS= read -r id; do
    [[ -z "$id" ]] && continue
    name=$(docker inspect --format '{{.Name}}' "$id" 2>/dev/null | sed 's#^/##')
    printf '\n--- last 50 lines for %s ---\n' "$name" >&2
    docker logs --tail=50 "$id" >&2 || true
  done < <(container_ids)
}

all_ready() {
  local id state health name ready=0 total=0
  while IFS= read -r id; do
    [[ -z "$id" ]] && continue
    total=$((total + 1))
    state=$(docker inspect --format '{{.State.Status}}' "$id")
    name=$(docker inspect --format '{{.Name}}' "$id" | sed 's#^/##')
    if [[ "$state" == exited || "$state" == dead ]]; then
      printf 'Container %s exited with state=%s\n' "$name" "$state" >&2
      return 2
    fi
    health=$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$id")
    if [[ "$state" == running && ( "$health" == healthy || "$health" == none ) ]]; then
      ready=$((ready + 1))
    else
      printf 'waiting: %s state=%s health=%s\n' "$name" "$state" "$health"
    fi
  done < <(container_ids)
  [[ "$total" -gt 0 && "$ready" -eq "$total" ]]
}

end=$((SECONDS + TIMEOUT))
while [[ "$SECONDS" -lt "$end" ]]; do
  set +e
  all_ready
  code=$?
  set -e
  case "$code" in
    0) printf 'Stack %s is healthy.\n' "$STACK"; exit 0 ;;
    2) print_unhealthy_logs; exit 2 ;;
  esac
  sleep "$INTERVAL"
done

printf 'Timed out waiting for stack %s after %ss.\n' "$STACK" "$TIMEOUT" >&2
print_unhealthy_logs
exit 1
