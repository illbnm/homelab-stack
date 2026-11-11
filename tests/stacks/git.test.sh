#!/usr/bin/env bash
# Stack test suite for 'git'
if [[ -f "stacks/git/docker-compose.yml" ]]; then
  validate_stack_static "git"
fi
assert_container_running "gitea" "Primary service 'gitea' is running"
assert_container_healthy "gitea" "Primary service 'gitea' is healthy"
assert_no_errors "gitea" "No fatal errors in 'gitea' logs"
