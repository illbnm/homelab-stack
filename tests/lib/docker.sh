#!/usr/bin/env bash
# =============================================================================
# docker.sh — Docker 工具函数
# =============================================================================

assert_container_running() {
  local name="$1"
  CURRENT_TEST="container_running:${name}"
  if docker ps --format '{{.Names}}' | grep -q "^${name}$"; then
    pass
  else
    fail_test "Container '${name}' is not running"
  fi
}

assert_container_healthy() {
  local name="$1"
  CURRENT_TEST="container_healthy:${name}"
  local health
  health=$(docker inspect --format '{{.State.Health.Status}}' "$name" 2>/dev/null || echo "none")
  if [[ "$health" == "healthy" ]]; then
    pass
  else
    fail_test "Container '${name}' health: ${health}"
  fi
}

assert_container_not_restarting() {
  local name="$1"
  CURRENT_TEST="container_stable:${name}"
  local restarts
  restarts=$(docker inspect --format '{{.RestartCount}}' "$name" 2>/dev/null || echo "-1")
  if [[ "$restarts" -lt 3 ]]; then
    pass
  else
    fail_test "Container '${name}' has restarted ${restarts} times"
  fi
}

get_container_port() {
  local name="$1" internal_port="$2"
  docker port "$name" "$internal_port" 2>/dev/null | head -1 | cut -d: -f2
}

wait_for_container() {
  local name="$1" timeout="${2:-60}"
  local elapsed=0
  while [[ $elapsed -lt $timeout ]]; do
    if docker ps --format '{{.Names}}' | grep -q "^${name}$"; then
      return 0
    fi
    sleep 2
    elapsed=$((elapsed + 2))
  done
  return 1
}

get_stack_containers() {
  local stack="$1"
  docker compose -f "stacks/${stack}/docker-compose.yml" ps --format '{{.Name}}' 2>/dev/null
}
