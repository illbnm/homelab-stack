#!/usr/bin/env bash
source "$(dirname "$0")/../lib/assert.sh"

test_media_compose_syntax() {
  assert_exit_code 0 $(docker compose -f stacks/media/docker-compose.yml config --quiet 2>/dev/null; echo $?) "Media compose syntax"
}
test_media_compose_syntax
