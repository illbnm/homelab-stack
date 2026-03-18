# Productivity stack tests

CURRENT_TEST="gitea_running"
assert_container_running "gitea"

CURRENT_TEST="gitea_healthy"
assert_container_healthy "gitea"

CURRENT_TEST="gitea_api"
assert_http_200 "http://localhost:3000/api/v1/version"

CURRENT_TEST="vaultwarden_running"
assert_container_running "vaultwarden"

CURRENT_TEST="vaultwarden_healthy"
assert_container_healthy "vaultwarden"

CURRENT_TEST="vaultwarden_alive"
assert_http_200 "http://localhost:80/alive"

CURRENT_TEST="outline_running"
assert_container_running "outline"

CURRENT_TEST="outline_healthy"
assert_container_healthy "outline"

CURRENT_TEST="outline_health"
assert_http_200 "http://localhost:3000/_health"

CURRENT_TEST="stirling_pdf_running"
assert_container_running "stirling-pdf"

CURRENT_TEST="stirling_pdf_healthy"
assert_container_healthy "stirling-pdf"

CURRENT_TEST="stirling_pdf_api"
assert_http_200 "http://localhost:8080/api/v1/info/status"

CURRENT_TEST="excalidraw_running"
assert_container_running "excalidraw"

CURRENT_TEST="excalidraw_healthy"
assert_container_healthy "excalidraw"
