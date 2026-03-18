# AI Stack

Local AI inference suite: **LLM chat**, **image generation**, and **AI-powered search** — with automatic GPU detection.

## Services

| Service | URL | Purpose |
|---------|-----|---------|
| [Ollama](https://ollama.com/) | `ollama.yourdomain.com` | LLM inference engine |
| [Open WebUI](https://openwebui.com/) | `ai.yourdomain.com` | ChatGPT-like interface for Ollama |
| [Stable Diffusion](https://github.com/AUTOMATIC1111/stable-diffusion-webui) | `sd.yourdomain.com` | Image generation |
| [Perplexica](https://github.com/ItzCrazyKns/Perplexica) | `search.yourdomain.com` | AI-powered search engine |

## Architecture

```
                    ┌─────────────┐
                    │   Traefik   │
                    │   :443      │
                    └──────┬──────┘
           ┌───────┬───────┼───────┬──────────┐
           ▼       ▼       ▼       ▼          ▼
      ┌────────┐ ┌──────┐ ┌────┐ ┌──────┐ ┌───────┐
      │  Open  │ │Ollama│ │ SD │ │Perp. │ │ Perp. │
      │ WebUI  │ │:11434│ │:7860│ │Front │ │ Back  │
      │ :8080  │ │      │ │    │ │:3000 │ │:3001  │
      └───┬────┘ └──┬───┘ └────┘ └──────┘ └───┬───┘
          │         │                          │
          └────►────┘◄─────────────────────────┘
                    │ (Ollama API)
                    ▼
              ┌───────────┐
              │  SearXNG   │ (Perplexica search backend)
              │   :8080    │
              └────────────┘
```

## GPU Support

The stack supports three GPU modes:

| Mode | Runtime | Performance | Setup |
|------|---------|-------------|-------|
| NVIDIA | `nvidia` | Best | Install [nvidia-container-toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html) |
| AMD | `rocm` | Good | Install [ROCm](https://rocm.docs.amd.com/) |
| CPU | (none) | Slow but works | No setup needed |

### Auto-detection

```bash
# Run GPU detection script (auto-updates .env)
bash scripts/detect-gpu.sh
```

### Manual Configuration

```bash
# NVIDIA GPU
GPU_RUNTIME=nvidia
SD_ARGS=--xformers

# CPU only (default)
GPU_RUNTIME=
SD_ARGS=--no-half --skip-torch-cuda-test --use-cpu all --precision full
```

## Quick Start

```bash
# 1. Copy environment template
cp .env.example .env

# 2. Detect GPU and configure
bash scripts/detect-gpu.sh

# 3. Generate secrets
sed -i "s/^WEBUI_SECRET_KEY=.*/WEBUI_SECRET_KEY=$(openssl rand -hex 32)/" .env

# 4. Start the stack
docker compose up -d

# 5. Pull a model (auto-pulled on first start, or manually)
docker exec ollama ollama pull qwen2.5:7b
docker exec ollama ollama pull llama3.1:8b
```

## Service Configuration

### Ollama

**Pulling models:**
```bash
# List available models
docker exec ollama ollama list

# Pull models
docker exec ollama ollama pull qwen2.5:7b      # Chinese + English
docker exec ollama ollama pull llama3.1:8b      # English
docker exec ollama ollama pull codellama:7b     # Code generation
docker exec ollama ollama pull nomic-embed-text # Embeddings (for RAG)
```

**API usage:**
```bash
# Generate text
curl https://ollama.yourdomain.com/api/generate \
  -d '{"model": "qwen2.5:7b", "prompt": "Hello!"}'

# Chat
curl https://ollama.yourdomain.com/api/chat \
  -d '{"model": "qwen2.5:7b", "messages": [{"role": "user", "content": "Hi"}]}'
```

**Memory requirements:**

| Model | Parameters | RAM/VRAM |
|-------|-----------|----------|
| qwen2.5:7b | 7B | ~5 GB |
| llama3.1:8b | 8B | ~5 GB |
| qwen2.5:14b | 14B | ~10 GB |
| llama3.1:70b | 70B | ~40 GB |

### Open WebUI

**First login:** The first user to register becomes admin.

**Features:**
- Chat with multiple Ollama models
- RAG (upload documents for context)
- Web search integration
- Model management
- Conversation history

### Stable Diffusion

**First start is slow** (~5-10 minutes) — downloads base model.

**CPU mode notes:**
- Generation is slow (2-5 minutes per image)
- Use small resolutions (512×512)
- Consider disabling on CPU-only servers

### Perplexica

AI-powered search that combines web search (via SearXNG) with LLM reasoning.

**Configuration:**
- Edit `perplexica-config.toml` to set API keys for external LLMs
- Default: uses local Ollama for all inference
- SearXNG settings in `searxng-settings.yml`

## Subdomains

| Subdomain | Service |
|-----------|---------|
| `ai.yourdomain.com` | Open WebUI |
| `ollama.yourdomain.com` | Ollama API |
| `sd.yourdomain.com` | Stable Diffusion |
| `search.yourdomain.com` | Perplexica |

## Volumes

| Volume | Content | Size Estimate |
|--------|---------|---------------|
| `ollama-data` | Downloaded models | 5-50+ GB |
| `open-webui-data` | Chat history, uploads, settings | ~100 MB |
| `sd-models` | Stable Diffusion models | 5-20+ GB |
| `sd-output` | Generated images | Variable |
| `perplexica-data` | Search history | ~50 MB |

## Troubleshooting

### "CUDA out of memory"
Reduce model size or limit concurrent models:
```bash
OLLAMA_MAX_MODELS=1
OLLAMA_NUM_PARALLEL=1
```

### Stable Diffusion won't start
Check logs: `docker logs stable-diffusion`
On CPU, the first start downloads ~4 GB model — allow 10+ minutes.

### Perplexica search returns empty
1. Check SearXNG is running: `docker logs perplexica-searxng`
2. Verify search engines are enabled in `searxng-settings.yml`
3. Test SearXNG directly: `curl http://localhost:8080/search?q=test&format=json` (from within the container)

### GPU not detected
```bash
# Verify NVIDIA toolkit
nvidia-smi
docker run --rm --gpus all nvidia/cuda:12.0-base nvidia-smi

# Re-run detection
bash scripts/detect-gpu.sh
```
