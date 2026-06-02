# AI Stack for NVIDIA DGX Atom (ARM64 + CUDA)

## Hardware Verified
- NVIDIA GB10 GPU with 122GB unified memory
- aarch64 architecture
- CUDA 13.0
- Ubuntu 24.04

## Components
- **Ollama**: Local LLM runtime (connects to host instance)
- **Open WebUI**: Chat interface for Ollama models

## Quick Start
```bash
./gpu-detect.sh  # Detects GPU type and architecture
docker compose up -d
```

## GPU Detection
Automatically detects NVIDIA CUDA, AMD ROCm, or falls back to CPU-only mode.
Verified on real NVIDIA GB10 ARM64 hardware.
