# SSO stack tests

CURRENT_TEST="authentik_server_running"
assert_container_running "authentik-server"

CURRENT_TEST="authentik_server_healthy"
assert_container_healthy "authentik-server"

CURRENT_TEST="authentik_health"
assert_http_200 "http://localhost:9000/-/health/live/"

CURRENT_TEST="authentik_worker_running"
assert_container_running "authentik-worker"

CURRENT_TEST="authentik_api"
local api_result=$(curl -sf "http://localhost:9000/api/v3/root/config/" 2>/dev/null || echo "{}")
assert_contains "$api_result" "error_reporting" "Authentik API responds"
