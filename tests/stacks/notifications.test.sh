# Notifications stack tests

CURRENT_TEST="ntfy_running"
assert_container_running "ntfy"

CURRENT_TEST="ntfy_healthy"
assert_container_healthy "ntfy"

CURRENT_TEST="ntfy_http"
assert_http_200 "http://localhost:8080/v1/health"

CURRENT_TEST="apprise_running"
assert_container_running "apprise"

CURRENT_TEST="apprise_healthy"
assert_container_healthy "apprise"

CURRENT_TEST="apprise_http"
assert_http_200 "http://localhost:8000/status"

CURRENT_TEST="notify_script_exists"
if [[ -x "scripts/notify.sh" ]]; then
  pass
else
  fail_test "scripts/notify.sh not found or not executable"
fi
