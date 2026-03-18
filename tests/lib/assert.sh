#!/bin/bash

assert_eq() {
  local actual="$1"
  local expected="$2"
  local msg="${3:-Expected '$expected' but got '$actual'}"
  if [ "$actual" != "$expected" ]; then
    echo "❌ FAIL: $msg"
    exit 1
  fi
}

assert_not_empty() {
  local value="$1"
  local msg="${2:-Expected non-empty value}"
  if [ -z "$value" ]; then
    echo "❌ FAIL: $msg"
    exit 1
  fi
}

assert_exit_code() {
  local code="$1"
  local msg="${2:-Expected exit code 0}"
  if [ "$code" -ne 0 ]; then
    echo "❌ FAIL: $msg"
    exit 1
  fi
}

assert_container_running() {
  local name="$1"
  if ! docker ps --format '{{.Names}}' | grep -q "^$name$"; then
    echo "❌ FAIL: Container '$name' is not running"
    exit 1
  fi
}

assert_container_healthy() {
  local name="$1"
  local timeout=60
  local start_time=$(date +%s)
  while [ $(( $(date +%s) - start_time )) -lt $timeout ]; do
    if docker inspect --format '{{.State.Health.Status}}' "$name" 2>/dev/null | grep -q "healthy"; then
      return
    fi
    sleep 1
  done
  echo "❌ FAIL: Container '$name' is not healthy"
  exit 1
}

assert_http_200() {
  local url="$1"
  local timeout="${2:-30}"
  if ! curl -s -o /dev/null -w "%{http_code}" --max-time "$timeout" "$url" | grep -q "200"; then
    echo "❌ FAIL: HTTP 200 expected from '$url'"
    exit 1
  fi
}