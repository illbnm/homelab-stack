#!/usr/bin/env bash
# SSO Stack Tests — Authentik Server + Worker + PostgreSQL + Redis
test_authentik_postgres_running() { assert_eq "$(container_status authentik-postgres)" "running" "Authentik PostgreSQL should be running"; }
test_authentik_postgres_healthy() {
  if container_healthy authentik-postgres; then return 0; fi
  return 1
}
test_authentik_redis_running() { assert_eq "$(container_status authentik-redis)" "running" "Authentik Redis should be running"; }
test_authentik_redis_healthy() {
  if container_healthy authentik-redis; then return 0; fi
  return 1
}
test_authentik_server_running() { assert_eq "$(container_status authentik-server)" "running" "Authentik server should be running"; }
test_authentik_server_health() { assert_http_200 "http://localhost:9000/-/health/live/" "Authentik server health endpoint"; }
test_authentik_worker_running() { assert_eq "$(container_status authentik-worker)" "running" "Authentik worker should be running"; }
test_authentik_server_on_homelab() {
  local net; net=$(docker inspect --format '{{range $k,$v := .NetworkSettings.Networks}}{{$k}} {{end}}' authentik-server 2>/dev/null || echo "")
  assert_contains "$net" "homelab" "Authentik server should be on homelab network"
}
test_authentik_api_users() {
  assert_http_status "http://localhost:9000/api/v3/core/users/?page_size=1" "200" "Authentik users API"
}