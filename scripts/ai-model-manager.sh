#!/bin/bash
# =============================================================================
# HomeLab AI Model Manager
# Manages Ollama models with GPU detection and storage optimization.
# Usage: ./ai-model-manager.sh [command]
# =============================================================================
set -euo pipefail

OLLAMA_CONTAINER="${OLLAMA_CONTAINER:-ollama}"
OLLAMA_API="http://localhost:11434"

# Colors
RED=''; GREEN=''; YELLOW=''; CYAN=''; RESET=''
log_info()  { echo -e "${GREEN}[INFO]${RESET} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${RESET} $*"; }
log_error() { echo -e "${RED}[ERROR]${RESET} $*" >&2; }

# Recommended models
declare -A MODELS=(
    ["qwen2.5:14b"]="通用对话/编程 (9GB)"
    ["codellama:7b"]="代码生成 (4GB)"
    ["llama3.2:3b"]="轻量对话 (2GB)"
    ["llava:7b"]="图像理解/OCR (4GB)"
    ["nomic-embed-text"]="文本嵌入 RAG (274MB)"
)

detect_gpu() {
    log_info "检测 GPU..."
    
    # Check NVIDIA
    if docker exec "$OLLAMA_CONTAINER" nvidia-smi &>/dev/null; then
        log_info "检测到 NVIDIA GPU"
        nvidia-smi --query-gpu=name,memory.total --format=csv,noheader
        return 0
    fi
    
    # Check AMD
    if docker exec "$OLLAMA_CONTAINER" rocminfo &>/dev/null; then
        log_info "检测到 AMD GPU"
        docker exec "$OLLAMA_CONTAINER" rocminfo | grep "Marketing Name" | head -1
        return 0
    fi
    
    log_warn "未检测到 GPU，将使用 CPU 模式"
    return 1
}

install_model() {
    local model="$1"
    log_info "安装模型: $model"
    docker exec "$OLLAMA_CONTAINER" ollama pull "$model"
}

install_recommended() {
    log_info "安装推荐模型..."
    for model in "${!MODELS[@]}"; do
        log_info "安装: $model - ${MODELS[$model]}"
        install_model "$model"
    done
    log_info "推荐模型安装完成"
}

list_models() {
    log_info "已安装模型:"
    docker exec "$OLLAMA_CONTAINER" ollama list
}

remove_model() {
    local model="$1"
    log_info "删除模型: $model"
    docker exec "$OLLAMA_CONTAINER" ollama rm "$model"
}

show_storage() {
    log_info "存储使用情况:"
    echo ""
    echo "=== Ollama 模型 ==="
    docker exec "$OLLAMA_CONTAINER" du -sh /root/.ollama/models 2>/dev/null || echo "N/A"
    
    echo ""
    echo "=== 所有 AI 卷 ==="
    docker system df -v | grep -E "(ollama|webui|sd|perplexica)" || echo "N/A"
    
    echo ""
    echo "=== 磁盘空间 ==="
    df -h /var/lib/docker
}

case "${1:-help}" in
    detect-gpu)
        detect_gpu
        ;;
    install)
        if [ -z "${2:-}" ]; then
            log_error "用法: $0 install <model-name>"
            exit 1
        fi
        install_model "$2"
        ;;
    install-llms)
        install_recommended
        ;;
    list)
        list_models
        ;;
    remove)
        if [ -z "${2:-}" ]; then
            log_error "用法: $0 remove <model-name>"
            exit 1
        fi
        remove_model "$2"
        ;;
    storage)
        show_storage
        ;;
    help|*)
        echo "HomeLab AI Model Manager"
        echo ""
        echo "用法: $0 [command]"
        echo ""
        echo "命令:"
        echo "  detect-gpu     检测 GPU (NVIDIA/AMD/CPU)"
        echo "  install <name> 安装指定模型"
        echo "  install-llms   安装推荐模型"
        echo "  list           列出已安装模型"
        echo "  remove <name>  删除指定模型"
        echo "  storage        显示存储使用情况"
        echo ""
        echo "推荐模型:"
        for model in "${!MODELS[@]}"; do
            printf "  %-20s %s\n" "$model" "${MODELS[$model]}"
        done
        ;;
esac
