# AI Stack

Local AI inference — Ollama + Open WebUI + optional Stable Diffusion.

## Services

| Service | Version | URL | Purpose |
|---------|---------|-----|---------|
| Ollama | 0.3.12 | :11434 (internal) | LLM inference engine |
| Open WebUI | 0.3.32 | ai.yourdomain.com | Chat UI |
| Stable Diffusion | latest | sd.yourdomain.com | Image generation (optional) |

## Setup

```bash
cp .env.example .env
nano .env   # Set DOMAIN, WEBUI_SECRET_KEY, ENABLE_GPU

# CPU mode (default)
docker compose up -d

# GPU mode (requires NVIDIA drivers + nvidia-container-toolkit)
ENABLE_GPU=true docker compose up -d

# With Stable Diffusion
docker compose --profile sd up -d
```

## Pull Models

```bash
# Pull a model (runs inside the ollama container)
docker exec ollama ollama pull llama3.2
docker exec ollama ollama pull qwen2.5:7b
docker exec ollama ollama pull nomic-embed-text

# List available models
docker exec ollama ollama list
```

## Access

- **Open WebUI**: https://ai.yourdomain.com — create account on first visit
- **Ollama API**: http://localhost:11434 (local only)
- **Stable Diffusion**: https://sd.yourdomain.com (if profile enabled)

## GPU Prerequisites

```bash
# Install NVIDIA Container Toolkit
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
# Follow: https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html
```

## Requires

- Base stack running (proxy network)
