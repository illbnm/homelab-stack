# AI Stack

A Docker-based AI development stack running on a single host, consisting of **Ollama**, **Open WebUI**, **Stable Diffusion WebUI**, and **Perplexica**.

## Components

| Service              | Description                                            | Port  |
| -------------------- | ------------------------------------------------------ | ----- |
| Ollama               | Local LLM inference engine                             | 11434 |
| Open WebUI           | Web-based chat interface for Ollama models             | 3000  |
| Stable Diffusion     | Image generation with the Stable Diffusion WebUI       | 7860  |
| Perplexica           | AI-powered search assistant                            | 3001  |

## Hardware Requirements

### Minimum (CPU-only)
- **CPU**: 4+ cores
- **RAM**: 16 GB
- **Storage**: 50 GB free

### Recommended (GPU-accelerated)
- **NVIDIA GPU**: GTX 1060 6GB or better (CUDA 11+)
- **AMD GPU**: RX 580 or better (ROCm 5+)
- **RAM**: 32 GB
- **Storage**: 100 GB SSD

> **Note**: GPU support is optional but highly recommended. Without a GPU, inference will run on CPU and be significantly slower, especially for image generation.

## Usage

### 1. Initialize GPU detection

```bash
chmod +x init.sh
source ./init.sh
```

The `init.sh` script checks for `nvidia-smi` (NVIDIA) or `rocm-smi` (AMD) and sets the following environment variables:

- `GPU_SUPPORTED` — `true` if a GPU is detected, `false` otherwise
- `DOCKER_RUNTIME` — `nvidia` for NVIDIA GPUs, `rocm` for AMD GPUs

### 2. Start the stack

```bash
docker-compose up -d
```

### 3. Access the services

- Open WebUI: http://localhost:3000
- Stable Diffusion WebUI: http://localhost:7860
- Perplexica: http://localhost:3001
- Ollama API: http://localhost:11434

## Pulling Models

After Ollama starts, pull a model via the API or Open WebUI:

```bash
curl http://localhost:11434/api/pull -d '{"name": "llama3"}'
```

## Stopping the Stack

```bash
docker-compose down
```

## GPU Notes

- Ensure the **NVIDIA Container Toolkit** (or AMD ROCm equivalent) is installed on the host.
- The `init.sh` script will auto-detect the GPU vendor. Run it with `source` so the environment variables persist in the current shell before launching `docker-compose`.
