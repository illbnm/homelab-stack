#!/usr/bin/env bash
# ==============================================================================
# HomeLab AI Stack — Adaptive GPU Detection & Launcher (`scripts/gpu-detect.sh`)
# Automatically detects NVIDIA CUDA, AMD ROCm, or CPU fallback and configures
# environment variables for Ollama and Stable Diffusion.
# ==============================================================================
set -euo pipefail

detect_gpu_backend() {
  if command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi >/dev/null 2>&1; then
    echo "cuda"
  elif [ -e /dev/kfd ] && [ -e /dev/dri ]; then
    echo "rocm"
  else
    echo "cpu"
  fi
}

BACKEND="${AI_COMPUTE_BACKEND:-$(detect_gpu_backend)}"
echo "[AI Stack] Detected compute backend: ${BACKEND}"

case "${BACKEND}" in
  cuda)
    export OLLAMA_IMAGE="${OLLAMA_IMAGE:-ollama/ollama:0.3.14}"
    export SD_IMAGE="${SD_IMAGE:-universonic/stable-diffusion-webui:v1.10.0}"
    export SD_COMMANDLINE_ARGS="--xformers --medvram --api --listen"
    ;;
  rocm)
    export OLLAMA_IMAGE="${OLLAMA_IMAGE:-ollama/ollama:0.3.14-rocm}"
    export SD_IMAGE="${SD_IMAGE:-universonic/stable-diffusion-webui:v1.10.0}"
    export SD_COMMANDLINE_ARGS="--precision full --no-half --api --listen"
    ;;
  *)
    export OLLAMA_IMAGE="${OLLAMA_IMAGE:-ollama/ollama:0.3.14}"
    export SD_IMAGE="${SD_IMAGE:-ghcr.io/abiosoft/sd-webui-docker:cpu-v1.10.1}"
    export SD_COMMANDLINE_ARGS="--no-half --skip-torch-cuda-test --use-cpu all --api --listen"
    ;;
esac

echo "[AI Stack] Configured OLLAMA_IMAGE=${OLLAMA_IMAGE}"
echo "[AI Stack] Configured SD_IMAGE=${SD_IMAGE}"
