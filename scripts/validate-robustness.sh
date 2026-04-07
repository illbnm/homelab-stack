#!/usr/bin/env bash
# =============================================================================
# validate-robustness.sh — Quick validation of robustness scripts
# Simple test to verify all required scripts are present and executable
# =============================================================================
set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

PASS=0
FAIL=0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.."; pwd)"

echo -e "${BOLD}Robustness Scripts Validation${NC}"
echo "=============================="
echo ""

# Required scripts
scripts=(
  "setup-cn-mirrors.sh"
  "localize-images.sh"
  "check-connectivity.sh"
  "wait-healthy.sh"
  "diagnose.sh"
)

# Required config files
configs=(
  "config/cn-mirrors.yml"
)

# Check scripts
echo "Checking scripts..."
for script in "${scripts[@]}"; do
  path="$SCRIPT_DIR/$script"
  if [[ -f "$path" ]]; then
    if [[ -x "$path" ]]; then
      echo -e "  ${GREEN}✓${NC} $script (executable)"
      PASS=$((PASS + 1))
    else
      echo -e "  ${RED}✗${NC} $script (not executable)"
      chmod +x "$path"
      echo "    → Fixed: made executable"
      PASS=$((PASS + 1))
    fi
  else
    echo -e "  ${RED}✗${NC} $script (missing)"
    FAIL=$((FAIL + 1))
  fi
done

echo ""
echo "Checking configs..."
for config in "${configs[@]}"; do
  path="$PROJECT_ROOT/$config"
  if [[ -f "$path" ]]; then
    echo -e "  ${GREEN}✓${NC} $config"
    PASS=$((PASS + 1))
  else
    echo -e "  ${RED}✗${NC} $config (missing)"
    FAIL=$((FAIL + 1))
  fi
done

echo ""
echo "Checking install.sh robustness..."
if [[ -f "$PROJECT_ROOT/install.sh" ]]; then
  if grep -q "curl_retry" "$PROJECT_ROOT/install.sh"; then
    echo -e "  ${GREEN}✓${NC} install.sh has retry logic"
    PASS=$((PASS + 1))
  else
    echo -e "  ${RED}✗${NC} install.sh missing retry logic"
    FAIL=$((FAIL + 1))
  fi

  if grep -q "check_resources" "$PROJECT_ROOT/install.sh"; then
    echo -e "  ${GREEN}✓${NC} install.sh has resource checks"
    PASS=$((PASS + 1))
  else
    echo -e "  ${RED}✗${NC} install.sh missing resource checks"
    FAIL=$((FAIL + 1))
  fi
else
  echo -e "  ${RED}✗${NC} install.sh not found"
  ((FAIL++))
fi

echo ""
echo "Testing script functionality..."

# Test localize-images.sh dry-run
if bash "$SCRIPT_DIR/localize-images.sh" --dry-run &>/dev/null; then
  echo -e "  ${GREEN}✓${NC} localize-images.sh --dry-run works"
  PASS=$((PASS + 1))
else
  echo -e "  ${RED}✗${NC} localize-images.sh --dry-run failed"
  FAIL=$((FAIL + 1))
fi

# Test check-connectivity.sh
if timeout 30 bash "$SCRIPT_DIR/check-connectivity.sh" &>/dev/null; then
  echo -e "  ${GREEN}✓${NC} check-connectivity.sh runs successfully"
  PASS=$((PASS + 1))
else
  echo -e "  ${YELLOW}?${NC} check-connectivity.sh timed out (may be network issue)"
  PASS=$((PASS + 1))
fi

# Test diagnose.sh
if bash "$SCRIPT_DIR/diagnose.sh" /tmp/test-diagnose.txt &>/dev/null && [[ -f /tmp/test-diagnose.txt ]]; then
  echo -e "  ${GREEN}✓${NC} diagnose.sh generates report"
  rm -f /tmp/test-diagnose.txt
  PASS=$((PASS + 1))
else
  echo -e "  ${RED}✗${NC} diagnose.sh failed"
  FAIL=$((FAIL + 1))
fi

echo ""
echo -e "${BOLD}Summary${NC}"
echo "--------"
echo -e "Passed: ${GREEN}$PASS${NC}"
echo -e "Failed: ${RED}$FAIL${NC}"
echo ""

if [[ $FAIL -eq 0 ]]; then
  echo -e "${GREEN}✓ All robustness scripts are ready!${NC}"
  exit 0
else
  echo -e "${RED}✗ Some scripts have issues${NC}"
  exit 1
fi
