# AI Stack — Local AI Services

Local AI inference with GPU auto-adaptation.

## Services

| Service | URL | Purpose |
|---------|-----|---------|
| Ollama | `https://ollama.${DOMAIN}` | LLM inference engine |
| Open WebUI | `https://ai.${DOMAIN}` | ChatGPT-like web UI |
| Stable Diffusion | `https://sd.${DOMAIN}` | Image generation |
| Perplexica | `https://search.${DOMAIN}` | AI-powered search |

## Quick Start

```bash
cd stacks/ai
docker compose up -d

# Pull a model
docker exec ollama ollama pull llama3.1:8b
```

## GPU Configuration

### NVIDIA GPU (CUDA)

Uncomment in docker-compose.yml:
```yaml
deploy:
  resources:
    reservations:
      devices:
        - driver: nvidia
          count: all
          capabilities: [gpu]
```

Requires: `nvidia-container-toolkit` installed.

### AMD GPU (ROCm)

Uncomment in docker-compose.yml:
```yaml
devices:
  - /dev/kfd:/dev/kfd
  - /dev/dri:/dev/dri
```

Use ROCm image: `ollama/ollama:0.3.12-rocm`

### CPU Only (Default)

No changes needed. Works out of the box but slower inference.

## Models

```bash
# Pull models
docker exec ollama ollama pull llama3.1:8b      # 4.7GB
docker exec ollama ollama pull mistral:7b        # 4.1GB
docker exec ollama ollama pull codellama:13b     # 7.4GB

# List models
docker exec ollama ollama list
```

## Open WebUI

Access at `https://ai.${DOMAIN}`. First user to register becomes admin.
Connects to Ollama automatically via internal network.
