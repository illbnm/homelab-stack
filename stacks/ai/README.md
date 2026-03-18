# AI Stack

Local AI services: LLM inference, chat UI, image generation, and AI search.

## Services

| Service | URL | Description |
|---------|-----|-------------|
| Ollama | `ollama.${DOMAIN}` | LLM inference engine (API) |
| Open WebUI | `ai.${DOMAIN}` | ChatGPT-like chat interface |
| Stable Diffusion | `sd.${DOMAIN}` | Image generation (A1111) |
| Perplexica | `search.${DOMAIN}` | AI-powered search engine |

## Quick Start (CPU)

```bash
cd stacks/ai
cp ../../.env .env   # or ensure .env exists at project root
docker compose up -d
```

## GPU Mode

### Prerequisites

- NVIDIA GPU with CUDA support
- [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html) installed on the host

### Enable GPU

1. Install NVIDIA Container Toolkit and restart Docker:

```bash
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
  sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
  sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
sudo apt update && sudo apt install -y nvidia-container-toolkit
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker
```

2. Set in your `.env`:

```env
OLLAMA_GPU_ENABLED=true
```

3. Edit `docker-compose.yml`:
   - Uncomment the `deploy.resources.reservations.devices` block under `ollama`
   - For Stable Diffusion: swap image tag to `gpu-*` and uncomment its deploy block

4. Restart:

```bash
docker compose up -d
```

## Pull Your First Model

```bash
# Into the running Ollama container:
docker exec -it ollama ollama pull llama3
docker exec -it ollama ollama pull llama3:8b-instruct-q4_K_M
```

## OIDC / SSO (Open WebUI)

Open WebUI supports OpenID Connect. When your IdP (Authentik, Keycloak, etc.) is ready:

1. Register a client with callback URL: `https://ai.${DOMAIN}/oauth/open-webui/callback`
2. Add to your `.env`:

```env
OPENID_CONNECT_URL=https://auth.yourdomain.com/application/o/oidc-openwebui/
OPENID_CONNECT_CLIENT_ID=your-client-id
OPENID_CONNECT_CLIENT_SECRET=your-client-secret
```

3. Uncomment the `OPENID_CONNECT_*` lines in docker-compose.yml
4. Restart: `docker compose up -d open-webui`

## Perplexica

Perplexica includes its own PostgreSQL (pgvector) instance and SearXNG for web search.

- **Config**: `config/ai/searxng/settings.yml` — customize search engines, rate limits
- **Default password**: set `PERPLEXICA_DB_PASSWORD` in `.env` (auto-generated if omitted)
- **Embedding model**: downloads automatically on first use (~2 GB)

## Resource Requirements

### CPU Mode (Minimum)

| Service | RAM | Disk |
|---------|-----|------|
| Ollama (7B model) | ~8 GB | ~5 GB/model |
| Open WebUI | ~1 GB | ~1 GB |
| Stable Diffusion | ~8 GB | ~10 GB (models) |
| Perplexica | ~2 GB | ~5 GB |
| **Total** | **~19 GB** | **~20+ GB** |

### GPU Mode (Recommended)

- GPU VRAM: ≥8 GB for 7B LLMs, ≥12 GB for image generation
- CPU RAM can be reduced when GPU handles inference

## Volumes

| Volume | Purpose |
|--------|---------|
| `ollama-data` | Downloaded models |
| `open-webui-data` | User data, settings |
| `sd-models` | Stable Diffusion checkpoints |
| `sd-output` | Generated images |
| `perplexica-data` | Embedding model cache |
| `perplexica-db-data` | Search index (pgvector) |

## Troubleshooting

**Ollama models are slow**: Enable GPU mode (see above). CPU inference for 7B+ models is usable but slow.

**Stable Diffusion OOM**: Use `--medvram` in `COMMANDLINE_ARGS`, or switch to a smaller model like SDXL-Turbo.

**Perplexica search fails**: Check SearXNG is healthy: `docker exec perplexica-searxng curl -s http://localhost:8080/search?q=test`

## License

Each service is governed by its own license. Refer to upstream repositories for details.
