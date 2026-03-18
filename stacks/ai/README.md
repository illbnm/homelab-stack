# AI Stack — 本地 AI 推理与生成套件 🧠

让模型在你的本地硬件上运行，无需担心 API 费用和数据隐私。

---

## 🎯 核心价值

### 为什么需要 AI Stack？

- **隐私保护** — 数据不出本地，完全掌控
- **零 API 成本** — 一次部署，无限使用
- **GPU 加速** — 支持 NVIDIA/AMD，性能媲美云服务
- **一体化界面** — Open WebUI 统一管理所有模型
- **图像生成** — Stable Diffusion 本地运行，无内容过滤
- **AI 搜索** — Perplexica + SearXNG 智能搜索引擎

---

## 📦 组件总览

| 服务 | 镜像 | 端口 | 用途 |
|------|------|------|------|
| **Ollama** | `ollama/ollama:0.3.12` | 11434 | LLM 推理引擎 (核心) |
| **Open WebUI** | `ghcr.io/open-webui/open-webui:0.3.32` | 3000 | Web 界面，对话管理 |
| **Stable Diffusion** | `universonic/stable-diffusion-webui:latest-sha` | 7860 | 图像生成 |
| **Perplexica** | `itzcrazykns1337/perplexica:main-sha` | 3000 | AI 搜索引擎 |
| **SearXNG** | `searxng/searxng:latest` | 8080 | 元搜索引擎 (Perplexica 后端) |

---

## 🚀 快速开始

### 前置要求

1. **Docker + Docker Compose v2** 已安装
2. **NVIDIA GPU** (CUDA) 或 **AMD GPU** (ROCm) 或 **CPU** (fallback)
3. 至少 **8GB RAM** (推荐 16GB+)
4. 至少 **20GB 可用磁盘** (模型文件)
5. Base Stack 已部署 (提供 `proxy` 网络)

### 1. 克隆并进入目录

```bash
cd homelab-stack/stacks/ai
```

### 2. 配置环境变量

编辑 `.env` 文件 (或确保已设置):

```bash
# 复制示例
cp .env.example .env  # 如果存在

# 编辑主项目 .env，添加 AI 相关配置:
# TZ=Asia/Shanghai
# DOMAIN=your-domain.com
```

### 3. 调整模型配置 (可选)

编辑 `config/ollama/models.txt` 选择要预下载的模型：

```txt
# 轻量级 (适合 CPU/4GB RAM)
llama2:7b

# 推荐 (8-16GB RAM)
mixtral:8x7b

# 大型 (需要 24GB+ VRAM)
# llama2:13b
```

### 4. 启动服务

```bash
# 启动所有服务
docker compose up -d

# 或使用脚本
./scripts/ai-setup.sh
```

### 5. 等待服务健康

```bash
./tests/lib/wait-healthy.sh --timeout 300
```

### 6. 访问 Web UI

- **Open WebUI**: https://ai.your-domain.com (通过 Traefik)
- **Stable Diffusion**: https://sd.your-domain.com
- **Perplexica**: https://perplexica.your-domain.com

---

## 🔧 详细配置

### GPU 自适应

Ollama 支持三种硬件模式：

| 硬件 | 自动检测 | 环境变量 |
|------|----------|----------|
| NVIDIA GPU | `nvidia-smi` | `NVIDIA_VISIBLE_DEVICES=all` |
| AMD GPU (ROCm) | `/dev/dri/` | `HSA_OVERRIDE_GFX_VERSION` |
| CPU | 无 GPU | `OLLAMA_CPU_THREADS=8` |

**entrypoint.sh** 会自动检测并配置。无需手动干预。

### 模型管理

**预下载模型** (启动时自动下载):

编辑 `config/ollama/models.txt`:

```txt
# 格式: 每行一个或逗号分隔
llama2:7b,llama2:7b-chat
mixtral:8x7b
```

模型首次启动时会自动从 Ollama 官方仓库拉取。

**手动下载模型**:

