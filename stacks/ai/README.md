# AI Stack

Local AI inference services with GPU-adaptive deployment.

## Services

| Service | URL | Description |
|---------|-----|-------------|
| Ollama | `https://ollama.${DOMAIN}` | LLM inference engine |
| Open WebUI | `https://ai.${DOMAIN}` | Chat interface for LLMs |
| Stable Diffusion | `https://sd.${DOMAIN}` | Image generation |
| Perplexica | `https://search.${DOMAIN}` | AI-powered search |

## Deployment Options

The stack supports three deployment profiles based on your hardware:

### CPU Only (Default)

```bash
docker compose --profile cpu up -d
```

### NVIDIA GPU (CUDA)

Requirements:
- NVIDIA GPU with CUDA support
- [nvidia-container-toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html) installed

```bash
docker compose --profile nvidia up -d
```

### AMD GPU (ROCm)

Requirements:
- AMD GPU with ROCm support (RX 5000/6000/7000 series)
- ROCm drivers installed
- Docker configured for ROCm

```bash
# For newer AMD GPUs, you may need to set the GFX version
export HSA_OVERRIDE_GFX_VERSION=10.3.0  # RX 6000 series example

docker compose --profile amd up -d
```

## First-Time Setup

1. Copy environment file:
   ```bash
   cp .env.example .env
   ```

2. Generate secrets:
   ```bash
   echo "WEBUI_SECRET_KEY=$(openssl rand -hex 32)" >> .env
   ```

3. Start the stack with your preferred profile:
   ```bash
   docker compose --profile cpu up -d
   ```

4. Pull a model in Ollama:
   ```bash
   docker exec -it ollama ollama pull llama3.2
   ```

5. Access Open WebUI at `https://ai.${DOMAIN}` and create your admin account.

## Model Management

Pull models via CLI:
```bash
docker exec -it ollama ollama pull llama3.2
docker exec -it ollama ollama pull mistral
docker exec -it ollama ollama pull codellama
```

Or use the Open WebUI interface to download models directly.

## Performance Tips

- **CPU mode**: Expect slower inference. Recommended: 16GB+ RAM
- **NVIDIA**: For best performance, use GPUs with 8GB+ VRAM
- **AMD**: ROCm support varies by GPU generation. Check compatibility first.

For Stable Diffusion, initial startup takes 2-3 minutes while loading models.

## Troubleshooting

### Ollama not responding

Check if the service is healthy:
```bash
docker logs ollama
curl http://localhost:11434/api/tags
```

### GPU not detected (NVIDIA)

Verify nvidia-container-toolkit:
```bash
docker run --rm --gpus all nvidia/cuda:12.0-base nvidia-smi
```

### GPU not detected (AMD)

Verify ROCm devices:
```bash
ls /dev/kfd /dev/dri
docker run --rm --device=/dev/kfd --device=/dev/dri rocm/pytorch rocm-smi
```

## Resource Requirements

| Profile | Min RAM | Min VRAM | Storage |
|---------|---------|----------|---------|
| CPU | 16 GB | - | 50 GB |
| NVIDIA | 8 GB | 6 GB | 50 GB |
| AMD | 8 GB | 6 GB | 50 GB |

Storage requirements vary based on models downloaded.
