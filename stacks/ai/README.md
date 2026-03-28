# AI Stack — Ollama + Open WebUI + Stable Diffusion

Self-hosted AI inference stack with local LLM inference, a web chat interface, and image generation.

## What's Included

| Service | Version | URL | Purpose |
|---------|---------|-----|---------|
| Ollama | 0.5.16 | `ollama.<DOMAIN>` | Local LLM inference engine |
| Open WebUI | 0.6.5 | `ai.<DOMAIN>` | Web chat UI for Ollama |
| A1111 Stable Diffusion WebUI | 1.10.3 | `sd.<DOMAIN>` | Image generation via text-to-image |

## Architecture

```
Internet
    │
    ▼
[Traefik :443]
    │
    ├── ollama.<DOMAIN>  → Ollama (LLM API)
    ├── ai.<DOMAIN>      → Open WebUI (chat UI)
    └── sd.<DOMAIN>      → Stable Diffusion WebUI (image gen)

[proxy] ← shared Docker network
```

All services are accessible only via Traefik with HTTPS (TLS auto-provisioned via Let's Encrypt).

## Prerequisites

- Base stack deployed (`stacks/base/` — Traefik + Portainer)
- NVIDIA GPU + `nvidia-container-toolkit` installed on host **for GPU acceleration**
  - Without a GPU, all services run on CPU (slow for LLMs)
  - Verify GPU runtime: `docker run --rm --gpus all nvidia/cuda:12.1.0-base nvidia-smi`
- Docker >= 24.0 with Compose v2 plugin

## Quick Start

```bash
cd stacks/ai

# 1. Copy environment file and fill in values
cp .env.example .env
$EDITOR .env   # set DOMAIN, WEBUI_SECRET_KEY, OLLAMA_PRELOAD_MODELS, SD_MODEL_ID

# 2. Launch
docker compose up -d

# 3. Pull a model manually (if not using OLLAMA_PRELOAD_MODELS)
docker exec ollama ollama pull llama3:8b

# 4. Pull an SD model via the WebUI at sd.DOMAIN → Models tab
```

## Configuration

### Environment Variables (`.env`)

| Variable | Default | Description |
|----------|---------|-------------|
| `DOMAIN` | — | Your base domain, e.g. `home.example.com` |
| `WEBUI_SECRET_KEY` | — | Secret for Open WebUI session. Generate: `openssl rand -hex 32` |
| `OLLAMA_VERSION` | `0.5.16` | Ollama Docker image tag |
| `OLLAMA_GPU_COUNT` | `all` | Number of GPUs for Ollama. Set `0` to disable GPU |
| `OLLAMA_PRELOAD_MODELS` | _(empty)_ | Space-separated models to download on startup, e.g. `llama3:8b mistral` |
| `OPEN_WEBUI_VERSION` | `0.6.5` | Open WebUI Docker image tag |
| `DEFAULT_LOCALE` | `zh-CN` | UI language for Open WebUI |
| `SD_VERSION` | `1.10.3` | Stable Diffusion WebUI image tag |
| `SD_GPU_COUNT` | `all` | Number of GPUs for SD WebUI. Set `0` to disable GPU |
| `SD_CLI_ARGS` | `--api --listen --opt-sdp-attention` | Extra command-line args for SD WebUI |
| `SD_TORCH_DTYPE` | `float16` | Precision. `float16` = fast, `float32` = slower/more VRAM |
| `SD_MODEL_ID` | _(empty)_ | HuggingFace model ID to auto-download on first start |

### Downloading Models

**Ollama models** — via CLI or Open WebUI:

```bash
# Pull via CLI
docker exec ollama ollama pull llama3:8b
docker exec ollama ollama pull mistral:7b
docker exec ollama ollama pull qwen2.5:14b
docker exec ollama ollama pull nomic-embed-text

# Or via Open WebUI at ai.DOMAIN → Settings → Models
```

Browse available models at [ollama.com/library](https://ollama.com/library).

**Stable Diffusion models** — via WebUI or HuggingFace:

```bash
# Set SD_MODEL_ID in .env to auto-download on first start:
# SD_MODEL_ID=stabilityai/stable-diffusion-3-medium
# SD_MODEL_ID=stabilityai/stable-diffusion-xl-base-1.0

# Download additional SD models via the WebUI at sd.DOMAIN → Extensions → Checkpoints
```

### GPU Acceleration

Both Ollama and SD WebUI use NVIDIA GPUs via `nvidia-container-toolkit`.

```bash
# Verify GPU runtime
docker run --rm --gpus all nvidia/cuda:12.1.0-base nvidia-smi

# If GPU is not detected, install nvidia-container-toolkit:
# https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html
```

When GPU is present, `OLLAMA_GPU_COUNT` and `SD_GPU_COUNT` control how many GPUs each service uses. Set to `0` to force CPU-only mode.

### Traefik Routes

| Service | URL | Notes |
|---------|-----|-------|
| Ollama | `https://ollama.<DOMAIN>` | Direct API access |
| Open WebUI | `https://ai.<DOMAIN>` | Chat UI |
| Stable Diffusion | `https://sd.<DOMAIN>` | Image generation UI |

## Healthchecks

| Service | Endpoint | Start Period |
|---------|----------|--------------|
| Ollama | `http://localhost:11434/api/tags` | 60s |
| Open WebUI | `http://localhost:8080/health` | 60s |
| Stable Diffusion | `http://localhost:7860/` | 300s |

## Data Persistence

| Volume | Mount | Purpose |
|--------|-------|---------|
| `ollama-data` | `/root/.ollama` | Ollama model storage |
| `open-webui-data` | `/app/backend/data` | Open WebUI settings & chat history |
| `sd-models` | `/app/models` | Stable Diffusion model/checkpoint files |
| `sd-output` | `/app/outputs` | Generated images |
| `sd-cache` | `/root/.cache` | HuggingFace/transformers cache |

## Troubleshooting

**Ollama not responding:**
```bash
docker logs ollama
docker exec ollama ollama list
```

**Open WebUI can't connect to Ollama:**
- Ensure Ollama is healthy first (`docker compose ps`)
- Check `OLLAMA_BASE_URL=http://ollama:11434` matches the service name in compose

**SD WebUI extremely slow on CPU:**
- This is expected. GPU acceleration requires NVIDIA GPU + `nvidia-container-toolkit`
- Reduce image resolution to 512x512 in the WebUI settings

**Model download stuck:**
```bash
docker exec -it ollama ollama pull <model>
# or for SD:
docker exec -it stable-diffusion-webui python -c "from diffusers import StableDiffusionPipeline; ..."
```

## Related

- [Ollama Documentation](https://github.com/ollama/ollama)
- [Open WebUI Documentation](https://docs.openwebui.com/)
- [AUTOMATIC1111 Stable Diffusion WebUI](https://github.com/AUTOMATIC1111/stable-diffusion-webui)
