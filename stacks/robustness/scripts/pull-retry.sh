#!/bin/sh
# Homelab Stack #8 - Docker 镜像拉取重试脚本
# 用于处理网络波动导致的镜像拉取失败，自动重试并使用备用镜像源

set -e

# 配置
MAX_RETRIES=${MAX_RETRIES:-3}
RETRY_DELAY=${RETRY_DELAY:-5}
TIMEOUT=${TIMEOUT:-30}

# 镜像源列表 (按优先级排序)
MIRRORS=(
    "docker.io"
    "docker.m.daocloud.io"
    "docker.mirrors.ustc.edu.cn"
    "registry.docker-cn.com"
    "hub-mirror.c.163.com"
    "ccr.ccs.tencentyun.com"
)

# 日志函数
log() {
    echo "[$(date -Iseconds)] $*"
}

# 检查镜像是否已存在
image_exists() {
    docker image inspect "$1" > /dev/null 2>&1
}

# 尝试从指定镜像源拉取
try_pull() {
    local image="$1"
    local mirror="$2"
    local pull_image
    
    if [ "$mirror" = "docker.io" ]; then
        pull_image="$image"
    else
        # 将 docker.io/library/image 转换为镜像源格式
        pull_image="${mirror}/${image#docker.io/}"
        pull_image="${pull_image#library/}"
    fi
    
    log "尝试从 ${mirror} 拉取：${pull_image}"
    
    if timeout "$TIMEOUT" docker pull "$pull_image" 2>&1; then
        # 如果从镜像源拉取成功，重新打标签为原始镜像名
        if [ "$mirror" != "docker.io" ] && [ "$pull_image" != "$image" ]; then
            docker tag "$pull_image" "$image" 2>/dev/null || true
        fi
        return 0
    fi
    
    return 1
}

# 主函数：带重试的镜像拉取
pull_with_retry() {
    local image="$1"
    local attempt=0
    
    log "开始拉取镜像：$image"
    
    # 检查是否已存在
    if image_exists "$image"; then
        log "镜像已存在：$image"
        return 0
    fi
    
    # 重试拉取
    while [ $attempt -lt $MAX_RETRIES ]; do
        attempt=$((attempt + 1))
        log "尝试第 $attempt/$MAX_RETRIES 次拉取"
        
        # 遍历所有镜像源
        for mirror in "${MIRRORS[@]}"; do
            if try_pull "$image" "$mirror"; then
                log "✓ 成功拉取镜像：$image (源：$mirror)"
                return 0
            fi
            log "从 $mirror 拉取失败，尝试下一个镜像源..."
            sleep "$RETRY_DELAY"
        done
        
        log "所有镜像源尝试失败，等待后重试..."
        sleep $((RETRY_DELAY * attempt))
    done
    
    log "✗ 失败：无法拉取镜像 $image (已尝试 $MAX_RETRIES 次)"
    return 1
}

# 批量拉取镜像
pull_batch() {
    local failed=0
    local success=0
    
    for image in "$@"; do
        if pull_with_retry "$image"; then
            success=$((success + 1))
        else
            failed=$((failed + 1))
        fi
    done
    
    log "批量拉取完成：成功 $success, 失败 $failed"
    return $failed
}

# 显示帮助
show_help() {
    cat << EOF
Docker 镜像拉取重试工具

用法:
  $0 pull <image>           拉取单个镜像 (带重试)
  $0 batch <image1> <image2> ...  批量拉取多个镜像
  $0 check <image>          检查镜像是否存在
  $0 list-mirrors           列出配置的镜像源
  $0 help                   显示此帮助信息

环境变量:
  MAX_RETRIES    最大重试次数 (默认：3)
  RETRY_DELAY    重试间隔秒数 (默认：5)
  TIMEOUT        单次拉取超时秒数 (默认：30)

示例:
  $0 pull nginx:1.25.4
  $0 batch alpine:3.19 redis:7.2 postgres:16
  $0 check nginx:1.25.4

镜像源列表:
EOF
    for mirror in "${MIRRORS[@]}"; do
        echo "  - $mirror"
    done
}

# 列出镜像源
list_mirrors() {
    echo "配置的镜像源:"
    for mirror in "${MIRRORS[@]}"; do
        echo "  - $mirror"
    done
}

# 检查镜像
check_image() {
    local image="$1"
    if image_exists "$image"; then
        echo "✓ 镜像存在：$image"
        docker image inspect --format='{{.RepoTags}} {{.Created}}' "$image"
        return 0
    else
        echo "✗ 镜像不存在：$image"
        return 1
    fi
}

# 主入口
case "${1:-help}" in
    pull)
        if [ -z "$2" ]; then
            echo "错误：请指定镜像名称"
            exit 1
        fi
        pull_with_retry "$2"
        ;;
    batch)
        shift
        if [ $# -eq 0 ]; then
            echo "错误：请指定至少一个镜像名称"
            exit 1
        fi
        pull_batch "$@"
        ;;
    check)
        if [ -z "$2" ]; then
            echo "错误：请指定镜像名称"
            exit 1
        fi
        check_image "$2"
        ;;
    list-mirrors)
        list_mirrors
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        echo "未知命令：$1"
        show_help
        exit 1
        ;;
esac
