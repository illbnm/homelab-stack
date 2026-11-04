# AI Stack

Self-hosted local artificial intelligence powerhouse integrating Ollama LLM execution, Open WebUI chat interface, Stable Diffusion image synthesis, and Perplexica deep research search.

## Services Included

| Service | Version | Web URL / Domain | Description |
|---|---|---|---|
| **Ollama** | `0.3.12` | `https://ollama.${DOMAIN}` | High performance local LLM runner (Llama 3, Mistral, Qwen) |
| **Open WebUI** | `0.3.32` | `https://ai.${DOMAIN}` | Feature-rich ChatGPT-like UI with RAG & multi-user support |
| **Stable Diffusion** | `latest` | `https://sd.${DOMAIN}` | WebUI & REST API for text-to-image and inpainting |
| **Perplexica** | `latest` | `https://search.${DOMAIN}` | Open-source Perplexity AI alternative with local LLM routing |

## Hardware Acceleration (CPU vs GPU)

By default, the stack runs in universal CPU mode. To enable hardware GPU acceleration:

### NVIDIA CUDA
Uncomment the `deploy.resources.reservations.devices` block under `ollama` in `docker-compose.yml`:
```yaml
deploy:
  resources:
    reservations:
      devices:
        - driver: nvidia
          count: all
          capabilities: [gpu]
```
Ensure `nvidia-container-toolkit` is installed on your host.

## Quick Start

```bash
cp stacks/ai/.env.example stacks/ai/.env
docker compose -f stacks/ai/docker-compose.yml up -d
```
