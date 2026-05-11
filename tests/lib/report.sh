#!/usr/bin/env bash
set -euo pipefail

REPORT_FILE="${REPORT_FILE:-tests/results/report.json}"
RESULTS_JSON='{"results":[],"summary":{"passed":0,"failed":0,"skipped":0}}'

report_init() {
  mkdir -p "$(dirname "$REPORT_FILE")"
  echo '{"results":[],"summary":{"passed":0,"failed":0,"skipped":0}}' > "$REPORT_FILE"
}

report_test() {
  local stack="$1" test_name="$2" status="$3" duration="$4" message="${5:-}"
  local entry
  entry=$(cat <<EOF
  {"stack":"$stack","test":"$test_name","status":"$status","duration":"$duration","message":"$message"}
EOF
)
  local tmp
  tmp=$(mktemp)
  jq --argjson entry "$entry" '.results[.results|length] = $entry' "$REPORT_FILE" > "$tmp" && mv "$tmp" "$REPORT_FILE"
  local key
  case "$status" in
    pass|PASS) key="passed" ;;
    fail|FAIL) key="failed" ;;
    skip|SKIP) key="skipped" ;;
  esac
  jq --arg key "$key" '.summary[$key] += 1' "$REPORT_FILE" > "$tmp" && mv "$tmp" "$REPORT_FILE"
}

print_banner() {
  echo ""
  echo "╔══════════════════════════════════════╗"
  echo "║   HomeLab Stack — Integration Tests  ║"
  echo "╚══════════════════════════════════════╝"
  echo ""
}

print_test_result() {
  local stack="$1" name="$2" status="$3" duration="$4"
  local icon
  case "$status" in
    PASS) icon="✅" ;;
    FAIL) icon="❌" ;;
    SKIP) icon="⏭️" ;;
  esac
  printf "[%-12s] %-30s %s %s (%s)\n" "$stack" "$name" "$icon" "$status" "$duration"
}

export -f report_init report_test print_banner print_test_result
