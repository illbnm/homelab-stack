# 🤖 AI Stack - 本地 AI 服务栈

完整的本地 AI 推理栈，支持 CPU/GPU 自适应部署。

## 📦 服务清单

| 服务 | 镜像 | 端口 | 用途 |
|------|------|------|------|
| **Ollama** | `ollama/ollama:0.3.14` | 11434 | LLM 推理引擎 |
| **Open WebUI** | `ghcr.io/open-webui/open-webui:v0.3.35` | 8080 | LLM Web 界面 |
| **Stable Diffusion** | `ghcr.io/abiosoft/sd-webui-docker:cpu-v1.10.1` | 7860 | 图像生成 |
| **Perplexica** | `itzcrazykns1337/perplexica:main` | 3001 | AI 搜索引擎 |

## 🚀 快速部署

### CPU 版本（默认）

```bash
cd stacks/ai
docker compose up -d
```

### NVIDIA GPU 版本

```bash
cd stacks/ai
docker compose -f docker-compose.yml -f docker-compose.gpu.yml --profile nvidia up -d
```

### AMD GPU 版本

```bash
cd stacks/ai
docker compose -f docker-compose.yml -f docker-compose.gpu.yml --profile amd up -d
```

## 🌐 访问地址

部署完成后，通过以下地址访问：

- **Open WebUI**: https://ai.your-domain.com
- **Stable Diffusion**: https://sd.your-domain.com
- **Perplexica**: https://perplexica.your-domain.com
- **Ollama API**: https://ollama.your-domain.com

## ⚙️ 配置说明

### 环境变量

创建 `.env` 文件：

```bash
# 域名配置
DOMAIN=your-domain.com

# Open WebUI 密钥（必须是 32 字符以上）
WEBUI_SECRET_KEY=your-secret-key-here-32-chars-min

# Ollama 模型（可选，预拉取模型）
OLLAMA_MODELS=llama3.2:3b,qwen2.5:7b
```

### GPU 支持

#### NVIDIA GPU

需要安装 NVIDIA Container Toolkit：

```bash
# Ubuntu/Debian
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit.gpg
curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
sudo apt-get update
sudo apt-get install -y nvidia-container-toolkit
sudo systemctl restart docker
```

#### AMD GPU

需要安装 ROCm 驱动：

```bash
# Ubuntu/Debian
sudo apt install rocm-dkms rocm-opencl-runtime
```

## 📝 使用示例

### Ollama API

```bash
# 拉取模型
curl -X POST http://localhost:11434/api/pull -d '{"name": "llama3.2:3b"}'

# 生成文本
curl http://localhost:11434/api/generate -d '{
  "model": "llama3.2:3b",
  "prompt": "Hello, world!",
  "stream": false
}'

# 对话
curl http://localhost:11434/api/chat -d '{
  "model": "llama3.2:3b",
  "messages": [
    {"role": "user", "content": "你好！"}
  ],
  "stream": false
}'
```

### Open WebUI

1. 访问 https://ai.your-domain.com
2. 创建管理员账户
3. 在设置中添加 Ollama 连接：`http://ollama:11434`
4. 选择模型开始对话

### Stable Diffusion

1. 访问 https://sd.your-domain.com
2. 选择模型（Checkpoint）
3. 输入提示词生成图像

### Perplexica

1. 访问 https://perplexica.your-domain.com
2. 输入问题进行搜索
3. 查看 AI 生成的答案和引用来源

## 🔧 故障排查

### 查看日志

```bash
docker compose logs -f ollama
docker compose logs -f open-webui
docker compose logs -f stable-diffusion
```

### 检查健康状态

```bash
docker compose ps
```

### 重启服务

```bash
docker compose restart
```

### 清理数据

```bash
# 删除所有容器和数据
docker compose down -v

# 仅删除容器，保留数据
docker compose down
```

## 📊 资源需求

| 服务 | CPU | 内存 | 存储 |
|------|-----|------|------|
| Ollama (7B 模型) | 2 核 | 8GB | 10GB |
| Open WebUI | 1 核 | 2GB | 5GB |
| Stable Diffusion | 4 核 | 8GB | 20GB |
| Perplexica | 2 核 | 4GB | 5GB |
| **总计** | **9 核** | **22GB** | **40GB** |

### GPU 推荐

- **最低**: NVIDIA GTX 1060 6GB / AMD RX 580 8GB
- **推荐**: NVIDIA RTX 3060 12GB / AMD RX 6700 XT 12GB
- **理想**: NVIDIA RTX 4090 24GB / AMD RX 7900 XTX 24GB

## 📚 推荐模型

### Ollama 模型

```bash
# 轻量级（适合 CPU）
ollama pull llama3.2:1b
ollama pull llama3.2:3b
ollama pull qwen2.5:3b

# 中等（适合 GPU 8GB+）
ollama pull llama3.2:7b
ollama pull qwen2.5:7b
ollama pull mistral:7b

# 大型（适合 GPU 16GB+）
ollama pull llama3.1:70b
ollama pull mixtral:8x7b
```

### Stable Diffusion 模型

将模型文件放入 `sd-models` 卷：

```bash
# 下载模型
wget https://civitai.com/api/download/models/xxx -P /path/to/sd-models
```

## 🔒 安全建议

1. **修改默认密钥**: 设置强密码的 `WEBUI_SECRET_KEY`
2. **启用 HTTPS**: 确保 Traefik 配置了有效的 SSL 证书
3. **限制访问**: 使用 Authentik SSO 保护 AI 服务
4. **定期更新**: 使用 Watchtower 自动更新镜像

## 📄 License

本配置采用与主项目相同的许可证。

---

**Issue**: #6 - AI Stack ($220 USDT Bounty)  
**作者**: 牛马 - Development Agent  
**钱包**: TMLkvEDrjvHEUbWYU1jfqyUKmbLNZkx6T1