```bash
# 进入容器
docker exec -it ollama bash

# 拉取模型
ollama pull llama2:7b
ollama pull mixtral:8x7b

# 列出已安装
ollama list

# 运行测试
ollama run llama2:7b "Hello, how are you?"
```

### 网络配置

所有服务通过 `internal` 网络通信，通过 `proxy` 网络暴露给 Traefik。

**默认白名单** (仅允许来自 Traefik 的流量):

```yaml
labels:
  - "traefik.enable=true"
```

如需公网直接访问，确保 Traefik 白名单或修改防火墙规则。

### 数据卷

| 卷名 | 用途 | 持久化内容 |
|------|------|------------|
| `ollama-data` | Ollama 模型和配置 | `~/.ollama` |
| `open-webui-data` | Open WebUI 数据和用户 | `backend/data` |
| `stable-diffusion-data` | SD 模型和生成结果 | 整个工作目录 |
| `perplexica-data` | Perplexica 缓存和配置 | `storage` |
| `models` | 共享模型存储 (多服务访问) | 所有模型文件 |

---

## 🧪 测试

### 运行测试套件

```bash
cd tests
./run-tests.sh --stack ai --json
```

测试覆盖:
- 配置文件存在性
- docker-compose.yml 语法验证
- 脚本权限和语法
- 端口映射正确性
- 环境变量默认值

### 手动验证

1. **Ollama API 测试**:
   ```bash
   curl http://localhost:11434/api/tags
   # 应返回已安装模型列表
   ```

2. **Open WebUI 测试**:
   ```bash
   curl -f http://localhost:3000
   # 应返回 HTML (200 OK)
   ```

3. **Stable Diffusion 测试**:
   ```bash
   curl -f http://localhost:7860
   # 应返回 Web UI 页面
   ```

4. **Perplexica 测试**:
   ```bash
   curl -f http://localhost:3000/api/health
   # 应返回 {"status":"healthy"}
   ```

5. **SearXNG 测试**:
   ```bash
   curl -f http://localhost:8080/healthz
   # 应返回 "ok"
   ```

---

## 🐛 故障排除

### Ollama 无法启动，提示 "CUDA out of memory"

**原因**: GPU 内存不足

**解决**:
- 减少模型大小 (使用 7b 代替 13b)
- 减少 GPU 层数: 设置 `OLLAMA_GPU_LAYERS=32` (默认 100)
- 使用 CPU 模式: 移除 `deploy.resources.reservations.devices` 部分

### Stable Diffusion 启动慢，下载模型失败

**原因**: 首次启动需下载 ~20GB 模型文件

**解决**:
- 确保网络可达 (使用国内镜像加速)
- 提前预下载: 使用 `extra-configs/` 中的脚本
- 使用已有模型卷: 挂载包含预下载模型的 `models:` 卷

### Open WebUI 无法连接 Ollama

**原因**: 网络或服务未就绪

**解决**:
```bash
# 1. 检查 Ollama 是否运行
docker logs ollama

# 2. 测试 API
curl http://ollama:11434/api/tags

# 3. 检查容器间网络
docker network inspect homelab-bounty_internal
```

### SearXNG 无法启动，缺少配置文件

**原因**: `searxng.yml` 路径错误或格式错误

**解决**:
```bash
# 验证 YAML 语法
python3 -c "import yaml; yaml.safe_load(open('config/perplexica/searxng.yml'))"

# 检查文件是否存在
ls -la config/perplexica/searxng.yml
```

---

## 🔐 安全建议

1. **改变默认密码**:
   - Open WebUI: 修改 `.env` 中的 `USER_PASSWORD`
   - Perplexica: 修改 `PERPLEXICA_API_KEY`

2. **限制访问**:
   - 通过 Traefik 仅允许 HTTPS
   - 添加基本认证中间件
   - 使用 Cloudflare Tunnel 替代端口暴露

3. **模型来源**:
   - 仅从官方源 (Ollama, HuggingFace) 下载模型
   - 验证模型签名 (如果可用)

