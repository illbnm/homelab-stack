#!/usr/bin/env bash
# Stack test suite for 'media'
if [[ -f "stacks/media/docker-compose.yml" ]]; then
  validate_stack_static "media"
fi
assert_container_running "jellyfin" "Primary service 'jellyfin' is running"
assert_container_healthy "jellyfin" "Primary service 'jellyfin' is healthy"
assert_no_errors "jellyfin" "No fatal errors in 'jellyfin' logs"
