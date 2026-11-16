# 🧠 HomeLab AI Stack (Ollama + Open WebUI + Stable Diffusion + Perplexica)

完整本地 AI 推理与生成服务栈，支持 **NVIDIA CUDA**、**AMD ROCm** 与 **纯 CPU 自适应回退**，内置 Traefik HTTPS 反代、Authentik OIDC 单点登录及国内镜像加速（`hf-mirror.com` / `ghcr.nju.edu.cn`）。

## 1. 服务组件与锁定版本

| 服务 | 锁定镜像版本 | 域名路由 | 用途 |
| :--- | :--- | :--- | :--- |
| **Ollama** | `ollama/ollama:0.3.14` | `ollama.${DOMAIN}` | 本地大语言模型推理引擎 |
| **Open WebUI** | `ghcr.io/open-webui/open-webui:v0.3.35` | `ai.${DOMAIN}` | AI 对话界面，集成 Authentik OIDC 与 SD 画图 |
| **Stable Diffusion** | `ghcr.io/abiosoft/sd-webui-docker:cpu-v1.10.1` | `sd.${DOMAIN}` | 文生图 / 图生图引擎（开启 `--api` 供 WebUI 调用） |
| **Perplexica** | `itzcrazykns1337/perplexica:v1.8.0` | `search.ai.${DOMAIN}` | AI 联网检索引擎 |

## 2. 快速启动

```bash
# 1. 复制环境变量配置
cp stacks/ai/.env.example stacks/ai/.env

# 2. 自动检测 GPU/CPU 并导出运行参数
source scripts/gpu-detect.sh

# 3. 启动 AI 服务栈
docker compose --env-file stacks/ai/.env -f stacks/ai/docker-compose.yml up -d
```

## 3. 国内网络加速适配 (CN Mirror)
- HuggingFace 模型下载默认走 `HF_ENDPOINT=https://hf-mirror.com`。
- 如需加速 `ghcr.io` 镜像拉取，可在 `stacks/ai/.env` 中将 `ghcr.io` 替换为 `ghcr.nju.edu.cn`。
