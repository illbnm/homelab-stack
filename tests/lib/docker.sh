#!/usr/bin/env bash
set -euo pipefail

compose_file_for_stack() {
  local base_dir="$1" stack="$2"
  if [[ -f "$base_dir/stacks/$stack/docker-compose.local.yml" ]]; then
    printf '%s\n' "$base_dir/stacks/$stack/docker-compose.local.yml"
  else
    printf '%s\n' "$base_dir/stacks/$stack/docker-compose.yml"
  fi
}

stack_compose_services() {
  local compose_file="$1"
  yq -r '.services | keys[]' "$compose_file" 2>/dev/null || \
    docker compose -f "$compose_file" config --services
}

service_container_name() {
  local compose_file="$1" service="$2"
  docker compose -f "$compose_file" config --services >/dev/null
  docker compose -f "$compose_file" config | awk -v svc="$service" '
    $1 == "services:" { in_services=1; next }
    in_services && $1 == svc ":" { in_service=1; next }
    in_service && $1 == "container_name:" { print $2; exit }
    in_service && /^[^[:space:]]/ { in_service=0 }
  '
}
