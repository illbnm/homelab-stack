# AI Stack

本地 AI 推理栈，支持 Ollama (LLM)、Open WebUI (Chat)、Stable Diffusion (图像)、Perplexica (AI 搜索)。

## 服务

| 服务 | 镜像 | 端口 | 用途 |
|------|------|------|------|
| Ollama | `ollama/ollama:0.3.14` | 11434 | LLM 推理引擎 |
| Open WebUI | `ghcr.io/open-webui/open-webui:v0.5.20` | 8080 | ChatGPT 式 Web 界面 |
| Stable Diffusion | `ghcr.io/ai-dock/stable-diffusion-webui` | 7860 | 图像生成 (可选) |
| Perplexica | `itzcrazykns1337/perplexica:latest` | 3001 | AI 搜索引擎 (可选) |

## 快速开始

```bash
# 1. 检测 GPU 并生成配置
bash scripts/setup-ai-gpu.sh

# 2. 启动基础服务 (Ollama + Open WebUI)
docker compose up -d ollama open-webui

# 3. 拉取模型
docker exec ollama ollama pull qwen2.5:7b
docker exec ollama ollama pull nomic-embed-text

# 4. 访问 Open WebUI: https://ai.${DOMAIN}

# 5. (可选) 启动完整栈
docker compose --profile full up -d
```

## GPU 自适应

| GPU | 检测方式 | 性能 |
|-----|---------|------|
| NVIDIA (CUDA) | `nvidia-smi` | 最佳 |
| AMD (ROCm) | `rocminfo` | 良好 |
| CPU only | fallback | 可用但慢 |

自动检测脚本：`scripts/setup-ai-gpu.sh`

## 配置

| 环境变量 | 默认值 | 说明 |
|----------|--------|------|
| `WEBUI_SECRET_KEY` | changeme | Open WebUI 密钥 |
| `PERPLEXICA_MODEL` | qwen2.5:7b | Perplexica 使用的模型 |
| `SD_COMMANDLINE_ARGS` | CPU 模式 | SD 命令行参数 |

## 推荐模型

```bash
# 轻量对话
ollama pull qwen2.5:7b        # ~4.7GB, 中文优秀

# 代码生成
ollama pull deepseek-coder-v2 # ~9GB

# Embedding (RAG)
ollama pull nomic-embed-text  # ~274MB
```

## 访问地址

| 服务 | URL |
|------|-----|
| Open WebUI | `https://ai.${DOMAIN}` |
| Ollama API | `https://ollama.${DOMAIN}` |
| Stable Diffusion | `https://sd.${DOMAIN}` (full profile) |
| Perplexica | `https://search.${DOMAIN}` (full profile) |
