#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — GPU Detection and Configuration Script
# Detects available GPUs and configures AI services accordingly
#
# Usage: ./scripts/detect-gpu.sh [--configure]
# =============================================================================

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ROOT_DIR=$(dirname "$SCRIPT_DIR")

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${RESET} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${RESET} $*"; }
log_error() { echo -e "${RED}[ERROR]${RESET} $*" >&2; }
log_step()  { echo; echo -e "${BOLD}${CYAN}==> $*${RESET}"; }

# =============================================================================
# GPU Detection Functions
# =============================================================================

detect_nvidia_gpu() {
  if command -v nvidia-smi &>/dev/null; then
    local gpu_info
    gpu_info=$(nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv,noheader 2>/dev/null | head -1)
    
    if [ -n "$gpu_info" ]; then
      log_info "NVIDIA GPU detected: $gpu_info"
      return 0
    fi
  fi
  return 1
}

detect_amd_gpu() {
  if command -v rocm-smi &>/dev/null; then
    local gpu_info
    gpu_info=$(rocm-smi --showproductname 2>/dev/null | grep -A1 "Card series" | tail -1 | awk '{print $NF}')
    
    if [ -n "$gpu_info" ]; then
      log_info "AMD GPU detected: $gpu_info"
      return 0
    fi
  fi
  
  # Fallback: check for AMD GPU in system
  if lspci 2>/dev/null | grep -qi 'vga.*amd'; then
    log_info "AMD GPU detected (generic)"
    return 0
  fi
  
  return 1
}

detect_apple_silicon() {
  if [[ "$(uname)" == "Darwin" ]] && [[ "$(uname -m)" == "arm64" ]]; then
    log_info "Apple Silicon detected"
    return 0
  fi
  return 1
}

# =============================================================================
# Configuration Functions
# =============================================================================

configure_for_cpu() {
  log_step "Configuring for CPU-only mode"
  
  local env_file="$ROOT_DIR/.env"
  
  # Update .env
  sed -i.bak "s/^OLLAMA_GPU_ENABLED=.*/OLLAMA_GPU_ENABLED=false/" "$env_file"
  sed -i.bak "s/^SD_IMAGE_TAG=.*/SD_IMAGE_TAG=cpu-v1.10.1/" "$env_file"
  sed -i.bak "s|^SD_COMMANDLINE_ARGS=.*|SD_COMMANDLINE_ARGS=--no-half --skip-torch-cuda-test --use-cpu all|" "$env_file"
  
  log_info "✓ CPU-only configuration applied"
  log_warn "Performance will be limited compared to GPU"
}

configure_for_nvidia() {
  log_step "Configuring for NVIDIA GPU"
  
  local env_file="$ROOT_DIR/.env"
  local gpu_count
  gpu_count=$(nvidia-smi --query-gpu=count --format=csv,noheader | head -1 | tr -d ' ')
  
  # Update .env
  sed -i.bak "s/^OLLAMA_GPU_ENABLED=.*/OLLAMA_GPU_ENABLED=true/" "$env_file"
  sed -i.bak "s/^CUDA_VISIBLE_DEVICES=.*/CUDA_VISIBLE_DEVICES=0/" "$env_file"
  sed -i.bak "s/^SD_IMAGE_TAG=.*/SD_IMAGE_TAG=cuda-v1.10.1/" "$env_file"
  sed -i.bak "s|^SD_COMMANDLINE_ARGS=.*|SD_COMMANDLINE_ARGS=--xformers --share|" "$env_file"
  
  log_info "✓ NVIDIA GPU configuration applied"
  log_info "  GPU Count: $gpu_count"
  log_info "  CUDA enabled for Ollama and Stable Diffusion"
}

configure_for_amd() {
  log_step "Configuring for AMD GPU (ROCm)"
  
  local env_file="$ROOT_DIR/.env"
  
  # Update .env
  sed -i.bak "s/^OLLAMA_GPU_ENABLED=.*/OLLAMA_GPU_ENABLED=true/" "$env_file"
  sed -i.bak "s/^SD_IMAGE_TAG=.*/SD_IMAGE_TAG=rocm-v1.10.1/" "$env_file"
  sed -i.bak "s|^SD_COMMANDLINE_ARGS=.*|SD_COMMANDLINE_ARGS=--precision full --no-half --opt-sub-quad-attention|" "$env_file"
  
  log_info "✓ AMD GPU (ROCm) configuration applied"
  log_warn "ROCm support may be limited compared to CUDA"
}

configure_for_apple_silicon() {
  log_step "Configuring for Apple Silicon (Metal)"
  
  local env_file="$ROOT_DIR/.env"
  
  # Update .env
  sed -i.bak "s/^OLLAMA_GPU_ENABLED=.*/OLLAMA_GPU_ENABLED=true/" "$env_file"
  sed -i.bak "s/^SD_IMAGE_TAG=.*/SD_IMAGE_TAG=cpu-v1.10.1/" "$env_file"  # SD doesn't have Metal support
  sed -i.bak "s|^SD_COMMANDLINE_ARGS=.*|SD_COMMANDLINE_ARGS=--no-half --skip-torch-cuda-test --use-cpu all|" "$env_file"
  
  log_info "✓ Apple Silicon configuration applied"
  log_info "  Ollama: Metal acceleration enabled"
  log_warn "  Stable Diffusion: CPU-only (Metal not yet supported)"
}

# =============================================================================
# Main Execution
# =============================================================================

main() {
  log_step "Detecting GPU hardware..."
  
  # Check .env exists
  if [ ! -f "$ROOT_DIR/.env" ]; then
    log_error ".env file not found. Please copy .env.example to .env first."
    exit 1
  fi
  
  # Detect GPU type
  local gpu_type="cpu"
  
  if detect_nvidia_gpu; then
    gpu_type="nvidia"
  elif detect_amd_gpu; then
    gpu_type="amd"
  elif detect_apple_silicon; then
    gpu_type="apple"
  fi
  
  log_step "GPU detection result: ${gpu_type^^}"
  
  # Configure if --configure flag provided
  if [ "${1:-}" == "--configure" ]; then
    case "$gpu_type" in
      nvidia)
        configure_for_nvidia
        ;;
      amd)
        configure_for_amd
        ;;
      apple)
        configure_for_apple_silicon
        ;;
      *)
        configure_for_cpu
        ;;
    esac
    
    log_info ""
    log_info "Configuration complete! Next steps:"
    log_info "  1. Review .env file: cat $ROOT_DIR/.env"
    log_info "  2. Restart AI stack: docker compose -f stacks/ai/docker-compose.yml up -d"
    log_info "  3. Verify GPU usage: docker logs ollama"
  else
    log_info ""
    log_info "Run with --configure to auto-configure .env file"
    log_info "  ./scripts/detect-gpu.sh --configure"
  fi
}

main "$@"
