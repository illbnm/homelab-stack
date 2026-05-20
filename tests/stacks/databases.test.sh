#!/usr/bin/env bash

run_databases_tests() {
  CURRENT_SUITE="databases"
  assert_stack_static_checks databases
  assert_compose_services_declared databases postgres redis mariadb
  assert_stack_containers_running homelab-postgres homelab-redis homelab-mariadb
  assert_stack_containers_healthy homelab-postgres homelab-redis homelab-mariadb
  assert_container_on_network homelab-postgres databases "PostgreSQL is attached to databases network"
  assert_container_on_network homelab-redis databases "Redis is attached to databases network"
  assert_container_on_network homelab-mariadb databases "MariaDB is attached to databases network"
}
