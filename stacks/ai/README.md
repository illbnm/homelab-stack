# Local AI Stack (Ollama + Open WebUI + Stable Diffusion + Perplexica)

Self-hosted local LLM inference, RAG chat interface, AI image generation, and AI search engine.

## Pinned Services

| Service | Image | Default Mode |
|---------|-------|--------------|
| `ollama` | `ollama/ollama:0.3.14` | CPU default; GPU via `docker-compose.gpu.yml` |
| `open-webui` | `ghcr.io/open-webui/open-webui:v0.3.35` | Connected to Ollama + Authentik OIDC + SD API |
| `stable-diffusion` | `ghcr.io/abiosoft/sd-webui-docker:cpu-v1.10.1` | Profile `sd` / `full`; CUDA override in `docker-compose.gpu.yml` |
| `perplexica` | `itzcrazykns1337/perplexica:v1.8.0` | Profile `search` / `full`; local AI search engine |

## Hardware Sizing Guide

| Tier | Hardware | Recommended Models |
|------|----------|--------------------|
| CPU-only | 8 Cores / 16 GB RAM | `qwen2.5:3b`, `llama3.2:3b`, `nomic-embed-text` |
| Entry GPU (8 GB VRAM) | RTX 3060 / 4060 | `qwen2.5:7b`, `llama3.1:8b`, SD 1.5 |
| Pro GPU (16-24 GB VRAM) | RTX 3090 / 4090 | `qwen2.5:32b`, `deepseek-coder-v2:16b`, SDXL |

## Deployment

```bash
cp stacks/ai/.env.example stacks/ai/.env
bash scripts/setup-ai.sh --dry-run
bash scripts/setup-ai.sh
```
