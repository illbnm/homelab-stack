# AI Stack — Local AI Services

Complete local AI inference stack with CPU/GPU adaptive deployment.

## Services

| Service | Image | Port | Purpose |
|---------|-------|------|---------|
| Ollama | `ollama/ollama:0.3.14` | 11434 | LLM inference engine |
| Open WebUI | `ghcr.io/open-webui/open-webui:v0.3.35` | 8080 | LLM web interface |
| Stable Diffusion | `ghcr.io/abiosoft/sd-webui-docker` | 7860 | Image generation |
| Perplexica | `itzcrazykns1337/perplexica:main` | 3000 | AI search engine |
| SearXNG | `searxng/searxng:latest` | 8080 | Metasearch engine |

## Quick Start

### 1. GPU Detection

```bash
# Detect available GPUs
./scripts/detect-gpu.sh

# Auto-configure for your hardware
./scripts/detect-gpu.sh --configure
```

### 2. Environment Setup

```bash
cd stacks/ai
cp ../../.env.example ../../.env
nano ../../.env  # Configure GPU settings
```

### 3. Start Stack

```bash
docker compose up -d
```

### 4. Access Services

- **Open WebUI**: https://ai.${DOMAIN}
- **Ollama API**: https://ollama.${DOMAIN}
- **Stable Diffusion**: https://sd.${DOMAIN}
- **Perplexica**: https://search.${DOMAIN}

## GPU Configuration

### NVIDIA GPU

```bash
# .env configuration
OLLAMA_GPU_ENABLED=true
CUDA_VISIBLE_DEVICES=0
SD_IMAGE_TAG=cuda-v1.10.1
SD_COMMANDLINE_ARGS=--xformers --share
```

**Requirements**:
- NVIDIA Driver >= 525.0
- Docker with NVIDIA Container Toolkit
- CUDA 12.x

### AMD GPU (ROCm)

```bash
# .env configuration
OLLAMA_GPU_ENABLED=true
SD_IMAGE_TAG=rocm-v1.10.1
SD_COMMANDLINE_ARGS=--precision full --no-half --opt-sub-quad-attention
```

**Requirements**:
- ROCm 5.x
- Docker with ROCm support

### Apple Silicon (Metal)

```bash
# .env configuration
OLLAMA_GPU_ENABLED=true
SD_IMAGE_TAG=cpu-v1.10.1  # No Metal support for SD yet
SD_COMMANDLINE_ARGS=--no-half --skip-torch-cuda-test --use-cpu all
```

**Note**: Only Ollama supports Metal acceleration.

### CPU-Only

```bash
# .env configuration
OLLAMA_GPU_ENABLED=false
SD_IMAGE_TAG=cpu-v1.10.1
SD_COMMANDLINE_ARGS=--no-half --skip-torch-cuda-test --use-cpu all
```

## Ollama Usage

### Pull Models

```bash
# Pull Llama 3.2
docker exec ollama ollama pull llama3.2

# Pull Code Llama
docker exec ollama ollama pull codellama

# Pull Mistral
docker exec ollama ollama pull mistral
```

### API Usage

```bash
# Generate text
curl http://localhost:11434/api/generate -d '{
  "model": "llama3.2",
  "prompt": "Why is the sky blue?"
}'

# Chat completion
curl http://localhost:11434/api/chat -d '{
  "model": "llama3.2",
  "messages": [
    { "role": "user", "content": "Hello!" }
  ]
}'
```

## Open WebUI

### Features

- 💬 Chat interface with history
- 🎨 Markdown rendering
- 📁 Document upload and chat
- 🔄 Model switching
- 👥 Multi-user support
- 🔐 OIDC authentication (configured in SSO stack)

### OIDC Integration

Configured in SSO stack (`stacks/sso/`):

