#!/bin/bash
# =============================================================================
# AI Storage Optimizer
# Cleans up temporary files, optimizes model storage, manages disk usage
# =============================================================================

set -euo pipefail

# Configuration
RETENTION_DAYS="${RETENTION_DAYS:-7}"
MAX_STORAGE_GB="${MAX_STORAGE_GB:-100}"
AI_DIR="${AI_DIR:-/home/zhaog/.openclaw/workspace/homelab-stack}"
LOG_FILE="${LOG_FILE:-/var/log/ai-storage-optimizer.log}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

# =============================================================================
# Clean Stable Diffusion temporary files
# =============================================================================
clean_sd_temp() {
    log "Cleaning Stable Diffusion temporary files..."

    # Find and remove old output files
    find "${AI_DIR}/stacks/ai/sd-output" -type f -mtime +${RETENTION_DAYS} -delete 2>/dev/null || true

    # Remove temporary files
    find "${AI_DIR}/stacks/ai/sd-data" -type f -name "*.tmp" -delete 2>/dev/null || true

    # Clear cache if exists
    if [ -d "${AI_DIR}/stacks/ai/sd-data/cache" ]; then
        rm -rf "${AI_DIR}/stacks/ai/sd-data/cache"/*
        log "✓ Stable Diffusion cache cleared"
    fi

    log "✓ Stable Diffusion cleanup complete"
}

# =============================================================================
# Clean Open WebUI temporary files
# =============================================================================
clean_webui_temp() {
    log "Cleaning Open WebUI temporary files..."

    # Remove old export files
    find "${AI_DIR}/stacks/ai/open-webui-data" -type f -name "*.json" -path "*/exports/*" -mtime +${RETENTION_DAYS} -delete 2>/dev/null || true

    # Clear temporary files
    find "${AI_DIR}/stacks/ai/open-webui-data" -type f -name "*.tmp" -delete 2>/dev/null || true

    # Remove old upload files (keep recent 7 days)
    find "${AI_DIR}/stacks/ai/open-webui-data" -type f -path "*/uploads/*" -mtime +${RETENTION_DAYS} -delete 2>/dev/null || true

    log "✓ Open WebUI cleanup complete"
}

# =============================================================================
# Optimize Ollama models
# =============================================================================
optimize_ollama() {
    log "Optimizing Ollama models..."

    # Prune unused model layers
    if command -v ollama &> /dev/null; then
        # List models before optimization
        log "Models before optimization:"
        ollama list | tee -a "$LOG_FILE"

        # Note: Ollama doesn't have a built-in prune command
        # Models are managed through API
        log "✓ Ollama models listed (manual cleanup may be needed)"
    else
        log "⚠ Ollama CLI not found"
    fi
}

# =============================================================================
# Clean Docker system
# =============================================================================
clean_docker() {
    log "Cleaning Docker system..."

    # Remove unused images
    docker image prune -a -f --filter "until=168h" 2>/dev/null || true

    # Remove stopped containers
    docker container prune -f 2>/dev/null || true

    # Remove unused volumes (be careful!)
    # docker volume prune -f 2>/dev/null || true

    # Clear build cache
    docker builder prune -f --filter "until=168h" 2>/dev/null || true

    log "✓ Docker cleanup complete"
}

# =============================================================================
# Monitor storage usage
# =============================================================================
monitor_storage() {
    log "Monitoring AI storage usage..."

    local total_size=0

    echo ""
    echo "================================"
    echo "AI Storage Usage Report"
    echo "================================"
    echo ""

    # Ollama
    if [ -d "${AI_DIR}/stacks/ai/ollama-data" ]; then
        local ollama_size=$(du -sg "${AI_DIR}/stacks/ai/ollama-data" 2>/dev/null | cut -f1 || echo "0")
        echo "Ollama Models:       ${ollama_size}GB"
        total_size=$((total_size + ollama_size))
    fi

    # Open WebUI
    if [ -d "${AI_DIR}/stacks/ai/open-webui-data" ]; then
        local webui_size=$(du -sg "${AI_DIR}/stacks/ai/open-webui-data" 2>/dev/null | cut -f1 || echo "0")
        echo "Open WebUI Data:     ${webui_size}GB"
        total_size=$((total_size + webui_size))
    fi

    # Stable Diffusion
    if [ -d "${AI_DIR}/stacks/ai/sd-models" ]; then
        local sd_size=$(du -sg "${AI_DIR}/stacks/ai/sd-models" 2>/dev/null | cut -f1 || echo "0")
        echo "Stable Diffusion:    ${sd_size}GB"
        total_size=$((total_size + sd_size))
    fi

    # SD Outputs
    if [ -d "${AI_DIR}/stacks/ai/sd-output" ]; then
        local output_size=$(du -sg "${AI_DIR}/stacks/ai/sd-output" 2>/dev/null | cut -f1 || echo "0")
        echo "SD Outputs:          ${output_size}GB"
        total_size=$((total_size + output_size))
    fi

    echo "--------------------------------"
    echo "Total:               ${total_size}GB"
    echo "Max Allowed:         ${MAX_STORAGE_GB}GB"
    echo "================================"
    echo ""

    # Warning if over limit
    if [ $total_size -gt $MAX_STORAGE_GB ]; then
        log "⚠ WARNING: Storage usage (${total_size}GB) exceeds limit (${MAX_STORAGE_GB}GB)"
        return 1
    fi

    return 0
}

# =============================================================================
# Emergency cleanup (when over storage limit)
# =============================================================================
emergency_cleanup() {
    log "🚨 Running emergency cleanup..."

    # More aggressive cleanup
    RETENTION_DAYS=3 clean_sd_temp
    RETENTION_DAYS=3 clean_webui_temp

    # Remove oldest Stable Diffusion outputs
    find "${AI_DIR}/stacks/ai/sd-output" -type f -mtime +3 -delete 2>/dev/null || true

    # Clear all caches
    rm -rf "${AI_DIR}/stacks/ai/sd-data/cache"/* 2>/dev/null || true

    log "✓ Emergency cleanup complete"
}

# =============================================================================
# Main
# =============================================================================
main() {
    log "========================================="
    log "AI Storage Optimizer - Starting"
    log "========================================="

    # Check current storage
    if ! monitor_storage; then
        log "Storage over limit, running emergency cleanup..."
        emergency_cleanup
        monitor_storage
    fi

    # Regular cleanup
    clean_sd_temp
    clean_webui_temp
    optimize_ollama
    clean_docker

    # Final storage check
    monitor_storage

    log "========================================="
    log "AI Storage Optimizer - Complete"
    log "========================================="
}

# Run main function
main "$@"
