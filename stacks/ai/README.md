# AI Stack — 本地 AI 服务

完整的本地 AI 推理栈，支持 CPU/GPU 自适应部署。

## 服务清单

| 服务 | 镜像 | 端口 | 用途 |
|------|------|------|------|
| Ollama | ollama/ollama:0.3.14 | 11434 | LLM 推理引擎 |
| Open WebUI | ghcr.io/open-webui/open-webui:v0.3.35 | 8080 | LLM Web 界面 |
| Stable Diffusion | ghcr.io/abiosoft/sd-webui-docker:cpu-v1.10.1 | 7860 | 图像生成 |
| Perplexica | itzcrazykns1337/perplexica:main | 3000 | AI 搜索引擎 |

## 快速开始

### 1. 自动配置

```bash
# 运行自动配置脚本（检测 GPU 并生成配置）
./scripts/setup-ai.sh
```

### 2. 启动服务

```bash
# CPU 模式
cd stacks/ai
docker compose -f docker-compose.yml -f docker-compose.local.yml up -d

# NVIDIA GPU 模式
export GPU_TYPE=nvidia
cd stacks/ai
docker compose -f docker-compose.yml -f docker-compose.local.yml up -d

# AMD GPU 模式
export GPU_TYPE=amd
cd stacks/ai
docker compose -f docker-compose.yml -f docker-compose.local.yml up -d
```

### 3. 访问服务

- **Open WebUI**: https://ai.your-domain.com
- **Ollama API**: https://ollama.your-domain.com
- **Stable Diffusion**: https://sd.your-domain.com
- **Perplexica**: https://perplexica.your-domain.com

## GPU 支持

### NVIDIA GPU

确保已安装 NVIDIA Docker Runtime:

```bash
# 安装 NVIDIA Container Toolkit
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit.gpg
curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
  sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit.gpg] https://#g' | \
  sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
sudo apt-get update
sudo apt-get install -y nvidia-container-toolkit
sudo systemctl restart docker
```

### AMD GPU

确保已安装 ROCm:

```bash
# Ubuntu/Debian
sudo usermod -aG render,video $LOGNAME
```

### CPU Only

无需特殊配置，默认使用 CPU 模式。

## 模型管理

### 拉取模型

```bash
# Llama 3.2 (3B, 轻量级)
docker exec -it ollama ollama pull llama3.2

# Qwen 2.5 (7B, 中文优化)
docker exec -it ollama ollama pull qwen2.5:7b

# Mistral (7B, 英文)
docker exec -it ollama ollama pull mistral

# 嵌入模型
docker exec -it ollama ollama pull nomic-embed-text
```

### 查看已安装模型

```bash
docker exec -it ollama ollama list
```

### 删除模型

```bash
docker exec -it ollama ollama rm <model-name>
```

## 环境变量

| 变量 | 说明 | 默认值 |
|------|------|--------|
| `GPU_TYPE` | GPU 类型 | `cpu` |
| `GPU_COUNT` | GPU 数量 | `1` |
| `WEBUI_SECRET_KEY` | Open WebUI 密钥 | 自动生成 |
| `PERPLEXICA_SECRET_KEY` | Perplexica 密钥 | 自动生成 |
| `SD_USERNAME` | Stable Diffusion 用户名 | `admin` |
| `SD_PASSWORD` | Stable Diffusion 密码 | 自动生成 |
| `DOMAIN` | 域名 | `example.com` |

## 数据持久化

| 卷 | 用途 |
|---|---|
| `ollama-data` | Ollama 模型数据 |
| `open-webui-data` | Open WebUI 用户数据 |
| `sd-models` | Stable Diffusion 模型 |
| `sd-output` | Stable Diffusion 输出 |
| `perplexica-config` | Perplexica 配置 |

## 故障排查

### 检查服务状态

```bash
docker compose -f docker-compose.yml -f docker-compose.local.yml ps
```

### 查看日志

```bash
# 所有服务
docker compose -f docker-compose.yml -f docker-compose.local.yml logs -f

# 单个服务
docker compose -f docker-compose.yml -f docker-compose.local.yml logs -f ollama
```

### GPU 检测

```bash
# NVIDIA
nvidia-smi

# AMD
rocm-smi

# Docker GPU 测试
docker run --rm --gpus all nvidia/cuda:11.0-base nvidia-smi
```

## 性能优化

### Ollama 优化

```bash
# 设置上下文长度
docker exec -it ollama ollama run llama3.2 --num_ctx 4096

# 设置 GPU 层数 (NVIDIA)
OLLAMA_NUM_GPU=50 docker compose up -d
```

### Stable Diffusion 优化

```yaml
# 启用 GPU 加速 (取消注释 docker-compose.local.yml 中的配置)
deploy:
  resources:
    reservations:
      devices:
        - driver: nvidia
          count: 1
          capabilities: [gpu]
```

## 安全建议

1. **修改默认密码**: 编辑 `.env` 文件设置强密码
2. **启用 HTTPS**: 通过 Traefik 自动获取 SSL 证书
3. **限制访问**: 使用 Authentik SSO 保护服务
4. **定期备份**: 备份 `volumes` 中的数据

## 参考链接

- [Ollama 文档](https://ollama.ai/docs)
- [Open WebUI 文档](https://docs.openwebui.com)
- [Stable Diffusion WebUI](https://github.com/AUTOMATIC1111/stable-diffusion-webui)
- [Perplexica 文档](https://github.com/ItzCrazyKns/Perplexica)
