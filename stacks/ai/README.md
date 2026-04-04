# AI Stack — Ollama + Open WebUI + Stable Diffusion + Perplexica

Complete AI infrastructure for HomeLab with local LLM inference, web UI, image generation, and AI-powered search.

## Architecture

```
Browser
  │
  ▼
Traefik (443)
  │
  ├── ai.DOMAIN        → Open WebUI (LLM Chat)
  ├── ollama.DOMAIN    → Ollama API
  ├── sd.DOMAIN        → Stable Diffusion WebUI (Image Gen)
  └── search.DOMAIN    → Perplexica (AI Search)

Internal:
  open-webui ──────▶ ollama:11434
  perplexica ──────▶ ollama:11434
  perplexica ──────▶ (External: Brave/Google/Tavily APIs)
```

## Services

| Service | Image | Port | Purpose |
|---------|-------|------|---------|
| Ollama | `ollama/ollama:0.3.14` | 11434 | Local LLM runtime |
| Open WebUI | `ghcr.io/open-webui/open-webui:v0.3.35` | 8080 | User-friendly LLM chat interface |
| Stable Diffusion | `ghcr.io/abiosoft/sd-webui-docker:2.0.2` | 7860 | AI image generation |
| Perplexica | `ghcr.io/itzderock/perplexica:2.1` | 3000 | AI-powered search engine |
| ScyllaDB | `scylladb/scylla:5.4.3` | 9042 (int) | Vector database (optional) |

## Prerequisites

- Base stack running (`stacks/base/` — Traefik + proxy network)
- SSO stack running (`stacks/sso/` — Authentik) for OIDC
- Domain with DNS pointing to your server
- Ports 80 + 443 open

### GPU Requirements

| GPU Type | Configuration |
|----------|---------------|
| NVIDIA | Auto-detected via nvidia-docker |
| AMD ROCm | Set `SD_USE_AMD_GPU=1` in .env |
| CPU Only | Set `SD_GPU_ENABLED=false`, `OLLAMA_GPU_ENABLED=false` |

## Quick Start

```bash
# 1. Navigate to AI stack directory
cd stacks/ai

# 2. Copy and fill environment variables
cp .env.example .env
nano .env  # Fill ALL required values

# 3. Generate secret key
export WEBUI_SECRET_KEY=$(openssl rand -base64 32)
sed -i "s|^WEBUI_SECRET_KEY=.*|WEBUI_SECRET_KEY=$WEBUI_SECRET_KEY|" .env

# 4. Start the stack
docker compose up -d

# 5. Wait for healthy services
docker compose ps
# All should show "healthy" status

# 6. Download initial models (optional)
# Ollama: Visit http://ollama.ai or use Open WebUI
# Stable Diffusion: Models auto-download on first use

# 7. Setup OIDC (optional, requires Authentik)
../../scripts/setup-authentik.sh
```

## Environment Variables

### General

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `DOMAIN` | Yes | — | Your base domain |
| `TZ` | No | Asia/Shanghai | Timezone |
| `AUTHENTIK_DOMAIN` | For OIDC | — | Authentik domain |

### Open WebUI

| Variable | Required | Description |
|----------|----------|-------------|
| `WEBUI_SECRET_KEY` | Yes | Secret key — generate with `openssl rand -base64 32` |
| `OIDC_ENABLED` | No | Set to `true` to enable OIDC SSO |
| `OPEN_WEBUI_OIDC_CLIENT_ID` | If OIDC | OAuth2 client ID |
| `OPEN_WEBUI_OIDC_CLIENT_SECRET` | If OIDC | OAuth2 client secret |

### Stable Diffusion

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `SD_GPU_ENABLED` | No | true | Enable GPU acceleration |
| `SD_USE_AMD_GPU` | No | 0 | Set to 1 for AMD ROCm |
| `SD_COMMANDLINE_ARGS` | No | — | Additional WebUI args |

### Perplexica

| Variable | Required | Description |
|----------|----------|-------------|
| `BRAVE_SEARCH_API_KEY` | At least one | Brave Search API key (recommended) |
| `GOOGLE_SEARCH_API_KEY` | of these | Google Custom Search API key |
| `TAVILY_API_KEY` | required | Tavily API key |

