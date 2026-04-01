# AI Service Stack

AI 服务栈，提供本地大语言模型推理、LLM 聊天界面和 Stable Diffusion 图像生成能力。

## 📋 服务清单

| 服务 | 镜像 | 用途 |
|------|------|------|
| Ollama | ollama/ollama:0.3.14 | 本地大语言模型推理引擎 |
| Open WebUI | ghcr.io/open-webui/open-webui:v0.3.35 | 美观易用的 LLM 聊天 Web 界面 |
| Stable Diffusion WebUI | ghcr.io/abiosoft/sd-webui-docker:cpu-v1.10.1 | 图像生成 Web 界面（Automatic1111） |

## 🚀 前置准备

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

### 3. 创建配置环境

```bash
# 复制环境变量文件
cp stacks/ai/.env.example stacks/ai/.env
nano stacks/ai/.env  # 编辑配置
```

生成 Open WebUI 密钥：

```bash
# Generate a random secret
openssl rand -hex 16
```

将输出复制到 `.env` 文件中的 `WEBUI_SECRET_KEY` 变量。

## ⚙️ 配置说明

### Ollama 配置

- **模型存储：** 模型数据存储在 Docker volume `ollama-data` 中
- **API 访问：** 通过 `ollama.${DOMAIN}` 公开 API
- **OLLAMA_ORIGINS：** 允许所有来源访问 API，便于 Open WebUI 连接

### Open WebUI 配置

- **连接 Ollama：** 默认连接到本栈内的 Ollama 服务
- **语言设置：** 默认中文界面，可通过 `DEFAULT_LOCALE` 修改
- **数据存储：** 用户数据和配置存储在 `open-webui-data` volume
- **用户注册：** 默认允许注册，如需禁止可添加环境变量 `ENABLE_SIGNUP=false`

### Stable Diffusion 配置

- **默认配置：** 默认为 CPU 运行配置
- **NVIDIA GPU 加速：** 修改 `.env` 中的 `COMMANDLINE_ARGS`：
  ```
  COMMANDLINE_ARGS=--xformers --enable-insecure-extension-access
  ```
  如果你有 NVIDIA GPU，建议使用 nvidia-docker 或 GPU 配置运行
- **模型存储：** 模型存储在 `sd-models` volume，输出生成在 `sd-output` volume
- **支持扩展：** 可通过 WebUI 界面安装第三方扩展

## GPU 加速配置（可选）

### NVIDIA Docker 运行时

如果你有 NVIDIA GPU，需要先配置 NVIDIA Docker 运行时：

```bash
# Install NVIDIA Container Toolkit
# Reference: https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html
```

然后修改 `docker-compose.yml`，为 Ollama 和 Stable Diffusion 添加：

```yaml
deploy:
  resources:
    reservations:
      devices:
        - driver: nvidia
          count: all
          capabilities: [gpu]
```

## 🚀 启动服务

```bash
cd stacks/ai
docker compose up -d
```

检查容器状态：

```bash
docker compose ps
```

所有容器状态应该显示 `Up (healthy)`。

## 📝 首次使用

### 1. 下载 LLM 模型

```bash
# Pull a model (e.g. Llama 3 8B)
docker exec ollama ollama pull llama3:8b

# List downloaded models
docker exec ollama ollama list
```

### 2. 访问 Open WebUI

打开 `https://ai.${DOMAIN}`，注册第一个管理员账号，开始聊天。

### 3. 下载 Stable Diffusion 模型

访问 `https://sd.${DOMAIN}`，在模型下载界面下载你喜欢的模型，或者手动将模型放置到 `sd-models/Stable-diffusion/` 目录。

## ✅ 验收检查

1. ✅ Ollama 容器健康检查通过，`docker exec ollama ollama list` 正常返回
2. ✅ `ai.${DOMAIN}` 能正常访问 Open WebUI 登录页面
3. ✅ `sd.${DOMAIN}` 能正常访问 Stable Diffusion WebUI
4. ✅ 所有容器健康检查通过

## 🔧 使用指南

### 下载新的 LLM 模型

```bash
docker exec ollama ollama pull modelname:tag
```

例如：
- `llama3:8b` - Llama 3 8B (4.7GB)
- `llama3:70b` - Llama 3 70B (38GB)
- `mistral:7b` - Mistral 7B v0.3 (4.1GB)
- `gemma:7b` - Google Gemma 7B (4.8GB)

### 开启用户注册控制

在 `docker-compose.yml` 的 `open-webui` 服务环境变量添加：

```yaml
environment:
  - ENABLE_SIGNUP=false
```

重启服务后只有管理员能创建新用户。

### 访问本地 Ollama API

在集群内部，可以通过 `http://ollama:11434` 直接访问 API，外部通过 `https://ollama.${DOMAIN}` 访问。

## 📝 文件结构

```
stacks/ai/
├── docker-compose.yml    # Docker Compose 配置
├── .env.example          # 环境变量示例
└── README.md             # 本文件
```

## 🔒 安全特性

- 全部服务通过 HTTPS 访问
- 安全响应头默认启用
- 容器运行禁止新权限提升
- 支持 Watchtower 自动更新

## 📚 依赖

- Docker 20.10+
- Docker Compose v2+
- Base 栈已部署
- 推荐：NVIDIA GPU 加速（可选但推荐）
