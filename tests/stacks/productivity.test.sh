#!/usr/bin/env bash
# Productivity Stack Tests — Gitea + Vaultwarden + Outline + Stirling PDF + Excalidraw
test_gitea_running() { assert_eq "$(container_status gitea)" "running" "Gitea should be running"; }
test_gitea_api() { assert_http_200 "http://localhost:3000/api/v1/version" "Gitea API version endpoint"; }
test_vaultwarden_running() { assert_eq "$(container_status vaultwarden)" "running" "Vaultwarden should be running"; }
test_vaultwarden_api() { assert_http_status "http://localhost:80/api/accounts/prelogin" "200" "Vaultwarden prelogin endpoint"; }
test_outline_running() { assert_eq "$(container_status outline)" "running" "Outline should be running"; }
test_stirling_pdf_running() { assert_eq "$(container_status stirling-pdf)" "running" "Stirling PDF should be running"; }
test_stirling_pdf_api() { assert_http_status "http://localhost:8080" "200" "Stirling PDF web should respond"; }
test_excalidraw_running() { assert_eq "$(container_status excalidraw)" "running" "Excalidraw should be running"; }
test_gitea_on_homelab_network() {
  local net; net=$(docker inspect --format '{{range $k,$v := .NetworkSettings.Networks}}{{$k}} {{end}}' gitea 2>/dev/null || echo "")
  assert_contains "$net" "homelab" "Gitea should be on homelab network"
}