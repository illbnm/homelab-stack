#!/usr/bin/env bash
set -euo pipefail

REPORT_CASES=()
REPORT_PASS=0
REPORT_FAIL=0
REPORT_SKIP=0
REPORT_START="${REPORT_START:-$(date +%s)}"

json_escape() {
  local s="$1"
  s=${s//\\/\\\\}
  s=${s//\"/\\\"}
  s=${s//$'\n'/\\n}
  s=${s//$'\r'/\\r}
  s=${s//$'\t'/\\t}
  printf '%s' "$s"
}

report_case() {
  local stack="$1" name="$2" status="$3" duration="$4" message="${5:-}"
  REPORT_CASES+=("$stack|$name|$status|$duration|$message")
  case "$status" in
    PASS) ((REPORT_PASS++)) ;;
    FAIL) ((REPORT_FAIL++)) ;;
    SKIP) ((REPORT_SKIP++)) ;;
  esac
  local icon label
  case "$status" in
    PASS) icon='PASS' ;;
    FAIL) icon='FAIL' ;;
    SKIP) icon='SKIP' ;;
  esac
  printf '[%s] %-24s %s (%ss)%s\n' "$stack" "$name" "$icon" "$duration" "${message:+ - $message}"
}

report_summary() {
  local total=$((REPORT_PASS + REPORT_FAIL + REPORT_SKIP))
  printf '\nResults: %s passed, %s failed, %s skipped (%s total)\n' "$REPORT_PASS" "$REPORT_FAIL" "$REPORT_SKIP" "$total"
}

report_write_json() {
  local path="$1"
  mkdir -p "$(dirname "$path")"
  {
    printf '{\n'
    printf '  "started_at": %s,\n' "$REPORT_START"
    printf '  "passed": %s,\n' "$REPORT_PASS"
    printf '  "failed": %s,\n' "$REPORT_FAIL"
    printf '  "skipped": %s,\n' "$REPORT_SKIP"
    printf '  "cases": [\n'
    local i=0
    for case_item in "${REPORT_CASES[@]}"; do
      IFS='|' read -r stack name status duration message <<<"$case_item"
      [[ $i -gt 0 ]] && printf ',\n'
      printf '    {"stack":"%s","name":"%s","status":"%s","duration":%s,"message":"%s"}' \
        "$(json_escape "$stack")" "$(json_escape "$name")" "$(json_escape "$status")" "$duration" "$(json_escape "$message")"
      i=$((i + 1))
    done
    printf '\n  ]\n}\n'
  } >"$path"
}
