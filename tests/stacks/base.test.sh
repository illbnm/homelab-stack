#!/usr/bin/env bash
# Stack test suite for 'base'
if [[ -f "stacks/base/docker-compose.yml" ]]; then
  validate_stack_static "base"
fi
assert_container_running "traefik" "Primary service 'traefik' is running"
assert_container_healthy "traefik" "Primary service 'traefik' is healthy"
assert_no_errors "traefik" "No fatal errors in 'traefik' logs"
