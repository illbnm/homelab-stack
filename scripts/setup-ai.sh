#!/usr/bin/env bash
# ==============================================================================
# scripts/setup-ai.sh
# Hardware GPU auto-detection (NVIDIA CUDA / AMD ROCm / CPU) & Model Pre-Puller
# ==============================================================================
set -euo pipefail

DRY_RUN=false
COMPOSE_DIR="stacks/ai"
MODELS="${OLLAMA_DEFAULT_MODELS:-qwen2.5:7b,nomic-embed-text}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --models)
      MODELS="$2"
      shift 2
      ;;
    --help|-h)
      echo "Usage: $(basename "$0") [--dry-run] [--models model1,model2]"
      exit 0
      ;;
    *)
      echo "[ERROR] Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

detect_accelerator() {
  if command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi -L >/dev/null 2>&1; then
    echo "nvidia"
  elif [[ -e /dev/kfd ]] && [[ -e /dev/dri ]]; then
    echo "rocm"
  else
    echo "cpu"
  fi
}

ACCEL="$(detect_accelerator)"
echo "[setup-ai] Detected compute accelerator: ${ACCEL}"

COMPOSE_CMD=("docker" "compose" "-f" "${COMPOSE_DIR}/docker-compose.yml")
if [[ "$ACCEL" == "nvidia" ]]; then
  COMPOSE_CMD+=("-f" "${COMPOSE_DIR}/docker-compose.gpu.yml")
fi

if [[ "$DRY_RUN" == "true" ]]; then
  echo "[setup-ai] [DRY-RUN] ${COMPOSE_CMD[*]} up -d"
  IFS=',' read -ra MODEL_LIST <<< "$MODELS"
  for m in "${MODEL_LIST[@]}"; do
    echo "[setup-ai] [DRY-RUN] docker exec ollama ollama pull ${m}"
  done
  exit 0
fi

"${COMPOSE_CMD[@]}" up -d

echo "[setup-ai] Waiting for Ollama container health..."
for i in $(seq 1 30); do
  if docker exec ollama ollama list >/dev/null 2>&1; then
    break
  fi
  sleep 2
done

IFS=',' read -ra MODEL_LIST <<< "$MODELS"
for m in "${MODEL_LIST[@]}"; do
  echo "[setup-ai] Pulling model: ${m}"
  docker exec ollama ollama pull "$m"
done

echo "[setup-ai] AI stack is ready."
