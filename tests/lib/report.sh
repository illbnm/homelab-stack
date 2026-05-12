#!/usr/bin/env bash
# Report generation utilities
set -euo pipefail

REPORT_FILE="${REPORT_FILE:-/tmp/homelab-test-report.json}"

init_report() {
  echo '{"suites":[],"timestamp":"'"$(date -u +%Y-%m-%dT%H:%M:%SZ)"'"}' > "$REPORT_FILE"
}

append_suite() {
  local name="$1" passed="$2" failed="$3" skipped="$4"
  local tmp
  tmp=$(mktemp)
  python3 -c "
import json, sys
with open('$REPORT_FILE') as f:
    report = json.load(f)
report['suites'].append({'name':'$name','passed':$passed,'failed':$failed,'skipped':$skipped})
with open('$tmp','w') as f:
    json.dump(report, f, indent=2)
" 2>/dev/null && mv "$tmp" "$REPORT_FILE"
}

print_final_report() {
  if [ -f "$REPORT_FILE" ]; then
    echo ""
    echo "📊 Full report: $REPORT_FILE"
    python3 -c "
import json
with open('$REPORT_FILE') as f:
    r = json.load(f)
total_p = sum(s['passed'] for s in r['suites'])
total_f = sum(s['failed'] for s in r['suites'])
total_s = sum(s['skipped'] for s in r['suites'])
print(f'Total: {total_p} passed, {total_f} failed, {total_s} skipped')
" 2>/dev/null
  fi
}
