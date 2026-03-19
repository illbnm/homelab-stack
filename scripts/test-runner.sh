#!/usr/bin/env bash
# test-runner.sh — 集成测试执行器

set -euo pipefail

BASE_DIR="/workspace"
STACKS_DIR="$BASE_DIR/stacks"
TESTS_DIR="$BASE_DIR/tests"
RESULTS_DIR="/results"
REPORTS_DIR="/reports"

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=== Testing Framework Runner ==="
echo "Stacks dir: $STACKS_DIR"
echo "Tests dir: $TESTS_DIR"
echo "Results: $RESULTS_DIR"
echo

# 发现所有 Stack
[[ -d "$STACKS_DIR" ]] || { echo "❌ stacks dir not found"; exit 1; }

stacks=($(find "$STACKS_DIR" -mindepth 1 -maxdepth 1 -type d -exec basename {} \;))
echo "Found stacks: ${stacks[*]}"
echo

# 执行每个 Stack 的测试
for stack in "${stacks[@]}"; do
  test_file="$TESTS_DIR/stacks/${stack}.test.sh"
  if [[ -f "$test_file" ]]; then
    echo -e "${YELLOW}[$stack]${NC} Running tests..."
    bash "$test_file" 2>&1 | tee "$RESULTS_DIR/${stack}.log" || true
    echo -e "${GREEN}[$stack] ✅ completed${NC}"
  else
    echo -e "${YELLOW}[$stack] ⏭️  no test script${NC}"
  fi
  echo
done

# 生成汇总报告
echo "Generating report..."
find "$RESULTS_DIR" -name "*.log" -exec bash -c '
  file="{}"
  stack=$(basename "$file" .log)
  passed=$(grep -c "✅" "$file" || true)
  failed=$(grep -c "❌" "$file" || true)
  echo "{\"stack\":\"$stack\",\"passed\":$passed,\"failed\":$failed}"
' \; | jq -s '.' > "$REPORTS_DIR/report.json"

echo "Report: $REPORTS_DIR/report.json"
cat "$REPORTS_DIR/report.json"
echo
echo "✅ All tests completed"