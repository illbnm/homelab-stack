#!/usr/bin/env bash

run_dashboard_tests() {
  CURRENT_SUITE="dashboard"
  assert_stack_static_checks dashboard
  assert_compose_services_declared dashboard homarr homepage
  assert_stack_containers_running homarr homepage
  assert_stack_containers_healthy homarr homepage
  assert_container_on_network homarr proxy "Homarr is attached to proxy network"
  assert_container_on_network homepage proxy "Homepage is attached to proxy network"
}
