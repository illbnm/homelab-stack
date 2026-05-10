#!/usr/bin/env bash
# Databases Stack — Shared database layer tests
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
source "$(dirname "$SCRIPT_DIR")/lib/assert.sh"
ROOT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
if [ -f "$ROOT_DIR/.env" ]; then set -a; source "$ROOT_DIR/.env"; set +a; fi

describe "Databases"

it "PostgreSQL running"; assert_container_running "homelab-postgres"
it "PostgreSQL healthy"; assert_container_healthy "homelab-postgres"
it "Redis running"; assert_container_running "homelab-redis"
it "Redis healthy"; assert_container_healthy "homelab-redis"
it "MariaDB running"; assert_container_running "homelab-mariadb"

it "pgAdmin running"; assert_container_running "homelab-pgadmin"
it "Redis Commander running"; assert_container_running "homelab-redis-commander"

it "PostgreSQL accepts connections";
  assert_true "docker exec homelab-postgres psql -U postgres -c 'SELECT 1;' &>/dev/null"

it "Redis accepts connections";
  local resp
  resp=$(docker exec homelab-redis redis-cli -a "${REDIS_PASSWORD:-}" --no-auth-warning ping 2>/dev/null || echo "FAIL")
  assert_eq "$resp" "PONG" "redis ping failed"

it "databases network isolated (no proxy)";
  local net
  net=$(docker inspect homelab-postgres -f '{{range $k,$v := .NetworkSettings.Networks}}{{$k}} {{end}}' 2>/dev/null)
  assert_not_contains "$net" "proxy" "postgres is on proxy network!"

it "init-databases.sh exists";
  assert_true "test -x ${ROOT_DIR}/scripts/init-databases.sh"

it "backup-databases.sh exists";
  assert_true "test -x ${ROOT_DIR}/scripts/backup-databases.sh"