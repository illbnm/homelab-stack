# AI Stack

本地 AI 推理服务栈，支持 LLM、图像生成和 AI 搜索。

## 服务架构

```
┌─────────────────────────────────────────────────────────┐
│                      AI Stack                                │
├─────────────────────────────────────────────────────────┤
│                                                          │
│   Ollama                                                 │
│   ├── LLM 推理引擎                                      │
│   ├── 本地模型运行                                      │
│   └── CPU/GPU 自适应                                    │
│                                                          │
│   Open WebUI                                            │
│   ├── LLM Web 界面                                      │
│   ├── OIDC 认证支持                                     │
│   └── ChatGPT 风格界面                                  │
│                                                          │
│   Stable Diffusion                                       │
│   ├── 图像生成                                          │
│   ├── Text-to-Image                                     │
│   └── CPU/GPU 自适应                                    │
│                                                          │
│   Perplexica                                             │
│   ├── AI 搜索引擎                                        │
│   └── 本地搜索 + LLM 增强                              │
│                                                          │
│   LocalAI (Optional)                                    │
│   ├── 备用 LLM 后端                                     │
│   └── OpenAI API 兼容                                   │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

## 服务列表

| 服务 | 地址 | 说明 |
|------|------|------|
| Ollama | http://ollama:11434 | LLM 推理 API |
| Open WebUI | https://ai.${DOMAIN} | LLM Web 界面 |
| Stable Diffusion | https://sd.${DOMAIN} | 图像生成 |
| Perplexica | https://search.${DOMAIN} | AI 搜索引擎 |
| LocalAI | https://localai.${DOMAIN} | 备用 LLM |

## 快速开始

### 1. GPU 配置

#### NVIDIA GPU

确保安装了 NVIDIA Container Toolkit：

```bash
# 检查 GPU
nvidia-smi

# 确认 Docker 支持 NVIDIA
docker run --rm --gpus all nvidia/cuda:11.8.0-base-ubuntu22.04 nvidia-smi
```

#### AMD GPU (ROCm)

使用 ROCm 镜像：

```yaml
image: ollama/ollama:rocm
```

#### CPU Only

如果没有 GPU，服务会自动使用 CPU 运行（速度较慢）。

### 2. 启动服务

```bash
docker compose -f stacks/ai/docker-compose.yml up -d
```

### 3. 访问服务

| 服务 | 地址 | 凭据 |
|------|------|------|
| Open WebUI | https://ai.${DOMAIN} | 首次注册 |
| Stable Diffusion | https://sd.${DOMAIN} | 无需认证 |
| Perplexica | https://search.${DOMAIN} | 无需认证 |

## Ollama

### 功能

- 本地 LLM 推理
- 无需 GPU 也能运行
- 支持多种模型

### 安装模型

```bash
# 进入 Ollama 容器
docker exec -it ollama bash

# 安装模型
ollama pull llama2
ollama pull mistral
ollama pull codellama

# 查看已安装模型
ollama list
```

### API 使用

```bash
# Chat API
curl http://localhost:11434/api/chat -d '{
  "model": "llama2",
  "messages": [{"role": "user", "content": "Hello!"}]
}'

# Generate API
curl http://localhost:11434/api/generate -d '{
  "model": "llama2",
  "prompt": "Why is the sky blue?"
}'
```

### 推荐模型

| 模型 | 内存需求 | 用途 |
|------|---------|------|
| llama2 | 4GB+ | 通用对话 |
| mistral | 4GB+ | 通用对话 |
| codellama | 6GB+ | 代码生成 |
| llama2-uncensored | 4GB+ | 无审查版本 |

## Open WebUI

### 功能

- ChatGPT 风格界面
- 本地 LLM 连接
- 会话历史
- 模型切换

### OIDC 认证

配置 Authentik OIDC：

1. 在 Authentik 创建 Open WebUI 应用
2. 设置环境变量：
   ```env
   OIDC_AUTH_URL=https://auth.yourdomain.com/application/o/authorize/
   OPENWEBUI_OIDC_CLIENT_ID=your_client_id
   OPENWEBUI_OIDC_CLIENT_SECRET=your_client_secret
   ```

### 使用

1. 访问 https://ai.${DOMAIN}
2. 首次使用需要注册账户
3. 选择模型开始对话

## Stable Diffusion

### 功能

- Text-to-Image（文生图）
- Image-to-Image（图生图）
- ControlNet 支持
- 高分辨率生成

### 使用

1. 访问 https://sd.${DOMAIN}
2. 输入提示词
3. 调整参数（Steps, CFG Scale, etc）
4. 生成图像

### CPU 模式

如果没有 GPU，会自动使用 CPU 运行，速度较慢。

## Perplexica

### 功能

- AI 增强搜索
- Web 搜索
- 本地索引
- LLM 摘要

### 配置

Perplexica 需要配置 LLM 后端：

1. 访问设置页面
2. 选择 Ollama 作为 LLM
3. 选择搜索 API

## LocalAI

### 功能

- OpenAI API 兼容
- 备用 LLM 后端
- TTS/Whisper 支持

### API 兼容

```bash
# 使用 OpenAI 兼容 API
curl http://localhost:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "llama2",
    "messages": [{"role": "user", "content": "Hello!"}]
  }'
```

## 故障排除

### Ollama 模型下载慢

```bash
# 使用代理
export HTTP_PROXY=http://your-proxy:port
export HTTPS_PROXY=http://your-proxy:port
```

### Stable Diffusion 内存不足

```yaml
# 使用 CPU 模式
environment:
  - COMMANDLINE_ARGS=--no-half --skip-torch-cuda-test --use-cpu all
```

### GPU 检测失败

```bash
# 检查 NVIDIA Docker 支持
docker info | grep nvidia

# 如果没有，重启 Docker
sudo systemctl restart docker
```

## 相关文档

- [Ollama 文档](https://github.com/ollama/ollama)
- [Open WebUI 文档](https://docs.openwebui.com/)
- [Stable Diffusion WebUI](https://github.com/AUTOMATIC1111/stable-diffusion-webui)
- [Perplexica](https://github.com/itzcrazykns1337/perplexica)
- [LocalAI](https://localai.io/)
