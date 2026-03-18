#!/usr/bin/env bash
# =============================================================================
# Databases Stack Tests — PostgreSQL + Redis + MariaDB + pgAdmin + Redis Commander
# =============================================================================

# --- Level 1: Container Health ---

test_databases_postgres_running() {
  assert_container_running "homelab-postgres"
}

test_databases_postgres_healthy() {
  assert_container_healthy "homelab-postgres" 60
}

test_databases_redis_running() {
  assert_container_running "homelab-redis"
}

test_databases_redis_healthy() {
  assert_container_healthy "homelab-redis" 60
}

test_databases_mariadb_running() {
  assert_container_running "homelab-mariadb"
}

test_databases_mariadb_healthy() {
  assert_container_healthy "homelab-mariadb" 60
}

test_databases_pgadmin_running() {
  assert_container_running "homelab-pgadmin"
}

test_databases_pgadmin_healthy() {
  assert_container_healthy "homelab-pgadmin" 60
}

test_databases_redis_commander_running() {
  assert_container_running "homelab-redis-commander"
}

test_databases_redis_commander_healthy() {
  assert_container_healthy "homelab-redis-commander" 60
}

# --- Level 1: Configuration ---

test_databases_compose_syntax() {
  local output
  output=$(compose_config_valid "stacks/databases/docker-compose.yml" 2>&1)
  _LAST_EXIT_CODE=$?
  assert_exit_code 0 "databases compose syntax invalid: ${output}"
}

test_databases_no_latest_tags() {
  assert_no_latest_images "stacks/databases/"
}

test_databases_network_exists() {
  assert_network_exists "databases"
}

# --- Level 2: PostgreSQL ---

test_databases_pg_accepts_connections() {
  assert_docker_exec "homelab-postgres" "pg_isready -U postgres" "accepting connections"
}

test_databases_pg_nextcloud_db() {
  assert_docker_exec "homelab-postgres" \
    "psql -U postgres -tAc \"SELECT 1 FROM pg_database WHERE datname='nextcloud'\"" "1"
}

test_databases_pg_gitea_db() {
  assert_docker_exec "homelab-postgres" \
    "psql -U postgres -tAc \"SELECT 1 FROM pg_database WHERE datname='gitea'\"" "1"
}

test_databases_pg_outline_db() {
  assert_docker_exec "homelab-postgres" \
    "psql -U postgres -tAc \"SELECT 1 FROM pg_database WHERE datname='outline'\"" "1"
}

test_databases_pg_authentik_db() {
  assert_docker_exec "homelab-postgres" \
    "psql -U postgres -tAc \"SELECT 1 FROM pg_database WHERE datname='authentik'\"" "1"
}

test_databases_pg_grafana_db() {
  assert_docker_exec "homelab-postgres" \
    "psql -U postgres -tAc \"SELECT 1 FROM pg_database WHERE datname='grafana'\"" "1"
}

test_databases_pg_vaultwarden_db() {
  assert_docker_exec "homelab-postgres" \
    "psql -U postgres -tAc \"SELECT 1 FROM pg_database WHERE datname='vaultwarden'\"" "1"
}

test_databases_pg_bookstack_db() {
  assert_docker_exec "homelab-postgres" \
    "psql -U postgres -tAc \"SELECT 1 FROM pg_database WHERE datname='bookstack'\"" "1"
}

test_databases_pg_uuid_ossp() {
  assert_docker_exec "homelab-postgres" \
    "psql -U postgres -d outline -tAc \"SELECT extname FROM pg_extension WHERE extname='uuid-ossp'\"" "uuid-ossp"
}

# --- Level 2: Redis ---

test_databases_redis_ping() {
  # Extract password from redis-server --requirepass in container cmd
  local redis_pass
  redis_pass=$(docker inspect --format='{{json .Config.Cmd}}' homelab-redis 2>/dev/null | \
    jq -r '. as $a | range(length) | select($a[.] == "--requirepass") | $a[. + 1] // empty') || redis_pass="test"
  assert_docker_exec "homelab-redis" \
    "redis-cli -a '${redis_pass}' --no-auth-warning PING" "PONG"
}

test_databases_redis_multi_db() {
  local redis_pass
  redis_pass=$(docker inspect --format='{{json .Config.Cmd}}' homelab-redis 2>/dev/null | \
    jq -r '. as $a | range(length) | select($a[.] == "--requirepass") | $a[. + 1] // empty') || redis_pass="test"
  assert_docker_exec "homelab-redis" \
    "redis-cli -a '${redis_pass}' --no-auth-warning CONFIG GET databases" "16"
}

# --- Level 2: MariaDB ---

test_databases_mariadb_bookstack_db() {
  assert_docker_exec "homelab-mariadb" \
    "mariadb -u root -p\${MARIADB_ROOT_PASSWORD:-test} -e 'SHOW DATABASES' 2>/dev/null" "bookstack"
}

# --- Level 2: Admin UIs ---

test_databases_pgadmin_http() {
  assert_http_200 "http://$(get_container_ip homelab-pgadmin):80/misc/ping" 30
}

test_databases_redis_commander_http() {
  assert_http_200 "http://$(get_container_ip homelab-redis-commander):8081/" 30
}

# --- Level 3: Network Isolation ---

test_databases_postgres_not_on_proxy() {
  assert_container_not_on_network "homelab-postgres" "proxy"
}

test_databases_redis_not_on_proxy() {
  assert_container_not_on_network "homelab-redis" "proxy"
}

test_databases_mariadb_not_on_proxy() {
  assert_container_not_on_network "homelab-mariadb" "proxy"
}

test_databases_pgadmin_on_proxy() {
  assert_container_on_network "homelab-pgadmin" "proxy"
}

test_databases_redis_commander_on_proxy() {
  assert_container_on_network "homelab-redis-commander" "proxy"
}

# --- Level 3: Port Exposure ---

test_databases_postgres_no_host_port() {
  # PostgreSQL should NOT be mapped to host ports (internal only)
  local ports
  ports=$(docker port homelab-postgres 2>/dev/null)
  if [[ -z "${ports}" ]]; then
    _pass
  else
    _fail "PostgreSQL has host-mapped ports (should be internal only): ${ports}"
  fi
}

test_databases_redis_no_host_port() {
  # Redis should NOT be mapped to host ports (internal only)
  local ports
  ports=$(docker port homelab-redis 2>/dev/null)
  if [[ -z "${ports}" ]]; then
    _pass
  else
    _fail "Redis has host-mapped ports (should be internal only): ${ports}"
  fi
}

test_databases_mariadb_no_host_port() {
  # MariaDB should NOT be mapped to host ports (internal only)
  local ports
  ports=$(docker port homelab-mariadb 2>/dev/null)
  if [[ -z "${ports}" ]]; then
    _pass
  else
    _fail "MariaDB has host-mapped ports (should be internal only): ${ports}"
  fi
}
