#!/usr/bin/env bash
# Stack test suite for 'cloud'
if [[ -f "stacks/cloud/docker-compose.yml" ]]; then
  validate_stack_static "cloud"
fi
assert_container_running "nextcloud" "Primary service 'nextcloud' is running"
assert_container_healthy "nextcloud" "Primary service 'nextcloud' is healthy"
assert_no_errors "nextcloud" "No fatal errors in 'nextcloud' logs"
