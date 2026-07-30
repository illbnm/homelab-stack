#!/usr/bin/env bash
# Notifications Stack Tests — Gotify + Apprise
test_gotify_running() { assert_eq "$(container_status gotify)" "running" "Gotify should be running"; }
test_gotify_health() { assert_http_200 "http://localhost:8080/health" "Gotify health endpoint"; }
test_gotify_api() { assert_http_status "http://localhost:8080/version" "200" "Gotify version API"; }
test_apprise_running() { assert_eq "$(container_status apprise)" "running" "Apprise should be running"; }
test_apprise_api() { assert_http_status "http://localhost:8000" "200" "Apprise API should respond"; }
test_gotify_on_homelab() {
  local net; net=$(docker inspect --format '{{range $k,$v := .NetworkSettings.Networks}}{{$k}} {{end}}' gotify 2>/dev/null || echo "")
  assert_contains "$net" "homelab" "Gotify should be on homelab network"
}