# report.sh — Test reporting utilities for HomeLab

REPORT_FILE="results/report.json"

init_report() {
  mkdir -p results
  echo '{"started_at":"'"$(date -Iseconds)"'","suites":[],"results":{"pass":0,"fail":0,"skip":0}}' > "$REPORT_FILE"
}

write_report() {
  local suite="$1" pass="$2" fail="$3" skip="$4" duration="$5"
  local tmp=$(mktemp)
  jq --arg s "$suite" --argjson p "$pass" --argjson f "$fail" --argjson k "$skip" --arg d "$duration" \
    '.suites += [{"name":$s,"pass":$p,"fail":$f,"skip":$k,"duration":$d}] |
     .results.pass += $p | .results.fail += $f | .results.skip += $k' \
    "$REPORT_FILE" > "$tmp" && mv "$tmp" "$REPORT_FILE"
}

finalize_report() {
  local tmp=$(mktemp)
  jq '.finished_at = "'"$(date -Iseconds)"'"' "$REPORT_FILE" > "$tmp" && mv "$tmp" "$REPORT_FILE"
}

print_banner() {
  echo "╔══════════════════════════════════════╗"
  echo "║   HomeLab Stack — Integration Tests  ║"
  echo "╚══════════════════════════════════════╝"
  echo ""
}
