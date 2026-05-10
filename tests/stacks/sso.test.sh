#!/usr/bin/env bash
# SSO Stack — Authentik integration tests
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
source "$(dirname "$SCRIPT_DIR")/lib/assert.sh"
ROOT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
if [ -f "$ROOT_DIR/.env" ]; then set -a; source "$ROOT_DIR/.env"; set +a; fi

describe "SSO (Authentik)"

it "authentik-server running"; assert_container_running "authentik-server"
it "authentik-server healthy"; assert_container_healthy "authentik-server"
it "authentik-worker running"; assert_container_running "authentik-worker"
it "authentik-postgres running"; assert_container_running "authentik-postgres"
it "authentik-redis running"; assert_container_running "authentik-redis"

it "Authentik health endpoint"; assert_http_200 "http://authentik-server:9000/-/health/ready/"
it "Authentik API accessible"; assert_http_200 "http://authentik-server:9000/api/v3/root/config/"
it "Authentik flows available"; 
  local resp
  resp=$(curl -sf http://authentik-server:9000/api/v3/flows/instances/ 2>/dev/null || echo "[]")
  assert_json_value "$resp" ".results | length > 0" "true" "no flows found"

it "PostgreSQL reachable from server";
  assert_true "docker exec authentik-server nc -z authentik-postgres 5432 2>/dev/null"

it "Redis reachable from server";
  assert_true "docker exec authentik-server nc -z authentik-redis 6379 2>/dev/null"

it "setup-authentik.sh exists and executable";
  assert_true "test -x ${ROOT_DIR}/scripts/setup-authentik.sh"