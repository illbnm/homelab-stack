# AI Stack

Local AI inference and image generation for HomeLab.

## What's Included

| Service | Version | URL | Purpose |
|---------|---------|-----|---------|
| Ollama | 0.3.12 | `ollama.<DOMAIN>` | LLM inference engine |
| Open WebUI | 0.3.32 | `ai.<DOMAIN>` | Chat UI for Ollama |
| Stable Diffusion | latest | `sd.<DOMAIN>` | AI image generation |
| Perplexica | main | `search.<DOMAIN>` | AI-powered search engine |
| SearXNG | latest | (internal) | Privacy metasearch (Perplexica backend) |

## Architecture

```
User → ai.<DOMAIN> (Open WebUI)
         ↓
         ollama:11434 (Ollama LLM)
         ↓
         Local inference (no data leaves server)

User → sd.<DOMAIN> (Stable Diffusion WebUI)
         ↓
         Local image generation

User → search.<DOMAIN> (Perplexica)
         ↓
         searxng:8080 → Web search
         ↓
         ollama:11434 → AI summarization
```

## GPU Support

This stack supports three GPU runtime modes via `GPU_RUNTIME` environment variable:

| Mode | Requirements | Performance |
|------|-------------|-------------|
| `nvidia` | NVIDIA GPU + nvidia-container-toolkit | ⚡ Fastest |
| `amd` | AMD GPU with ROCm support | ⚡ Fast |
| `cpu` | No GPU required | 🐢 Slower but works everywhere |

### NVIDIA GPU Setup

```bash
# Install nvidia-container-toolkit
sudo apt-get install -y nvidia-container-toolkit
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker

# Set GPU runtime
echo "GPU_RUNTIME=nvidia" >> .env

# Start with NVIDIA profile
docker compose --profile nvidia up -d
```

### AMD GPU Setup

```bash
# Ensure ROCm is installed and /dev/kfd, /dev/dri exist
ls -la /dev/kfd /dev/dri

# Set GPU runtime
echo "GPU_RUNTIME=amd" >> .env

# Start with AMD profile
docker compose --profile amd up -d
```

### CPU-Only Setup (Default)

```bash
# Set GPU runtime (or leave default)
echo "GPU_RUNTIME=cpu" >> .env

# Start with CPU profile
docker compose --profile cpu up -d
```

## Prerequisites

- Base infrastructure stack running (Traefik + proxy network)
- Docker Compose v2.20+
- (Optional) NVIDIA GPU + nvidia-container-toolkit for GPU acceleration
- (Optional) AMD GPU with ROCm for AMD support

## Quick Start

```bash
# 1. Navigate to AI stack
cd stacks/ai

# 2. Copy environment template
cp .env.example .env

# 3. Edit .env with your domain and secrets
nano .env

# 4. Start the stack (choose your profile)
# CPU mode (default):
docker compose --profile cpu up -d

# NVIDIA GPU mode:
docker compose --profile nvidia up -d

# AMD GPU mode:
docker compose --profile amd up -d
```

## Configuration

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `DOMAIN` | ✅ | - | Base domain for Traefik routing |
| `TZ` | ⚪ | `Asia/Shanghai` | Timezone |
| `GPU_RUNTIME` | ⚪ | `cpu` | GPU mode: `nvidia`, `amd`, or `cpu` |
| `WEBUI_SECRET_KEY` | ✅ | - | Secret key for Open WebUI sessions |
| `DEFAULT_LOCALE` | ⚪ | `zh-CN` | Open WebUI language |
| `SEARXNG_SECRET` | ✅ | - | Secret for SearXNG |

### Generate Secrets

```bash
# Open WebUI secret
openssl rand -hex 32

# SearXNG secret
openssl rand -hex 32
```

## Post-Deploy Setup

### Ollama Models

Pull models via CLI or Open WebUI:

```bash
# Pull popular models
docker exec ollama ollama pull llama3.2:3b
docker exec ollama ollama pull qwen2.5:7b
docker exec ollama ollama pull mistral:7b
docker exec ollama ollama pull deepseek-r1:7b

# List installed models
docker exec ollama ollama list
```

### Open WebUI

1. Open `https://ai.<DOMAIN>`
2. Create admin account (first visit)
3. Select model from dropdown
4. Start chatting!

### Stable Diffusion

1. Open `https://sd.<DOMAIN>`
2. First launch downloads models automatically (~4GB)
3. Use `--xformers` flag on NVIDIA for faster generation
4. Generated images saved to `sd-output` volume

### Perplexica

1. Open `https://search.<DOMAIN>`
2. Type your question
3. Perplexica searches the web and summarizes with AI
4. Uses local Ollama for privacy

## Health Checks

All services include health checks:

```bash
# Check all AI services
docker compose ps

# Check specific service
docker logs ollama --tail 50
docker logs open-webui --tail 50
docker logs stable-diffusion --tail 50
docker logs perplexica --tail 50
```

## Troubleshooting

### Ollama out of memory

```bash
# Reduce model context
docker exec ollama ollama run llama3.2:3b --num-ctx 2048

# Or pull smaller model
docker exec ollama ollama pull llama3.2:1b
```

### Stable Diffusion slow on CPU

CPU mode is slow (1-5 min per image). For faster generation:
- Use NVIDIA GPU with `--profile nvidia`
- Use AMD GPU with `--profile amd`
- Or reduce image resolution in settings

### Perplexica can't connect to Ollama

```bash
# Verify Ollama is running
docker logs ollama --tail 20

# Check network connectivity
docker exec perplexica curl -s http://ollama:11434/api/tags
```

### GPU not detected (NVIDIA)

```bash
# Check NVIDIA runtime
docker run --rm --gpus all nvidia/cuda:12-base nvidia-smi

# If fails, reinstall nvidia-container-toolkit
sudo apt-get purge nvidia-container-toolkit
sudo apt-get install -y nvidia-container-toolkit
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker
```

## Resource Requirements

| Service | CPU | RAM | GPU | Storage |
|---------|-----|-----|-----|---------|
| Ollama | 2+ cores | 8GB+ | Optional | 10GB+ (models) |
| Open WebUI | 1 core | 1GB | None | 1GB |
| Stable Diffusion | 4+ cores | 8GB+ | Recommended | 10GB+ (models) |
| Perplexica | 2 cores | 2GB | None | 500MB |
| SearXNG | 1 core | 512MB | None | 100MB |

**Minimum for CPU mode:** 8GB RAM, 20GB storage
**Recommended for GPU mode:** 16GB+ RAM, NVIDIA RTX 3060+ or AMD RX 6600+

## Security Notes

- Ollama API exposed at `ollama.<DOMAIN>` (consider restricting)
- Open WebUI requires authentication after first admin setup
- Perplexica and SearXNG are internal services (not directly exposed)
- All traffic goes through Traefik with TLS

## License

Each service has its own license. See individual documentation for details.