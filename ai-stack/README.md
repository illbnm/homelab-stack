# AI Stack - 本地 AI 服务栈

[![Bounty](https://img.shields.io/badge/Bounty-%24220%20USDT-green)](https://github.com/illbnm/homelab-stack/issues/6)
[![Docker](https://img.shields.io/badge/Docker-Compose-blue)](https://docs.docker.com/compose/)
[![License](https://img.shields.io/badge/License-MIT-yellow)](LICENSE)

完整的本地 AI 推理栈，支持 CPU/GPU 自适应部署。包含 Ollama、Open WebUI、Stable Diffusion 和 Perplexica。

## 📋 服务清单

| 服务 | 镜像 | 端口 | 用途 |
|------|------|------|------|
| Ollama | `ollama/ollama:0.3.12` | 11434 | LLM 推理引擎 |
| Open WebUI | `ghcr.io/open-webui/open-webui:0.3.32` | 3000 | LLM Web 界面 |
| Stable Diffusion | `universonic/stable-diffusion-webui:latest-sha` | 7860 | 图像生成 |
| Perplexica | `itzcrazykns1337/perplexica:main-sha` | 3080 | AI 搜索引擎 |

## 🚀 快速开始

### 1. 克隆项目

```bash
git clone https://github.com/illbnm/homelab-stack.git
cd homelab-stack/ai-stack
```

### 2. 配置环境变量

```bash
cp .env.example .env
# 编辑 .env 文件，根据您的需求修改配置
```

### 3. 启动服务

```bash
# GPU 模式 (NVIDIA)
docker compose up -d

# CPU 模式
GPU_TYPE=cpu docker compose up -d
```

### 4. 访问服务

- **Open WebUI**: http://localhost:3000
- **Stable Diffusion**: http://localhost:7860
- **Perplexica**: http://localhost:3080
- **Ollama API**: http://localhost:11434

## 🔧 GPU 配置

### NVIDIA GPU (CUDA)

默认配置，无需额外修改。确保已安装 NVIDIA Docker Runtime：

```bash
# 验证 NVIDIA Docker
docker run --rm --gpus all nvidia/cuda:12.0-base nvidia-smi
```

### AMD GPU (ROCm)

1. 编辑 `docker-compose.yml`，取消注释 AMD ROCm 配置部分
2. 注释掉 NVIDIA GPU 配置部分
3. 确保已安装 ROCm 驱动

```bash
# AMD 模式启动
GPU_TYPE=amd docker compose up -d
```

### CPU 模式

无需 GPU 时使用 CPU fallback：

```bash
GPU_TYPE=cpu docker compose up -d
```

## 📦 数据持久化

所有数据存储在 Docker volumes 中：

| Volume | 用途 |
|--------|------|
| `ollama_data` | Ollama 模型数据 |
| `openwebui_data` | WebUI 用户数据和配置 |
| `sd_data` | Stable Diffusion 模型 |
| `sd_output` | 生成的图像 |
| `perplexica_data` | Perplexica 索引数据 |

### 备份数据

```bash
# 备份所有 volumes
docker compose run --rm -v $(pwd)/backup:/backup alpine \
  tar czf /backup/ai-stack-data.tar.gz \
  /var/lib/docker/volumes/ollama_data \
  /var/lib/docker/volumes/openwebui_data \
  /var/lib/docker/volumes/sd_data \
  /var/lib/docker/volumes/sd_output \
  /var/lib/docker/volumes/perplexica_data
```

## 🤖 使用 Ollama 模型

### 拉取模型

```bash
# 通过 Open WebUI 界面拉取，或使用命令行
docker exec ollama ollama pull llama3.2:3b
docker exec ollama ollama pull qwen2.5:7b
```

### 测试推理

```bash
docker exec ollama ollama run llama3.2:3b "Hello, how are you?"
```

## 🎨 使用 Stable Diffusion

访问 http://localhost:7860 使用 WebUI 生成图像。

### API 调用示例

```bash
curl -X POST http://localhost:7860/sdapi/v1/txt2img \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "a beautiful sunset over mountains",
    "steps": 20,
    "width": 512,
    "height": 512
  }'
```

## 🔍 使用 Perplexica

访问 http://localhost:3080 使用 AI 搜索引擎。

Perplexica 会自动使用 Ollama 作为后端 LLM，提供本地化的搜索体验。

## 🏥 健康检查

```bash
# 检查所有服务状态
docker compose ps

# 查看日志
docker compose logs -f

# 检查 Ollama 健康状态
curl http://localhost:11434/api/tags

# 检查 Open WebUI 健康状态
curl http://localhost:3000/health
```

## 🛠️ 故障排除

### Ollama 无法启动

```bash
# 检查 GPU 支持
docker exec ollama nvidia-smi

# 查看日志
docker compose logs ollama
```

### Stable Diffusion 启动缓慢

首次启动需要下载模型，可能需要 10-30 分钟。耐心等待。

### 内存不足

减少同时运行的服务或降低模型大小：

```bash
# 只启动 Ollama + WebUI
docker compose up -d ollama open-webui
```

## 📝 环境变量

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `GPU_TYPE` | `nvidia` | GPU 类型：nvidia/amd/cpu |
| `OLLAMA_PORT` | `11434` | Ollama 服务端口 |
| `WEBUI_PORT` | `3000` | Open WebUI 端口 |
| `SD_PORT` | `7860` | Stable Diffusion 端口 |
| `PERPLEXICA_PORT` | `3080` | Perplexica 端口 |
| `ENABLE_SIGNUP` | `false` | 是否允许用户注册 |

## 📄 许可证

MIT License

## 💰 赏金信息

- **Issue**: [#6](https://github.com/illbnm/homelab-stack/issues/6)
- **金额**: $220 USDT
- **收款地址**: `TMLkvEDrjvHEUbWYU1jfqyUKmbLNZkx6T1` (USDT TRC20)

## 📞 支持

如有问题，请提交 Issue 或联系开发者。
