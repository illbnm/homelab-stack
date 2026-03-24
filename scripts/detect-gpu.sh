#!/usr/bin/env bash
# =============================================================================
# Detect GPU — 自动检测 GPU 类型并输出推荐配置
# Detects NVIDIA/AMD GPU and prints recommended GPU_RUNTIME value.
#
# Usage: ./scripts/detect-gpu.sh
# =============================================================================
set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }

echo -e "${BLUE}${BOLD}=== GPU Detection ===${NC}"
echo ""

GPU_RUNTIME="cpu"

# ---------------------------------------------------------------------------
# Check NVIDIA GPU
# ---------------------------------------------------------------------------
if command -v nvidia-smi &>/dev/null; then
  if nvidia-smi &>/dev/null; then
    gpu_name=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1)
    gpu_mem=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader 2>/dev/null | head -1)
    driver=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null | head -1)
    log_info "NVIDIA GPU detected: ${gpu_name} (${gpu_mem})"
    log_info "Driver version: ${driver}"

    # Check NVIDIA Container Toolkit
    if docker info 2>/dev/null | grep -qi nvidia; then
      log_info "NVIDIA Container Toolkit: installed ✓"
      GPU_RUNTIME="nvidia"
    else
      log_warn "NVIDIA Container Toolkit not found."
      log_warn "Install: https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html"
      log_warn "Falling back to CPU mode."
    fi
  fi
fi

# ---------------------------------------------------------------------------
# Check AMD GPU (ROCm)
# ---------------------------------------------------------------------------
if [[ "$GPU_RUNTIME" == "cpu" ]] && [[ -d /opt/rocm ]] || command -v rocminfo &>/dev/null; then
  if rocminfo &>/dev/null 2>&1; then
    gpu_name=$(rocminfo 2>/dev/null | grep "Marketing Name" | head -1 | sed 's/.*: *//')
    log_info "AMD GPU detected: ${gpu_name}"

    if [[ -e /dev/kfd ]]; then
      log_info "ROCm device: available ✓"
      GPU_RUNTIME="rocm"
    else
      log_warn "/dev/kfd not found. ROCm may not be properly configured."
      log_warn "Falling back to CPU mode."
    fi
  fi
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
if [[ "$GPU_RUNTIME" == "nvidia" ]]; then
  log_info "${GREEN}${BOLD}Recommended: GPU_RUNTIME=nvidia${NC}"
  echo ""
  echo "Set in stacks/ai/.env:"
  echo "  GPU_RUNTIME=nvidia"
  echo "  SD_CLI_ARGS=--xformers"
elif [[ "$GPU_RUNTIME" == "rocm" ]]; then
  log_info "${GREEN}${BOLD}Recommended: GPU_RUNTIME=rocm${NC}"
  echo ""
  echo "Set in stacks/ai/.env:"
  echo "  GPU_RUNTIME=rocm"
  echo "  SD_CLI_ARGS=--no-half"
else
  log_info "No GPU detected. Using CPU mode."
  echo ""
  echo "Set in stacks/ai/.env:"
  echo "  GPU_RUNTIME=cpu"
  echo "  SD_CLI_ARGS=--no-half --skip-torch-cuda-test --use-cpu all"
fi
