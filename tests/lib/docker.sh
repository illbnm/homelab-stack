#!/usr/bin/env bash

: "${PROJECT_ROOT:?PROJECT_ROOT must be set}"

STACKS=(base databases sso monitoring network storage productivity media ai home-automation notifications dashboard)

stack_compose_file() {
  local stack=$1
  printf '%s/stacks/%s/docker-compose.yml' "$PROJECT_ROOT" "$stack"
}

docker_available() {
  command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1
}

compose_available() {
  command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1
}

assert_stack_compose_file() {
  local stack=$1
  local file
  file=$(stack_compose_file "$stack")
  if [[ -f "$file" ]]; then
    pass_result "$stack compose file exists" "$file"
  else
    fail_result "$stack compose file exists" "missing: $file"
  fi
}

assert_compose_config() {
  local stack=$1
  local file output start_ms
  file=$(stack_compose_file "$stack")
  start_ms=$(current_millis)
  if ! compose_available; then
    skip_result "$stack compose config is valid" "docker compose is not available" "$start_ms"
    return
  fi
  if output=$(docker compose -f "$file" config 2>&1 >/dev/null); then
    pass_result "$stack compose config is valid" "$file" "$start_ms"
  else
    fail_result "$stack compose config is valid" "$output" "$start_ms"
  fi
}

assert_compose_services_declared() {
  local stack=$1
  shift
  local file services service start_ms missing=()
  file=$(stack_compose_file "$stack")
  start_ms=$(current_millis)
  if ! compose_available; then
    skip_result "$stack expected services are declared" "docker compose is not available" "$start_ms"
    return
  fi
  if ! services=$(docker compose -f "$file" config --services 2>/dev/null); then
    fail_result "$stack expected services are declared" "unable to list compose services" "$start_ms"
    return
  fi
  for service in "$@"; do
    if ! grep -Fxq "$service" <<< "$services"; then
      missing+=("$service")
    fi
  done
  if [[ "${#missing[@]}" -eq 0 ]]; then
    pass_result "$stack expected services are declared" "$*" "$start_ms"
  else
    fail_result "$stack expected services are declared" "missing services: ${missing[*]}" "$start_ms"
  fi
}

assert_stack_static_checks() {
  local stack=$1
  local file
  file=$(stack_compose_file "$stack")
  assert_stack_compose_file "$stack"
  assert_file_contains "$file" '^[[:space:]]*services:' "$stack compose declares services"
  assert_no_latest_images "$file" "$stack compose images are pinned"
  assert_compose_config "$stack"
}

assert_container_on_network() {
  local container=$1
  local network=$2
  local name=${3:-"container $container is attached to $network"}
  local start_ms networks
  start_ms=$(current_millis)
  if ! command -v docker >/dev/null 2>&1; then
    skip_result "$name" "docker is not installed" "$start_ms"
    return
  fi
  if ! networks=$(docker inspect --format '{{json .NetworkSettings.Networks}}' "$container" 2>/dev/null); then
    fail_result "$name" "container not found: $container" "$start_ms"
    return
  fi
  if grep -q "\"$network\"" <<< "$networks"; then
    pass_result "$name" "$container" "$start_ms"
  else
    fail_result "$name" "attached networks: $networks" "$start_ms"
  fi
}

assert_stack_containers_running() {
  local container
  for container in "$@"; do
    assert_container_running "$container"
  done
}

assert_stack_containers_healthy() {
  local container
  for container in "$@"; do
    assert_container_healthy "$container"
  done
}
