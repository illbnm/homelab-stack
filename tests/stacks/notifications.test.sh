#!/usr/bin/env bash
source "$(dirname "$0")/../lib/assert.sh"

test_notifications_compose_syntax() {
  assert_exit_code 0 $(docker compose -f stacks/notifications/docker-compose.yml config --quiet 2>/dev/null; echo $?) "Notifications compose syntax"
}
test_notifications_compose_syntax
