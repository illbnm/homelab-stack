# AI Stack

Local AI inference: Ollama + Open WebUI + Stable Diffusion.

## Services

| Service | Version | URL | Purpose |
|---------|---------|-----|---------|
| Ollama | 0.3.14 | `ollama.${DOMAIN}` | LLM inference |
| Open WebUI | 0.3.32 | `ai.${DOMAIN}` | LLM chat UI |
| Stable Diffusion | latest | `sd.${DOMAIN}` | Image generation |

## Quick Start

```bash
docker compose -f stacks/ai/docker-compose.yml up -d
# Pull a model
docker exec ollama ollama pull llama3.2
```
