#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Docker Utility Library
# =============================================================================
set -uo pipefail

# Load assert if not already loaded
[[ -z "${_A_NC:-}" ]] && source "$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)/assert.sh"

# ---------------------------------------------------------------------------
# Container checks
# ---------------------------------------------------------------------------
assert_container_running() {
  local name="$1"
  begin_test "container:$name:running"
  if docker ps --format '{{.Names}}' 2>/dev/null | grep -qx "$name"; then
    assert_pass "running"
  else
    assert_fail "not running"
  fi
}

assert_container_healthy() {
  local name="$1"
  begin_test "container:$name:healthy"
  local health
  health=$(docker inspect --format '{{.State.Health.Status}}' "$name" 2>/dev/null || echo "no-healthcheck")
  if [[ "$health" == "healthy" ]]; then
    assert_pass "healthy"
  elif [[ "$health" == "no-healthcheck" ]]; then
    assert_pass "no healthcheck configured (running)"
  else
    assert_fail "status=$health"
  fi
}

assert_container_restarting() {
  local name="$1" max="${2:-5}"
  begin_test "container:$name:restart_count"
  local count
  count=$(docker inspect --format '{{.RestartCount}}' "$name" 2>/dev/null || echo "0")
  if [[ "$count" -le "$max" ]]; then
    assert_pass "restart_count=$count (<= $max)"
  else
    assert_fail "restart_count=$count (> $max)"
  fi
}

assert_container_label() {
  local name="$1" label="$2" expected="$3"
  begin_test "container:$name:label:$label"
  local val
  val=$(docker inspect --format "{{index .Config.Labels \"$label\"}}" "$name" 2>/dev/null || echo "")
  if [[ "$val" == "$expected" ]]; then
    assert_pass "$label=$val"
  elif [[ -z "$expected" && -n "$val" ]]; then
    assert_pass "$label exists"
  else
    assert_fail "$label='$val' (expected '$expected')"
  fi
}

assert_container_image() {
  local name="$1" expected="$2"
  begin_test "container:$name:image"
  local img
  img=$(docker inspect --format '{{.Config.Image}}' "$name" 2>/dev/null || echo "")
  if [[ "$img" == "$expected" ]]; then
    assert_pass "image=$img"
  else
    assert_fail "image=$img (expected $expected)"
  fi
}

assert_container_not_latest() {
  local name="$1"
  begin_test "container:$name:no_latest_tag"
  local img
  img=$(docker inspect --format '{{.Config.Image}}' "$name" 2>/dev/null || echo "")
  if [[ "$img" == *":latest" ]] || [[ "$img" != *":"* ]]; then
    assert_fail "uses 'latest' tag: $img"
  else
    assert_pass "pinned version: $img"
  fi
}

assert_container_restart_policy() {
  local name="$1" expected="${2:-unless-stopped}"
  begin_test "container:$name:restart_policy"
  local policy
  policy=$(docker inspect --format '{{.HostConfig.RestartPolicy.Name}}' "$name" 2>/dev/null || echo "")
  if [[ "$policy" == "$expected" ]]; then
    assert_pass "policy=$policy"
  else
    assert_fail "policy=$policy (expected $expected)"
  fi
}

# ---------------------------------------------------------------------------
# HTTP checks
# ---------------------------------------------------------------------------
assert_http_200() {
  local url="$1" name="${2:-$1}"
  begin_test "http:$name"
  local code
  code=$(curl -sf -o /dev/null -w '%{http_code}' --connect-timeout 5 --max-time 10 "$url" 2>/dev/null || echo "000")
  if [[ "$code" =~ ^[23] ]]; then
    assert_pass "HTTP $code"
  else
    assert_fail "HTTP $code"
  fi
}

assert_http_status() {
  local url="$1" expected="$2" name="${3:-$1}"
  begin_test "http:$name:status"
  local code
  code=$(curl -sf -o /dev/null -w '%{http_code}' --connect-timeout 5 --max-time 10 "$url" 2>/dev/null || echo "000")
  if [[ "$code" == "$expected" ]]; then
    assert_pass "HTTP $code"
  else
    assert_fail "HTTP $code (expected $expected)"
  fi
}

assert_http_body_contains() {
  local url="$1" needle="$2" name="${3:-$1}"
  begin_test "http:$name:body"
  local body
  body=$(curl -sf --connect-timeout 5 --max-time 10 "$url" 2>/dev/null || echo "")
  if [[ "$body" == *"$needle"* ]]; then
    assert_pass "body contains '$needle'"
  else
    assert_fail "body missing '$needle'"
  fi
}

