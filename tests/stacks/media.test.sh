#!/usr/bin/env bash

run_media_tests() {
  CURRENT_SUITE="media"
  assert_stack_static_checks media
  assert_compose_services_declared media jellyfin prowlarr qbittorrent radarr sonarr
  assert_stack_containers_running jellyfin prowlarr qbittorrent radarr sonarr
  assert_stack_containers_healthy jellyfin prowlarr qbittorrent radarr sonarr
  assert_file_contains "$PROJECT_ROOT/scripts/setup-media.sh" 'sonarr' "Media setup script configures Sonarr"
  assert_file_contains "$PROJECT_ROOT/scripts/setup-media.sh" 'radarr' "Media setup script configures Radarr"
}
