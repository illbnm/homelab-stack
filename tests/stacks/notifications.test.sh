#!/usr/bin/env bash
_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib"; pwd)"
source "$_LIB_DIR/assert.sh"

test_notify_ntfy_running() { assert_container_running "ntfy" "ntfy should be running"; }
test_notify_ntfy_http() { assert_http_200 "http://localhost:2586" 15 "ntfy should respond"; }
test_notify_no_latest_tags() { assert_no_latest_images "$BASE_DIR/stacks/notifications" "Notifications should pin image versions"; }
