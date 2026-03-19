#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.."; pwd)"
source "$SCRIPT_DIR/tests/lib/assert.sh"
source "$SCRIPT_DIR/tests/lib/docker.sh"

test_postgres_running() {
  assert_container_running "homelab-postgres"
}
test_postgres_port() {
  assert_http_200 "http://localhost:5432" 3
}
test_redis_running() {
  assert_container_running "homelab-redis"
}
test_mariadb_running() {
  assert_container_running "homelab-mariadb"
}
test_databases_compose_valid() {
  assert_compose_valid "$SCRIPT_DIR/stacks/databases/docker-compose.yml"
}
