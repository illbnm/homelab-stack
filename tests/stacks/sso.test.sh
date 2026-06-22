test_postgresql_running() {
  assert_container_running "authentik-postgres"
  assert_container_healthy "authentik-postgres"
}

test_redis_running() {
  assert_container_running "authentik-redis"
  assert_container_healthy "authentik-redis"
}

test_authentik_server_running() {
  assert_container_running "authentik-server"
  assert_container_healthy "authentik-server"
}

test_authentik_worker_running() {
  assert_container_running "authentik-worker"
}

