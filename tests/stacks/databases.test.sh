test_postgres_running() {
  assert_container_running "homelab-postgres"
  assert_container_healthy "homelab-postgres"
}

test_redis_running() {
  assert_container_running "homelab-redis"
  assert_container_healthy "homelab-redis"
}

test_mariadb_running() {
  assert_container_running "homelab-mariadb"
  assert_container_healthy "homelab-mariadb"
}

test_pgadmin_running() {
  assert_container_running "homelab-pgadmin"
}

test_redis_commander_running() {
  assert_container_running "homelab-redis-commander"
}

