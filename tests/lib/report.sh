#!/usr/bin/env bash

: "${PROJECT_ROOT:?PROJECT_ROOT must be set}"

REPORT_FILE="${REPORT_FILE:-$PROJECT_ROOT/tests/results/report.json}"
REPORT_RESULTS=()
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0
REPORT_STARTED_AT=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

json_string() {
  local value=${1-}
  if command -v jq >/dev/null 2>&1; then
    jq -Rn --arg value "$value" '$value'
    return
  fi
  value=${value//\\/\\\\}
  value=${value//"/\\"}
  value=${value//$'\n'/\\n}
  printf '"%s"' "$value"
}

report_init() {
  mkdir -p "$(dirname "$REPORT_FILE")"
  REPORT_RESULTS=()
  TESTS_TOTAL=0
  TESTS_PASSED=0
  TESTS_FAILED=0
  TESTS_SKIPPED=0
  REPORT_STARTED_AT=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
}

report_add_result() {
  local suite=$1
  local test_name=$2
  local status=$3
  local message=$4
  local duration_ms=$5
  local suite_json test_json status_json message_json object

  suite_json=$(json_string "$suite")
  test_json=$(json_string "$test_name")
  status_json=$(json_string "$status")
  message_json=$(json_string "$message")
  printf -v object '{"suite":%s,"test":%s,"status":%s,"message":%s,"duration_ms":%s}' \
    "$suite_json" "$test_json" "$status_json" "$message_json" "$duration_ms"
  REPORT_RESULTS+=("$object")
}

report_write() {
  local finished_at
  finished_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  mkdir -p "$(dirname "$REPORT_FILE")"
  {
    printf '{\n'
    printf '  "started_at": %s,\n' "$(json_string "$REPORT_STARTED_AT")"
    printf '  "finished_at": %s,\n' "$(json_string "$finished_at")"
    printf '  "summary": {"total": %s, "passed": %s, "failed": %s, "skipped": %s},\n' \
      "$TESTS_TOTAL" "$TESTS_PASSED" "$TESTS_FAILED" "$TESTS_SKIPPED"
    printf '  "results": [\n'
    local index
    for index in "${!REPORT_RESULTS[@]}"; do
      if [[ "$index" -gt 0 ]]; then
        printf ',\n'
      fi
      printf '    %s' "${REPORT_RESULTS[$index]}"
    done
    printf '\n  ]\n'
    printf '}\n'
  } > "$REPORT_FILE"
}
