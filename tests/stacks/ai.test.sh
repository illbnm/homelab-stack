#!/usr/bin/env bash
source "$(dirname "$0")/../lib/assert.sh"

test_ai_compose_syntax() {
  assert_exit_code 0 $(docker compose -f stacks/ai/docker-compose.yml config --quiet 2>/dev/null; echo $?) "AI compose syntax"
}
test_ai_compose_syntax
