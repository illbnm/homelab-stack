# AI Stack - Ollama + Open WebUI + Stable Diffusion + Perplexica

完整的 AI 工具栈，提供 LLM 推理、聊天界面、图像生成和 AI 搜索功能。

## 📦 服务列表

| 服务 | 版本 | 用途 | 访问地址 |
|------|------|------|----------|
| **Ollama** | 0.3.14 | LLM 推理引擎 | https://ollama.yourdomain.com |
| **Open WebUI** | 0.3.35 | ChatGPT 风格界面 | https://ai.yourdomain.com |
| **Stable Diffusion** | 1.10.1 | 图像生成 | https://sd.yourdomain.com |
| **Perplexica** | latest | AI 搜索引擎 | https://search.yourdomain.com |
| **SearXNG** | latest | 搜索后端 | 内部服务 |

## 🚀 快速开始

### 1. GPU 配置（可选）

**NVIDIA GPU:**
```bash
# 安装 nvidia-container-toolkit
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
  sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
  sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
sudo apt update && sudo apt install -y nvidia-container-toolkit
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker
```

**AMD GPU:**
```bash
# 安装 ROCm（参考 AMD 官方文档）
# https://rocm.docs.amd.com/en/latest/deploy/linux/os-native/install.html
```

### 2. 配置环境变量

```bash
cd stacks/ai
cp .env.example .env
nano .env
```

**必需配置:**
- `WEBUI_SECRET_KEY` - Open WebUI 密钥
- `PERPLEXICA_SECRET_KEY` - Perplexica 密钥
- `SEARXNG_SECRET` - SearXNG 密钥

**生成密钥:**
```bash
openssl rand -hex 32
```

### 3. Authentik SSO 配置（可选但推荐）

1. 登录 Authentik 管理界面
2. 创建新应用 "Open WebUI"
3. 选择 OAuth2/OIDC 协议
4. 设置回调 URL: `https://ai.yourdomain.com/oauth/oidc/callback`
5. 复制 Client ID 和 Client Secret 到 `.env`

### 4. 启动服务

```bash
docker-compose up -d
docker-compose logs -f
```

### 5. 下载模型

```bash
# 使用模型管理脚本
cd ../../scripts
./ai-model-manager.sh install-llms

# 或手动下载
docker exec -it homelab-ollama ollama pull qwen2.5:14b
docker exec -it homelab-ollama ollama pull codellama:7b
```

## 🔧 GPU 自适应

本栈支持三种运行模式：

### NVIDIA GPU (CUDA)

**docker-compose.yml 配置:**
```yaml
services:
  ollama:
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: all
              capabilities: [gpu]
```

**.env 配置:**
```bash
NVIDIA_VISIBLE_DEVICES=all
SD_DEVICE=cuda
```

### AMD GPU (ROCm)

**docker-compose.yml 修改:**
```yaml
services:
  ollama:
    image: ollama/ollama:rocm
    devices:
      - /dev/kfd
      - /dev/dri
```

**.env 配置:**
```bash
SD_DEVICE=rocm
```

### CPU 模式（默认）

**.env 配置:**
```bash
NVIDIA_VISIBLE_DEVICES=none
SD_DEVICE=cpu
```

**性能对比:**
| 模式 | LLM 速度 | 图像生成速度 | 推荐场景 |
|------|---------|------------|----------|
| NVIDIA GPU | ⚡⚡⚡ | ⚡⚡⚡ | 生产环境、高频使用 |
| AMD GPU | ⚡⚡ | ⚡⚡ | 预算有限、有 AMD GPU |
| CPU | ⚡ | ⏳ | 测试、低频使用 |

## 🤖 推荐模型

### LLM（大语言模型）

| 模型 | 大小 | 用途 | 下载命令 |
|------|------|------|----------|
| **qwen2.5:14b** | 9GB | 通用对话、编程 | `ollama pull qwen2.5:14b` |
| **codellama:7b** | 4GB | 代码生成 | `ollama pull codellama:7b` |
| **llama3.2:3b** | 2GB | 轻量对话 | `ollama pull llama3.2:3b` |
| **nomic-embed-text** | 274MB | 文本嵌入（RAG） | `ollama pull nomic-embed-text` |

**安装推荐模型:**
```bash
./scripts/ai-model-manager.sh install-llms
```

### Vision（视觉-语言模型）

| 模型 | 大小 | 用途 |
|------|------|------|
| **llava:7b** | 4GB | 图像理解、OCR |
| **bakllava:latest** | 5GB | 高质量视觉模型 |

### Stable Diffusion

推荐从 Civitai 下载模型：
- **SDXL Base 1.0** - 高质量生成
- **DreamShaper** - 通用模型
- **Realistic Vision** - 写实风格

**下载示例:**
```bash
# 下载 SDXL 模型
wget https://civitai.com/api/download/models/128713 -O sd-models/sdxl-base.safetensors
```

## 🛠️ 模型管理

### 使用管理脚本

```bash
# 查看已安装模型
./scripts/ai-model-manager.sh list

# 下载模型
./scripts/ai-model-manager.sh pull qwen2.5:14b

# 删除模型
./scripts/ai-model-manager.sh delete old-model:latest

# 查看存储使用
./scripts/ai-model-manager.sh storage

# 检测 GPU
./scripts/ai-model-manager.sh detect-gpu
```

