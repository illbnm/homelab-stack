# AI Stack — Ollama + Open WebUI + Stable Diffusion

Local AI inference and image generation stack for the homelab.

## Prerequisites
- NVIDIA GPU with drivers and nvidia-container-toolkit installed.

## Deployment
1. Install NVIDIA container toolkit: `sudo apt install nvidia-container-toolkit`
2. Start the stack: `docker compose up -d`
3. Pull a model in Ollama: `docker exec -it ollama ollama pull llama3`
4. Access Open WebUI at `https://ai.yourdomain.com`
5. Access Stable Diffusion WebUI at `https://sd.yourdomain.com`

## Note
If no GPU is available, remove the `deploy` sections from the compose file to run on CPU.
