#!/usr/bin/env bash
# Stack test suite for 'photos'
if [[ -f "stacks/photos/docker-compose.yml" ]]; then
  validate_stack_static "photos"
fi
assert_container_running "immich-server" "Primary service 'immich-server' is running"
assert_container_healthy "immich-server" "Primary service 'immich-server' is healthy"
assert_no_errors "immich-server" "No fatal errors in 'immich-server' logs"
