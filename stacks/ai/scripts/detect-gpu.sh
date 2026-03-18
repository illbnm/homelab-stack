#!/usr/bin/env bash
# ============================================================
# detect-gpu.sh — Auto-detect GPU runtime for Docker
# ============================================================
# Usage: source scripts/detect-gpu.sh
# Sets GPU_RUNTIME and SD_ARGS environment variables
# ============================================================

set -euo pipefail

detect_gpu() {
    echo "🔍 Detecting GPU..."

    # Check for NVIDIA GPU
    if command -v nvidia-smi &>/dev/null && nvidia-smi &>/dev/null; then
        GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader | head -1)
        GPU_MEMORY=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader | head -1)
        echo "✅ NVIDIA GPU detected: $GPU_NAME ($GPU_MEMORY)"
        echo ""
        echo "Setting GPU_RUNTIME=nvidia"
        export GPU_RUNTIME=nvidia
        export SD_ARGS="--xformers"
        return 0
    fi

    # Check for AMD GPU (ROCm)
    if command -v rocminfo &>/dev/null && rocminfo &>/dev/null; then
        GPU_NAME=$(rocminfo 2>/dev/null | grep -m1 "Marketing Name" | awk -F: '{print $2}' | xargs)
        echo "✅ AMD GPU detected: $GPU_NAME"
        echo ""
        echo "Setting GPU_RUNTIME=rocm"
        # Note: ROCm requires special Docker images for SD
        export GPU_RUNTIME=""
        export SD_ARGS="--use-cpu all --no-half --precision full"
        echo "⚠️  ROCm detected but Stable Diffusion may need ROCm-specific image"
        return 0
    fi

    # CPU fallback
    echo "ℹ️  No GPU detected — running in CPU mode"
    echo ""
    export GPU_RUNTIME=""
    export SD_ARGS="--no-half --skip-torch-cuda-test --use-cpu all --precision full"
    return 0
}

# Run detection
detect_gpu

# Write to .env if it exists
if [ -f .env ]; then
    # Update or add GPU_RUNTIME
    if grep -q "^GPU_RUNTIME=" .env; then
        sed -i.bak "s/^GPU_RUNTIME=.*/GPU_RUNTIME=$GPU_RUNTIME/" .env
    else
        echo "GPU_RUNTIME=$GPU_RUNTIME" >> .env
    fi

    # Update or add SD_ARGS
    if grep -q "^SD_ARGS=" .env; then
        sed -i.bak "s|^SD_ARGS=.*|SD_ARGS=$SD_ARGS|" .env
    else
        echo "SD_ARGS=$SD_ARGS" >> .env
    fi

    rm -f .env.bak
    echo ""
    echo "✅ Updated .env with GPU settings"
fi
