# AI Stack - Ollama + Open WebUI + Stable Diffusion

> **Bounty:** illbnm/homelab-stack#6 - $220 USD

## Setup
```bash
cp .env.example .env
docker compose up -d
# Pull first model:
docker exec ollama ollama pull llama3.2
```

## Access
- Open WebUI: http://localhost:8080
- Ollama API: http://localhost:11434
- InvokeAI: http://localhost:9090
