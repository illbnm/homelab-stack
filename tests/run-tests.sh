#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.."; pwd)"
TESTS_DIR="$BASE_DIR/tests"
RESULTS_DIR="$TESTS_DIR/results"
JSON_OUTPUT="$RESULTS_DIR/report.json"

STACK="${1:-}"
MODE="${2:-}"
if [[ "${STACK:-}" == "--stack" ]]; then
  STACK="${2:-}"
  MODE="stack"
elif [[ "${STACK:-}" == "--all" || -z "${STACK:-}" ]]; then
  MODE="all"
  [[ "${STACK:-}" == "--all" ]] && STACK="${2:-}"
fi

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  cat <<EOF
Usage: $0 --all
       $0 --stack <name>
EOF
  exit 0
fi

source "$TESTS_DIR/lib/assert.sh"
source "$TESTS_DIR/lib/report.sh"

run_suite_file() {
  local file="$1"
  local stack
  stack="$(basename "$file" .test.sh)"
  stack="${stack%%.*}"
  local before after test_functions
  before="$(mktemp)"
  after="$(mktemp)"
  declare -F | awk '{print $3}' | sort >"$before"
  source "$TESTS_DIR/lib/docker.sh"
  source "$file"
  local fn
  declare -F | awk '{print $3}' | sort >"$after"
  mapfile -t test_functions < <(comm -13 "$before" "$after" | grep '^test_' || true)
  rm -f "$before" "$after"
  for fn in "${test_functions[@]}"; do
    local start end duration status output rc
    start="$(date +%s)"
    set +e
    output="$("$fn" 2>&1)"
    rc=$?
    set -e
    end="$(date +%s)"
    duration=$((end - start))
    case "$rc" in
      0) status=PASS ;;
      2) status=SKIP ;;
      *) status=FAIL ;;
    esac
    report_case "$stack" "$fn" "$status" "$duration" "${output//$'\n'/; }"
  done
}

stack_files=()
if [[ "$MODE" == "stack" && -n "${STACK:-}" ]]; then
  stack_files+=("$TESTS_DIR/stacks/$STACK.test.sh")
else
  for file in "$TESTS_DIR"/stacks/*.test.sh; do
    stack_files+=("$file")
  done
  for file in "$TESTS_DIR"/e2e/*.test.sh; do
    stack_files+=("$file")
  done
fi

for file in "${stack_files[@]}"; do
  [[ -f "$file" ]] || continue
  if ! run_suite_file "$file"; then
    :
  fi
done

report_summary
report_write_json "$JSON_OUTPUT"
[[ "$REPORT_FAIL" -eq 0 ]]
