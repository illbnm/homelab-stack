# AI Stack — 本地 AI 推理服务

Issue #6 · Bounty $220 · Difficulty: Hard

## 概览

本地 AI 推理栈，支持 NVIDIA GPU / AMD GPU / CPU 三种部署模式。

## 服务

| 服务 | 端口 | 用途 |
|------|------|------|
| Ollama | 11434 | LLM 推理引擎 |
| Open WebUI | 8080 | LLM Web 界面 |
| Stable Diffusion | 7860 | 图像生成 |
| Perplexica | 3003 | AI 搜索引擎 |

## 快速开始

### NVIDIA GPU（推荐）
```bash
docker compose --profile ai up -d
```

### AMD GPU (ROCm)
```bash
docker compose --profile ai-rocm up -d
```

### CPU Only
```bash
docker compose --profile ai-cpu up -d
```

## GPU 自适应

通过 Profile 选择部署模式：

| Profile | 说明 |
|---------|------|
| `ai` | NVIDIA GPU (CUDA) |
| `ai-rocm` | AMD GPU (ROCm) |
| `ai-cpu` | 纯 CPU |
| `full` | 完整栈（含 GPU） |

## 环境变量

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `GPU_DRIVER` | nvidia | GPU 驱动类型 |
| `GPU_COUNT` | all | GPU 数量 |
| `OLLAMA_KEEP_ALIVE` | 24h | 模型保活时间 |
| `WEBUI_NAME` | HomeLab AI | WebUI 名称 |
| `SD_CLI_ARGS` | --xformers --listen | SD 启动参数 |

## 模型管理

```bash
# 拉取模型
docker exec ollama ollama pull llama3.1:8b
docker exec ollama ollama pull mistral:7b

# 列出已安装模型
docker exec ollama ollama list

# 删除模型
docker exec ollama ollama rm <model>
```

## 故障排除

1. **GPU 不可用**: 检查 NVIDIA Container Toolkit 安装
2. **Ollama 启动慢**: 首次加载模型需下载，耐心等待
3. **SD 内存不足**: 使用 `--medvram` 或 `--lowvram` 参数

## 验收标准

- ✅ Ollama 运行并可拉取模型
- ✅ Open WebUI 可访问并连接 Ollama
- ✅ Stable Diffusion 可生成图像
- ✅ Perplexica 可进行 AI 搜索
- ✅ 支持 GPU/CPU 自适应
- ✅ Traefik 集成
- ✅ 健康检查配置
