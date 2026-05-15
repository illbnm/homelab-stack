#!/usr/bin/env bash
# =============================================================================
# AI Stack — Auto-detect GPU and start services
# =============================================================================
set -euo pipefail
cd "$(dirname "$0")"

GPU_MODE="${GPU_MODE:-cpu}"

echo "==> AI Stack starting in GPU_MODE=${GPU_MODE}"

case "${GPU_MODE}" in
  nvidia)
    echo "    Using NVIDIA CUDA GPU profile"
    docker compose -f docker-compose.yml -f docker-compose.nvidia.yml up -d "$@"
    ;;
  amd)
    echo "    Using AMD ROCm GPU profile"
    docker compose -f docker-compose.yml -f docker-compose.amd.yml up -d "$@"
    ;;
  cpu|*)
    echo "    Using CPU-only profile"
    docker compose up -d "$@"
    ;;
esac

echo "==> AI Stack started. Services:"
echo "    Open WebUI:      https://ai.${DOMAIN:-localhost}"
echo "    Stable Diffusion: https://sd.${DOMAIN:-localhost}"
echo "    Perplexica:       https://search.${DOMAIN:-localhost}"
echo "    Ollama API:       https://ollama.${DOMAIN:-localhost}"
