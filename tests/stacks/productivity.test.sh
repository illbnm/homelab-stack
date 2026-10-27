#!/usr/bin/env bash
set -euo pipefail

test_gitea_running() { assert_container_healthy gitea; }
test_vaultwarden_running() { assert_container_healthy vaultwarden; }
test_outline_running() { assert_container_healthy outline; }
test_bookstack_running() { assert_container_healthy bookstack; }