assert_http_json_field() {
  local url="$1" field="$2" expected="$3" name="${4:-$1}"
  begin_test "http:$name:json:$field"
  local body val
  body=$(curl -sf --connect-timeout 5 --max-time 10 "$url" 2>/dev/null || echo "{}")
  val=$(echo "$body" | python3 -c "import sys,json; print(json.load(sys.stdin).get('$field',''))" 2>/dev/null || echo "")
  if [[ "$val" == "$expected" ]]; then
    assert_pass "$field=$val"
  else
    assert_fail "$field='$val' (expected '$expected')"
  fi
}

# ---------------------------------------------------------------------------
# Port checks
# ---------------------------------------------------------------------------
assert_port_open() {
  local host="${1:-localhost}" port="$2" name="${3:-$host:$port}"
  begin_test "port:$name"
  if nc -z -w3 "$host" "$port" 2>/dev/null; then
    assert_pass "port $port open"
  else
    assert_fail "port $port closed"
  fi
}

assert_port_closed() {
  local host="${1:-localhost}" port="$2" name="${3:-$host:$port}"
  begin_test "port:$name:closed"
  if nc -z -w3 "$host" "$port" 2>/dev/null; then
    assert_fail "port $port unexpectedly open"
  else
    assert_pass "port $port closed"
  fi
}

# ---------------------------------------------------------------------------
# Network checks
# ---------------------------------------------------------------------------
assert_network_exists() {
  local net="$1"
  begin_test "network:$net"
  if docker network inspect "$net" &>/dev/null; then
    assert_pass "exists"
  else
    assert_fail "does not exist"
  fi
}

assert_container_in_network() {
  local container="$1" network="$2"
  begin_test "network:$container:in:$network"
  local nets
  nets=$(docker inspect --format '{{range $k,$v := .NetworkSettings.Networks}}{{$k}} {{end}}' "$container" 2>/dev/null || echo "")
  if [[ "$nets" == *"$network"* ]]; then
    assert_pass "in $network"
  else
    assert_fail "not in $network (has: $nets)"
  fi
}

# ---------------------------------------------------------------------------
# Volume checks
# ---------------------------------------------------------------------------
assert_volume_exists() {
  local vol="$1"
  begin_test "volume:$vol"
  if docker volume inspect "$vol" &>/dev/null; then
    assert_pass "exists"
  else
    assert_fail "does not exist"
  fi
}

# ---------------------------------------------------------------------------
# Docker Compose
# ---------------------------------------------------------------------------
assert_compose_valid() {
  local file="$1" name="${2:-$1}"
  begin_test "compose:$name:syntax"
  if docker compose -f "$file" config --quiet 2>/dev/null; then
    assert_pass "valid"
  else
    assert_fail "invalid syntax"
  fi
}

assert_compose_services_running() {
  local file="$1" name="${2:-$1}"
  begin_test "compose:$name:all_running"
  local running stopped
  running=$(docker compose -f "$file" ps --status running -q 2>/dev/null | wc -l)
  stopped=$(docker compose -f "$file" ps --status exited -q 2>/dev/null | wc -l)
  if [[ "$stopped" -eq 0 && "$running" -gt 0 ]]; then
    assert_pass "$running services running"
  else
    assert_fail "$running running, $stopped stopped"
  fi
}

# ---------------------------------------------------------------------------
# Wait helpers
# ---------------------------------------------------------------------------
wait_for_container() {
  local name="$1" timeout="${2:-60}"
  local elapsed=0
  while [[ $elapsed -lt $timeout ]]; do
    local health
    health=$(docker inspect --format '{{.State.Health.Status}}' "$name" 2>/dev/null || echo "not-found")
    [[ "$health" == "healthy" ]] && return 0
    [[ "$health" == "no-healthcheck" ]] && docker ps --format '{{.Names}}' 2>/dev/null | grep -qx "$name" && return 0
    sleep 2
    elapsed=$(( elapsed + 2 ))
  done
  return 1
}

wait_for_http() {
  local url="$1" timeout="${2:-60}"
  local elapsed=0
  while [[ $elapsed -lt $timeout ]]; do
    local code
    code=$(curl -sf -o /dev/null -w '%{http_code}' --connect-timeout 3 --max-time 5 "$url" 2>/dev/null || echo "000")
    [[ "$code" =~ ^[23] ]] && return 0
    sleep 2
    elapsed=$(( elapsed + 2 ))
  done
  return 1
}
