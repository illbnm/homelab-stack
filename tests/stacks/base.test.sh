# Base infrastructure tests

CURRENT_TEST="traefik_running"
assert_container_running "traefik"

CURRENT_TEST="traefik_healthy"
assert_container_healthy "traefik"

CURRENT_TEST="traefik_api"
assert_http_200 "http://localhost:8080/api/version"

CURRENT_TEST="portainer_running"
assert_container_running "portainer"

CURRENT_TEST="portainer_api"
assert_http_200 "http://localhost:9000/api/status"

CURRENT_TEST="watchtower_running"
assert_container_running "watchtower"
