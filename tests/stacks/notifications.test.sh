#!/usr/bin/env bash

run_notifications_tests() {
  CURRENT_SUITE="notifications"
  assert_stack_static_checks notifications
  assert_compose_services_declared notifications ntfy apprise
  assert_stack_containers_running ntfy apprise
  assert_stack_containers_healthy ntfy apprise
  assert_file_contains "$(stack_compose_file notifications)" 'ntfy' "ntfy service is configured"
  assert_container_on_network ntfy proxy "ntfy is attached to proxy network"
}
