#!/usr/bin/env bash
source "$(dirname "$0")/../lib/assert.sh"

test_sso_compose_syntax() {
  assert_exit_code 0 $(docker compose -f stacks/sso/docker-compose.yml config --quiet 2>/dev/null; echo $?) "SSO compose syntax"
}
test_sso_compose_syntax
