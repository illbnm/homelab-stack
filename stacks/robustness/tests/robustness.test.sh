#!/bin/bash
# Homelab Stack #8 - Robustness 集成测试脚本
# 测试国内网络适配和环境鲁棒性功能

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 测试统计
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# 日志函数
log_test() {
    echo -e "\n${YELLOW}[TEST]${NC} $1"
}

log_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    TESTS_RUN=$((TESTS_RUN + 1))
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    TESTS_RUN=$((TESTS_RUN + 1))
}

# 检查 Docker 是否运行
check_docker() {
    if ! docker info > /dev/null 2>&1; then
        echo -e "${RED}错误：Docker 未运行${NC}"
        exit 1
    fi
}

# 测试 1: 配置文件存在性
test_config_files() {
    log_test "测试配置文件存在性"
    
    local files=(
        "docker-compose.yml"
        ".env.example"
        "config/dnsmasq.conf"
        "config/nginx.conf"
        "config/registry.yml"
        "scripts/pull-retry.sh"
        "scripts/network-health.sh"
    )
    
    local all_exist=true
    for file in "${files[@]}"; do
        if [ ! -f "$file" ]; then
            echo "  缺失文件：$file"
            all_exist=false
        fi
    done
    
    if $all_exist; then
        log_pass "所有配置文件存在"
    else
        log_fail "部分配置文件缺失"
    fi
}

# 测试 2: docker-compose.yml 语法验证
test_compose_syntax() {
    log_test "测试 docker-compose.yml 语法"
    
    if docker compose config > /dev/null 2>&1; then
        log_pass "docker-compose.yml 语法正确"
    else
        log_fail "docker-compose.yml 语法错误"
        docker compose config 2>&1 | head -20
    fi
}

# 测试 3: 环境变量模板验证
test_env_template() {
    log_test "测试环境变量模板"
    
    if [ -f ".env.example" ]; then
        # 检查必要变量
        local required_vars=("DOMAIN" "TZ" "DOCKER_MIRROR_URL" "DNS_PRIMARY")
        local all_present=true
        
        for var in "${required_vars[@]}"; do
            if ! grep -q "^${var}=" ".env.example"; then
                echo "  缺失变量：$var"
                all_present=false
            fi
        done
        
        if $all_present; then
            log_pass "环境变量模板完整"
        else
            log_fail "环境变量模板缺少必要变量"
        fi
    else
        log_fail ".env.example 文件不存在"
    fi
}

# 测试 4: 脚本可执行性
test_scripts_executable() {
    log_test "测试脚本可执行性"
    
    local scripts=(
        "scripts/pull-retry.sh"
        "scripts/network-health.sh"
    )
    
    local all_valid=true
    for script in "${scripts[@]}"; do
        if [ -f "$script" ]; then
            if bash -n "$script" 2>/dev/null; then
                echo "  ✓ $script 语法正确"
            else
                echo "  ✗ $script 语法错误"
                all_valid=false
            fi
        else
            echo "  ✗ $script 不存在"
            all_valid=false
        fi
    done
    
    if $all_valid; then
        log_pass "所有脚本语法正确"
    else
        log_fail "部分脚本存在问题"
    fi
}

# 测试 5: 镜像源配置验证
test_mirror_config() {
    log_test "测试镜像源配置"
    
    # 检查 pull-retry.sh 中的镜像源列表
    if grep -q "docker.m.daocloud.io" "scripts/pull-retry.sh" && \
       grep -q "docker.mirrors.ustc.edu.cn" "scripts/pull-retry.sh"; then
        log_pass "镜像源配置包含国内加速源"
    else
        log_fail "镜像源配置不完整"
    fi
}

# 测试 6: DNS 配置验证
test_dns_config() {
    log_test "测试 DNS 配置"
    
    if grep -q "223.5.5.5" "config/dnsmasq.conf" && \
       grep -q "223.6.6.6" "config/dnsmasq.conf"; then
        log_pass "DNS 配置包含阿里 DNS"
    else
        log_fail "DNS 配置不完整"
    fi
}

# 测试 7: NTP 配置验证
test_ntp_config() {
    log_test "测试 NTP 配置"
    
    if grep -q "ntp.aliyun.com" "docker-compose.yml" || \
       grep -q "ntp.tencent.com" "docker-compose.yml"; then
        log_pass "NTP 配置包含国内服务器"
    else
        log_fail "NTP 配置不完整"
    fi
}

