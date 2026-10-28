#!/usr/bin/env bash
source "$(dirname "$0")/../lib/assert.sh"

test_network_compose_syntax() {
  assert_exit_code 0 $(docker compose -f stacks/network/docker-compose.yml config --quiet 2>/dev/null; echo $?) "Network compose syntax"
}
test_network_compose_syntax
