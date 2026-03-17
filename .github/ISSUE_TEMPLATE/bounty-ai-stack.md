---
name: 💰 Bounty - AI Stack
about: 实现 AI 服务栈 (Ollama, Open WebUI, Stable Diffusion, LocalAI)
title: '[BOUNTY $220] AI Stack — 本地 AI 服务'
labels: bounty, hard
assignees: ''
---

## 赏金金额

**$220 USDT**

## 任务描述

实现完整的本地 AI 推理栈，支持 CPU/GPU 自适应部署。

## 服务清单

| 服务 | 镜像 | 用途 |
|------|------|------|
| Ollama | `ollama/ollama:0.3.12` | LLM 推理引擎 |
| Open WebUI | `ghcr.io/open-webui/open-webui:0.3.32` | LLM Web 界面 |
| Stable Diffusion | `universonic/stable-diffusion-webui:latest-sha` | 图像生成 |
| Perplexica | `itzcrazykns1337/perplexica:main-sha` | AI 搜索引擎 |

## 核心要求

### 1. GPU 自适应

```yaml
# docker-compose.yml 需支持：
# 1. NVIDIA GPU (CUDA)
# 2. AMD GPU (ROCm)
# 3. 纯 CPU fallback
# 通过环境变量