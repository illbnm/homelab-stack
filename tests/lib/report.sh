#!/usr/bin/env bash

# Reporting Library for HomeLab Stack Integration Tests
#
# Manages test results and generates terminal and JSON reports.

# --- Global Variables ---
TEST_RESULTS=() # Array to store test result objects
# Example result object: { "stack": "base", "name": "test_traefik_running", "status": "PASS", "duration": "0.3", "message": "" }

# --- Reporting Functions ---

# add_test_result <stack> <name> <status> <duration> [message]
add_test_result() {
  local stack="$1"
  local name="$2"
  local status="$3"
  local duration="$4"
  local message="${5:-}"

  # Escape double quotes in message for JSON
  local escaped_message=$(echo "${message}" | sed 's/"/\\"/g')

  TEST_RESULTS+=(
    "{\"stack\":\"${stack}\",\"name\":\"${name}\",\"status\":\"${status}\",\"duration\":\"${duration}\",\"message\":\"${escaped_message}\"}"
  )
}

# generate_json_report <output_path>
generate_json_report() {
  local output_path="$1"
  local results_array_json=""

  # Join all individual JSON objects into a single JSON array
  if [[ ${#TEST_RESULTS[@]} -gt 0 ]]; then
    results_array_json=$(IFS=,; echo "[${TEST_RESULTS[*]}]")
  else
    results_array_json="[]"
  fi

  local total_duration=$(( $(date +%s) - START_TIME )) # START_TIME is from run-tests.sh
  local report_json=$(jq -n \
    --argjson results "${results_array_json}" \
    --arg total_tests "${TOTAL_TESTS}" \
    --arg passed_tests "${PASSED_TESTS}" \
    --arg failed_tests "${FAILED_TESTS}" \
    --arg skipped_tests "${SKIPPED_TESTS}" \
    --arg total_duration "${total_duration}" \
    '{
      "timestamp": (now | strftime("%Y-%m-%dT%H:%M:%SZ")),
      "total_tests": ($total_tests | tonumber),
      "passed_tests": ($passed_tests | tonumber),
      "failed_tests": ($failed_tests | tonumber),
      "skipped_tests": ($skipped_tests | tonumber),
      "total_duration_seconds": ($total_duration | tonumber),
      "results": $results
    }')

  echo "${report_json}" > "${output_path}"
}
