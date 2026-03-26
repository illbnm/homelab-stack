# AI Stack

> 本地 AI 推理栈，支持 LLM 对话和图像生成。

## 服务清单

| 服务 | 镜像 | 用途 |
|------|------|------|
| Ollama | `ollama/ollama:0.5.6` | 本地大语言模型推理引擎 |
| Open WebUI | `ghcr.io/open-webui/open-webui:main` | LLM 聊天 Web 界面 |
| Stable Diffusion | `ghcr.io/automatictroll/automatic1111-webui:1.10` | 图像生成 Web UI + API |

## 前置准备

### 1. 依赖 Base 栈

本栈依赖 Base 栈提供的反向代理和网络，请先完成 [Base 栈](../base/README.md) 的部署。

确保已创建共享网络：

```bash
docker network create proxy
```

### 2. 配置 DNS

将以下域名解析到你的 homelab 服务器 IP：
- `ai.${DOMAIN}` - Open WebUI 聊天界面
- `ollama.${DOMAIN}` - Ollama API（如需外部访问）
- `sd.${DOMAIN}` - Stable Diffusion WebUI

### 3. 配置环境变量

```bash
# 复制环境变量文件
cp stacks/ai/.env.example stacks/ai/.env
nano stacks/ai/.env  # 编辑配置
```

**关键配置项：**

| 变量 | 说明 | 默认值 |
|------|------|--------|
| `OLLAMA_GPU_TYPE` | GPU 类型：`nvidia`、`amd`、`cpu` | `cpu` |
| `OLLAMA_MODELS` | 首次启动自动下载的模型列表（逗号分隔） | `llama3.3 mistral` |
| `SD_GPU_TYPE` | Stable Diffusion GPU 类型 | `cpu` |
| `OPEN_WEBUI_OAUTH_CLIENT_ID` | Authentik OIDC Client ID（可选） | 空 |
| `OPEN_WEBUI_OAUTH_CLIENT_SECRET` | Authentik OIDC Client Secret（可选） | 空 |

生成 Open WebUI 密钥：

```bash
openssl rand -hex 32
```

将输出复制到 `.env` 文件中的 `WEBUI_SECRET_KEY` 变量。

## GPU 加速配置

### NVIDIA GPU

```bash
# 确保已安装 NVIDIA Container Toolkit
# https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html
```

在 `.env` 中设置：

```env
OLLAMA_GPU_TYPE=nvidia
SD_GPU_TYPE=nvidia
SD_COMMANDLINE_ARGS=--xformers --enable-insecure-extension-access --api
```

### AMD GPU (ROCm)

```env
OLLAMA_GPU_TYPE=amd
SD_GPU_TYPE=amd
SD_COMMANDLINE_ARGS=--use-rocmm --enable-insecure-extension-access --api
```

### CPU Only（默认）

```env
OLLAMA_GPU_TYPE=cpu
SD_GPU_TYPE=cpu
SD_COMMANDLINE_ARGS=--no-half --skip-torch-cuda-test --use-cpu all --force-enable-textseg
```

## 启动服务

```bash
cd stacks/ai
docker compose up -d
```

检查容器状态：

```bash
docker compose ps
```

所有容器状态应该显示 `Up (healthy)`。

### 下载模型（可选）

首次部署时自动下载 `OLLAMA_MODELS` 中指定的模型。如果需要下载额外的模型：

```bash
# 进入 ollama 容器
docker exec -it ollama bash

# 拉取模型
ollama pull llama3.3
ollama pull mistral
ollama pull gemma:7b
ollama pull phi4
```

## Authentik SSO 配置（可选）

### 1. 在 Authentik 创建 Application

1. 登录 Authentik 管理界面
2. 进入 **Applications** → **Applications** → **Create**
3. 配置：
   - **Name**: Open WebUI
   - **Provider type**: OAuth2/OpenID Connect
   - **Redirect URI** (Strict): `https://ai.${DOMAIN}/oauth/oidc/callback`
4. 记下 **Client ID** 和 **Client Secret**

### 2. 配置 Open WebUI 环境变量

在 `stacks/ai/.env` 中填入：

```env
OPEN_WEBUI_OAUTH_CLIENT_ID=<your-client-id>
OPEN_WEBUI_OAUTH_CLIENT_SECRET=<your-client-secret>
OIDC_DISABLE_LOGIN_FORM=false      # true = 禁用本地登录，SSO only
OIDC_ENABLE_SIGNUP=false            # true = 允许 OAuth 用户自动注册
```

重启服务：

```bash
cd stacks/ai
docker compose up -d open-webui
```

## API 访问

### Ollama API

内部访问：`http://ollama:11434`

外部访问：`https://ollama.${DOMAIN}`

常用端点：

```bash
# 列出已下载模型
curl http://localhost:11434/api/tags

# 生成文本
curl -X POST http://localhost:11434/api/generate \
  -d '{"model": "llama3.3", "prompt": "Hello!"}'

# 流式生成
curl -X POST http://localhost:11434/api/generate \
  -d '{"model": "llama3.3", "prompt": "Hello!", "stream": true}'
```

### Stable Diffusion API

API 文档：`https://sd.${DOMAIN}/sdapi/v1/`

常用端点：

```bash
# 列出可用模型
curl http://localhost:7860/sdapi/v1/sd-models

# 图像生成
curl -X POST http://localhost:7860/sdapi/v1/txt2img \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "a beautiful landscape",
    "steps": 20,
    "width": 512,
    "height": 512
  }'
```

## 验收检查

1. ✅ `docker compose ps` 所有容器状态为 `Up (healthy)`
2. ✅ `curl http://localhost:11434/api/tags` 正常返回已下载模型列表
3. ✅ `https://ai.${DOMAIN}` 能正常访问 Open WebUI
4. ✅ `https://sd.${DOMAIN}` 能正常访问 Stable Diffusion WebUI
5. ✅ `https://sd.${DOMAIN}/sdapi/v1/options` API 可访问（返回 200）

## 文件结构

```
stacks/ai/
├── docker-compose.yml    # Docker Compose 配置
├── .env.example          # 环境变量示例
└── README.md             # 本文件
```

## 依赖

- Docker 20.10+
- Docker Compose v2+
- Base 栈已部署
- 推荐：NVIDIA/AMD GPU 加速（可选）
