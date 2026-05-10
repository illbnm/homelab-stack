#!/usr/bin/env bash
# Notifications Stack — ntfy, Gotify, Apprise tests
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
source "$(dirname "$SCRIPT_DIR")/lib/assert.sh"
ROOT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"

describe "Notifications"

it "ntfy running"; assert_container_running "ntfy"
it "ntfy healthy"; assert_container_healthy "ntfy"
it "ntfy health endpoint"; assert_http_200 "http://ntfy:80/v1/health"

it "gotify running"; assert_container_running "gotify"
it "gotify health endpoint"; assert_http_200 "http://gotify:80/"

it "apprise running"; assert_container_running "apprise"
it "apprise health endpoint"; assert_http_200 "http://apprise:8000/"

it "ntfy publish endpoint accepts POST";
  local resp
  resp=$(curl -s -o /dev/null -w "%{http_code}" -d "test" http://ntfy:80/test-topic 2>/dev/null || echo "000")
  assert_contains "200 403" "$resp" "unexpected HTTP $resp"

it "notify.sh exists and executable";
  assert_true "test -x ${ROOT_DIR}/scripts/notify.sh"

it "ntfy server.yml config exists";
  assert_file_exists "${ROOT_DIR}/config/ntfy/server.yml"