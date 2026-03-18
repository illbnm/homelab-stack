# AI Stack

Local AI inference and chat interface, fully self-hosted.

**Components:**
- [Ollama](https://ollama.com/) — Local LLM inference server (100+ models)
- [Open WebUI](https://github.com/open-webui/open-webui) — Feature-rich chat interface with RAG, voice, and user management
- [Stable Diffusion WebUI](https://github.com/AUTOMATIC1111/stable-diffusion-webui) — Image generation (optional, GPU profile)

## Prerequisites

**CPU-only:** Docker + Docker Compose v2. Works but is slow for large models. Use 7B parameter models or smaller.

**GPU (recommended):** NVIDIA GPU with NVIDIA Container Toolkit installed:
```bash
# Install NVIDIA Container Toolkit
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
  sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
  sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
sudo apt-get update && sudo apt-get install -y nvidia-container-toolkit
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker
```

## Quick Start

```bash
cp .env.example .env
nano .env  # Set DOMAIN and WEBUI_SECRET_KEY

# CPU mode
docker compose up -d

# GPU mode (recommended)
docker compose --profile gpu up -d
```

## Pulling Models

After starting Ollama, pull models via the CLI:

```bash
# Small, fast (4GB VRAM)
docker exec ollama ollama pull llama3.2:3b

# Balanced (8GB VRAM)
docker exec ollama ollama pull llama3.1:8b
docker exec ollama ollama pull qwen2.5:7b

# Code generation (6GB VRAM)
docker exec ollama ollama pull deepseek-coder-v2:16b

# List downloaded models
docker exec ollama ollama list

# GPU memory usage
nvidia-smi
```

## Access

| Service | URL |
|---------|-----|
| Open WebUI | `https://ai.YOUR_DOMAIN` |
| Ollama API | `http://ollama:11434` (internal only) |
| Stable Diffusion | `https://sd.YOUR_DOMAIN` (GPU profile) |

## First Setup

1. Open `https://ai.YOUR_DOMAIN` in your browser
2. Create the first admin account (subsequent signups blocked by default)
3. Go to **Settings → Models** to select your default model
4. Start chatting!

## Stable Diffusion (Optional)

Image generation requires a GPU and additional VRAM (8GB+ recommended):

```bash
docker compose --profile sd up -d stable-diffusion
```

Access at `https://sd.YOUR_DOMAIN` — LAN restricted by default.

## Enable Image Generation in Open WebUI

1. Pull ComfyUI or configure Automatic1111 URL in Open WebUI
2. Settings → Admin → Images → set URL to `http://stable-diffusion:7860`
3. Enable `ENABLE_IMAGE_GENERATION=true` in `.env`
4. Restart: `docker compose up -d`

## Performance Tips

- **VRAM > 8GB:** Use 13B+ parameter models for better quality
- **Multiple users:** Increase `OLLAMA_NUM_PARALLEL` to handle concurrent requests
- **Model pre-loading:** Set `DEFAULT_MODELS` to avoid cold-start delay
- **Flash Attention:** Already enabled via `OLLAMA_FLASH_ATTENTION=1` (faster inference)

## Connecting Other Services

Other stacks can use Ollama via the `ai` network:

```yaml
networks:
  - ai

environment:
  - OLLAMA_URL=http://ollama:11434
```
