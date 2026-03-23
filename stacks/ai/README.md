# AI Stack

Local AI inference stack — Ollama + Open WebUI + Stable Diffusion + Perplexica.

## Services

| Service | Version | URL | Purpose |
|---------|---------|-----|---------|
| Ollama | 0.3.14 | `ollama.${DOMAIN}` (internal: `:11434`) | LLM inference engine |
| Open WebUI | 0.3.35 | `ai.${DOMAIN}` | Chat UI for Ollama |
| Stable Diffusion | latest | `sd.${DOMAIN}` | Image generation (optional) |
| Perplexica | latest | `search.${DOMAIN}` | AI-powered search engine |

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                      proxy network                       │
│  (Traefik reverse proxy — see stacks/base)              │
└──────┬───────────────┬──────────────┬────────────────────┘
       │               │              │
   ┌───┴───┐     ┌─────┴─────┐  ┌────┴────┐
   │ Ollama│     │Open WebUI │  │Perplexica│
   │  +    │◄────│  (chat)   │◄─│ (search) │
   │GPU/CPU│     └───────────┘  └──────────┘
   └───────┘
       │
   ┌───┴─────┐
   │ Stable  │  (optional, --profile sd)
   │Diffusion│
   └─────────┘
```

## Setup

### Prerequisites

- Base stack deployed (`stacks/base`) with Traefik and `proxy` network
- Docker 20.10+, Docker Compose v2

### 1. Configure environment

```bash
cd stacks/ai
cp .env.example .env
nano .env   # Set DOMAIN, WEBUI_SECRET_KEY, ENABLE_GPU
```

Generate a secret key for Open WebUI:

```bash
openssl rand -hex 32
```

### 2. GPU Mode Selection

| Mode | `ENABLE_GPU` value | Hardware |
|------|-------------------|----------|
| CPU only | `cpu` (default) | No GPU needed |
| NVIDIA CUDA | `nvidia` | NVIDIA GPU + nvidia-container-toolkit |
| AMD ROCm | `amd` | AMD GPU + ROCm |

For NVIDIA GPU acceleration, install [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html) first.

### 3. Deploy

```bash
# CPU mode (default)
docker compose up -d

# NVIDIA GPU mode
ENABLE_GPU=nvidia docker compose up -d

# AMD GPU mode
ENABLE_GPU=amd docker compose up -d

# With Stable Diffusion (optional)
docker compose --profile sd up -d
```

## Pull Models

### Ollama models

```bash
# Pull a model
docker exec ollama ollama pull llama3:8b

# List downloaded models
docker exec ollama ollama list
```

Recommended models:
- `llama3:8b` — General purpose (4.7GB)
- `mistral:7b` — Balanced performance (4.1GB)
- `qwen2.5:7b` — Multilingual (4.4GB)
- `codellama:7b` — Code generation (3.8GB)

### Stable Diffusion models

Access `sd.${DOMAIN}` → Extensions → Model Manager, or mount models into `sd_models:/app/models`.

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `DOMAIN` | `example.com` | Your domain for Traefik routing |
| `TZ` | `Asia/Shanghai` | Container timezone |
| `ENABLE_GPU` | `cpu` | GPU mode: `cpu`, `nvidia`, `amd` |
| `OLLAMA_PORT` | `11434` | Ollama API port |
| `WEBUI_SECRET_KEY` | _(required)_ | Open WebUI session secret |
| `DEFAULT_LOCALE` | `zh-CN` | Open WebUI language |
| `SD_ARGS` | _(see .env.example)_ | Stable Diffusion CLI args |
| `SEARCH_MODELS` | `llama3:8b` | Perplexica search model |

## Routing

| Service | Subdomain | Port | Auth |
|---------|-----------|------|------|
| Open WebUI | `ai.${DOMAIN}` | 8080 | Yes (managed by Open WebUI) |
| Ollama API | `ollama.${DOMAIN}` | 11434 | Traefik basic auth (if configured) |
| Stable Diffusion | `sd.${DOMAIN}` | 7860 | No |
| Perplexica | `search.${DOMAIN}` | 3000 | No |

## Health Checks

All services have healthchecks. Monitor with:

```bash
docker compose ps
```

Wait for all services to reach `Up (healthy)` before first use.

## Security

- Containers run with `no-new-privileges:true`
- HTTPS enforced via Traefik Let's Encrypt
- Watchtower auto-updates enabled on all containers
- `WEBUI_SECRET_KEY` must be set to a strong random value

## Troubleshooting

### Ollama fails to start with GPU

```bash
# Verify NVIDIA runtime
docker run --rm --gpus all nvidia/cuda:12.1 nvidia-smi

# Verify nvidia-container-toolkit
nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker
```

### Open WebUI can't reach Ollama

Ensure both are on the `ai` network and Ollama is healthy:

```bash
docker compose logs ollama
docker exec open-webui wget -qO- http://ollama:11434/api/tags
```

### Stable Diffusion slow on CPU

Reduce memory usage:

```bash
SD_ARGS="--no-half --lowvram --medvram" docker compose --profile sd up -d
```
