#!/usr/bin/env bash
# Stack test suite for 'monitoring'
if [[ -f "stacks/monitoring/docker-compose.yml" ]]; then
  validate_stack_static "monitoring"
fi
assert_container_running "prometheus" "Primary service 'prometheus' is running"
assert_container_healthy "prometheus" "Primary service 'prometheus' is healthy"
assert_no_errors "prometheus" "No fatal errors in 'prometheus' logs"
