#!/usr/bin/env bash

run_network_tests() {
  CURRENT_SUITE="network"
  assert_stack_static_checks network
  assert_compose_services_declared network adguardhome nginx-proxy-manager
  assert_stack_containers_running adguardhome nginx-proxy-manager
  assert_stack_containers_healthy adguardhome nginx-proxy-manager
  assert_file_contains "$(stack_compose_file network)" '53:53/tcp' "AdGuard DNS TCP port is declared"
  assert_file_contains "$(stack_compose_file network)" '53:53/udp' "AdGuard DNS UDP port is declared"
}
