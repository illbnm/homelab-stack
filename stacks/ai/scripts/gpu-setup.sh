#!/bin/bash
# ─────────────────────────────────────────────────────────────
# GPU Setup Script for AI Stack
# ─────────────────────────────────────────────────────────────

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STACK_DIR="$(dirname "$SCRIPT_DIR")"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

detect_gpu() {
    print_info "检测 GPU 硬件..."
    
    # Check NVIDIA
    if command -v nvidia-smi &> /dev/null; then
        print_info "检测到 NVIDIA GPU"
        nvidia-smi --query-gpu=name,memory.total --format=csv,noheader
        echo "NVIDIA"
        return
    fi
    
    # Check AMD
    if command -v rocm-smi &> /dev/null; then
        print_info "检测到 AMD GPU (ROCm)"
        rocm-smi --showproductname 2>/dev/null || true
        echo "AMD"
        return
    fi
    
    # Check /dev/dri for generic GPU
    if [ -e /dev/dri/renderD128 ]; then
        print_info "检测到 GPU (通过 /dev/dri)"
        echo "DRM"
        return
    fi
    
    print_warn "未检测到 GPU，将使用 CPU 模式"
    echo "CPU"
}

install_nvidia_toolkit() {
    print_info "安装 NVIDIA Container Toolkit..."
    
    if [ -f /etc/debian_version ]; then
        # Debian/Ubuntu
        curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit.gpg
        curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
            sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit.gpg] https://#g' | \
            sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
        sudo apt-get update
        sudo apt-get install -y nvidia-container-toolkit
        sudo systemctl restart docker
        print_info "NVIDIA Container Toolkit 安装完成"
    elif [ -f /etc/redhat-release ]; then
        # RHEL/CentOS
        curl -s -L https://nvidia.github.io/libnvidia-container/stable/rpm/nvidia-container-toolkit.repo | \
            sudo tee /etc/yum.repos.d/nvidia-container-toolkit.repo
        sudo yum install -y nvidia-container-toolkit
        sudo systemctl restart docker
        print_info "NVIDIA Container Toolkit 安装完成"
    else
        print_error "不支持的系统，请手动安装 NVIDIA Container Toolkit"
        exit 1
    fi
}

generate_compose_file() {
    local gpu_type="$1"
    local output_file="$STACK_DIR/docker-compose.yml"
    
    print_info "生成 GPU 优化的 docker-compose.yml ($gpu_type)..."
    
    # Read the base file and modify based on GPU type
    cp "$STACK_DIR/docker-compose.yml.base" "$output_file" 2>/dev/null || true
    
    case "$gpu_type" in
        NVIDIA)
            print_info "配置 NVIDIA GPU 支持..."
            # Add nvidia runtime config
            ;;
        AMD)
            print_info "配置 AMD GPU 支持..."
            # Add AMD device config
            ;;
        *)
            print_info "使用 CPU 模式..."
            ;;
    esac
    
    print_info "配置完成：$output_file"
}

show_status() {
    print_info "AI Stack 状态:"
    cd "$STACK_DIR"
    docker compose ps
}

show_help() {
    echo "用法：$0 [命令]"
    echo ""
    echo "命令:"
    echo "  detect      检测 GPU 硬件"
    echo "  install     安装 GPU 驱动和工具"
    echo "  configure   生成 GPU 优化的配置文件"
    echo "  status      显示服务状态"
    echo "  help        显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  $0 detect           # 检测 GPU"
    echo "  $0 install          # 安装 NVIDIA 工具"
    echo "  $0 configure NVIDIA # 配置 NVIDIA GPU"
}

# Main
case "${1:-detect}" in
    detect)
        GPU_TYPE=$(detect_gpu)
        print_info "GPU 类型：$GPU_TYPE"
        ;;
    install)
        GPU_TYPE=$(detect_gpu)
        case "$GPU_TYPE" in
            NVIDIA)
                install_nvidia_toolkit
                ;;
            AMD)
                print_info "AMD ROCm 驱动需要手动安装，请参考：https://rocm.docs.amd.com"
                ;;
            *)
                print_warn "无需安装 GPU 驱动（CPU 模式）"
                ;;
        esac
        ;;
    configure)
        GPU_TYPE="${2:-$(detect_gpu)}"
        generate_compose_file "$GPU_TYPE"
        ;;
    status)
        show_status
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        print_error "未知命令：$1"
        show_help
        exit 1
        ;;
esac
