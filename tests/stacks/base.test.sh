#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════
# Base Stack Tests — Traefik + Portainer + Watchtower
# ════════════════════════════════════════════════════════════════

test_traefik_running() {
  assert_eq "$(container_status traefik)" "running" "Traefik should be running"
}

test_traefik_healthy() {
  if container_healthy traefik; then
    return 0
  fi
  # Traefik may not have a healthcheck — check API instead
  assert_http_200 "http://localhost:8080/api/version" "Traefik API should respond"
}

test_traefik_api_version() {
  assert_http_json_key "http://localhost:8080/api/version" ".version" "Traefik API should return version"
}

test_traefik_dashboard() {
  assert_http_status "http://localhost:8080/dashboard/" "200" "Traefik dashboard should be accessible"
}

test_portainer_running() {
  assert_eq "$(container_status portainer)" "running" "Portainer should be running"
}

test_portainer_api() {
  assert_http_200 "http://localhost:9000/api/status" "Portainer API should respond"
}

test_watchtower_running() {
  assert_eq "$(container_status watchtower)" "running" "Watchtower should be running"
}

test_homelab_network_exists() {
  network_exists "homelab" "homelab network should exist"
}

test_traefik_on_homelab_network() {
  local net
  net=$(docker inspect --format '{{range $k,$v := .NetworkSettings.Networks}}{{$k}} {{end}}' traefik 2>/dev/null || echo "")
  assert_contains "$net" "homelab" "Traefik should be on homelab network"
}

test_portainer_on_homelab_network() {
  local net
  net=$(docker inspect --format '{{range $k,$v := .NetworkSettings.Networks}}{{$k}} {{end}}' portainer 2>/dev/null || echo "")
  assert_contains "$net" "homelab" "Portainer should be on homelab network"
}

test_traefik_entrypoints() {
  local result
  result=$(curl -s "http://localhost:8080/api/entrypoints" 2>/dev/null || echo "")
  assert_json_key_exists "$result" ".[0].name" "Traefik should have entrypoints configured"
}