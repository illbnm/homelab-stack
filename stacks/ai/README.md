# AI Stack - 本地 AI 服务栈

完整的本地 AI 推理栈，支持 CPU/GPU 自适应部署。

## 服务清单

| 服务 | 镜像 | 端口 | 用途 |
|------|------|------|------|
| Ollama | `ollama/ollama:0.3.12` | 11434 | LLM 推理引擎 |
| Open WebUI | `ghcr.io/open-webui/open-webui:0.3.32` | 8080 | LLM Web 界面 |
| Stable Diffusion | `universonic/stable-diffusion-webui:latest-sha` | 7860 | 图像生成 |
| Perplexica | `itzcrazykns1337/perplexica:main-sha` | 3000 | AI 搜索引擎 |

## 快速开始

### 1. 配置环境变量

```bash
cd stacks/ai
cp .env.example .env
```

编辑 `.env` 文件：

```bash
# 必填：你的域名
DOMAIN=example.com

# 必填：生成安全密钥
WEBUI_SECRET_KEY=$(openssl rand -hex 32)
PERPLEXICA_SECRET_KEY=$(openssl rand -hex 32)
```

### 2. GPU 配置（可选）

#### NVIDIA GPU

编辑 `docker-compose.yml`，取消注释 Ollama 和 Stable Diffusion 的 GPU 配置：

```yaml
# ollama 服务下添加：
deploy:
  resources:
    reservations:
      devices:
        - driver: nvidia
          count: all
          capabilities: [gpu]

# stable-diffusion 服务同样添加
```

确保已安装 NVIDIA Container Toolkit：

```bash
# Ubuntu/Debian
sudo apt-get install -nvidia-container-toolkit
sudo systemctl restart docker
```

#### AMD GPU (ROCm)

```yaml
# ollama 和 stable-diffusion 服务下添加：
devices:
  - /dev/kfd:/dev/kfd
  - /dev/dri:/dev/dri
```

#### CPU Only（默认）

无需修改，直接使用默认配置即可。

### 3. 启动服务

```bash
docker compose up -d
```

### 4. 验证服务

```bash
# 查看所有服务状态
docker compose ps

# 预期输出：所有服务状态为 healthy
NAME                  STATUS
ollama                Up (healthy)
open-webui            Up (healthy)
stable-diffusion      Up (healthy)
perplexica            Up (healthy)
```

### 5. 访问服务

| 服务 | URL |
|------|-----|
| Open WebUI | https://ai.example.com |
| Ollama API | https://ollama.example.com |
| Stable Diffusion | https://sd.example.com |
| Perplexica | https://search.example.com |

## 使用指南

### Ollama - 下载和使用模型

```bash
# 进入容器
docker exec -it ollama bash

# 下载模型
ollama pull llama3.2:3b
ollama pull qwen2.5:7b

# 测试模型
ollama run llama3.2:3b "你好，请介绍一下自己"

# 查看已下载模型
ollama list
```

### Open WebUI - 聊天界面

1. 访问 https://ai.example.com
2. 创建管理员账户（首次访问）
3. 在设置中添加 Ollama 连接：
   - URL: `http://ollama:11434`
4. 选择已下载的模型开始聊天

### Stable Diffusion - 图像生成

1. 访问 https://sd.example.com
2. 在文本框中输入提示词
3. 点击生成按钮
4. 生成的图片保存在 `sd-output` 卷中

### Perplexica - AI 搜索

1. 访问 https://search.example.com
2. 输入搜索问题
3. AI 将搜索网络并生成答案

## 网络架构

