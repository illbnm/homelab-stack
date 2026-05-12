# assert.sh — Assertion library for HomeLab integration tests
# Usage: source lib/assert.sh

PASS=0; FAIL=0; SKIP=0; TOTAL=0

assert_eq() { TOTAL=$((TOTAL+1)); local a="$1" e="$2" m="${3:-}"; if [ "$a" = "$e" ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); log_fail "${m:-expected '$e', got '$a'}"; fi; }
assert_not_empty() { TOTAL=$((TOTAL+1)); local v="$1" m="${2:-}"; if [ -n "$v" ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); log_fail "${m:-expected non-empty value}"; fi; }
assert_exit_code() { TOTAL=$((TOTAL+1)); local c="$1" m="${2:-}"; assert_eq "$c" "0" "$m"; }
assert_container_running() { TOTAL=$((TOTAL+1)); local n="$1"; local s=$(docker inspect -f '{{.State.Status}}' "$n" 2>/dev/null); if [ "$s" = "running" ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); log_fail "container '$n' not running (status: ${s:-not found})"; fi; }
assert_container_healthy() { TOTAL=$((TOTAL+1)); local n="$1"; for i in $(seq 1 60); do local h=$(docker inspect -f '{{.State.Health.Status}}' "$n" 2>/dev/null); [ "$h" = "healthy" ] && { PASS=$((PASS+1)); return 0; }; sleep 1; done; FAIL=$((FAIL+1)); log_fail "container '$n' not healthy after 60s (status: ${h:-unknown})"; }
assert_http_200() { TOTAL=$((TOTAL+1)); local u="$1" t="${2:-30}"; local c=$(curl -s -o /dev/null -w '%{http_code}' --max-time "$t" "$u" 2>/dev/null); if [ "$c" = "200" ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); log_fail "HTTP $u → $c (expected 200)"; fi; }
assert_http_response() { TOTAL=$((TOTAL+1)); local u="$1" p="$2"; if curl -s "$u" | grep -q "$p"; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); log_fail "HTTP $u — pattern '$p' not found"; fi; }
assert_json_value() { TOTAL=$((TOTAL+1)); local j="$1" q="$2" e="$3"; local a=$(echo "$j" | jq -r "$q" 2>/dev/null); if [ "$a" = "$e" ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); log_fail "jq '$q': expected '$e', got '$a'"; fi; }
assert_json_key_exists() { TOTAL=$((TOTAL+1)); local j="$1" q="$2"; if echo "$j" | jq -e "$q" >/dev/null 2>&1; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); log_fail "jq key '$q' not found"; fi; }
assert_no_errors() { TOTAL=$((TOTAL+1)); local j="$1"; if echo "$j" | jq -e '.errors == null or .errors == []' >/dev/null 2>&1; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); log_fail "unexpected errors in response"; fi; }
assert_file_contains() { TOTAL=$((TOTAL+1)); local f="$1" p="$2"; if [ -f "$f" ] && grep -q "$p" "$f"; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); log_fail "file '$f' doesn't contain pattern '$p'"; fi; }
assert_no_latest_images() { TOTAL=$((TOTAL+1)); local d="$1"; local c=$(grep -r 'image:.*:latest' "$d" 2>/dev/null | wc -l); if [ "$c" -eq 0 ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); log_fail "found $c ':latest' image tags in $d"; fi; }

log_pass() { echo -e "  \033[32m✅ PASS\033[0m ($1)"; }
log_fail() { echo -e "  \033[31m❌ FAIL\033[0m — $1"; }
log_skip() { TOTAL=$((TOTAL+1)); SKIP=$((SKIP+1)); echo -e "  \033[33m⏭ SKIP\033[0m ($1)"; }

print_summary() {
  echo ""
  echo "──────────────────────────────────────"
  echo -e "Results: $PASS passed, $FAIL failed, $SKIP skipped"
  echo -e "Duration: $(($(date +%s)-START))s"
  echo "──────────────────────────────────────"
  return $FAIL
}
