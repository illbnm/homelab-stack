# 🤖 AI Stack — Ollama + Open WebUI + Stable Diffusion + Perplexica

> 本地 AI 推理栈：LLM 对话、图像生成、AI 搜索，支持 CPU/GPU 自适应部署。

## 服务清单

| 服务 | 镜像 | URL | 用途 |
|------|------|-----|------|
| **Ollama** | `ollama/ollama:0.3.12` | internal `:11434` | LLM 推理引擎 |
| **Open WebUI** | `open-webui:0.3.32` | `ai.${DOMAIN}` | LLM Web 界面 |
| **Stable Diffusion** | `universonic/stable-diffusion-webui` | `sd.${DOMAIN}` | 图像生成 |
| **Perplexica** | `itzcrazykns1337/perplexica` | `search.${DOMAIN}` | AI 搜索引擎 |

## GPU 自适应部署

### 检测 GPU

```bash
# NVIDIA
nvidia-smi

# AMD
rocm-smi

# 无 GPU → 使用 CPU 模式（默认）
```

### NVIDIA GPU (CUDA)

取消 docker-compose.yml 中 Ollama 和 Stable Diffusion 的 GPU 注释：

```yaml
deploy:
  resources:
    reservations:
      devices:
        - driver: nvidia
          count: all
          capabilities: [gpu]
```

前置要求：
```bash
# 安装 NVIDIA Container Toolkit
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
  sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
  sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
sudo apt-get update && sudo apt-get install -y nvidia-container-toolkit
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker
```

### AMD GPU (ROCm)

取消 Ollama 的 AMD GPU 注释：
```yaml
devices:
  - /dev/kfd
  - /dev/dri
```

### CPU 模式

默认配置即为 CPU 模式，无需额外配置。Ollama 会自动使用 CPU 推理。

## 快速启动

```bash
# 1. 配置 .env
WEBUI_SECRET_KEY=$(openssl rand -hex 32)

# 2. 启动
docker compose -f stacks/ai/docker-compose.yml up -d

# 3. 下载模型
docker exec ollama ollama pull llama3.1:8b
docker exec ollama ollama pull codellama:7b

# 4. 访问
# Open WebUI: https://ai.${DOMAIN}
# Stable Diffusion: https://sd.${DOMAIN}
# Perplexica: https://search.${DOMAIN}
```

## Ollama

### 常用模型

| 模型 | 大小 | 用途 | 命令 |
|------|------|------|------|
| llama3.1:8b | 4.7GB | 通用对话 | `ollama pull llama3.1:8b` |
| codellama:7b | 3.8GB | 代码生成 | `ollama pull codellama:7b` |
| mistral:7b | 4.1GB | 通用 | `ollama pull mistral:7b` |
| phi3:mini | 2.3GB | 轻量 | `ollama pull phi3:mini` |
| llava:7b | 4.5GB | 多模态 | `ollama pull llava:7b` |

### API 使用

```bash
# 列出模型
curl http://localhost:11434/api/tags

# 对话
curl http://localhost:11434/api/chat -d '{
  "model": "llama3.1:8b",
  "messages": [{"role": "user", "content": "Hello!"}]
}'
```

## Open WebUI

首次访问创建管理员账号。支持：
- 多模型切换
- 对话历史
- RAG (文档问答)
- 模型管理
- 用户管理

## Stable Diffusion

### 推荐模型
下载到 `sd-models` volume:
- Stable Diffusion XL
- DreamShaper
- Realistic Vision

### API
```bash
curl -X POST https://sd.${DOMAIN}/sdapi/v1/txt2img \
  -H "Content-Type: application/json" \
  -d '{"prompt": "a cat", "steps": 20}'
```

## 资源需求

| 配置 | CPU 模式 | GPU 模式 |
|------|---------|---------|
| RAM | 16GB+ | 8GB+ |
| VRAM | — | 8GB+ (推荐 12GB+) |
| 存储 | 50GB+ (模型) | 50GB+ |
| 推理速度 | 慢 (1-5 tok/s) | 快 (30-100 tok/s) |
