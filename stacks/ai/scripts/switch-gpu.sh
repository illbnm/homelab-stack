#!/bin/bash
# AI Stack GPU Profile Switcher
# Usage: ./switch-gpu.sh [nvidia|amd|cpu]

set -e

GPU_TYPE="${1:-cpu}"
COMPOSE_FILE="docker-compose.yml"

echo "Switching GPU profile to: $GPU_TYPE"

case "$GPU_TYPE" in
  nvidia)
    # Enable NVIDIA GPU blocks, disable AMD and CPU
    sed -i 's/^# \<<: \*gpu-nvidia/  <<: *gpu-nvidia/' "$COMPOSE_FILE"
    sed -i 's/^  <<: \*gpu-amd/#   <<: *gpu-amd/' "$COMPOSE_FILE"
    echo "✅ NVIDIA CUDA mode enabled"
    echo "   Requires: nvidia-container-toolkit installed on host"
    echo "   Verify: docker run --rm --gpus all nvidia/cuda:12.0-base nvidia-smi"
    ;;
  amd)
    # Enable AMD GPU blocks, disable NVIDIA
    sed -i 's/^  <<: \*gpu-nvidia/#   <<: *gpu-nvidia/' "$COMPOSE_FILE"
    sed -i 's/^# \<<: \*gpu-amd/  <<: *gpu-amd/' "$COMPOSE_FILE"
    echo "✅ AMD ROCm mode enabled"
    echo "   Requires: AMD ROCm drivers on host"
    echo "   Verify: rocminfo | grep 'Agent 0'"
    ;;
  cpu)
    # Disable all GPU blocks
    sed -i 's/^  <<: \*gpu-nvidia/#   <<: *gpu-nvidia/' "$COMPOSE_FILE"
    sed -i 's/^  <<: \*gpu-amd/#   <<: *gpu-amd/' "$COMPOSE_FILE"
    echo "✅ CPU-only mode enabled"
    echo "   Note: Inference will be significantly slower"
    echo "   Stable Diffusion: add --use-cpu all --no-half to COMMANDLINE_ARGS"
    ;;
  *)
    echo "❌ Unknown GPU type: $GPU_TYPE"
    echo "Usage: $0 [nvidia|amd|cpu]"
    exit 1
    ;;
esac

echo ""
echo "Restart stack with: docker compose up -d"