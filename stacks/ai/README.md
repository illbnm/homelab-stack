# AI Stack

Local AI services for HomeLab Stack — LLM chat, model serving, and image generation.

## What's Included

| Service | Version | URL | Purpose |
|---------|---------|-----|---------|
| Ollama | 0.3.14 | `ollama.<DOMAIN>` | Local LLM model server |
| Open WebUI | v0.3.35 | `ai.<DOMAIN>` | ChatGPT-like web interface |
| Stable Diffusion | v1.10.1 | `sd.<DOMAIN>` | AI image generation |

## Architecture

```
Users
  │
  ├──► ai.<DOMAIN>       ── Open WebUI (chat interface)
  │       │
  │       └──► ollama:11434 (LLM inference)
  │
  └──► sd.<DOMAIN>       ── Stable Diffusion (image gen)
          │
          └──► CPU or NVIDIA GPU

ollama.<DOMAIN>          ── Ollama API (direct access)
```

## Quick Start

```bash
cd stacks/base && docker compose up -d
cd ../ai
ln -sf ../../.env .env
docker compose up -d
```

### GPU Acceleration (NVIDIA)

If you have an NVIDIA GPU, use the GPU compose override:

```bash
docker compose -f docker-compose.yml up -d
```

Ollama auto-detects NVIDIA GPUs when the container has GPU access.

### CPU Only (Default)

The default compose runs on CPU. Stable Diffusion uses `--use-cpu all` flag.
LLM inference is slower on CPU — use smaller models (qwen2:0.5b, llama3.2:1b).

## Configuration

### Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `DOMAIN` | Yes | — | Base domain |
| `WEBUI_SECRET_KEY` | Yes | — | Secret key for Open WebUI sessions |
| `OLLAMA_GPU_ENABLED` | No | `false` | Enable GPU passthrough |

### Pulling Models

After starting Ollama, pull models:

```bash
# Small models (good for CPU)
docker exec ollama ollama pull qwen2:0.5b
docker exec ollama ollama pull llama3.2:1b

# Medium models (need GPU for reasonable speed)
docker exec ollama ollama pull llama3.1:8b
docker exec ollama ollama pull qwen2.5:7b

# List installed models
docker exec ollama ollama list
```

### Open WebUI Setup

1. Visit `https://ai.<DOMAIN>`
2. Create admin account (first launch)
3. Select model from top-left dropdown
4. Start chatting

### Stable Diffusion Setup

1. Visit `https://sd.<DOMAIN>`
2. Download a model (e.g., SDXL, Stable Diffusion 1.5) via the Models tab
3. Go to Generate tab, enter prompt, generate

## GPU Passthrough

For NVIDIA GPU support, add to `docker-compose.yml`:

```yaml
ollama:
  deploy:
    resources:
      reservations:
        devices:
          - driver: nvidia
            count: all
            capabilities: [gpu]
```

Requires NVIDIA Container Toolkit installed on host.

## CN Network Adaptation

Open WebUI and Stable Diffusion images are on `ghcr.io`:

```bash
CN_MODE=true ./scripts/cn-pull.sh
```

Ollama is on Docker Hub.

## Health Check

```bash
docker compose ps --format "table {{.Name}}\t{{.Status}}"
```

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Ollama OOM (out of memory) | Use smaller models; add swap on host |
| Open WebUI can't connect to Ollama | Ensure both on proxy network; URL = `http://ollama:11434` |
| Stable Diffusion very slow | Normal on CPU; use GPU or reduce image size |
| GPU not detected | Install NVIDIA Container Toolkit; check `nvidia-smi` on host |
| Model download timeout | Pull models manually: `docker exec ollama ollama pull <model>` |
