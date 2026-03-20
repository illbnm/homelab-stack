#!/bin/bash

# Media stack integration tests
# Tests for Plex, Jellyfin, qBittorrent, Sonarr, Radarr, Prowlarr, Overseerr

source "$(dirname "$0")/../lib/assert.sh"
source "$(dirname "$0")/../lib/docker.sh"

STACK_NAME="media"
COMPOSE_FILE="stacks/media/docker-compose.yml"

setup_media_tests() {
    echo "Setting up media stack tests..."
    # Ensure media stack is running
    if ! docker compose -f "$COMPOSE_FILE" ps | grep -q "Up"; then
        echo "Starting media stack for testing..."
        docker compose -f "$COMPOSE_FILE" up -d
        sleep 30  # Wait for services to initialize
    fi
}

test_plex_running() {
    echo "Testing Plex..."
    assert_container_running "plex"
    assert_container_healthy "plex"
    assert_http_200 "http://localhost:32400/web"
    assert_port_open 32400
}

test_jellyfin_running() {
    echo "Testing Jellyfin..."
    assert_container_running "jellyfin"
    assert_container_healthy "jellyfin"
    assert_http_200 "http://localhost:8096"
    assert_port_open 8096
}

test_qbittorrent_running() {
    echo "Testing qBittorrent..."
    assert_container_running "qbittorrent"
    assert_container_healthy "qbittorrent"
    assert_http_200 "http://localhost:8080"
    assert_port_open 8080
}

test_sonarr_running() {
    echo "Testing Sonarr..."
    assert_container_running "sonarr"
    assert_container_healthy "sonarr"
    assert_http_200 "http://localhost:8989"
    assert_port_open 8989
}

test_radarr_running() {
    echo "Testing Radarr..."
    assert_container_running "radarr"
    assert_container_healthy "radarr"
    assert_http_200 "http://localhost:7878"
    assert_port_open 7878
}

test_prowlarr_running() {
    echo "Testing Prowlarr..."
    assert_container_running "prowlarr"
    assert_container_healthy "prowlarr"
    assert_http_200 "http://localhost:9696"
    assert_port_open 9696
}

test_overseerr_running() {
    echo "Testing Overseerr..."
    assert_container_running "overseerr"
    assert_container_healthy "overseerr"
    assert_http_200 "http://localhost:5055"
    assert_port_open 5055
}

test_media_volumes() {
    echo "Testing media volumes..."

    # Check if media directories exist
    assert_volume_exists "media_plex_config"
    assert_volume_exists "media_jellyfin_config"
    assert_volume_exists "media_qbittorrent_config"
    assert_volume_exists "media_sonarr_config"
    assert_volume_exists "media_radarr_config"
    assert_volume_exists "media_prowlarr_config"
    assert_volume_exists "media_overseerr_config"

    # Check bind mounts for media storage
    if [ -d "/media" ]; then
        assert_directory_accessible "/media/movies"
        assert_directory_accessible "/media/tv"
        assert_directory_accessible "/media/downloads"
    fi
}

test_media_network() {
    echo "Testing media network connectivity..."

    # Test internal communication between services
    assert_container_can_resolve "sonarr" "prowlarr"
    assert_container_can_resolve "radarr" "prowlarr"
    assert_container_can_resolve "overseerr" "sonarr"
    assert_container_can_resolve "overseerr" "radarr"
}

test_media_api_endpoints() {
    echo "Testing media service API endpoints..."

    # Test API endpoints (may return 401 without auth, but should be reachable)
    assert_http_response "http://localhost:8989/api/v3/system/status" 401
    assert_http_response "http://localhost:7878/api/v3/system/status" 401
    assert_http_response "http://localhost:9696/api/v1/system/status" 401

    # Overseerr API
    assert_http_response "http://localhost:5055/api/v1/status" 200
}

test_media_configuration() {
    echo "Testing media service configurations..."

    # Check if config files were created
    assert_file_in_container "sonarr" "/config/config.xml"
    assert_file_in_container "radarr" "/config/config.xml"
    assert_file_in_container "prowlarr" "/config/config.xml"

    # Check Plex database
    assert_file_in_container "plex" "/config/Library/Application Support/Plex Media Server/Plug-in Support/Databases/com.plexapp.plugins.library.db"
}

run_media_tests() {
    echo "Running media stack tests..."

    setup_media_tests

    test_plex_running
    test_jellyfin_running
    test_qbittorrent_running
    test_sonarr_running
    test_radarr_running
    test_prowlarr_running
    test_overseerr_running

    test_media_volumes
    test_media_network
    test_media_api_endpoints
    test_media_configuration

    echo "Media stack tests completed!"
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_media_tests
fi
