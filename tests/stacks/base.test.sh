#!/usr/bin/env bash
source "$(dirname "$0")/../lib/assert.sh"

test_base_compose_syntax() {
  assert_exit_code 0 $(docker compose -f stacks/base/docker-compose.yml config --quiet 2>/dev/null; echo $?) "Base compose syntax"
}
test_base_compose_syntax
