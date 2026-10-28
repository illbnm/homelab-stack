#!/usr/bin/env bash
source "$(dirname "$0")/../lib/assert.sh"

test_productivity_compose_syntax() {
  assert_exit_code 0 $(docker compose -f stacks/productivity/docker-compose.yml config --quiet 2>/dev/null; echo $?) "Productivity compose syntax"
}
test_productivity_compose_syntax
