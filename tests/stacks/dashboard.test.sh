#!/usr/bin/env bash
set -euo pipefail

test_homarr_running() { assert_container_healthy homarr; }
test_homepage_running() { assert_container_healthy homepage; }
