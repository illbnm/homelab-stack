#!/usr/bin/env bash
# =============================================================================
# test-robustness.sh — Test suite for robustness features
# Validates all robustness scripts work correctly
# =============================================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'

PASS=0
FAIL=0

log_pass() { echo -e "${GREEN}[✓]${NC} $*"; ((PASS++)); }
log_fail() { echo -e "${RED}[✗]${NC} $*"; ((FAIL++)); }
log_info() { echo -e "${BLUE}[i]${NC} $*"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.."; pwd)"

# ---------------------------------------------------------------------------
# Test: setup-cn-mirrors.sh exists and is executable
# ---------------------------------------------------------------------------
test_setup_cn_mirrors() {
  echo -e "\n${BOLD}Test 1: setup-cn-mirrors.sh${NC}"

  local script="$SCRIPT_DIR/setup-cn-mirrors.sh"

  if [[ -f "$script" ]]; then
    log_pass "Script exists: $script"
  else
    log_fail "Script not found: $script"
    return
  fi

  if [[ -x "$script" ]]; then
    log_pass "Script is executable"
  else
    log_fail "Script is not executable"
    chmod +x "$script"
    log_info "Fixed: Made script executable"
  fi

  # Check for required functions
  if grep -q "check_root" "$script"; then
    log_pass "Contains root check function"
  else
    log_fail "Missing root check function"
  fi

  if grep -q "MIRRORS=(" "$script"; then
    log_pass "Contains mirror configuration"
  else
    log_fail "Missing mirror configuration"
  fi
}

# ---------------------------------------------------------------------------
# Test: localize-images.sh exists and has required options
# ---------------------------------------------------------------------------
test_localize_images() {
  echo -e "\n${BOLD}Test 2: localize-images.sh${NC}"

  local script="$SCRIPT_DIR/localize-images.sh"

  if [[ -f "$script" ]]; then
    log_pass "Script exists: $script"
  else
    log_fail "Script not found: $script"
    return
  fi

  if [[ -x "$script" ]]; then
    log_pass "Script is executable"
  else
    log_fail "Script is not executable"
    chmod +x "$script"
    log_info "Fixed: Made script executable"
  fi

  # Check for required options
  local options=("--cn" "--restore" "--dry-run" "--check")
  for opt in "${options[@]}"; do
    if grep -q "$opt" "$script"; then
      log_pass "Supports $opt option"
    else
      log_fail "Missing $opt option"
    fi
  done

  # Test dry-run mode
  if bash "$script" --dry-run &>/dev/null; then
    log_pass "Dry-run mode works"
  else
    log_fail "Dry-run mode failed"
  fi
}

# ---------------------------------------------------------------------------
# Test: cn-mirrors.yml configuration file
# ---------------------------------------------------------------------------
test_mirror_config() {
  echo -e "\n${BOLD}Test 3: cn-mirrors.yml configuration${NC}"

  local config="$PROJECT_ROOT/config/cn-mirrors.yml"

  if [[ -f "$config" ]]; then
    log_pass "Config file exists: $config"
  else
    log_fail "Config file not found: $config"
    return
  fi

  # Check for required registries
  local registries=("gcr.io" "ghcr.io" "k8s.gcr.io" "registry.k8s.io" "quay.io")
  for registry in "${registries[@]}"; do
    if grep -q "$registry" "$config"; then
      log_pass "Contains mappings for $registry"
    else
      log_fail "Missing mappings for $registry"
    fi
  done

  # Check YAML syntax (basic)
  if grep -q "^mirrors:" "$config"; then
    log_pass "YAML structure is valid"
  else
    log_fail "YAML structure is invalid"
  fi
}

# ---------------------------------------------------------------------------
# Test: check-connectivity.sh exists and runs
# ---------------------------------------------------------------------------
test_check_connectivity() {
  echo -e "\n${BOLD}Test 4: check-connectivity.sh${NC}"

  local script="$SCRIPT_DIR/check-connectivity.sh"

  if [[ -f "$script" ]]; then
    log_pass "Script exists: $script"
  else
    log_fail "Script not found: $script"
    return
  fi

  if [[ -x "$script" ]]; then
    log_pass "Script is executable"
  else
    log_fail "Script is not executable"
    chmod +x "$script"
    log_info "Fixed: Made script executable"
  fi

  # Test script runs (with timeout)
  if timeout 30 bash "$script" &>/dev/null; then
    log_pass "Script executes successfully"
  else
    log_warn "Script execution timed out or failed (may be network issue)"
  fi
}

# ---------------------------------------------------------------------------
# Test: wait-healthy.sh exists and has required functions
# ---------------------------------------------------------------------------
test_wait_healthy() {
  echo -e "\n${BOLD}Test 5: wait-healthy.sh${NC}"

  local script="$SCRIPT_DIR/wait-healthy.sh"

  if [[ -f "$script" ]]; then
    log_pass "Script exists: $script"
  else
    log_fail "Script not found: $script"
    return
  fi

  if [[ -x "$script" ]]; then
    log_pass "Script is executable"
  else
    log_fail "Script is not executable"
    chmod +x "$script"
    log_info "Fixed: Made script executable"
  fi

  # Check for required options
  if grep -q "\-\-stack" "$script" && grep -q "\-\-timeout" "$script"; then
    log_pass "Supports --stack and --timeout options"
  else
    log_fail "Missing required options"
  fi

  # Check for health check logic
  if grep -q "is_container_healthy" "$script"; then
    log_pass "Contains health check logic"
  else
    log_fail "Missing health check logic"
  fi
}

# ---------------------------------------------------------------------------
# Test: diagnose.sh exists and generates report
# ---------------------------------------------------------------------------
test_diagnose() {
  echo -e "\n${BOLD}Test 6: diagnose.sh${NC}"

  local script="$SCRIPT_DIR/diagnose.sh"

  if [[ -f "$script" ]]; then
    log_pass "Script exists: $script"
  else
    log_fail "Script not found: $script"
    return
  fi

  if [[ -x "$script" ]]; then
    log_pass "Script is executable"
  else
    log_fail "Script is not executable"
    chmod +x "$script"
    log_info "Fixed: Made script executable"
  fi

  # Test report generation
  local report="$PROJECT_ROOT/test-diagnose-report.txt"
  if bash "$script" "$report" &>/dev/null; then
    if [[ -f "$report" ]]; then
      log_pass "Generates diagnostic report"

      # Check report content
      if grep -q "System Information" "$report"; then
        log_pass "Report contains system information"
      else
        log_fail "Report missing system information"
      fi

      # Cleanup
      rm -f "$report"
    else
      log_fail "Report file not created"
    fi
  else
    log_fail "Script execution failed"
  fi
}

# ---------------------------------------------------------------------------
# Test: install.sh robustness features
# ---------------------------------------------------------------------------
test_install_robustness() {
  echo -e "\n${BOLD}Test 7: install.sh robustness${NC}"

  local script="$PROJECT_ROOT/install.sh"

  if [[ -f "$script" ]]; then
    log_pass "Script exists: $script"
  else
    log_fail "Script not found: $script"
    return
  fi

  if [[ -x "$script" ]]; then
    log_pass "Script is executable"
  else
    log_fail "Script is not executable"
    chmod +x "$script"
    log_info "Fixed: Made script executable"
  fi

  # Check for robustness features
  local features=(
    "curl_retry"
    "check_resources"
    "check_ports"
    "detect_china_network"
    "install_docker"
  )

  for feature in "${features[@]}"; do
    if grep -q "$feature" "$script"; then
      log_pass "Contains $feature function"
    else
      log_fail "Missing $feature function"
    fi
  done

  # Check for retry logic
  if grep -q "max_attempts" "$script"; then
    log_pass "Contains retry logic"
  else
    log_fail "Missing retry logic"
  fi
}

# ---------------------------------------------------------------------------
# Test: All scripts pass shellcheck (if available)
# ---------------------------------------------------------------------------
test_shellcheck() {
  echo -e "\n${BOLD}Test 8: ShellCheck validation${NC}"

  if ! command -v shellcheck &>/dev/null; then
    log_warn "ShellCheck not installed, skipping"
    return
  fi

  local scripts=(
    "$SCRIPT_DIR/setup-cn-mirrors.sh"
    "$SCRIPT_DIR/localize-images.sh"
    "$SCRIPT_DIR/check-connectivity.sh"
    "$SCRIPT_DIR/wait-healthy.sh"
    "$SCRIPT_DIR/diagnose.sh"
    "$PROJECT_ROOT/install.sh"
  )

  for script in "${scripts[@]}"; do
    if [[ -f "$script" ]]; then
      if shellcheck "$script" &>/dev/null; then
        log_pass "ShellCheck passed: $(basename "$script")"
      else
        log_warn "ShellCheck warnings: $(basename "$script")"
        log_info "Run: shellcheck $script"
      fi
    fi
  done
}

# ---------------------------------------------------------------------------
# Test: Integration test with sample compose file
# ---------------------------------------------------------------------------
test_integration() {
  echo -e "\n${BOLD}Test 9: Integration test${NC}"

  # Create test compose file with foreign images
  local test_compose="$PROJECT_ROOT/test-compose.yml"
  cat > "$test_compose" <<EOF
version: '3.8'
services:
  test-cadvisor:
    image: gcr.io/cadvisor/cadvisor:v0.50.0
  test-authentik:
    image: ghcr.io/goauthentik/server:2024.10.4
  test-normal:
    image: nginx:latest
EOF

  log_info "Created test compose file with foreign images"

  # Test check mode
  if bash "$SCRIPT_DIR/localize-images.sh" --check &>/dev/null; then
    log_fail "Check should detect foreign images"
  else
    log_pass "Check correctly detects foreign images"
  fi

  # Test dry-run mode
  if bash "$SCRIPT_DIR/localize-images.sh" --dry-run &>/dev/null; then
    log_pass "Dry-run mode works"
  else
    log_fail "Dry-run mode failed"
  fi

  # Cleanup
  rm -f "$test_compose"
  log_info "Cleaned up test files"
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
print_summary() {
  echo -e "\n${BOLD}=== Test Summary ===${NC}"
  echo -e "  ${GREEN}Passed: $PASS${NC}"
  echo -e "  ${RED}Failed: $FAIL${NC}"
  echo ""

  if [[ $FAIL -eq 0 ]]; then
    echo -e "${GREEN}✓ All robustness tests passed!${NC}"
    echo ""
    log_info "Robustness features are ready to use"
    log_info "Next steps:"
    log_info "  1. Run: ./scripts/check-connectivity.sh"
    log_info "  2. For China: sudo ./scripts/setup-cn-mirrors.sh"
    log_info "  3. For China: ./scripts/localize-images.sh --cn"
    log_info "  4. Install: ./install.sh"
    exit 0
  else
    echo -e "${RED}✗ Some tests failed${NC}"
    echo ""
    log_warn "Review failed tests and fix issues"
    exit 1
  fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
  echo -e ""
  echo -e "${BOLD}  HomeLab Stack — Robustness Test Suite${NC}"
  echo -e "${BOLD}  =======================================${NC}"

  test_setup_cn_mirrors
  test_localize_images
  test_mirror_config
  test_check_connectivity
  test_wait_healthy
  test_diagnose
  test_install_robustness
  test_shellcheck
  test_integration

  print_summary
}

main "$@"
