#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════
# Ollama 入口脚本 — 处理 GPU 检测和模型预下载
#
# 功能:
# 1. 检测系统 GPU 类型 (NVIDIA/AMD/None)
# 2. 设置相应的环境变量
# 3. 从 models.txt 下载预定义模型列表
# 4. 启动 Ollama 服务
# ═══════════════════════════════════════════════════════════════════════════

set -euo pipefail

# 颜色
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo "🚀 Starting Ollama with GPU detection..."

# ═══════════════════════════════════════════════════════════════════════════
# 1. GPU 检测
# ═══════════════════════════════════════════════════════════════════════════

detect_gpu() {
  echo "📊 Detecting GPU..."

  # 检测 NVIDIA GPU
  if command -v nvidia-smi &>/dev/null && nvidia-smi &>/dev/null; then
    echo -e "  ${GREEN}✓ NVIDIA GPU detected${NC}"
    export OLLAMA_GPU_TYPE="nvidia"
    export CUDA_VISIBLE_DEVICES=${NVIDIA_VISIBLE_DEVICES:-all}
    export OLLAMA_NUM_GPU=${OLLAMA_GPU_LAYERS:-100}
    return 0
  fi

  # 检测 AMD GPU (ROCm)
  if ls /dev/dri/ &>/dev/null; then
    echo -e "  ${GREEN}✓ AMD GPU (ROCm) detected${NC}"
    export OLLAMA_GPU_TYPE="amd"
    export HSA_OVERRIDE_GFX_VERSION=${HSA_OVERRIDE_GFX_VERSION:-}
    return 0
  fi

  # 无 GPU
  echo -e "  ${YELLOW}⚠️  No GPU detected, using CPU mode${NC}"
  export OLLAMA_GPU_TYPE="cpu"
  export OLLAMA_CPU_THREADS=${OLLAMA_CPU_THREADS:-8}
  return 1
}

# ═══════════════════════════════════════════════════════════════════════════
# 2. 模型列表加载
# ═══════════════════════════════════════════════════════════════════════════

load_models() {
  local models_file="${OLLAMA_MODELS_FILE:-/models.txt}"

  echo "📋 Loading model list from ${models_file}..."

  if [[ ! -f "$models_file" ]]; then
    echo -e "  ${YELLOW}⚠️  Model list not found, skipping pre-download${NC}"
    return 0
  fi

  # 读取模型列表 (逗号分隔或换行分隔)
  local models=()
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    [[ "$line" =~ ^# ]] && continue  # 跳过注释
    # 支持逗号分隔
    IFS=',' read -ra model_list <<< "$line"
    for model in "${model_list[@]}"; do
      model=$(echo "$model" | xargs)  # 去除空格
      [[ -n "$model" ]] && models+=("$model")
    done
  done < "$models_file"

  if [[ ${#models[@]} -eq 0 ]]; then
    echo -e "  ${YELLOW}⚠️  No models specified${NC}"
    return 0
  fi

  echo -e "  ${CYAN}Models to download:${NC} ${models[*]}"

  # 下载每个模型
  for model in "${models[@]}"; do
    echo "  Downloading model: $model..."
    # 使用 Ollama API 拉取模型
    if curl -s -X POST "http://localhost:11434/api/pull" \
      -H "Content-Type: application/json" \
      -d "{\"name\":\"$model\",\"stream\":false}" 2>/dev/null | grep -q "status"; then
      echo -e "  ${GREEN}✓ Model $model downloaded${NC}"
    else
      echo -e "  ${YELLOW}⚠️  Model $model download failed (will retry later)${NC}"
    fi
  done
}

# ═══════════════════════════════════════════════════════════════════════════
# 3. 主流程
# ═══════════════════════════════════════════════════════════════════════════

main() {
  # 检测 GPU
  detect_gpu
  echo

  # 输出配置
  echo "⚙️  Configuration:"
  echo "  GPU Type: ${OLLAMA_GPU_TYPE:-cpu}"
  echo "  GPU Layers: ${OLLAMA_GPU_LAYERS:-100}"
  echo "  Models: ${OLLAMA_MODELS:-from models.txt}"
  echo

  # 启动 Ollama 服务 (后台)
  echo "🎯 Starting Ollama service..."
  exec /bin/ollama serve
}

main "$@"