## Access URLs

After starting the stack:

| Service | URL |
|---------|-----|
| Open WebUI | https://ai.DOMAIN |
| Ollama API | https://ollama.DOMAIN |
| Stable Diffusion | https://sd.DOMAIN |
| Perplexica | https://search.DOMAIN |

## Model Management

### Ollama Models

```bash
# Pull a model
docker exec -it ollama ollama pull llama3.1

# List installed models
docker exec -it ollama ollama list

# Remove a model
docker exec -it ollama ollama rm llama3.1
```

### Stable Diffusion Models

Place models in the volume:
```bash
# List model files
docker exec -it stable-diffusion ls /app/models/Stable-diffusion/

# Copy custom models
docker cp /path/to/model.safetensors stable-diffusion:/app/models/Stable-diffusion/
```

## OIDC Integration

### Enable OIDC

1. Set `OIDC_ENABLED=true` in `.env`
2. Run `../../scripts/setup-authentik.sh` to create Authentik provider
3. The script will populate `OPEN_WEBUI_OIDC_CLIENT_ID` and `OPEN_WEBUI_OIDC_CLIENT_SECRET`
4. Restart: `docker compose restart open-webui`

### Services with OIDC Support

- **Open WebUI**: OIDC login via Authentik
- **Perplexica**: Optional OIDC (set `OIDC_ENABLED=true`)

## GPU Configuration

### NVIDIA GPU

Auto-detected if nvidia-docker is installed:

```bash
# Verify GPU detection
docker run --rm --gpus all nvidia/cuda:12.0-base-ubuntu22.04 nvidia-smi
```

### AMD GPU (ROCm)

Edit `.env`:
```bash
SD_USE_AMD_GPU=1
SD_GPU_ENABLED=true
```

### CPU Only

Edit `.env`:
```bash
SD_GPU_ENABLED=false
OLLAMA_GPU_ENABLED=false
```

### Docker GPU Runtime

Ensure nvidia-docker is installed:
```bash
# Install nvidia-docker
distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | sudo apt-key add -
curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | \
  sudo tee /etc/apt/sources.list.d/nvidia-docker.list
sudo apt-get update && sudo apt-get install -y nvidia-container-toolkit
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker
```

## Health Check

```bash
# All containers healthy
docker compose ps

# Ollama API
curl -sf https://ollama.DOMAIN/api/tags && echo "Ollama OK"

# Open WebUI
curl -sf https://ai.DOMAIN/health && echo "WebUI OK"

# Stable Diffusion
curl -sf https://sd.DOMAIN/ && echo "SD OK"

# Perplexica
curl -sf https://search.DOMAIN/api/health && echo "Perplexica OK"
```

## Data Persistence

| Volume | Purpose |
|--------|---------|
| `ollama-data` | Downloaded LLM models |
| `open-webui-data` | Chat history, settings |
| `sd-models` | Custom Stable Diffusion models |
| `sd-output` | Generated images |
| `perplexica-data` | Search configuration |

## CN Mirror

If `ghcr.io` is inaccessible, edit `docker-compose.yml` and uncomment CN mirror lines:

```yaml
# Example for Ollama
# image: swr.cn-north-4.myhuaweicloud.com/ddn-k8s/ghcr.io/ollama/ollama:0.3.14
```

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| Ollama fails to start | Check GPU detection: `docker exec ollama nvidia-smi` |
| Open WebUI can't connect to Ollama | Wait for Ollama to be healthy, check network |
| Stable Diffusion slow on CPU | Normal — GPU strongly recommended |
| Perplexica search fails | Check at least one API key is set |
| OIDC login loop | Verify callback URL in Authentik matches |
| GPU not detected | Install nvidia-docker or set CPU mode |
| `ghcr.io` pull timeout | Use CN mirror in docker-compose.yml |

## File Structure

```
stacks/ai/
├── docker-compose.yml    # Main configuration
├── .env.example          # Environment template
├── .env                  # Your configuration (gitignored)
└── README.md             # This file
```