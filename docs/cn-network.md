# 中国大陆网络环境适配

本项目已完整支持中国大陆网络环境下的自动部署。

## 🚀 快速开始（中国大陆用户）

```bash
# 1. 配置 Docker 镜像加速（推荐首次运行时执行）
./scripts/setup-cn-mirrors.sh

# 2. 将所有镜像替换为国内 CDN 源
./scripts/localize-images.sh --cn

# 3. 安装并启动
./install.sh
```

## 🛠 工具说明

### 1. setup-cn-mirrors.sh — Docker 镜像加速配置

自动检测网络环境，配置国内 Docker 镜像加速源。

```bash
./scripts/setup-cn-mirrors.sh              # 交互式配置
./scripts/setup-cn-mirrors.sh --silent      # 自动检测并配置
./scripts/setup-cn-mirrors.sh --minimal     # 仅配置主镜像源
./scripts/setup-cn-mirrors.sh --show        # 显示当前配置
./scripts/setup-cn-mirrors.sh --verify      # 验证镜像拉取
```

**支持的镜像源：**
- DaoCloud: `https://docker.m.daocloud.io`
- 网易: `https://hub-mirror.c.163.com`
- 百度: `https://mirror.baidubce.com`
- Google Mirror: `https://mirror.gcr.io`

### 2. localize-images.sh — 镜像替换工具

批量替换 docker-compose 文件中的镜像为国内源。

```bash
./scripts/localize-images.sh --cn         # 替换为国内镜像
./scripts/localize-images.sh --restore   # 恢复原始镜像
./scripts/localize-images.sh --dry-run  # 预览变更
./scripts/localize-images.sh --check    # 检测是否需要替换
```

**镜像映射表：** `config/cn-mirrors.yml`

支持的镜像包括：
- `gcr.io/*` → `gcr.m.daocloud.io/*`
- `ghcr.io/*` → `ghcr.m.daocloud.io/*`
- `docker.io/*` → `docker.m.daocloud.io/*`
- 以及所有 linuxserver.io 系列镜像

### 3. check-connectivity.sh — 网络连通性检测

检测 Docker Hub、GitHub、gcr.io、ghcr.io 等的可达性。

```bash
./scripts/check-connectivity.sh           # 完整检测
./scripts/check-connectivity.sh --quick   # 快速检测
./scripts/check-connectivity.sh --cn-mirrors  # 仅检测国内镜像源
```

### 4. wait-healthy.sh — 容器健康等待

等待 Docker Compose 堆栈中所有容器通过健康检查。

```bash
./scripts/wait-healthy.sh                          # 等待默认 compose
./scripts/wait-healthy.sh docker-compose.yml       # 指定文件
./scripts/wait-healthy.sh -s monitoring           # 等待指定堆栈
./scripts/wait-healthy.sh -t 600 -f               # 600秒超时，实时输出
```

### 5. diagnose.sh — 一键诊断

收集系统信息、Docker 状态、网络连通性等诊断信息。

```bash
./scripts/diagnose.sh
```

输出示例：
```
诊断时间: 2024-01-01 12:00:00
报告目录: .diagnose-20240101120000

关键检查项:
  Docker 安装: 是
  Docker Compose v2: 是
  .env 文件: 是
  运行中容器: 12 个
  可用磁盘空间: 50GB
```

## 🔧 手动配置

### apt 源（Ubuntu/Debian）

```bash
# 替换为清华源
sudo sed -i 's|http://archive.ubuntu.com|https://mirrors.tuna.tsinghua.edu.cn|g' /etc/apt/sources.list
sudo apt update
```

### pip 源

```bash
pip3 config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple
```

### Alpine 源

```bash
echo "https://mirrors.ustc.edu.cn/alpine/v3.18/main" > /etc/apk/repositories
echo "https://mirrors.ustc.edu.cn/alpine/v3.18/community" >> /etc/apk/repositories
apk update
```

## 📡 网络检测

手动检测网络连通性：

```bash
# 检测 Docker Hub
curl -sf --connect-timeout 5 https://registry-1.docker.io/v2/ && echo "OK"

# 检测 GitHub
curl -sf --connect-timeout 5 https://api.github.com/ && echo "OK"

# 检测国内镜像源
curl -sf --connect-timeout 5 https://docker.m.daocloud.io/v2/ && echo "OK"
```

## ❓ 常见问题

**Q: 镜像拉取仍然很慢怎么办？**

A: 尝试使用 `localize-images.sh --cn` 替换所有镜像为国内源，或手动配置多个镜像源。

**Q: 如何回滚镜像替换？**

A: 运行 `./scripts/localize-images.sh --restore` 恢复原始镜像地址。

**Q: 某些镜像没有国内镜像怎么办？**

A: 可以尝试 VPN 或自行搭建镜像代理。也可以提交 Issue 请求添加新的镜像映射。
