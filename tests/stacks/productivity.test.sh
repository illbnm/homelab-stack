#!/usr/bin/env bash

run_productivity_tests() {
  CURRENT_SUITE="productivity"
  assert_stack_static_checks productivity
  assert_compose_services_declared productivity gitea vaultwarden outline bookstack
  assert_stack_containers_running gitea vaultwarden outline bookstack
  assert_stack_containers_healthy gitea vaultwarden outline bookstack
  assert_file_contains "$(stack_compose_file productivity)" 'AUTHENTIK_DOMAIN' "Productivity stack has SSO configuration"
  assert_container_on_network gitea proxy "Gitea is attached to proxy network"
}
