#!/usr/bin/env bash
# AI Stack Setup Script — auto-detects GPU
set -euo pipefail

# Color output
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
err() { echo -e "${RED}[ERROR]${NC} $1"; }

DOMAIN="${DOMAIN:-homelab.local}"
LOCALE="${LOCALE:-en}"
COMPOSE_DIR="$(cd "$(dirname "$0")" && pwd)"

# GPU detection
GPU_AVAILABLE=false
if command -v nvidia-smi &>/dev/null && nvidia-smi &>/dev/null; then
    GPU_AVAILABLE=true
    info "NVIDIA GPU detected"
elif command -v rocm-smi &>/dev/null; then
    warn "AMD GPU detected but not fully supported yet — falling back to CPU"
elif lspci | grep -qi "vga.*nvidia" 2>/dev/null; then
    warn "NVIDIA GPU present but nvidia-smi not found — install NVIDIA drivers"
else
    info "No GPU detected — using CPU mode"
fi

echo ""
echo "===== AI Stack Configuration ====="
echo "Domain:     $DOMAIN"
echo "Locale:     $LOCALE"
echo "GPU Mode:   $GPU_AVAILABLE"
echo "Compose:    $COMPOSE_DIR"
echo "=================================="
echo ""

export DOMAIN LOCALE

if [ "$GPU_AVAILABLE" = true ]; then
    info "Starting with GPU support..."
    docker compose -f "$COMPOSE_DIR/docker-compose.yml" -f "$COMPOSE_DIR/docker-compose.gpu.yml" up -d
else
    info "Starting in CPU mode..."
    docker compose -f "$COMPOSE_DIR/docker-compose.yml" up -d
fi

info "AI stack deployed!"
echo ""
echo "  Ollama:       http://ollama.$DOMAIN"
echo "  Open WebUI:   http://ai.$DOMAIN"
echo "  Stable Diff:  http://sd.$DOMAIN"
echo "  Perplexica:   http://search.$DOMAIN"
echo "  LocalAI:      http://localai.$DOMAIN"
