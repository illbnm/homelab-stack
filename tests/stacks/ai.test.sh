#!/bin/bash
# ─────────────────────────────────────────────────────────────
# AI Stack Integration Tests
# ─────────────────────────────────────────────────────────────

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STACK_DIR="$(dirname "$SCRIPT_DIR")/stacks/ai"

# Fallback for different execution contexts
if [ ! -d "$STACK_DIR" ]; then
    STACK_DIR="/home/gg/opt/agentwork/niuma/homelab-integration-tests/stacks/ai"
fi

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS=0
FAIL=0

test_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    PASS=$((PASS + 1))
}

test_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    FAIL=$((FAIL + 1))
}

test_info() {
    echo -e "${YELLOW}[INFO]${NC} $1"
}

# ─────────────────────────────────────────────────────────────
# Test 1: Docker Compose file validation
# ─────────────────────────────────────────────────────────────
test_compose_file() {
    test_info "测试 docker-compose.yml 语法..."
    
    if [ ! -f "$STACK_DIR/docker-compose.yml" ]; then
        test_fail "docker-compose.yml 不存在"
        return
    fi
    
    # Check YAML syntax
    if command -v docker &> /dev/null; then
        cd "$STACK_DIR"
        if docker compose config > /dev/null 2>&1; then
            test_pass "docker-compose.yml 语法正确"
        else
            test_fail "docker-compose.yml 语法错误"
        fi
    else
        test_info "Docker 未安装，跳过语法检查"
    fi
}

# ─────────────────────────────────────────────────────────────
# Test 2: Required services defined
# ─────────────────────────────────────────────────────────────
test_services_defined() {
    test_info "测试必需服务定义..."
    
    local required_services=("ollama" "open-webui" "stable-diffusion" "perplexica")
    
    for service in "${required_services[@]}"; do
        if grep -q "  $service:" "$STACK_DIR/docker-compose.yml"; then
            test_pass "服务 $service 已定义"
        else
            test_fail "服务 $service 未定义"
        fi
    done
}

# ─────────────────────────────────────────────────────────────
# Test 3: Health checks configured
# ─────────────────────────────────────────────────────────────
test_health_checks() {
    test_info "测试健康检查配置..."
    
    # Count healthcheck entries in the file
    local healthcheck_count
    healthcheck_count=$(grep -c "healthcheck:" "$STACK_DIR/docker-compose.yml" || echo "0")
    
    if [ "$healthcheck_count" -ge 4 ]; then
        test_pass "所有 4 个服务都配置了健康检查 (共 $healthcheck_count 个)"
    elif [ "$healthcheck_count" -ge 1 ]; then
        test_pass "部分服务配置了健康检查 (共 $healthcheck_count 个)"
    else
        test_fail "没有服务配置健康检查"
    fi
}

# ─────────────────────────────────────────────────────────────
# Test 4: Traefik labels configured
# ─────────────────────────────────────────────────────────────
test_traefik_labels() {
    test_info "测试 Traefik 标签配置..."
    
    if grep -q "traefik.enable=true" "$STACK_DIR/docker-compose.yml"; then
        test_pass "Traefik 标签已配置"
    else
        test_fail "Traefik 标签未配置"
    fi
    
    # Check for external proxy network
    if grep -q "proxy:" "$STACK_DIR/docker-compose.yml" && grep -q "external: true" "$STACK_DIR/docker-compose.yml"; then
        test_pass "外部 proxy 网络已配置"
    else
        test_fail "外部 proxy 网络未配置"
    fi
}

# ─────────────────────────────────────────────────────────────
# Test 5: Environment file exists
# ─────────────────────────────────────────────────────────────
test_env_file() {
    test_info "测试环境变量文件..."
    
    if [ -f "$STACK_DIR/.env.example" ]; then
        test_pass ".env.example 文件存在"
        
        # Check required variables
        local required_vars=("DOMAIN" "WEBUI_SECRET_KEY" "PERPLEXICA_SECRET_KEY")
        for var in "${required_vars[@]}"; do
            if grep -q "^$var=" "$STACK_DIR/.env.example"; then
                test_pass "环境变量 $var 已定义"
            else
                test_fail "环境变量 $var 未定义"
            fi
        done
    else
        test_fail ".env.example 文件不存在"
    fi
}

