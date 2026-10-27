#!/usr/bin/env bash
set -euo pipefail

test_authentik_server() {
  assert_container_running authentik-server
  assert_container_healthy authentik-server
}

test_authentik_worker() {
  assert_container_running authentik-worker
  assert_container_healthy authentik-worker
}
