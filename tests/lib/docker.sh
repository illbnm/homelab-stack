#!/usr/bin/env bash
set -euo pipefail

wait_for_container() {
  local name="$1" timeout="${2:-120}"
  local elapsed=0
  while [ $elapsed -lt $timeout ]; do
    local status
    status=$(docker inspect --format='{{.State.Status}}' "$name" 2>/dev/null || echo "")
    if [ "$status" = "running" ]; then
      return 0
    fi
    sleep 2
    elapsed=$((elapsed + 2))
  done
  echo "Timeout waiting for container $name" >&2
  return 1
}

get_container_ip() {
  local name="$1" network="${2:-bridge}"
  docker inspect --format="{{.NetworkSettings.Networks.$network.IPAddress}}" "$name" 2>/dev/null || echo ""
}

stack_dir() {
  local stack="$1"
  echo "$(dirname "$0")/../../stacks/$stack"
}

compose_file() {
  local stack="$1"
  local dir
  dir=$(stack_dir "$stack")
  if [ -f "$dir/docker-compose.yml" ]; then
    echo "$dir/docker-compose.yml"
  elif [ -f "$dir/compose.yml" ]; then
    echo "$dir/compose.yml"
  else
    echo ""
  fi
}

export -f wait_for_container get_container_ip stack_dir compose_file
