# AI Stack 部署指南

## 📋 部署前检查

### 系统要求

- Docker 20.10+
- Docker Compose v2.0+
- CPU: 4 核以上（推荐 8 核）
- 内存：16GB 以上（推荐 32GB）
- 存储：50GB 可用空间
- GPU（可选）: NVIDIA 6GB+ / AMD 8GB+

### 检查 GPU 支持

```bash
# NVIDIA
nvidia-smi

# AMD
rocm-smi
```

## 🚀 部署步骤

### Step 1: 准备环境

```bash
cd stacks/ai

# 复制环境变量文件
cp .env.example .env

# 编辑 .env 文件
nano .env
```

### Step 2: 生成密钥

```bash
# 生成随机密钥
openssl rand -hex 32
```

将生成的密钥填入 `.env` 文件的 `WEBUI_SECRET_KEY`。

### Step 3: 启动服务

#### CPU 模式

```bash
docker compose up -d
```

#### NVIDIA GPU 模式

```bash
docker compose -f docker-compose.yml -f docker-compose.gpu.yml --profile nvidia up -d
```

#### AMD GPU 模式

```bash
docker compose -f docker-compose.yml -f docker-compose.gpu.yml --profile amd up -d
```

### Step 4: 验证部署

```bash
# 检查容器状态
docker compose ps

# 查看日志
docker compose logs -f

# 测试 Ollama API
curl http://localhost:11434/api/version

# 测试 Open WebUI
curl http://localhost:8080/health

# 测试 Stable Diffusion
curl http://localhost:7860

# 测试 Perplexica
curl http://localhost:3001
```

### Step 5: 拉取模型

```bash
# 拉取推荐模型
docker exec ollama ollama pull llama3.2:3b
docker exec ollama ollama pull qwen2.5:7b

# 或者通过 API
curl -X POST http://localhost:11434/api/pull -d '{"name": "llama3.2:3b"}'
```

## 🔧 配置优化

### Ollama 并发配置

编辑 `docker-compose.yml`：

```yaml
environment:
  - OLLAMA_MAX_QUEUE=512
  - OLLAMA_NUM_PARALLEL=4
```

### Stable Diffusion 优化

NVIDIA GPU 优化：

```yaml
environment:
  - COMMANDLINE_ARGS=--opt-split-attention --xformers --listen --api
```

AMD GPU 优化：

```yaml
environment:
  - COMMANDLINE_ARGS=--precision autocast --no-half --listen --api
```

### 内存限制

```yaml
deploy:
  resources:
    limits:
      memory: 16G
    reservations:
      memory: 8G
```

## 📊 监控

### 查看资源使用

```bash
docker stats ollama open-webui stable-diffusion perplexica
```

### 查看 GPU 使用

```bash
# NVIDIA
nvidia-smi dmon

# AMD
rocm-smi --showallinfo
```

## 🐛 常见问题

### Ollama 启动失败

```bash
# 检查端口占用
netstat -tlnp | grep 11434

# 查看日志
docker compose logs ollama

# 重启服务
docker compose restart ollama
```

### Stable Diffusion 内存不足

1. 减少并发请求
2. 使用 `--medvram` 或 `--lowvram` 参数
3. 增加 swap 空间

### GPU 不被识别

```bash
# NVIDIA
sudo systemctl restart docker
nvidia-ctk runtime configure --runtime=docker

# AMD
sudo usermod -a -G render,video $USER
```

## 📈 性能基准

### CPU (Intel i7-12700K)

- llama3.2:3b - ~5 tokens/s
- llama3.2:7b - ~2 tokens/s

### NVIDIA RTX 3060 12GB

- llama3.2:3b - ~50 tokens/s
- llama3.2:7b - ~35 tokens/s
- llama3.1:70b (量化) - ~15 tokens/s

### AMD RX 6700 XT 12GB

- llama3.2:3b - ~40 tokens/s
- llama3.2:7b - ~28 tokens/s

## 🔄 更新

```bash
# 拉取最新镜像
docker compose pull

# 重启服务
docker compose up -d --force-recreate

# 清理旧镜像
docker image prune -f
```

## 🗑️ 卸载

```bash
# 停止并删除容器（保留数据）
docker compose down

# 完全删除（包括数据）
docker compose down -v

# 删除镜像
docker rmi ollama/ollama:0.3.14
docker rmi ghcr.io/open-webui/open-webui:v0.3.35
docker rmi ghcr.io/abiosoft/sd-webui-docker:cpu-v1.10.1
```

---

**文档版本**: 1.0.0  
**更新日期**: 2026-03-22
