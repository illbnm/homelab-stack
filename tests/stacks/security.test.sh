#!/usr/bin/env bash
# Stack test suite for 'security'
if [[ -f "stacks/security/docker-compose.yml" ]]; then
  validate_stack_static "security"
fi
assert_container_running "vaultwarden" "Primary service 'vaultwarden' is running"
assert_container_healthy "vaultwarden" "Primary service 'vaultwarden' is healthy"
assert_no_errors "vaultwarden" "No fatal errors in 'vaultwarden' logs"