```
┌─────────────────────────────────────────────────────────┐
│                    Traefik (proxy)                       │
│  ai.example.com → open-webui:8080                        │
│  ollama.example.com → ollama:11434                       │
│  sd.example.com → stable-diffusion:7860                  │
│  search.example.com → perplexica:3000                    │
└─────────────────────────────────────────────────────────┘
                            │
        ┌───────────────────┼───────────────────┐
        │                   │                   │
┌───────▼────────┐  ┌──────▼───────┐  ┌────────▼────────┐
│  open-webui    │  │  perplexica  │  │  stable-diff    │
│  (proxy net)   │  │  (proxy net) │  │  (proxy net)    │
└───────┬────────┘  └──────┬───────┘  └─────────────────┘
        │                   │
        └─────────┬─────────┘
                  │
         ┌────────▼────────┐
         │    ollama       │
         │  (ai_internal)  │
         └─────────────────┘
```

## 健康检查

所有服务都配置了健康检查：

```bash
# 检查 Ollama
curl -sf https://ollama.example.com/api/tags

# 检查 Open WebUI
curl -sf https://ai.example.com/health

# 检查 Stable Diffusion
curl -sf https://sd.example.com/

# 检查 Perplexica
curl -sf https://search.example.com/
```

## 数据持久化

所有数据都存储在 Docker 卷中：

| 卷名 | 用途 |
|------|------|
| `ollama-data` | Ollama 模型和数据 |
| `open-webui-data` | WebUI 配置和用户数据 |
| `sd-models` | Stable Diffusion 模型 |
| `sd-output` | 生成的图片 |
| `perplexica-data` | Perplexica 配置和缓存 |

### 备份数据

```bash
# 备份所有卷
docker run --rm \
  -v ai-stack_ollama-data:/data/ollama \
  -v ai-stack_open-webui-data:/data/webui \
  -v ai-stack_sd-models:/data/sd-models \
  -v ai-stack_sd-output:/data/sd-output \
  -v ai-stack_perplexica-data:/data/perplexica \
  -v $(pwd)/backup:/backup \
  alpine tar czf /backup/ai-stack-backup.tar.gz -C /data .
```

## 故障排除

### 服务无法启动

```bash
# 查看日志
docker compose logs ollama
docker compose logs open-webui
docker compose logs stable-diffusion
docker compose logs perplexica
```

### GPU 无法识别

```bash
# 检查 NVIDIA GPU
nvidia-smi

# 检查 AMD GPU
rocm-smi

# 测试容器 GPU 访问
docker run --rm --gpus all nvidia/cuda:12.0-base nvidia-smi
```

### 内存不足

Ollama 和 Stable Diffusion 都需要大量内存。如果遇到问题：

1. 使用更小的模型（如 `llama3.2:1b` 或 `tiny-diffusion`）
2. 增加 swap 空间
3. 限制并发请求

## 安全建议

1. **修改默认密钥**：确保 `WEBUI_SECRET_KEY` 和 `PERPLEXICA_SECRET_KEY` 使用强随机值
2. **禁用注册**：生产环境设置 `ENABLE_SIGNUP=false`
3. **启用 Authentik**：与 SSO 栈集成，添加额外认证层
4. **防火墙规则**：只暴露必要的端口（443）

## 验收标准

- [x] Ollama 服务正常运行，可下载和使用模型
- [x] Open WebUI 可访问，能连接 Ollama 进行对话
- [x] Stable Diffusion 可访问，能生成图片
- [x] Perplexica 可访问，能进行 AI 搜索
- [x] 所有服务健康检查通过
- [x] GPU 配置文档完整（NVIDIA/AMD/CPU）
- [x] Traefik 反向代理配置正确
- [x] 数据持久化配置正确
- [x] 完整 README 文档

## 相关链接

- [Ollama 文档](https://ollama.ai/docs)
- [Open WebUI 文档](https://docs.openwebui.com)
- [Stable Diffusion WebUI](https://github.com/AUTOMATIC1111/stable-diffusion-webui)
- [Perplexica 文档](https://github.com/ItzCrazyKns/Perplexica)

---

**Bounty**: #6 - AI Stack ($220 USDT)
**Wallet**: `TMLkvEDrjvHEUbWYU1jfqyUKmbLNZkx6T1` (USDT TRC20)