### 手动管理

```bash
# Ollama
docker exec -it homelab-ollama ollama list
docker exec -it homelab-ollama ollama pull <model>
docker exec -it homelab-ollama ollama rm <model>

# Stable Diffusion
# 模型文件位于: stacks/ai/sd-models/
# 直接复制 .safetensors 文件到此目录
```

## 💾 存储优化

### 自动清理

```bash
# 运行存储优化器
./scripts/ai-storage-optimizer.sh

# 设置定时任务（每周日凌晨 3:00）
echo "0 3 * * 0 /home/zhaog/.openclaw/workspace/homelab-stack/scripts/ai-storage-optimizer.sh" | crontab -
```

### 存储限制

默认限制 AI 栈最多使用 100GB 存储空间：

```bash
# .env 配置
MAX_STORAGE_GB=100
RETENTION_DAYS=7
```

### 手动清理

```bash
# 清理旧输出文件
find stacks/ai/sd-output -mtime +7 -delete

# 清理临时文件
find stacks/ai/sd-data -name "*.tmp" -delete
```

## 🔐 安全配置

### 网络隔离

- ✅ Ollama API 通过 Traefik 身份验证保护
- ✅ Open WebUI 支持 Authentik SSO
- ✅ SearXNG 仅内部访问（不对外暴露）

### 身份验证

**Ollama API（可选）:**
```bash
# 生成 htpasswd 哈希
htpasswd -nB admin | sed -e 's/\$/\$\$/g'

# .env 配置
OLLAMA_TRAEFIK_USER=admin
OLLAMA_TRAEFIK_HASH=$$2y$$05$$your_hash_here
```

**Open WebUI SSO:**
1. 在 Authentik 创建 OAuth2 应用
2. 配置 Client ID 和 Client Secret
3. 用户通过 Authentik 登录

### 数据保护

- ✅ 所有密钥使用环境变量存储
- ✅ 支持加密卷（需配置 Docker）
- ✅ 日志轮转（防止磁盘占满）

## 📊 性能调优

### Ollama

**GPU 加速:**
- 确保正确安装 nvidia-container-toolkit
- 设置 `NVIDIA_VISIBLE_DEVICES=all`
- 模型将自动使用 GPU

**CPU 优化:**
```bash
# 限制 CPU 核心数
docker-compose.yml:
  deploy:
    resources:
      limits:
        cpus: '4.0'
```

### Stable Diffusion

**NVIDIA GPU:**
```bash
# 使用 xformers 加速
COMMANDLINE_ARGS=--xformers --api --listen
```

**CPU 优化:**
```bash
# 默认配置已针对 CPU 优化
COMMANDLINE_ARGS=--no-half --skip-torch-cuda-test --use-cpu all --api --listen
```

### 内存管理

```bash
# 限制内存使用
docker-compose.yml:
  deploy:
    resources:
      limits:
        memory: 8G
```

## 🔍 故障排查

### Ollama 无法启动

```bash
# 检查 GPU 支持
docker exec -it homelab-ollama nvidia-smi

# 检查日志
docker-compose logs ollama

# 测试 API
curl http://localhost:11434/api/tags
```

### Open WebUI 无法连接 Ollama

```bash
# 检查 Ollama 健康状态
docker-compose ps

# 检查网络
docker network inspect ai

# 重启服务
docker-compose restart open-webui
```

### Stable Diffusion 启动缓慢

**正常现象** - CPU 模式下首次启动需要 2-5 分钟加载模型。

```bash
# 查看启动日志
docker-compose logs -f stable-diffusion

# 检查健康状态
docker inspect homelab-stable-diffusion | jq '.[0].State.Health'
```

### 存储空间不足

```bash
# 检查存储使用
./scripts/ai-model-manager.sh storage

# 运行优化器
./scripts/ai-storage-optimizer.sh

# 删除旧模型
docker exec -it homelab-ollama ollama rm old-model
```

## 📚 相关文档

- [Ollama 官方文档](https://github.com/ollama/ollama)
- [Open WebUI 文档](https://docs.openwebui.com/)
- [Stable Diffusion WebUI](https://github.com/AUTOMATIC1111/stable-diffusion-webui)
- [Perplexica 文档](https://github.com/ItzCrazyKns/Perplexica)
- [SearXNG 文档](https://docs.searxng.org/)

## 🆘 常见问题

**Q: CPU 模式下 Ollama 很慢？**
A: 正常现象。建议使用量化模型（如 qwen2.5:7b-q4）或升级到 GPU。

**Q: Stable Diffusion 生成图片很慢？**
A: CPU 模式下单张图需要 2-10 分钟。建议使用 GPU 或使用在线服务。

**Q: 如何添加新模型？**
A: 使用 `./scripts/ai-model-manager.sh pull <model>` 或直接复制到 `sd-models/` 目录。

**Q: 如何备份数据？**
A: 备份 `stacks/ai/` 目录下的所有卷数据。

---

_最后更新: 2026-04-08_
