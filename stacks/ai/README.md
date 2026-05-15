# 🤖 AI Stack — Local AI Inference Services

Complete local AI inference stack with GPU auto-detection support.

## Services

| Service | Image | Port | URL |
|---------|-------|------|-----|
| **Ollama** | `ollama/ollama:0.3.12` | 11434 | `ollama.${DOMAIN}` |
| **Open WebUI** | `ghcr.io/open-webui/open-webui:v0.3.32` | 8080 | `ai.${DOMAIN}` |
| **Stable Diffusion** | `ghcr.io/abiosoft/sd-webui-docker:cpu-v1.10.1` | 7860 | `sd.${DOMAIN}` |
| **Perplexica** | `itzcrazykns1337/perplexica:main` | 3000 | `search.${DOMAIN}` |

## Quick Start

```bash
# 1. Copy and edit environment
cp .env.example .env
# Edit .env — set DOMAIN, WEBUI_SECRET_KEY, GPU_MODE

# 2. Start (CPU mode)
docker compose up -d

# Or use the auto-detect script:
./start.sh
```

## GPU Configuration

### CPU Only (default)
```bash
docker compose up -d
```

### NVIDIA CUDA
```bash
docker compose -f docker-compose.yml -f docker-compose.nvidia.yml up -d
```

### AMD ROCm
```bash
docker compose -f docker-compose.yml -f docker-compose.amd.yml up -d
```

### Auto-detect via environment
```bash
GPU_MODE=nvidia ./start.sh
GPU_MODE=amd ./start.sh
GPU_MODE=cpu ./start.sh
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `DOMAIN` | `localhost` | Base domain for Traefik routing |
| `GPU_MODE` | `cpu` | GPU mode: `cpu`, `nvidia`, `amd` |
| `NVIDIA_GPU_COUNT` | `all` | Number of NVIDIA GPUs to use |
| `HSA_OVERRIDE_GFX_VERSION` | `10.3.0` | AMD GPU architecture version |
| `WEBUI_SECRET_KEY` | — | **Required.** `openssl rand -hex 32` |
| `DEFAULT_LOCALE` | `zh-CN` | Open WebUI language |
| `OLLAMA_KEEP_ALIVE` | `24h` | Model keep-alive duration |
| `OLLAMA_MAX_LOADED_MODELS` | `1` | Max concurrent models |
| `SD_COMMANDLINE_ARGS` | Auto-set by GPU mode | Stable Diffusion launch args |
| `PERPLEXICA_SIMILARITY_MEASURE` | `cosine` | Search similarity measure |
| `PERPLEXICA_TOP_N` | `5` | Number of search results |

## Architecture

```
┌─────────────┐     ┌──────────────┐     ┌───────────────────┐
│  Traefik    │────▶│  Open WebUI  │────▶│     Ollama        │
│  (proxy)    │     │   :8080      │     │    :11434         │
│             │     └──────────────┘     │  (LLM inference)  │
│             │                          └───────────────────┘
│             │     ┌──────────────┐
│             │────▶│   Perplexica │──── Ollama API
│             │     │   :3000      │
│             │     └──────────────┘
│             │
│             │     ┌──────────────┐
│             │────▶│  Stable      │
│             │     │  Diffusion   │
│             │     │  :7860       │
└─────────────┘     └──────────────┘
```

## Health Checks

All services include health checks:
- **Ollama**: `GET /api/tags`
- **Open WebUI**: `GET /health`
- **Stable Diffusion**: `GET /`
- **Perplexica**: `GET /`

Verify with:
```bash
docker compose ps
```

## First Run

On first startup, Ollama needs to download models:
```bash
# Pull a model after Ollama is healthy
docker exec ollama ollama pull llama3.2
docker exec ollama ollama pull qwen2.5:7b
```

Open WebUI will be accessible at `https://ai.${DOMAIN}` — create an admin account on first visit.

## Troubleshooting

**Ollama won't start with GPU:**
- NVIDIA: Ensure `nvidia-container-toolkit` is installed
- AMD: Check `/dev/kfd` and `/dev/dri` exist; adjust `HSA_OVERRIDE_GFX_VERSION`

**Stable Diffusion slow on CPU:**
- Expected — SD on CPU is very slow. Use GPU mode for practical image generation.

**Perplexica can't reach Ollama:**
- Both must be on the same `ai` network (default)
- Check `OLLAMA_URL` in .env
