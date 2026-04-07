#!/bin/bash
# =============================================================================
# AI Model Management Script
# Downloads, updates, and manages Ollama and Stable Diffusion models
# =============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
OLLAMA_HOST="${OLLAMA_HOST:-http://localhost:11434}"
MODELS_DIR="${MODELS_DIR:-/home/zhaog/.openclaw/workspace/homelab-stack/ai-models}"
LOG_FILE="${LOG_FILE:-/var/log/ai-model-manager.log}"

# =============================================================================
# Logging functions
# =============================================================================
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

# =============================================================================
# Ollama Model Management
# =============================================================================

ollama_list() {
    log_info "Listing installed Ollama models..."
    curl -s "${OLLAMA_HOST}/api/tags" | jq -r '.models[] | "\(.name) - \(.size / 1024 / 1024 / 1024 | floor)GB - Modified: \(.modified)"' || {
        log_error "Failed to list Ollama models"
        return 1
    }
}

ollama_pull() {
    local model="$1"
    log_info "Pulling Ollama model: $model..."
    curl -s -X POST "${OLLAMA_HOST}/api/pull" -d "{\"name\": \"${model}\"}" | jq -r '.status' || {
        log_error "Failed to pull model: $model"
        return 1
    }
    log_success "Model pulled: $model"
}

