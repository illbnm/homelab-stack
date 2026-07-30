# AI Stack — Local AI Inference Suite

Self-hosted AI platform: Ollama LLM engine, Open WebUI chat interface, Stable Diffusion image generation, and Perplexica AI search.

## Services

| Service | Image | URL |
|---------|-------|-----|
| Ollama | `ollama/ollama:0.3.12` | `https://ollama.${DOMAIN}` |
| Open WebUI | `ghcr.io/open-webui/open-webui:0.3.32` | `https://ai.${DOMAIN}` |
| Stable Diffusion | `universonic/stable-diffusion-webui:latest` | `https://diffusion.${DOMAIN}` |
| Perplexica | `itzcrazykns1337/perplexica:main` | `https://search.${DOMAIN}` |

## GPU Support

This stack supports three GPU modes via the `switch-gpu.sh` script:

| Mode | Requirements | Performance |
|------|-------------|-------------|
| **NVIDIA (CUDA)** | nvidia-container-toolkit | ⚡ Fastest |
| **AMD (ROCm)** | ROCm drivers | ⚡ Fast |
| **CPU-only** | None | 🐢 Slowest (works anywhere) |

### Switching GPU Mode

```bash
./scripts/switch-gpu.sh nvidia   # NVIDIA CUDA
./scripts/switch-gpu.sh amd      # AMD ROCm
./scripts/switch-gpu.sh cpu      # CPU fallback
```

### NVIDIA Setup

1. Install `nvidia-container-toolkit` on the host
2. Run `./scripts/switch-gpu.sh nvidia`
3. Verify: `docker run --rm --gpus all nvidia/cuda:12.0-base nvidia-smi`

### AMD Setup

1. Install AMD ROCm drivers on the host
2. Run `./scripts/switch-gpu.sh amd`
3. Verify: `rocminfo | grep 'Agent 0'`

### CPU-Only

1. Run `./scripts/switch-gpu.sh cpu`
2. For Stable Diffusion, add `--use-cpu all --no-half` to `COMMANDLINE_ARGS`

## Quick Start

```bash
cp .env.example .env
nano .env  # Set domain, GPU type, secrets

# Switch to your GPU mode
./scripts/switch-gpu.sh cpu  # or nvidia/amd

# Start the stack
docker compose up -d

# Pull a model in Ollama
docker exec ollama ollama pull llama3.1:8b
```

## Post-Install

### Open WebUI
1. Visit `https://ai.${DOMAIN}`
2. Create admin account
3. Select a model (e.g., `llama3.1:8b`)
4. Start chatting

### Stable Diffusion
1. Visit `https://diffusion.${DOMAIN}`
2. Models auto-download on first use
3. Use `--api` flag for programmatic access at `/sdapi/v1/txt2img`

### Perplexica
1. Visit `https://search.${DOMAIN}`
2. Configure SearXNG URL in `perplexica/config.toml` if needed
3. Select Ollama model for search-augmented answers

## Recommended Models

### LLMs (Ollama)
| Model | Size | Use Case |
|-------|------|----------|
| `llama3.1:8b` | ~4.7 GB | General chat, reasoning |
| `qwen2.5:7b` | ~4.4 GB | Coding, multilingual |
| `mistral:7b` | ~4.1 GB | Fast general purpose |
| `nomic-embed-text` | ~274 MB | Embeddings for RAG |

### Pull Models
```bash
docker exec ollama ollama pull llama3.1:8b
docker exec ollama ollama pull qwen2.5:7b
docker exec ollama ollama pull nomic-embed-text
```

## DNS Records

| Hostname | Service |
|----------|---------|
| `ollama.${DOMAIN}` | Ollama API |
| `ai.${DOMAIN}` | Open WebUI |
| `diffusion.${DOMAIN}` | Stable Diffusion |
| `search.${DOMAIN}` | Perplexica |

## Resource Notes

- **Ollama**: Uses GPU when available; CPU mode works but is 10-50x slower
- **Stable Diffusion**: Requires 4GB+ VRAM for GPU, 16GB+ RAM for CPU
- **Open WebUI**: Lightweight, runs on CPU fine
- **Perplexica**: Depends on Ollama for LLM and embeddings

## Traefik Labels

All services are pre-configured with Traefik labels for HTTPS. Ensure your Traefik instance is running with the `homelab` network and `letsencrypt` certresolver.