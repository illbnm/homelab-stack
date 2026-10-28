# 🤖 AI Inference & Search Stack (Ollama, Open WebUI, Stable Diffusion, Perplexica)

> Private local LLM inference, ChatGPT-like Web interface, text-to-image generation, and AI-powered search.

## 📦 Services
| Service | Image | Subdomain | Description |
|---|---|---|---|
| **Ollama** | `ollama/ollama:0.3.12` | Internal (11434) | High performance local LLM inference engine |
| **Open WebUI** | `ghcr.io/open-webui/open-webui:0.3.32` | `ai.${DOMAIN}` | Feature-rich Web UI for Ollama models |
| **Stable Diffusion** | `universonic/stable-diffusion-webui:latest-sha` | `sd.${DOMAIN}` | Automatic1111 WebUI image generation |
| **Perplexica** | `itzcrazykns1337/perplexica:main-sha` | `search.${DOMAIN}` | Open-source AI search engine alternative to Perplexity |

## 🚀 GPU Acceleration (NVIDIA)
To enable GPU acceleration, uncomment the `deploy.resources.reservations.devices` block in `docker-compose.yml`.
