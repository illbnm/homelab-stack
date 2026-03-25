# AI Stack

Local AI stack with LLM inference and image generation capabilities.

## Services

| Service | Image | Port | Purpose |
|---------|-------|------|---------|
| Ollama | `ollama/ollama:0.3.12` | 11434 | LLM inference |
| Open WebUI | `ghcr.io/open-webui/open-webui:0.3.32` | 8080 | Chat interface |
| Stable Diffusion | `universalis/local-server-ai:stable-diffusion-webui-1.10.2` | 7860 | Image generation |

## Quick Start

### Prerequisites

- **GPU recommended** (NVIDIA with CUDA support)
- Minimum 16GB RAM (32GB+ recommended)
- 50GB+ disk space for models

### 1. Configure Environment

```bash
cp .env.example .env
nano .env
```

### 2. Start Services

```bash
docker compose up -d
```

### 3. Pull LLM Models

```bash
# Pull a model (examples)
docker exec -it ollama ollama pull llama3.2
docker exec -it ollama ollama pull mistral
docker exec -it ollama ollama pull codellama

# List available models
docker exec -it ollama ollama list
```

### 4. Access Services

| Service | URL | Notes |
|---------|-----|-------|
| Open WebUI | https://chat.yourdomain.com | Chat interface |
| Ollama API | https://ollama.yourdomain.com | API endpoint |
| Stable Diffusion | https://sd.yourdomain.com | Image generation |

## GPU Configuration

### NVIDIA GPU Support

1. Install NVIDIA Container Toolkit:
```bash
# Ubuntu/Debian
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
  sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
  sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
sudo apt update
sudo apt install -y nvidia-container-toolkit
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker
```

2. Uncomment GPU section in `docker-compose.yml`:
```yaml
deploy:
  resources:
    reservations:
      devices:
        - driver: nvidia
          count: 1
          capabilities: [gpu]
```

### Verify GPU Access

```bash
docker exec -it ollama nvidia-smi
```

## Ollama Usage

### CLI

```bash
# Interactive chat
docker exec -it ollama ollama run llama3.2

# Generate text
docker exec -it ollama ollama run llama3.2 "Explain quantum computing"

# API call
curl http://localhost:11434/api/generate -d '{
  "model": "llama3.2",
  "prompt": "Why is the sky blue?"
}'
```

### API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/tags` | GET | List models |
| `/api/pull` | POST | Download model |
| `/api/generate` | POST | Generate text |
| `/api/chat` | POST | Chat completion |
| `/api/embeddings` | POST | Get embeddings |

## Open WebUI

### First Setup

1. Access https://chat.yourdomain.com
2. Create admin account
3. Select model from dropdown

### Features

- 💬 Multi-model chat
- 📁 RAG (document upload)
- 🎤 Voice input (with Whisper)
- 📝 Code highlighting
- 🔍 Web search integration
- 👥 Multi-user support

### Disable Signup

```bash
ENABLE_SIGNUP=false
```

Users must be created by admin.

## Stable Diffusion WebUI

### First Setup

1. Access https://sd.yourdomain.com
2. Download models (see below)
3. Select model in UI

### Download Models

Models are stored in `stable-diffusion-models` volume:

```bash
# Download Stable Diffusion XL
# Place .safetensors files in:
/var/lib/docker/volumes/ai_stable-diffusion-models/_data/Stable-diffusion/
```

Popular models:
- [SDXL Base](https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0)
- [DreamShaper](https://civitai.com/models/4384/dreamshaper)
- [Deliberate](https://civitai.com/models/4823/deliberate)

### API Usage

```bash
# Generate image
curl -X POST "http://localhost:7860/sdapi/v1/txt2img" \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "a beautiful sunset over mountains",
    "steps": 20,
    "width": 1024,
    "height": 1024
  }'
```

## Model Management

### Ollama Models

```bash
# List
docker exec ollama ollama list

# Pull
docker exec ollama ollama pull MODEL_NAME

# Delete
docker exec ollama ollama rm MODEL_NAME

# Show info
docker exec ollama ollama show MODEL_NAME
```

### Disk Usage

```bash
# Check Ollama models size
docker exec ollama du -sh /models

# Check Stable Diffusion models size
docker exec stable-diffusion du -sh /app/models
```

## Performance Tuning

### Ollama

```yaml
# In docker-compose.yml
environment:
  # Keep model in memory
  - OLLAMA_KEEP_ALIVE=24h
  
  # GPU layers (for Metal/CUDA)
  - OLLAMA_NUM_GPU=1
```

### Stable Diffusion

```yaml
# In docker-compose.yml
environment:
  # Performance optimizations
  - COMMANDLINE_ARGS=--api --listen --xformers --opt-sdp-attention
```

## Resource Requirements

| Service | CPU Only | GPU Recommended |
|---------|----------|-----------------|
| Ollama | 4GB RAM | 8GB VRAM |
| Open WebUI | 512MB | - |
| Stable Diffusion | 16GB RAM | 8GB VRAM |
| **Total** | **20GB+** | **16GB VRAM** |

### CPU-Only Mode

Works but significantly slower:
- Ollama: ~1-5 tokens/sec
- Stable Diffusion: ~2-5 min/image

### GPU Mode

- Ollama: ~30-100 tokens/sec
- Stable Diffusion: ~5-15 sec/image

## Troubleshooting

### Ollama Slow on CPU

```bash
# Use smaller models
docker exec ollama ollama pull llama3.2:1b  # 1B parameters
docker exec ollama ollama pull phi3:mini    # 3.8B parameters
```

### GPU Not Detected

```bash
# Check NVIDIA runtime
docker run --rm --gpus all nvidia/cuda:11.8.0-base-ubuntu22.04 nvidia-smi

# Check Docker config
cat /etc/docker/daemon.json
```

### Stable Diffusion Out of Memory

```bash
# Reduce image size
# Use --medvram or --lowvram
environment:
  - COMMANDLINE_ARGS=--api --listen --xformers --lowvram
```

### Open WebUI Can't Connect to Ollama

```bash
# Check Ollama health
docker logs ollama

# Test connection
docker exec open-webui curl http://ollama:11434/api/version
```

## Security Notes

1. **Disable public signup** (`ENABLE_SIGNUP=false`)
2. **Use HTTPS** (Traefik handles this)
3. **Monitor GPU usage** (LLM can use 100%)
4. **Limit model sizes** based on your hardware

## License

MIT
