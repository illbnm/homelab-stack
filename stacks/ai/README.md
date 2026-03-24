# AI Stack

Local AI inference and image generation for HomeLab.

## What's Included

| Service | Version | URL | Purpose |
|---------|---------|-----|---------|
| Ollama | 0.3.14 | `ollama.<DOMAIN>` | LLM inference engine |
| Open WebUI | 0.3.35 | `ai.<DOMAIN>` | Chat UI for Ollama |
| Stable Diffusion | CPU v1.10.1 | `sd.<DOMAIN>` | AI image generation |

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
```

## Prerequisites

- Base infrastructure stack running (Traefik + proxy network)
- (Optional) NVIDIA GPU + nvidia-container-toolkit for GPU acceleration

## Quick Start

```bash
cd stacks/ai
cp .env.example .env
# Edit .env with your credentials
docker compose up -d
```

## Configuration

| Variable | Required | Description |
|----------|----------|-------------|
| `DOMAIN` | ✅ | Base domain |
| `TZ` | ✅ | Timezone |
| `WEBUI_SECRET_KEY` | ✅ | Secret key for Open WebUI sessions |
| `OLLAMA_GPU_ENABLED` | ❌ | Default: `false` |

## GPU Setup (Optional)

If you have an NVIDIA GPU:

1. Install nvidia-container-toolkit:
   ```bash
   sudo apt-get install -y nvidia-container-toolkit
   sudo nvidia-ctk runtime configure --runtime=docker
   sudo systemctl restart docker
   ```

2. Add GPU config to ollama service in `docker-compose.yml`:
   ```yaml
   deploy:
     resources:
       reservations:
         devices:
           - driver: nvidia
             count: all
             capabilities: [gpu]
   ```

## Post-Deploy Setup

1. **Ollama**: Pull models via CLI or Open WebUI
   ```bash
   docker exec ollama ollama pull llama3.2:3b
   docker exec ollama ollama pull qwen2.5:7b
   ```
2. **Open WebUI**: Open `https://ai.<DOMAIN>` — create admin account
3. **Stable Diffusion**: Open `https://sd.<DOMAIN>` — models download on first use

## Health Checks

```bash
docker compose ps
```
