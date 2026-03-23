#!/usr/bin/env bash
_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib"; pwd)"
source "$_LIB_DIR/assert.sh"

test_productivity_gitea_running() { assert_container_running "gitea" "Gitea should be running"; }
test_productivity_gitea_http() { assert_http_200 "http://localhost:3001" 15 "Gitea should respond"; }
test_productivity_vaultwarden_running() { assert_container_running "vaultwarden" "Vaultwarden should be running"; }
test_productivity_vaultwarden_http() { assert_http_200 "http://localhost:8080" 15 "Vaultwarden should respond"; }
test_productivity_no_latest_tags() { assert_no_latest_images "$BASE_DIR/stacks/productivity" "Productivity stack should pin image versions"; }
