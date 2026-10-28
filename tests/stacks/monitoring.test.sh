#!/usr/bin/env bash
source "$(dirname "$0")/../lib/assert.sh"

test_monitoring_compose_syntax() {
  assert_exit_code 0 $(docker compose -f stacks/observability/docker-compose.yml config --quiet 2>/dev/null; echo $?) "Observability compose syntax"
}
test_monitoring_compose_syntax
