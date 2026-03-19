#!/usr/bin/env bash
# =============================================================================
# AI Stack Setup — GPU 检测与配置脚本
# 自动检测 GPU 类型并生成合适的配置
# =============================================================================
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[AI Setup]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[AI Setup]${NC} $*" >&2; }
log_error() { echo -e "${RED}[AI Setup]${NC} $*" >&2; }
log_step()  { echo -e "${BLUE}[AI Setup]${NC} $*"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
STACK_DIR="$SCRIPT_DIR/../stacks/ai"
ENV_FILE="$STACK_DIR/.env"

# 检测 NVIDIA GPU
detect_nvidia() {
  if command -v nvidia-smi &>/dev/null; then
    local gpu_info
    gpu_info=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1)
    if [[ -n "$gpu_info" ]]; then
      echo "$gpu_info"
      return 0
    fi
  fi
  
  # 检查 /dev/nvidia* 设备
  if ls /dev/nvidia* &>/dev/null; then
    echo "NVIDIA GPU (detected via /dev)"
    return 0
  fi
  
  return 1
}

# 检测 AMD GPU
detect_amd() {
  if command -v rocm-smi &>/dev/null; then
    echo "AMD GPU (ROCm)"
    return 0
  fi
  
  # 检查 /dev/kfd 设备
  if [[ -c /dev/kfd ]]; then
    echo "AMD GPU (detected via /dev/kfd)"
    return 0
  fi
  
  # 检查 lspci
  if lspci 2>/dev/null | grep -qi "advanced micro devices.*vga"; then
    echo "AMD GPU (detected via lspci)"
    return 0
  fi
  
  return 1
}

# 检测 Intel GPU
detect_intel() {
  if lspci 2>/dev/null | grep -qi "intel.*graphics"; then
    echo "Intel GPU (iGPU)"
    return 0
  fi
  
  return 1
}

# 主检测函数
detect_gpu() {
  log_step "检测 GPU..."
  
  local gpu_type="cpu"
  local gpu_name="CPU Only"
  
  if detect_nvidia; then
    gpu_type="nvidia"
    gpu_name=$(detect_nvidia)
  elif detect_amd; then
    gpu_type="amd"
    gpu_name=$(detect_amd)
  elif detect_intel; then
    gpu_type="intel"
    gpu_name=$(detect_intel)
  fi
  
  log_info "检测到: $gpu_name"
  echo "$gpu_type"
}

# 创建环境文件
create_env_file() {
  local gpu_type="$1"
  
  log_step "创建环境配置文件..."
  
  cat > "$ENV_FILE" << EOF
# AI Stack 环境变量配置
# 由 setup-ai.sh 自动生成

# GPU 类型：nvidia | amd | intel | cpu
GPU_TYPE=$gpu_type

# GPU 数量 (NVIDIA)
GPU_COUNT=1

# NVIDIA 可见设备
NVIDIA_VISIBLE_DEVICES=all

# WebUI 密钥 (32 字符以上)
WEBUI_SECRET_KEY=$(openssl rand -hex 32 2>/dev/null || echo "changeme-secret-key-$(date +%s)")

# Perplexica 密钥
PERPLEXICA_SECRET_KEY=$(openssl rand -hex 32 2>/dev/null || echo "changeme-perplexica-$(date +%s)")

# Stable Diffusion 认证
SD_USERNAME=admin
SD_PASSWORD=$(openssl rand -base64 12 2>/dev/null || echo "admin123")

# 域名配置
DOMAIN=${DOMAIN:-example.com}
EOF
  
  chmod 600 "$ENV_FILE"
  log_info "已创建：$ENV_FILE"
}

# 显示使用说明
show_usage() {
  local gpu_type="$1"
  
  echo ""
  echo "=============================================="
  echo "  AI Stack 配置完成！"
  echo "=============================================="
  echo ""
  echo "检测到 GPU 类型：$gpu_type"
  echo ""
  echo "启动命令:"
  if [[ "$gpu_type" == "nvidia" ]]; then
    echo "  export GPU_TYPE=nvidia"
    echo "  cd stacks/ai"
    echo "  docker compose -f docker-compose.yml -f docker-compose.local.yml up -d"
  elif [[ "$gpu_type" == "amd" ]]; then
    echo "  export GPU_TYPE=amd"
    echo "  cd stacks/ai"
    echo "  docker compose -f docker-compose.yml -f docker-compose.local.yml up -d"
  else
    echo "  export GPU_TYPE=cpu"
    echo "  cd stacks/ai"
    echo "  docker compose -f docker-compose.yml up -d"
  fi
  echo ""
  echo "访问地址:"
  echo "  - Open WebUI: https://ai.\${DOMAIN}"
  echo "  - Ollama API: https://ollama.\${DOMAIN}"
  echo "  - Stable Diffusion: https://sd.\${DOMAIN}"
  echo "  - Perplexica: https://perplexica.\${DOMAIN}"
  echo ""
  echo "模型管理:"
  echo "  # 拉取模型"
  echo "  docker exec -it ollama ollama pull llama3.2"
  echo "  docker exec -it ollama ollama pull qwen2.5:7b"
  echo ""
  echo "  # 查看已安装模型"
  echo "  docker exec -it ollama ollama list"
  echo ""
}

# 主函数
main() {
  echo ""
  echo "=============================================="
  echo "  AI Stack 自动配置工具"
  echo "=============================================="
  echo ""
  
  # 检测 GPU
  local gpu_type
  gpu_type=$(detect_gpu)
  
  # 创建环境文件
  create_env_file "$gpu_type"
  
  # 显示使用说明
  show_usage "$gpu_type"
  
  log_info "配置完成！"
}

main "$@"
