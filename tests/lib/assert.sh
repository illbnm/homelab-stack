#!/usr/bin/env bash

: "${PROJECT_ROOT:?PROJECT_ROOT must be set}"
: "${CURRENT_SUITE:=general}"

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  RED=$'\033[0;31m'
  GREEN=$'\033[0;32m'
  YELLOW=$'\033[1;33m'
  BLUE=$'\033[0;34m'
  BOLD=$'\033[1m'
  RESET=$'\033[0m'
else
  RED=''
  GREEN=''
  YELLOW=''
  BLUE=''
  BOLD=''
  RESET=''
fi

current_millis() {
  date +%s%3N 2>/dev/null || printf '%s000' "$(date +%s)"
}

record_result() {
  local status=$1
  local name=$2
  local message=$3
  local start_ms=$4
  local now_ms duration_ms marker color

  now_ms=$(current_millis)
  duration_ms=$((now_ms - start_ms))
  TESTS_TOTAL=$((TESTS_TOTAL + 1))

  case "$status" in
    pass)
      TESTS_PASSED=$((TESTS_PASSED + 1))
      marker='PASS'
      color=$GREEN
      ;;
    fail)
      TESTS_FAILED=$((TESTS_FAILED + 1))
      marker='FAIL'
      color=$RED
      ;;
    skip)
      TESTS_SKIPPED=$((TESTS_SKIPPED + 1))
      marker='SKIP'
      color=$YELLOW
      ;;
    *)
      TESTS_FAILED=$((TESTS_FAILED + 1))
      marker='FAIL'
      color=$RED
      status='fail'
      ;;
  esac

  printf '%b[%s]%b %s: %s\n' "$color" "$marker" "$RESET" "$CURRENT_SUITE" "$name"
  if [[ -n "$message" ]]; then
    printf '       %s\n' "$message"
  fi
  report_add_result "$CURRENT_SUITE" "$name" "$status" "$message" "$duration_ms"
}

pass_result() {
  local name=$1
  local message=${2:-}
  local start_ms=${3:-$(current_millis)}
  record_result pass "$name" "$message" "$start_ms"
}

fail_result() {
  local name=$1
  local message=${2:-}
  local start_ms=${3:-$(current_millis)}
  record_result fail "$name" "$message" "$start_ms"
}

skip_result() {
  local name=$1
  local message=${2:-}
  local start_ms=${3:-$(current_millis)}
  record_result skip "$name" "$message" "$start_ms"
}

assert_eq() {
  local expected=$1
  local actual=$2
  local name=${3:-"expected '$expected' equals '$actual'"}
  local start_ms
  start_ms=$(current_millis)
  if [[ "$expected" == "$actual" ]]; then
    pass_result "$name" "value: $actual" "$start_ms"
  else
    fail_result "$name" "expected '$expected', got '$actual'" "$start_ms"
  fi
}

assert_not_empty() {
  local value=$1
  local name=${2:-"value is not empty"}
  local start_ms
  start_ms=$(current_millis)
  if [[ -n "$value" ]]; then
    pass_result "$name" "value is set" "$start_ms"
  else
    fail_result "$name" "value is empty" "$start_ms"
  fi
}

assert_exit_code() {
  local expected=$1
  local actual=$2
  local name=${3:-"exit code equals $expected"}
  local start_ms
  start_ms=$(current_millis)
  assert_eq "$expected" "$actual" "$name"
}

assert_cmd_success() {
  local name=$1
  shift
  local start_ms output
  start_ms=$(current_millis)
  if output=$("$@" 2>&1); then
    pass_result "$name" "command succeeded" "$start_ms"
  else
    fail_result "$name" "$output" "$start_ms"
  fi
}

assert_file_contains() {
  local file=$1
  local pattern=$2
  local name=${3:-"$file contains $pattern"}
  local start_ms
  start_ms=$(current_millis)
  if [[ ! -f "$file" ]]; then
    fail_result "$name" "missing file: $file" "$start_ms"
    return
  fi
  if grep -Eq -- "$pattern" "$file"; then
    pass_result "$name" "$file" "$start_ms"
  else
    fail_result "$name" "pattern not found: $pattern" "$start_ms"
  fi
}

assert_file_executable() {
  local file=$1
  local name=${2:-"$file is executable"}
  local start_ms
  start_ms=$(current_millis)
  if [[ -x "$file" ]]; then
    pass_result "$name" "$file" "$start_ms"
  else
    fail_result "$name" "file is not executable: $file" "$start_ms"
  fi
}

assert_container_running() {
  local container=$1
  local name=${2:-"container $container is running"}
  local start_ms
  start_ms=$(current_millis)
  if ! command -v docker >/dev/null 2>&1; then
    skip_result "$name" "docker is not installed" "$start_ms"
    return
  fi
  if docker ps --format '{{.Names}}' | grep -Fxq "$container"; then
    pass_result "$name" "$container" "$start_ms"
  else
    fail_result "$name" "container not running: $container" "$start_ms"
  fi
}

