# Media stack tests

CURRENT_TEST="jellyfin_running"
assert_container_running "jellyfin"

CURRENT_TEST="jellyfin_healthy"
assert_container_healthy "jellyfin"

CURRENT_TEST="jellyfin_http"
assert_http_200 "http://localhost:8096/health"

CURRENT_TEST="sonarr_running"
assert_container_running "sonarr"

CURRENT_TEST="sonarr_healthy"
assert_container_healthy "sonarr"

CURRENT_TEST="sonarr_http"
assert_http_200 "http://localhost:8989/ping"

CURRENT_TEST="radarr_running"
assert_container_running "radarr"

CURRENT_TEST="radarr_healthy"
assert_container_healthy "radarr"

CURRENT_TEST="radarr_http"
assert_http_200 "http://localhost:7878/ping"

CURRENT_TEST="prowlarr_running"
assert_container_running "prowlarr"

CURRENT_TEST="prowlarr_healthy"
assert_container_healthy "prowlarr"

CURRENT_TEST="prowlarr_http"
assert_http_200 "http://localhost:9696/ping"

CURRENT_TEST="qbittorrent_running"
assert_container_running "qbittorrent"

CURRENT_TEST="qbittorrent_healthy"
assert_container_healthy "qbittorrent"

CURRENT_TEST="qbittorrent_api"
assert_http_200 "http://localhost:8080/api/v2/app/version"

CURRENT_TEST="jellyseerr_running"
assert_container_running "jellyseerr"

CURRENT_TEST="jellyseerr_healthy"
assert_container_healthy "jellyseerr"
