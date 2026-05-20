#!/usr/bin/env bash

run_sso_tests() {
  CURRENT_SUITE="sso"
  assert_stack_static_checks sso
  assert_compose_services_declared sso postgresql redis authentik-server authentik-worker
  assert_stack_containers_running authentik-postgres authentik-redis authentik-server authentik-worker
  assert_stack_containers_healthy authentik-postgres authentik-redis authentik-server
  assert_file_contains "$PROJECT_ROOT/stacks/sso/README.md" 'AUTHENTIK_BOOTSTRAP_TOKEN' "SSO docs mention bootstrap token"
  assert_container_on_network authentik-server proxy "Authentik server is attached to proxy network"
}
