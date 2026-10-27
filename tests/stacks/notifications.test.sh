#!/usr/bin/env bash
set -euo pipefail

test_ntfy_running() { assert_container_healthy ntfy; }
test_apprise_running() { assert_container_healthy apprise; }
