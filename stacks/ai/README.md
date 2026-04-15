# AI Stack

完整的AI服务栈，提供本地LLM推理、图像生成、AI搜索功能。

## 服务列表

| 服务 | 端口 | 子域名 | 说明 |
|------|------|--------|------|
| Ollama | 11434 | ollama.DOMAIN | LLM推理引擎 |
| Open WebUI | 8080 | ai.DOMAIN | ChatGPT风格界面 |
| Stable Diffusion | 7860 | sd.DOMAIN | AI图像生成 |
| Perplexica | 3000 | search.DOMAIN | AI搜索引擎 |
| SearXNG | 8080 | searx.DOMAIN | 搜索后端 |

## GPU 自适应

自动检测并使用可用GPU：

| 模式 | LLM速度 | 图像生成 | 推荐场景 |
|------|---------|----------|----------|
| NVIDIA GPU | ⚡⚡⚡ | ⚡⚡⚡ | 生产环境 |
| AMD GPU | ⚡⚡ | ⚡⚡ | 预算有限 |
| CPU | ⚡ | ⏳ | 测试 |

### GPU 检测
```bash
./scripts/ai-model-manager.sh detect-gpu
```

## 推荐模型

### LLM
| 模型 | 大小 | 用途 |
|------|------|------|
| qwen2.5:14b | 9GB | 通用对话/编程 |
| codellama:7b | 4GB | 代码生成 |
| llama3.2:3b | 2GB | 轻量对话 |

### Vision
| 模型 | 大小 | 用途 |
|------|------|------|
| llava:7b | 4GB | 图像理解/OCR |

### Embedding
| 模型 | 大小 | 用途 |
|------|------|------|
| nomic-embed-text | 274MB | RAG文本嵌入 |

## 快速开始

```bash
cd stacks/ai

# 1. 配置环境变量
cp .env.example .env

# 2. 检测GPU
./scripts/ai-model-manager.sh detect-gpu

# 3. 启动服务
docker compose up -d

# 4. 安装推荐模型
./scripts/ai-model-manager.sh install-llms
```

## 模型管理

```bash
# 列出已安装模型
./scripts/ai-model-manager.sh list

# 安装指定模型
./scripts/ai-model-manager.sh install qwen2.5:14b

# 删除模型
./scripts/ai-model-manager.sh remove qwen2.5:14b

# 查看存储使用
./scripts/ai-model-manager.sh storage
```

## 存储优化

```bash
# 预览清理内容
./scripts/ai-storage-optimizer.sh --dry-run

# 执行清理
./scripts/ai-storage-optimizer.sh
```

清理内容：
- Docker系统缓存
- 临时文件 (>7天)
- Stable Diffusion输出 (>30天)
- 未使用的Docker镜像

## SSO 集成

Open WebUI 支持 Authentik OIDC 登录：

1. 在 Authentik 中创建 OAuth2 应用
2. 获取 Client ID 和 Secret
3. 填入 .env 文件
4. 重启 Open WebUI

## 硬件要求

### 最低配置 (CPU模式)
- CPU: 4核心
- RAM: 8GB
- 存储: 50GB

### 推荐配置 (GPU模式)
- GPU: NVIDIA RTX 3060 或更高
- RAM: 16GB
- 存储: 100GB

## 故障排查

### GPU未检测到
```bash
# 检查NVIDIA驱动
nvidia-smi

# 检查Docker GPU支持
docker run --rm --gpus all nvidia/cuda:11.0-base nvidia-smi
```

### Ollama无法启动
```bash
# 检查日志
docker logs ollama

# 检查端口
curl http://localhost:11434/api/tags
```

### 模型下载失败
```bash
# 手动下载
docker exec ollama ollama pull qwen2.5:14b

# 检查网络
docker exec ollama curl -I https://registry.ollama.ai
```

## 性能调优

- Ollama: 根据GPU显存调整模型大小
- Stable Diffusion: GPU模式下移除 --use-cpu all
- Open WebUI: 调整并发请求数
- 定期运行存储优化脚本
