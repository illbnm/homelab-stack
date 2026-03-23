#!/usr/bin/env bash
_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib"; pwd)"
source "$_LIB_DIR/assert.sh"

test_network_adguard_running() { assert_container_running "adguardhome" "AdGuard Home should be running"; }
test_network_adguard_http() { assert_http_200 "http://localhost:3000" 15 "AdGuard Home should respond"; }
test_network_npm_running() { assert_container_running "nginx-proxy-manager" "NPM should be running"; }
test_network_wireguard_running() { assert_container_running "wg-easy" "WireGuard Easy should be running"; }
test_network_wireguard_port() { assert_port_open "localhost" 51820 "WireGuard port 51820"; }
test_network_no_latest_tags() { assert_no_latest_images "$BASE_DIR/stacks/network" "Network stack should pin image versions"; }
