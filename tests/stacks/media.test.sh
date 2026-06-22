test_jellyfin_running() {
  assert_container_running "jellyfin"
  assert_container_healthy "jellyfin"
}

test_qbittorrent_running() {
  assert_container_running "qbittorrent"
  assert_container_healthy "qbittorrent"
}

test_sonarr_running() {
  assert_container_running "sonarr"
  assert_container_healthy "sonarr"
}

test_radarr_running() {
  assert_container_running "radarr"
  assert_container_healthy "radarr"
}

test_prowlarr_running() {
  assert_container_running "prowlarr"
  assert_container_healthy "prowlarr"
}

test_jellyseerr_running() {
  assert_container_running "jellyseerr"
  assert_container_healthy "jellyseerr"
}

