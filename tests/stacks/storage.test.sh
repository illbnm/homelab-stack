#!/usr/bin/env bash
source "$(dirname "$0")/../lib/assert.sh"

test_storage_compose_syntax() {
  assert_exit_code 0 $(docker compose -f stacks/storage/docker-compose.yml config --quiet 2>/dev/null; echo $?) "Storage compose syntax"
}
test_storage_compose_syntax