assert_container_healthy() {
  local container=$1
  local name=${2:-"container $container is healthy"}
  local start_ms health
  start_ms=$(current_millis)
  if ! command -v docker >/dev/null 2>&1; then
    skip_result "$name" "docker is not installed" "$start_ms"
    return
  fi
  if ! docker inspect "$container" >/dev/null 2>&1; then
    fail_result "$name" "container not found: $container" "$start_ms"
    return
  fi
  health=$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$container" 2>/dev/null || true)
  case "$health" in
    healthy)
      pass_result "$name" "health=$health" "$start_ms"
      ;;
    none)
      skip_result "$name" "no Docker healthcheck configured" "$start_ms"
      ;;
    *)
      fail_result "$name" "health=$health" "$start_ms"
      ;;
  esac
}

assert_http_response() {
  local url=$1
  local expected=$2
  local name=${3:-"HTTP $expected from $url"}
  local start_ms code
  start_ms=$(current_millis)
  if ! command -v curl >/dev/null 2>&1; then
    skip_result "$name" "curl is not installed" "$start_ms"
    return
  fi
  code=$(curl -sS -o /dev/null -w '%{http_code}' --connect-timeout 5 --max-time 15 "$url" 2>/dev/null || printf '000')
  if [[ "$expected" == "2xx" && "$code" =~ ^2 ]] || [[ "$expected" == "3xx" && "$code" =~ ^3 ]] || [[ "$code" == "$expected" ]]; then
    pass_result "$name" "HTTP $code" "$start_ms"
  else
    fail_result "$name" "expected HTTP $expected, got $code" "$start_ms"
  fi
}

assert_http_200() {
  local url=$1
  local name=${2:-"HTTP 200 from $url"}
  assert_http_response "$url" "200" "$name"
}

assert_json_value() {
  local file=$1
  local filter=$2
  local expected=$3
  local name=${4:-"JSON value $filter equals $expected"}
  local start_ms actual
  start_ms=$(current_millis)
  if ! command -v jq >/dev/null 2>&1; then
    fail_result "$name" "jq is not installed" "$start_ms"
    return
  fi
  if [[ ! -f "$file" ]]; then
    fail_result "$name" "missing JSON file: $file" "$start_ms"
    return
  fi
  if ! actual=$(jq -er "$filter" "$file" 2>&1); then
    fail_result "$name" "$actual" "$start_ms"
    return
  fi
  if [[ "$actual" == "$expected" ]]; then
    pass_result "$name" "value: $actual" "$start_ms"
  else
    fail_result "$name" "expected '$expected', got '$actual'" "$start_ms"
  fi
}

assert_json_key_exists() {
  local file=$1
  local filter=$2
  local name=${3:-"JSON key exists: $filter"}
  local start_ms output
  start_ms=$(current_millis)
  if ! command -v jq >/dev/null 2>&1; then
    fail_result "$name" "jq is not installed" "$start_ms"
    return
  fi
  if [[ ! -f "$file" ]]; then
    fail_result "$name" "missing JSON file: $file" "$start_ms"
    return
  fi
  if output=$(jq -e "$filter" "$file" 2>&1 >/dev/null); then
    pass_result "$name" "$filter" "$start_ms"
  else
    fail_result "$name" "$output" "$start_ms"
  fi
}

assert_no_errors() {
  local target=$1
  local name=${2:-"no error patterns are present"}
  local start_ms content
  start_ms=$(current_millis)
  if [[ -f "$target" ]]; then
    content=$(<"$target")
  else
    content=$target
  fi
  if grep -Eiq '(panic|traceback|exception|fatal|segmentation fault|permission denied|connection refused)' <<< "$content"; then
    fail_result "$name" "error-like text found" "$start_ms"
  else
    pass_result "$name" "no fatal error patterns" "$start_ms"
  fi
}

assert_no_latest_images() {
  local compose_file=$1
  local name=${2:-"$compose_file has pinned images"}
  local start_ms images_found image raw basename violations=()
  start_ms=$(current_millis)
  if [[ ! -f "$compose_file" ]]; then
    fail_result "$name" "missing compose file: $compose_file" "$start_ms"
    return
  fi
  images_found=0
  while IFS= read -r raw; do
    raw=${raw%%#*}
    image=${raw#*image:}
    image=${image//\"/}
    image=${image//\'/}
    image=${image#"${image%%[![:space:]]*}"}
    image=${image%"${image##*[![:space:]]}"}
    [[ -z "$image" ]] && continue
    if [[ "$image" =~ :-([^}]+) ]]; then
      image=${BASH_REMATCH[1]}
    fi
    images_found=$((images_found + 1))
    basename=${image##*/}
    if [[ "$basename" == *:latest || ( "$basename" != *:* && "$basename" != *@sha256:* ) ]]; then
      violations+=("$image")
    fi
  done < <(grep -E '^[[:space:]]*image:[[:space:]]*' "$compose_file" || true)

  if [[ "${#violations[@]}" -eq 0 ]]; then
    pass_result "$name" "checked $images_found image references" "$start_ms"
  else
    fail_result "$name" "unpinned/latest images: ${violations[*]}" "$start_ms"
  fi
}
