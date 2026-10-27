#!/usr/bin/env bash
set -euo pipefail

test_postgres_running() { assert_container_running homelab-postgres; }
test_redis_running() { assert_container_running homelab-redis; }
test_mariadb_running() { assert_container_running homelab-mariadb; }
