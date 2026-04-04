#!/bin/bash
# cn-adaptation.test.sh - 中国网络适配测试
# 测试镜像替换和 Docker 镜像加速配置

set -u

# 测试镜像替换脚本正确性
test_cn_image_replacement() {
    local script="${ROOT_DIR}/scripts/localize-images.sh"
    
    if [[ ! -f "$script" ]]; then
        local start_time=$(date +%s.%N)
        local end_time=$(date +%s.%N)
        local duration=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")
        _record_assertion "SKIP" "CN image replacement script exists" "$duration"
        return 0
    fi
    
    # 执行 dry-run 测试
    if bash "$script" --cn --dry-run &> /dev/null; then
        local start_time=$(date +%s.%N)
        local end_time=$(date +%s.%N)
        local duration=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")
        _record_assertion "PASS" "CN image replacement dry-run" "$duration"
    else
        local start_time=$(date +%s.%N)
        local end_time=$(date +%s.%N)
        local duration=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")
        _record_assertion "FAIL" "CN image replacement dry-run" "$duration" "Script execution failed"
    fi
    
    # 检查无 GCR 镜像
    local gcr_count=$(grep -r 'gcr\.io' "${ROOT_DIR}/stacks/" 2>/dev/null | wc -l)
    if [[ "$gcr_count" -eq 0 ]]; then
        local start_time=$(date +%s.%N)
        local end_time=$(date +%s.%N)
        local duration=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")
        _record_assertion "PASS" "No GCR images in stacks" "$duration"
    else
        local start_time=$(date +%s.%N)
        local end_time=$(date +%s.%N)
        local duration=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")
        _record_assertion "FAIL" "No GCR images in stacks" "$duration" "Found $gcr_count GCR references"
    fi
}

# 测试 Docker 镜像加速配置
test_docker_mirror_config() {
    local script="${ROOT_DIR}/scripts/setup-cn-mirrors.sh"
    
    if [[ ! -f "$script" ]]; then
        local start_time=$(date +%s.%N)
        local end_time=$(date +%s.%N)
        local duration=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")
        _record_assertion "SKIP" "CN mirrors setup script exists" "$duration"
        return 0
    fi
    
    # 执行 dry-run 测试
    if bash "$script" --dry-run &> /dev/null; then
        local start_time=$(date +%s.%N)
        local end_time=$(date +%s.%N)
        local duration=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")
        _record_assertion "PASS" "CN mirrors setup dry-run" "$duration"
    else
        local start_time=$(date +%s.%N)
        local end_time=$(date +%s.%N)
        local duration=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")
        _record_assertion "FAIL" "CN mirrors setup dry-run" "$duration" "Script execution failed"
    fi
}

# 测试 Docker Hub 镜像加速
test_dockerhub_mirror() {
    # 检查 Docker daemon 配置
    if [[ -f "/etc/docker/daemon.json" ]]; then
        if grep -q "registry-mirrors" /etc/docker/daemon.json 2>/dev/null; then
            local start_time=$(date +%s.%N)
            local end_time=$(date +%s.%N)
            local duration=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")
            _record_assertion "PASS" "Docker registry mirrors configured" "$duration"
        else
            local start_time=$(date +%s.%N)
            local end_time=$(date +%s.%N)
            local duration=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")
            _record_assertion "SKIP" "Docker registry mirrors configured" "$duration"
        fi
    else
        local start_time=$(date +%s.%N)
        local end_time=$(date +%s.%N)
        local duration=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")
        _record_assertion "SKIP" "Docker registry mirrors configured" "$duration"
    fi
}
