# AI Stack - Ollama + Open WebUI + Stable Diffusion

**Issue**: #6 - AI Stack  
**Bounty**: $220 USDT  
**Status**: ✅ Complete

---

## 📦 包含服务

### 1. Ollama - 本地 LLM 推理引擎

- **镜像**: `ollama/ollama:0.3.14`
- **端口**: 11434
- **访问**: `https://ollama.${DOMAIN}`
- **功能**:
  - 本地运行开源大语言模型 (Llama 3, Mistral, Qwen 等)
  - RESTful API 接口
  - 自动模型下载和管理
  - GPU 加速支持 (可选)

### 2. Open WebUI - AI 聊天界面

- **镜像**: `ghcr.io/open-webui/open-webui:v0.3.35`
- **端口**: 8080
- **访问**: `https://ai.${DOMAIN}`
- **功能**:
  - 类 ChatGPT 的用户界面
  - 支持多个 AI 模型
  - 对话历史和上下文管理
  - 中文界面支持
  - 文件上传和分析
  - RAG (检索增强生成) 支持

### 3. Stable Diffusion WebUI (可选)

- **镜像**: `ghcr.io/neggles/sd-webui-docker:latest`
- **端口**: 7860
- **访问**: `https://sd.${DOMAIN}`
- **功能**:
  - AI 图像生成
  - 文生图/图生图
  - 模型管理和切换
  - 扩展插件支持

---

## 🚀 快速启动

### 1. 启动 AI Stack

```bash
cd stacks/ai
docker compose up -d
```

### 2. 下载模型

```bash
# 通过 Ollama CLI 下载模型
docker exec -it ollama ollama pull llama3.2
docker exec -it ollama ollama pull qwen2.5:7b
docker exec -it ollama ollama pull mistral
```

### 3. 访问服务

- **Open WebUI**: https://ai.yourdomain.com
- **Ollama API**: https://ollama.yourdomain.com/api
- **Stable Diffusion**: https://sd.yourdomain.com

---

## ⚙️ 配置说明

### 环境变量

在 `.env` 文件中配置:

```bash
# 域名配置
DOMAIN=yourdomain.com

# Open WebUI 密钥 (32 字符随机字符串)
WEBUI_SECRET_KEY=your-secret-key-here

# GPU 支持 (可选)
NVIDIA_VISIBLE_DEVICES=all
```

### Traefik 集成

所有服务已配置 Traefik 反向代理:

- 自动 HTTPS 证书
- 域名路由
- 健康检查

### 数据持久化

```yaml
volumes:
  - ollama-data:/root/.ollama      # Ollama 模型数据
  - open-webui-data:/app/backend/data  # WebUI 对话数据
  - sd-models:/stable-diffusion-webui/models  # SD 模型
```

---

## 🔧 高级配置

### GPU 加速 (NVIDIA)

编辑 `docker-compose.yml`:

```yaml
services:
  ollama:
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: 1
              capabilities: [gpu]
```

### 模型推荐

#### 文本生成 (Ollama)
- `llama3.2` - Meta 最新模型，平衡性能和速度
- `qwen2.5:7b` - 阿里通义千问，中文优化
- `mistral` - Mistral AI 7B 模型
- `codellama` - 代码生成专用

#### 图像生成 (Stable Diffusion)
- `sd-v1-5` - 经典版本，兼容性好
- `sd-xl` - 高质量图像生成
- `realistic-vision` - 写实风格

---

## 📊 资源需求

| 服务 | CPU | 内存 | 存储 | GPU (可选) |
|------|-----|------|------|-----------|
| Ollama | 2-4 核 | 4-8GB | 10-50GB | 推荐 |
| Open WebUI | 1-2 核 | 2-4GB | 5GB | 不需要 |
| Stable Diffusion | 4-8 核 | 8-16GB | 20-100GB | 必需 |

**最低配置**: 4 核 CPU, 8GB 内存, 50GB 存储  
**推荐配置**: 8 核 CPU, 16GB 内存, 100GB 存储, NVIDIA GPU

---

## 🔍 健康检查

```bash
# 检查服务状态
docker compose ps

# 查看日志
docker compose logs -f ollama
docker compose logs -f open-webui

# 测试 Ollama API
curl https://ollama.yourdomain.com/api/tags

# 测试 Open WebUI
curl https://ai.yourdomain.com/health
```

---

## 🛡️ 安全建议

1. **强密码**: 修改默认密钥
2. **防火墙**: 仅开放 443 端口
3. **认证**: 启用 Open WebUI 用户认证
4. **监控**: 配置日志记录和告警

---

## 📝 使用示例

### 通过 API 调用 Ollama

```bash
curl -X POST https://ollama.yourdomain.com/api/generate \
  -H "Content-Type: application/json" \
  -d '{
    "model": "llama3.2",
    "prompt": "Hello, how are you?",
    "stream": false
  }'
```

### 在 Open WebUI 中使用

1. 访问 https://ai.yourdomain.com
2. 首次访问创建管理员账号
3. 在设置中选择下载的模型
4. 开始对话

---

## 🔄 更新和维护

```bash
# 更新镜像
docker compose pull

# 重启服务
docker compose down && docker compose up -d

# 清理未使用的模型
docker exec ollama ollama prune
```

---

## 📞 故障排除

### Ollama 无法下载模型
```bash
# 检查网络连接
docker exec ollama curl -I https://ollama.com

# 手动导入模型
docker cp model.bin ollama:/tmp/model.bin
docker exec ollama ollama create mymodel -f /tmp/Modelfile
```

### Open WebUI 无法连接 Ollama
```bash
# 检查 OLLAMA_BASE_URL 配置
docker compose exec open-webui env | grep OLLAMA

# 测试内部网络
docker compose exec open-webui curl http://ollama:11434/api/tags
```

---

## 📚 参考链接

- [Ollama 官方文档](https://ollama.com/)
- [Open WebUI 文档](https://docs.openwebui.com/)
- [Stable Diffusion WebUI](https://github.com/AUTOMATIC1111/stable-diffusion-webui)
- [Issue #6](https://github.com/illbnm/homelab-stack/issues/6)

---

**开发者**: 牛马 🐂🐴  
**提交时间**: 2026-03-20  
**Bounty 金额**: $220 USDT
