#!/usr/bin/env bash
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$ROOT_DIR"

source "$SCRIPT_DIR/lib/assert.sh"
source "$SCRIPT_DIR/lib/docker.sh"
source "$SCRIPT_DIR/lib/report.sh"

TARGET_STACK="all"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --stack) TARGET_STACK="$2"; shift 2 ;;
    --all) TARGET_STACK="all"; shift ;;
    *) shift ;;
  esac
done

echo "================================================="
echo "   🧪 HomeLab Stack Automated Testing Suite      "
echo "================================================="

# Test Level 1: Compose Syntax & Linting across stacks
echo "[Level 1] Validating Compose File Syntax..."
for f in $(find stacks -type f -name "docker-compose*.yml" 2>/dev/null); do
  if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
    docker compose -f "$f" config --quiet 2>/dev/null
    report_test "Syntax: $f" $?
  else
    # Fallback YAML validator
    python3 -c "import yaml; yaml.safe_load(open('$f'))" 2>/dev/null || python -c "import yaml; yaml.safe_load(open('$f'))" 2>/dev/null
    report_test "YAML Lint: $f" $?
  fi
done

# Test Level 1: Image tag hygiene (No :latest tags)
echo "[Level 1] Checking Tag Hygiene (:latest ban)..."
LATEST_COUNT=$(grep -rn "image:.*:latest" stacks/ 2>/dev/null | wc -l || echo 0)
if [ "$LATEST_COUNT" -eq 0 ]; then
  report_test "Pinning: No :latest image tags in stacks/" 0
else
  report_test "Pinning: Found $LATEST_COUNT :latest tags" 1
fi

# Test Level 2: Stack Specific Tests
echo "[Level 2] Running Individual Stack Tests..."
for test_file in tests/stacks/*.test.sh; do
  if [ -f "$test_file" ]; then
    bash "$test_file"
    report_test "Suite: $(basename "$test_file")" $?
  fi
done

# Test Level 4: E2E Flows
echo "[Level 4] Running E2E Scenarios..."
for e2e_file in tests/e2e/*.test.sh; do
  if [ -f "$e2e_file" ]; then
    bash "$e2e_file"
    report_test "E2E: $(basename "$e2e_file")" $?
  fi
done

report_summary