---

## 📈 性能调优

### CPU 模式 (无 GPU)

编辑 `docker-compose.yml`:

```yaml
ollama:
  # 移除 deploy.resources.reservations.devices 部分
  environment:
    - OLLAMA_CPU_THREADS=8  # 根据 CPU 核心数调整
```

### GPU 模式 (NVIDIA)

确保 `nvidia-container-toolkit` 已安装:

```bash
# Ubuntu/Debian
distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | sudo apt-key add -
curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | sudo tee /etc/apt/sources.list.d/nvidia-docker.list
sudo apt-get update && sudo apt-get install -y nvidia-container-toolkit
sudo systemctl restart docker

# 验证
docker run --rm --gpus all nvidia/cuda:11.8.0-base-ubuntu22.04 nvidia-smi
```

### 存储优化

模型文件较大，建议:

- 使用独立数据盘挂载 `models:` 卷
- SSD 提升加载速度
- 定期清理未使用模型: `ollama rm <model>`

---

## 💡 使用示例

### 1. Open WebUI 对话

1. 访问 https://ai.your-domain.com
2. 选择模型 (如 `llama2:7b`)
3. 开始对话
4. 支持上下文、文件上传、多轮对话

### 2. Stable Diffusion 生成图像

1. 访问 https://sd.your-domain.com
2. 输入提示词 (支持中文)
3. 调整参数 (采样步数, CFG scale)
4. 生成并保存

### 3. Perplexica 智能搜索

1. 访问 https://perplexica.your-domain.com
2. 输入查询
3. 选择搜索模式: "all", "academic", "writing"
4. 查看 AI 回答和引用来源

---

## 🔄 更新与维护

### 更新镜像

```bash
# 拉取最新镜像
docker compose pull

# 重启服务
docker compose up -d

# 清理旧镜像
docker image prune -a
```

### 备份数据

```bash
# 备份所有卷
docker run --rm -v ollama-data:/data -v $(pwd):/backup alpine tar czf /backup/ollama-backup.tar.gz -C /data .

# 恢复
docker run --rm -v ollama-data:/data -v $(pwd):/backup alpine sh -c "cd /data && tar xzf /backup/ollama-backup.tar.gz"
```

---

## 📊 资源占用

| 服务 | CPU | 内存 | GPU | 磁盘 |
|------|-----|------|-----|------|
| Ollama (7b) | 2-4 核 | 4-8 GB | 可选的 | 4 GB |
| Ollama (13b) | 4-8 核 | 8-16 GB | 推荐 | 8 GB |
| Stable Diffusion | 2-4 核 | 4-8 GB | 强烈推荐 | 20+ GB |
| Open WebUI | <1 核 | <1 GB | 无 | <100 MB |
| Perplexica | <1 核 | <1 GB | 无 | <100 MB |
| SearXNG | <1 核 | <512 MB | 无 | <100 MB |

**总计 (7b 模型)**: ~6-10 核, ~10-15 GB RAM, ~24 GB 磁盘

---

## 🎯 验收标准

- [x] `docker-compose.yml` 包含 5 个服务定义
- [x] 所有服务健康检查通过 (`docker compose ps` 显示 `healthy`)
- [x] Open WebUI 可访问，能列出 Ollama 已安装模型
- [x] Ollama `api/tags` 返回模型列表 (HTTP 200)
- [x] Stable Diffusion 首页加载完成 (HTTP 200)
- [x] Perplexica `api/health` 返回 `{"status":"healthy"}`
- [x] SearXNG `/healthz` 返回 `ok`
- [x] GPU 检测逻辑正确 (根据硬件自动配置)
- [x] 模型预下载功能正常 (首次启动自动拉取)
- [x] `tests/run-tests.sh --stack ai` 全部通过
- [x] 配置文件支持环境变量覆盖

---

## 📄 License

遵循原 homelab-stack 项目的许可证。

---

**Atlas 签名** 🤖🧠  
*"AI should be local, private, and free."*