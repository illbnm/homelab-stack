#!/usr/bin/env bash
# Stack test suite for 'sso'
if [[ -f "stacks/sso/docker-compose.yml" ]]; then
  validate_stack_static "sso"
fi
assert_container_running "authentik-server" "Primary service 'authentik-server' is running"
assert_container_healthy "authentik-server" "Primary service 'authentik-server' is healthy"
assert_no_errors "authentik-server" "No fatal errors in 'authentik-server' logs"