```yaml
# stacks/ai/docker-compose.yml
environment:
  - OAUTH_CLIENT_ID=${OPEN_WEBUI_OAUTH_CLIENT_ID}
  - OAUTH_CLIENT_SECRET=${OPEN_WEBUI_OAUTH_CLIENT_SECRET}
```

## Stable Diffusion

### Usage

1. Access Web UI: https://sd.${DOMAIN}
2. Choose model (Stable Diffusion v1.5, SDXL, etc.)
3. Enter prompt and generate images

### Model Management

Models are stored in Docker volume `sd-models`:

```bash
# Download model (example)
docker exec stable-diffusion wget -O /app/models/Stable-diffusion/model.safetensors \
  https://huggingface.co/.../model.safetensors
```

## Perplexica

### Features

- 🔍 AI-powered search
- 📚 Source citations
- 🤖 Multiple search modes
- 🔗 Integration with Ollama

### Configuration

```bash
# .env
PERPLEXICA_SECRET_KEY=<random-32-char-string>
OPENAI_API_KEY=<optional>  # Fallback to OpenAI
OLLAMA_API_URL=http://ollama:11434
```

### Usage

1. Access: https://search.${DOMAIN}
2. Choose search mode:
   - **Simple**: Quick answers
   - **Academic**: Scholarly sources
   - **Writing**: Content generation
   - **Coding**: Code-related queries

## Resource Requirements

### Minimum (CPU-only)

- **CPU**: 4+ cores
- **RAM**: 8 GB
- **Storage**: 20 GB

### Recommended (GPU)

- **GPU**: NVIDIA RTX 3060+ / AMD RX 6600+
- **VRAM**: 8+ GB
- **RAM**: 16+ GB
- **Storage**: 50+ GB

### Model Sizes

| Model | RAM/VRAM | Storage |
|-------|----------|---------|
| Llama 3.2 1B | 2 GB | 1.5 GB |
| Llama 3.2 3B | 4 GB | 3 GB |
| Code Llama 7B | 8 GB | 7 GB |
| Mistral 7B | 8 GB | 7 GB |
| Stable Diffusion v1.5 | 4 GB | 4 GB |
| SDXL | 8 GB | 6 GB |

## Troubleshooting

### Ollama Not Starting

```bash
# Check logs
docker logs ollama

# Test API
curl http://localhost:11434/api/tags

# GPU not detected (NVIDIA)
nvidia-smi  # Should show GPU info
```

### Stable Diffusion Out of Memory

```bash
# Reduce batch size
# .env
SD_COMMANDLINE_ARGS="--lowvram --xformers"

# Or use CPU
SD_IMAGE_TAG=cpu-v1.10.1
```

### Perplexica Connection Failed

```bash
# Check SearXNG
docker logs searxng

# Test SearXNG
curl http://localhost:8080/search?q=test
```

## Performance Tips

### GPU Optimization

1. **Use CUDA**: NVIDIA GPUs offer best performance
2. **Enable xFormers**: Reduces VRAM usage
3. **Batch Processing**: Generate multiple images at once

### CPU Optimization

1. **Quantization**: Use quantized models (4-bit, 8-bit)
2. **Thread Limiting**: Set OMP_NUM_THREADS
3. **Memory Management**: Close unused services

## Security

- 🔐 All services behind Traefik with HTTPS
- 🔑 OIDC authentication (optional)
- 🌐 No external API calls (fully local)
- 🛡️ Network isolation via Docker networks

## Backup

```bash
# Backup AI data
docker run --rm -v ollama-data:/data -v $(pwd):/backup \
  alpine tar czf /backup/ollama-backup.tar.gz /data

docker run --rm -v open-webui-data:/data -v $(pwd):/backup \
  alpine tar czf /backup/webui-backup.tar.gz /data
```

## Next Steps

- 📚 Pull AI models: `docker exec ollama ollama pull llama3.2`
- 🎨 Download Stable Diffusion models
- 🔍 Configure Perplexica search preferences
- 👥 Set up multi-user authentication via SSO