# ─────────────────────────────────────────────────────────────
# Test 6: README exists
# ─────────────────────────────────────────────────────────────
test_readme() {
    test_info "测试文档..."
    
    if [ -f "$STACK_DIR/README.md" ]; then
        test_pass "README.md 文件存在"
        
        # Check for required sections
        local required_sections=("快速开始" "GPU" "健康检查" "验收标准")
        for section in "${required_sections[@]}"; do
            if grep -q "$section" "$STACK_DIR/README.md"; then
                test_pass "README 包含 $section 章节"
            else
                test_fail "README 缺少 $section 章节"
            fi
        done
    else
        test_fail "README.md 文件不存在"
    fi
}

# ─────────────────────────────────────────────────────────────
# Test 7: Volume configuration
# ─────────────────────────────────────────────────────────────
test_volumes() {
    test_info "测试卷配置..."
    
    local required_volumes=("ollama-data" "open-webui-data" "sd-models" "sd-output" "perplexica-data")
    
    for volume in "${required_volumes[@]}"; do
        if grep -q "  $volume:" "$STACK_DIR/docker-compose.yml"; then
            test_pass "卷 $volume 已定义"
        else
            test_fail "卷 $volume 未定义"
        fi
    done
}

# ─────────────────────────────────────────────────────────────
# Test 8: Image versions locked
# ─────────────────────────────────────────────────────────────
test_image_versions() {
    test_info "测试镜像版本锁定..."
    
    # Check that no 'latest' tags are used (except for sd-webui which uses latest-sha)
    if grep -E "image:.*:latest$" "$STACK_DIR/docker-compose.yml" | grep -v "latest-sha" > /dev/null; then
        test_fail "发现未锁定版本的镜像 (latest tag)"
    else
        test_pass "所有镜像版本已锁定"
    fi
    
    # Check specific versions
    if grep -q "ollama/ollama:0.3" "$STACK_DIR/docker-compose.yml"; then
        test_pass "Ollama 镜像版本已锁定"
    else
        test_fail "Ollama 镜像版本未锁定"
    fi
    
    if grep -q "open-webui:0.3" "$STACK_DIR/docker-compose.yml"; then
        test_pass "Open WebUI 镜像版本已锁定"
    else
        test_fail "Open WebUI 镜像版本未锁定"
    fi
}

# ─────────────────────────────────────────────────────────────
# Test 9: Network isolation
# ─────────────────────────────────────────────────────────────
test_network_isolation() {
    test_info "测试网络隔离..."
    
    if grep -q "ai_internal:" "$STACK_DIR/docker-compose.yml"; then
        test_pass "内部网络 ai_internal 已定义"
        
        if grep -A 3 "ai_internal:" "$STACK_DIR/docker-compose.yml" | grep -q "internal: true"; then
            test_pass "内部网络配置为 internal"
        else
            test_info "内部网络未配置为 internal（可选）"
        fi
    else
        test_info "未定义专用内部网络（使用默认网络）"
    fi
}

# ─────────────────────────────────────────────────────────────
# Test 10: GPU configuration documented
# ─────────────────────────────────────────────────────────────
test_gpu_config() {
    test_info "测试 GPU 配置文档..."
    
    if grep -q "NVIDIA" "$STACK_DIR/docker-compose.yml" && grep -q "nvidia" "$STACK_DIR/docker-compose.yml"; then
        test_pass "NVIDIA GPU 配置已文档化"
    else
        test_info "NVIDIA GPU 配置未文档化"
    fi
    
    if grep -q "AMD" "$STACK_DIR/docker-compose.yml" || grep -q "ROCm" "$STACK_DIR/docker-compose.yml"; then
        test_pass "AMD GPU 配置已文档化"
    else
        test_info "AMD GPU 配置未文档化"
    fi
    
    if grep -q "CPU" "$STACK_DIR/docker-compose.yml"; then
        test_pass "CPU 模式已文档化"
    else
        test_info "CPU 模式未文档化"
    fi
}

# ─────────────────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────────────────
main() {
    echo "========================================"
    echo "  AI Stack Integration Tests"
    echo "========================================"
    echo ""
    
    test_compose_file
    test_services_defined
    test_health_checks
    test_traefik_labels
    test_env_file
    test_readme
    test_volumes
    test_image_versions
    test_network_isolation
    test_gpu_config
    
    echo ""
    echo "========================================"
    echo "  测试结果汇总"
    echo "========================================"
    echo -e "  ${GREEN}通过${NC}: $PASS"
    echo -e "  ${RED}失败${NC}: $FAIL"
    echo "========================================"
    
    if [ $FAIL -eq 0 ]; then
        echo -e "${GREEN}所有测试通过!${NC}"
        exit 0
    else
        echo -e "${RED}部分测试失败!${NC}"
        exit 1
    fi
}

main "$@"
