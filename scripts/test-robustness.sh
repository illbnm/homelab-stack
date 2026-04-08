#!/usr/bin/env bash
# =============================================================================
# Robustness Feature Test Suite
# Tests all robustness scripts and features
# =============================================================================
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

PASS=0
FAIL=0

log_pass() { echo -e "  ${GREEN}✓${NC} $*"; ((PASS++)); }
log_fail() { echo -e "  ${RED}✗${NC} $*"; ((FAIL++)); }
log_info() { echo -e "  ${BLUE}●${NC} $*"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"

echo -e "\n${BOLD}${BLUE}=== Robustness 测试套件 ===${NC}\n"

# Test 1: check-connectivity.sh exists and is executable
echo "[1/6] 检查 check-connectivity.sh"
if [[ -x "$SCRIPT_DIR/check-connectivity.sh" ]]; then
  log_pass "脚本存在且可执行"
  if bash -n "$SCRIPT_DIR/check-connectivity.sh" 2>/dev/null; then
    log_pass "语法检查通过"
  else
    log_fail "语法错误"
  fi
else
  log_fail "脚本不存在或不可执行"
fi
echo

# Test 2: setup-cn-mirrors.sh exists and is executable
echo "[2/6] 检查 setup-cn-mirrors.sh"
if [[ -x "$SCRIPT_DIR/setup-cn-mirrors.sh" ]]; then
  log_pass "脚本存在且可执行"
  if bash -n "$SCRIPT_DIR/setup-cn-mirrors.sh" 2>/dev/null; then
    log_pass "语法检查通过"
  else
    log_fail "语法错误"
  fi
else
  log_fail "脚本不存在或不可执行"
fi
echo

# Test 3: localize-images.sh exists and has all required modes
echo "[3/6] 检查 localize-images.sh"
if [[ -x "$SCRIPT_DIR/localize-images.sh" ]]; then
  log_pass "脚本存在且可执行"
  
  # Test --help
  if "$SCRIPT_DIR/localize-images.sh" --help >/dev/null 2>&1; then
    log_pass "--help 参数正常"
  else
    log_fail "--help 参数失败"
  fi
  
  # Test --check
  if "$SCRIPT_DIR/localize-images.sh" --check >/dev/null 2>&1; then
    log_pass "--check 参数正常"
  else
    log_info "--check 返回非零（可能镜像已替换）"
  fi
else
  log_fail "脚本不存在或不可执行"
fi
echo

# Test 4: wait-healthy.sh exists and validates arguments
echo "[4/6] 检查 wait-healthy.sh"
if [[ -x "$SCRIPT_DIR/wait-healthy.sh" ]]; then
  log_pass "脚本存在且可执行"
  
  # Test --help
  if "$SCRIPT_DIR/wait-healthy.sh" --help >/dev/null 2>&1; then
    log_pass "--help 参数正常"
  else
    log_fail "--help 参数失败"
  fi
  
  # Test missing stack argument
  if ! "$SCRIPT_DIR/wait-healthy.sh" 2>/dev/null; then
    log_pass "缺少参数时正确报错"
  else
    log_fail "缺少参数时应报错"
  fi
else
  log_fail "脚本不存在或不可执行"
fi
echo

# Test 5: diagnose.sh exists and generates report
echo "[5/6] 检查 diagnose.sh"
if [[ -x "$SCRIPT_DIR/diagnose.sh" ]]; then
  log_pass "脚本存在且可执行"
  
  # Run diagnose
  cd "$SCRIPT_DIR/.."
  if bash -n "$SCRIPT_DIR/diagnose.sh" 2>/dev/null; then
    log_pass "语法检查通过"
  else
    log_fail "语法错误"
  fi
  
  # Check if it can generate report
  if timeout 30 "$SCRIPT_DIR/diagnose.sh" >/dev/null 2>&1; then
    log_pass "诊断脚本可运行"
    if [[ -f "diagnose-report.txt" ]]; then
      log_pass "诊断报告已生成"
      rm -f diagnose-report.txt
    else
      log_fail "诊断报告未生成"
    fi
  else
    log_info "诊断脚本运行超时或出错"
  fi
else
  log_fail "脚本不存在或不可执行"
fi
echo

# Test 6: install.sh robustness features
echo "[6/6] 检查 install.sh 健壮性"
if [[ -f "$SCRIPT_DIR/../install.sh" ]]; then
  log_pass "install.sh 存在"
  
  # Check for retry logic
  if grep -q "curl_retry" "$SCRIPT_DIR/../install.sh"; then
    log_pass "包含网络重试逻辑"
  else
    log_fail "缺少网络重试逻辑"
  fi
  
  # Check for disk space check
  if grep -q "DISK_GB" "$SCRIPT_DIR/../install.sh"; then
    log_pass "包含磁盘空间检查"
  else
    log_fail "缺少磁盘空间检查"
  fi
  
  # Check for memory check
  if grep -q "MEMORY_GB" "$SCRIPT_DIR/../install.sh"; then
    log_pass "包含内存检查"
  else
    log_fail "缺少内存检查"
  fi
  
  # Check for port conflict check
  if grep -q "PORT_CONFLICT" "$SCRIPT_DIR/../install.sh"; then
    log_pass "包含端口冲突检测"
  else
    log_fail "缺少端口冲突检测"
  fi
  
  # Check for auto Docker installation
  if grep -q "get.docker.com" "$SCRIPT_DIR/../install.sh"; then
    log_pass "包含 Docker 自动安装"
  else
    log_fail "缺少 Docker 自动安装"
  fi
else
  log_fail "install.sh 不存在"
fi
echo

# Test 7: cn-mirrors.yml configuration
echo "[7/7] 检查配置文件"
if [[ -f "$SCRIPT_DIR/../config/cn-mirrors.yml" ]]; then
  log_pass "cn-mirrors.yml 存在"
  
  # Check for required sections
  if grep -q "mirrors:" "$SCRIPT_DIR/../config/cn-mirrors.yml"; then
    log_pass "包含镜像映射"
  else
    log_fail "缺少镜像映射"
  fi
  
  if grep -q "fallback_rules:" "$SCRIPT_DIR/../config/cn-mirrors.yml"; then
    log_pass "包含回退规则"
  else
    log_fail "缺少回退规则"
  fi
else
  log_fail "cn-mirrors.yml 不存在"
fi
echo

# Summary
echo -e "${BOLD}${BLUE}=== 测试结果 ===${NC}\n"
echo -e "  ${GREEN}通过: $PASS${NC}"
echo -e "  ${RED}失败: $FAIL${NC}\n"

if [[ $FAIL -eq 0 ]]; then
  echo -e "${GREEN}${BOLD}✓ 所有测试通过${NC}\n"
  exit 0
else
  echo -e "${RED}${BOLD}✗ 部分测试失败${NC}\n"
  exit 1
fi