ollama_delete() {
    local model="$1"
    log_warning "Deleting Ollama model: $model..."
    read -p "Are you sure? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        curl -s -X DELETE "${OLLAMA_HOST}/api/delete" -d "{\"name\": \"${model}\"}" || {
            log_error "Failed to delete model: $model"
            return 1
        }
        log_success "Model deleted: $model"
    else
        log_info "Operation cancelled"
    fi
}

ollama_update_all() {
    log_info "Updating all Ollama models..."
    local models
    models=$(curl -s "${OLLAMA_HOST}/api/tags" | jq -r '.models[].name' || {
        log_error "Failed to get model list"
        return 1
    })

    for model in $models; do
        ollama_pull "$model"
    done

    log_success "All models updated"
}

# =============================================================================
# Recommended Models
# =============================================================================

install_recommended_llms() {
    log_info "Installing recommended LLM models..."

    # General purpose - Qwen2.5 (latest)
    ollama_pull "qwen2.5:latest"

    # Coding assistant - CodeQwen
    ollama_pull "codeqwen:latest"

    # Fast and lightweight - Phi-3
    ollama_pull "phi3:3.8b"

    # Multilingual - Gemma2
    ollama_pull "gemma2:latest"

    # Embeddings - Nomic Embed Text
    ollama_pull "nomic-embed-text:latest"

    log_success "Recommended LLM models installed"
}

install_recommended_vision() {
    log_info "Installing recommended vision models..."

    # Vision-language model - LLaVA
    ollama_pull "llava:7b"

    # Alternative vision model - BakLLaVA
    ollama_pull "bakllava:latest"

    log_success "Recommended vision models installed"
}

# =============================================================================
# Stable Diffusion Model Management
# =============================================================================

sd_download_model() {
    local model_url="$1"
    local model_name="$2"
    local target_dir="${MODELS_DIR}/stable-diffusion/models"

    mkdir -p "$target_dir"

    log_info "Downloading Stable Diffusion model: $model_name..."
    wget -q --show-progress -O "${target_dir}/${model_name}" "$model_url" || {
        log_error "Failed to download model: $model_name"
        return 1
    }

    log_success "Model downloaded: $model_name"
}

sd_list_models() {
    local target_dir="${MODELS_DIR}/stable-diffusion/models"

    if [ -d "$target_dir" ]; then
        log_info "Installed Stable Diffusion models:"
        ls -lh "$target_dir"/*.safetensors 2>/dev/null || {
            log_warning "No models found in $target_dir"
        }
    else
        log_warning "Model directory not found: $target_dir"
    fi
}

# =============================================================================
# Storage Management
# =============================================================================

cleanup_old_models() {
    log_info "Cleaning up old/unused models..."

    # Remove old Ollama model versions (keep latest 2)
    local models
    models=$(curl -s "${OLLAMA_HOST}/api/tags" | jq -r '.models[].name' | sort | uniq -d || true)

    for model in $models; do
        log_warning "Found duplicate model: $model"
        # Keep latest, remove older versions
        ollama_delete "$model"
    done

    log_success "Cleanup complete"
}

show_storage_usage() {
    log_info "AI models storage usage:"
    echo ""

    # Ollama models
    echo "Ollama Models:"
    curl -s "${OLLAMA_HOST}/api/tags" | jq -r '.models[] | "  \(.name): \(.size / 1024 / 1024 / 1024 | floor)GB"' 2>/dev/null || echo "  Unable to retrieve"

    echo ""

    # Stable Diffusion models
    echo "Stable Diffusion Models:"
    du -sh "${MODELS_DIR}/stable-diffusion/models" 2>/dev/null || echo "  Directory not found"

    echo ""

    # Total usage
    echo "Total Usage:"
    du -sh /var/lib/docker/volumes/homelab_ollama-data 2>/dev/null || echo "  Ollama: Unable to calculate"
    du -sh /var/lib/docker/volumes/homelab_sd-models 2>/dev/null || echo "  SD Models: Unable to calculate"
}

# =============================================================================
# GPU Detection
# =============================================================================

detect_gpu() {
    log_info "Detecting GPU..."

    # Check for NVIDIA GPU
    if command -v nvidia-smi &> /dev/null; then
        if nvidia-smi &> /dev/null; then
            log_success "NVIDIA GPU detected:"
            nvidia-smi --query-gpu=name,memory.total --format=csv,noheader
            echo "NVIDIA"
            return 0
        fi
    fi

    # Check for AMD GPU
    if command -v rocm-smi &> /dev/null; then
        if rocm-smi &> /dev/null; then
            log_success "AMD GPU detected:"
            rocm-smi --showproductname
            echo "AMD"
            return 0
        fi
    fi

    # Check for AMD GPU via lspci
    if lspci | grep -qi "vga.*amd\|vga.*ati"; then
        log_warning "AMD GPU detected (ROCm not installed, using CPU mode)"
        echo "AMD_CPU"
        return 0
    fi

    log_warning "No GPU detected, using CPU mode"
    echo "CPU"
    return 0
}

# =============================================================================
# Main Menu
# =============================================================================

show_help() {
    cat << EOF
AI Model Management Script

Usage: $0 <command> [arguments]

Commands:
  # Ollama
  list                    List installed Ollama models
  pull <model>            Pull a specific Ollama model
  delete <model>          Delete a specific Ollama model
  update-all              Update all installed Ollama models

  # Installation
  install-llms            Install recommended LLM models
  install-vision          Install recommended vision models

  # Stable Diffusion
  sd-list                 List Stable Diffusion models
  sd-download <url> <name> Download a Stable Diffusion model

  # Storage
  cleanup                 Remove old/unused model versions
  storage                 Show storage usage

  # System
  detect-gpu              Detect available GPU
  help                    Show this help message

Examples:
  $0 pull qwen2.5:latest
  $0 install-llms
  $0 storage
  $0 detect-gpu
EOF
}

# Main command dispatcher
case "${1:-help}" in
    list)
        ollama_list
        ;;
    pull)
        [ -z "${2:-}" ] && { log_error "Usage: $0 pull <model>"; exit 1; }
        ollama_pull "$2"
        ;;
    delete)
        [ -z "${2:-}" ] && { log_error "Usage: $0 delete <model>"; exit 1; }
        ollama_delete "$2"
        ;;
    update-all)
        ollama_update_all
        ;;
    install-llms)
        install_recommended_llms
        ;;
    install-vision)
        install_recommended_vision
        ;;
    sd-list)
        sd_list_models
        ;;
    sd-download)
        [ -z "${2:-}" ] || [ -z "${3:-}" ] && { log_error "Usage: $0 sd-download <url> <name>"; exit 1; }
        sd_download_model "$2" "$3"
        ;;
    cleanup)
        cleanup_old_models
        ;;
    storage)
        show_storage_usage
        ;;
    detect-gpu)
        detect_gpu
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        log_error "Unknown command: $1"
        show_help
        exit 1
        ;;
esac
