#!/bin/bash
# Auto-detect GPU and set env vars for AI stack deployment
set -e

echo "🔍 Detecting GPU..."

if command -v nvidia-smi &>/dev/null && nvidia-smi &>/dev/null; then
  echo "✅ NVIDIA GPU detected (CUDA)"
  cat >> .env <<EOF
GPU_NVIDIA_DEPLOY=deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: 1
              capabilities: [gpu]
GPU_NVIDIA_DEPLOY_SD=deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: 1
              capabilities: [gpu]
SD_COMMANDLINE_ARGS=--medvram --opt-sdp-attention
EOF

elif command -v rocminfo &>/dev/null && rocminfo &>/dev/null; then
  echo "✅ AMD GPU detected (ROCm)"
  cat >> .env <<EOF
GPU_NVIDIA_DEPLOY=devices:
      - /dev/kfd
      - /dev/dri:/dev/dri
GPU_NVIDIA_DEPLOY_SD=devices:
      - /dev/kfd
      - /dev/dri:/dev/dri
SD_COMMANDLINE_ARGS=--medvram --opt-sdp-attention --use-rocm
EOF

else
  echo "⚠️  No GPU detected — using CPU mode"
  cat >> .env <<EOF
GPU_NVIDIA_DEPLOY=
GPU_NVIDIA_DEPLOY_SD=
SD_COMMANDLINE_ARGS=--no-half --skip-torch-cuda-test --use-cpu all
EOF
fi

echo "✅ GPU config written to .env"
