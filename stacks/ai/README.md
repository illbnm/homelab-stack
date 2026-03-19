# 🤖 AI Stack

> Local AI inference, web UI, and image generation — fully private.

**Services:** Ollama · Open WebUI · Stable Diffusion WebUI  
**Bounty:** $220 USDT ([#6](https://github.com/illbnm/homelab-stack/issues/6))

---

## 🏗️ Architecture

```
User (Browser)
    │
    ├──► https://ai.${DOMAIN}  →  Open WebUI  (chat interface)
    │                               │
    │                               └──► Ollama  (local LLM inference)
    │                                     e.g. llama3.2, qwen2.5, mistral
    │
    └──► https://ollama.${DOMAIN}  →  Ollama REST API

    └──► https://sd.${DOMAIN}     →  Stable Diffusion WebUI (image gen)
```

**Open WebUI** is the unified chat interface — connects to Ollama for text, and can be extended for image generation. Open WebUI supports **Authentik OIDC** (SSO) after running `scripts/setup-authentik.sh`.

---

## 🚀 Quick Start

### 1. Prerequisites

```bash
# Base infrastructure must be running first
docker network create proxy 2>/dev/null || true
```

### 2. Configure environment

```bash
cd stacks/ai
cp .env.example .env
nano .env
```

Required `.env` variables:

```env
DOMAIN=yourdomain.com
TZ=Asia/Shanghai
WEBUI_SECRET_KEY=your-random-32-char-secret
# OIDC — run scripts/setup-authentik.sh first to get these
OPENWEBUI_OIDC_CLIENT_ID=
OPENWEBUI_OIDC_CLIENT_SECRET=
AUTHENTIK_DOMAIN=auth.yourdomain.com
```

### 3. Pull models (first run)

```bash
# SSH into the Ollama container to pull models
docker exec -it ollama ollama pull llama3.2
docker exec -it ollama ollama pull qwen2.5:latest

# Check available models
docker exec -it ollama ollama list
```

### 4. Start services

```bash
docker compose up -d
```

### 5. Access services

| Service | URL | Notes |
|---------|-----|-------|
| Open WebUI (chat) | `https://ai.${DOMAIN}` | Recommended — use this |
| Ollama API | `https://ollama.${DOMAIN}` | For programmatic access |
| Stable Diffusion | `https://sd.${DOMAIN}` | CPU mode — slow, for testing |

---

## 🌐 Service URLs (after DNS + Traefik)

| Service | URL | Default Credentials |
|---------|-----|---------------------|
| Open WebUI | `https://ai.${DOMAIN}` | First user becomes admin |
| Ollama API | `https://ollama.${DOMAIN}` | No auth (internal only) |
| Stable Diffusion WebUI | `https://sd.${DOMAIN}` | No auth |

---

## 🔐 SSO / Authentik Integration

Open WebUI supports OIDC login via Authentik. Run the Authentik setup script first:

```bash
./scripts/setup-authentik.sh
```

This creates an OIDC application in Authentik and outputs the `OPENWEBUI_OIDC_CLIENT_ID` and `OPENWEBUI_OIDC_CLIENT_SECRET` values. Add these to your `.env` and restart.

After restart, the login page shows an **"Authentik"** button alongside the local admin account.

---

## 📁 File Structure

```
stacks/ai/
├── docker-compose.yml
└── .env               ← set WEBUI_SECRET_KEY, OIDC credentials

Docker volumes:
  ollama-data     → /root/.ollama (models stored here)
  open-webui-data → /app/backend/data
  sd-models       → /app/models
  sd-output       → /app/outputs
```

---

## 🖥️ GPU Acceleration (Optional)

The Stable Diffusion service runs in CPU mode by default (`--use-cpu all`). For GPU acceleration:

1. Install NVIDIA Docker runtime on the host
2. Update the `stable-diffusion` service:
   ```yaml
   environment:
     - COMMANDLINE_ARGS=--no-half --skip-torch-cuda-test
   deploy:
     resources:
       reservations:
         devices:
           - driver: nvidia
             count: 1
             capabilities: [gpu]
   ```

Ollama auto-detects NVIDIA GPUs. No compose changes needed — just install `nvidia-container-toolkit` on the host.

---

## 🔧 Common Tasks

### Pull a new model

```bash
docker exec -it ollama ollama pull <model-name>

# Examples:
docker exec -it ollama ollama pull mistral
docker exec -it ollama ollama pull deepseek-r1:7b
docker exec -it ollama ollama pull nomic-embed-text
```

### Check Ollama is running

```bash
curl http://localhost:11434/api/tags
```

### Use Open WebUI with a specific model

1. Open `https://ai.${DOMAIN}`
2. Settings → Models → Select model (e.g. `llama3.2`)
3. Start chatting

### Connect Open WebUI to Stable Diffusion

Open WebUI supports image generation via API integration. In Open WebUI:
1. Settings → Images
2. Set Stable Diffusion API URL: `http://stable-diffusion:7860`

### Change the default model

```bash
# Set default in Ollama
docker exec -it ollama ollama show llama3.2 --modelfile | ollama create my-default -f -
```

---

## 🐛 Troubleshooting

### Open WebUI shows "Ollama not connected"

1. Check Ollama is healthy: `curl http://localhost:11434/api/tags`
2. Check network: `docker exec -it open-webui curl http://ollama:11434/api/tags`
3. Verify `OLLAMA_BASE_URL=http://ollama:11434` is set in compose

### Models not loading

```bash
# Check available disk space (models are stored in ollama-data volume)
docker exec -it ollama df -h /root/.ollama

# Check which models are installed
docker exec -it ollama ollama list
```

### OIDC login not working

1. Verify `OPENWEBUI_OIDC_CLIENT_ID` and `OPENWEBUI_OIDC_CLIENT_SECRET` are set in `.env`
2. Check `AUTHENTIK_DOMAIN` is correct and Authentik is running
3. Check Authentik outpost is accessible: `https://${AUTHENTIK_DOMAIN}/outpost.goauthentik.io/auth/traefik`
4. Restart: `docker compose down && docker compose up -d`

### Stable Diffusion very slow on CPU

This is expected. CPU inference is 10-50x slower than GPU. For production image generation:
- Use a GPU (NVIDIA CUDA) — see GPU Acceleration section above
- Or use a cloud API instead

---

## 🔄 Update services

```bash
cd stacks/ai
docker compose pull
docker compose up -d
```

To update a specific service:
```bash
docker compose pull ollama && docker compose up -d ollama
```

---

## 🗑️ Tear down

```bash
cd stacks/ai
docker compose down        # keeps volumes
docker compose down -v    # removes volumes (deletes all downloaded models!)
```

---

## 📋 Acceptance Criteria

- [x] Ollama runs with health check and API accessible
- [x] Open WebUI connects to Ollama automatically
- [x] Open WebUI OIDC configured via Authentik (run setup-authentik.sh)
- [x] Stable Diffusion WebUI runs in CPU-safe mode
- [x] All services behind Traefik reverse proxy
- [x] Image tags are pinned versions
- [x] README documents setup and SSO integration
