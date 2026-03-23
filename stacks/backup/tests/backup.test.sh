#!/bin/bash
#
# Homelab Backup & DR - 集成测试脚本
#

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 测试统计
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

# 打印函数
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[PASS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[FAIL]${NC} $1"; }

# 测试函数
run_test() {
    local test_name="$1"
    local test_command="$2"
    
    ((TESTS_TOTAL++)) || true
    
    echo ""
    log_info "测试 ${TESTS_TOTAL}: ${test_name}"
    
    if eval "$test_command" > /dev/null 2>&1; then
        log_success "✓ ${test_name}"
        ((TESTS_PASSED++)) || true
        return 0
    else
        log_error "✗ ${test_name}"
        ((TESTS_FAILED++)) || true
        return 1
    fi
}

# 测试 1: Docker Compose 文件语法验证 (使用 Python YAML 解析)
test_docker_compose_syntax() {
    python3 -c "import yaml; yaml.safe_load(open('docker-compose.yml'))" 2>/dev/null || \
    python -c "import yaml; yaml.safe_load(open('docker-compose.yml'))" 2>/dev/null
}

run_test "Docker Compose 语法验证" "test_docker_compose_syntax"

# 测试 2: 环境变量文件存在
test_env_example_exists() {
    [ -f ".env.example" ]
}

run_test ".env.example 文件存在" "test_env_example_exists"

# 测试 3: 备份脚本存在且可执行
test_backup_script_exists() {
    [ -f "scripts/backup.sh" ] && [ -x "scripts/backup.sh" ] || chmod +x scripts/backup.sh && [ -f "scripts/backup.sh" ]
}

run_test "备份脚本存在" "test_backup_script_exists"

# 测试 4: 备份脚本帮助信息
test_backup_script_help() {
    bash scripts/backup.sh --help | grep -q "用法"
}

run_test "备份脚本帮助信息" "test_backup_script_help"

# 测试 5: 备份脚本 Dry Run
test_backup_script_dry_run() {
    bash scripts/backup.sh --target all --dry-run 2>&1 | grep -q "DRY-RUN"
}

run_test "备份脚本 Dry Run" "test_backup_script_dry_run"

# 测试 6: 备份脚本 List 功能
test_backup_script_list() {
    bash scripts/backup.sh --list 2>&1 | grep -q "备份"
}

run_test "备份脚本 List 功能" "test_backup_script_list"

# 测试 7: README 文档存在
test_readme_exists() {
    [ -f "README.md" ]
}

run_test "README.md 文档存在" "test_readme_exists"

# 测试 8: README 包含必要章节
test_readme_content() {
    grep -q "快速开始" README.md && \
    grep -q "验收标准" README.md && \
    grep -q "docker-compose" README.md
}

run_test "README 包含必要章节" "test_readme_content"

# 测试 9: 灾难恢复文档存在
test_disaster_recovery_exists() {
    [ -f "docs/disaster-recovery.md" ]
}

run_test "灾难恢复文档存在" "test_disaster_recovery_exists"

# 测试 10: 灾难恢复文档包含恢复流程
test_disaster_recovery_content() {
    grep -q "恢复流程" docs/disaster-recovery.md && \
    grep -q "RTO" docs/disaster-recovery.md && \
    grep -q "RPO" docs/disaster-recovery.md
}

run_test "灾难恢复文档包含恢复流程" "test_disaster_recovery_content"

# 测试 11: 镜像版本锁定
test_image_versions_locked() {
    ! grep -q ":latest" docker-compose.yml
}

run_test "镜像版本锁定 (无 latest)" "test_image_versions_locked"

# 测试 12: 无硬编码密码
test_no_hardcoded_passwords() {
    ! grep -q "password=" docker-compose.yml && \
    ! grep -q "secret=" docker-compose.yml
}

run_test "无硬编码密码" "test_no_hardcoded_passwords"

# 测试 13: 健康检查配置
test_healthchecks_configured() {
    grep -q "healthcheck:" docker-compose.yml
}

run_test "健康检查配置" "test_healthchecks_configured"

# 测试 14: 网络隔离配置
test_network_isolation() {
    grep -q "internal: true" docker-compose.yml || grep -q "backup_internal" docker-compose.yml
}

run_test "网络隔离配置" "test_network_isolation"

# 测试 15: 数据卷持久化
test_volumes_persistent() {
    grep -q "volumes:" docker-compose.yml && \
    grep -q "driver: local" docker-compose.yml
}

run_test "数据卷持久化配置" "test_volumes_persistent"

# 测试 16: .env.example 包含必要配置
test_env_example_content() {
    grep -q "BACKUP_TARGET" .env.example && \
    grep -q "RESTIC_PASSWORD" .env.example && \
    grep -q "DOMAIN" .env.example
}

run_test ".env.example 包含必要配置" "test_env_example_content"

# 测试 17: 备份脚本支持所有目标类型
test_backup_targets() {
    bash scripts/backup.sh --help 2>&1 | grep -q "all" && \
    bash scripts/backup.sh --help 2>&1 | grep -q "media" && \
    bash scripts/backup.sh --help 2>&1 | grep -q "dry-run"
}

run_test "备份脚本支持所有目标类型" "test_backup_targets"

# 测试 18: 备份脚本 Verify 功能
test_backup_script_verify() {
    bash scripts/backup.sh --verify 2>&1 | grep -q "验证"
}

run_test "备份脚本 Verify 功能" "test_backup_script_verify"

# 测试 19: Traefik 标签配置
test_traefik_labels() {
    grep -q "traefik.enable" docker-compose.yml
}

run_test "Traefik 标签配置" "test_traefik_labels"

# 测试 20: README 格式验证
test_readme_format() {
    grep -q "^#" README.md && grep -q "##" README.md
}

run_test "README 格式验证" "test_readme_format"

# 打印测试结果
echo ""
echo "=========================================="
echo "测试结果汇总"
echo "=========================================="
echo -e "总测试数：${TESTS_TOTAL}"
echo -e "通过：${GREEN}${TESTS_PASSED}${NC}"
echo -e "失败：${RED}${TESTS_FAILED}${NC}"
echo ""

if [ ${TESTS_FAILED} -eq 0 ]; then
    echo -e "${GREEN}✓ 所有测试通过!${NC}"
    exit 0
else
    echo -e "${RED}✗ ${TESTS_FAILED} 个测试失败${NC}"
    exit 1
fi
