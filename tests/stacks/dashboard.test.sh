#!/usr/bin/env bash
# =============================================================================
# Dashboard Stack Tests — Homarr, Homepage
# =============================================================================

log_group "Dashboard"

# --- Level 1: Container health ---

DASHBOARD_CONTAINERS=(homarr homepage)

for c in "${DASHBOARD_CONTAINERS[@]}"; do
  if is_container_running "$c"; then
    assert_container_running "$c"
    assert_container_healthy "$c"
    assert_container_not_restarting "$c"
  else
    skip_test "Container '$c'" "not running"
  fi
done

# --- Level 2: HTTP endpoints ---
if [[ "${TEST_LEVEL:-99}" -ge 2 ]]; then

  test_homarr_http() {
    require_container "homarr" || return
    assert_http_ok "http://localhost:7575" "Homarr Web UI"
  }

  test_homepage_http() {
    require_container "homepage" || return
    assert_http_ok "http://localhost:3000" "Homepage Web UI"
  }

  test_homarr_http
  test_homepage_http
fi

# --- Image tags ---
for c in "${DASHBOARD_CONTAINERS[@]}"; do
  if is_container_running "$c"; then
    assert_container_image_not_latest "$c"
  fi
done