# 测试 8: 健康检查配置验证
test_healthcheck_config() {
    log_test "测试健康检查配置"
    
    local healthcheck_count
    healthcheck_count=$(grep -c "healthcheck:" "docker-compose.yml" || echo "0")
    
    if [ "$healthcheck_count" -ge 3 ]; then
        log_pass "健康检查配置完整 ($healthcheck_count 个服务)"
    else
        log_fail "健康检查配置不足 (仅 $healthcheck_count 个)"
    fi
}

# 测试 9: 网络隔离配置验证
test_network_isolation() {
    log_test "测试网络隔离配置"
    
    if grep -q "robustness_internal" "docker-compose.yml" && \
       grep -q "subnet: 172.28" "docker-compose.yml"; then
        log_pass "网络隔离配置正确"
    else
        log_fail "网络隔离配置不完整"
    fi
}

# 测试 10: Traefik 标签配置验证
test_traefik_labels() {
    log_test "测试 Traefik 标签配置"
    
    if grep -q "traefik.enable=true" "docker-compose.yml" && \
       grep -q "traefik.http.routers" "docker-compose.yml"; then
        log_pass "Traefik 标签配置正确"
    else
        log_fail "Traefik 标签配置不完整"
    fi
}

# 测试 11: 卷配置验证
test_volume_config() {
    log_test "测试卷配置"
    
    if grep -q "volumes:" "docker-compose.yml" && \
       grep -q "registry-data:" "docker-compose.yml"; then
        log_pass "卷配置正确"
    else
        log_fail "卷配置不完整"
    fi
}

# 测试 12: 日志配置验证
test_logging_config() {
    log_test "测试日志配置"
    
    if grep -q "json-file" "docker-compose.yml" && \
       grep -q "max-size" "docker-compose.yml"; then
        log_pass "日志配置正确"
    else
        log_fail "日志配置不完整"
    fi
}

# 测试 13: 镜像版本锁定验证
test_image_tags() {
    log_test "测试镜像版本锁定"
    
    # 检查是否有使用 latest 标签
    if grep -qE "image:.*:latest" "docker-compose.yml"; then
        log_fail "发现使用 latest 标签的镜像"
    else
        log_pass "所有镜像版本已锁定"
    fi
}

# 测试 14: 文档完整性
test_documentation() {
    log_test "测试文档完整性"
    
    if [ -f "README.md" ]; then
        local required_sections=("功能" "部署" "配置" "使用")
        local all_present=true
        
        for section in "${required_sections[@]}"; do
            if ! grep -qi "$section" "README.md"; then
                echo "  缺失章节：$section"
                all_present=false
            fi
        done
        
        if $all_present; then
            log_pass "文档完整"
        else
            log_fail "文档缺少必要章节"
        fi
    else
        log_fail "README.md 不存在"
    fi
}

# 运行所有测试
run_all_tests() {
    echo "========================================"
    echo "  Homelab #8 Robustness 集成测试"
    echo "  开始时间：$(date -Iseconds)"
    echo "========================================"
    
    check_docker
    
    test_config_files
    test_compose_syntax
    test_env_template
    test_scripts_executable
    test_mirror_config
    test_dns_config
    test_ntp_config
    test_healthcheck_config
    test_network_isolation
    test_traefik_labels
    test_volume_config
    test_logging_config
    test_image_tags
    test_documentation
    
    echo ""
    echo "========================================"
    echo "  测试结果汇总"
    echo "========================================"
    echo "  总测试数：$TESTS_RUN"
    echo -e "  ${GREEN}通过：$TESTS_PASSED${NC}"
    echo -e "  ${RED}失败：$TESTS_FAILED${NC}"
    echo "========================================"
    
    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "\n${GREEN}✓ 所有测试通过!${NC}"
        return 0
    else
        echo -e "\n${RED}✗ 部分测试失败${NC}"
        return 1
    fi
}

# 主入口
cd "$(dirname "$0")/.." || exit 1

case "${1:-all}" in
    all)
        run_all_tests
        ;;
    *)
        "test_$1" 2>/dev/null || {
            echo "未知测试：$1"
            echo "可用测试：all, config_files, compose_syntax, env_template, scripts_executable,"
            echo "           mirror_config, dns_config, ntp_config, healthcheck_config,"
            echo "           network_isolation, traefik_labels, volume_config, logging_config,"
            echo "           image_tags, documentation"
            exit 1
        }
        ;;
esac
