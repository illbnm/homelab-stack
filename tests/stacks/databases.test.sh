#!/usr/bin/env bash
source "$(dirname "$0")/../lib/assert.sh"

test_databases_compose_syntax() {
  assert_exit_code 0 $(docker compose -f stacks/databases/docker-compose.yml config --quiet 2>/dev/null; echo $?) "Databases compose syntax"
}
test_databases_compose_syntax
