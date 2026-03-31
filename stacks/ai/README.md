# 🤖 AI Stack - Local AI Inference Platform

> Self-hosted AI services with GPU acceleration support

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](../../LICENSE)
[![Docker](https://img.shields.io/badge/docker-required-blue.svg)](https://docs.docker.com/get-docker/)
[![GPU Support](https://img.shields.io/badge/GPU-NVIDIA%20%7C%20AMD%20%7C%20CPU-green.svg)](#gpu-configuration)

## 📦 Services

| Service | Description | Port | GPU Support |
|---------|-------------|------|-------------|
| [Ollama](https://github.com/ollama/ollama) | Local LLM inference engine | 11434 | ✅ |
| [Open WebUI](https://github.com/open-webui/open-webui) | User-friendly chat interface | 8080 | - |
| [Stable Diffusion](https://github.com/AUTOMATIC1111/stable-diffusion-webui) | AI image generation | 7860 | ✅ |
| [Perplexica](https://github.com/itsundera/perplexica) | AI-powered search engine | 3000 | ✅ |

## 🚀 Quick Start

### 1. Prerequisites

Ensure you have Docker and the base infrastructure running:

```bash
# Check if base stack is running
docker compose -f docker-compose.base.yml ps
```

### 2. GPU Configuration

This stack supports automatic GPU detection. The configuration will automatically use:

- **NVIDIA GPUs**: CUDA acceleration via `nvidia-docker`
- **AMD GPUs**: ROCm support
- **No GPU / CPU-only**: Falls back to CPU inference

For CPU-only mode, set in your `.env`:

```bash
GPU_TYPE=cpu
```

### 3. Deploy

```bash
# Copy environment template
cp stacks/ai/.env.example .env

# Edit .env with your settings
nano .env

# Start the stack
docker compose -f stacks/ai/docker-compose.yml up -d
```

### 4. Verify

```bash
# Check container status
docker compose -f stacks/ai/docker-compose.yml ps

# Check Ollama health
curl http://localhost:11434/api/tags

# Check Open WebUI
curl http://localhost:8080/health
```

## 🔧 Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `DOMAIN` | `localhost` | Your domain for Traefik |
| `GPU_TYPE` | `auto` | GPU type: auto, nvidia, amd, cpu |
| `DEFAULT_MODEL` | `llama3.2` | Default Ollama model |
| `WEBUI_SECRET_KEY` | - | Secret key for Open WebUI sessions |
| `DEFAULT_LOCALE` | `zh-CN` | UI language |

### GPU Configuration

#### NVIDIA GPUs

1. Install [nvidia-docker](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html)
2. The stack automatically detects NVIDIA GPUs

```bash
# Verify NVIDIA runtime
docker info | grep nvidia
```

#### AMD GPUs

For AMD GPUs, add these additional options in your `.env`:

```bash
# AMD ROCm configuration
GPU_TYPE=amd
```

And update the docker-compose.yml to mount ROCm devices:

```yaml
services:
  ollama:
    volumes:
      - ollama-data:/root/.ollama
    environment:
      - HSA_OVERRIDE_GFX_VERSION=10.3.0  # Adjust for your GPU
    devices:
      - /dev/kfd:/dev/kfd
      - /dev/dri:/dev/dri
```

#### CPU Only

For systems without GPUs:

```bash
# In .env
GPU_TYPE=cpu
```

The Stable Diffusion service will use CPU mode:

```bash
# Update SD args for CPU
SD_ARGS=--api --listen --cpu --precision full --no-half
```

## 📖 Usage

### Accessing Services

After deployment, services are available at:

- **Open WebUI**: `https://ai.yourdomain.com`
- **Ollama API**: `https://ollama.yourdomain.com`
- **Stable Diffusion**: `https://sd.yourdomain.com`
- **Perplexica**: `https://search.yourdomain.com`

### Using Ollama CLI

```bash
# Pull models
docker exec ollama ollama pull llama3.2
docker exec ollama ollama pull codellama
docker exec ollama ollama pull mistral

# List models
docker exec ollama ollama list

# Test API
curl http://localhost:11434/api/generate -d '{
  "model": "llama3.2",
  "prompt": "Hello!",
  "stream": false
}'
```

### Using Perplexica

1. Open `https://search.yourdomain.com`
2. Select search mode (All, Academic, Writing, etc.)
3. Enter your search query
4. Perplexica uses Ollama to provide AI-enhanced results

### Image Generation

1. Open Open WebUI at `https://ai.yourdomain.com`
2. Enable image generation in settings
3. Use the `/img` command or select image generation mode

## 🔍 Health Checks

Each service has built-in health checks:

```bash
# Ollama
docker exec ollama curl -sf http://localhost:11434/api/tags

# Open WebUI
docker exec open-webui wget -q --spider http://localhost:8080/health

# Stable Diffusion
docker exec stable-diffusion curl -sf http://localhost:7860/sdapi/v1/sd-models

# Perplexica
docker exec perplexica wget -q --spider http://localhost:3000/api/health
```

## 🔧 Troubleshooting

### Ollama not starting

```bash
# Check logs
docker logs ollama

# Verify GPU detection
docker exec ollama nvidia-smi  # For NVIDIA
```

### Models not loading

```bash
# Check available disk space
df -h

# Check Docker disk usage
docker system df
```

### Slow inference

- Reduce `OLLAMA_NUM_PARALLEL` to 1
- Increase `OLLAMA_NUM_THREADS`
- Use smaller models

### GPU not detected

```bash
# NVIDIA: Check nvidia-smi
nvidia-smi

# AMD: Check ROCm
rocm-smi

# Verify Docker GPU access
docker run --rm --gpus all nvidia/cuda:12.0-base nvidia-smi
```

## 💾 Data Persistence

All data is stored in Docker volumes:

- `ollama-data` - Ollama models and settings
- `open-webui-data` - Chat history and user data
- `open-webui-models` - Downloaded models for WebUI
- `sd-models` - Stable Diffusion models
- `sd-output` - Generated images
- `perplexica-data` - Search index database

## 🔐 Security

- All services are behind Traefik with HTTPS
- Open WebUI can be protected with authentication (set `WEBUI_AUTH=true`)
- Forward Auth integration with Authentik (optional)

## 📦 Requirements

- Docker Engine 24+
- Docker Compose v2.20+
- 4GB RAM minimum (8GB+ recommended for AI workloads)
- NVIDIA GPU with CUDA (optional) or AMD GPU with ROCm (optional)

## 🤝 Contributing

See [CONTRIBUTING.md](../../CONTRIBUTING.md) for contribution guidelines.

## 📄 License

MIT License - see [LICENSE](../../LICENSE) for details.