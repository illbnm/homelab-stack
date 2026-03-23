#!/usr/bin/env bash
# assert.sh - 测试断言库
# 提供常用断言函数用于集成测试

set -u

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 计数器
ASSERTIONS_PASSED=0
ASSERTIONS_FAILED=0
ASSERTIONS_SKIPPED=0

# 断言：相等
assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-值相等检查}"
    
    if [[ "$expected" == "$actual" ]]; then
        ((ASSERTIONS_PASSED++))
        echo -e "${GREEN}✓${NC} $message"
        return 0
    else
        ((ASSERTIONS_FAILED++))
        echo -e "${RED}✗${NC} $message"
        echo -e "  期望：$expected"
        echo -e "  实际：$actual"
        return 1
    fi
}

# 断言：不为空
assert_not_empty() {
    local value="$1"
    local message="${2:-值非空检查}"
    
    if [[ -n "$value" ]]; then
        ((ASSERTIONS_PASSED++))
        echo -e "${GREEN}✓${NC} $message"
        return 0
    else
        ((ASSERTIONS_FAILED++))
        echo -e "${RED}✗${NC} $message"
        echo -e "  值：(空)"
        return 1
    fi
}

# 断言：文件存在
assert_file_exists() {
    local filepath="$1"
    local message="${2:-文件存在检查}"
    
    if [[ -f "$filepath" ]]; then
        ((ASSERTIONS_PASSED++))
        echo -e "${GREEN}✓${NC} $message: $filepath"
        return 0
    else
        ((ASSERTIONS_FAILED++))
        echo -e "${RED}✗${NC} $message: $filepath"
        return 1
    fi
}

# 断言：目录存在
assert_dir_exists() {
    local dirpath="$1"
    local message="${2:-目录存在检查}"
    
    if [[ -d "$dirpath" ]]; then
        ((ASSERTIONS_PASSED++))
        echo -e "${GREEN}✓${NC} $message: $dirpath"
        return 0
    else
        ((ASSERTIONS_FAILED++))
        echo -e "${RED}✗${NC} $message: $dirpath"
        return 1
    fi
}

# 断言：命令成功
assert_command_success() {
    local cmd="$1"
    local message="${2:-命令执行检查}"
    
    if eval "$cmd" > /dev/null 2>&1; then
        ((ASSERTIONS_PASSED++))
        echo -e "${GREEN}✓${NC} $message"
        return 0
    else
        ((ASSERTIONS_FAILED++))
        echo -e "${RED}✗${NC} $message"
        echo -e "  命令：$cmd"
        return 1
    fi
}

# 断言：HTTP 状态码
assert_http_status() {
    local expected="$1"
    local url="$2"
    local message="${3:-HTTP 状态检查}"
    
    local actual
    actual=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null)
    
    if [[ "$expected" == "$actual" ]]; then
        ((ASSERTIONS_PASSED++))
        echo -e "${GREEN}✓${NC} $message: $url -> $actual"
        return 0
    else
        ((ASSERTIONS_FAILED++))
        echo -e "${RED}✗${NC} $message: $url"
        echo -e "  期望：$expected"
        echo -e "  实际：$actual"
        return 1
    fi
}

# 断言：容器运行中
assert_container_running() {
    local container="$1"
    local message="${2:-容器运行检查}"
    
    if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${container}$"; then
        ((ASSERTIONS_PASSED++))
        echo -e "${GREEN}✓${NC} $message: $container"
        return 0
    else
        ((ASSERTIONS_FAILED++))
        echo -e "${RED}✗${NC} $message: $container"
        return 1
    fi
}

# 断言：端口监听
assert_port_listening() {
    local port="$1"
    local message="${2:-端口监听检查}"
    
    if command -v ss &> /dev/null; then
        if ss -tln | grep -q ":${port} "; then
            ((ASSERTIONS_PASSED++))
            echo -e "${GREEN}✓${NC} $message: $port"
            return 0
        fi
    elif command -v netstat &> /dev/null; then
        if netstat -tln | grep -q ":${port} "; then
            ((ASSERTIONS_PASSED++))
            echo -e "${GREEN}✓${NC} $message: $port"
            return 0
        fi
    fi
    
    ((ASSERTIONS_FAILED++))
    echo -e "${RED}✗${NC} $message: $port"
    return 1
}

# 跳过测试
skip_test() {
    local reason="$1"
    ((ASSERTIONS_SKIPPED++))
    echo -e "${YELLOW}○${NC} 跳过：$reason"
}

# 获取断言统计
get_assertion_stats() {
    echo "passed=$ASSERTIONS_PASSED"
    echo "failed=$ASSERTIONS_FAILED"
    echo "skipped=$ASSERTIONS_SKIPPED"
}

# 重置计数器
reset_counters() {
    ASSERTIONS_PASSED=0
    ASSERTIONS_FAILED=0
    ASSERTIONS_SKIPPED=0
}
