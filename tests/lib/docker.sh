#!/usr/bin/env bash
# ==============================================================================
# tests/lib/docker.sh — Docker Compose lifecycle helpers for stack testing
# ==============================================================================

stack_compose_file() {
  local stack="$1"
  echo "stacks/${stack}/docker-compose.yml"
}

validate_stack_static() {
  local stack="$1"
  local compose_file
  compose_file="$(stack_compose_file "$stack")"
  local env_file="stacks/${stack}/.env.example"

  assert_file_contains "$compose_file" "services:" "Stack '${stack}' defines services"
  assert_file_contains "$compose_file" "healthcheck:" "Stack '${stack}' defines healthchecks"
  assert_no_latest_images "$compose_file" "Stack '${stack}' pins all container image versions"
  if [[ -f "$env_file" ]]; then
    assert_not_empty "$(cat "$env_file")" "Stack '${stack}' provides non-empty .env.example"
  fi
}
