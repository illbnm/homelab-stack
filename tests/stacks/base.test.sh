#!/usr/bin/env bash

run_base_tests() {
  CURRENT_SUITE="base"
  assert_stack_static_checks base
  assert_compose_services_declared base traefik portainer watchtower
  assert_file_contains "$PROJECT_ROOT/config/traefik/traefik.yml" 'ping:' "Traefik ping is configured"
  assert_stack_containers_running traefik portainer watchtower
  assert_stack_containers_healthy traefik portainer watchtower
  assert_container_on_network traefik proxy "Traefik is attached to proxy network"
  assert_container_on_network portainer proxy "Portainer is attached to proxy network"
}
