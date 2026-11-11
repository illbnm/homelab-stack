#!/usr/bin/env bash
# Stack test suite for 'network'
if [[ -f "stacks/network/docker-compose.yml" ]]; then
  validate_stack_static "network"
fi
assert_container_running "adguardhome" "Primary service 'adguardhome' is running"
assert_container_healthy "adguardhome" "Primary service 'adguardhome' is healthy"
assert_no_errors "adguardhome" "No fatal errors in 'adguardhome' logs"
