#!/usr/bin/env bash
set -euo pipefail

test_adguardhome_running() { assert_container_healthy adguardhome; }
test_npm_running() { assert_container_healthy nginx-proxy-manager; }
